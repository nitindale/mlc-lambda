provider "aws" {
  region = "ap-southeast-2"
}

resource "random_id" "bucket_id" {
  byte_length = 8
}

resource "aws_s3_bucket" "weather_data" {
  bucket = "weather-data-bucket-${random_id.bucket_id.hex}"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_weather_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_lambda_function" "fetch_weather" {
  function_name    = "fetch_weather_data"
  handler          = "fetchWeatherData.handler"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_role.arn
  filename         = "${path.module}/dist/fetchWeatherData.zip"
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.weather_data.bucket
      OPENWEATHER_API_KEY = "UPDATE_YOUR_KEYS"
    }
  }
}

resource "aws_lambda_function" "get_historical_weather" {
  function_name    = "get_historical_weather"
  handler          = "getHistoricalData.handler"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_role.arn
  filename         = "${path.module}/dist/getHistoricalData.zip"
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.weather_data.bucket
    }
  }
}

resource "aws_api_gateway_rest_api" "weather_api" {
  name = "weather_api"
}

# Create a resource (e.g., /weather) in the API
resource "aws_api_gateway_resource" "fetch_weather" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  parent_id   = aws_api_gateway_rest_api.weather_api.root_resource_id
  path_part   = "weather"
}

# Add a new resource: /weather/history
resource "aws_api_gateway_resource" "weather_history" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  # parent_id   = aws_api_gateway_rest_api.weather_api.root_resource_id
  parent_id   = aws_api_gateway_resource.fetch_weather.id
  path_part   = "history"
}

# Add a new resource for the {city} path parameter
resource "aws_api_gateway_resource" "weather_history_city" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  parent_id   = aws_api_gateway_resource.weather_history.id
  path_part   = "{city}"
}

# Add a new resource for the {city} path parameter
resource "aws_api_gateway_resource" "weather_city" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  parent_id   = aws_api_gateway_resource.fetch_weather.id
  path_part   = "{city}"
}

# API Gateway Method for the Weather Resource (GET)
resource "aws_api_gateway_method" "fetch_weather_method" {
  rest_api_id   = aws_api_gateway_rest_api.weather_api.id
  resource_id   = aws_api_gateway_resource.weather_city.id
  http_method   = "GET"
  authorization = "NONE"
}

# Define the GET method for /weather/history/{city}
resource "aws_api_gateway_method" "get_weather_history" {
  rest_api_id   = aws_api_gateway_rest_api.weather_api.id
  resource_id   = aws_api_gateway_resource.weather_history_city.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "fetch_weather_integration" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  resource_id = aws_api_gateway_resource.weather_city.id
  http_method = aws_api_gateway_method.fetch_weather_method.http_method  # Correct method reference
  integration_http_method = "POST"  # Assuming the backend integration is a POST request
  type                  = "AWS_PROXY"
  uri                   = aws_lambda_function.fetch_weather.invoke_arn  # Lambda ARN
}

# Integrate the GET method with the Lambda function
resource "aws_api_gateway_integration" "get_weather_history_integration" {
  rest_api_id             = aws_api_gateway_rest_api.weather_api.id
  resource_id             = aws_api_gateway_resource.weather_history_city.id
  http_method             = aws_api_gateway_method.get_weather_history.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_historical_weather.invoke_arn
}

resource "aws_api_gateway_method_response" "fetch_weather_method_response" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  resource_id = aws_api_gateway_resource.weather_city.id
  http_method = aws_api_gateway_method.fetch_weather_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Define the integration response separately
resource "aws_api_gateway_integration_response" "fetch_weather_response" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  resource_id = aws_api_gateway_resource.weather_city.id
  http_method = aws_api_gateway_method.fetch_weather_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_deployment" "weather_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  depends_on = [
    aws_api_gateway_integration.fetch_weather_integration,
    aws_api_gateway_method.get_weather_history,
    aws_api_gateway_integration.get_weather_history_integration,
  ]
}

# Grant API Gateway permissions to invoke Lambda
resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  # function_name = aws_lambda_function.fetch_weather.function_name
  function_name = aws_lambda_function.fetch_weather.arn
  source_arn    = "${aws_api_gateway_rest_api.weather_api.execution_arn}/*"
}

resource "aws_lambda_permission" "allow_api_gateway_historical" {
  statement_id  = "AllowAPIGatewayInvokeHistorical"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_historical_weather.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.weather_api.execution_arn}/*"
}
