variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "organization_root_id" {
  description = "The ID of the root of the AWS Organization"
  type        = string
}

variable "tag_compliance_ou_name" {
  description = "Name of the Tag Compliance OU"
  type        = string
  default     = "TagCompliance"
}

variable "required_tags" {
  description = "List of required tags to enforce"
  type        = list(string)
  default     = ["Environment", "Layer", "Component", "Product"]
}

variable "notification_emails" {
  description = "List of email addresses to notify for compliance issues"
  type        = list(string)
  default     = []
}

variable "ses_sender_email" {
  description = "Email address to use as the sender for SES emails to resource owners"
  type        = string
}
variable "ses_sender_name" {
  description = "Name to use as the sender for SES emails to resource owners"
  type        = string
  default     = "AWS Tag Compliance"
}
