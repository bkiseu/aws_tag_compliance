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
