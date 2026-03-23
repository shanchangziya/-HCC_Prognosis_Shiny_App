#!/usr/bin/env Rscript
# 测试脚本 - 验证所有组件是否正常工作

cat("=================================================\n")
cat("HCC预后预测应用 - 组件测试\n")
cat("=================================================\n\n")

# 记录测试结果
test_results <- list()

# 1. 测试R包加载 ================================================
cat("[1/5] 测试R包加载...\n")
required_packages <- c(
  "shiny", "shinydashboard", "shinyWidgets", "DT",
  "ggplot2", "plotly", "dplyr", "survival", "survminer", "rms", "readr"
)

pkg_test <- sapply(required_packages, function(pkg) {
  suppressPackageStartupMessages(require(pkg, character.only = TRUE, quietly = TRUE))
})

if (all(pkg_test)) {
  cat("✓ 所有必需R包加载成功\n")
  test_results$packages <- TRUE
} else {
  cat("✗ 以下R包加载失败:\n")
  cat(paste("  -", names(pkg_test)[!pkg_test], collapse = "\n"), "\n")
  test_results$packages <- FALSE
}

# 2. 测试数据文件 ================================================
cat("\n[2/5] 测试数据文件...\n")
data_files <- c(
  "data/resnet_features.csv",
  "data/clinical_data.csv",
  "data/cell_fractions.csv",
  "data/drug_database.csv"
)

data_test <- file.exists(data_files)
if (all(data_test)) {
  cat("✓ 所有数据文件存在\n")
  # 测试读取
  tryCatch({
    resnet <- read_csv("data/resnet_features.csv", show_col_types = FALSE)
    cat(sprintf("  - ResNet特征: %d 样本 × %d 特征\n", nrow(resnet), ncol(resnet)-1))
    test_results$data <- TRUE
  }, error = function(e) {
    cat("✗ 数据文件读取失败:", e$message, "\n")
    test_results$data <- FALSE
  })
} else {
  cat("✗ 缺少数据文件:\n")
  cat(paste("  -", data_files[!data_test], collapse = "\n"), "\n")
  test_results$data <- FALSE
}

# 3. 测试模型文件 ================================================
cat("\n[3/5] 测试模型文件...\n")
model_files <- c(
  "models/cox_model_objects.rds",
  "models/nomogram.rds"
)

model_test <- file.exists(model_files)
if (all(model_test)) {
  cat("✓ 所有模型文件存在\n")
  # 测试加载
  tryCatch({
    model_obj <- readRDS("models/cox_model_objects.rds")
    cat(sprintf("  - C-index: %.3f\n", model_obj$performance$c_index))
    cat(sprintf("  - 训练样本数: %d\n", nrow(model_obj$data)))
    test_results$models <- TRUE
  }, error = function(e) {
    cat("✗ 模型文件加载失败:", e$message, "\n")
    test_results$models <- FALSE
  })
} else {
  cat("✗ 缺少模型文件:\n")
  cat(paste("  -", model_files[!model_test], collapse = "\n"), "\n")
  test_results$models <- FALSE
}

# 4. 测试辅助函数 ================================================
cat("\n[4/5] 测试辅助函数...\n")
if (file.exists("scripts/model_functions.R")) {
  tryCatch({
    source("scripts/model_functions.R")
    cat("✓ 辅助函数加载成功\n")
    test_results$functions <- TRUE
  }, error = function(e) {
    cat("✗ 辅助函数加载失败:", e$message, "\n")
    test_results$functions <- FALSE
  })
} else {
  cat("⚠ 辅助函数文件不存在（非必需）\n")
  test_results$functions <- NA
}

# 5. 测试应用启动 ================================================
cat("\n[5/5] 测试应用文件...\n")
if (file.exists("app.R")) {
  # 检查app.R语法
  tryCatch({
    parse("app.R")
    cat("✓ app.R 语法检查通过\n")
    test_results$app <- TRUE
  }, error = function(e) {
    cat("✗ app.R 语法错误:", e$message, "\n")
    test_results$app <- FALSE
  })
} else {
  cat("✗ app.R 文件不存在\n")
  test_results$app <- FALSE
}

# 总结 ==========================================================
cat("\n=================================================\n")
cat("测试总结\n")
cat("=================================================\n")

all_passed <- all(unlist(test_results[!sapply(test_results, is.na)]))

if (all_passed) {
  cat("✓ 所有测试通过！应用可以正常启动。\n\n")
  cat("运行以下命令启动应用：\n")
  cat("  source('start_app.R')\n")
  cat("或\n")
  cat("  shiny::runApp('app.R')\n\n")
} else {
  cat("✗ 部分测试失败，请检查以下问题：\n\n")

  if (!test_results$packages) cat("  - R包安装: 运行 source('requirements.R')\n")
  if (!test_results$data) cat("  - 数据准备: 运行 source('prepare_data.R')\n")
  if (!test_results$models) cat("  - 模型构建: 运行 source('build_model.R')\n")
  if (!test_results$app) cat("  - 应用文件: 检查 app.R 是否存在\n")

  cat("\n详细信息请查看上方测试输出。\n\n")
}

cat("=================================================\n\n")

# 返回测试结果
invisible(test_results)
