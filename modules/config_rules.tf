resource "aws_config_config_rule" "required_tags_rule" {
  name        = "${var.environment_prefix}-required-tags"
  description = "Checks for required tags on resources"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    for i, tag in var.required_tags : "tag${i+1}Key" => tag
  })

  scope {
    compliance_resource_types = [
      "AWS::EC2::Instance",
      "AWS::EC2::Volume",
      "AWS::S3::Bucket",
      "AWS::RDS::DBInstance",
      "AWS::DynamoDB::Table"
    ]
  }
}

resource "aws_cloudwatch_event_rule" "config_compliance_status_change" {
  name        = "${var.environment_prefix}-config-compliance-changes"
  description = "Capture when a resource changes compliance status"

  event_pattern = jsonencode({
    source      = ["aws.config"],
    detail-type = ["Config Rules Compliance Change"],
    detail = {
      configRuleName = ["${var.environment_prefix}-required-tags"]
    }
  })
}

resource "aws_cloudwatch_event_target" "tag_compliance_notification" {
  rule      = aws_cloudwatch_event_rule.config_compliance_status_change.name
  arn       = var.lambda_compliance_notification_arn
}