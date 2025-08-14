# A Strategus Study adapted from the CreateStrategusAnalysisSpecification.R file - Simplified study by removing many modules

################################################################################
# INSTRUCTIONS: Make sure you have downloaded your cohorts using 
# DownloadCohorts.R and that those cohorts are stored in the "inst" folder
# of the project. This script is written to use the sample study cohorts
# located in "inst/sampleStudy/Eunomia" so you will need to modify this in the code 
# below. 
# 
# See the Create analysis specifications section
# of the UsingThisTemplate.md for more details.
# 
# More information about Strategus HADES modules can be found at:
# https://ohdsi.github.io/Strategus/reference/index.html#omop-cdm-hades-modules.
# This help page also contains links to the corresponding HADES package that
# further details.
# ##############################################################################

# Load required packages
library(dplyr)
library(Strategus)

# Time-at-risks (TARs) for the outcomes of interest in your study
timeAtRisks <- tibble(
  label = c("On treatment"),
  riskWindowStart  = c(1),
  startAnchor = c("cohort start"),
  riskWindowEnd  = c(0),
  endAnchor = c("cohort end")
)

# PLP time-at-risks should try to use fixed-time TARs
plpTimeAtRisks <- tibble(
  riskWindowStart  = c(1),
  startAnchor = c("cohort start"),
  riskWindowEnd  = c(365),
  endAnchor = c("cohort start"),
)

# If you are not restricting your study to a specific time window, 
# please make these strings empty
# studyStartDate <- '' #YYYYMMDD
# studyEndDate <- ''   #YYYYMMDD
studyStartDate <- '19080101' #YYYYMMDD
studyEndDate <- '20231231'   #YYYYMMDD
# Some of the settings require study dates with hyphens
studyStartDateWithHyphens <- gsub("(\\d{4})(\\d{2})(\\d{2})", "\\1-\\2-\\3", studyStartDate)
studyEndDateWithHyphens <- gsub("(\\d{4})(\\d{2})(\\d{2})", "\\1-\\2-\\3", studyEndDate)

# Consider these settings for estimation  ----------------------------------------
useCleanWindowForPriorOutcomeLookback <- FALSE # If FALSE, lookback window is all time prior, i.e., including only first events
psMatchMaxRatio <- 1 # If bigger than 1, the outcome model will be conditioned on the matched set

# Shared Resources -------------------------------------------------------------
# Get the list of cohorts - NOTE: you should modify this for your
# study to retrieve the cohorts you downloaded as part of
# DownloadCohorts.R
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = "inst/Eunomia/sampleStudy/Cohorts.csv",
  jsonFolder = "inst/Eunomia/sampleStudy/cohorts",
  sqlFolder = "inst/Eunomia/sampleStudy/sql/sql_server"
)

# OPTIONAL: Create a subset to define the new user cohorts
# Cohort Subsets help to add more strict criteria for entry etc.
# More information: https://ohdsi.github.io/CohortGenerator/articles/CreatingCohortSubsetDefinitions.html
subset1 <- CohortGenerator::createCohortSubsetDefinition(
  name = "New Users",
  definitionId = 1,
  subsetOperators = list(
    CohortGenerator::createLimitSubset(
      priorTime = 365,
      limitTo = "firstEver"
    )
  )
)
# applies the subset definition to first cohort (and not the one with id 1) - it's index
cohortDefinitionSet <- cohortDefinitionSet |>
  CohortGenerator::addCohortSubsetDefinition(subset1, targetCohortIds = c(1))

# add negative control cohorts - helps with tackling Bias in model fitting
negativeControlOutcomeCohortSet <- CohortGenerator::readCsv(
  file = "inst/Eunomia/sampleStudy/negativeControlOutcomes.csv"
)

if (any(duplicated(cohortDefinitionSet$cohortId, negativeControlOutcomeCohortSet$cohortId))) {
 stop("*** Error: duplicate cohort IDs found ***")
}

