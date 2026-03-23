#!/usr/bin/env Rscript
# 一键打包脚本 - 将应用打包为可分发的压缩包

cat("=================================================\n")
cat("HCC预后预测应用 - 打包脚本\n")
cat("=================================================\n\n")

# 获取当前目录
app_dir <- getwd()
app_name <- basename(app_dir)
parent_dir <- dirname(app_dir)

# 输出文件名
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
output_file <- file.path(parent_dir, sprintf("%s_%s.zip", app_name, timestamp))

cat("打包目录:", app_dir, "\n")
cat("输出文件:", output_file, "\n\n")

# 要排除的文件和目录
exclude_patterns <- c(
  "\\.Rhistory$",
  "\\.RData$",
  "\\.Rproj$",
  "^\\.git",
  "^data/",  # 数据文件太大，需要用户自己生成
  "^models/",  # 模型文件也需要用户自己生成
  "\\.log$",
  "~$"
)

# 获取所有文件
all_files <- list.files(app_dir, recursive = TRUE, full.names = FALSE, all.files = FALSE)

# 过滤要打包的文件
files_to_zip <- all_files[!grepl(paste(exclude_patterns, collapse = "|"), all_files)]

cat("打包文件列表:\n")
cat(paste("  -", files_to_zip, collapse = "\n"), "\n\n")
cat(sprintf("共 %d 个文件\n\n", length(files_to_zip)))

# 创建压缩包
cat("正在创建压缩包...\n")

# 使用zip命令（如果可用）
if (Sys.which("zip") != "") {
  cmd <- sprintf("cd '%s' && zip -r '%s' %s",
                 app_dir,
                 output_file,
                 paste(shQuote(files_to_zip), collapse = " "))
  system(cmd, ignore.stdout = FALSE)
} else {
  # 使用R的zip功能
  zip(output_file, files = file.path(app_dir, files_to_zip))
}

if (file.exists(output_file)) {
  file_size <- file.size(output_file) / 1024 / 1024
  cat("\n=================================================\n")
  cat("✓ 打包完成！\n")
  cat("=================================================\n")
  cat(sprintf("文件: %s\n", basename(output_file)))
  cat(sprintf("大小: %.2f MB\n", file_size))
  cat(sprintf("位置: %s\n", output_file))
  cat("\n可以将此压缩包分发给其他用户。\n")
  cat("解压后按照README.md或使用说明.txt操作即可。\n\n")
} else {
  cat("\n✗ 打包失败\n")
  cat("请检查是否有写入权限或使用其他压缩工具。\n\n")
}

cat("=================================================\n")
