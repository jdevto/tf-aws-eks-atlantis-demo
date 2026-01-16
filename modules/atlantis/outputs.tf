output "iam_role_arn" {
  description = "ARN of the IAM role for Atlantis service account"
  value       = aws_iam_role.atlantis.arn
}
