#!/bin/bash
# Import existing IAM roles into Terraform state

cd /Users/ashutup/Documents/Learning/fsi-lz/aft-deploy

# Import the two failing roles
terraform import 'module.aft-initiator.module.aft_iam_roles.aws_iam_role.aft_admin_role' AWSAFTAdmin
terraform import 'module.aft-initiator.module.aft_lambda_layer.aws_iam_role.codebuild_trigger_lambda_role' codebuild_trigger_role

echo "✅ Import complete"
