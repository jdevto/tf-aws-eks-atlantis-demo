# S3 bucket
resource "aws_s3_bucket" "this" {
  bucket = var.name

  force_destroy = var.s3_force_destroy

  tags = merge(var.tags, {
    Name = var.name
  })
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "this" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 objects for uploaded files
resource "aws_s3_object" "files" {
  for_each = var.upload_files != null ? fileset(var.upload_files.source_dir, var.upload_files.file_pattern) : toset([])

  bucket = aws_s3_bucket.this.id
  key    = var.upload_files != null && var.upload_files.s3_prefix != null ? "${var.upload_files.s3_prefix}/${each.value}" : each.value
  source = var.upload_files != null ? "${var.upload_files.source_dir}/${each.value}" : null
  content_type = var.upload_files != null ? lookup(
    var.upload_files.content_types,
    regex("\\.[^.]+$", each.value),
    "application/octet-stream"
  ) : "application/octet-stream"
  etag = var.upload_files != null ? filemd5("${var.upload_files.source_dir}/${each.value}") : null

  tags = merge(var.tags, {
    Name = each.value
  })

  depends_on = [aws_s3_bucket.this]
}
