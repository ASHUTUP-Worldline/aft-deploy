#!/bin/bash

# Set AWS region and profile if needed
export AWS_REGION="ap-southeast-1"
# export AWS_PROFILE="your-profile"

echo "Starting AFT cleanup process..."

# Function to delete CloudWatch query definitions
# delete_cloudwatch_queries() {
#     echo "Deleting CloudWatch query definitions..."
#     aws logs delete-query-definition --name "Account Factory for Terraform/Customization Logs by Customization Request ID" || true
#     aws logs delete-query-definition --name "Account Factory for Terraform/Customization Logs by Account ID" || true
# }
delete_cloudwatch_queries() {
    echo "Deleting CloudWatch query definitions..."
    
    # List and delete query definitions
    aws logs describe-query-definitions | jq -r '.queryDefinitions[] | select(.name | contains("Account Factory for Terraform")) | .queryDefinitionId' | while read -r query_id; do
        echo "Deleting query definition: $query_id"
        aws logs delete-query-definition --query-definition-id "$query_id" || true
    done
}

# Function to delete IAM roles and policies
delete_iam_roles() {
    echo "Deleting IAM roles..."
    roles=(
        "aft-account-provisioning-framework-lambda-create-role-role"
        "aft-account-provisioning-framework-lambda-tag-account-role"
        "aft-account-provisioning-framework-lambda-persist-metadata-role"
        "aft-states-execution-role"
        "aft-lambda-account-request-audit-trigger"
        "aft-lambda-account-request-action-trigger"
        "aft-lambda-controltower-event-logger"
        "aft-lambda-account-request-processor"
        "aft-lambda-invoke-aft-account-provisioning-framework"
        "aft-lambda-cleanup-resources"
        "aft-aws-backup"
        "ct-aft-codepipeline-account-request-role"
        "ct-aft-codepipeline-account-provisioning-customizations-role"
        "ct-aft-codebuild-account-provisioning-customizations-role"
        "ct-aft-codebuild-account-request-role"
        "aft-codepipeline-customizations-role"
        "aft-codebuild-customizations-role"
        "aft-invoke-customizations-execution-role"
        "aft-identify-targets-execution-role"
        "aft-execute-pipeline-execution-role"
        "aft-get-pipeline-status-execution-role"
        "AWSAFTExecution"
        "AWSAFTService"
    )

    for role in "${roles[@]}"; do
        echo "Deleting role: $role"
        # Delete role policies first
        aws iam list-role-policies --role-name "$role" | jq -r '.PolicyNames[]' | while read policy; do
            aws iam delete-role-policy --role-name "$role" --policy-name "$policy" || true
        done
        # Delete attached policies
        aws iam list-attached-role-policies --role-name "$role" | jq -r '.AttachedPolicies[].PolicyArn' | while read policy; do
            aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" || true
        done
        # Delete role
        aws iam delete-role --role-name "$role" || true
    done
}

# Function to delete DynamoDB tables
delete_dynamodb_tables() {
    echo "Deleting DynamoDB tables..."
    tables=(
        "aft-request-metadata"
        "aft-request"
        "aft-request-audit"
        "aft-controltower-events"
        "aft-backend-658659131265"
    )

    for table in "${tables[@]}"; do
        aws dynamodb delete-table --table-name "$table" || true
    done
}

# Function to delete KMS aliases and keys
delete_kms() {
    echo "Deleting KMS aliases and keys..."
    aliases=(
        "alias/aft"
        "alias/aft-backend-658659131265-kms-key"
    )

    for alias in "${aliases[@]}"; do
        # Schedule key deletion and remove alias
        key_id=$(aws kms list-aliases --query "Aliases[?AliasName=='$alias'].TargetKeyId" --output text)
        if [ ! -z "$key_id" ]; then
            aws kms schedule-key-deletion --key-id "$key_id" --pending-window-in-days 7 || true
            aws kms delete-alias --alias-name "$alias" || true
        fi
    done
}

# Function to delete S3 buckets
delete_s3_buckets() {
    echo "Deleting S3 buckets..."
    buckets=(
        "aft-backend-658659131265-primary-region"
        "aft-backend-658659131265-secondary-region"
        "aft-backend-658659131265-primary-region-access-logs"
        "aws-aft-logs-235279000749-ap-southeast-1"
        "aws-aft-s3-access-logs-235279000749-ap-southeast-1"
    )

    for bucket in "${buckets[@]}"; do
        # Empty bucket first
        aws s3 rm s3://$bucket --recursive || true
        # Delete bucket
        aws s3api delete-bucket --bucket $bucket || true
    done
}

# Function to delete CloudWatch log groups
delete_log_groups() {
    echo "Deleting CloudWatch log groups..."
    aws logs delete-log-group --log-group-name "/aws/lambda/aft-customizations-invoke-account-provisioning" || true
}

# Function to clean up Event Bridge
delete_eventbridge() {
    echo "Deleting EventBridge resources..."
    aws events delete-event-bus --name "aft-events-from-ct-management" || true
}

# Main cleanup sequence
echo "Starting cleanup sequence..."
delete_cloudwatch_queries
delete_iam_roles
delete_dynamodb_tables
delete_kms
delete_s3_buckets
delete_log_groups
delete_eventbridge

echo "Cleanup complete. Wait a few minutes before redeploying resources."

# Optional: Remove local Terraform state
echo "Cleaning local Terraform state..."
rm -rf .terraform
rm -f terraform.tfstate*

echo "Script execution completed."
