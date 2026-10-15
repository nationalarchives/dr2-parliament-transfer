data "aws_caller_identity" "current" {}

locals {
  lambda_zip_path        = "${path.module}/lambda.zip"
  ctd_bucket_name        = "${terraform.workspace}-dtp-data-processing-bucket"
  send_to_discovery_name = "${terraform.workspace}-send-to-discovery"
  transfer_bucket_name   = "${terraform.workspace}-pa-transfer"
}

resource "terraform_data" "lambda_package" {
  triggers_replace = {
    handler      = filesha256("lambda/lambda_handler.py")
    requirements = filesha256("lambda/requirements.txt")
    builder      = filesha256("scripts/build_lambda.sh")
    zip_missing  = !fileexists("lambda.zip")
  }
}

data "local_file" "lambda_package" {
  filename   = local.lambda_zip_path
  depends_on = [terraform_data.lambda_package]
}


module "send_to_discovery_lambda" {
  source          = "git::https://github.com/nationalarchives/da-terraform-modules//lambda"
  function_name   = local.send_to_discovery_name
  handler         = "lambda_handler.lambda_handler"
  timeout_seconds = 900
  filename        = data.local_file.lambda_package.filename
  policies = {
    "${terraform.workspace}_send_to_discovery_policy" = templatefile(
      "${path.module}/templates/lambda_policy.json.tpl", {
        ctd_bucket      = local.ctd_bucket_name
        input_queue     = module.send_to_discovery_queue.sqs_arn
        transfer_bucket = module.pa_transfer_bucket.s3_bucket_name
        ctd_kms_key     = var.ctd_kms_key_arn
        account_id      = data.aws_caller_identity.current.account_id
        lambda_name     = local.send_to_discovery_name
      }
    )
  }
  code_sha256 = data.local_file.lambda_package.content_base64sha256
  layers      = [var.layer_version_arn]
  memory_size = 4096
  runtime     = "python3.14"
  plaintext_env_vars = {
    CTD_BUCKET = local.ctd_bucket_name
  }
  lambda_sqs_queue_mappings = [{
    sqs_queue_arn         = "arn:aws:sqs:eu-west-2:${data.aws_caller_identity.current.account_id}:${local.send_to_discovery_name}"
    sqs_queue_concurrency = 2
  }]
}

module "send_to_discovery_queue" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//sqs"
  queue_name = local.send_to_discovery_name
  sqs_policy = templatefile("${path.module}/templates/queue_policy.json.tpl", {
    account_id      = data.aws_caller_identity.current.account_id,
    queue_name      = local.send_to_discovery_name
    transfer_bucket = module.pa_transfer_bucket.s3_bucket_name
  })
  encryption_type    = "sse"
  visibility_timeout = 900
}

module "pa_transfer_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  bucket_name = local.transfer_bucket_name
  bucket_policy = templatefile("${path.module}/templates/bucket_policy.json.tpl", {
    dr2_importer_role = var.dr2_importer_role_arn
    dr2_transfer_role = var.dr2_transfer_role_arn
    bucket_name       = local.transfer_bucket_name
  })
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.pa_transfer_bucket.s3_bucket_id
  queue {
    events        = ["s3:ObjectCreated:*"]
    queue_arn     = module.send_to_discovery_queue.sqs_arn
    filter_suffix = ".metadata"
  }
}

module "bootstrap" {
  source      = "./bootstrap"
  environment = terraform.workspace
  layer_arn   = var.layer_version_arn
}

resource "aws_iam_openid_connect_provider" "openid_provider" {
  count           = terraform.workspace == "dev" ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
  url             = "https://token.actions.githubusercontent.com"
}