data "aws_caller_identity" "current" {}

module "terraform_read_only_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${var.environment}-terraform-read-only"
  policy_string = templatefile("${path.module}/templates/iam/terraform_read_only.json.tpl", {
    account_id  = data.aws_caller_identity.current.account_id
    environment = var.environment
    layer_arn   = var.layer_arn
  })
}

module "terraform_write_policy" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_policy"
  name   = "${var.environment}-terraform-write"
  policy_string = templatefile("${path.module}/templates/iam/terraform_write.json.tpl", {
    account_id  = data.aws_caller_identity.current.account_id
    environment = var.environment
  })
}

module "terraform_plan_role" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  name   = "${var.environment}-terraform-plan"
  assume_role_policy = templatefile("${path.module}/templates/iam/assume_role.json.tpl", {
    account_id  = data.aws_caller_identity.current.account_id
    environment = var.environment
  })
  policy_attachments = {
    plan_policy = module.terraform_read_only_policy.policy_arn
  }
  tags = {}
}

module "terraform_apply_role" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  name   = "${var.environment}-terraform-apply"
  assume_role_policy = templatefile("${path.module}/templates/iam/assume_role.json.tpl", {
    account_id  = data.aws_caller_identity.current.account_id
    environment = var.environment
  })
  policy_attachments = {
    plan_policy  = module.terraform_read_only_policy.policy_arn
    apply_policy = module.terraform_write_policy.policy_arn
  }
  tags = {}
}
