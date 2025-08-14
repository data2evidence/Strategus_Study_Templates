################################################################################
# Strategus Treatment Patterns Study: Depression Treatment Sequences
################################################################################

library(Strategus)
library(dplyr)

# Study period
studyStartDate <- "19001201"
studyEndDate <- "20231231"

# Load all cohorts
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = "inst/Eunomia/sampleStudy/Cohorts.csv",
  jsonFolder = "inst/Eunomia/sampleStudy/cohorts",
  sqlFolder = "inst/Eunomia/sampleStudy/sql/sql_server"
)

# Assume target cohort is for depression
targetCohortId <- 1  # Replace with your actual depression cohort ID

# Event cohorts: SSRI, SNRI, TCA, bupropion, esketamine
eventCohortIds <- c(2, 3, 4, 5, 6)  # Replace with actual event cohort IDs

# Shared resources
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(cohortDefinitionSet)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications(generateStats = TRUE)

# TreatmentPatterns module setup
tpModuleSettingsCreator <- TreatmentPatternsModule$new()

treatmentPatternsSpecifications <- tpModuleSettingsCreator$createModuleSpecifications(
  targetCohortId = targetCohortId,
  eventCohortIds = eventCohortIds,
  studyWindow = list(
    startDate = studyStartDate,
    endDate = studyEndDate
  ),
  periodPriorToIndex = 0,
  minEraDuration = 0,
  combinationWindow = 30,
  minPostCombinationDuration = 0,
  splitEventCohorts = TRUE,
  minCellCount = 5,
  groupCombinations = TRUE
)

# Create analysis spec
analysisSpecifications <- Strategus::createEmptyAnalysisSpecificiations() |>
  Strategus::addSharedResources(cohortDefinitionShared) |>
  Strategus::addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
  Strategus::addModuleSpecifications(treatmentPatternsSpecifications)

# Save JSON
ParallelLogger::saveSettingsToJson(
  analysisSpecifications,
  file.path("inst", "Eunomia", "SampleStudy", "treatmentPatternsAnalysisSpecification.json")
)