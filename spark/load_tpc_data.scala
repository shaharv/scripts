// Script for loading the TPC-DS SF1 tables to Spark.
//
// Suggested run commands:
//
// export SPARK_HOME=/path/to/spark     # Path to the Spark installation folder
// export SPARK_DATA_DIR=/tmp           # Path to Spark data folder where spark-warehouse folder will be written
// export DATA_DIR=/path/to/data        # Path to TPC-H/TPC-DS Parquet files
// export DB_NAME=name-of-db            # Name of the database, which must be prefixed by "tpch" or "tpcds"
// . set_spark_env.sh; set +e; time ${SPARK_HOME}/bin/spark-shell --master ${MASTER_URL} --conf spark.sql.warehouse.dir=${SPARK_DATA_DIR}/spark-warehouse -i ./load_tpcds_data.scala || true

import scala.io.{Source, StdIn}

// Create the database if it doesn't exist
spark.sql("CREATE DATABASE IF NOT EXISTS tpcds_sf1")

def load_table(table_name: String) = {
    val data_dir = sys.env("DATA_DIR")
    val parquet_file = s"$data_dir/$table_name"
    println("loading table: " + parquet_file)
    val table_df = spark.read.parquet(parquet_file)
    // Write the DataFrame as a permanent table under tpcds_sf1
    table_df.write.mode("overwrite").saveAsTable(s"tpcds_sf1.$table_name")
}

def createTablesForTpch() = {
    val tpch_tables = Array(
        "customer", "lineitem", "nation", "orders", "part", "partsupp", "region", "supplier"
    )
    tpch_tables.par.foreach(load_table) // Run in parallel
}

def createTablesForTpcds() = {
    val tpcds_tables = Array(
        "call_center", "catalog_page", "catalog_returns", "catalog_sales", "customer", "customer_address", "customer_demographics",
        "date_dim", "household_demographics", "income_band", "inventory", "item", "promotion", "reason", "ship_mode",
        "store", "store_returns", "store_sales", "time_dim", "warehouse", "web_page", "web_returns", "web_sales", "web_site"
    )
    tpcds_tables.par.foreach(load_table) // Run in parallel
}

val db_name = sys.env("DB_NAME")
if (db_name.startsWith("tpch")) {
    println(s"Importing TPC-H tables to the database $db_name.")
    createTablesForTpch()
}
else if (db_name.startsWith("tpcds")) {
    println(s"Importing TPC-DS tables to the database $db_name.")
    createTablesForTpcds()
}
else {
    println(s"Database name $db_name is not prefixed by 'tpch' or 'tpcds'.")
}

// Shutdown and exit
sc.stop()
spark.stop()
System.exit(0)
