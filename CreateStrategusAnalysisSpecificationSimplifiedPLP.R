################################################################################
# INSTRUCTIONS: This R script defines a Strategus-based PLP study using Eunomia
#               dataset. This version retains only the necessary modules and logic
#               for a Patient-Level Prediction (PLP) study. All other modules and
#               cohort subsets have been removed to simplify execution.
################################################################################

library(dplyr)
library(Strategus)

packageDescription("Strategus")$RemoteUrl# PLP time-at-risks should try to use fixed-time TARs
plpTimeAtRisks <- tibble(
  riskWindowStart  = c(1),
  startAnchor = c("cohort start"),
  riskWindowEnd  = c(365),
  endAnchor = c("cohort start")
)

# If you are not restricting your study to a specific time window,
# please make these strings empty
studyStartDate <- '19001201' # YYYYMMDD
studyEndDate <- '20231231'   # YYYYMMDD

# Get the list of cohorts from CohortGenerator
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = "inst/Eunomia/sampleStudy/Cohorts.csv",
  jsonFolder = "inst/Eunomia/sampleStudy/cohorts",
  sqlFolder = "inst/Eunomia/sampleStudy/sql/sql_server"
)

# Outcomes: The outcome for this study is cohort_id == 3 
oList <- cohortDefinitionSet %>%
  filter(.data$cohortId == 3) %>%
  mutate(outcomeCohortId = cohortId, outcomeCohortName = cohortName) %>%
  select(outcomeCohortId, outcomeCohortName) %>%
  mutate(cleanWindow = 365)

# CohortGeneratorModule --------------------------------------------------------
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(cohortDefinitionSet)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications(
  generateStats = TRUE
)

# PatientLevelPredictionModule -------------------------------------------------
plpModuleSettingsCreator <- PatientLevelPredictionModule$new()

modelSettings <- list(
  lassoLogisticRegression = PatientLevelPrediction::setLassoLogisticRegression()
)

modelDesignList <- list()
tcIds <- cohortDefinitionSet %>%
  filter(cohortId != 3) %>%
  pull(cohortId)

for (cohortId in tcIds) {
  for (j in seq_len(nrow(plpTimeAtRisks))) {
    for (k in seq_len(nrow(oList))) {
      priorOutcomeLookback <- 99999
      for (mSetting in modelSettings) {
        modelDesignList[[length(modelDesignList) + 1]] <- PatientLevelPrediction::createModelDesign(
          targetId = cohortId,
          outcomeId = oList$outcomeCohortId[k],
          restrictPlpDataSettings = PatientLevelPrediction::createRestrictPlpDataSettings(
            sampleSize = 1000000,
            studyStartDate = studyStartDate,
            studyEndDate = studyEndDate,
            firstExposureOnly = FALSE,
            washoutPeriod = 0
          ),
          populationSettings = PatientLevelPrediction::createStudyPopulationSettings(
            riskWindowStart = plpTimeAtRisks$riskWindowStart[j],
            startAnchor = plpTimeAtRisks$startAnchor[j],
            riskWindowEnd = plpTimeAtRisks$riskWindowEnd[j],
            endAnchor = plpTimeAtRisks$endAnchor[j],
            removeSubjectsWithPriorOutcome = TRUE,
            priorOutcomeLookback = priorOutcomeLookback,
            requireTimeAtRisk = FALSE,
            binary = TRUE,
            includeAllOutcomes = TRUE,
            firstExposureOnly = FALSE,
            washoutPeriod = 0,
            minTimeAtRisk = plpTimeAtRisks$riskWindowEnd[j] - plpTimeAtRisks$riskWindowStart[j],
            restrictTarToCohortEnd = FALSE
          ),
          covariateSettings = FeatureExtraction::createCovariateSettings(
            useDemographicsGender = TRUE,
            useDemographicsAgeGroup = TRUE,
            useConditionGroupEraLongTerm = TRUE,
            useDrugGroupEraLongTerm = TRUE,
            useVisitConceptCountLongTerm = TRUE
          ),
          preprocessSettings = PatientLevelPrediction::createPreprocessSettings(),
          modelSettings = mSetting
        )
      }
    }
  }
}

plpModuleSpecifications <- plpModuleSettingsCreator$createModuleSpecifications(
  modelDesignList = modelDesignList
)

# Create the analysis specifications ------------------------------------------
analysisSpecifications <- Strategus::createEmptyAnalysisSpecificiations() |>
  Strategus::addSharedResources(cohortDefinitionShared) |> 
  Strategus::addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
  Strategus::addModuleSpecifications(plpModuleSpecifications)

ParallelLogger::saveSettingsToJson(
  analysisSpecifications, 
  file.path("inst", "Eunomia", "SampleStudy", "sampleStudyAnalysisSpecificationCleanPLP.json")
)

