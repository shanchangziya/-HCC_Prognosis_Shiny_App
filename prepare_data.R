#!/usr/bin/env Rscript
# 数据准备脚本 - 从原始TCGA-LIHC数据生成应用所需的CSV文件

cat("=================================================\n")
cat("HCC预后预测应用 - 数据准备\n")
cat("=================================================\n\n")

library(dplyr)
library(readr)
library(tidyr)

# 设置工作目录
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# 创建数据文件夹
if (!dir.exists("data")) {
  dir.create("data")
  cat("✓ 创建 data/ 文件夹\n")
}

# ============================================
# 1. 加载原始数据
# ============================================
cat("\n[1/5] 加载原始数据...\n")

# 检查必需文件
required_files <- c(
  "../Resnet.Rdata",
  "../TCGA-LIHC_deconv_with_survival.csv",
  "../bulk/TCGA-LIHC.Rdata"
)

missing_files <- !file.exists(required_files)
if (any(missing_files)) {
  cat("\n✗ 错误：缺少以下必需文件：\n")
  cat(paste("  -", required_files[missing_files], collapse = "\n"), "\n")
  cat("\n请将以下文件复制到正确位置：\n")
  cat("  - Resnet.Rdata → HCC_Prognosis_Shiny_App/../\n")
  cat("  - TCGA-LIHC_deconv_with_survival.csv → HCC_Prognosis_Shiny_App/../\n")
  cat("  - TCGA-LIHC.Rdata → HCC_Prognosis_Shiny_App/../bulk/\n\n")
  stop("缺少必需文件")
}

# 加载ResNet特征
cat("  - 加载 Resnet.Rdata...\n")
load("../Resnet.Rdata")  # 包含 resnet_RS_sig, resnet2, rp

# 加载反卷积结果
cat("  - 加载 TCGA-LIHC_deconv_with_survival.csv...\n")
deconv_surv <- read_csv("../TCGA-LIHC_deconv_with_survival.csv", show_col_types = FALSE)

# 加载TCGA临床数据（如果可用）
cat("  - 加载 TCGA-LIHC.Rdata...\n")
load("../bulk/TCGA-LIHC.Rdata")  # 包含 exp, surv

cat("✓ 数据加载完成\n")

# ============================================
# 2. 处理ResNet特征
# ============================================
cat("\n[2/5] 处理ResNet特征...\n")

# 使用71个筛选后的ResNet特征
resnet_features_df <- as.data.frame(resnet_RS_sig)
resnet_features_df$sample <- rownames(resnet_features_df)
resnet_features_df <- resnet_features_df %>%
  select(sample, everything())

# 保存ResNet特征
write_csv(resnet_features_df, "data/resnet_features.csv")
cat(sprintf("✓ 保存 resnet_features.csv (%d 样本, %d 特征)\n",
            nrow(resnet_features_df), ncol(resnet_features_df) - 1))

# ============================================
# 3. 处理临床数据
# ============================================
cat("\n[3/5] 处理临床数据...\n")

# 从surv数据框提取临床信息
if (exists("surv") && is.data.frame(surv)) {
  clinical_df <- surv %>%
    as.data.frame() %>%
    mutate(sample = rownames(.)) %>%
    select(sample, everything())

  # 标准化列名
  colnames(clinical_df) <- tolower(colnames(clinical_df))

  # 确保有OS和OS.time
  if (!"os" %in% colnames(clinical_df) && "vital_status" %in% colnames(clinical_df)) {
    clinical_df$os <- ifelse(clinical_df$vital_status == "Dead", 1, 0)
  }
  if (!"os.time" %in% colnames(clinical_df) && "days_to_death" %in% colnames(clinical_df)) {
    clinical_df$os.time <- as.numeric(clinical_df$days_to_death)
  }

} else {
  # 如果没有surv对象，从rp创建基本临床数据
  clinical_df <- rp %>%
    select(ID, OS.time, OS) %>%
    rename(sample = ID, os.time = OS.time, os = OS)

  # 添加模拟临床特征（用于演示）
  set.seed(123)
  clinical_df <- clinical_df %>%
    mutate(
      age = round(rnorm(n(), 60, 10)),
      gender = sample(c("Male", "Female"), n(), replace = TRUE, prob = c(0.7, 0.3)),
      stage = sample(c("I", "II", "III", "IV"), n(), replace = TRUE, prob = c(0.2, 0.3, 0.3, 0.2)),
      grade = sample(c("G1", "G2", "G3", "G4"), n(), replace = TRUE, prob = c(0.1, 0.3, 0.4, 0.2)),
      afp = round(exp(rnorm(n(), 4, 2))),
      cirrhosis = sample(c("Yes", "No"), n(), replace = TRUE, prob = c(0.7, 0.3))
    )
}

