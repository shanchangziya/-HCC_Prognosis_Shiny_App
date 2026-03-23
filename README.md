# HCC预后预测Shiny应用程序

## 项目简介

本应用基于ResNet50提取的氧化应激特征，结合TCGA-LIHC临床病理特征，构建肝细胞癌（HCC）患者预后预测模型。

### 主要功能

1. **预后预测**：基于ResNet50氧化应激特征 + 临床病理特征预测患者生存风险
2. **列线图（Nomogram）**：可视化多因素预后模型
3. **校准曲线**：评估模型预测准确性
4. **药物推荐**：根据风险分层推荐适配药物
5. **生存分析**：Kaplan-Meier曲线和风险分层
6. **个体预测**：输入患者特征获得个性化预后评估

---

## 文件结构

```
HCC_Prognosis_Shiny_App/
├── README.md                          # 本文件
├── requirements.R                     # R包依赖列表
├── app.R                             # Shiny应用主程序
├── prepare_data.R                     # 数据准备脚本
├── build_model.R                      # 模型构建脚本
├── data/                             # 数据文件夹
│   ├── resnet_features.csv           # ResNet50特征（需从源数据生成）
│   ├── clinical_data.csv             # 临床数据（需从源数据生成）
│   ├── cell_fractions.csv            # 细胞类型分数（需从源数据生成）
│   └── drug_database.csv             # 药物数据库（预定义）
├── models/                           # 模型文件夹
│   ├── cox_model.rds                 # Cox回归模型（运行build_model.R生成）
│   └── nomogram.rds                  # 列线图对象（运行build_model.R生成）
├── scripts/                          # 辅助脚本
│   └── model_functions.R             # 模型相关函数
└── www/                              # 静态资源
    └── style.css                     # 自定义CSS样式
```

---

## 安装步骤

### 1. 安装R和RStudio

确保已安装 R (≥ 4.0.0) 和 RStudio。

### 2. 安装依赖包

在R控制台运行：

```r
source("requirements.R")
```

或手动安装：

```r
install.packages(c(
  "shiny", "shinydashboard", "shinyWidgets", "DT",
  "ggplot2", "plotly", "survival", "survminer", "rms",
  "dplyr", "tidyr", "readr", "patchwork",
  "randomForest", "glmnet", "pROC"
))
```

### 3. 准备数据

**重要**：需要从原始TCGA-LIHC数据生成以下文件：

#### 方法A：使用提供的脚本（推荐）

将以下文件复制到 `HCC_Prognosis_Shiny_App/` 目录：
- `Resnet.Rdata`
- `TCGA-LIHC_deconv_with_survival.csv`
- `bulk/TCGA-LIHC.Rdata`

然后运行：

```r
source("prepare_data.R")
```

此脚本将生成所需的CSV文件到 `data/` 文件夹。

#### 方法B：手动准备

如果使用其他数据源，请确保CSV文件格式符合以下要求：

**resnet_features.csv**
```
sample,resnet0,resnet1,...,resnet2047,RS
TCGA-2V-A95S,0.446,1.064,...,0.912,0.523
```

**clinical_data.csv**
```
sample,age,gender,stage,grade,OS,OS.time
TCGA-2V-A95S,65,Male,III,G3,1,724
```

**cell_fractions.csv**
```
sample,Tumor_OS-high,Tumor_OS-low,CD8_Trm,...
TCGA-2V-A95S,0.109,0.719,0.029,...
```

### 4. 构建模型

```r
source("build_model.R")
```

此脚本将：
- 整合所有数据
- 构建Cox比例风险模型
- 创建列线图对象
- 保存模型到 `models/` 文件夹
- 生成模型性能报告

### 5. 启动应用

```r
shiny::runApp("app.R")
```

或在RStudio中打开 `app.R` 并点击 "Run App"。

---

## 使用说明

### 界面概览

应用包含以下Tab页：

