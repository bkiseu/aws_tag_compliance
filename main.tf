provider "aws" {
  region = var.aws_region
}

# For getting the current account ID
data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "existing_org" {}

# Create Tag Compliance OU
resource "aws_organizations_organizational_unit" "tag_compliance_ou" {
  name      = var.tag_compliance_ou_name
  parent_id = var.organization_root_id
}

###########################################
# AWS Config Setup - Required for Config Rules
###########################################

# Create AWS Config role
resource "aws_iam_role" "config_role" {
  name = "aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach required policies to the AWS Config role
resource "aws_iam_role_policy_attachment" "config_policy_attachment" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Create S3 bucket for AWS Config recordings
resource "aws_s3_bucket" "config_bucket" {
  bucket_prefix = "aws-config-bucket-"
  force_destroy = true
}

# S3 bucket policy for Config
resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowConfigBucketAccess"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.config_bucket.arn
      },
      {
        Sid    = "AllowConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.config_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Create AWS Config configuration recorder
resource "aws_config_configuration_recorder" "config_recorder" {
  name     = "aws-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# Create AWS Config delivery channel
resource "aws_config_delivery_channel" "config_delivery_channel" {
  name           = "aws-config-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket

  depends_on = [aws_config_configuration_recorder.config_recorder]
}

# Start the AWS Config recorder
resource "aws_config_configuration_recorder_status" "config_recorder_status" {
  name       = aws_config_configuration_recorder.config_recorder.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.config_delivery_channel]
}

###########################################
# Tag Compliance SCP
###########################################

# Create Tag Compliance SCP
resource "aws_organizations_policy" "tag_compliance_scp" {
  name        = "tag-compliance-scp"
  description = "Enforces mandatory tagging for resources"
  
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTaggingOnResources"
        Effect    = "Deny"
        Action    = [
          "ec2:RunInstances",
          "ec2:CreateVolume",
          "s3:CreateBucket",
          "rds:CreateDBInstance",
          "dynamodb:CreateTable"
        ]
        Resource  = "*"
        Condition = {
          Null = {
            for tag in var.required_tags : "aws:RequestTag/${tag}" => "true"
          }
        }
      }
    ]
  })

}

resource "aws_organizations_policy_attachment" "attach_to_tag_compliance_ou" {
  policy_id = aws_organizations_policy.tag_compliance_scp.id
  target_id = aws_organizations_organizational_unit.tag_compliance_ou.id

  depends_on = [aws_organizations_policy.tag_compliance_scp]
}

###########################################
# AWS Config Rule for Tag Monitoring
###########################################

# Set up AWS Config rule for tag monitoring
resource "aws_config_config_rule" "required_tags_rule" {
  name        = "required-tags"
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

  depends_on = [aws_config_configuration_recorder_status.config_recorder_status]
}

###########################################
# Notification System
###########################################

# Create SNS topic for notifications
resource "aws_sns_topic" "tag_compliance_notifications" {
  name = "tag-compliance-notifications"
}

# Create email subscriptions
resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.tag_compliance_notifications.arn
  protocol  = "email"
  endpoint  = each.value
}

###########################################
# Lambda Functions for Automation
###########################################

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "tag-compliance-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  role = aws_iam_role.lambda_role.id
  name = "tag-compliance-permissions"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "organizations:DescribeCreateAccountStatus",
          "organizations:ListRoots",
          "organizations:MoveAccount",
          "sns:Publish",
          "config:GetResourceConfigHistory",
          "resourcegroupstaggingapi:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create ZIP file for process_new_account Lambda
data "archive_file" "process_new_account_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/process_new_account/lambda_function.py"
  output_path = "${path.module}/build/process_new_account.zip"
}

# Create ZIP file for tag_compliance_notification Lambda
data "archive_file" "tag_compliance_notification_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/tag_compliance_notification/lambda_function.py"
  output_path = "${path.module}/build/tag_compliance_notification.zip"
}

# Create Lambda for processing new accounts
resource "aws_lambda_function" "process_new_account" {
  function_name    = "process-new-account"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  
  filename         = data.archive_file.process_new_account_zip.output_path
  source_code_hash = data.archive_file.process_new_account_zip.output_base64sha256

  environment {
    variables = {
      TAG_COMPLIANCE_OU_ID = aws_organizations_organizational_unit.tag_compliance_ou.id,
      SNS_TOPIC_ARN        = aws_sns_topic.tag_compliance_notifications.arn
      ACCOUNT_ID       = data.aws_caller_identity.current.account_id,
      SES_SENDER_EMAIL = var.ses_sender_email
      SES_SENDER_NAME  = var.ses_sender_name
    }
  }
}

# Create Lambda for tag compliance notifications
resource "aws_lambda_function" "tag_compliance_notification" {
  function_name    = "tag-compliance-notification"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  
  filename         = data.archive_file.tag_compliance_notification_zip.output_path
  source_code_hash = data.archive_file.tag_compliance_notification_zip.output_base64sha256
  
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.tag_compliance_notifications.arn,
      ACCOUNT_ID    = data.aws_caller_identity.current.account_id
    }
  }
}

###########################################
# EventBridge Rules
###########################################

# EventBridge rule for new account creation
resource "aws_cloudwatch_event_rule" "new_account_created" {
  name        = "capture-new-account-creation"
  description = "Capture when a new AWS account is created"

  event_pattern = jsonencode({
    source      = ["aws.organizations", "custom.organizations"],
    detail-type = ["AWS API Call via CloudTrail"],
    detail = {
      eventSource = ["organizations.amazonaws.com"],
      eventName = ["CreateAccount", "InviteAccountToOrganization"]
    }
  })
}

resource "aws_cloudwatch_event_target" "process_new_account" {
  rule      = aws_cloudwatch_event_rule.new_account_created.name
  arn       = aws_lambda_function.process_new_account.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_new_account" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_new_account.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.new_account_created.arn
}

# EventBridge rule for AWS Config findings
resource "aws_cloudwatch_event_rule" "config_compliance_status_change" {
  name        = "capture-config-compliance-changes"
  description = "Capture when a resource changes compliance status"

  event_pattern = jsonencode({
    source      = ["aws.config"],
    detail-type = ["Config Rules Compliance Change"],
    detail = {
      configRuleName = ["required-tags"]
    }
  })
}

resource "aws_cloudwatch_event_target" "tag_compliance_notification" {
  rule      = aws_cloudwatch_event_rule.config_compliance_status_change.name
  arn       = aws_lambda_function.tag_compliance_notification.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_config" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tag_compliance_notification.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_compliance_status_change.arn
}