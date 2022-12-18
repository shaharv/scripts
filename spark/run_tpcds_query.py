import os
import sys
import time
from pyspark.sql import SparkSession


def read_tpcds_data(spark, data_path):
    tables = ["call_center",
            "catalog_page",
            "catalog_returns",
            "customer",
            "customer_address",
            "customer_demographics",
            "date_dim",
            "household_demographics",
            "income_band",
            "inventory",
            "item",
            "promotion",
            "reason",
            "ship_mode",
            "store",
            "store_returns",
            "store_sales",
            "time_dim",
            "warehouse",
            "web_page",
            "web_returns",
            "web_sales",
            "catalog_sales",
            "web_site"]

    for table_name in tables:
        print("Creating table view: ", table_name, os.path.join(data_path, table_name))
        df = spark.read.parquet(os.path.join(data_path, table_name))
        df.createTempView(table_name)

    return


def usage():
    script_path = sys.argv[0]
    script_name = os.path.basename(script_path)
    print("Usage: " + script_name + " <data dir> <.sql file>")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        usage()
        sys.exit(0)

    data_dir = sys.argv[1]
    query_file = sys.argv[2]

    print("Data dir: " + data_dir)
    print("Query file: " + query_file)

    # Initialize spark.
    # TODO: Set master to proper URL (spark://localhost:7078)
    # TODO: Set Spark configuration.
    # TODO: Run with spark-submit.
    spark = SparkSession.builder.master("local[1]").appName("submit-tpcds").getOrCreate()

    # Read TPC-DS data / create table views
    read_tpcds_data(spark, data_dir)

    with open(query_file, "rt") as fp:
        query = fp.read()
        try:
            print("Running query: ")
            print(query)
            results = spark.sql(query)
            start_time = time.time()
            results.collect()
            end_time = time.time()
            execution_time = end_time - start_time
            results.show()
            print("Running time: " + str(execution_time) + " seconds")
        except Exception as e:
            print(e)
