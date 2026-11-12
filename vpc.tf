# 1. Main Virtual Private Cloud (VPC)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

# Restrict default security group to deny all traffic (Resolves CKV2_AWS_12)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress = []
  egress  = []
}

# 2. Public Subnets (AZ 1 and AZ 2)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.environment}-public-subnet-${count.index + 1}"
  }
}

# 3. Private Subnets (AZ 1 and AZ 2)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.environment}-private-subnet-${count.index + 1}"
  }
}

# 4. Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

# 5. Static Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.environment}-nat-eip"
  }
}

# 6. NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.environment}-nat-gw"
  }
}

# 7. KMS Key for CloudWatch Log Encryption (Resolves CKV_AWS_158)
resource "aws_kms_key" "cloudwatch_key" {
  description             = "KMS key for VPC flow logs CloudWatch group encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# 8. CloudWatch Log Group with KMS Encryption and 365-day Retention (Resolves CKV_AWS_338 & CKV_AWS_158)
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc-flow-log/${var.environment}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cloudwatch_key.arn
}

# 9. IAM Role for Flow Logs
resource "aws_iam_role" "vpc_flow_log_role" {
  name = "${var.environment}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# 10. IAM Policy for Flow Logs with Scoped Resource (Resolves CKV_AWS_290 & CKV_AWS_355)
resource "aws_iam_policy" "vpc_flow_log_policy" {
  name = "${var.environment}-vpc-flow-log-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = aws_cloudwatch_log_group.vpc_flow_log.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_flow_log_attach" {
  role       = aws_iam_role.vpc_flow_log_role.name
  policy_arn = aws_iam_policy.vpc_flow_log_policy.arn
}

# 11. Enable VPC Flow Log on the VPC (Resolves CKV2_AWS_11)
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}