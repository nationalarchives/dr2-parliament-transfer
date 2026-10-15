# DR2 Parliament Transfer

This repository provisions the AWS infrastructure and Lambda function that transfers files from the DR2 Parliament
transfer bucket into the existing CTD data-processing bucket and publishes replica metadata for Discovery.

## How it works

1. A `.metadata` object and and accompanying file are uploaded to the transfer bucket using the adhoc ingest script.
2. An S3 notification sends an event to an SQS queue.
3. The `send-to-discovery` Lambda reads the metadata and the corresponding asset files from the transfer bucket.
4. Files are copied to the CTD bucket under `files/{IAID}/`. TIFF files (`.tif` and `.tiff`) are converted to JPEG using
   the ImageMagick Lambda layer; other files are copied without conversion.
5. The Lambda writes a replica metadata document to `metadata/{IAID}.json` in the CTD bucket.

The metadata input is a JSON array. Each file entry must include:

| Field             | Description                                                                     |
|-------------------|---------------------------------------------------------------------------------|
| `UUID`            | Asset identifier; files are read from `{UUID}/{fileId}` in the transfer bucket. |
| `IAID`            | Identifier used in the output object paths.                                     |
| `fileId`          | File identifier and part of the source object key.                              |
| `Filename`        | Original filename, including its extension.                                     |
| `checksum_sha256` | Checksum included in the output replica metadata.                               |

`digitalAssetSource` is optional; when omitted, the output `origination` is `Born Digital`. Output metadata includes
each file's checksum, format, name, original filename and size, along with the replica ID, origination and total size.
File sizes are truncated to whole decimal kilobytes.

## AWS infrastructure

Terraform creates an environment-prefixed transfer bucket, S3-to-SQS notification, encrypted SQS queue and dead-letter
queue, and a Python 3.14 Lambda function.

Resource names use the active Terraform workspace:

- Transfer bucket: `{workspace}-pa-transfer`
- Queue and Lambda: `{workspace}-send-to-discovery`
- CTD bucket: `{workspace}-dtp-data-processing-bucket`

The `bootstrap/` Terraform module also provisions environment-specific Terraform plan and apply IAM roles and policies.
The root configuration manages the GitHub Actions OIDC provider in the `dev` workspace. This provider can only be
created once.

## Prerequisites

- Terraform `>= 1.7.0, < 2.0.0`
- Python 3.14 and pip
- AWS credentials with permissions for the configured account and region (`eu-west-2`)
- Access to the remote Terraform state bucket, `pa-transfer-terraform-state-bucket`
- The existing CTD KMS key, importer and transfer IAM roles, and ImageMagick Lambda layer

## Configuration

The root Terraform module requires these input variables. Supply them through `TF_VAR_*` environment variables or an
uncommitted `.tfvars` file.

| Variable                | Description                                                    |
|-------------------------|----------------------------------------------------------------|
| `layer_version_arn`     | ARN of the existing ImageMagick Lambda layer version.          |
| `ctd_kms_key_arn`       | ARN of the KMS key used by the CTD bucket.                     |
| `dr2_importer_role_arn` | IAM role for the DR2 importer lambda                           |
| `dr2_transfer_role_arn` | IAM role used by the archivists to run the adhoc ingest script |

The Terraform S3 backend is configured in `provider.tf`. Terraform workspaces identify environments; the deployment
workflow uses `dev`, `staging` and `prod`.

## Build and test

Build the Lambda deployment archive before running Terraform:

```sh
scripts/build_lambda.sh
```

This installs `lambda/requirements.txt` into `package/` and creates `lambda.zip` in the repository root. Both generated
paths are ignored by Git.

Run the tests and formatting checks:

```sh
terraform fmt -check -recursive
terraform init -backend=false
terraform test
python -m pip install boto3 -r lambda/requirements.txt
python -m unittest discover -s lambda -p '*_test.py'
```

## Deploy

The GitHub Actions deployment workflow runs on pushes to `main` and on manual dispatch. It deploys to `dev`, `staging`
and `prod` using each GitHub environment's `DEPLOY_ROLE`, `CTD_KMS_KEY_ARN`, `DR2_IMPORTER_ROLE_ARN` and
`DR2_TRANSFER_ROLE_ARN` secrets. The workflow discovers the latest matching ImageMagick layer in `eu-west-2`.

To deploy manually, configure AWS credentials and the four Terraform variables, build the Lambda archive, then
initialise Terraform and select the target workspace:

```sh
export TF_VAR_layer_version_arn="<imagemagick-layer-version-arn>"
export TF_VAR_ctd_kms_key_arn="<ctd-kms-key-arn>"
export TF_VAR_dr2_importer_role_arn="<dr2-importer-role-arn>"
export TF_VAR_dr2_transfer_role_arn="<dr2-transfer-role-arn>"

scripts/build_lambda.sh
terraform init
terraform workspace select dev
terraform plan
terraform apply
```

Replace `dev` with the intended workspace. The workspace must already exist, and the configured state bucket and AWS
resources must be accessible before applying.
