variable "bucket_name" {
    type        = string
    default     = "bucketname047"  
}

variable "componentTagName" {
    type        = string
    default     = "s3"  
}

variable "aws_account_id" {
    description = "The AWS account ID to use for the bucket policy."
    default     = "084828579410" 
}