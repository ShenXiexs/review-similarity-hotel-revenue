project_paths <- function(project_dir = getwd()) {
  normalize <- function(x) normalizePath(x, winslash = "/", mustWork = FALSE)
  root <- normalize(project_dir)

  list(
    root = root,
    artifacts = normalize(file.path(root, "artifacts")),
    archive = normalize(file.path(root, "archive")),
    docs = normalize(file.path(root, "docs")),
    inputs = normalize(file.path(root, "inputs")),
    full_data = normalize(file.path(root, "full-data")),
    outputs = normalize(file.path(root, "outputs")),
    pipelines = normalize(file.path(root, "pipelines")),
    legacy_scripts_r = normalize(file.path(root, "scripts", "r")),
    legacy_scripts_stata = normalize(file.path(root, "scripts", "stata")),
    src_r = normalize(file.path(root, "src", "r")),
    src_stata = normalize(file.path(root, "src", "stata"))
  )
}
