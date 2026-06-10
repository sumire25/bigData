from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("Taxi-Queries") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.adaptive.skewJoin.enabled", "true") \
    .getOrCreate()

INPUT_PATH   = "s3://onpe-datalake-mx/warehouse/optimized_yellow_taxi/"
RESULTS_BASE = "s3://onpe-datalake-mx/query_results/"

df = spark.read.parquet(INPUT_PATH)
df.createOrReplaceTempView("optimized_yellow_taxi")

queries = [
    ("metrics_summary", """
        SELECT COUNT(1) AS total_trips, AVG(trip_distance) AS avg_distance
        FROM optimized_yellow_taxi
    """),
    ("traffic_hours", """
        SELECT HOUR(tpep_pickup_datetime) AS traffic_hour, COUNT(1) AS total_trips
        FROM optimized_yellow_taxi
        GROUP BY HOUR(tpep_pickup_datetime)
        ORDER BY total_trips DESC
    """),
    ("payment_methods", """
        SELECT payment_type, COUNT(1) AS usage_count
        FROM optimized_yellow_taxi
        GROUP BY payment_type
    """),
    ("expensive_trips", """
        SELECT tpep_pickup_datetime, trip_distance, total_amount
        FROM optimized_yellow_taxi
        ORDER BY total_amount DESC
        LIMIT 10
    """),
    ("january_metrics", """
        SELECT HOUR(tpep_pickup_datetime) AS hour,
               AVG(total_amount) AS avg_cost,
               AVG(trip_distance) AS avg_distance
        FROM optimized_yellow_taxi
        WHERE pickup_month = 1
        GROUP BY HOUR(tpep_pickup_datetime)
    """),
    ("february_metrics", """
        SELECT HOUR(tpep_pickup_datetime) AS hour,
               AVG(total_amount) AS avg_cost,
               AVG(trip_distance) AS avg_distance
        FROM optimized_yellow_taxi
        WHERE pickup_month = 2
        GROUP BY HOUR(tpep_pickup_datetime)
    """)
]

for name, sql in queries:
    output_path = f"{RESULTS_BASE}{name}/"
    spark.sql(sql).coalesce(1).write.mode("overwrite") \
        .option("header", "true").csv(output_path)

spark.stop()
