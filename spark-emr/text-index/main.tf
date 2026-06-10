terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "my_datalake_bucket" {
  type        = string
  description = "The name of your personal S3 bucket for the Learner Lab"
  default     = "onpe-datalake-mx"
}

resource "aws_s3_object" "wordcount_script" {
  bucket = var.my_datalake_bucket
  key    = "artifacts/wordcount_index.py"
  source = "${path.module}/scripts/wordcount_index.py"
  etag   = filemd5("${path.module}/scripts/wordcount_index.py")
}

resource "aws_emr_cluster" "spark_text_index" {
  name          = "Spark-WordCount-InvertedIndex"
  release_label = "emr-6.15.0"
  applications  = ["Hadoop", "Spark"]

  service_role = "LabRole"

  ec2_attributes {
    instance_profile = "LabInstanceProfile"
  }

  master_instance_group {
    instance_type  = "m4.large"
    instance_count = 1
  }

  core_instance_group {
    instance_type  = "m4.large"
    instance_count = 2
  }

  log_uri = "s3://${var.my_datalake_bucket}/emr-logs/"

  tags = {
    Name        = "Spark-WordCount-InvertedIndex"
    Environment = "lab"
    Project     = "big-data"
  }

  step {
    name              = "Spark_WordCount_InvertedIndex"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar = "command-runner.jar"
      args = [
        "spark-submit",
        "--deploy-mode", "cluster",
        "--master", "yarn",
        "s3://${var.my_datalake_bucket}/artifacts/wordcount_index.py"
      ]
    }
  }

  keep_job_flow_alive_when_no_steps = false

  depends_on = [aws_s3_object.wordcount_script]
}
