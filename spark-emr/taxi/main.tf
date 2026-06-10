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

resource "aws_s3_object" "etl_script" {
  bucket = var.my_datalake_bucket
  key    = "artifacts/taxi_etl.py"
  source = "${path.module}/scripts/taxi_etl.py"
  etag   = filemd5("${path.module}/scripts/taxi_etl.py")
}

resource "aws_s3_object" "queries_script" {
  bucket = var.my_datalake_bucket
  key    = "artifacts/taxi_queries.py"
  source = "${path.module}/scripts/taxi_queries.py"
  etag   = filemd5("${path.module}/scripts/taxi_queries.py")
}

resource "aws_emr_cluster" "spark_taxi_pipeline" {
  name          = "Spark-Taxi-Analytical-Pipeline"
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
    instance_count = 4
  }

  log_uri = "s3://${var.my_datalake_bucket}/emr-logs/"

  tags = {
    Name        = "Spark-Taxi-Analytical-Pipeline"
    Environment = "lab"
    Project     = "big-data"
  }

  step {
    name              = "Spark_Taxi_ETL"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar = "command-runner.jar"
      args = [
        "spark-submit",
        "--deploy-mode", "cluster",
        "--master", "yarn",
        "s3://${var.my_datalake_bucket}/artifacts/taxi_etl.py"
      ]
    }
  }

  step {
    name              = "Spark_Taxi_Queries"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar = "command-runner.jar"
      args = [
        "spark-submit",
        "--deploy-mode", "cluster",
        "--master", "yarn",
        "s3://${var.my_datalake_bucket}/artifacts/taxi_queries.py"
      ]
    }
  }

  keep_job_flow_alive_when_no_steps = false

  depends_on = [aws_s3_object.etl_script, aws_s3_object.queries_script]
}
