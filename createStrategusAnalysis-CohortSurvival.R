################################################################################
# INSTRUCTIONS: This R script defines a Strategus-based Kaplan-Meier survival
#               analysis study using the CohortSurvival module.
################################################################################

library(dplyr)
library(Strategus)

# Study time window
studyStartDate <- "19000101" # YYYYMMDD
studyEndDate <- "20231231" # YYYYMMDD

# Load cohort definitions
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = "inst/Eunomia/sampleStudy/Cohorts.csv",
  jsonFolder = "inst/Eunomia/sampleStudy/cohorts",
  sqlFolder = "inst/Eunomia/sampleStudy/sql/sql_server"
)
# print(cohortDefinitionSet)

# Target and outcome cohorts
targetCohortTable <- "sample_study"
targetCohortId <- 1
outcomeCohortTable <- "sample_study"
outcomeCohortId <- 3

# Stratification variables (if any)
strata <- list(
  #gender = c("gender")
  age = c("age")
)
# strata <- list("age", "gender")


# CohortSurvivalModule ---------------------------------------------------------
csModuleSettingsCreator <- CohortSurvivalModule$new()

cohortSurvivalModuleSpecifications <- csModuleSettingsCreator$createModuleSpecifications(
  targetCohortTable = targetCohortTable,
  targetCohortId = targetCohortId,
  outcomeCohortTable = outcomeCohortTable,
  outcomeCohortId = outcomeCohortId,
  strata = strata,
  analysisType = "single_event",
  competingOutcomeCohortTable = NULL
)

print(cohortSurvivalModuleSpecifications)

# Cohort Generator -------------------------------------------------------------
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(cohortDefinitionSet)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications()

# Create the analysis specifications -------------------------------------------
analysisSpecifications <- Strategus::createEmptyAnalysisSpecificiations() |>
  Strategus::addSharedResources(cohortDefinitionShared) |>
  Strategus::addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
  Strategus::addModuleSpecifications(cohortSurvivalModuleSpecifications)

# Save the analysis specifications to a JSON file
path <- file.path("inst", "Eunomia", "SampleStudy", "sampleStudyAnalysisSpecificationSurvival.json")
ParallelLogger::saveSettingsToJson(
  analysisSpecifications,
  path
)
cat("Analysis specifications saved to", path, "\n")
