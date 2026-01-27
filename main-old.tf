# terraform {
#   required_version = ">= 1.4.0"

#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# provider "aws" {
#   region = var.region
# }



# ############################
# # SageMaker Execution Role
# ############################
# resource "aws_iam_role" "sagemaker_role" {
#   name = "bpl-sagemaker-execution-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "sagemaker.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }
# resource "aws_iam_role_policy" "sagemaker_policy" {
#   role = aws_iam_role.sagemaker_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:ListBucket"
#         ]
#         Resource = "*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# resource "aws_s3_bucket" "timesheet_raw" {
#   bucket = "timesheet-raw-data-dev"
# }
# resource "aws_s3_bucket" "dq_results" {
#   bucket = "timesheet-dq-results-dev"
# }

# resource "aws_sagemaker_pipeline" "dq_pipeline" {
#   pipeline_name         = "bpl-dq-pipeline"
#   pipeline_display_name = "TimesheetTimeline"
#   role_arn              = aws_iam_role.sagemaker_role.arn

#   pipeline_definition = jsonencode({
#     Version = "2020-12-01"

#     Parameters = [
#       {
#         Name = "InputData"
#         Type = "String"
#         DefaultValue = "s3://bpl-ml-artifacts-234}/input/"
#       }
#     ]

#     Steps = [
#       {
#         Name = "DataQualityCheck"
#         Type = "Processing"
#         Arguments = {
#           AppSpecification = {
#             ImageUri = "763104351884.dkr.ecr.${var.region}.amazonaws.com/sagemaker-processing-container:latest"
#           }

#           ProcessingResources = {
#             ClusterConfig = {
#               InstanceType  = "ml.m5.large"
#               InstanceCount = 1
#               VolumeSizeInGB = 30
#             }
#           }

#           ProcessingInputs = [{
#             InputName = "input"
#             S3Input = {
#               S3Uri = { "Get" = "Parameters.InputData" }
#               LocalPath = "/opt/ml/processing/input"
#               S3DataType = "S3Prefix"
#             }
#           }]

#         #   ProcessingOutputs = [{
#         #     OutputName = "dq-output"
#         #     S3Output = {
#         #       S3Uri = "s3://s3://bpl-ml-artifacts-234//results/"
#         #       LocalPath = "/opt/ml/processing/output"
#         #     }
#         #   }]
#         }
#       }
#     ]
#   })
# }
