#Create S3 bucket
 resource "aws_s3_bucket" "a" {
  bucket = "my-tf-test-bucket-07-oct-22"
  tags = {
    Name        = "my-tf-test-bucket-07-oct-22"
  }
}

#Create S3 bucket acl
resource "aws_s3_bucket_acl" "acl-1" {
  bucket = aws_s3_bucket.a.id
  acl    = "private"
}

#Enabling S3 versioning
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.a.id
  versioning_configuration {
    status = "Enabled"
  }
}

#Enable SSE using aws default kms key
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.a.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
    }
  }
}

#Enable block public access
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.a.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#Upload a file to the above created S3 bucket
resource "aws_s3_bucket_object" "object" {
  bucket = "my-tf-test-bucket-07-oct-22"
  key    = "<FILE NAME>"
  source = "<FILE PATH>"
  depends_on = [aws_s3_bucket.a]
}

#Enable object lock
resource "aws_s3_bucket_object_lock_configuration" "example" {
  bucket = aws_s3_bucket.a.bucket

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 1
    }
  }
}
#Amazon S3 currently does not support enabling Object Lock after a bucket has been created. To enable Object Lock for this bucket, contact Customer Support 
#Note that objects that are locked and cannot be deleted will continue to be billed. To minimize costs for this tutorial, ensure you have set the default retention to only 1 day, and only upload small files.
