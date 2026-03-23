#!/usr/bin/env Rscript
# 模型构建脚本 - 构建Cox回归预后模型和列线图

cat("=================================================\n")
cat("HCC预后预测应用 - 模型构建\n")
cat("=================================================\n\n")

# 加载必要的包
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(survival)
  library(survminer)
  library(rms)
  library(pROC)
  library(ggplot2)
  library(glmnet)
})

# 设置工作目录
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# 创建模型文件夹
if (!dir.exists("models")) {
  dir.create("models")
  cat("✓ 创建 models/ 文件夹\n")
}

# ============================================
# 1. 加载数据
# ============================================
cat("\n[1/7] 加载数据...\n")

if (!all(file.exists(c("data/resnet_features.csv",
                       "data/clinical_data.csv",
                       "data/cell_fractions.csv")))) {
  stop("✗ 数据文件缺失！请先运行 source('prepare_data.R')")
}

resnet_df <- read_csv("data/resnet_features.csv", show_col_types = FALSE)
clinical_df <- read_csv("data/clinical_data.csv", show_col_types = FALSE)
cell_fractions_df <- read_csv("data/cell_fractions.csv", show_col_types = FALSE)

cat(sprintf("  ✓ ResNet特征: %d 样本 × %d 特征\n", nrow(resnet_df), ncol(resnet_df)-1))
cat(sprintf("  ✓ 临床数据: %d 样本 × %d 变量\n", nrow(clinical_df), ncol(clinical_df)-1))
cat(sprintf("  ✓ 细胞分数: %d 样本 × %d 细胞类型\n", nrow(cell_fractions_df), ncol(cell_fractions_df)-1))

# ============================================
# 2. 数据整合
# ============================================
cat("\n[2/7] 整合数据...\n")

# 合并所有数据
full_data <- resnet_df %>%
  left_join(clinical_df, by = "sample") %>%
  left_join(cell_fractions_df, by = "sample")

# 选择关键特征
# ResNet风险评分 + 临床特征 + 关键细胞类型
key_features <- c(
  "RS",  # ResNet风险评分
  "age", "gender", "stage", "grade",  # 临床特征
  "Tumor_OS-high", "Tumor_OS-low",   # 肿瘤氧化应激
  "CD8_Trm_Activated_Trm", "CD8_Trm_Cytotoxic_Trm",  # 细胞毒性T细胞
  "NK_CD56dim_NK",  # NK细胞
  "Mac_TREM2_TAM", "Mac_SLC40A1_TAM"  # 肿瘤相关巨噬细胞
)

# 检查哪些特征可用
available_features <- key_features[key_features %in% colnames(full_data)]
missing_features <- setdiff(key_features, available_features)

if (length(missing_features) > 0) {
  cat("  ⚠ 缺少以下特征，将从模型中排除:\n")
  cat(paste("    -", missing_features, collapse = "\n"), "\n")
}

# 保留有完整数据的样本
model_data <- full_data %>%
  select(sample, os, os.time, all_of(available_features)) %>%
  filter(!is.na(os) & !is.na(os.time) & os.time > 0) %>%
  na.omit()

cat(sprintf("  ✓ 整合后样本数: %d\n", nrow(model_data)))
cat(sprintf("  ✓ 特征数: %d\n", length(available_features)))

# 处理分类变量
if ("gender" %in% colnames(model_data)) {
  model_data$gender <- factor(model_data$gender, levels = c("Male", "Female"))
}
if ("stage" %in% colnames(model_data)) {
  model_data$stage <- factor(model_data$stage, levels = c("I", "II", "III", "IV"))
  # 转换为数值型（用于列线图）
  model_data$stage_numeric <- as.numeric(model_data$stage)
}
if ("grade" %in% colnames(model_data)) {
  model_data$grade <- factor(model_data$grade, levels = c("G1", "G2", "G3", "G4"))
  model_data$grade_numeric <- as.numeric(model_data$grade)
}

# ============================================
# 3. 构建Cox回归模型
# ============================================
cat("\n[3/7] 构建Cox回归模型...\n")

# 方法1: 完整模型（包含所有特征）
formula_vars <- setdiff(available_features, c())
formula_str <- paste("Surv(os.time, os) ~", paste(formula_vars, collapse = " + "))

# 如果有stage和grade，使用数值型版本
if ("stage" %in% formula_vars) {
  formula_str <- gsub("stage", "stage_numeric", formula_str)
}
if ("grade" %in% formula_vars) {
  formula_str <- gsub("grade", "grade_numeric", formula_str)
}

cat("  模型公式:", formula_str, "\n")

cox_full <- coxph(as.formula(formula_str), data = model_data)

