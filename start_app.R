#!/usr/bin/env Rscript
# 一键启动脚本 - 检查环境并启动Shiny应用

cat("=================================================\n")
cat("HCC预后预测 Shiny 应用 - 启动脚本\n")
cat("=================================================\n\n")

# 设置工作目录到脚本所在目录
if (interactive()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
} else {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_dir <- dirname(sub("--file=", "", file_arg))
    setwd(script_dir)
  }
}

cat("工作目录:", getwd(), "\n\n")

# 1. 检查必需的R包 ===============================================
cat("[1/4] 检查R包依赖...\n")

required_packages <- c(
  "shiny", "shinydashboard", "shinyWidgets", "shinyjs", "DT",
  "ggplot2", "plotly", "dplyr", "survival", "survminer", "rms", "readr"
)

missing_packages <- c()
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    missing_packages <- c(missing_packages, pkg)
  }
}

if (length(missing_packages) > 0) {
  cat("\n✗ 缺少以下R包：\n")
  cat(paste("  -", missing_packages, collapse = "\n"), "\n\n")
  cat("请运行以下命令安装：\n")
  cat("  source('requirements.R')\n\n")
  stop("请先安装必需的R包")
}

cat("✓ 所有必需的R包已安装\n")

# 2. 检查数据文件 =================================================
cat("\n[2/4] 检查数据文件...\n")

required_data_files <- c(
  "data/resnet_features.csv",
  "data/clinical_data.csv",
  "data/cell_fractions.csv",
  "data/drug_database.csv"
)

missing_data <- required_data_files[!file.exists(required_data_files)]

if (length(missing_data) > 0) {
  cat("\n✗ 缺少数据文件：\n")
  cat(paste("  -", missing_data, collapse = "\n"), "\n\n")
  cat("请运行以下命令准备数据：\n")
  cat("  source('prepare_data.R')\n\n")
  stop("请先准备数据文件")
}

cat("✓ 所有数据文件已就绪\n")

# 3. 检查模型文件 =================================================
cat("\n[3/4] 检查模型文件...\n")

required_model_files <- c(
  "models/cox_model_objects.rds",
  "models/nomogram.rds"
)

missing_models <- required_model_files[!file.exists(required_model_files)]

if (length(missing_models) > 0) {
  cat("\n✗ 缺少模型文件：\n")
  cat(paste("  -", missing_models, collapse = "\n"), "\n\n")
  cat("请运行以下命令构建模型：\n")
  cat("  source('build_model.R')\n\n")
  stop("请先构建预测模型")
}

cat("✓ 模型文件已加载\n")

# 4. 启动应用 =====================================================
cat("\n[4/4] 启动Shiny应用...\n\n")

cat("=================================================\n")
cat("✓ 环境检查完成！正在启动应用...\n")
cat("=================================================\n\n")

# 默认端口
port <- 3838

# 检查端口是否被占用（可选）
# 如果被占用，自动选择下一个可用端口
while (TRUE) {
  tryCatch({
    # 尝试在指定端口启动
    cat(sprintf("尝试在端口 %d 启动应用...\n", port))
    break
  }, error = function(e) {
    port <- port + 1
    if (port > 4000) {
      stop("无法找到可用端口（3838-4000范围内）")
    }
  })
}

# 启动应用
cat("\n")
cat("========================================\n")
cat("应用启动信息：\n")
cat(sprintf("  本地访问: http://127.0.0.1:%d\n", port))
cat(sprintf("  局域网访问: http://<您的IP>:%d\n", port))
cat("  按 Ctrl+C 或 Esc 停止应用\n")
cat("========================================\n\n")

# 运行应用
tryCatch({
  shiny::runApp(
    appDir = "app.R",
    port = port,
    host = "0.0.0.0",  # 允许外部访问
    launch.browser = TRUE  # 自动打开浏览器
  )
}, error = function(e) {
  cat("\n✗ 应用启动失败：\n")
  cat(e$message, "\n\n")
}, interrupt = function(e) {
  cat("\n\n应用已停止。\n")
})

cat("\n感谢使用 HCC 预后预测系统！\n\n")
