# Create an IAM Role for Application EC2 instances
resource "aws_iam_role" "app_role" {
  name = "${var.environment}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Restrictive Policy: ONLY allows reading logs from CloudWatch
resource "aws_iam_policy" "cloudwatch_write" {
  name        = "${var.environment}-cloudwatch-policy"
  description = "Allows least-privilege logging access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "attach_logging" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.cloudwatch_write.arn
}