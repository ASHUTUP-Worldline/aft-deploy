terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  backend "s3" {
    region         = "ap-southeast-1"                       #"us-east-1"
    bucket         = "aft-deploy-terraform-state-1368"      #"{STATE_BUCKET}"
    key            = "aft-deploy/terraform.tfstate"         #"{STATE_FILE}"
    dynamodb_table = "aft-deploy-terraform-state-ddb"       #"{DYNAMODB_TABLE}"
    encrypt        = "true"
    kms_key_id     = "bd162e87-6998-4418-b6f6-7b2c6a69e4c1" #"{KMS_KEY}"
  }
}
provider "aws" {
  region = "ap-southeast-1" #"us-east-1"
}
# Reference: https://github.com/aws-ia/terraform-aws-control_tower_account_factory
# Reference: https://github.com/ASHUTUP-Worldline/terraform-aws-control_tower_account_factory
module "aft-initiator" {
  source  = "aws-ia/control_tower_account_factory/aws"
  # source  = "../terraform-aws-control_tower_account_factory"
  version = "1.16.0" #"1.10.3"

  # Account IDs
  ct_management_account_id  = "681833711368" #"{ACCOUNT_ID}"
  aft_management_account_id = "658659131265" #"{ACCOUNT_ID}"
  audit_account_id          = "805187822430" #"{ACCOUNT_ID}"
  log_archive_account_id    = "235279000749" #"{ACCOUNT_ID}"

  # VCS Configuration
  vcs_provider                                    = "github"
  account_customizations_repo_branch              = "main"
  account_customizations_repo_name                = "ASHUTUP-Worldline/aft-account-customizations" #"{GITHUB_ORGANIZATION}/aft-account-customizations"
  account_provisioning_customizations_repo_branch = "main"
  account_provisioning_customizations_repo_name   = "ASHUTUP-Worldline/aft-account-provisioning-customizations" #"{GITHUB_ORGANIZATION}/aft-account-provisioning-customizations"
  account_request_repo_branch                     = "main"
  account_request_repo_name                       = "ASHUTUP-Worldline/aft-account-request" #"{GITHUB_ORGANIZATION}/aft-account-request"
  global_customizations_repo_branch               = "main"
  global_customizations_repo_name                 = "ASHUTUP-Worldline/aft-global-customizations" #"{GITHUB_ORGANIZATION}/aft-global-customizations"

  # AFT Configuration
  ct_home_region                          = "ap-southeast-1" #"us-east-1"
  tf_backend_secondary_region             = "eu-central-1" #"us-west-2"
  aft_feature_cloudtrail_data_events      = true
  aft_feature_delete_default_vpcs_enabled = true
  aft_feature_enterprise_support          = true
  aft_metrics_reporting                   = true
  aft_vpc_endpoints                       = true
  cloudwatch_log_group_retention          = 90
  maximum_concurrent_customizations       = 10
#   terraform_version                       = "1.5.3" # Released July 12, 2023
}
