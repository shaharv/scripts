// Script for loading TPC-H/DS tables to Spark.
//
// For running this script, the following environment variables must be set:
//
// export SPARK_HOME=/path/to/spark     # Path to the Spark installation folder
// export DATA_DIR=/path/to/data        # Path to TPC-H/TPC-DS Parquet files
// export DB_NAME=name-of-db            # Name of the database, which must be prefixed by "tpch" or "tpcds"
// export SPARK_DIRS=/tmp/spark         # Location of Spark folders, such as metastore_db and spark-warehouse
//
// Suggested run command line:
// time ./run_spark_shell.sh --conf spark.sql.parquet.compression.codec=lz4_raw -i ./load_tpc_data.scala

import scala.io.{Source, StdIn}

val tpch_tables = Array(
    "customer", "lineitem", "nation", "orders", "part", "partsupp", "region", "supplier"
)

val tpcds_tables = Array(
    "call_center", "catalog_page", "catalog_returns", "catalog_sales", "customer", "customer_address", "customer_demographics",
    "date_dim", "household_demographics", "income_band", "inventory", "item", "promotion", "reason", "ship_mode",
    "store", "store_returns", "store_sales", "time_dim", "warehouse", "web_page", "web_returns", "web_sales", "web_site"
)

def load_table(db_name: String, table_name: String) = {
    try {
        val data_dir = sys.env("DATA_DIR")
        val parquet_file = s"$data_dir/$table_name"
        println(s"Loading table $table_name from $parquet_file into $db_name")

        val start = System.nanoTime()
        val table_df = spark.read.parquet(parquet_file)
        table_df.write.mode("overwrite").saveAsTable(s"$db_name.$table_name")
        val end = System.nanoTime()
        val elapsed = (end - start) / 1e9
        println(f"Successfully loaded $table_name into $db_name in ${elapsed}%.2f seconds")
    }
    catch {
        case e: Exception =>
            println(s"ERROR loading table $table_name: ${e.getMessage}")
    }
}

def createTables(db_name: String, table_names: Array[String]) = {
    spark.sql(s"CREATE DATABASE IF NOT EXISTS $db_name")
    table_names.par.foreach(table => load_table(db_name, table)) // Run in parallel
}

val db_name = sys.env("DB_NAME")
if (db_name.startsWith("tpch")) {
    println(s"Importing TPC-H tables to the database $db_name.")
    createTables(db_name, tpch_tables)
}
else if (db_name.startsWith("tpcds")) {
    println(s"Importing TPC-DS tables to the database $db_name.")
    createTables(db_name, tpcds_tables)
}
else {
    println(s"Database name $db_name is not prefixed by 'tpch' or 'tpcds'.")
    System.exit(1)
}

spark.sql(s"show tables in $db_name").show()

// Shutdown and exit
sc.stop()
spark.stop()
System.exit(0)
