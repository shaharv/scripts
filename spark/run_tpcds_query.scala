import scala.io.{Source, StdIn}

def load_table(table_name: String) = {
    val data_dir = sys.env("TPCDS_DATA_DIR")
    val parquet_file = data_dir + "/" + table_name
    println("loading table: " + parquet_file)
    val table_df = spark.read.parquet(parquet_file)
    table_df.createTempView(table_name)
}

def createTempViewForTpcdsTables() = {
    val tpcds_tables = Array(
        "call_center", "catalog_page", "catalog_returns", "catalog_sales", "customer", "customer_address", "customer_demographics",
        "date_dim", "household_demographics", "income_band", "inventory", "item", "promotion", "reason", "ship_mode",
        "store", "store_returns", "store_sales", "time_dim", "warehouse", "web_page", "web_returns", "web_sales", "web_site")

    for (t <- tpcds_tables) {
        load_table(t)
    }
}

def runQuery(query_file: String) = {
    val sql_query = Source.fromFile(query_file).getLines.mkString

    // Run the query
    val query_df = spark.sql(sql_query)
    val query_start_time = System.nanoTime
    val query_res = query_df.collect
    val query_duration = (System.nanoTime - query_start_time) / 1e9d
    val query_duration_rounded = (math floor query_duration * 100) / 100

    // Print results
    print("Number of results: " + query_res.length + "\n")
    var print_num_results = sys.env.getOrElse("PRINT_NUM_RESULTS", "0").toInt
    if (print_num_results == 0) {
        print_num_results = query_res.length
    }
    else {
        print_num_results = Math.min(print_num_results, query_res.length)
    }
    print("Printing the first " + print_num_results + " results...\n")
    for (x <- 0 to (print_num_results - 1)) { print(query_res(x) + "\n") }

    println("\n================================================================================")
    print("Query duration: " + query_duration_rounded + " seconds\n")
    println("================================================================================")
}

createTempViewForTpcdsTables()
val query_file = sys.env("QUERY_FILE")
runQuery(query_file)

val batch_mode = sys.env.getOrElse("BATCH_MODE", "")
if (batch_mode == "") {
    println("Press any key to exit spark-shell.")
    scala.io.StdIn.readLine()
}

// Shutdown and exit
sc.stop()
spark.stop()
System.exit(0)
