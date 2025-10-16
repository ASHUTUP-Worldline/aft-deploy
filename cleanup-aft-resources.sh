#!/bin/bash
# WARNING: This script will DELETE all AFT resources
# Use with extreme caution

set -e

REGION="ap-southeast-1"
AFT_MGMT_ACCOUNT="658659131265"
LOG_ARCHIVE_ACCOUNT="235279000749"

echo "⚠️  WARNING: This will delete all AFT resources!"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# Delete CloudWatch Query Definitions
echo "Deleting CloudWatch Query Definitions..."
aws logs delete-query-definition --query-definition-id $(aws logs describe-query-definitions --region $REGION --query 'queryDefinitions[?name==`Account Factory for Terraform/Customization Logs by Customization Request ID`].queryDefinitionId' --output text) --region $REGION 2>/dev/null || true
aws logs delete-query-definition --query-definition-id $(aws logs describe-query-definitions --region $REGION --query 'queryDefinitions[?name==`Account Factory for Terraform/Customization Logs by Account ID`].queryDefinitionId' --output text) --region $REGION 2>/dev/null || true

# Delete SSM Parameters
echo "Deleting SSM Parameters..."
aws ssm delete-parameters --names $(aws ssm describe-parameters --region $REGION --query 'Parameters[?starts_with(Name, `/aft/`)].Name' --output text) --region $REGION 2>/dev/null || true

# Delete IAM Roles (in AFT Management Account)
echo "Deleting IAM Roles..."
ROLES=(
  "aft-account-provisioning-framework-lambda-create-role-role"
  "aft-account-provisioning-framework-lambda-tag-account-role"
  "aft-account-provisioning-framework-lambda-persist-metadata-role"
  "aft-states-execution-role"
  "aft-control-tower-events-rule"
  "aft-lambda-account-request-audit-trigger"
  "aft-lambda-account-request-action-trigger"
  "aft-lambda-controltower-event-logger"
  "aft-lambda-account-request-processor"
  "aft-lambda-invoke-aft-account-provisioning-framework"
  "aft-lambda-cleanup-resources"
  "aft-aws-backup"
  "aft-s3-terraform-backend-replication"
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
  "aft-delete-default-vpc-execution-role"
  "aft-enroll-support-execution-role"
  "aft-enable-cloudtrail-execution-role"
  "AWSAFTAdmin"
  "codebuild_trigger_role"
)

for role in "${ROLES[@]}"; do
  echo "Deleting role: $role"
  # Detach policies
  aws iam list-attached-role-policies --role-name $role --region $REGION 2>/dev/null | jq -r '.AttachedPolicies[].PolicyArn' | while read policy; do
    aws iam detach-role-policy --role-name $role --policy-arn $policy --region $REGION 2>/dev/null || true
  done
  # Delete inline policies
  aws iam list-role-policies --role-name $role --region $REGION 2>/dev/null | jq -r '.PolicyNames[]' | while read policy; do
    aws iam delete-role-policy --role-name $role --policy-name $policy --region $REGION 2>/dev/null || true
  done
  # Delete role
  aws iam delete-role --role-name $role --region $REGION 2>/dev/null || true
done

# Delete EventBridge Event Bus
echo "Deleting EventBridge Event Bus..."
aws events delete-event-bus --name aft-events-from-ct-management --region $REGION 2>/dev/null || true

# Delete S3 Buckets
echo "Deleting S3 Buckets..."
BUCKETS=(
  "aft-backend-$AFT_MGMT_ACCOUNT-secondary-region"
  "aft-backend-$AFT_MGMT_ACCOUNT-primary-region-access-logs"
  "aft-customizations-pipeline-$AFT_MGMT_ACCOUNT"
  "aws-aft-logs-$LOG_ARCHIVE_ACCOUNT-$REGION"
  "aws-aft-s3-access-logs-$LOG_ARCHIVE_ACCOUNT-$REGION"
)

for bucket in "${BUCKETS[@]}"; do
  echo "Emptying and deleting bucket: $bucket"
  aws s3 rm s3://$bucket --recursive --region $REGION 2>/dev/null || true
  aws s3api delete-bucket --bucket $bucket --region $REGION 2>/dev/null || true
done

# Delete KMS Aliases
echo "Deleting KMS Aliases..."
aws kms delete-alias --alias-name alias/aft-backend-$AFT_MGMT_ACCOUNT-kms-key --region $REGION 2>/dev/null || true
aws kms delete-alias --alias-name alias/aft --region $REGION 2>/dev/null || true

echo "✅ Cleanup complete!"
echo "Note: KMS keys are scheduled for deletion (7-30 days). You may need to manually delete other resources."
