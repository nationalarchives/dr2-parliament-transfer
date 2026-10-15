{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LocateTerraformStateBucket",
      "Effect": "Allow",
      "Action": "s3:GetBucketLocation",
      "Resource": "arn:aws:s3:::pa-transfer-terraform-state-bucket"
    },
    {
      "Sid": "ListTerraformStateBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::pa-transfer-terraform-state-bucket"
    },
    {
      "Sid": "ReadTerraformStateObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": [
        "arn:aws:s3:::pa-transfer-terraform-state-bucket/env:/${environment}/terraform.state",
        "arn:aws:s3:::pa-transfer-terraform-state-bucket/env:/${environment}/terraform.state.tflock"
      ]
    },
    {
      "Sid": "ManageTerraformStateLocks",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::pa-transfer-terraform-state-bucket/env:/${environment}/terraform.state.tflock"
      ]
    },
    {
      "Sid": "ReadLambdaConfiguration",
      "Effect": "Allow",
      "Action": [
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:GetPolicy",
        "lambda:ListVersionsByFunction",
        "lambda:GetFunctionCodeSigningConfig"
      ],
      "Resource": [
        "arn:aws:lambda:eu-west-2:${account_id}:function:${environment}-send-to-discovery"
      ]
    },
    {
      "Sid": "ReadLambdaEventSourceMappings",
      "Effect": "Allow",
      "Action": [
        "lambda:GetEventSourceMapping",
        "lambda:ListTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ReadConfiguredLambdaLayers",
      "Effect": "Allow",
      "Action": [
        "lambda:GetLayerVersion"
      ],
      "Resource": "${layer_arn}"
    },
    {
      "Sid": "ListLambdaLayers",
      "Effect": "Allow",
      "Action": "lambda:ListLayers",
      "Resource": "*"
    },
    {
      "Sid": "WriteTerraformPolicy",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:GetPolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:ListPolicyVersions",
        "iam:GetPolicyVersion"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:role/${environment}-terraform-plan",
        "arn:aws:iam::${account_id}:role/${environment}-terraform-apply",
        "arn:aws:iam::${account_id}:policy/${environment}-terraform-read-only",
        "arn:aws:iam::${account_id}:policy/${environment}-terraform-write"
      ]
    },
    {
      "Sid": "ReadLambdaExecutionRole",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:ListPolicyVersions"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:role/${environment}-send-to-discovery-role"
      ]
    },
    {
      "Sid": "ReadLambdaExecutionPolicies",
      "Effect": "Allow",
      "Action": [
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:policy/${environment}_send_to_discovery_policy"
      ]
    },
    {
      "Sid": "ReadQueues",
      "Effect": "Allow",
      "Action": [
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ListQueueTags"
      ],
      "Resource": [
        "arn:aws:sqs:eu-west-2:${account_id}:${environment}-send-to-discovery",
        "arn:aws:sqs:eu-west-2:${account_id}:${environment}-send-to-discovery-dlq"
      ]
    },
    {
      "Sid": "ReadTransferBuckets",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketAcl",
        "s3:GetBucketAccelerateConfiguration",
        "s3:GetBucketCors",
        "s3:GetBucketLocation",
        "s3:GetBucketLogging",
        "s3:GetBucketNotification",
        "s3:GetBucketObjectLockConfiguration",
        "s3:GetBucketPolicy",
        "s3:GetBucketPolicyStatus",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketOwnershipControls",
        "s3:GetBucketReplication",
        "s3:GetBucketRequestPayment",
        "s3:GetBucketTagging",
        "s3:GetBucketVersioning",
        "s3:GetBucketWebsite",
        "s3:GetEncryptionConfiguration",
        "s3:GetLifecycleConfiguration",
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${environment}-pa-transfer",
        "arn:aws:s3:::${environment}-pa-transfer-logs"
      ]
    },
    {
      "Sid": "ReadLambdaLogGroups",
      "Effect": "Allow",
      "Action": "logs:ListTagsForResource",
      "Resource": [
        "arn:aws:logs:eu-west-2:${account_id}:log-group:/aws/lambda/${environment}-send-to-discovery"
      ]
    },
    {
      "Sid": "DescribeLambdaLogGroups",
      "Effect": "Allow",
      "Action": "logs:DescribeLogGroups",
      "Resource": "*"
    },
    {
      "Sid": "DescribeQueueAlarms",
      "Effect": "Allow",
      "Action": "cloudwatch:DescribeAlarms",
      "Resource": "*"
    },
    {
      "Sid": "ReadQueueAlarmTags",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:ListTagsForResource"
      ],
      "Resource": [
        "arn:aws:cloudwatch:eu-west-2:${account_id}:alarm:${environment}-send-to-discovery*"
      ]
    }
  ]
}
