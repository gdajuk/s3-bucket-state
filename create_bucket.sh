#!/bin/bash -x

export bucket_name="myapp-state"
export profile="default"
export region="eu-central-1"

cecho () {
  local _color=$1; shift
  echo -e "$(tput setaf $_color)$@$(tput sgr0)"
}
black=0; red=1; green=2; yellow=3; blue=4; pink=5; cyan=6; white=7;
err () {
  cecho 1 "$@" >&2;
}

check_bucket="`aws s3api list-buckets | jq -r .Buckets[].Name|grep "${bucket_name}"`"

function create_bucket {
    echo "Creating bucket: ${bucket_name}"
    aws s3 mb s3://${bucket_name} \
        --profile ${profile} \
        --region ${region} #1>2 2>/dev/null
    cecho $green "  Bucket: ${bucket_name} has been created."
}

create_bucket

function enable_bucket_versioning {
    echo "Enable versioning for bucket: ${bucket_name}"
    aws s3api put-bucket-versioning \
        --bucket ${bucket_name} \
        --versioning-configuration "Status=Enabled" \
        --profile ${profile} \
        --region ${region} #1>2 2>/dev/null
    cecho $green "  Versioning has been enabled on bucket: ${bucket_name}."
}

function setup_bucket_access {
    echo "Setup bucket access..."
    aws s3api put-public-access-block \
    --bucket ${bucket_name}  \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --profile ${profile}  \
    --region ${region} #1>2 2>/dev/null
    cecho $green "  Bucket access has been set."
}

function check_bucket_access {
    echo "Validate bucket access..."
    aws s3api get-public-access-block --bucket ${bucket_name} 1>2 2>/dev/null
    if [ $? -eq "0" ]; then
        cecho $green "  All bucket accesses are valid."
    else
        ERROR=0
        if [[ `aws s3api get-public-access-block --bucket ${bucket_name} 1>2 2>/dev/null; echo $?` -ne "0" ]]; then
            for i in BlockPublicAcls IgnorePublicAcls BlockPublicPolicy RestrictPublicBuckets ; do
                if [[ "`aws s3api get-public-access-block --bucket ${bucket_name} 2>/dev/null |jq .PublicAccessBlockConfiguration.$i`" != "True" ]]; then
                    ERROR=1
                fi
            done
        else
            cecho $green "  Bucket accesses are valid."
        fi
    fi
}

function check_dynamodb_table {
    aws dynamodb list-tables --region eu-central-1 |jq -r ".TableNames[]" |grep ${bucket_name} 1>2 2>/dev/null
}

function create_dynamodb_table {
    echo "Create dynamodb table for locks..."
    aws dynamodb create-table \
    --table-name ${bucket_name} \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --profile ${profile}  \
    --region ${region}  1>/dev/null
    cecho $green  "  Dynamodb table has been created."
}

# echo "Check if bucket: '${bucket_name}'  exist..."
# if [[ "${check_bucket}" == "${bucket_name}" ]]; then
#     cecho $green  "  Bucket ${bucket_name} exist."
#     echo "Check if ${bucket_name} has versioning enabled..."
#     if [[ `aws s3api get-bucket-versioning --bucket "${bucket_name}"|jq -r .Status` != "Enabled" ]]; then
#         enable_bucket_versioning
#     else
#         cecho $green "  Versioning already enabled."
#     fi
#     check_bucket_access
#     if [[ $ERROR -eq "1" ]];then
#         setup_bucket_access
#     fi
#     check_dynamodb_table
#     if [ $? -eq "0" ]; then
#         cecho $green "  Dynamodb table is valid."
#     else
#         create_dynamodb_table
#     fi
# else
#     create_bucket
#     enable_bucket_versioning
#     setup_bucket_access
#     create_dynamodb_table
#     echo "All accesses are valid now."
# fi

