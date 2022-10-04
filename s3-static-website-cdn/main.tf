#Create provider
 provider "aws" {
  region = var.region
  access_key = var.access_key
  secret_key = var.secret_access_key
 }


#Create S3 bucket
 resource "aws_s3_bucket" "a" {
  bucket = "my-tf-test-bucket-28-sept-22"

  tags = {
    Name        = "my-tf-test-bucket-28-sept-22"
  }
}

#Create S3 bucket acl
resource "aws_s3_bucket_acl" "acl-1" {
  bucket = aws_s3_bucket.a.id
  acl    = "private"
}

#Upload files to the bucket
resource "aws_s3_bucket_object" "object-1" {
  bucket = "my-tf-test-bucket-28-sept-22"
  key    = "index.html"
  source = "<FILE PATH>"
  depends_on = [aws_s3_bucket.a]
}
resource "aws_s3_bucket_object" "object-2" {
  bucket = "my-tf-test-bucket-28-09-22"
  key    = "error.html"
  source = "<FILE PATH>"
  depends_on = [aws_s3_bucket.a]
}

#Enable static website property
resource "aws_s3_bucket_website_configuration" "config-1" {
  bucket = aws_s3_bucket.a.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

#Create S3 bucket policy for cloudfront OAI access
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.a.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.OAI.iam_arn]
    }
  }


#Attach the policy 
resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.a.id
  policy = data.aws_iam_policy_document.s3_policy.json
  depends_on = [aws_s3_bucket.a]
}
}

#Create s3 origin for cloudfront
locals {
  s3_origin_id = "myS3Origin"
}

#Create OAI
resource "aws_cloudfront_origin_access_identity" "OAI" {
  comment = "Some comment"
}

#Create cloudfront distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.a.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    #attaching OAI to the distribution
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.OAI.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3
    max_ttl                = 5
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    #use this if you have SSL certificate or else leave it default assuming both HTTP and HTTPS
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    
  }

  price_class = "PriceClass_200"

  #restrictions {
  #geo_restriction {
      #restriction_type = "whitelist"
      #locations        = ["US", "CA", "GB", "DE"]
    #}
  #}

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  depends_on = [aws_s3_bucket.a]
}
