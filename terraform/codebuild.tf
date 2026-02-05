resource "aws_codebuild_project" "start_pipeline" {
  name         = "start-sagemaker-pipeline-dev"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "PIPELINE_NAME"
      value = aws_sagemaker_pipeline.smoke_test.pipeline_name
    }
  }
}
