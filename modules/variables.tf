variable "environment_prefix" {
  description = "Prefix to add to resource names for different environments"
  type        = string
}

variable "tag_compliance_ou_id" {
  description = "ID of the Tag Compliance OU"
  type        = string
}

variable "required_tags" {
  description = "List of required tags to enforce"
  type        = list(string)
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  type        = string
}

variable "notification_emails" {
  description = "List of email addresses to notify for compliance issues"
  type        = list(string)
}

variable "lambda_compliance_notification_arn" {
  description = "ARN of the Lambda function for tag compliance notifications"
  type        = string
}

variable "lambda_process_new_account_arn" {
  description = "ARN of the Lambda function for processing new accounts"
  type        = string
}
