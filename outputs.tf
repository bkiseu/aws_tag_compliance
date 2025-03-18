output "tag_compliance_ou_id" {
  description = "ID of the Tag Compliance OU"
  value       = aws_organizations_organizational_unit.tag_compliance_ou.id
}

output "tag_compliance_scp_id" {
  description = "ID of the Tag Compliance Service Control Policy"
  value       = aws_organizations_policy.tag_compliance_scp.id
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for tag compliance notifications"
  value       = aws_sns_topic.tag_compliance_notifications.arn
}

output "config_bucket_name" {
  description = "Name of the S3 bucket used for AWS Config recordings"
  value       = aws_s3_bucket.config_bucket.bucket
}

output "process_new_account_lambda_arn" {
  description = "ARN of the Lambda function that processes new accounts"
  value       = aws_lambda_function.process_new_account.arn
}

output "tag_compliance_notification_lambda_arn" {
  description = "ARN of the Lambda function that handles tag compliance notifications"
  value       = aws_lambda_function.tag_compliance_notification.arn
}