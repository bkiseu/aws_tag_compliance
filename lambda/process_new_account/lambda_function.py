# process-new-account/lambda_function.py
import json
import time
import os
import boto3
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
organizations = boto3.client('organizations')
sns = boto3.client('sns')

def lambda_handler(event, context):
    """
    Handles events for new AWS account creation and moves the account to the Tag Compliance OU.
    """
    logger.info(f"Event: {json.dumps(event)}")
    
    try:
        # Extract account ID from the event
        account_id = None
        if event['detail']['eventName'] == 'CreateAccount':
            create_account_status = event['detail']['responseElements']['createAccountStatus']
            
            # Wait for account creation to complete - it may still be in progress
            account_status = wait_for_account_creation(create_account_status['id'])
            
            if account_status['State'] == 'SUCCEEDED':
                account_id = account_status['AccountId']
            else:
                raise Exception(f"Account creation failed or timed out: {account_status.get('FailureReason', 'Unknown reason')}")
        
        elif event['detail']['eventName'] == 'InviteAccountToOrganization':
            # Handle invited accounts
            account_id = event['detail']['requestParameters']['target']['id']
        
        if not account_id:
            raise Exception("Could not determine account ID from event")
        
        # Move account to Tag Compliance OU
        source_parent_id = os.environ.get('SOURCE_PARENT_ID') or get_organization_root_id()
        organizations.move_account(
            AccountId=account_id,
            SourceParentId=source_parent_id,
            DestinationParentId=os.environ.get('TAG_COMPLIANCE_OU_ID')
        )
        
        # Send notification about the new account
        message = f"""
        A new AWS account ({account_id}) has been created and moved to the Tag Compliance OU.
        
        This account is subject to tag compliance SCPs and will be monitored for proper tagging.
        
        Required tags:
        - Environment (e.g., "dev", "prod")
        - Layer (e.g., "services", "data")
        - Component (e.g., "admin", "api")
        - Product (e.g., "innovation", "core")
        
        Please ensure all resources are properly tagged according to organizational policy.
        """
        
        sns.publish(
            TopicArn=os.environ.get('SNS_TOPIC_ARN'),
            Subject='New AWS Account Added to Tag Compliance OU',
            Message=message
        )
        
        return {
            'statusCode': 200,
            'body': f"Successfully processed new account {account_id}"
        }
    
    except Exception as e:
        logger.error(f"Error processing new account: {str(e)}")
        
        # Send error notification
        sns.publish(
            TopicArn=os.environ.get('SNS_TOPIC_ARN'),
            Subject='Error Processing New AWS Account',
            Message=f"An error occurred while processing a new AWS account: {str(e)}"
        )
        
        raise

def wait_for_account_creation(create_account_request_id):
    """
    Helper function to wait for account creation to complete
    """
    max_attempts = 10
    delay = 5  # 5 seconds
    
    for attempt in range(max_attempts):
        response = organizations.describe_create_account_status(
            CreateAccountRequestId=create_account_request_id
        )
        
        status = response['CreateAccountStatus']
        if status['State'] in ['SUCCEEDED', 'FAILED']:
            return status
        
        # Wait before checking again
        time.sleep(delay)
    
    raise Exception('Timed out waiting for account creation to complete')

def get_organization_root_id():
    """
    Helper function to get organization root ID if source parent not specified
    """
    response = organizations.list_roots()
    return response['Roots'][0]['Id']