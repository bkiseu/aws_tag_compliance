# tag-compliance-notification/lambda_function.py
import json
import os
import boto3
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sns = boto3.client('sns')

def lambda_handler(event, context):
    """
    Handles AWS Config rule findings for non-compliant resources and sends notifications
    """
    logger.info(f"Event: {json.dumps(event)}")
    
    try:
        # Parse Config rule finding from the event
        config_event = event['detail']
        account_id = config_event['accountId']
        resource_type = config_event['resourceType']
        resource_id = config_event['resourceId']
        aws_region = config_event['awsRegion']
        compliance_type = config_event['newEvaluationResult']['complianceType']
        
        if compliance_type == 'NON_COMPLIANT':
            # Get resource details to determine which tags are missing
            missing_tags = determine_missing_tags(
                aws_region, 
                resource_type, 
                resource_id,
                ['Environment', 'Layer', 'Component', 'Product']
            )
            
            # Format missing tags for the message
            missing_tags_formatted = '\n'.join([f"- {tag}" for tag in missing_tags])
            
            # Format tag addition CLI command
            cli_tags = ' \\\n            '.join([f"--tags Key={tag},Value=YOUR_VALUE" for tag in missing_tags])
            
            # Send notification about non-compliant resource
            message = f"""
            A non-compliant resource has been detected in AWS account {account_id}:
            
            Resource Type: {resource_type}
            Resource ID: {resource_id}
            Region: {aws_region}
            
            Missing Required Tags:
            {missing_tags_formatted}
            
            Action Required:
            Please add the missing tags to this resource. Until proper tagging is implemented,
            this account is subject to tag compliance SCPs which may restrict certain operations.
            
            To add tags via AWS CLI:
            aws {get_service_from_resource_type(resource_type)} add-tags-to-resource \\
                --resource-name {resource_id} \\
                {cli_tags}
                
            Required tag format:
            - Environment: dev, test, staging, prod
            - Layer: services, data, infrastructure, security
            - Component: admin, api, ui, db
            - Product: innovation, core, platform, customer
            
            For assistance, please contact the Cloud Operations team.
            """
            
            sns.publish(
                TopicArn=os.environ.get('SNS_TOPIC_ARN'),
                Subject=f"Tag Compliance Alert: Non-Compliant Resource Detected in Account {account_id}",
                Message=message
            )
            
            return {
                'statusCode': 200,
                'body': f"Successfully sent notification for non-compliant resource {resource_id}"
            }
        
        elif compliance_type == 'COMPLIANT':
            # Previously non-compliant resource is now compliant - remediation notification
            message = f"""
            A previously non-compliant resource is now properly tagged:
            
            Resource Type: {resource_type}
            Resource ID: {resource_id}
            Region: {aws_region}
            Account ID: {account_id}
            
            All required tags are now present. Thank you for maintaining tag compliance!
            """
            
            sns.publish(
                TopicArn=os.environ.get('SNS_TOPIC_ARN'),
                Subject=f"Tag Compliance Resolved: Resource Now Compliant in Account {account_id}",
                Message=message
            )
            
            return {
                'statusCode': 200,
                'body': f"Successfully sent remediation notification for resource {resource_id}"
            }
        
        return {
            'statusCode': 200,
            'body': 'Event processed, no action required'
        }
    
    except Exception as e:
        logger.error(f"Error processing config rule finding: {str(e)}")
        
        # Send error notification
        sns.publish(
            TopicArn=os.environ.get('SNS_TOPIC_ARN'),
            Subject='Error Processing Tag Compliance Alert',
            Message=f"An error occurred while processing a tag compliance alert: {str(e)}"
        )
        
        raise

def determine_missing_tags(region, resource_type, resource_id, required_tags):
    """
    Helper function to determine which required tags are missing from a resource
    """
    # Implementation would vary based on resource type
    # This is a simplified example
    
    tagging = boto3.client('resourcegroupstaggingapi', region_name=region)
    
    try:
        response = tagging.get_resources(
            ResourceARNList=[convert_to_arn(resource_type, resource_id, region)]
        )
        
        resources = response.get('ResourceTagMappingList', [])
        
        if not resources:
            return required_tags  # All tags are missing
        
        existing_tag_keys = [tag['Key'] for tag in resources[0].get('Tags', [])]
        return [tag_key for tag_key in required_tags if tag_key not in existing_tag_keys]
    
    except Exception as e:
        logger.error(f"Error getting resource tags: {str(e)}")
        return required_tags  # Assume all tags are missing on error

def convert_to_arn(resource_type, resource_id, region):
    """
    Helper function to convert resource type and ID to ARN
    """
    # This is a simplified function - in production you'd need a more comprehensive mapping
    service = get_service_from_resource_type(resource_type)
    account_id = os.environ.get('ACCOUNT_ID', '')
    
    # Different resource types have different ARN formats
    if resource_type == 'AWS::S3::Bucket':
        return f"arn:aws:{service}:::{resource_id}"
    else:
        return f"arn:aws:{service}:{region}:{account_id}:{resource_type.lower().split('::')[-1]}/{resource_id}"

def get_service_from_resource_type(resource_type):
    """
    Helper function to get AWS service from resource type
    """
    # Simplified mapping of resource types to services
    mapping = {
        'AWS::EC2::Instance': 'ec2',
        'AWS::S3::Bucket': 's3',
        'AWS::RDS::DBInstance': 'rds',
        'AWS::DynamoDB::Table': 'dynamodb',
        # Add more mappings as needed
    }
    
    return mapping.get(resource_type) or resource_type.split('::')[1].lower()