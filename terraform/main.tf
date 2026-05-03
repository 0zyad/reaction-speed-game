terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

data "aws_caller_identity" "current" {}

resource "aws_dynamodb_table" "games" {
  name         = "Games"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "gameId"
  attribute { name = "gameId"; type = "S" }
  ttl { attribute_name = "expiresAt"; enabled = true }
}

resource "aws_dynamodb_table" "players" {
  name         = "Players"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "gameId"
  range_key    = "playerId"
  attribute { name = "gameId";   type = "S" }
  attribute { name = "playerId"; type = "S" }
}

resource "aws_dynamodb_table" "results" {
  name         = "Results"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "gameId"
  range_key    = "playerId"
  attribute { name = "gameId";   type = "S" }
  attribute { name = "playerId"; type = "S" }
}

resource "aws_ecr_repository" "game_service"   { name = "reaction-game-service";   image_tag_mutability = "MUTABLE"; force_delete = true }
resource "aws_ecr_repository" "player_service" { name = "reaction-player-service"; image_tag_mutability = "MUTABLE"; force_delete = true }
resource "aws_ecr_repository" "result_service" { name = "reaction-result-service"; image_tag_mutability = "MUTABLE"; force_delete = true }

resource "aws_iam_role" "lambda_role" {
  name = "reaction-game-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole"; Effect = "Allow"; Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "reaction-game-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow"; Action = ["dynamodb:*"]; Resource = ["*"] },
      { Effect = "Allow"; Action = ["execute-api:ManageConnections"]; Resource = ["*"] },
      { Effect = "Allow"; Action = ["logs:*"]; Resource = ["*"] },
      { Effect = "Allow"; Action = ["ecr:GetAuthorizationToken"]; Resource = ["*"] },
      { Effect = "Allow"; Action = ["ecr:GetDownloadUrlForLayer","ecr:BatchGetImage","ecr:BatchCheckLayerAvailability"];
        Resource = [aws_ecr_repository.game_service.arn, aws_ecr_repository.player_service.arn, aws_ecr_repository.result_service.arn] }
    ]
  })
}

resource "aws_apigatewayv2_api" "ws" {
  name                       = "reaction-game-ws"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_lambda_function" "game_service" {
  function_name = "game-service"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.game_service.repository_url}:latest"
  timeout       = 30
  environment { variables = {
    GAMES_TABLE   = aws_dynamodb_table.games.name
    PLAYERS_TABLE = aws_dynamodb_table.players.name
    WS_ENDPOINT   = aws_apigatewayv2_api.ws.api_endpoint
  } }
  depends_on = [aws_ecr_repository.game_service]
}

resource "aws_lambda_function" "player_service" {
  function_name = "player-service"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.player_service.repository_url}:latest"
  timeout       = 30
  environment { variables = {
    PLAYERS_TABLE = aws_dynamodb_table.players.name
    GAMES_TABLE   = aws_dynamodb_table.games.name
    WS_ENDPOINT   = aws_apigatewayv2_api.ws.api_endpoint
  } }
  depends_on = [aws_ecr_repository.player_service]
}

resource "aws_lambda_function" "result_service" {
  function_name = "result-service"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.result_service.repository_url}:latest"
  timeout       = 30
  environment { variables = {
    PLAYERS_TABLE = aws_dynamodb_table.players.name
    RESULTS_TABLE = aws_dynamodb_table.results.name
    WS_ENDPOINT   = aws_apigatewayv2_api.ws.api_endpoint
  } }
  depends_on = [aws_ecr_repository.result_service]
}

resource "aws_apigatewayv2_integration" "game_int"   { api_id = aws_apigatewayv2_api.ws.id; integration_type = "AWS_PROXY"; integration_uri = aws_lambda_function.game_service.invoke_arn }
resource "aws_apigatewayv2_integration" "player_int" { api_id = aws_apigatewayv2_api.ws.id; integration_type = "AWS_PROXY"; integration_uri = aws_lambda_function.player_service.invoke_arn }
resource "aws_apigatewayv2_integration" "result_int" { api_id = aws_apigatewayv2_api.ws.id; integration_type = "AWS_PROXY"; integration_uri = aws_lambda_function.result_service.invoke_arn }

resource "aws_apigatewayv2_route" "connect"         { api_id = aws_apigatewayv2_api.ws.id; route_key = "$connect";       target = "integrations/${aws_apigatewayv2_integration.player_int.id}" }
resource "aws_apigatewayv2_route" "disconnect"      { api_id = aws_apigatewayv2_api.ws.id; route_key = "$disconnect";    target = "integrations/${aws_apigatewayv2_integration.player_int.id}" }
resource "aws_apigatewayv2_route" "create_game"     { api_id = aws_apigatewayv2_api.ws.id; route_key = "createGame";     target = "integrations/${aws_apigatewayv2_integration.game_int.id}" }
resource "aws_apigatewayv2_route" "join_game"       { api_id = aws_apigatewayv2_api.ws.id; route_key = "joinGame";       target = "integrations/${aws_apigatewayv2_integration.player_int.id}" }
resource "aws_apigatewayv2_route" "start_game"      { api_id = aws_apigatewayv2_api.ws.id; route_key = "startGame";      target = "integrations/${aws_apigatewayv2_integration.game_int.id}" }
resource "aws_apigatewayv2_route" "submit_reaction" { api_id = aws_apigatewayv2_api.ws.id; route_key = "submitReaction"; target = "integrations/${aws_apigatewayv2_integration.player_int.id}" }

resource "aws_apigatewayv2_stage" "prod" { api_id = aws_apigatewayv2_api.ws.id; name = "prod"; auto_deploy = true }

resource "aws_lambda_permission" "game_perm"   { action = "lambda:InvokeFunction"; function_name = aws_lambda_function.game_service.function_name;   principal = "apigateway.amazonaws.com"; source_arn = "${aws_apigatewayv2_api.ws.execution_arn}/*/*" }
resource "aws_lambda_permission" "player_perm" { action = "lambda:InvokeFunction"; function_name = aws_lambda_function.player_service.function_name; principal = "apigateway.amazonaws.com"; source_arn = "${aws_apigatewayv2_api.ws.execution_arn}/*/*" }
resource "aws_lambda_permission" "result_perm" { action = "lambda:InvokeFunction"; function_name = aws_lambda_function.result_service.function_name;  principal = "apigateway.amazonaws.com"; source_arn = "${aws_apigatewayv2_api.ws.execution_arn}/*/*" }

resource "aws_s3_bucket" "frontend" { bucket = "reaction-speed-game-frontend"; force_destroy = true }

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  block_public_acls = false; block_public_policy = false
  ignore_public_acls = false; restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Sid = "PublicRead"; Effect = "Allow"; Principal = "*"; Action = "s3:GetObject"; Resource = "${aws_s3_bucket.frontend.arn}/*" }]
  })
}

output "websocket_url" { value = aws_apigatewayv2_stage.prod.invoke_url }
output "frontend_url"  { value = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}" }