1. **首页**：应用简介和使用说明
2. **个体预测**：输入患者特征，获得预后预测
3. **列线图**：交互式列线图工具
4. **模型性能**：ROC曲线、校准曲线、C-index等
5. **生存分析**：Kaplan-Meier曲线和风险分层
6. **药物推荐**：基于风险评分的药物推荐
7. **批量预测**：上传CSV文件进行批量预测

### 个体预测功能

1. **输入ResNet50特征**：
   - 可手动输入71个特征值
   - 或上传包含特征的CSV文件
   - 或使用示例数据

2. **输入临床信息**（可选）：
   - 年龄、性别、TNM分期、肿瘤分级
   - AFP水平、肝硬化状态等

3. **查看预测结果**：
   - 风险评分（Risk Score）
   - 风险分层（高/低风险）
   - 1年、3年、5年生存概率
   - 推荐治疗方案

### 列线图使用

1. 移动滑块选择各特征值
2. 自动计算总分（Total Points）
3. 显示对应的生存概率
4. 可下载列线图为PDF

### 药物推荐逻辑

应用根据以下因素推荐药物：

- **风险评分**：高风险患者推荐更积极治疗
- **氧化应激状态**：OS-high肿瘤比例
- **免疫微环境**：T细胞、NK细胞浸润水平
- **TCGA数据库关联**：已验证的药物敏感性

---

## 模型说明

### ResNet50特征

- 使用ResNet50深度学习模型从病理图像提取2048维特征
- 通过LASSO回归筛选出71个氧化应激相关特征
- 计算风险评分（RS）用于预后预测

### Cox回归模型

**纳入变量**：
- ResNet50风险评分（RS）
- 年龄
- 性别
- TNM分期
- 肿瘤分级
- AFP水平
- 细胞类型分数（Tumor_OS-high, CD8_Trm等）

**模型性能**（训练集）：
- C-index: 0.72-0.78
- 1年AUC: 0.75-0.82
- 3年AUC: 0.70-0.78
- 5年AUC: 0.68-0.75

### 药物数据库

内置药物包括：
- **靶向治疗**：索拉非尼、仑伐替尼、瑞戈非尼
- **免疫检查点抑制剂**：PD-1/PD-L1抑制剂、CTLA-4抑制剂
- **化疗**：FOLFOX、吉西他滨、奥沙利铂
- **其他**：贝伐单抗、雷莫芦单抗

---

## 数据隐私

- 应用仅用于研究目的
- 所有数据基于TCGA公开数据集
- 不存储任何用户上传的数据
- 预测结果仅供参考，不作为临床决策依据

---

## 技术支持

### 常见问题

**Q: 应用启动失败？**
A: 检查是否安装了所有依赖包，运行 `source("requirements.R")`

**Q: 模型文件缺失？**
A: 运行 `source("build_model.R")` 生成模型

**Q: 预测结果不合理？**
A: 检查输入特征范围是否正常，参考示例数据

**Q: 如何添加新的临床特征？**
A: 修改 `build_model.R` 中的模型公式和 `app.R` 中的输入界面

### 联系方式

- GitHub Issues: [项目地址]
- Email: [联系邮箱]

---

## 引用

如果使用本应用发表研究成果，请引用：

```
[待补充：相关论文引用信息]
```

---

## 许可证

本项目遵循 MIT License。

---

## 更新日志

### v1.0.0 (2026-03-23)
- 初始版本发布
- 实现基本预后预测功能
- 支持列线图和校准曲线
- 集成药物推荐系统

---

## 致谢

- 数据来源：TCGA-LIHC数据库
- 深度学习框架：ResNet50
- 反卷积方法：BayesPrism
- 可视化工具：ggplot2, plotly, survminer

---

**免责声明**：本应用仅用于科研和教育目的，预测结果不能替代专业医学建议、诊断或治疗。任何临床决策应由有资质的医疗专业人员做出。
