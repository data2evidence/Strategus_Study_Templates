# -------------------------------------------------------
#                     PLEASE READ
# -------------------------------------------------------
#
# You must call "renv::restore()" and follow the prompts
# to install all of the necessary R libraries to run this
# project. This is a one-time operation that you must do
# before running any code.
#
# !!! PLEASE RESTART R AFTER RUNNING renv::restore() !!!
#
# -------------------------------------------------------
# renv::restore()

# libraries
library(duckdb)


# convert Eunomia SQLite to DuckDB
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
  print(paste("sqlite_conn type is : ", class(sqlite_conn)))

  # duckdb_file <- tempfile(fileext = ".duckdb")
  duckdb_file <- "my_eunomia_v2.duckdb"
  if (file.exists(duckdb_file)) {
    print(paste("Removing existing DuckDB file:", duckdb_file))
    file.remove(duckdb_file)
}
  # Create connection details for DuckDB
  duckdb_connectionDetails <- DatabaseConnector::createConnectionDetails(
    dbms = "duckdb",
    server = duckdb_file
  )
  # Connect to DuckDB using DatabaseConnector
  duckdb_conn <- DatabaseConnector::connect(duckdb_connectionDetails)
  print(paste("duckdb_conn type is : ", class(duckdb_conn)))

  # Copy all tables from SQLite to DuckDB
  tables <- DatabaseConnector::getTableNames(sqlite_conn)
  for (tbl in tables) {
    # message("Copying table: ", tbl)
    tryCatch(
      {
        data <- DatabaseConnector::querySql(sqlite_conn, paste0("SELECT * FROM ", tbl))
        DatabaseConnector::insertTable(
          connection = duckdb_conn,
          tableName = tbl,
          data = data,
          dropTableIfExists = TRUE,
          createTable = TRUE,
          tempTable = FALSE
        )
      },
      error = function(e) {
        message("Error copying table: ", tbl, " - ", e$message)
      }
    )
  }
  tables <- DatabaseConnector::getTableNames(duckdb_conn)
  cat("Tables in the database:\n")
  print(tables)

  tryCatch(
    {
      person_count <- DatabaseConnector::querySql(duckdb_conn, "SELECT COUNT(*) AS patient_count FROM person")
      cat("\n\n", paste("Person count:", person_count), "\n\n")
    },
    error = function(e) {
      message("Error running query: ", e$message)
    }
  )

  # List columns for each table
  # List columns for the person table
  # List columns in the 'person' table
  query <- "
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_name = 'person'
  ORDER BY ordinal_position
  "
  cols <- DatabaseConnector::querySql(duckdb_conn, query)
  print(cols)

  # Disconnect SQLite and DuckDB
  DatabaseConnector::disconnect(sqlite_conn)
  # DatabaseConnector::disconnect(duckdb_conn)

  message("Conversion complete. DuckDB file: ", duckdb_file)

  # Return DuckDB connection details
  return(duckdb_connectionDetails)
}

# ENVIRONMENT SETTINGS NEEDED FOR RUNNING Strategus ------------
# Sys.setenv("_JAVA_OPTIONS" = "-Xmx4g") # Sets the Java maximum heap space to 4GB
# Sys.setenv("VROOM_THREADS" = 1) # Sets the number of threads to 1 to avoid deadlocks on file system

## =========== START OF INPUTS ==========
cdmDatabaseSchema <- "main"
workDatabaseSchema <- "main"
outputLocation <- file.path(getwd(), "results")
databaseName <- "Eunomia" # Only used as a folder name for results from the study
minCellCount <- 5
cohortTableName <- "sample_study"

connectionDetails <- convertEunomiaSqliteToDuckDB()
# connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sqlite", server = "/var/folders/t2/g6fq88md4sv1vj5pl0t16h3h0000gn/T//Rtmp9onkHk/file13c768e6c138.sqlite")

# clean results folder
results_folder <- file.path(outputLocation)
cat("Trying to delete previousfolders:", results_folder, "\n")
# Remove everything inside the folder
if (dir.exists(results_folder)) {
  unlink(results_folder, recursive = TRUE, force = TRUE)
}
# Recreate the empty folder (optional, if Strategus expects it to exist)
dir.create(results_folder, showWarnings = FALSE, recursive = TRUE)
# You can use this snippet to test your connection
# conn <- DatabaseConnector::connect(connectionDetails)
# DatabaseConnector::disconnect(conn)
## =========== END OF INPUTS ==========

fileName <- file.path("inst", "Eunomia", "sampleStudy", "sampleStudyAnalysisSpecificationSurvival.json")
analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = fileName
)
cat("Analysis specifications loaded from", fileName, "\n")
# print(CohortGenerator::getCohortTableNames(cohortTable = cohortTableName))

executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTableName),
  workFolder = file.path(outputLocation, databaseName, "strategusWork"),
  resultsFolder = file.path(outputLocation, databaseName, "strategusOutput"),
  minCellCount = minCellCount
)

if (!dir.exists(file.path(outputLocation, databaseName))) {
  dir.create(file.path(outputLocation, databaseName), recursive = T)
}
# ParallelLogger::saveSettingsToJson(
#  object = executionSettings,
#  fileName = file.path(outputLocation, databaseName, "executionSettings.json")
# )

Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)
cat("Execution complete\n")
