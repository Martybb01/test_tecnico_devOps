# Ordine di dipendenza:
# modules/lambda (nessuna dep) → sqs (nessuna dep) → eventbridge (riceve ARN da lambda + sqs)

module "lambda_order_processor" {
  source        = "./modules/lambda"
  function_name = "order-processor"
  handler       = "handler.handler"
  runtime       = "nodejs20.x"
  timeout       = 30
  memory_size   = 512
  reserved_concurrent_executions = 10
  source_dir    = "${path.module}/lambda/order-processor"
  project_name  = var.project_name
  environment   = var.environment
  subnet_ids         = var.private_subnet_ids
  security_group_ids = var.lambda_security_group_ids
  event_bus_arn      = var.event_bus_arn  # permesso IAM events:PutEvent
  dynamodb_table_arn = var.dynamodb_table_arn # permesso IAM dynamodb:PutItem e dynamodb:GetItem
  environment_variables = {
    EVENT_BUS_NAME   = "order-events"
    DB_HOST          = var.db_host
    CACHE_ENDPOINT   = var.cache_endpoint
  }
}

resource "aws_lambda_alias" "order_processor_live" {
  name             = "live"
  function_name    = module.lambda_order_processor.function_name
  function_version = "$LATEST"
}

resource "aws_lambda_provisioned_concurrency_config" "order_processor" {
  function_name                      = module.lambda_order_processor.function_name
  qualifier                          = aws_lambda_alias.order_processor_live.name  # "live"
  provisioned_concurrent_executions  = 5 # istanze sempre calde
}

module "lambda_email_notifier" {
  source        = "./modules/lambda"
  function_name = "email-notifier"
  handler       = "handler.handler"
  runtime       = "nodejs20.x"
  timeout       = 60
  memory_size   = 256
  source_dir    = "${path.module}/lambda/email-notifier"
  project_name  = var.project_name
  environment   = var.environment
  ses_sender_arn = var.ses_sender_arn
}

module "lambda_data_sync" {
  source        = "./modules/lambda"
  function_name = "data-sync"
  handler       = "handler.handler"
  runtime       = "nodejs20.x"
  timeout       = 900
  memory_size   = 3008
  source_dir    = "${path.module}/lambda/data-sync"
  project_name  = var.project_name
  environment   = var.environment
  subnet_ids         = var.private_subnet_ids
  security_group_ids = var.lambda_security_group_ids
  ephemeral_storage_size = 10240
  enable_xray            = true 
  sns_topic_arn          = var.sns_topic_arn # permesso IAM sns:Publish
  data_lake_bucket_arn   = var.data_lake_bucket_arn # permesso IAM s3:PutObject
  kms_key_arn            = var.kms_key_arn # permesso IAM kms:GenerateDataKey + kms:Decrypt
  environment_variables = {
    DB_HOST          = var.db_host
    DATA_LAKE_BUCKET = var.data_lake_bucket
    SNS_TOPIC_ARN    = var.sns_topic_arn
  }
}

module "lambda_dlq_processor" {
  source        = "./modules/lambda"
  function_name = "dlq-processor"
  handler       = "handler.handler"
  runtime       = "nodejs20.x"
  timeout       = 60
  memory_size   = 128
  source_dir    = "${path.module}/lambda/dlq-processor"
  project_name  = var.project_name
  environment   = var.environment
  enable_sqs_trigger = true
  sqs_queue_arn = module.sqs.dlq_arn
}

module "sqs" {
  source       = "./sqs"
  project_name = var.project_name
  environment  = var.environment
}

resource "aws_lambda_event_source_mapping" "dlq_processor" {
  event_source_arn = module.sqs.dlq_arn
  function_name    = module.lambda_dlq_processor.function_arn
  batch_size       = 1
}

module "eventbridge" {
  source                       = "./eventbridge"
  dlq_arn                      = module.sqs.dlq_arn
  dlq_queue_url                = module.sqs.dlq_queue_url
  email_notifier_arn           = module.lambda_email_notifier.function_arn
  email_notifier_function_name = module.lambda_email_notifier.function_name
  data_sync_arn                = module.lambda_data_sync.function_arn
  data_sync_function_name      = module.lambda_data_sync.function_name
  project_name                 = var.project_name
  environment                  = var.environment
}
