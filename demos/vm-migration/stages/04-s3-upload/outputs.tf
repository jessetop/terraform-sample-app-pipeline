# outputs.tf - S3 upload details for downstream stages

output "s3_key" {
  description = "S3 object key of the uploaded OVA"
  value       = aws_s3_object.ova.key
}

output "s3_bucket" {
  description = "S3 bucket containing the OVA"
  value       = aws_s3_object.ova.bucket
}

output "s3_uri" {
  description = "Full S3 URI of the uploaded OVA"
  value       = "s3://${aws_s3_object.ova.bucket}/${aws_s3_object.ova.key}"
}

output "etag" {
  description = "ETag (MD5) of the uploaded OVA — used as change trigger by Stage 05"
  value       = aws_s3_object.ova.etag
}