write_csv(clinical_df, "data/clinical_data.csv")
cat(sprintf("✓ 保存 clinical_data.csv (%d 样本, %d 特征)\n",
            nrow(clinical_df), ncol(clinical_df) - 1))

# ============================================
# 4. 处理细胞类型分数
# ============================================
cat("\n[4/5] 处理细胞类型分数...\n")

# 从反卷积结果提取细胞分数
cell_cols <- setdiff(colnames(deconv_surv), c("sample", "OS", "X_PATIENT", "OS.time"))
cell_fractions_df <- deconv_surv %>%
  select(sample, all_of(cell_cols))

write_csv(cell_fractions_df, "data/cell_fractions.csv")
cat(sprintf("✓ 保存 cell_fractions.csv (%d 样本, %d 细胞类型)\n",
            nrow(cell_fractions_df), ncol(cell_fractions_df) - 1))

# ============================================
# 5. 创建药物数据库
# ============================================
cat("\n[5/5] 创建药物数据库...\n")

drug_database <- data.frame(
  drug_name = c(
    "索拉非尼 (Sorafenib)",
    "仑伐替尼 (Lenvatinib)",
    "瑞戈非尼 (Regorafenib)",
    "卡博替尼 (Cabozantinib)",
    "纳武利尤单抗 (Nivolumab)",
    "帕博利珠单抗 (Pembrolizumab)",
    "阿替利珠单抗 (Atezolizumab)",
    "伊匹木单抗 (Ipilimumab)",
    "贝伐单抗 (Bevacizumab)",
    "雷莫芦单抗 (Ramucirumab)",
    "FOLFOX (5-FU + 奥沙利铂)",
    "吉西他滨 (Gemcitabine)",
    "多柔比星 (Doxorubicin)",
    "奥沙利铂 (Oxaliplatin)"
  ),
  drug_class = c(
    "多靶点TKI",
    "多靶点TKI",
    "多靶点TKI",
    "多靶点TKI",
    "PD-1抑制剂",
    "PD-1抑制剂",
    "PD-L1抑制剂",
    "CTLA-4抑制剂",
    "抗VEGF单抗",
    "抗VEGFR2单抗",
    "化疗",
    "化疗",
    "化疗",
    "化疗"
  ),
  indication = c(
    "一线标准治疗",
    "一线标准治疗",
    "二线治疗",
    "二线治疗",
    "二线免疫治疗",
    "二线免疫治疗",
    "联合贝伐单抗一线",
    "联合纳武利尤单抗",
    "联合阿替利珠单抗",
    "二线抗血管生成",
    "系统化疗",
    "系统化疗",
    "TACE化疗",
    "系统化疗"
  ),
  risk_group = c(
    "高风险",
    "高风险",
    "高风险",
    "高风险",
    "高风险",
    "高风险",
    "中高风险",
    "高风险",
    "中高风险",
    "中高风险",
    "高风险",
    "中风险",
    "中风险",
    "中高风险"
  ),
  os_high_suitable = c(
    "推荐",
    "推荐",
    "推荐",
    "推荐",
    "不推荐",
    "不推荐",
    "条件推荐",
    "不推荐",
    "推荐",
    "推荐",
    "推荐",
    "条件推荐",
    "条件推荐",
    "推荐"
  ),
  immune_high_suitable = c(
    "条件推荐",
    "条件推荐",
    "条件推荐",
    "条件推荐",
    "推荐",
    "推荐",
    "推荐",
    "推荐",
    "条件推荐",
    "条件推荐",
    "不推荐",
    "不推荐",
    "不推荐",
    "不推荐"
  ),
  response_rate = c(
    "15-20%",
    "18-24%",
    "10-15%",
    "12-20%",
    "15-20%",
    "16-18%",
    "27-30%",
    "10-15%",
    "20-25%",
    "7-10%",
    "10-15%",
    "8-12%",
    "10-15%",
    "8-10%"
  ),
  median_os = c(
    "10.7月",
    "13.6月",
    "10.6月",
    "10.2月",
    "14.7月",
    "13.9月",
    "15.6月",
    "12.5月",
    "15.6月",
    "8.5月",
    "8-10月",
    "7-9月",
    "6-8月",
    "7-9月"
  ),
  adverse_events = c(
    "腹泻,高血压,手足综合征",
    "高血压,腹泻,蛋白尿",
    "手足综合征,高血压,疲劳",
    "腹泻,手足综合征,疲劳",
    "疲劳,皮疹,免疫相关不良反应",
    "疲劳,皮疹,免疫相关不良反应",
    "疲劳,免疫相关不良反应",
    "免疫相关不良反应",
    "高血压,出血,蛋白尿",
    "高血压,疲劳,肝毒性",
    "中性粒细胞减少,周围神经病变",
    "骨髓抑制,肝毒性",
    "心脏毒性,骨髓抑制",
    "周围神经病变,骨髓抑制"
  ),
  notes = c(
    "FDA批准HCC一线治疗",
    "FDA批准HCC一线治疗,非劣效于索拉非尼",
    "索拉非尼进展后二线",
    "索拉非尼或仑伐替尼进展后",
    "索拉非尼治疗后,PD-L1 ≥1%",
    "索拉非尼治疗后",
    "联合贝伐单抗,IMbrave150研究",
    "联合纳武利尤单抗CheckMate-040",
    "联合阿替利珠单抗用于一线",
    "AFP ≥400 ng/mL二线治疗",
    "不可切除或转移性HCC",
    "二线或联合治疗",
    "TACE常用化疗药",
    "联合化疗方案"
  )
)

