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

resource "aws_emr_cluster" "map_reduce_cluster" {
  name          = "MapReduce-Jobs"
  release_label = "emr-6.15.0"
  applications  = ["Hadoop"]

  # The role for the EMR service
  service_role = "LabRole"

  ec2_attributes {
    # The profile container for the EC2 instances
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
  
  log_uri = "s3://onpe-datalake-mx/emr-logs/"

  # Step 1: Execute the Inverted Index Job
  step {
    name              = "Execute_Inverted_Index"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar        = "s3://onpe-datalake-mx/artifacts/InvertedIndex.jar"
      main_class = "InvertedIndex"
      
      args = [
        "s3://onpe-datalake-mx/resultados_finales_csv_v5_split",
        "s3://onpe-datalake-mx/query_results/inverted_index_mr/"
      ]
    }
  }

  # Step 2: Execute the Word Count Job
  step {
    name              = "Execute_Word_Count"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar        = "s3://onpe-datalake-mx/artifacts/WordCount.jar"
      main_class = "WordCount"
      
      args = [
        "s3://onpe-datalake-mx/resultados_finales_csv_v5_split",
        "s3://onpe-datalake-mx/query_results/word_count_mr/"
      ]
    }
  }

  keep_job_flow_alive_when_no_steps = false
}
