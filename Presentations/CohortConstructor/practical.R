# Connexion
library(CDMConnector)
library(CodelistGenerator)
library(CohortConstructor)
library(CohortCharacteristics)
library(duckdb)
library(DBI)
library(dplyr)
library(gt)
library(here)

con <- dbConnect(drv = duckdb(dbdir = here("Databases", "delphi.duckdb")))
cdm <- cdmFromCon(
  con = con,
  cdmSchema = "main",
  writeSchema = "results",
  writePrefix = "cc_"
)

# Exercise 1 ----
# Create a cohort table with two cohorts: chronic kidney disease and acute kidney injury. Use the following codelist.
codes <- list(
  "chronic_kidney_disease" = c(46271022L),
  "acute_kidney_injury" = c(197320L)
) |> newCodelist()

cdm$base_conditions_cohort <- conceptCohort(cdm = cdm, conceptSet = codes, name = "base_conditions_cohort")

summariseCohortAttrition(cohort = cdm$base_conditions_cohort) |>
  tableCohortAttrition() |>
  gt::gtsave(filename = here::here("Presentations", "CohortConstructor", "exercise_1.png"))

# Exercise 2 ----
# Create a new cohort named "study_cohort" by applying the following criteria to the base conditions cohort:
# -   For both cohorts, require that records start between January 1, 1990, and December 31, 2011.
# -   For both cohorts, include only patients with no previous history (before diagnosis) of diabetes. Use the diabetes codes below.

diabetesCodes <- list("diabetes" = c(201254L, 201826L)) |> newCodelist()

cdm$study_cohort <- cdm$base_conditions_cohort |>
  requireInDateRange(
    dateRange = as.Date(c("1990-01-01", "2011-12-31")),
    name = "study_cohort"
  ) |>
  requireConceptIntersect(
    conceptSet = diabetesCodes,
    window = list(c(-Inf, 0)),
    intersections = 0,
    name = "study_cohort"
  )

summariseCohortAttrition(cohort = cdm$study_cohort) |>
  tableCohortAttrition() |>
  gt::gtsave(filename = here::here("Presentations", "CohortConstructor", "exercise_2.png"))


# Exercise 3 ----
# Since Chronic Kidney Disease (CKD) is a chronic condition, define its cohort exit so patients remain in the cohort from first diagnostic date to the end of patient's observation.
cdm$study_cohort <- cdm$study_cohort |>
  exitAtObservationEnd(
    cohortId = "chronic_kidney_disease",
    persistAcrossObservationPeriods = TRUE,
    name = "study_cohort"
  ) |>
  padCohortStart(
    days = 180,
    cohortId = "acute_kidney_injury",
    name = "study_cohort"
  )

summariseCohortAttrition(cohort = cdm$study_cohort) |>
  tableCohortAttrition() |>
  gt::gtsave(filename = here::here("Presentations", "CohortConstructor", "exercise_3.png"), vwidth = 1500)


# Exercise 4 ----
# Create a third cohort containing patients with Chronic Kidney Disease who also experience an Acute Kidney Injury; define its criteria so that the final "study_cohort" table includes three distinct cohorts: "acute_kidney_injury", "chronic_kidney_disease", and "acute_kidney_injury_chronic_kidney_disease".
# Finally, rename cohorts so they are called "aki", "ckd", and "aki_ckd", respectively.
cdm$study_cohort <- cdm$study_cohort |>
  intersectCohorts(
    keepOriginalCohorts = TRUE,
    name = "study_cohort",
  ) |>
  renameCohort(
    newCohortName = c("aki", "ckd", "aki_ckd")
  )

summariseCohortAttrition(cohort = cdm$study_cohort) |>
  tableCohortAttrition() |>
  gt::gtsave(filename = here::here("Presentations", "CohortConstructor", "exercise_4.png"), vwidth = 1500)

CDMConnector::cdmDisconnect(cdm)
