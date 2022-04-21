data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "archive_file" "inline_lambda_code" {
  output_path = "lambda_code.zip"
  type        = "zip"

  source {
    filename = "index.js"
    content  = <<-EOF
    exports.handler = async (event, context) => {
      try {
        // Log event and context object to CloudWatch Logs
        console.log("Event: ", JSON.stringify(event, null, 2));
        console.log("Context: ", JSON.stringify(context, null, 2));
        return {};
      } catch (error) {
        console.error(error);
        throw new Error(error);
      }
    };
EOF
  }
}