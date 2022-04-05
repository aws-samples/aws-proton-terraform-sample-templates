#module "api_gateway" {
#  source = "terraform-aws-modules/apigateway-v2/aws"
#  name = var.service_instance.name
#
#  domain_name = "test"
#
#
#  cors_configuration = {
#    allow_methods = ["*"]
#    allow_origins = ["*"]
#  }
#
#}


resource "aws_apigatewayv2_api" "example" {
  name          = "example-http-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "POST",
    ]
  }

  target = aws_lambda_function.lambda_function.arn
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "${var.service_instance.name}-function"
  runtime       = var.service_instance.inputs.lambda_runtime
  role          = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      SNStopic = var.environment.outputs.SNSTopicName
    }
  }

  handler   = contains(keys(var.service_instance.inputs), "code_uri") ? var.service_instance.inputs.lambda_handler : "index.handler"
  s3_bucket = contains(keys(var.service_instance.inputs), "code_uri") ? var.service_instance.inputs.lambda_bucket : null
  s3_key    = contains(keys(var.service_instance.inputs), "code_uri") ? var.service_instance.inputs.lambda_key : null
  filename  = contains(keys(var.service_instance.inputs), "code_uri") ? null : data.archive_file.lambda_zip_inline.output_path
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_zip_inline" {
  type        = "zip"
  output_path = "/tmp/lambda_zip_inline.zip"
  source {
    filename = "lambda_zip_inline.zip"
    content  = <<EOF
        exports.handler = async (event, context) => {
          try {
            // Log event and context object to CloudWatch Logs
            console.log("Event: ", JSON.stringify(event, null, 2));
            console.log("Context: ", JSON.stringify(context, null, 2));
            // Create event object to return to caller
            const eventObj = {
              functionName: context.functionName,
              method: event.requestContext.http.method,
              rawPath: event.rawPath,
            };
            const response = {
              statusCode: 200,
              body: JSON.stringify(eventObj, null, 2),
            };
            return response;
          } catch (error) {
            console.error(error);
            throw new Error(error);
          }
        };
EOF
  }
}