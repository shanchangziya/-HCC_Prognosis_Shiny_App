# HCC预后预测Shiny应用 - 快速开始指南

## 5分钟快速启动

### 第一步：安装依赖包（首次使用）
```r
# 在R控制台运行
source("requirements.R")
```
等待所有包安装完成（约5-10分钟）。

### 第二步：准备数据（首次使用）
```r
# 确保以下文件在正确位置：
# - ../Resnet.Rdata
# - ../TCGA-LIHC_deconv_with_survival.csv
# - ../bulk/TCGA-LIHC.Rdata

source("prepare_data.R")
```
此脚本会生成 `data/` 文件夹中的所有CSV文件。

### 第三步：构建模型（首次使用）
```r
source("build_model.R")
```
此脚本会训练Cox模型并保存到 `models/` 文件夹。

### 第四步：启动应用
```r
source("start_app.R")
```
或直接运行：
```r
shiny::runApp("app.R")
```

应用会自动在浏览器中打开！

---

## 目录结构

```
HCC_Prognosis_Shiny_App/
├── README.md                 # 完整说明文档
├── QUICKSTART.md            # 本文件
├── requirements.R            # 依赖安装脚本
├── prepare_data.R            # 数据准备脚本
├── build_model.R             # 模型构建脚本
├── app.R                     # 主应用程序 ⭐
├── start_app.R               # 一键启动脚本
│
├── data/                     # 数据文件夹
│   ├── resnet_features.csv
│   ├── clinical_data.csv
│   ├── cell_fractions.csv
│   ├── drug_database.csv
│   └── example_patients.csv
│
├── models/                   # 模型文件夹
│   ├── cox_model_objects.rds
│   ├── nomogram.rds
│   ├── predict_function.rds
│   ├── model_performance.pdf
│   └── model_report.txt
│
├── scripts/                  # 辅助脚本
│   └── model_functions.R
│
└── www/                      # 静态资源
    └── style.css
```

---

## 常见问题

### Q1: 提示缺少某个R包？
```r
# 单独安装缺失的包
install.packages("包名称")

# 或重新运行完整安装
source("requirements.R")
```

### Q2: 提示找不到数据文件？
确保原始数据文件在正确位置：
- `Resnet.Rdata` 应该在 `HCC_Prognosis_Shiny_App/` 的上级目录
- 或者修改 `prepare_data.R` 中的文件路径

### Q3: 模型构建时报错？
检查数据完整性：
```r
# 查看数据文件
list.files("data/", pattern = "\\.csv$")

# 检查数据行数
nrow(read.csv("data/resnet_features.csv"))
nrow(read.csv("data/clinical_data.csv"))
```

### Q4: 应用启动后无法访问？
- 检查端口是否被占用
- 尝试更改端口：
```r
shiny::runApp("app.R", port = 8080)
```
- 检查防火墙设置

### Q5: 预测结果不合理？
- 检查输入特征范围（RS通常在-5到5之间）
- 使用「加载示例数据」按钮测试
- 查看 `models/model_report.txt` 了解模型参数

---

## 使用示例

### 示例1: 预测单个患者
1. 打开应用后，点击「个体预测」
2. 输入RS评分（例如：1.5）
3. 输入年龄、性别、分期等临床信息
4. 点击「开始预测」
5. 查看右侧预测结果

### 示例2: 使用列线图
1. 点击「列线图」标签页
2. 在图中找到各个预测因子的值
3. 向上读取对应的分数
4. 将所有分数相加
5. 在底部读取生存概率

### 示例3: 批量预测
1. 准备CSV文件（可下载示例模板）
2. 点击「批量预测」标签页
3. 上传CSV文件
4. 点击「批量预测」
5. 下载结果文件

### 示例4: 获取药物推荐
1. 点击「药物推荐」标签页
2. 输入风险评分和肿瘤特征
3. 点击「获取推荐」
4. 查看推荐药物列表

---

## 数据格式说明

### ResNet50特征（RS）
- 从病理图像提取的深度学习特征
- 范围：通常在 -5 到 5 之间
- 值越大，风险越高

### 临床特征
- **年龄**：18-100岁
- **性别**：Male/Female
- **TNM分期**：I-IV（或数值1-4）
- **肿瘤分级**：G1-G4（或数值1-4）

### 细胞类型分数
- 范围：0-1（百分比）
- 表示该细胞类型在肿瘤中的比例
- 关键类型：Tumor_OS-high, CD8_Trm, NK等

---

## 性能要求

### 最低配置
- R版本：≥ 4.0.0
- 内存：≥ 4 GB
- 硬盘：≥ 1 GB可用空间

### 推荐配置
- R版本：≥ 4.2.0
- 内存：≥ 8 GB
- 硬盘：≥ 2 GB可用空间
- CPU：多核处理器

---

## 进阶使用

### 自定义模型
编辑 `build_model.R` 修改：
- 特征选择（第89-103行）
- 模型公式（第116行）
- 风险分层阈值（第143行）

### 添加新药物
编辑 `data/drug_database.csv`：
```csv
drug_name,drug_class,indication,...
新药名称,药物类别,适应症,...
```

### 修改界面
编辑 `app.R` UI部分（第75-300行）
或修改 `www/style.css` 自定义样式

### 导出报告
在应用中使用下载按钮：
- 列线图PDF
- 批量预测结果CSV
- 模型性能报告

---

## 获取帮助

1. **应用内帮助**：点击「使用说明」标签页
2. **完整文档**：查阅 `README.md`
3. **模型报告**：查看 `models/model_report.txt`
4. **代码注释**：所有R脚本都有详细注释

---

## 引用和许可

如使用本应用发表成果，请引用相关论文。

本项目遵循 MIT License，可自由使用和修改。

---

**祝您使用愉快！如有问题请查阅README或联系开发团队。**

*最后更新：2026-03-23*
