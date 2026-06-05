capture program drop project_paths
program define project_paths
    args root
    global PROJECT_ROOT "`root'"
    global ARTIFACT_ROOT "$PROJECT_ROOT/artifacts"
    global ARCHIVE_ROOT "$PROJECT_ROOT/archive"
    global DOC_ROOT "$PROJECT_ROOT/docs"
    global INPUT_ROOT "$PROJECT_ROOT/inputs"
    global FULL_DATA_ROOT "$PROJECT_ROOT/full-data"
    global OUTPUT_ROOT "$PROJECT_ROOT/outputs"
    global PIPELINE_ROOT "$PROJECT_ROOT/pipelines"
    global LEGACY_R_ROOT "$PROJECT_ROOT/scripts/r"
    global LEGACY_STATA_ROOT "$PROJECT_ROOT/scripts/stata"
    global SRC_R_ROOT "$PROJECT_ROOT/src/r"
    global SRC_STATA_ROOT "$PROJECT_ROOT/src/stata"
end
