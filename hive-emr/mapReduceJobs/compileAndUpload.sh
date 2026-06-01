#!/bin/bash
set -e

S3_PATH="s3://onpe-datalake-mx/artifacts"
CLASSPATH="hadoop-common-3.3.6.jar:hadoop-mapreduce-client-core-3.3.6.jar:commons-cli-1.2.jar"
JOBS=("InvertedIndex" "WordCount")

# Download required libraries
wget -q -nc https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/3.3.6/hadoop-common-3.3.6.jar
wget -q -nc https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-mapreduce-client-core/3.3.6/hadoop-mapreduce-client-core-3.3.6.jar
wget -q -nc https://repo1.maven.org/maven2/commons-cli/commons-cli/1.2/commons-cli-1.2.jar

# Compile, package, and upload
for JOB in "${JOBS[@]}"; do
    echo "Processing ${JOB}..."
    javac -source 1.8 -target 1.8 -cp "$CLASSPATH" "${JOB}.java"
    jar cf "${JOB}.jar" ${JOB}*.class
    aws s3 cp "${JOB}.jar" "${S3_PATH}/${JOB}.jar" > /dev/null
done

rm -f *.class
echo "Done."
