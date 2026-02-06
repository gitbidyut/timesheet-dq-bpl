resource "aws_sagemaker_pipeline" "smoke_test" {
  pipeline_name         = "sm-pipeline-smoketest"
  pipeline_display_name = "SageMaker-smoke-Test"
  role_arn              = aws_iam_role.sagemaker_role.arn

  pipeline_definition = jsonencode({
    Version = "2020-12-01"
    Parameters = [
      {
        Name = "InputDataS3"
        Type = "String"
        DefaultValue = "s3://${aws_s3_bucket.raw.bucket}/input/"
      }
    ]
    Steps = [
      {
        Name = "ProcessingSmokeTest"
        Type = "Processing"
        
        Arguments = {
          AppSpecification = {
             ImageUri = "${aws_ecr_repository.dq_repo.repository_url}:latest"
             ContainerEntrypoint = [
                   "python3",
                  "/opt/ml/processing/code/data_quality.py"
          ]
      }


          ProcessingResources = {
            ClusterConfig = {
              InstanceType   = "ml.t3.medium"
              InstanceCount  = 1
              VolumeSizeInGB = 30
            }
          }
           ProcessingInputs = [
            {
              InputName = "input"
              S3Input = {
                S3Uri      = { "Get" = "Parameters.InputDataS3" }
                LocalPath = "/opt/ml/processing/input"
                S3DataType = "S3Prefix"
              }
            }
          ]
          ProcessingOutputConfig = {
            Outputs = [
            {
              OutputName = "dq-output"
              S3Output = {
              S3Uri      = "s3://${aws_s3_bucket.results.bucket}/results/"
              LocalPath = "/opt/ml/processing/output"
              S3UploadMode = "EndOfJob"
            }
           }
         ]
        }
      }
    ]
  })
}
