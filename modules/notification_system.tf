
resource "aws_cloudwatch_event_rule" "new_account_created" {
  name        = "${var.environment_prefix}-new-account-creation"
  description = "Capture when a new AWS account is created"

  event_pattern = jsonencode({
    source      = ["aws.organizations"],
    detail-type = ["AWS API Call via CloudTrail"],
    detail = {
      eventName = ["CreateAccount", "InviteAccountToOrganization"]
    }
  })
}

resource "aws_cloudwatch_event_target" "process_new_account" {
  rule      = aws_cloudwatch_event_rule.new_account_created.name
  arn       = var.lambda_process_new_account_arn
}
