AWS_PROFILE=default
BUCKET=terraform.<PROFILE>


aws --profile $AWS_PROFILE s3 mb s3://$BUCKET
aws --profile $AWS_PROFILE s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled
aws --profile $AWS_PROFILE s3api put-bucket-encryption --bucket $BUCKET --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
aws --profile $AWS_PROFILE s3api put-public-access-block --bucket $BUCKET --public-access-block-configuration '{"BlockPublicAcls": true, "IgnorePublicAcls": true, "BlockPublicPolicy": true, "RestrictPublicBuckets": true}'
