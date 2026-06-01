#!/bin/bash

HADOOP_BIN="/usr/local/hadoop/bin/hdfs"
INPUT_FILE="s3a://onpe-datalake-mx/resultados_finales_csv_v5/part-00000"
SPLIT_LOCAL_DIR="/tmp/split_csv"
SPLIT_S3_DIR="s3a://onpe-datalake-mx/resultados_finales_csv_v5_split"
OUTPUT_DIR="s3a://onpe-datalake-mx/output"

# 1. Prepare local temporary directory
rm -rf $SPLIT_LOCAL_DIR
mkdir -p $SPLIT_LOCAL_DIR

# 2. Download locally, split into exactly 60 chunks, then delete the large original
$HADOOP_BIN dfs -get $INPUT_FILE $SPLIT_LOCAL_DIR/full_file.csv
split -n l/60 -d $SPLIT_LOCAL_DIR/full_file.csv "$SPLIT_LOCAL_DIR/chunk_"
rm $SPLIT_LOCAL_DIR/full_file.csv

# 3. Upload the chunks back to the datalake
$HADOOP_BIN dfs -mkdir -p $SPLIT_S3_DIR
$HADOOP_BIN dfs -put $SPLIT_LOCAL_DIR/* $SPLIT_S3_DIR/

# 4. Remove existing output directory if it exists to avoid job failure
$HADOOP_BIN dfs -rm -r -skipTrash $OUTPUT_DIR || true

# 5. Launch MapReduce job to create the inverted index

# 1. Locate the exact paths of the required AWS Java libraries
AWS_JAR=$(ls /usr/local/hadoop/share/hadoop/tools/lib/hadoop-aws-*.jar)
SDK_JAR=$(ls /usr/local/hadoop/share/hadoop/tools/lib/aws-java-sdk-bundle-*.jar)

# 2. Execute the job with the injected libraries
mapred streaming \
  -libjars $AWS_JAR,$SDK_JAR \
  -D mapreduce.map.memory.mb=512 \
  -D mapreduce.reduce.memory.mb=512 \
  -D yarn.app.mapreduce.am.resource.mb=512 \
  -D mapreduce.task.io.sort.mb=128 \
  -files mapper.py,reducer.py \
  -inputformat org.apache.hadoop.mapred.lib.CombineTextInputFormat \
  -mapper "python3 mapper.py" \
  -reducer "python3 reducer.py" \
  -input $SPLIT_S3_DIR \
  -output $OUTPUT_DIR
