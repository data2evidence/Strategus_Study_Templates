library(Strategus)
library(dplyr)

studyStartDate <- "19000101"
studyEndDate <- "20231231"

# Load cohort definitions
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = "inst/ImmunoSurgeryStudy/Cohorts.csv",
  jsonFolder = "inst/ImmunoSurgeryStudy/cohorts",
  sqlFolder = "inst/ImmunoSurgeryStudy/sql/sql_server"
)

# Target-Comparator pairs
cmTcList <- data.frame(
  targetCohortId = 1001,
  targetCohortName = "Immunotherapy + Surgery",
  comparatorCohortId = 1002,
  comparatorCohortName = "Surgery only"
)

# Outcome cohort
outcomeCohortId <- 3001

# Set time-at-risk
timeAtRisks <- tibble(
  label = c("KM Analysis"),
  riskWindowStart = c(1),
  startAnchor = c("cohort start"),
  riskWindowEnd = c(0),
  endAnchor = c("cohort end")
)

# Define the outcome
outcomeList <- lapply(seq_len(1), function(i) {
  CohortMethod::createOutcome(
    outcomeId = outcomeCohortId,
    outcomeOfInterest = TRUE
  )
})

# Define the T-C-O structure
targetComparatorOutcomesList <- list(
  CohortMethod::createTargetComparatorOutcomes(
    targetId = cmTcList$targetCohortId,
    comparatorId = cmTcList$comparatorCohortId,
    outcomes = outcomeList
  )
)

# Setup cohort method module
cmModuleSettingsCreator <- CohortMethodModule$new()

cmAnalysisList <- list(
  CohortMethod::createCmAnalysis(
    analysisId = 1,
    description = "Kaplan-Meier survival analysis",
    getDbCohortMethodDataArgs = CohortMethod::createGetDbCohortMethodDataArgs(
      studyStartDate = studyStartDate,
      studyEndDate = studyEndDate
    ),
    createStudyPopArgs = CohortMethod::createCreateStudyPopulationArgs(
      firstExposureOnly = TRUE,
      removeDuplicateSubjects = "keep first",
      removeSubjectsWithPriorOutcome = FALSE,
      priorOutcomeLookback = 0,
      requireTimeAtRisk = FALSE,
      riskWindowStart = timeAtRisks$riskWindowStart,
      startAnchor = timeAtRisks$startAnchor,
      riskWindowEnd = timeAtRisks$riskWindowEnd,
      endAnchor = timeAtRisks$endAnchor
    )
  )
)

cohortMethodModuleSpecifications <- cmModuleSettingsCreator$createModuleSpecifications(
  cmAnalysisList = cmAnalysisList,
  targetComparatorOutcomesList = targetComparatorOutcomesList
)

# Cohort Generator
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(cohortDefinitionSet)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications()

# Final Analysis Spec
analysisSpecifications <- createEmptyAnalysisSpecificiations() |>
  addSharedResources(cohortDefinitionShared) |>
  addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
  addModuleSpecifications(cohortMethodModuleSpecifications)

ParallelLogger::saveSettingsToJson(
  analysisSpecifications,
  file.path("inst", "ImmunoSurgeryStudy", "immunoSurgeryAnalysisSpecification.json")
)