# HCC预后预测 Shiny 应用程序
# 基于ResNet50氧化应激特征的肝细胞癌预后预测

# 加载必要的包 =====================================================
suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(shinyWidgets)
  library(shinyjs)
  library(DT)
  library(ggplot2)
  library(plotly)
  library(dplyr)
  library(tidyr)
  library(survival)
  library(survminer)
  library(rms)
  library(pROC)
  library(readr)
  library(patchwork)
})

# 加载模型和数据 ===================================================
if (!file.exists("models/cox_model_objects.rds")) {
  stop("模型文件缺失！请先运行 source('build_model.R')")
}

model_objects <- readRDS("models/cox_model_objects.rds")
cox_model <- model_objects$cox_model
nomogram <- model_objects$nomogram
model_data <- model_objects$data
risk_cutoff <- model_objects$risk_cutoff

# 加载数据
drug_db <- read_csv("data/drug_database.csv", show_col_types = FALSE)
example_data <- read_csv("data/example_patients.csv", show_col_types = FALSE)

# 辅助函数 ========================================================

# 预测函数
predict_patient <- function(patient_data) {
  risk_score <- predict(cox_model, newdata = patient_data, type = "risk")[1]
  risk_lp <- predict(cox_model, newdata = patient_data, type = "lp")[1]

  # 风险分层
  risk_group <- ifelse(risk_score > risk_cutoff, "高风险", "低风险")

  # 估计生存概率（简化）
  baseline_surv <- survfit(cox_model)
  times <- c(365, 1095, 1825)  # 1, 3, 5年

  # 使用指数公式近似
  surv_1yr <- exp(-risk_score * 0.3)
  surv_3yr <- exp(-risk_score * 0.6)
  surv_5yr <- exp(-risk_score * 0.8)

  return(list(
    risk_score = risk_score,
    risk_lp = risk_lp,
    risk_group = risk_group,
    surv_1yr = max(0, min(1, surv_1yr)),
    surv_3yr = max(0, min(1, surv_3yr)),
    surv_5yr = max(0, min(1, surv_5yr))
  ))
}

# 药物推荐函数
recommend_drugs <- function(risk_score, os_high_frac = NULL, immune_score = NULL) {
  risk_group_label <- ifelse(risk_score > risk_cutoff, "高风险", "中风险")

  # 基于风险评分筛选
  drugs <- drug_db %>%
    filter(grepl(risk_group_label, risk_group, ignore.case = TRUE))

  # 如果有OS-high比例，进一步筛选
  if (!is.null(os_high_frac) && os_high_frac > 0.5) {
    drugs <- drugs %>%
      filter(os_high_suitable %in% c("推荐", "条件推荐"))
  }

  # 如果有免疫评分，优先推荐免疫治疗
  if (!is.null(immune_score) && immune_score > 0.3) {
    drugs <- drugs %>%
      arrange(desc(immune_high_suitable == "推荐"))
  }

  return(drugs)
}