cat("\n模型摘要:\n")
print(summary(cox_full))

# 方法2: 逐步回归选择最优模型
cat("\n  执行逐步回归...\n")
cox_step <- step(cox_full, direction = "backward", trace = 0)

cat("\n最优模型变量:\n")
print(names(coef(cox_step)))

# 计算风险评分
model_data$risk_score <- predict(cox_step, type = "risk")
model_data$risk_lp <- predict(cox_step, type = "lp")  # 线性预测值

# 风险分层（中位数分割）
risk_cutoff <- median(model_data$risk_score)
model_data$risk_group <- ifelse(model_data$risk_score > risk_cutoff, "High", "Low")

cat(sprintf("  ✓ 高风险组: %d 样本\n", sum(model_data$risk_group == "High")))
cat(sprintf("  ✓ 低风险组: %d 样本\n", sum(model_data$risk_group == "Low")))

# ============================================
# 4. 模型性能评估
# ============================================
cat("\n[4/7] 评估模型性能...\n")

# C-index
c_index <- concordance(cox_step)$concordance
cat(sprintf("  C-index: %.3f\n", c_index))

# 时间依赖ROC (1年, 3年, 5年)
library(survivalROC)
time_points <- c(365, 365*3, 365*5)  # 天数
auc_results <- list()

for (t in time_points) {
  # 只评估有足够随访时间的样本
  if (max(model_data$os.time, na.rm = TRUE) >= t) {
    roc_obj <- survivalROC(
      Stime = model_data$os.time,
      status = model_data$os,
      marker = model_data$risk_lp,
      predict.time = t,
      method = "KM"
    )
    auc_results[[paste0(t/365, "yr")]] <- roc_obj$AUC
    cat(sprintf("  %d年AUC: %.3f\n", t/365, roc_obj$AUC))
  }
}

# 生存分析
fit_km <- survfit(Surv(os.time, os) ~ risk_group, data = model_data)
surv_diff <- survdiff(Surv(os.time, os) ~ risk_group, data = model_data)
p_value <- 1 - pchisq(surv_diff$chisq, df = 1)
cat(sprintf("  Log-rank P值: %.2e\n", p_value))

# ============================================
# 5. 创建列线图
# ============================================
cat("\n[5/7] 创建列线图...\n")

# 使用rms包的cph和nomogram函数
# 需要用datadist设置数据分布
dd <- datadist(model_data)
options(datadist = "dd")

# 重新拟合模型（使用rms::cph）
# 选择关键变量构建列线图
nomogram_vars <- c("RS")

if ("age" %in% available_features) nomogram_vars <- c(nomogram_vars, "age")
if ("stage_numeric" %in% colnames(model_data)) nomogram_vars <- c(nomogram_vars, "stage_numeric")
if ("Tumor_OS-high" %in% colnames(model_data)) nomogram_vars <- c(nomogram_vars, "Tumor_OS-high")

nomogram_formula <- as.formula(paste("Surv(os.time, os) ~", paste(nomogram_vars, collapse = " + ")))

cph_model <- cph(nomogram_formula, data = model_data, x = TRUE, y = TRUE, surv = TRUE, time.inc = 365)

# 创建列线图对象
nom <- nomogram(
  cph_model,
  fun = list(
    function(x) 1 - survest(cph_model, times = 365, newdata = data.frame(x))$surv,
    function(x) 1 - survest(cph_model, times = 365*3, newdata = data.frame(x))$surv,
    function(x) 1 - survest(cph_model, times = 365*5, newdata = data.frame(x))$surv
  ),
  funlabel = c("1-Year Mortality", "3-Year Mortality", "5-Year Mortality"),
  fun.at = c(0.1, 0.3, 0.5, 0.7, 0.9)
)

cat("  ✓ 列线图创建完成\n")

# ============================================
# 6. 保存模型和相关对象
# ============================================
cat("\n[6/7] 保存模型...\n")

# 保存主要模型对象
model_objects <- list(
  cox_model = cox_step,
  cph_model = cph_model,
  nomogram = nom,
  data = model_data,
  features = available_features,
  performance = list(
    c_index = c_index,
    auc = auc_results,
    log_rank_p = p_value
  ),
  risk_cutoff = risk_cutoff,
  formula = formula_str
)

saveRDS(model_objects, "models/cox_model_objects.rds")
cat("  ✓ models/cox_model_objects.rds\n")

# 单独保存列线图（用于绘图）
saveRDS(nom, "models/nomogram.rds")
cat("  ✓ models/nomogram.rds\n")

