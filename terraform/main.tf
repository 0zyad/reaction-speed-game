terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "games" {
  name         = "Games"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "gameId"
  attribute { name = "gameId" type = "S" }
  ttl { attribute_name = "expiresAt" enabled = true }
}

resource "aws_dynamodb_table" "players" {
  name         = "Players"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "gameId"
  range_key    = "playerId"
  attribute { name = "gameId" type = "S" }
  attribute { name = "playerId" type = "S" }
}

resource "aws_dynamodb_table" "results" {
  name         = "Results"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "gameId"
  range_key    = "playerId"
  attribute { name = "gameId" type = "S" }
  attribute { name = "playerId" type = "S" }
}

resource "aws_iam_role" "lambda_role" {
  name = "reaction-game-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "reaction-game-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:*"], Resource = ["*"] },
      { Effect = "Allow", Action = ["execute-api:ManageConnections"], Resource = ["*"] },
      { Effect = "Allow", Action = ["logs:*"], Resource = ["*"] }
    ]
  })
}

data "archive_file" "game_zip" {
  type        = "zip"
  source_dir  = "../lambdas/game-service"
  output_path = "../lambdas/game-service.zip"
}

data "archive_file" "player_zip" {
  type        = "zip"
  source_dir  = "../lambdas/player-service"
  output_path = "../lambdas/player-service.zip"
}

data "archive_file" "result_zip" {
  type        = "zip"
  source_dir  = "../lambdas/result-service"
  output_path = "../lambdas/result-service.zip"
}

resource "aws_apigatewayv2_api" "ws" {
  name                       = "reaction-game-ws"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_lambda_function" "game_service" {
  filename         = "../lambdas/game-service.zip"
  function_name    = "game-service"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.game_zip.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      GAMES_TABLE   = "Games"
      PLAYERS_TABLE = "Players"
      WS_ENDPOINT   = aws_apigatewayv2_api.ws.api_endpoint
    }
  }
}

resource "aws_lambda_function" "player_service" {
  filename         = "../lambdas/player-service.zip"
  function_name    = "player-service"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.player_zip.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      PLAYERS_TABLE = "Players"
      GAMES_TABLE   = "Games"
      WS_ENDPOINT   = aws_apigatewayv2_api.ws.api_endpoint
    }
  }
}

resource "aws_lambda_function" "result_service" {
  filename         = "../lambdas/result-service.zip"
  function_name    = "result-service"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.result_zip.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      PLAYERS_TABLE = "Players"
      RESULTS_TABLE = "Results"
      WS_ENDPOINT   = aws_apigatewayv2_api.ws.api_endpoint
    }
  }
}

resource "aws_apigatewayv2_integration" "game_int" {
  api_id           = aws_apigatewayv2_api.ws.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.game_service.invoke_arn
}

resource "aws_apigatewayv2_integration" "player_int" {
  api_id           = aws_apigatewayv2_api.ws.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.player_service.invoke_arn
}

resource "aws_apigatewayv2_integration" "result_int" {
  api_id           = aws_apigatewayv2_api.ws.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.result_service.invoke_arn
}

resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.ws.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.player_int.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.ws.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.player_int.id}"
}

resource "aws_apigatewayv2_route" "create_game" {
  api_id    = aws_apigatewayv2_api.ws.id
  route_key = "createGame"
  target    = "integrations/${aws_apigatewayv2_integration.game_int.id}"
}

resource "aws_apigatewayv2_route" "join_game" {
  api_id    = aws_apigatewayv2_api.ws.id
  route_key = "joinGame"
  target    = "integrations/${aws_apigatewayv2_integration.player_int.id}"
}

resource "aws_apigatewayv2_route" "start_game" {
  api_id    = aws_apigatewayv2_api.ws.id
  route_key = "startGame"
  target    = "integrations/${aws_apigatewayv2_integration.game_int.id}"
}

resource "aws_apigatewayv2_route" "submit_reaction" {
  api_id    = aws_apigatewayv2_api.ws.id
  route_key = "submitReaction"
  target    = "integrations/${aws_apigatewayv2_integration.player_int.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.ws.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_lambda_permission" "game_perm" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.game_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws.execution_arn}/*/*"
}

resource "aws_lambda_permission" "player_perm" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.player_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws.execution_arn}/*/*"
}

resource "aws_lambda_permission" "result_perm" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.result_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws.execution_arn}/*/*"
}

output "websocket_url" {
  value       = aws_apigatewayv2_stage.prod.invoke_url
  description = "Share this URL with Person 2 and Person 3!"
}
