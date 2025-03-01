// Script for loading the TPC-DS SF1 tables to Spark.
// Suggested run command line:
// . set_spark_env.sh; set +e; time ${SPARK_HOME}/bin/spark-shell --master ${MASTER_URL} -i ./load_tpcds_data.scala || true

import scala.io.{Source, StdIn}

// Create the database if it doesn't exist
spark.sql("CREATE DATABASE IF NOT EXISTS tpcds_sf1")

def load_table(table_name: String) = {
    val data_dir = sys.env("TPCDS_DATA_DIR")
    val parquet_file = s"$data_dir/$table_name"
    println("loading table: " + parquet_file)
    val table_df = spark.read.parquet(parquet_file)
    // Write the DataFrame as a permanent table under tpcds_sf1
    table_df.write.mode("overwrite").saveAsTable(s"tpcds_sf1.$table_name")
}

def createTablesForTpcds() = {
    val tpcds_tables = Array(
        "call_center", "catalog_page", "catalog_returns", "catalog_sales", "customer", "customer_address", "customer_demographics",
        "date_dim", "household_demographics", "income_band", "inventory", "item", "promotion", "reason", "ship_mode",
        "store", "store_returns", "store_sales", "time_dim", "warehouse", "web_page", "web_returns", "web_sales", "web_site")

    tpcds_tables.par.foreach(load_table) // Run in parallel
}

createTablesForTpcds()

// Shutdown and exit
sc.stop()
spark.stop()
System.exit(0)