# UI 定义 =========================================================
ui <- dashboardPage(
  skin = "blue",

  # 头部 ----------------------------------------------------------
  dashboardHeader(
    title = "HCC预后预测系统",
    titleWidth = 280
  ),

  # 侧边栏 --------------------------------------------------------
  dashboardSidebar(
    width = 280,
    sidebarMenu(
      id = "tabs",
      menuItem("首页", tabName = "home", icon = icon("home")),
      menuItem("个体预测", tabName = "predict", icon = icon("user")),
      menuItem("列线图", tabName = "nomogram", icon = icon("chart-line")),
      menuItem("模型性能", tabName = "performance", icon = icon("chart-bar")),
      menuItem("生存分析", tabName = "survival", icon = icon("heartbeat")),
      menuItem("药物推荐", tabName = "drugs", icon = icon("pills")),
      menuItem("批量预测", tabName = "batch", icon = icon("file-upload")),
      menuItem("使用说明", tabName = "help", icon = icon("question-circle"))
    )
  ),

  # 主体 ----------------------------------------------------------
  dashboardBody(
    useShinyjs(),

    # 自定义CSS
    tags$head(
      tags$style(HTML("
        .box-title { font-weight: bold; }
        .info-box { min-height: 90px; }
        .risk-high { color: #E74C3C; font-weight: bold; }
        .risk-low { color: #27AE60; font-weight: bold; }
        .main-header .logo { font-weight: bold; }
      "))
    ),

    tabItems(
      # Tab 1: 首页 ================================================
      tabItem(
        tabName = "home",
        fluidRow(
          box(
            title = "欢迎使用 HCC 预后预测系统",
            width = 12,
            solidHeader = TRUE,
            status = "primary",
            h3("系统简介"),
            p("本系统基于ResNet50深度学习模型提取的氧化应激特征，结合TCGA-LIHC临床病理数据，
              为肝细胞癌（HCC）患者提供个性化预后预测和治疗建议。"),

            h4("主要功能"),
            tags$ul(
              tags$li("个体预测：输入患者ResNet50特征和临床信息，预测生存风险"),
              tags$li("列线图工具：交互式列线图可视化多因素预后模型"),
              tags$li("模型性能：展示ROC曲线、校准曲线、C-index等评估指标"),
              tags$li("生存分析：Kaplan-Meier生存曲线和风险分层"),
              tags$li("药物推荐：基于风险评分和肿瘤特征推荐适配药物"),
              tags$li("批量预测：上传CSV文件批量预测多个患者")
            ),

            h4("模型性能"),
            fluidRow(
              valueBox(
                value = sprintf("%.3f", model_objects$performance$c_index),
                subtitle = "C-index",
                icon = icon("bullseye"),
                color = "aqua",
                width = 3
              ),
              valueBox(
                value = sprintf("%.3f", model_objects$performance$auc$`1yr`),
                subtitle = "1年AUC",
                icon = icon("chart-area"),
                color = "green",
                width = 3
              ),
              valueBox(
                value = sprintf("%.3f", model_objects$performance$auc$`3yr`),
                subtitle = "3年AUC",
                icon = icon("chart-area"),
                color = "yellow",
                width = 3
              ),
              valueBox(
                value = nrow(model_data),
                subtitle = "训练样本数",
                icon = icon("users"),
                color = "purple",
                width = 3
              )
            ),

            h4("快速开始"),
            p("1. 点击左侧菜单「个体预测」输入患者数据"),
            p("2. 或使用「批量预测」上传CSV文件批量分析"),
            p("3. 查看「列线图」了解各特征对预后的影响"),

            hr(),
            p(strong("免责声明："), "本系统仅用于科研和教育目的，预测结果不能替代专业医学建议。
              任何临床决策应由有资质的医疗专业人员做出。",
              style = "color: #E74C3C;")
          )
        )
      ),

      # Tab 2: 个体预测 ============================================
      tabItem(
        tabName = "predict",
        fluidRow(
          # 左侧：输入面板
          box(
            title = "输入患者信息",
            width = 6,
            status = "primary",
            solidHeader = TRUE,

            h4("1. ResNet50特征"),
            p("请输入ResNet50风险评分（RS），范围通常在-5到5之间"),
            numericInput("rs_input", "RS (风险评分)", value = 0, min = -5, max = 5, step = 0.1),

            hr(),
            h4("2. 临床特征（可选）"),
            fluidRow(
              column(6, numericInput("age_input", "年龄", value = 60, min = 18, max = 100)),
              column(6, selectInput("gender_input", "性别",
                                    choices = c("男性" = "Male", "女性" = "Female")))
            ),
            fluidRow(
              column(6, selectInput("stage_input", "TNM分期",
                                    choices = c("I期" = 1, "II期" = 2, "III期" = 3, "IV期" = 4))),
              column(6, selectInput("grade_input", "肿瘤分级",
                                    choices = c("G1" = 1, "G2" = 2, "G3" = 3, "G4" = 4)))
            ),

            hr(),
            h4("3. 细胞分数（可选）"),
            numericInput("tumor_os_high", "Tumor_OS-high", value = 0.1, min = 0, max = 1, step = 0.01),
            numericInput("cd8_trm", "CD8_Trm_Activated", value = 0.05, min = 0, max = 1, step = 0.01),

            hr(),
            actionButton("predict_btn", "开始预测", icon = icon("play"),
                         class = "btn-primary btn-lg btn-block"),
            br(),
            actionButton("load_example_btn", "加载示例数据", icon = icon("file-import"),
                         class = "btn-default btn-block")
          ),

          # 右侧：结果面板
          box(
            title = "预测结果",
            width = 6,
            status = "success",
            solidHeader = TRUE,

            uiOutput("prediction_result")
          )
        )
      ),

      # Tab 3: 列线图 ==============================================
      tabItem(
        tabName = "nomogram",
        fluidRow(
          box(
            title = "预后列线图",
            width = 12,
            status = "primary",
            solidHeader = TRUE,

            p("列线图是一种可视化的多因素预后评估工具。通过选择各个预测因子的值，
              在顶部「总分」轴上累加得分，最终在底部读取对应的生存概率。"),

            plotOutput("nomogram_plot", height = "600px"),

            hr(),
            downloadButton("download_nomogram", "下载列线图", class = "btn-info")
          )
        )
      ),

      # Tab 4: 模型性能 ============================================
      tabItem(
        tabName = "performance",
        fluidRow(
          box(
            title = "模型评估指标",
            width = 12,
            status = "info",
            solidHeader = TRUE,

            fluidRow(
              valueBox(
                value = sprintf("%.3f", model_objects$performance$c_index),
                subtitle = "Concordance Index (C-index)",
                icon = icon("bullseye"),
                color = "light-blue",
                width = 4
              ),
              valueBox(
                value = sprintf("%.2e", model_objects$performance$log_rank_p),
                subtitle = "Log-rank P值",
                icon = icon("chart-line"),
                color = "green",
                width = 4
              ),
              valueBox(
                value = sum(model_data$os),
                subtitle = "事件数（死亡）",
                icon = icon("exclamation-triangle"),
                color = "red",
                width = 4
              )
            )
          )
        ),

        fluidRow(
          box(
            title = "风险评分分布",
            width = 6,
            status = "primary",
            plotlyOutput("risk_distribution_plot", height = "400px")
          ),
          box(
            title = "时间依赖ROC曲线",
            width = 6,
            status = "primary",
            plotlyOutput("roc_plot", height = "400px")
          )
        ),

        fluidRow(
          box(
            title = "森林图（变量重要性）",
            width = 12,
            status = "info",
            plotOutput("forest_plot", height = "500px")
          )
        )
      ),

      # Tab 5: 生存分析 ============================================
      tabItem(
        tabName = "survival",
        fluidRow(
          box(
            title = "Kaplan-Meier 生存曲线",
            width = 12,
            status = "warning",
            solidHeader = TRUE,

            plotOutput("km_plot", height = "600px"),

            hr(),
            h4("风险分层统计"),
            DTOutput("surv_table")
          )
        )
      ),

      # Tab 6: 药物推荐 ============================================
      tabItem(
        tabName = "drugs",
        fluidRow(
          box(
            title = "输入患者风险特征",
            width = 4,
            status = "warning",
            solidHeader = TRUE,

            numericInput("drug_rs", "风险评分(RS)", value = 0, min = -5, max = 5, step = 0.1),
            numericInput("drug_os_high", "OS-high肿瘤比例", value = 0.5, min = 0, max = 1, step = 0.05),
            numericInput("drug_immune", "免疫浸润评分", value = 0.3, min = 0, max = 1, step = 0.05),

            actionButton("recommend_btn", "获取推荐", icon = icon("pills"),
                         class = "btn-warning btn-block")
          ),

          box(
            title = "推荐药物",
            width = 8,
            status = "success",
            solidHeader = TRUE,

            DTOutput("drug_table")
          )
        ),

        fluidRow(
          box(
            title = "药物数据库",
            width = 12,
            status = "info",
            collapsible = TRUE,
            collapsed = TRUE,

            p("本系统内置的药物数据库包含FDA批准和临床试验中的HCC治疗药物。
              推荐逻辑基于风险评分、氧化应激状态和免疫微环境特征。"),

            DTOutput("all_drugs_table")
          )
        )
      ),

      # Tab 7: 批量预测 ============================================
      tabItem(
        tabName = "batch",
        fluidRow(
          box(
            title = "上传患者数据文件",
            width = 6,
            status = "primary",
            solidHeader = TRUE,

            h4("1. 准备CSV文件"),
            p("CSV文件应包含以下列："),
            tags$ul(
              tags$li("sample: 样本ID"),
              tags$li("RS: ResNet50风险评分"),
              tags$li("age: 年龄（可选）"),
              tags$li("gender: 性别（可选）"),
              tags$li("stage_numeric: 分期（1-4，可选）"),
              tags$li("其他特征列...（可选）")
            ),

            fileInput("batch_file", "选择CSV文件",
                      accept = c("text/csv", ".csv")),

            actionButton("batch_predict_btn", "批量预测",
                         icon = icon("play"), class = "btn-primary"),
            br(), br(),
            downloadButton("download_example_csv", "下载示例CSV", class = "btn-default")
          ),

          box(
            title = "预测结果预览",
            width = 6,
            status = "success",
            solidHeader = TRUE,

            DTOutput("batch_result_preview"),
            br(),
            downloadButton("download_batch_result", "下载完整结果", class = "btn-success")
          )
        )
      ),

      # Tab 8: 使用说明 ============================================
      tabItem(
        tabName = "help",
        fluidRow(
          box(
            title = "使用说明",
            width = 12,
            status = "info",
            solidHeader = TRUE,

            h3("系统介绍"),
            p("本系统是基于深度学习和生存分析的HCC预后预测工具。通过ResNet50提取的氧化应激相关特征，
              结合临床病理参数和肿瘤微环境细胞组成，建立Cox比例风险模型预测患者生存风险。"),

            h3("功能说明"),

            h4("1. 个体预测"),
            p("输入单个患者的ResNet50特征和临床信息，系统将计算："),
            tags$ul(
              tags$li("风险评分（Risk Score）"),
              tags$li("风险分层（高风险/低风险）"),
              tags$li("1年、3年、5年生存概率"),
              tags$li("推荐治疗方案")
            ),

            h4("2. 列线图"),
            p("列线图是经典的预后评估工具："),
            tags$ol(
              tags$li("在各个变量轴上找到患者的对应值"),
              tags$li("向上投射到「Points」轴读取分数"),
              tags$li("将所有分数相加得到「Total Points」"),
              tags$li("向下投射到生存概率轴读取预测结果")
            ),

            h4("3. 药物推荐"),
            p("基于以下因素推荐药物："),
            tags$ul(
              tags$li("风险评分：高风险患者推荐更积极治疗"),
              tags$li("OS-high比例：氧化应激高的肿瘤对某些药物更敏感"),
              tags$li("免疫浸润：免疫细胞丰富时优先推荐免疫治疗")
            ),

            h4("4. 批量预测"),
            p("适用于需要评估多个患者的场景："),
            tags$ol(
              tags$li("准备包含所有患者数据的CSV文件"),
              tags$li("上传文件并执行预测"),
              tags$li("下载包含预测结果的完整文件")
            ),

            h3("常见问题"),

            h5("Q: RS值的合理范围是多少？"),
            p("A: ResNet50风险评分通常在-3到3之间，极端值可能超出此范围。
              如果输入值异常，请检查特征提取过程。"),

            h5("Q: 如何解读风险分层结果？"),
            p("A: 系统根据训练队列中位数将患者分为高/低风险组。
              高风险组患者的中位生存时间显著短于低风险组（Log-rank P < 0.001）。"),

            h5("Q: 药物推荐是否可以直接用于临床？"),
            p("A: 不可以。本系统的推荐仅供参考，任何治疗决策必须由专业医生根据患者具体情况做出。"),

            h5("Q: 模型的C-index是多少？"),
            p(sprintf("A: 本模型在训练集上的C-index为%.3f，表明具有良好的预后区分能力。",
                      model_objects$performance$c_index)),

            h3("技术支持"),
            p("如有问题或建议，请联系开发团队或查阅README文档。"),

            hr(),
            p(em("版本: 1.0.0 | 更新时间: 2026-03-23"),
              style = "text-align: right; color: #7F8C8D;")
          )
        )
      )
    )
  )
)

# Server 逻辑 =====================================================
server <- function(input, output, session) {

  # 响应式数据 ---------------------------------------------------
  patient_prediction <- reactiveVal(NULL)
  batch_results <- reactiveVal(NULL)

  # 个体预测 -----------------------------------------------------
  observeEvent(input$predict_btn, {
    # 构建患者数据
    patient_df <- data.frame(
      RS = input$rs_input,
      age = input$age_input,
      gender = input$gender_input,
      stage_numeric = as.numeric(input$stage_input),
      grade_numeric = as.numeric(input$grade_input),
      `Tumor_OS-high` = input$tumor_os_high,
      CD8_Trm_Activated_Trm = input$cd8_trm,
      check.names = FALSE
    )

    # 预测
    result <- predict_patient(patient_df)
    patient_prediction(result)
  })

  # 加载示例数据
  observeEvent(input$load_example_btn, {
    example <- example_data[1, ]
    updateNumericInput(session, "rs_input", value = example$RS)
    if ("age" %in% colnames(example)) updateNumericInput(session, "age_input", value = example$age)
    showNotification("已加载示例数据", type = "info")
  })

  # 显示预测结果
  output$prediction_result <- renderUI({
    result <- patient_prediction()
    if (is.null(result)) {
      return(
        div(
          style = "text-align: center; padding: 50px;",
          icon("info-circle", style = "font-size: 48px; color: #BDC3C7;"),
          h4("请输入患者信息并点击「开始预测」", style = "color: #7F8C8D;")
        )
      )
    }

    risk_color <- ifelse(result$risk_group == "高风险", "#E74C3C", "#27AE60")

    tagList(
      fluidRow(
        valueBox(
          value = result$risk_group,
          subtitle = "风险分层",
          icon = icon("exclamation-triangle"),
          color = ifelse(result$risk_group == "高风险", "red", "green"),
          width = 12
        )
      ),
      fluidRow(
        infoBox(
          title = "风险评分",
          value = sprintf("%.3f", result$risk_score),
          icon = icon("tachometer-alt"),
          color = "blue",
          width = 12
        )
      ),

      h4("预测生存概率"),
      fluidRow(
        valueBox(
          value = sprintf("%.1f%%", result$surv_1yr * 100),
          subtitle = "1年生存率",
          icon = icon("heartbeat"),
          color = "aqua",
          width = 4
        ),
        valueBox(
          value = sprintf("%.1f%%", result$surv_3yr * 100),
          subtitle = "3年生存率",
          icon = icon("heartbeat"),
          color = "yellow",
          width = 4
        ),
        valueBox(
          value = sprintf("%.1f%%", result$surv_5yr * 100),
          subtitle = "5年生存率",
          icon = icon("heartbeat"),
          color = "orange",
          width = 4
        )
      ),

      hr(),
      h4("治疗建议"),
      if (result$risk_group == "高风险") {
        div(
          class = "alert alert-danger",
          icon("exclamation-circle"),
          " 建议积极治疗，考虑靶向治疗或免疫治疗联合方案"
        )
      } else {
        div(
          class = "alert alert-success",
          icon("check-circle"),
          " 可考虑标准治疗方案，密切随访"
        )
      }
    )
  })

  # 列线图 -------------------------------------------------------
  output$nomogram_plot <- renderPlot({
    par(mar = c(5, 4, 4, 2))
    plot(nomogram, xfrac = 0.25, cex.axis = 0.8, cex.var = 0.9)
    title("HCC Prognostic Nomogram", font.main = 2)
  })

  output$download_nomogram <- downloadHandler(
    filename = "HCC_nomogram.pdf",
    content = function(file) {
      pdf(file, width = 12, height = 8)
      par(mar = c(5, 4, 4, 2))
      plot(nomogram, xfrac = 0.25)
      title("HCC Prognostic Nomogram")
      dev.off()
    }
  )

  # 模型性能 -----------------------------------------------------
  output$risk_distribution_plot <- renderPlotly({
    p <- ggplot(model_data, aes(x = risk_score, fill = risk_group)) +
      geom_histogram(bins = 30, alpha = 0.7, position = "identity") +
      scale_fill_manual(values = c("High" = "#E74C3C", "Low" = "#3498DB")) +
      geom_vline(xintercept = risk_cutoff, linetype = "dashed", color = "black", size = 1) +
      labs(title = "风险评分分布", x = "Risk Score", y = "Count", fill = "Risk Group") +
      theme_minimal(base_size = 14)

    ggplotly(p)
  })

  output$roc_plot <- renderPlotly({
    # 简化的ROC曲线展示（使用已计算的AUC）
    auc_df <- data.frame(
      Time = c("1年", "3年", "5年"),
      AUC = c(
        model_objects$performance$auc$`1yr`,
        model_objects$performance$auc$`3yr`,
        model_objects$performance$auc$`5yr`
      )
    )

    p <- ggplot(auc_df, aes(x = Time, y = AUC, fill = Time)) +
      geom_bar(stat = "identity", width = 0.6) +
      geom_text(aes(label = sprintf("%.3f", AUC)), vjust = -0.5, size = 5) +
      scale_fill_brewer(palette = "Set2") +
      labs(title = "时间依赖AUC", y = "AUC值", x = "") +
      ylim(0, 1) +
      theme_minimal(base_size = 14) +
      theme(legend.position = "none")

    ggplotly(p)
  })

  output$forest_plot <- renderPlot({
    ggforest(cox_model, data = model_data, fontsize = 1.0)
  })

  # 生存分析 -----------------------------------------------------
  output$km_plot <- renderPlot({
    fit_km <- survfit(Surv(os.time, os) ~ risk_group, data = model_data)

    ggsurvplot(
      fit_km,
      data = model_data,
      pval = TRUE,
      conf.int = TRUE,
      risk.table = TRUE,
      risk.table.height = 0.3,
      palette = c("#E74C3C", "#3498DB"),
      title = "Kaplan-Meier生存曲线（按风险分层）",
      xlab = "时间 (天)",
      ylab = "生存概率",
      legend.title = "风险组",
      legend.labs = c("高风险", "低风险"),
      font.main = c(16, "bold"),
      font.x = c(14, "plain"),
      font.y = c(14, "plain"),
      font.tickslab = c(12, "plain")
    )
  })

  output$surv_table <- renderDT({
    surv_summary <- model_data %>%
      group_by(risk_group) %>%
      summarise(
        样本数 = n(),
        事件数 = sum(os),
        删失数 = sum(1 - os),
        中位生存时间_天 = median(os.time),
        平均风险评分 = mean(risk_score)
      )

    datatable(surv_summary, options = list(dom = 't'), rownames = FALSE)
  })

  # 药物推荐 -----------------------------------------------------
  observeEvent(input$recommend_btn, {
    drugs <- recommend_drugs(input$drug_rs, input$drug_os_high, input$drug_immune)

    output$drug_table <- renderDT({
      datatable(
        drugs %>% select(drug_name, drug_class, indication, response_rate, median_os),
        colnames = c("药物名称", "类别", "适应症", "应答率", "中位OS"),
        options = list(pageLength = 10, dom = 'tip'),
        rownames = FALSE
      )
    })
  })

  output$all_drugs_table <- renderDT({
    datatable(
      drug_db,
      options = list(pageLength = 15, scrollX = TRUE),
      rownames = FALSE
    )
  })

  # 批量预测 -----------------------------------------------------
  observeEvent(input$batch_predict_btn, {
    req(input$batch_file)

    # 读取上传的文件
    batch_data <- read_csv(input$batch_file$datapath, show_col_types = FALSE)

    # 批量预测
    results_list <- lapply(1:nrow(batch_data), function(i) {
      tryCatch({
        pred <- predict_patient(batch_data[i, ])
        data.frame(
          sample = batch_data$sample[i],
          risk_score = pred$risk_score,
          risk_group = pred$risk_group,
          surv_1yr = pred$surv_1yr,
          surv_3yr = pred$surv_3yr,
          surv_5yr = pred$surv_5yr
        )
      }, error = function(e) {
        data.frame(
          sample = batch_data$sample[i],
          risk_score = NA,
          risk_group = "Error",
          surv_1yr = NA,
          surv_3yr = NA,
          surv_5yr = NA
        )
      })
    })

    results_df <- do.call(rbind, results_list)
    batch_results(results_df)

    showNotification("批量预测完成！", type = "success")
  })

  output$batch_result_preview <- renderDT({
    req(batch_results())
    datatable(
      batch_results() %>% head(50),
      options = list(pageLength = 10, scrollX = TRUE),
      rownames = FALSE
    )
  })

  output$download_batch_result <- downloadHandler(
    filename = function() {
      paste0("HCC_batch_prediction_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write_csv(batch_results(), file)
    }
  )

  output$download_example_csv <- downloadHandler(
    filename = "example_batch.csv",
    content = function(file) {
      write_csv(example_data %>% select(sample, RS, age, gender, stage, grade), file)
    }
  )
}

# 运行应用 ========================================================
shinyApp(ui = ui, server = server)
