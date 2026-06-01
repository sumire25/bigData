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

resource "aws_emr_cluster" "hive_cluster" {
  name          = "Pure-Hive-Single-Scan-Index"
  release_label = "emr-6.15.0"
  applications  = ["Hadoop", "Hive"]

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
  
  log_uri = "s3://onpe-datalake-mx/emr-logs/"

  step {
    name              = "Execute_Pure_Hive_Pipeline"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar  = "command-runner.jar"
      
      args = [
        "hive",
        "-e",
        <<-EOF
        CREATE EXTERNAL TABLE IF NOT EXISTS raw_docs (
            line STRING
        ) 
        STORED AS TEXTFILE 
        LOCATION 's3://onpe-datalake-mx/resultados_finales_csv_v5_split/';

        FROM (
            SELECT 
                INPUT__FILE__NAME as file, 
                word, 
                COUNT(1) as count 
            FROM raw_docs 
            LATERAL VIEW explode(split(lower(line), '[^a-z0-9]+')) adTable AS word 
            WHERE word != '' 
            GROUP BY INPUT__FILE__NAME, word
        ) aggregated_words
        
        -- Complete Word Count
        INSERT OVERWRITE DIRECTORY 's3://onpe-datalake-mx/query_results/word_count/' 
        ROW FORMAT DELIMITED 
        FIELDS TERMINATED BY ',' 
        SELECT 
            word, 
            SUM(count) as total_occurrences 
        GROUP BY word 
        ORDER BY total_occurrences DESC
        
        -- Complete Inverted Index
        INSERT OVERWRITE DIRECTORY 's3://onpe-datalake-mx/query_results/inverted_index/' 
        ROW FORMAT DELIMITED 
        FIELDS TERMINATED BY '\t' 
        SELECT 
            word, 
            concat_ws(',', collect_set(file)) as file_list 
        GROUP BY word;
        EOF
      ]
    }
  }

  keep_job_flow_alive_when_no_steps = false
}