resource "aws_sagemaker_pipeline" "dq_pipeline" {
  pipeline_name         = "timesheet-edfx-${var.env}"
  pipeline_display_name = "pipe-line-bpl"
  role_arn              = aws_iam_role.sagemaker_role.arn

  pipeline_definition = jsonencode({
    Version = "2020-12-01"

    Parameters = [
      {
        Name = "InputDataS3"
        Type = "String"
        DefaultValue = "s3://${aws_s3_bucket.timesheet_raw.bucket}/input/"
      }
    ]

    Steps = [
      {
        Name = "DataQualityCheck"
        Type = "Processing"
        Arguments = {
          AppSpecification = {
            ImageUri = "763104351884.dkr.ecr.${var.region}.amazonaws.com/sagemaker-processing-container:latest"
          }

          ProcessingResources = {
            ClusterConfig = {
              InstanceType   = "ml.m5.large"
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
              S3Uri      = "s3://${aws_s3_bucket.dq_results.bucket}/results/"
              LocalPath = "/opt/ml/processing/output"
              S3UploadMode = "EndOfJob"
            }
           }
         ]
        }

      }
     }
    ]
  })
} 
