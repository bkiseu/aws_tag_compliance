# AWS Tag Compliance Solution

A Terraform-based solution to enforce and monitor tag compliance across an AWS Organization.

## Overview

This solution helps organizations enforce tagging standards by:

1. Creating a dedicated Tag Compliance OU within AWS Organizations
2. Implementing Service Control Policies (SCPs) to enforce tagging at resource creation
3. Deploying AWS Config rules to monitor ongoing tag compliance
4. Setting up automated notifications for non-compliant resources
5. Creating a system to automatically place new accounts in the Tag Compliance OU

## Architecture

![Architecture Diagram](architecture-diagram.png)

The solution consists of the following components:

- **Tag Compliance OU**: A dedicated Organizational Unit where new accounts are placed
- **Tag Compliance SCP**: A Service Control Policy that prevents creation of untagged resources
- **AWS Config Rule**: Monitors resources for proper tagging
- **SNS Notifications**: Alerts for non-compliant resources and remediation actions
- **Lambda Functions**: Process new accounts and tag compliance events

## Required Tags

By default, this solution enforces the following tags:

- `Environment` (e.g., "dev", "prod")
- `Layer` (e.g., "services", "data")
- `Component` (e.g., "admin", "api")
- `Product` (e.g., "innovation", "core")

## Prerequisites

- AWS Organizations must be enabled
- The AWS account used for deployment must have Organization management permissions
- AWS Config must be enabled in all member accounts where you want to monitor tag compliance
- Terraform 1.0.0 or newer

## Installation

1. Clone this repository
2. Configure the `terraform.tfvars` file with your specific values:

```bash
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

3. Build the Lambda packages:

```bash
./scripts/build.sh
```

4. Deploy the solution:

```bash
terraform init
terraform plan
terraform apply
```

## Configuration

Edit the `terraform.tfvars` file to customize:

- AWS region for control plane resources
- Organization root ID
- Tag Compliance OU name
- Required tags list
- Notification email addresses

## Usage

### Adding a New AWS Account

When a new AWS account is created or invited to the organization, it will automatically:

1. Be moved to the Tag Compliance OU
2. Inherit the tag compliance SCP
3. Trigger an SNS notification to the configured email addresses

### Tag Compliance Monitoring

The solution monitors resources for the required tags and:

1. Identifies non-compliant resources via AWS Config
2. Sends detailed notifications with remediation instructions
3. Sends confirmation when resources are remediated

### Fixing Non-Compliant Resources

When you receive a non-compliance notification:

1. Add the missing tags to the resource
2. Use the AWS CLI commands provided in the notification
3. Receive a confirmation email once the resource is compliant

## Customization

### Adding Additional Resource Types

Edit the `aws_config_config_rule` resource in `main.tf` to add more resource types to the monitoring scope:

```hcl
scope {
  compliance_resource_types = [
    "AWS::EC2::Instance",
    "AWS::EC2::Volume",
    "AWS::S3::Bucket",
    "AWS::RDS::DBInstance",
    "AWS::DynamoDB::Table",
    # Add more resource types here
  ]
}
```

### Modifying the SCP

Edit the `aws_organizations_policy` resource in `main.tf` to change which actions require tags:

```hcl
Action = [
  "ec2:RunInstances",
  "ec2:CreateVolume",
  "s3:CreateBucket",
  "rds:CreateDBInstance",
  "dynamodb:CreateTable",
  # Add more actions here
]
```

## Troubleshooting

### Common Issues

1. **SCP not applying to resources**: Ensure the account is in the Tag Compliance OU and CloudTrail is enabled.

2. **AWS Config rule not evaluating resources**: Verify AWS Config is properly configured in the member accounts.

3. **Notifications not being received**: Check the SNS subscription confirmation was accepted.

### Logs

Check the CloudWatch Logs for the Lambda functions:

- `/aws/lambda/process-new-account`
- `/aws/lambda/tag-compliance-notification`

## Security Considerations

The Lambda functions are deployed with least-privilege permissions. The IAM role only includes the necessary permissions to:

- Read and move accounts within the organization
- Publish to the SNS topic
- Access AWS Config resource configuration
- Query resource tags


## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
