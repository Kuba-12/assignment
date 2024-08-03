provider "aws" {
  region     = "us-east-2" # Change this to your desired AWS region
  access_key = "#"
  secret_key = "#"
}

# Creating everything in Default VPC, I can also create VPC and them create ec2 in that VPC.

resource "aws_instance" "ec2_instance" {
  ami           = "ami-05fb0b8c1424f266b"        # AMI of EC2 Instance
  instance_type = "t2.micro" #Instance Type
  key_name      = "" # Replace with your key pair name
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "EC2-Instance-Assignment" #Tags for EC2 Instance
  }
}

# Standard Queue
resource "aws_sqs_queue" "sqs_queue_standard" {
  name = "my-sqs-queue-standard"
}

# FIFO Queue Uncomment to create FIFO QUEUE
# resource "aws_sqs_queue" "sqs_queue_fifo" {
#   name = "my-sqs-queue.fifo"
#   fifo_queue = true
# }

# Dynamo DB table
resource "aws_dynamodb_table" "dynamodb_assignment" {
  name         = "dynamodb-assignment"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# IAM Instance Profile to attatch with EC2 Instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2_Instance_Profile"

  role = aws_iam_role.ec2_role.name
}


# IAM Role for EC2 instance
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role_for_sqs_and_dynamoDB"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com",
        },
      },
    ],
  })
}

# IAM SQS Policy 
data "aws_iam_policy_document" "sqs_queue_policy_json" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage", "sqs:ReceiveMessage"]
    resources = ["${aws_sqs_queue.sqs_queue_standard.arn}"]
  }
}

# Create a policy with above json policy
resource "aws_iam_policy" "sqs-queue-policy" {
  name        = "SQS-Queue-Policy"
  description = "SQS Queue Policy to send and receive messages"
  policy      = data.aws_iam_policy_document.sqs_queue_policy_json.json
}

# Assign this SQS policy to IAM Role
resource "aws_iam_role_policy_attachment" "sqs_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.sqs-queue-policy.arn
}


# IAM DynamoDB Policy for all tables in DB
data "aws_iam_policy_document" "dynami_db_json" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:CreateTable",
                "dynamodb:PutItem",
                "dynamodb:DescribeTable",
                "dynamodb:GetItem",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "dynamodb:DeleteTable",
                "dynamodb:UpdateTable"]
    resources = ["${aws_dynamodb_table.dynamodb_assignment.arn}"]    # Edit this to mention specific table in Dynamo DB
  }
}

# Create a policy with above json policy
resource "aws_iam_policy" "dynamo-db-policy" {
  name        = "Dynamo-DB-Policy"
  description = "Policy for DynamoDB tables to be created along with permissions to read and write table data"
  policy      = data.aws_iam_policy_document.dynami_db_json.json
}

# Assign this DynamoDB policy to IAM Role
resource "aws_iam_role_policy_attachment" "dynamodb_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.dynamo-db-policy.arn
}
