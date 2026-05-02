const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');

const dynamo = DynamoDBDocumentClient.from(new DynamoDBClient({}));

function generateGameId() {
  return Math.random().toString(36).substring(2, 6).toUpperCase();
}

async function sendToConnection(endpoint, connectionId, data) {
  const client = new ApiGatewayManagementApiClient({
    endpoint: endpoint.replace('wss://', 'https://').replace('ws://', 'http://'),
  });
  try {
    await client.send(new PostToConnectionCommand({
      ConnectionId: connectionId,
      Data: JSON.stringify(data),
    }));
  } catch (e) {
    console.log('Failed to send to', connectionId, e.message);
  }
}

async function broadcast(endpoint, gameId, data) {
  const result = await dynamo.send(new QueryCommand({
    TableName: process.env.PLAYERS_TABLE,
    KeyConditionExpression: 'gameId = :gid',
    ExpressionAttributeValues: { ':gid': gameId },
  }));
  const players = result.Items || [];
  await Promise.all(players.map(p => sendToConnection(endpoint, p.connectionId, data)));
}

exports.handler = async (event) => {
  const { routeKey, connectionId } = event.requestContext;
  const body = event.body ? JSON.parse(event.body) : {};
  const wsEndpoint = process.env.WS_ENDPOINT + '/prod';

  if (routeKey === 'createGame') {
    const gameId = generateGameId();
    const expiresAt = Math.floor(Date.now() / 1000) + 3600;

    await dynamo.send(new PutCommand({
      TableName: process.env.GAMES_TABLE,
      Item: {
        gameId,
        hostConnectionId: connectionId,
        status: 'WAITING',
        createdAt: Date.now(),
        expiresAt,
      }
    }));

    await sendToConnection(wsEndpoint, connectionId, {
      action: 'gameCreated',
      gameId,
    });

    return { statusCode: 200 };
  }

  if (routeKey === 'startGame') {
    const { gameId } = body;

    await dynamo.send(new UpdateCommand({
      TableName: process.env.GAMES_TABLE,
      Key: { gameId },
      UpdateExpression: 'SET #s = :status',
      ExpressionAttributeNames: { '#s': 'status' },
      ExpressionAttributeValues: { ':status': 'STARTED' },
    }));

    await broadcast(wsEndpoint, gameId, { action: 'gameStarting' });

    const delay = Math.floor(Math.random() * 4000) + 2000;
    await new Promise(resolve => setTimeout(resolve, delay));

    const signalAt = Date.now();

    await dynamo.send(new UpdateCommand({
      TableName: process.env.GAMES_TABLE,
      Key: { gameId },
      UpdateExpression: 'SET signalAt = :t, #s = :status',
      ExpressionAttributeNames: { '#s': 'status' },
      ExpressionAttributeValues: { ':t': signalAt, ':status': 'SIGNAL_SENT' },
    }));

    await broadcast(wsEndpoint, gameId, {
      action: 'SIGNAL',
      signalAt,
    });

    return { statusCode: 200 };
  }

  return { statusCode: 200 };
};
