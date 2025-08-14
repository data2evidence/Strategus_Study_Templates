#library(Eunomia)
#library(DBI)
#library(RSQLite)
library(duckdb)

convertEunomiaSqliteToDuckDB <- function() {
  # Get Eunomia connection details
  connectionDetails <- Eunomia::getEunomiaConnectionDetails()
  sqlite_file <- connectionDetails$server()
  message("SQLite file path: ", sqlite_file)
  if (!file.exists(sqlite_file)) stop("SQLite file does not exist: ", sqlite_file)
  
  # Connect to SQLite
  sqlite_connectionDetails <- DatabaseConnector::createConnectionDetails(
    dbms = "sqlite",
    server = sqlite_file
  )
  sqlite_conn <- DatabaseConnector::connect(sqlite_connectionDetails)
  
  duckdb_file = tempfile(fileext = ".duckdb")
  # Create connection details for DuckDB
  duckdb_connectionDetails <- DatabaseConnector::createConnectionDetails(
    dbms = "duckdb",
    server = duckdb_file
  )
  # Connect to DuckDB using DatabaseConnector
  duckdb_conn <- DatabaseConnector::connect(duckdb_connectionDetails)
  
  # Copy all tables from SQLite to DuckDB
  tables <- DatabaseConnector::getTableNames(sqlite_conn)
  for (tbl in tables) {
    message("Copying table: ", tbl)
    tryCatch({
      data <- DatabaseConnector::querySql(sqlite_conn, paste0("SELECT * FROM ", tbl))
      DatabaseConnector::insertTable(
        connection = duckdb_conn,
        tableName = tbl,
        data = data,
        dropTableIfExists = TRUE,
        createTable = TRUE,
        tempTable = FALSE
      )
    }, error = function(e) {
      message("Error copying table: ", tbl, " - ", e$message)
    })
  }
  
  print(DatabaseConnector::getTableNames(duckdb_conn))
  tryCatch({
    person_count <- DatabaseConnector::querySql(duckdb_conn, "SELECT COUNT(*) AS patient_count FROM person")
    cat("\n\n" , paste("Person count:", person_count), "\n\n")
  }, error = function(e) {
    message("Error running query: ", e$message)
  })
  
  # Disconnect SQLite and DuckDB
  DatabaseConnector::disconnect(sqlite_conn)
  DatabaseConnector::disconnect(duckdb_conn)
  
  message("Conversion complete. DuckDB file: ", duckdb_file)
  
  # Return DuckDB connection details
  return(duckdb_connectionDetails)
}

# Example usage:
duckdb_connectionDetails <- convertEunomiaSqliteToDuckDB()