# 保存预测函数
predict_risk <- function(new_data, model = cox_step) {
  # 预测风险评分
  risk_score <- predict(model, newdata = new_data, type = "risk")
  risk_lp <- predict(model, newdata = new_data, type = "lp")

  # 计算生存概率
  surv_prob_1yr <- exp(-predict(model, newdata = new_data, type = "expected") *
                         (1 / median(model$y[,1])))

  # 风险分层
  risk_group <- ifelse(risk_score > risk_cutoff, "High Risk", "Low Risk")

  return(data.frame(
    risk_score = risk_score,
    risk_lp = risk_lp,
    risk_group = risk_group,
    surv_prob_1yr = surv_prob_1yr
  ))
}

saveRDS(predict_risk, "models/predict_function.rds")
cat("  ✓ models/predict_function.rds\n")

# ============================================
# 7. 生成模型报告
# ============================================
cat("\n[7/7] 生成模型报告...\n")

# 绘制并保存关键图形
pdf("models/model_performance.pdf", width = 12, height = 8)

# 1. KM曲线
p1 <- ggsurvplot(
  fit_km,
  data = model_data,
  pval = TRUE,
  risk.table = TRUE,
  conf.int = TRUE,
  palette = c("#E74C3C", "#3498DB"),
  title = "Kaplan-Meier Survival Curves by Risk Group",
  xlab = "Time (days)",
  ylab = "Survival Probability",
  legend.title = "Risk Group",
  legend.labs = c("High Risk", "Low Risk")
)
print(p1)

# 2. 列线图
plot(nom, xfrac = 0.25)
title("Prognostic Nomogram for HCC Patients")

# 3. 风险评分分布
p3 <- ggplot(model_data, aes(x = risk_score, fill = risk_group)) +
  geom_histogram(bins = 30, alpha = 0.7, position = "identity") +
  scale_fill_manual(values = c("High" = "#E74C3C", "Low" = "#3498DB")) +
  geom_vline(xintercept = risk_cutoff, linetype = "dashed", color = "black") +
  labs(title = "Distribution of Risk Scores",
       x = "Risk Score", y = "Count", fill = "Risk Group") +
  theme_minimal()
print(p3)

# 4. 森林图
p4 <- ggforest(cox_step, data = model_data)
print(p4)

dev.off()

cat("  ✓ models/model_performance.pdf\n")

# 保存文本报告
report_file <- "models/model_report.txt"
sink(report_file)
cat("=================================================\n")
cat("HCC预后预测模型 - 性能报告\n")
cat("=================================================\n\n")
cat("生成时间:", as.character(Sys.time()), "\n\n")

cat("数据摘要\n")
cat("-------------------------------------------------\n")
cat("训练样本数:", nrow(model_data), "\n")
cat("特征数:", length(available_features), "\n")
cat("事件数 (死亡):", sum(model_data$os), "\n")
cat("删失数:", sum(1 - model_data$os), "\n")
cat("中位随访时间:", median(model_data$os.time), "天\n\n")

cat("模型特征\n")
cat("-------------------------------------------------\n")
cat(paste(available_features, collapse = "\n"), "\n\n")

cat("模型性能\n")
cat("-------------------------------------------------\n")
cat("C-index:", sprintf("%.3f", c_index), "\n")
for (name in names(auc_results)) {
  cat(sprintf("%s AUC: %.3f\n", name, auc_results[[name]]))
}
cat("Log-rank P值:", sprintf("%.2e", p_value), "\n\n")

cat("模型系数\n")
cat("-------------------------------------------------\n")
print(summary(cox_step))

cat("\n风险分层\n")
cat("-------------------------------------------------\n")
cat("风险分割点:", sprintf("%.3f", risk_cutoff), "\n")
cat("高风险组样本数:", sum(model_data$risk_group == "High"), "\n")
cat("低风险组样本数:", sum(model_data$risk_group == "Low"), "\n\n")

cat("=================================================\n")
sink()

cat("  ✓ models/model_report.txt\n")

# ============================================
# 完成
# ============================================
cat("\n=================================================\n")
cat("✓ 模型构建完成！\n")
cat("=================================================\n")
cat("\n生成的文件:\n")
cat("  ✓ models/cox_model_objects.rds\n")
cat("  ✓ models/nomogram.rds\n")
cat("  ✓ models/predict_function.rds\n")
cat("  ✓ models/model_performance.pdf\n")
cat("  ✓ models/model_report.txt\n")
cat("\n模型性能总结:\n")
cat(sprintf("  • C-index: %.3f\n", c_index))
for (name in names(auc_results)) {
  cat(sprintf("  • %s AUC: %.3f\n", name, auc_results[[name]]))
}
cat(sprintf("  • Log-rank P: %.2e\n", p_value))
cat("\n下一步：运行 shiny::runApp('app.R') 启动应用\n\n")
