{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WriteTerraformState",
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": [
        "arn:aws:s3:::pa-transfer-terraform-state-bucket/env:/${environment}/terraform.state"
      ]
    },
    {
      "Sid": "ManageLambdaFunctions",
      "Effect": "Allow",
      "Action": [
        "lambda:AddPermission",
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:RemovePermission",
        "lambda:TagResource",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration"
      ],
      "Resource": [
        "arn:aws:lambda:eu-west-2:${account_id}:function:${environment}-send-to-discovery"
      ]
    },
    {
      "Sid": "WriteTerraformPolicy",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:CreatePolicy",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicy",
        "iam:SetDefaultPolicyVersion",
        "iam:TagPolicy",
        "iam:UntagPolicy",
        "iam:DeletePolicyVersion",
        "iam:GetOpenIDConnectProvider"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:policy/${environment}-terraform-read-only",
        "arn:aws:iam::${account_id}:policy/${environment}-terraform-write",
        "arn:aws:iam::${account_id}:role/${environment}-terraform-plan",
        "arn:aws:iam::${account_id}:role/${environment}-terraform-apply",
        "arn:aws:iam::${account_id}:oidc-provider/token.actions.githubusercontent.com"
      ]
    },
    {
      "Sid": "ManageLambdaEventSourceMappings",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateEventSourceMapping",
        "lambda:DeleteEventSourceMapping",
        "lambda:UpdateEventSourceMapping"
      ],
      "Resource": [
        "arn:aws:lambda:eu-west-2:${account_id}:function:${environment}-send-to-discovery",
        "arn:aws:sqs:eu-west-2:${account_id}:${environment}-send-to-discovery",
        "arn:aws:lambda:eu-west-2:${account_id}:event-source-mapping:*"
      ]
    },
    {
      "Sid": "PassLambdaExecutionRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::${account_id}:role/${environment}-send-to-discovery-role"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "lambda.amazonaws.com"
        }
      }
    },
    {
      "Sid": "ManageLambdaExecutionRoles",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:UpdateAssumeRolePolicy"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:role/${environment}-send-to-discovery-role"
      ]
    },
    {
      "Sid": "ManageLambdaExecutionPolicies",
      "Effect": "Allow",
      "Action": [
        "iam:CreatePolicy",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicy",
        "iam:DeletePolicyVersion",
        "iam:SetDefaultPolicyVersion",
        "iam:TagPolicy",
        "iam:UntagPolicy"
      ],
      "Resource": "arn:aws:iam::${account_id}:policy/${environment}_send_to_discovery_policy"
    },
    {
      "Sid": "AttachLambdaExecutionPolicies",
      "Effect": "Allow",
      "Action": [
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:role/${environment}-send-to-discovery-role"
      ]
    },
    {
      "Sid": "ManageQueues",
      "Effect": "Allow",
      "Action": [
        "sqs:CreateQueue",
        "sqs:DeleteQueue",
        "sqs:SetQueueAttributes",
        "sqs:TagQueue",
        "sqs:UntagQueue"
      ],
      "Resource": [
        "arn:aws:sqs:eu-west-2:${account_id}:${environment}-send-to-discovery",
        "arn:aws:sqs:eu-west-2:${account_id}:${environment}-send-to-discovery-dlq"
      ]
    },
    {
      "Sid": "ManageTransferBuckets",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:DeleteBucketEncryption",
        "s3:DeleteBucketPolicy",
        "s3:DeleteBucketPublicAccessBlock",
        "s3:DeleteBucketTagging",
        "s3:DeleteLifecycleConfiguration",
        "s3:GetAccelerateConfiguration",
        "s3:PutBucketLogging",
        "s3:PutBucketNotification",
        "s3:PutBucketPolicy",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketTagging",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration"
      ],
      "Resource": [
        "arn:aws:s3:::${environment}-pa-transfer",
        "arn:aws:s3:::${environment}-pa-transfer-logs"
      ]
    },
    {
      "Sid": "ManageLambdaLogGroups",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DeleteRetentionPolicy",
        "logs:PutRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource"
      ],
      "Resource": [
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/aws/lambda/${environment}-send-to-discovery"
      ]
    },
    {
      "Sid": "ManageQueueAlarms",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:DeleteAlarms",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:TagResource",
        "cloudwatch:UntagResource"
      ],
      "Resource": [
        "arn:aws:cloudwatch:eu-west-2:${account_id}:alarm:${environment}-send-to-discovery*"
      ]
    }
  ]
}