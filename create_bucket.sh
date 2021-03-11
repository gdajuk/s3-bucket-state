#!/bin/bash

export bucket_name="myapp-state2"
export profile="default"
export region="eu-central-1"


black=0; red=1; green=2; yellow=3; blue=4; pink=5; cyan=6; white=7;
cecho () {
  local _color=$1; shift
  echo -e "$(tput setaf $_color)$@$(tput sgr0)"
}

function create_bucket {
    aws s3 mb s3://${bucket_name} \
        --profile ${profile} \
        --region ${region} 1>&2 2>/dev/null
}

function check_bucket_versioning {
    aws s3api get-bucket-versioning --bucket "${bucket_name}"|jq -r .Status |grep "Enabled" 2>&1 1>/dev/null
}

function enable_bucket_versioning {
    aws s3api put-bucket-versioning \
        --bucket ${bucket_name} \
        --versioning-configuration "Status=Enabled" \
        --profile ${profile} \
        --region ${region} 1>&2 2>/dev/null
}

function bucket_access_check {
    aws s3api get-public-access-block --bucket  ${bucket_name} 2>/dev/null 1>&2
}

function setup_bucket_access {
    aws s3api put-public-access-block \
        --bucket ${bucket_name}  \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --profile ${profile}  \
        --region ${region} 1>&2 2>/dev/null
}

function check_dynamodb_table {
    aws dynamodb list-tables --region eu-central-1 |jq -r ".TableNames[]" |grep ${bucket_name} 2>/dev/null 1>&2
}

function create_dynamodb_table {
    aws dynamodb create-table \
        --table-name ${bucket_name} \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --profile ${profile}  \
        --region ${region}  2>/dev/null 1>&2
}


### .................................................. BUCKET 
bucketstatus=$(aws s3api head-bucket --bucket "${bucket_name}" 2>&1)
if echo "${bucketstatus}" | grep 'Not Found'; then
  cecho $yellow "Bucket doesn't exist. Creating..";
  create_bucket
elif echo "${bucketstatus}" | grep 'Forbidden'; then
  cecho $red "Bucket name already taken."
  exit 1
elif echo "${bucketstatus}" | grep 'Bad Request'; then
  cecho $red "Bucket name specified is less than 3 or greater than 63 characters"
  exit 1
else
  cecho $green "  Bucket owned and exists";
fi

### .................................................. BUCKET VERSIONING
check_bucket_versioning
if [ $? -eq "0" ]; then
    cecho $green "  Bucket versioning is already enabled."
else
    cecho $red  "Bucket versioning was disabled for ${bucket_name}. Enabling.."
    enable_bucket_versioning
    cecho $yellow "  Bucket versioning has been enabled on bucket: ${bucket_name}."
fi
### .................................................. BUCKET ACCESS
bucket_access_check
if [ $? -eq "0" ]; then
    cecho $green "  Bucket accesses are valid."
else
    cecho $red  "Bucket access is open. Fixing.."
    setup_bucket_access
    cecho $yellow "  Bucket access has been set."
fi
### .................................................. DYNAMODB
check_dynamodb_table
if [ $? -eq "0" ]; then
    cecho $green "  Dynamodb lock table exist"
else
    cecho $red  "Dynamodb lock table doesn't exist. Creating.."
    create_dynamodb_table
    cecho $yellow "  Dynamodb lock table has been created."
fi
