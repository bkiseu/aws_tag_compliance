resource "aws_organizations_policy" "tag_compliance_scp" {
  name        = "${var.environment_prefix}-tag-compliance-scp"
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
          # Add more resource creation APIs as needed
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
  target_id = var.tag_compliance_ou_id
}