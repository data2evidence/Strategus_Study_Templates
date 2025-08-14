library(DatabaseConnector)
library(SqlRender)

# 1. Connect to your OMOP SQLite database
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite",
  server = "/var/folders/t2/g6fq88md4sv1vj5pl0t16h3h0000gn/T//RtmpELJpaf/file4db1281392cb.sqlite"
)
conn <- DatabaseConnector::connect(connectionDetails)

targetCohortId <-3
# 2. Read the cohort SQL file (from ATLAS export)
sqlFilePath <- paste0("inst/Eunomia/sampleStudy/sql/sql_server/", targetCohortId, ".sql")
sql <- readLines(sqlFilePath)
#sql <- readLines("inst/Eunomia/sampleStudy/sql/sql_server/1.sql")
# sql <- readLines("inst/sampleStudy/sql/sql_server/20130.sql")
sql <- paste(sql, collapse = "\n")
print(sql)
# 3. Render the SQL: replaces @variables with actual values
renderedSql <- SqlRender::render(
  sql,
  cdm_database_schema = "main",
  vocabulary_database_schema = "main",
  target_database_schema = "main",
  results_database_schema = "main",
  target_cohort_table = "sample_study",
  target_cohort_id = targetCohortId
  #cohort_definition_id = 1
)

# 4. Translate SQL from OHDSI syntax to SQLite
translatedSql <- SqlRender::translate(
  renderedSql,
  targetDialect = "sqlite"
)
#executeSql(conn, "Select * from main.temp_cohort;")


# DatabaseConnector::executeSql(conn, "
#   CREATE TABLE main.sample_study (
#     cohort_definition_id INTEGER,
#     subject_id INTEGER,
#     cohort_start_date DATE,
#     cohort_end_date DATE
#   );
#  ")

# 5. Execute the translated SQL — this creates the cohort table
DatabaseConnector::executeSql(conn, translatedSql)

# 6. Check the number of patients in the cohort
#count <- DatabaseConnector::querySql(
#  conn,
#  "SELECT COUNT(*) AS person_count FROM sample_study"
#)
count <- DatabaseConnector::querySql(
  conn,
  paste0("SELECT COUNT(*) AS person_count FROM sample_study WHERE cohort_definition_id = ", targetCohortId)
)
print(count)

# 7. (Optional) Clean up: drop the temp cohort table
DatabaseConnector::executeSql(conn, "DROP TABLE IF EXISTS temp_cohort;")

# 8. Disconnect
DatabaseConnector::disconnect(conn)

