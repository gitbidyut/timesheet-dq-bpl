

resource "aws_iam_role" "sagemaker_role" {
  name = "sagemaker-dq-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sagemaker_policy" {
  role = aws_iam_role.sagemaker_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish", "logs:*"]
        Resource = "*"
      }
    ]
  })
}


resource "aws_s3_bucket" "timesheet_raw" {
  bucket = "timesheet-raw-data-bpl-${var.env}"
}

resource "aws_s3_bucket" "dq_results" {
  bucket = "timesheet-dq-results-bpl-${var.env}"
}
############################
# CodePipeline Artifact Bucket
############################
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "bpl-codepipeline-artifacts"

  force_destroy = true
}

resource "aws_s3_bucket_versioning" "artifact_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# resource "aws_sagemaker_processing_job" "data_quality" {
#   name = "timesheet-data-quality-${var.env}"
#   role_arn = aws_iam_role.sagemaker_role.arn

#   processing_resources {
#     cluster_config {
#       instance_type  = "ml.m5.large"
#       instance_count = 1
#       volume_size_in_gb = 30
#     }
#   }

#   app_specification {
#     image_uri = "763104351884.dkr.ecr.${var.region}.amazonaws.com/sagemaker-processing-container:latest"
#     container_entrypoint = ["python3", "/opt/ml/processing/code/data_quality.py"]
#   }

#   processing_inputs {
#     input_name = "input-data"
#     s3_input {
#       s3_uri = "s3://${aws_s3_bucket.timesheet_raw.bucket}/input/"
#       local_path = "/opt/ml/processing/input"
#     }
#   }

#   processing_outputs {
#     output_name = "dq-results"
#     s3_output {
#       s3_uri = "s3://${aws_s3_bucket.dq_results.bucket}/results/"
#       local_path = "/opt/ml/processing/output"
#     }
#   }
# }


resource "aws_sns_topic" "dq_alerts" {
  name = "data-quality-alerts-bpl"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.dq_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
############################
# IAM Role for CodePipeline
############################
resource "aws_iam_role" "codepipeline_role" {
  name = "bpl-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
      }
    ]
  })
}


resource "aws_iam_role" "codebuild_role" {
  name = "bpl-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:StartPipelineExecution",
          "sagemaker:DescribePipeline",
          "sagemaker:ListPipelineExecutions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
resource "aws_codebuild_project" "tf_project" {
  name         = "bpl-start-sm-pipeline"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false

    # environment_variable {
    #   name  = "PIPELINE_NAME"
    #   value = aws_sagemaker_pipeline.dq_pipeline.pipeline_name
    # }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/bpl"
      stream_name = "start-sagemaker-pipeline"
    }
  }
}


resource "aws_codepipeline" "dq_pipeline" {
  name     = "$bpl-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  ############################
  # REQUIRED Artifact Store
  ############################
  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.codepipeline_artifacts.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "arn:aws:codeconnections:us-east-1:361509912577:connection/09caa1e3-a6ab-45df-be90-10c14777466b"
        FullRepositoryId = "gitbidyut/timesheet-dq-bpl" # e.g., "myuser/my-repo"
        #RepositoryName = aws_codecommit_repository.app_repo.repository_name
        BranchName     = "main"
        
      }
    }
  }

  stage {
    name = "Terraform_Deploy"

    action {
      name             = "TerraformApply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]

      configuration = {
        ProjectName = aws_codebuild_project.tf_project.name
      }
    }
  }
}
