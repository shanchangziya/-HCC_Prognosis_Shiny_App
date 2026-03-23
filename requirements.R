#!/usr/bin/env Rscript
# HCC预后预测Shiny应用 - R包依赖安装脚本
# 运行此脚本以安装所有必需的R包

cat("=================================================\n")
cat("HCC预后预测Shiny应用 - 依赖包安装\n")
cat("=================================================\n\n")

# 检查和安装包的函数
install_if_missing <- function(package) {
  if (!require(package, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("正在安装 %s...\n", package))
    install.packages(package, dependencies = TRUE, repos = "https://cloud.r-project.org/")
    library(package, character.only = TRUE)
    cat(sprintf("✓ %s 安装完成\n", package))
  } else {
    cat(sprintf("✓ %s 已安装\n", package))
  }
}

# 核心包列表
core_packages <- c(
  # Shiny相关
  "shiny",
  "shinydashboard",
  "shinyWidgets",
  "shinyjs",
  "DT",
  "fresh",

  # 数据处理
  "dplyr",
  "tidyr",
  "readr",
  "data.table",
  "purrr",
  "stringr",

  # 可视化
  "ggplot2",
  "plotly",
  "ggpubr",
  "patchwork",
  "scales",
  "RColorBrewer",
  "viridis",

  # 生存分析
  "survival",
  "survminer",
  "survivalROC",
  "rms",
  "Hmisc",

  # 机器学习
  "glmnet",
  "randomForest",
  "caret",
  "pROC",
  "ROCR",

  # 其他工具
  "officer",      # PPT导出
  "openxlsx",     # Excel读写
  "gridExtra",    # 图形排版
  "cowplot",      # 图形组合
  "ggtext"        # 文本增强
)

cat("\n开始安装核心包...\n\n")
for (pkg in core_packages) {
  install_if_missing(pkg)
}

cat("\n=================================================\n")
cat("检查Bioconductor包...\n")
cat("=================================================\n\n")

# Bioconductor包
if (!require("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

bioc_packages <- c()  # 如需要可添加

if (length(bioc_packages) > 0) {
  for (pkg in bioc_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      cat(sprintf("正在安装 %s (Bioconductor)...\n", pkg))
      BiocManager::install(pkg, update = FALSE, ask = FALSE)
      cat(sprintf("✓ %s 安装完成\n", pkg))
    } else {
      cat(sprintf("✓ %s 已安装\n", pkg))
    }
  }
}

cat("\n=================================================\n")
cat("验证安装...\n")
cat("=================================================\n\n")

# 验证所有包是否可以正常加载
all_packages <- c(core_packages, bioc_packages)
failed_packages <- c()

for (pkg in all_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    failed_packages <- c(failed_packages, pkg)
  }
}

if (length(failed_packages) == 0) {
  cat("\n✓ 所有包安装成功！\n")
  cat("\n可以运行以下命令启动应用：\n")
  cat("  source('prepare_data.R')  # 准备数据\n")
  cat("  source('build_model.R')   # 构建模型\n")
  cat("  shiny::runApp('app.R')    # 启动应用\n\n")
} else {
  cat("\n✗ 以下包安装失败：\n")
  cat(paste("  -", failed_packages, collapse = "\n"), "\n")
  cat("\n请手动安装这些包或检查错误信息。\n\n")
}

# 打印R和包版本信息
cat("\n=================================================\n")
cat("系统信息\n")
cat("=================================================\n")
cat("R version:", R.version.string, "\n")
cat("Platform:", R.version$platform, "\n")
cat("\n主要包版本：\n")
key_packages <- c("shiny", "ggplot2", "survival", "rms", "plotly", "dplyr")
for (pkg in key_packages) {
  if (require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("  %s: %s\n", pkg, packageVersion(pkg)))
  }
}

cat("\n=================================================\n")
cat("安装脚本执行完毕\n")
cat("=================================================\n\n")
