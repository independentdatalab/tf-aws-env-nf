/*
///Uncomment to create a bucket
resource "aws_s3_bucket" "<SOME_BUCKET_NAME>" {
  bucket = "<BUCKET_NAME.ACCOUNT>"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
resource "aws_s3_bucket_public_access_block" "<SOME_BUCKET_NAME>" {
  bucket = "<BUCKET_NAME.ACCOUNT>"

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}
*/
