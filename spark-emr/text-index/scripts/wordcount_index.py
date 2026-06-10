from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    input_file_name, split, explode, lower, col, trim, length,
    sum as _sum, collect_set, concat_ws
)

spark = SparkSession.builder.appName("WordCount-InvertedIndex") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.adaptive.skewJoin.enabled", "true") \
    .getOrCreate()

INPUT_PATH = "s3://onpe-datalake-mx/resultados_finales_csv_v5_split/"
WC_OUTPUT  = "s3://onpe-datalake-mx/query_results/word_count/"
II_OUTPUT  = "s3://onpe-datalake-mx/query_results/inverted_index/"

raw = spark.read.text(INPUT_PATH).withColumn("file", input_file_name())

tokens = raw.select(
    col("file"),
    explode(split(lower(col("value")), "[^a-z0-9]+")).alias("word")
).filter(length(trim(col("word"))) > 0)

word_counts = tokens.groupBy("file", "word").count()
word_counts.cache()

word_counts.groupBy("word").agg(_sum("count").alias("total_occurrences")) \
    .orderBy(col("total_occurrences").desc()) \
    .coalesce(1) \
    .write.mode("overwrite").option("header", "true").csv(WC_OUTPUT)

word_counts.groupBy("word").agg(
    concat_ws(",", collect_set("file")).alias("file_list")
).coalesce(1) \
    .write.mode("overwrite").option("header", "true").csv(II_OUTPUT)

spark.stop()
