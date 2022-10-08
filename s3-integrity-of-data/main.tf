#Create S3 bucket
 resource "aws_s3_bucket" "a" {
  bucket = "my-tf-test-bucket-08-oct-22"
  tags = {
    Name        = "my-tf-test-bucket-08-oct-22"
  }
}

#Create S3 bucket acl
resource "aws_s3_bucket_acl" "acl-1" {
  bucket = aws_s3_bucket.a.id
  acl    = "private"
}

#Enable SSE using aws default kms key
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.a.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}
#Amazon S3-managed keys (SSE-S3)--> sse_algorithm = "AES256"
#AWS Key Management Service key (SSE-KMS)--> sse_algorithm = "aws:kms"

#Enable block public access
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.a.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#Terraform has not added the attribute "additional checksum" for s3 object
#So please manually enable it while adding the object manually
#for comparison, compare the checksum id in the console and in your local termianl using the command,
#shasum -a 256 image.jpg | cut -f1 -d\ | xxd -r -p | base64
