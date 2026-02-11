output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "cluster_name" {
  value = module.eks.cluster_name
}
output "region" {
  value = "us-east-1"
}
output "vpc_id" {
  value = module.vpc.vpc_id
}
output "assets_bucket_name" {
  value = aws_s3_bucket.assets.id
}

output "lambda_processor_function_name" {
  description = "The name of the Lambda function processing assets"
  value       = aws_lambda_function.processor.function_name
}

output "lambda_processor_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.processor.arn
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.assets.arn
}

output "iam_user_name" {
  description = "The IAM user created for grading"
  value       = aws_iam_user.dev_view.name
}

output "iam_user_arn" {
  description = "The ARN of the grading user"
  value       = aws_iam_user.dev_view.arn
}

output "cloudwatch_log_group" {
  value = "/aws/lambda/${aws_lambda_function.processor.function_name}"
}
