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

resource "aws_emr_cluster" "taxi_analytical_cluster" {
  name          = "NYC-Taxi-Analytical-Pipeline"
  release_label = "emr-6.15.0"
  applications  = ["Hadoop", "Hive"]
  
  # Strictly required for AWS Learner Lab environments
  service_role  = "LabRole" 

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

  # STEP 1: Using HTTPS
  step {
    name              = "Retrieve_2026_Taxi_Data_via_HTTPS"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar  = "command-runner.jar"
      args = [
        "bash",
        "-c",
        "for i in 01 02 03 04 05 06 07 08 09 10 11 12; do if wget -q https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2026-$i.parquet; then aws s3 cp yellow_tripdata_2026-$i.parquet s3://${var.my_datalake_bucket}/staging/yellow_taxi_2026/; rm yellow_tripdata_2026-$i.parquet; fi; done"
      ]
    }
  }
  
  # STEP 2: Hive Table
  step {
    name              = "Create_And_Partition_Tables"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar  = "command-runner.jar"
      args = [
        "hive",
        "-e",
        <<-EOF
        SET hive.exec.dynamic.partition = true;
        SET hive.exec.dynamic.partition.mode = nonstrict;
        SET hive.vectorized.execution.enabled = true;
        SET hive.vectorized.execution.reduce.enabled = true;

        -- 1. Staging Table schema matching the Parquet metadata
        CREATE EXTERNAL TABLE IF NOT EXISTS staging_yellow_taxi (
            VendorID INT,
            tpep_pickup_datetime BIGINT,
            tpep_dropoff_datetime BIGINT,
            passenger_count BIGINT,
            trip_distance DOUBLE,
            RatecodeID BIGINT,
            store_and_fwd_flag STRING,
            PULocationID INT,
            DOLocationID INT,
            payment_type BIGINT,
            fare_amount DOUBLE,
            extra DOUBLE,
            mta_tax DOUBLE,
            tip_amount DOUBLE,
            tolls_amount DOUBLE,
            improvement_surcharge DOUBLE,
            total_amount DOUBLE,
            congestion_surcharge DOUBLE,
            Airport_fee DOUBLE,
            cbd_congestion_fee DOUBLE
        )
        STORED AS PARQUET
        LOCATION 's3://${var.my_datalake_bucket}/staging/yellow_taxi_2026/';

        -- 2. Optimized Target Table
        CREATE EXTERNAL TABLE IF NOT EXISTS optimized_yellow_taxi (
            tpep_pickup_datetime TIMESTAMP,
            trip_distance DOUBLE,
            payment_type BIGINT,
            total_amount DOUBLE
        )
        PARTITIONED BY (pickup_month INT)
        STORED AS ORC
        LOCATION 's3://${var.my_datalake_bucket}/warehouse/optimized_yellow_taxi/';

        -- 3. Adds only the needed columns and partitions by month
        WITH converted_taxi AS (
            SELECT 
                CAST(from_unixtime(CAST(tpep_pickup_datetime / 1000000 AS BIGINT)) AS TIMESTAMP) AS clean_pickup_time,
                trip_distance,
                payment_type,
                total_amount
            FROM staging_yellow_taxi
        )
        INSERT OVERWRITE TABLE optimized_yellow_taxi PARTITION (pickup_month)
        SELECT 
            clean_pickup_time, 
            trip_distance, 
            payment_type, 
            total_amount, 
            MONTH(clean_pickup_time) AS pickup_month
        FROM converted_taxi
        WHERE YEAR(clean_pickup_time) = 2026;
        EOF
      ]
    }
  }

  # STEP 3: Analytical Query Execution
  step {
    name              = "Execute_Analytical_Queries"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar  = "command-runner.jar"
      args = [
        "hive",
        "-e",
        <<-EOF
        -- Query A: Total trips and average distance
        INSERT OVERWRITE DIRECTORY 's3://${var.my_datalake_bucket}/query_results/metrics_summary/'
        ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
        SELECT COUNT(1) AS total_trips, AVG(trip_distance) AS avg_distance 
        FROM optimized_yellow_taxi;

        -- Query B: Peak traffic hours
        INSERT OVERWRITE DIRECTORY 's3://${var.my_datalake_bucket}/query_results/traffic_hours/'
        ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
        SELECT HOUR(tpep_pickup_datetime) AS traffic_hour, COUNT(1) AS total_trips
        FROM optimized_yellow_taxi
        GROUP BY HOUR(tpep_pickup_datetime)
        ORDER BY total_trips DESC;

        -- Query C: Payment methods utilized
        INSERT OVERWRITE DIRECTORY 's3://${var.my_datalake_bucket}/query_results/payment_methods/'
        ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
        SELECT payment_type, COUNT(1) AS usage_count
        FROM optimized_yellow_taxi
        GROUP BY payment_type;

        -- Query D: Top 10 expensive trips
        INSERT OVERWRITE DIRECTORY 's3://${var.my_datalake_bucket}/query_results/expensive_trips/'
        ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
        SELECT tpep_pickup_datetime, trip_distance, total_amount
        FROM optimized_yellow_taxi
        ORDER BY total_amount DESC
        LIMIT 10;

        -- Query E: January 2026 Metrics
        INSERT OVERWRITE DIRECTORY 's3://${var.my_datalake_bucket}/query_results/january_metrics/'
        ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
        SELECT HOUR(tpep_pickup_datetime) AS hour, 
               AVG(total_amount) as avg_cost, 
               AVG(trip_distance) as avg_distance
        FROM optimized_yellow_taxi
        WHERE pickup_month = 1
        GROUP BY HOUR(tpep_pickup_datetime);

        -- Query F: February 2026 Metrics
        INSERT OVERWRITE DIRECTORY 's3://${var.my_datalake_bucket}/query_results/february_metrics/'
        ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
        SELECT HOUR(tpep_pickup_datetime) AS hour, 
               AVG(total_amount) as avg_cost, 
               AVG(trip_distance) as avg_distance
        FROM optimized_yellow_taxi
        WHERE pickup_month = 2
        GROUP BY HOUR(tpep_pickup_datetime);
        EOF
      ]
    }
  }

  keep_job_flow_alive_when_no_steps = false
}
