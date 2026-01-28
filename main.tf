

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
data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.project}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:ListBucket",
      "codecommit:GitPull",
      "codecommit:GetBranch",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:BatchGetProjects",
      "iam:PassRole",
      "codestar-connections:UseConnection",
      "codeconnections:UseConnection"
               
    ]
    resources = ["*"]
  }
 
}
  
  


resource "aws_iam_role_policy" "codepipeline_policy_attach" {
  name   = "${var.project}-codepipeline-policy"
  role   = aws_iam_role.codepipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
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
          "sagemaker:ListPipelineExecutions",
          "s3:*"
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
  name     = "bpl-pipeline"
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
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "arn:aws:codeconnections:eu-west-1:361509912577:connection/9c948075-73f7-4c60-8d1a-2539faa9ba9f"
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
