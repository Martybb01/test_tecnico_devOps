# collegamento policy - lambda attraverso il role, diverso per ogni istanza del modulo
# order-processor  → basic + vpc + eventbridge + dynamodb
# email-notifier   → basic + ses
# data-sync        → basic + vpc + xray + sns + s3 + kms
# dlq-processor    → basic + sqs

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# policy base per logs CloudWatch, applicata a tutte
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray" {
  count      = var.enable_xray ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "vpc_execution" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "eventbridge_publish" {
  count = var.event_bus_arn != "" ? 1 : 0
  name  = "allow-eventbridge-putevents"
  role  = aws_iam_role.lambda.name

  # pubblica OrderCreated sul bus custom
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:PutEvents"
      Resource = var.event_bus_arn
    }]
  })
}

resource "aws_iam_role_policy" "sns_publish" {
  count = var.sns_topic_arn != "" ? 1 : 0
  name  = "allow-sns-publish"
  role  = aws_iam_role.lambda.name

  # notifica il completamento del sync
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = var.sns_topic_arn
    }]
  })
}

resource "aws_iam_role_policy" "dynamodb_write" {
  count = var.dynamodb_table_arn != "" ? 1 : 0
  name  = "allow-dynamodb-write"
  role  = aws_iam_role.lambda.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem", # persistenza su DynamoDB
        "dynamodb:GetItem"
      ]
      Resource = var.dynamodb_table_arn
    }]
  })
}

resource "aws_iam_role_policy" "s3_write" {
  count = var.data_lake_bucket_arn != "" ? 1 : 0
  name  = "allow-s3-write"
  role  = aws_iam_role.lambda.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "s3:PutObject", "s3:PutObjectAcl"]
      Resource = "${var.data_lake_bucket_arn}/*"
    }]
  })
}

resource "aws_iam_role_policy" "kms_encrypt" {
  count = var.kms_key_arn != "" ? 1 : 0
  name  = "allow-kms-encrypt"
  role  = aws_iam_role.lambda.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
      Resource = var.kms_key_arn
    }]
  })
}

# AWSLambdaSQSQueueExecutionRole include ReceiveMessage, DeleteMessage, GetQueueAttributes
resource "aws_iam_role_policy_attachment" "sqs_execution" {
  count      = var.enable_sqs_trigger ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}


resource "aws_iam_role_policy" "ses_send" {
  count = var.ses_sender_arn != "" ? 1 : 0
  name  = "allow-ses-send"
  role  = aws_iam_role.lambda.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ses:SendEmail"
      Resource = var.ses_sender_arn
    }]
  })
}
