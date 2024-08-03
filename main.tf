# provider.tf
provider "aws" {
  region = "us-west-2"
}

# ec2.tf
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"  # Update with your preferred AMI
  instance_type = "t2.micro"

  tags = {
    Name = "AppInstance"
  }
}

# sqs.tf
resource "aws_sqs_queue" "app_queue" {
  name = "app-queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queue.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue" "dead_letter_queue" {
  name = "app-dead-letter-queue"
}

resource "aws_iam_role" "sqs_role" {
  name = "sqs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "sqs_policy" {
  name        = "sqs-policy"
  description = "Policy for SQS access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Effect   = "Allow"
        Resource = [
          aws_sqs_queue.app_queue.arn,
          aws_sqs_queue.dead_letter_queue.arn,
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sqs_policy_attachment" {
  role       = aws_iam_role.sqs_role.name
  policy_arn = aws_iam_policy.sqs_policy.arn
}

# dynamodb.tf
resource "aws_dynamodb_table" "app_table" {
  name         = "app-table"
  billing_mode = "PAY_PER_REQUEST"
  
  attribute {
    name = "id"
    type = "S"
  }

  hash_key = "id"
  
  tags = {
    Name = "AppTable"
  }
}

resource "aws_iam_role" "dynamodb_role" {
  name = "dynamodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "dynamodb_policy" {
  name        = "dynamodb-policy"
  description = "Policy for DynamoDB access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.app_table.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_policy_attachment" {
  role       = aws_iam_role.dynamodb_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

# ec2_iam_role.tf
resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "app-instance-profile"
  role = aws_iam_role.sqs_role.name
}

resource "aws_iam_instance_profile" "dynamodb_instance_profile" {
  name = "dynamodb-instance-profile"
  role = aws_iam_role.dynamodb_role.name
}

resource "aws_instance" "app" {
  ami                    = "ami-0c55b159cbfafe1f0"  # Update with your preferred AMI
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.app_instance_profile.name

  tags = {
    Name = "AppInstance"
  }

  depends_on = [
    aws_iam_role_policy_attachment.sqs_policy_attachment,
    aws_iam_role_policy_attachment.dynamodb_policy_attachment
  ]
}


