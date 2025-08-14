library(DatabaseConnector)
library(SqlRender)

# 1. Connect to OMOP SQLite database
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite",
  server = "/var/folders/t2/g6fq88md4sv1vj5pl0t16h3h0000gn/T//RtmpELJpaf/file4db1281392cb.sqlite"
)
conn <- DatabaseConnector::connect(connectionDetails)


# 2. Define SQL with @cdm_database_schema placeholder
sql <- "
SELECT cohort_definition_id, MIN(cohort_start_date), MAX(cohort_start_date), COUNT(*) 
FROM main.sample_study 
GROUP BY cohort_definition_id;
"

# 3. Render and translate for SQLite
renderedSql <- SqlRender::render(
  sql,
  cdm_database_schema = "main"
)
translatedSql <- SqlRender::translate(
  renderedSql,
  targetDialect = "sqlite"
)

# 4. Execute the query and retrieve result
result <- DatabaseConnector::querySql(conn, translatedSql)
print(result)

# 5. Disconnect
DatabaseConnector::disconnect(conn)