# Create some data frames to hold the cohorts we'll use in each analysis ---------------
# Outcomes: The outcome for this study is cohort_id == 3 
oList <- cohortDefinitionSet %>%
  filter(.data$cohortId == 3) %>%
  mutate(outcomeCohortId = cohortId, outcomeCohortName = cohortName) %>%
  select(outcomeCohortId, outcomeCohortName) %>%
  mutate(cleanWindow = 365)

# For the CohortMethod analysis we'll use the subsetted cohorts
cmTcList <- data.frame(
  targetCohortId = 1001,
  targetCohortName = "celecoxib new users",
  comparatorCohortId = 2001,
  comparatorCohortName = "diclofenac new users"
)

# For the CohortMethod LSPS we'll need to exclude the drugs of interest in this
# study
excludedCovariateConcepts <- data.frame(
  conceptId = c(1118084, 1124300),
  conceptName = c("celecoxib", "diclofenac")
)

# For the SCCS analysis we'll use the all exposure cohorts
sccsTList <- data.frame(
  targetCohortId = c(1,2),
  targetCohortName = c("celecoxib", "diclofenac")
)

# CohortGeneratorModule --------------------------------------------------------
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(cohortDefinitionSet)

negativeControlsShared <- cgModuleSettingsCreator$createNegativeControlOutcomeCohortSharedResourceSpecifications(
  negativeControlOutcomeCohortSet = negativeControlOutcomeCohortSet,
  occurrenceType = "first",
  detectOnDescendants = TRUE
)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications(
  generateStats = TRUE
)

# CharacterizationModule Settings ---------------------------------------------
cModuleSettingsCreator <- CharacterizationModule$new()
characterizationModuleSpecifications <- cModuleSettingsCreator$createModuleSpecifications(
  targetIds = cohortDefinitionSet$cohortId, # NOTE: This is all T/C/I/O
  outcomeIds = oList$outcomeCohortId,
  outcomeWashoutDays = rep(0, length(oList$outcomeCohortId)),
  minPriorObservation = 365,
  dechallengeStopInterval = 30,
  dechallengeEvaluationWindow = 30,
  riskWindowStart = timeAtRisks$riskWindowStart,
  startAnchor = timeAtRisks$startAnchor,
  riskWindowEnd = timeAtRisks$riskWindowEnd,
  endAnchor = timeAtRisks$endAnchor,
  minCharacterizationMean = .01
)

# PatientLevelPredictionModule -------------------------------------------------
plpModuleSettingsCreator <- PatientLevelPredictionModule$new()

modelSettings <- list(
  lassoLogisticRegression = PatientLevelPrediction::setLassoLogisticRegression()
  #randomForest = PatientLevelPrediction::setRandomForest()
)
tcIds <- cohortDefinitionSet %>%
  filter(!cohortId %in% oList$outcomeCohortId & isSubset) %>%
  pull(cohortId)

modelDesignList <- list()
for (cohortId in tcIds) {
  for (j in seq_len(nrow(plpTimeAtRisks))) {
    for (k in seq_len(nrow(oList))) {
      if (useCleanWindowForPriorOutcomeLookback) {
        priorOutcomeLookback <- oList$cleanWindow[k]
      } else {
        priorOutcomeLookback <- 99999
      }
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
  Strategus::addSharedResources(negativeControlsShared) |>
  Strategus::addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
  #Strategus::addModuleSpecifications(cohortDiagnosticsModuleSpecifications) |>
  #Strategus::addModuleSpecifications(characterizationModuleSpecifications) |>
  #Strategus::addModuleSpecifications(cohortIncidenceModuleSpecifications) |>
  #Strategus::addModuleSpecifications(cohortMethodModuleSpecifications) |>
  #Strategus::addModuleSpecifications(selfControlledModuleSpecifications) |>
  Strategus::addModuleSpecifications(plpModuleSpecifications)

ParallelLogger::saveSettingsToJson(
  analysisSpecifications, 
  file.path("inst", "Eunomia", "sampleStudy", "sampleStudyAnalysisSpecificationModified.json")
)