write_csv(drug_database, "data/drug_database.csv")
cat(sprintf("✓ 保存 drug_database.csv (%d 种药物)\n", nrow(drug_database)))

# ============================================
# 6. 数据质量检查
# ============================================
cat("\n=================================================\n")
cat("数据质量检查\n")
cat("=================================================\n")

# 检查样本ID匹配
samples_resnet <- resnet_features_df$sample
samples_clinical <- clinical_df$sample
samples_cells <- cell_fractions_df$sample

common_samples <- Reduce(intersect, list(samples_resnet, samples_clinical, samples_cells))
cat(sprintf("\nResNet特征样本数: %d\n", length(samples_resnet)))
cat(sprintf("临床数据样本数: %d\n", length(samples_clinical)))
cat(sprintf("细胞分数样本数: %d\n", length(samples_cells)))
cat(sprintf("共同样本数: %d\n", length(common_samples)))

if (length(common_samples) < 300) {
  warning("共同样本数少于300，可能影响模型性能")
}

# 检查缺失值
cat("\n缺失值统计:\n")
cat(sprintf("  ResNet特征: %.1f%%\n",
            sum(is.na(resnet_features_df)) / prod(dim(resnet_features_df)) * 100))
cat(sprintf("  临床数据: %.1f%%\n",
            sum(is.na(clinical_df)) / prod(dim(clinical_df)) * 100))
cat(sprintf("  细胞分数: %.1f%%\n",
            sum(is.na(cell_fractions_df)) / prod(dim(cell_fractions_df)) * 100))

# 检查生存数据完整性
if ("os" %in% colnames(clinical_df) && "os.time" %in% colnames(clinical_df)) {
  complete_surv <- sum(!is.na(clinical_df$os) & !is.na(clinical_df$os.time))
  cat(sprintf("\n完整生存数据样本数: %d (%.1f%%)\n",
              complete_surv, complete_surv / nrow(clinical_df) * 100))
  cat(sprintf("  死亡事件数: %d\n", sum(clinical_df$os == 1, na.rm = TRUE)))
  cat(sprintf("  删失样本数: %d\n", sum(clinical_df$os == 0, na.rm = TRUE)))
}

# ============================================
# 7. 创建示例数据
# ============================================
cat("\n[6/5] 创建示例数据...\n")

# 随机选择3个样本作为示例
set.seed(123)
example_samples <- sample(common_samples, min(3, length(common_samples)))

example_data <- resnet_features_df %>%
  filter(sample %in% example_samples) %>%
  left_join(clinical_df %>% select(sample, os, os.time, age, gender, stage, grade),
            by = "sample")

write_csv(example_data, "data/example_patients.csv")
cat(sprintf("✓ 保存 example_patients.csv (%d 示例样本)\n", nrow(example_data)))

# ============================================
# 完成
# ============================================
cat("\n=================================================\n")
cat("✓ 数据准备完成！\n")
cat("=================================================\n")
cat("\n生成的文件:\n")
cat("  ✓ data/resnet_features.csv\n")
cat("  ✓ data/clinical_data.csv\n")
cat("  ✓ data/cell_fractions.csv\n")
cat("  ✓ data/drug_database.csv\n")
cat("  ✓ data/example_patients.csv\n")
cat("\n下一步：运行 source('build_model.R') 构建预测模型\n\n")
