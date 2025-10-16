#!/bin/bash

# Set variables
PROJECT_NAME="python-layer-builder-aft-common-koxxighc"
REGION="ap-southeast-1"

echo "Starting CodeBuild Debug Process..."

# 1. Get Latest Build ID and Status
get_build_info() {
    echo "Getting latest build information..."
    BUILD_ID=$(aws codebuild list-builds-for-project \
        --project-name $PROJECT_NAME \
        --region $REGION \
        --query 'ids[0]' \
        --output text)

    if [ "$BUILD_ID" == "None" ]; then
        echo "No builds found!"
        return 1
    fi

    echo "Latest Build ID: $BUILD_ID"
    
    # Get build details
    aws codebuild batch-get-builds \
        --ids $BUILD_ID \
        --query 'builds[0].{Status:buildStatus,Phase:currentPhase,StartTime:startTime,EndTime:endTime}' \
        --output table
}

# 2. Get Build Logs
get_build_logs() {
    echo "Fetching build logs..."
    LOG_GROUP="/aws/codebuild/$PROJECT_NAME"
    
    # Get latest log stream
    LOG_STREAM=$(aws logs describe-log-streams \
        --log-group-name $LOG_GROUP \
        --order-by LastEventTime \
        --descending \
        --limit 1 \
        --query 'logStreams[0].logStreamName' \
        --output text)
    
    if [ "$LOG_STREAM" != "None" ]; then
        echo "Log Stream: $LOG_STREAM"
        
        # Get logs
        aws logs get-log-events \
            --log-group-name $LOG_GROUP \
            --log-stream-name $LOG_STREAM \
            --output text
    else
        echo "No log streams found"
    fi
}

# 3. Check Project Configuration
check_project_config() {
    echo "Checking project configuration..."
    aws codebuild batch-get-projects \
        --names $PROJECT_NAME \
        --query 'projects[0].{Environment:environment,ServiceRole:serviceRole,Source:source,Cache:cache}' \
        --output json
}

# 4. Check IAM Role Permissions
check_iam_permissions() {
    echo "Checking IAM role permissions..."
    
    # Get role name from ARN
    ROLE_ARN=$(aws codebuild batch-get-projects \
        --names $PROJECT_NAME \
        --query 'projects[0].serviceRole' \
        --output text)
    
    if [ "$ROLE_ARN" != "None" ]; then
        ROLE_NAME=$(echo $ROLE_ARN | cut -d'/' -f2)
        
        echo "Role Name: $ROLE_NAME"
        
        # List attached policies
        echo "Attached Policies:"
        aws iam list-attached-role-policies --role-name $ROLE_NAME --output table
        
        # List inline policies
        echo "Inline Policies:"
        aws iam list-role-policies --role-name $ROLE_NAME --output table
    else
        echo "No service role found"
    fi
}

# 5. Check Build Status
check_build_status() {
    echo "Checking recent build status..."
    aws codebuild list-builds-for-project \
        --project-name $PROJECT_NAME \
        --region $REGION \
        --max-items 5 \
        --query 'ids[]' \
        --output text | tr '\t' '\n' | while read -r build_id; do
        echo "Build ID: $build_id"
        aws codebuild batch-get-builds \
            --ids "$build_id" \
            --query 'builds[].{Status:buildStatus,Phase:currentPhase,StartTime:startTime}' \
            --output table
    done
}

# 6. Check VPC Configuration
check_vpc_config() {
    echo "Checking VPC configuration..."
    aws codebuild batch-get-projects \
        --names $PROJECT_NAME \
        --query 'projects[0].vpcConfig' \
        --output json
}

# 7. Check Environment Variables
check_environment_vars() {
    echo "Checking environment variables..."
    aws codebuild batch-get-projects \
        --names $PROJECT_NAME \
        --query 'projects[0].environment.environmentVariables' \
        --output json
}

# Main debugging sequence
echo "=== CodeBuild Debug Report ==="
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo "Time: $(date)"
echo "================================"

echo -e "\n1. Build Information"
get_build_info

echo -e "\n2. Build Logs"
get_build_logs

echo -e "\n3. Project Configuration"
check_project_config

echo -e "\n4. IAM Permissions"
check_iam_permissions

echo -e "\n5. Recent Build Status"
check_build_status

echo -e "\n6. VPC Configuration"
check_vpc_config

echo -e "\n7. Environment Variables"
check_environment_vars

echo -e "\n=== Debug Report Complete ==="

# Optional: Save output to file
OUTPUT_FILE="codebuild-debug-$(date +%Y%m%d-%H%M%S).log"
{
    echo "=== CodeBuild Debug Report ==="
    echo "Project: $PROJECT_NAME"
    echo "Region: $REGION"
    echo "Time: $(date)"
    echo "================================"
    
    get_build_info
    get_build_logs
    check_project_config
    check_iam_permissions
    check_build_status
    check_vpc_config
    check_environment_vars
} > "$OUTPUT_FILE"

echo -e "\nDebug log saved to: $OUTPUT_FILE"
