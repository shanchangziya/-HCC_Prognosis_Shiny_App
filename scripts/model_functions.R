# HCC预后预测模型 - 辅助函数库
# 包含数据处理、模型预测、可视化等功能函数

# 数据处理函数 ====================================================

#' 标准化ResNet特征
#' @param features 数值向量，ResNet50特征值
#' @return 标准化后的特征
normalize_resnet_features <- function(features) {
  # Z-score标准化
  scaled <- scale(features)
  return(as.numeric(scaled))
}

#' 计算氧化应激评分
#' @param os_high OS-high肿瘤细胞比例
#' @param os_low OS-low肿瘤细胞比例
#' @return 氧化应激评分
calculate_os_score <- function(os_high, os_low) {
  # 简单的比值评分
  total <- os_high + os_low
  if (total == 0) return(0)
  return(os_high / total)
}

#' 计算免疫浸润评分
#' @param cell_fractions 数据框，包含各细胞类型分数
#' @return 免疫评分
calculate_immune_score <- function(cell_fractions) {
  # 关键免疫细胞类型
  immune_cells <- c(
    "CD8_Trm_Activated_Trm",
    "CD8_Trm_Cytotoxic_Trm",
    "NK_CD56dim_NK",
    "CD4_Cyto_Effector_Cyto"
  )

  available_cells <- intersect(immune_cells, colnames(cell_fractions))
  if (length(available_cells) == 0) return(0)

  immune_score <- rowSums(cell_fractions[, available_cells, drop = FALSE], na.rm = TRUE)
  return(immune_score)
}

# 模型预测函数 ====================================================

#' 扩展的预测函数（包含置信区间）
#' @param model Cox模型对象
#' @param new_data 新数据框
#' @return 包含预测结果的列表
predict_with_confidence <- function(model, new_data) {
  # 点估计
  risk_score <- predict(model, newdata = new_data, type = "risk")
  risk_lp <- predict(model, newdata = new_data, type = "lp")

  # 标准误
  se <- predict(model, newdata = new_data, type = "lp", se.fit = TRUE)$se.fit

  # 95%置信区间
  ci_lower <- risk_lp - 1.96 * se
  ci_upper <- risk_lp + 1.96 * se

  return(list(
    risk_score = risk_score,
    risk_lp = risk_lp,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    se = se
  ))
}

#' 计算多时间点生存概率
#' @param model Cox模型
#' @param new_data 新数据
#' @param times 时间点向量（天数）
#' @return 生存概率矩阵
predict_survival_curves <- function(model, new_data, times = c(365, 1095, 1825)) {
  # 使用survfit预测
  surv_obj <- survfit(model, newdata = new_data)

  # 提取指定时间点的生存概率
  surv_probs <- summary(surv_obj, times = times)$surv

  return(surv_probs)
}

# 可视化函数 ======================================================

#' 绘制风险评分分布图
#' @param data 数据框，包含risk_score和risk_group
#' @param cutoff 风险分割点
#' @return ggplot对象
plot_risk_distribution <- function(data, cutoff) {
  library(ggplot2)

  p <- ggplot(data, aes(x = risk_score, fill = risk_group)) +
    geom_histogram(bins = 30, alpha = 0.7, position = "identity") +
    geom_vline(xintercept = cutoff, linetype = "dashed", size = 1) +
    scale_fill_manual(values = c("High" = "#E74C3C", "Low" = "#3498DB"),
                      labels = c("高风险", "低风险")) +
    labs(
      title = "风险评分分布",
      x = "Risk Score",
      y = "频数",
      fill = "风险组"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      legend.position = "top"
    )

  return(p)
}

#' 绘制校准曲线
#' @param model Cox模型
#' @param data 数据框
#' @param time 预测时间点（天数）
#' @return ggplot对象
plot_calibration_curve <- function(model, data, time = 1095) {
  library(rms)
  library(ggplot2)

  # 计算预测生存概率
  pred_surv <- 1 - predict(model, type = "expected") / time

  # 实际生存率（K-M估计）
  data$pred_prob <- pred_surv
  data$pred_group <- cut(pred_surv, breaks = seq(0, 1, 0.1), include.lowest = TRUE)

  # 按预测概率分组计算实际生存率
  cal_data <- data %>%
    group_by(pred_group) %>%
    summarise(
      pred_mean = mean(pred_prob, na.rm = TRUE),
      obs_surv = sum(os.time >= time & os == 0) / n(),
      n = n()
    ) %>%
    filter(n >= 10)

  # 绘图
  p <- ggplot(cal_data, aes(x = pred_mean, y = obs_surv)) +
    geom_point(aes(size = n), alpha = 0.6, color = "#3498DB") +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") +
    geom_smooth(method = "loess", se = TRUE, color = "#2ECC71") +
    scale_size_continuous(range = c(3, 10)) +
    labs(
      title = sprintf("校准曲线 (%d年)", time/365),
      x = "预测生存概率",
      y = "观察生存概率",
      size = "样本数"
    ) +
    xlim(0, 1) + ylim(0, 1) +
    theme_minimal(base_size = 14) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"))

  return(p)
}

