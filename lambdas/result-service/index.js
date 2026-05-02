const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand, PutCommand } = require('@aws-sdk/lib-dynamodb');

const dynamo = DynamoDBDocumentClient.from(new DynamoDBClient({}));

exports.handler = async (event) => {
  const gameId = event.queryStringParameters?.gameId
               || (event.body ? JSON.parse(event.body).gameId : null);

  if (!gameId) {
    return {
      statusCode: 400,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'gameId required' }),
    };
  }

  const result = await dynamo.send(new QueryCommand({
    TableName: process.env.PLAYERS_TABLE,
    KeyConditionExpression: 'gameId = :gid',
    ExpressionAttributeValues: { ':gid': gameId },
  }));

  const players = result.Items || [];

  const rankings = players
    .filter(p => p.reactionMs !== null && p.reactionMs !== undefined)
    .sort((a, b) => a.reactionMs - b.reactionMs)
    .map((p, index) => ({
      rank: index + 1,
      name: p.playerName,
      ms: p.reactionMs,
      medal: index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : '',
    }));

  await Promise.all(rankings.map(r =>
    dynamo.send(new PutCommand({
      TableName: process.env.RESULTS_TABLE,
      Item: { gameId, playerId: r.name, rank: r.rank, reactionMs: r.ms }
    }))
  ));

  return {
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ gameId, rankings }),
  };
};
