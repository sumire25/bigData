from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_unixtime, month, year, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, LongType, DoubleType

spark = SparkSession.builder.appName("Taxi-ETL") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.adaptive.skewJoin.enabled", "true") \
    .config("spark.sql.parquet.enableVectorizedReader", "true") \
    .getOrCreate()

STAGING_PATH = "s3://onpe-datalake-mx/staging/yellow_taxi_2026/"
OUTPUT_PATH  = "s3://onpe-datalake-mx/warehouse/optimized_yellow_taxi/"

staging_schema = StructType([
    StructField("VendorID", IntegerType()),
    StructField("tpep_pickup_datetime", LongType()),
    StructField("tpep_dropoff_datetime", LongType()),
    StructField("passenger_count", LongType()),
    StructField("trip_distance", DoubleType()),
    StructField("RatecodeID", LongType()),
    StructField("store_and_fwd_flag", StringType()),
    StructField("PULocationID", IntegerType()),
    StructField("DOLocationID", IntegerType()),
    StructField("payment_type", LongType()),
    StructField("fare_amount", DoubleType()),
    StructField("extra", DoubleType()),
    StructField("mta_tax", DoubleType()),
    StructField("tip_amount", DoubleType()),
    StructField("tolls_amount", DoubleType()),
    StructField("improvement_surcharge", DoubleType()),
    StructField("total_amount", DoubleType()),
    StructField("congestion_surcharge", DoubleType()),
    StructField("Airport_fee", DoubleType()),
    StructField("cbd_congestion_fee", DoubleType()),
])

raw = spark.read.schema(staging_schema).parquet(STAGING_PATH)

optimized = raw.select(
    to_timestamp(
        from_unixtime(col("tpep_pickup_datetime") / 1000000)
    ).alias("tpep_pickup_datetime"),
    col("trip_distance"),
    col("payment_type"),
    col("total_amount")
).filter(year(col("tpep_pickup_datetime")) == 2026) \
 .withColumn("pickup_month", month(col("tpep_pickup_datetime")))

optimized.write.mode("overwrite") \
    .partitionBy("pickup_month") \
    .parquet(OUTPUT_PATH)

spark.stop()