#' 绘制时间依赖ROC曲线
#' @param model Cox模型
#' @param data 数据框
#' @param times 时间点向量
#' @return ggplot对象
plot_time_dependent_roc <- function(model, data, times = c(365, 1095, 1825)) {
  library(survivalROC)
  library(ggplot2)

  roc_data <- lapply(times, function(t) {
    roc_obj <- survivalROC(
      Stime = data$os.time,
      status = data$os,
      marker = predict(model, type = "lp"),
      predict.time = t,
      method = "KM"
    )

    data.frame(
      FPR = roc_obj$FP,
      TPR = roc_obj$TP,
      Time = paste0(t/365, "年"),
      AUC = roc_obj$AUC
    )
  })

  roc_df <- do.call(rbind, roc_data)

  p <- ggplot(roc_df, aes(x = FPR, y = TPR, color = Time)) +
    geom_line(size = 1.2) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray50") +
    geom_text(
      data = roc_df %>% group_by(Time) %>% slice(1),
      aes(label = sprintf("AUC=%.3f", AUC)),
      x = 0.7, y = c(0.3, 0.2, 0.1),
      hjust = 0
    ) +
    scale_color_brewer(palette = "Set1") +
    labs(
      title = "时间依赖ROC曲线",
      x = "假阳性率 (1 - Specificity)",
      y = "真阳性率 (Sensitivity)"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      legend.position = c(0.8, 0.3),
      legend.background = element_rect(fill = "white", color = "black")
    )

  return(p)
}

# 药物推荐函数 ====================================================

#' 智能药物推荐
#' @param risk_score 风险评分
#' @param os_high_frac OS-high肿瘤比例
#' @param immune_score 免疫评分
#' @param drug_db 药物数据库
#' @return 推荐药物数据框
smart_drug_recommendation <- function(risk_score, os_high_frac, immune_score, drug_db) {
  # 风险分层
  risk_label <- ifelse(risk_score > median(risk_score), "高风险", "中风险")

  # 初步筛选
  drugs <- drug_db %>%
    filter(grepl(risk_label, risk_group, ignore.case = TRUE))

  # 基于OS状态调整
  if (!is.null(os_high_frac) && os_high_frac > 0.5) {
    drugs <- drugs %>%
      mutate(priority = case_when(
        os_high_suitable == "推荐" ~ 3,
        os_high_suitable == "条件推荐" ~ 2,
        TRUE ~ 1
      ))
  } else {
    drugs$priority <- 2
  }

  # 基于免疫状态调整
  if (!is.null(immune_score) && immune_score > 0.3) {
    drugs <- drugs %>%
      mutate(priority = priority + ifelse(immune_high_suitable == "推荐", 2, 0))
  }

  # 排序
  drugs <- drugs %>%
    arrange(desc(priority)) %>%
    select(-priority)

  return(drugs)
}

# 数据验证函数 ====================================================

#' 验证输入数据完整性
#' @param data 数据框
#' @param required_cols 必需列名向量
#' @return 逻辑值和错误信息列表
validate_input_data <- function(data, required_cols) {
  missing_cols <- setdiff(required_cols, colnames(data))

  if (length(missing_cols) > 0) {
    return(list(
      valid = FALSE,
      message = paste("缺少必需列:", paste(missing_cols, collapse = ", "))
    ))
  }

  # 检查数据范围
  if ("RS" %in% colnames(data)) {
    if (any(abs(data$RS) > 10, na.rm = TRUE)) {
      return(list(
        valid = FALSE,
        message = "RS值超出合理范围(-10到10)"
      ))
    }
  }

  if ("age" %in% colnames(data)) {
    if (any(data$age < 0 | data$age > 120, na.rm = TRUE)) {
      return(list(
        valid = FALSE,
        message = "年龄值不合理"
      ))
    }
  }

  return(list(valid = TRUE, message = "数据验证通过"))
}

# 报告生成函数 ====================================================

#' 生成患者预后报告
#' @param patient_id 患者ID
#' @param prediction_result 预测结果列表
#' @param drug_recommendations 药物推荐数据框
#' @return 格式化的HTML报告
generate_patient_report <- function(patient_id, prediction_result, drug_recommendations) {
  library(htmltools)

  report <- div(
    class = "patient-report",
    h2(paste("患者", patient_id, "预后评估报告")),
    hr(),

    h3("预测结果"),
    tags$ul(
      tags$li(strong("风险分层: "), prediction_result$risk_group),
      tags$li(strong("风险评分: "), sprintf("%.3f", prediction_result$risk_score)),
      tags$li(strong("1年生存概率: "), sprintf("%.1f%%", prediction_result$surv_1yr * 100)),
      tags$li(strong("3年生存概率: "), sprintf("%.1f%%", prediction_result$surv_3yr * 100)),
      tags$li(strong("5年生存概率: "), sprintf("%.1f%%", prediction_result$surv_5yr * 100))
    ),

    h3("治疗建议"),
    if (nrow(drug_recommendations) > 0) {
      tags$ol(
        lapply(1:min(5, nrow(drug_recommendations)), function(i) {
          tags$li(
            strong(drug_recommendations$drug_name[i]),
            " - ",
            drug_recommendations$indication[i]
          )
        })
      )
    } else {
      p("暂无推荐药物")
    },

    hr(),
    p(
      em("本报告仅供参考，不作为临床诊断依据。"),
      style = "color: #E74C3C; font-size: 12px;"
    ),
    p(
      paste("生成时间:", Sys.time()),
      style = "text-align: right; font-size: 10px; color: #7F8C8D;"
    )
  )

  return(report)
}

# 导出所有函数
# (在实际使用时，source此文件即可使用所有函数)
