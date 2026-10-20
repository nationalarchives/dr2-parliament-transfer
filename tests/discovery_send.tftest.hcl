mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/terraform-test"
      id         = "123456789012"
      user_id    = "AIDATESTUSER"
    }
  }
}

mock_provider "local" {
  mock_data "local_file" {
    defaults = {
      content_base64sha256 = "mock-package-sha256"
    }
  }
}

mock_provider "terraform" {}

variables {
  layer_version_arn     = "arn:aws:lambda:eu-west-2:123456789012:layer:imagemagick:1"
  ctd_kms_key_arn       = "arn:aws:kms:eu-west-2:123456789012:key/57bc976c-ba7a-4dcf-99cb-475d3530c0cb"
  dr2_importer_role_arn = "arn:aws:iam::123456789012:role/importer"
  dr2_transfer_role_arn = "arn:aws:iam::123456789012:role/transfer"
}

run "prepare_lambda_package" {
  command = apply

  plan_options {
    target = [terraform_data.lambda_package]
  }

  override_resource {
    target = terraform_data.lambda_package
  }
}

run "discovery_send" {
  command = plan

  override_data {
    target          = data.local_file.lambda_package
    override_during = plan

    values = {
      content_base64sha256 = "mock-package-sha256"
    }
  }

  assert {
    condition = (
      module.pa_transfer_bucket.s3_bucket_name == "${terraform.workspace}-pa-transfer" &&
      module.send_to_discovery_lambda.lambda_function.function_name == "${terraform.workspace}-send-to-discovery"
    )
    error_message = "The bucket and Lambda names must have the environment prefix."
  }

  assert {
    condition = (
      module.send_to_discovery_lambda.lambda_function.runtime == "python3.14" &&
      module.send_to_discovery_lambda.lambda_function.handler == "lambda_handler.lambda_handler" &&
      module.send_to_discovery_lambda.lambda_function.memory_size == 4096 &&
      module.send_to_discovery_lambda.lambda_function.timeout == 900 &&
      module.send_to_discovery_lambda.lambda_function.code_sha256 == "mock-package-sha256" &&
      tolist(module.send_to_discovery_lambda.lambda_function.layers) == tolist([var.layer_version_arn]) &&
      module.send_to_discovery_lambda.lambda_function.filename == "${path.module}/lambda.zip"
    )
    error_message = "The Lambda runtime, handler, sizing, layer and package must match the module configuration."
  }

  assert {
    condition = (
      module.send_to_discovery_lambda.lambda_function.environment[0].variables == tomap({
        CTD_BUCKET = "${terraform.workspace}-dtp-data-processing-bucket"
      })
    )
    error_message = "The Lambda must use the environment-prefixed CTD bucket."
  }

  assert {
    condition = (
      module.send_to_discovery_queue.sqs_queue.name == "${terraform.workspace}-send-to-discovery" &&
      module.send_to_discovery_queue.sqs_queue.sqs_managed_sse_enabled &&
      module.send_to_discovery_queue.sqs_queue.visibility_timeout_seconds == 900 &&
      module.send_to_discovery_queue.sqs_dlq.name == "${terraform.workspace}-send-to-discovery-dlq"
    )
    error_message = "The SQS module must create the encrypted queue with the configured timeout and dead-letter queue."
  }

  assert {
    condition = (
      jsondecode(module.send_to_discovery_queue.sqs_queue.policy).Statement[0].Principal.Service == "s3.amazonaws.com" &&
      jsondecode(module.send_to_discovery_queue.sqs_queue.policy).Statement[0].Action == "SQS:SendMessage" &&
      jsondecode(module.send_to_discovery_queue.sqs_queue.policy).Statement[0].Condition.ArnLike["aws:SourceArn"] == "arn:aws:s3:*:*:${terraform.workspace}-pa-transfer"
    )
    error_message = "The queue policy must allow S3 notifications from the transfer bucket."
  }

  assert {
    condition = (
      length(jsondecode(templatefile("${path.module}/templates/lambda_policy.json.tpl", {
        ctd_bucket      = "${terraform.workspace}-dtp-data-processing-bucket"
        input_queue     = "arn:aws:sqs:eu-west-2:123456789012:${terraform.workspace}-send-to-discovery"
        transfer_bucket = module.pa_transfer_bucket.s3_bucket_name
        ctd_kms_key     = var.ctd_kms_key_arn
        account_id      = "123456789012"
        lambda_name     = "${terraform.workspace}-send-to-discovery"
      })).Statement) == 5 &&
      jsondecode(templatefile("${path.module}/templates/lambda_policy.json.tpl", {
        ctd_bucket      = "${terraform.workspace}-dtp-data-processing-bucket"
        input_queue     = "arn:aws:sqs:eu-west-2:123456789012:${terraform.workspace}-send-to-discovery"
        transfer_bucket = module.pa_transfer_bucket.s3_bucket_name
        ctd_kms_key     = var.ctd_kms_key_arn
        account_id      = "123456789012"
        lambda_name     = "${terraform.workspace}-send-to-discovery"
        })).Statement[2].Resource == [
        "arn:aws:s3:::${terraform.workspace}-pa-transfer",
        "arn:aws:s3:::${terraform.workspace}-pa-transfer/*"
      ] &&
      jsondecode(templatefile("${path.module}/templates/lambda_policy.json.tpl", {
        ctd_bucket      = "${terraform.workspace}-dtp-data-processing-bucket"
        input_queue     = "arn:aws:sqs:eu-west-2:123456789012:${terraform.workspace}-send-to-discovery"
        transfer_bucket = module.pa_transfer_bucket.s3_bucket_name
        ctd_kms_key     = var.ctd_kms_key_arn
        account_id      = "123456789012"
        lambda_name     = "${terraform.workspace}-send-to-discovery"
      })).Statement[3].Resource == var.ctd_kms_key_arn &&
      jsondecode(templatefile("${path.module}/templates/lambda_policy.json.tpl", {
        ctd_bucket      = "${terraform.workspace}-dtp-data-processing-bucket"
        input_queue     = "arn:aws:sqs:eu-west-2:123456789012:${terraform.workspace}-send-to-discovery"
        transfer_bucket = module.pa_transfer_bucket.s3_bucket_name
        ctd_kms_key     = var.ctd_kms_key_arn
        account_id      = "123456789012"
        lambda_name     = "${terraform.workspace}-send-to-discovery"
        })).Statement[4].Resource == [
        "arn:aws:logs:eu-west-2:123456789012:log-group:/aws/lambda/${terraform.workspace}-send-to-discovery:*:*",
        "arn:aws:logs:eu-west-2:123456789012:log-group:/aws/lambda/${terraform.workspace}-send-to-discovery:*"
      ]
    )
    error_message = "The Lambda policy template must include transfer bucket, KMS and CloudWatch Logs permissions."
  }

  assert {
    condition = (
      jsondecode(templatefile("${path.module}/templates/bucket_policy.json.tpl", {
        bucket_name       = module.pa_transfer_bucket.s3_bucket_name
        dr2_importer_role = var.dr2_importer_role_arn
        dr2_transfer_role = var.dr2_transfer_role_arn
      })).Statement[0].Principal.AWS == var.dr2_transfer_role_arn &&
      jsondecode(templatefile("${path.module}/templates/bucket_policy.json.tpl", {
        bucket_name       = module.pa_transfer_bucket.s3_bucket_name
        dr2_importer_role = var.dr2_importer_role_arn
        dr2_transfer_role = var.dr2_transfer_role_arn
      })).Statement[1].Principal.AWS == var.dr2_importer_role_arn
    )
    error_message = "The transfer bucket policy must preserve the importer and transfer role permissions."
  }
}
