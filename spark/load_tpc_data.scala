// Script for loading TPC-H/DS tables to Spark.
//
// Suggested run commands:
//
// export SPARK_HOME=/path/to/spark     # Path to the Spark installation folder
// export SPARK_DATA_DIR=/tmp           # Path to Spark data folder where spark-warehouse folder will be written
// export DATA_DIR=/path/to/data        # Path to TPC-H/TPC-DS Parquet files
// export DB_NAME=name-of-db            # Name of the database, which must be prefixed by "tpch" or "tpcds"
// . set_spark_env.sh; set +eu; time ${SPARK_HOME}/bin/spark-shell --master ${MASTER_URL} --conf spark.sql.warehouse.dir=${SPARK_DATA_DIR}/spark-warehouse -i ./load_tpc_data.scala || true

import scala.io.{Source, StdIn}

def load_table(db_name: String, table_name: String) = {
    val data_dir = sys.env("DATA_DIR")
    val parquet_file = s"$data_dir/$table_name"
    println("loading table: " + parquet_file)
    val table_df = spark.read.parquet(parquet_file)
    // Write the DataFrame as a permanent table in the database
    table_df.write.mode("overwrite").saveAsTable(s"$db_name.$table_name")
}

def createTablesForTpch(db_name: String) = {
    val tpch_tables = Array(
        "customer", "lineitem", "nation", "orders", "part", "partsupp", "region", "supplier"
    )
    spark.sql(s"CREATE DATABASE IF NOT EXISTS $db_name")
    tpch_tables.par.foreach(table => load_table(db_name, table)) // Run in parallel
}

def createTablesForTpcds(db_name: String) = {
    val tpcds_tables = Array(
        "call_center", "catalog_page", "catalog_returns", "catalog_sales", "customer", "customer_address", "customer_demographics",
        "date_dim", "household_demographics", "income_band", "inventory", "item", "promotion", "reason", "ship_mode",
        "store", "store_returns", "store_sales", "time_dim", "warehouse", "web_page", "web_returns", "web_sales", "web_site"
    )
    spark.sql(s"CREATE DATABASE IF NOT EXISTS $db_name")
    tpcds_tables.par.foreach(table => load_table(db_name, table)) // Run in parallel
}

val db_name = sys.env("DB_NAME")
if (db_name.startsWith("tpch")) {
    println(s"Importing TPC-H tables to the database $db_name.")
    createTablesForTpch(db_name)
}
else if (db_name.startsWith("tpcds")) {
    println(s"Importing TPC-DS tables to the database $db_name.")
    createTablesForTpcds(db_name)
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
