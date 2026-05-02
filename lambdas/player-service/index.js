const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');

const dynamo = DynamoDBDocumentClient.from(new DynamoDBClient({}));

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
    console.log('Connection failed:', connectionId);
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

  if (routeKey === '$connect') {
    console.log('New connection:', connectionId);
    return { statusCode: 200 };
  }

  if (routeKey === '$disconnect') {
    console.log('Disconnected:', connectionId);
    return { statusCode: 200 };
  }

  if (routeKey === 'joinGame') {
    const { gameId, playerName } = body;
    const playerId = connectionId;

    await dynamo.send(new PutCommand({
      TableName: process.env.PLAYERS_TABLE,
      Item: {
        gameId,
        playerId,
        playerName,
        connectionId,
        joinedAt: Date.now(),
        reactionMs: null,
      }
    }));

    const result = await dynamo.send(new QueryCommand({
      TableName: process.env.PLAYERS_TABLE,
      KeyConditionExpression: 'gameId = :gid',
      ExpressionAttributeValues: { ':gid': gameId },
    }));
    const allPlayers = result.Items.map(p => p.playerName);

    await broadcast(wsEndpoint, gameId, {
      action: 'playerJoined',
      playerName,
      players: allPlayers,
    });

    return { statusCode: 200 };
  }

  if (routeKey === 'submitReaction') {
    const { gameId, clickedAt } = body;
    const playerId = connectionId;

    const gameResult = await dynamo.send(new GetCommand({
      TableName: process.env.GAMES_TABLE,
      Key: { gameId },
    }));

    if (!gameResult.Item || !gameResult.Item.signalAt) {
      return { statusCode: 400 };
    }

    const reactionMs = clickedAt - gameResult.Item.signalAt;

    await dynamo.send(new UpdateCommand({
      TableName: process.env.PLAYERS_TABLE,
      Key: { gameId, playerId },
      UpdateExpression: 'SET reactionMs = :ms',
      ExpressionAttributeValues: { ':ms': reactionMs },
    }));

    await sendToConnection(wsEndpoint, connectionId, {
      action: 'reactionRecorded',
      reactionMs,
    });

    const playersResult = await dynamo.send(new QueryCommand({
      TableName: process.env.PLAYERS_TABLE,
      KeyConditionExpression: 'gameId = :gid',
      ExpressionAttributeValues: { ':gid': gameId },
    }));

    const allPlayers = playersResult.Items || [];
    const allDone = allPlayers.every(p => p.reactionMs !== null && p.reactionMs !== undefined);

    if (allDone) {
      const sorted = allPlayers
        .sort((a, b) => a.reactionMs - b.reactionMs)
        .map((p, i) => ({
          rank: i + 1,
          name: p.playerName,
          ms: p.reactionMs,
          medal: i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : '',
        }));

      await broadcast(wsEndpoint, gameId, {
        action: 'RESULTS',
        rankings: sorted,
      });
    }

    return { statusCode: 200 };
  }

  return { statusCode: 200 };
};
