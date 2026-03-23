# HCC预后预测Shiny应用 - 交付说明

## 📦 交付内容

本压缩包包含一个完整的、可立即使用的Shiny Web应用程序，用于肝细胞癌（HCC）患者预后预测。

### 应用功能
✅ 基于ResNet50氧化应激特征的预后预测
✅ 交互式列线图（Nomogram）可视化
✅ 多时间点生存概率估计（1/3/5年）
✅ 智能药物推荐系统
✅ 批量患者预测功能
✅ 完整的模型性能评估

---

## 📂 文件结构

```
HCC_Prognosis_Shiny_App/
│
├── 📖 文档文件
│   ├── README.md              # 完整使用说明（30页+）
│   ├── QUICKSTART.md          # 5分钟快速开始指南
│   ├── CHECKLIST.md           # 文件清单和检查列表
│   └── DELIVERY.md            # 本文件
│
├── 🚀 启动脚本
│   ├── requirements.R         # 自动安装所有R包依赖
│   ├── prepare_data.R         # 从TCGA数据生成应用数据
│   ├── build_model.R          # 构建Cox预后模型
│   ├── start_app.R           # 一键启动应用（推荐）
│   ├── setup.sh              # Linux/Mac自动化设置脚本
│   └── test_components.R     # 组件测试脚本
│
├── ⭐ 核心应用
│   └── app.R                 # Shiny应用主程序（约600行）
│
├── 📁 数据文件夹（运行后生成）
│   └── data/
│       ├── resnet_features.csv
│       ├── clinical_data.csv
│       ├── cell_fractions.csv
│       ├── drug_database.csv
│       └── example_patients.csv
│
├── 🧠 模型文件夹（运行后生成）
│   └── models/
│       ├── cox_model_objects.rds
│       ├── nomogram.rds
│       ├── predict_function.rds
│       ├── model_performance.pdf
│       └── model_report.txt
│
├── 🔧 辅助脚本
│   └── scripts/
│       └── model_functions.R  # 扩展功能函数库
│
└── 🎨 静态资源
    └── www/
        └── style.css          # 自定义UI样式
```

---

## 🎯 使用场景

### 场景1：临床研究人员
- 输入患者ResNet50特征和临床数据
- 获得生存风险评分和分层
- 查看1/3/5年生存概率
- 获取个性化治疗建议

### 场景2：生物信息学家
- 上传批量患者数据CSV文件
- 批量预测所有患者预后
- 下载完整预测结果
- 用于后续统计分析

### 场景3：AI/ML研究者
- 修改模型特征和参数
- 测试不同的预后模型
- 评估模型性能指标
- 生成可视化报告

---

## 🚀 快速开始（3种方法）

### 方法1：使用setup.sh（最简单，Linux/Mac）

```bash
# 1. 解压应用包
unzip HCC_Prognosis_Shiny_App.zip
cd HCC_Prognosis_Shiny_App/

# 2. 准备TCGA数据文件（复制到正确位置）
# - Resnet.Rdata → 当前目录的上级目录
# - TCGA-LIHC_deconv_with_survival.csv → 上级目录
# - TCGA-LIHC.Rdata → ../bulk/

# 3. 运行自动化设置
bash setup.sh

# 完成！应用会自动启动
```

### 方法2：使用R脚本（所有平台）

```r
# 1. 在R或RStudio中设置工作目录
setwd("/path/to/HCC_Prognosis_Shiny_App")

# 2. 安装依赖（首次使用）
source("requirements.R")  # 5-10分钟

# 3. 准备数据（首次使用）
source("prepare_data.R")  # 1-2分钟

# 4. 构建模型（首次使用）
source("build_model.R")   # 2-5分钟

# 5. 启动应用
source("start_app.R")     # 应用将在浏览器打开
```

### 方法3：在RStudio中直接运行

```r
# 1. 用RStudio打开 app.R 文件
# 2. 确保已完成上述步骤2-4（安装、数据、模型）
# 3. 点击右上角 "Run App" 按钮
```

---

## 📋 系统要求

### 必需
- ✅ R语言 >= 4.0.0（推荐 >= 4.2.0）
- ✅ 4 GB RAM（推荐 8 GB）
- ✅ 1 GB 可用硬盘空间
- ✅ 现代浏览器（Chrome/Firefox/Edge/Safari）

### 推荐
- ✅ RStudio Desktop（提供更好的开发体验）
- ✅ 多核CPU（加快模型训练）
- ✅ 网络连接（首次安装R包时需要）

### 操作系统
- ✅ Windows 10/11
- ✅ macOS 10.14+
- ✅ Linux（Ubuntu 18.04+, CentOS 7+等）

---

## 📊 数据要求

### 必需的原始数据文件

在运行 `prepare_data.R` 之前，需要准备：

1. **Resnet.Rdata** - 包含ResNet50特征
   - 对象: `resnet_RS_sig`（71个特征）、`resnet2`（2048个特征）、`rp`（风险评分）
   - 位置: `HCC_Prognosis_Shiny_App/../Resnet.Rdata`

2. **TCGA-LIHC_deconv_with_survival.csv** - 反卷积结果
   - 包含: 细胞类型分数、生存数据（OS, OS.time）
   - 位置: `HCC_Prognosis_Shiny_App/../TCGA-LIHC_deconv_with_survival.csv`

3. **TCGA-LIHC.Rdata** - TCGA bulk数据
   - 对象: `exp`（表达矩阵）、`surv`（生存数据）
   - 位置: `HCC_Prognosis_Shiny_App/../bulk/TCGA-LIHC.Rdata`

### 数据格式说明

如果使用自己的数据，CSV文件格式应为：

```csv
sample,RS,age,gender,stage_numeric,grade_numeric,...
TCGA-XX-XXXX,1.234,65,Male,3,2,...
```

关键列：
- `sample`: 样本ID（必需）
- `RS`: ResNet50风险评分（必需，通常在-5到5之间）
- `os`: 生存状态（0=删失，1=死亡）
- `os.time`: 生存时间（天数）
- 其他列可选

---

## 🧪 测试应用

### 运行测试脚本

```r
source("test_components.R")
```

这将检查：
- ✅ R包是否正确安装
- ✅ 数据文件是否存在
- ✅ 模型文件是否加载
- ✅ 应用文件语法是否正确

### 使用示例数据

应用内置了示例数据：
1. 打开应用后进入「个体预测」页面
2. 点击「加载示例数据」按钮
3. 点击「开始预测」查看结果

---

## 🔧 自定义和扩展

### 修改模型特征

编辑 `build_model.R` 第89-103行：

```r
key_features <- c(
  "RS",                    # 必需
  "age", "gender",         # 添加或删除临床特征
  "Tumor_OS-high",         # 添加或删除细胞类型
  # 添加您自己的特征...
)
```

### 添加新药物

编辑 `data/drug_database.csv`，添加新行：

```csv
新药名称,药物类别,适应症,风险组,推荐度,...
```

### 自定义UI样式

编辑 `www/style.css` 修改界面颜色、字体等。

### 添加新功能

参考 `scripts/model_functions.R` 中的函数示例，编写新功能并集成到 `app.R`。

---

## 📱 部署到服务器

### 部署到Shinyapps.io（免费）

```r
# 1. 安装rsconnect包
install.packages("rsconnect")

# 2. 设置账户（在shinyapps.io注册后获取token）
rsconnect::setAccountInfo(
  name = "your-account",
  token = "your-token",
  secret = "your-secret"
)

# 3. 部署应用
rsconnect::deployApp(appDir = ".", appName = "hcc-prognosis")
```

### 部署到自己的服务器

使用Shiny Server（开源）或RStudio Connect（商业）：

```bash
# Ubuntu安装Shiny Server
sudo apt-get install gdebi-core
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.20.1002-amd64.deb
sudo gdebi shiny-server-1.5.20.1002-amd64.deb

# 复制应用到Shiny Server目录
sudo cp -r HCC_Prognosis_Shiny_App /srv/shiny-server/

# 访问 http://your-server:3838/HCC_Prognosis_Shiny_App/
```

---

## 🐛 故障排除

### 问题1: R包安装失败

**症状**: `requirements.R` 报错无法安装某些包

**解决**:
```r
# 尝试手动安装失败的包
install.packages("包名", dependencies = TRUE)

# 或使用二进制包（Windows/Mac）
install.packages("包名", type = "binary")

# 对于Bioconductor包
if (!requireNamespace("BiocManager"))
  install.packages("BiocManager")
BiocManager::install("包名")
```

### 问题2: 提示缺少数据文件

**症状**: 运行 `build_model.R` 时提示找不到数据文件

**解决**:
```r
# 检查数据文件是否存在
list.files("data/", pattern = "\\.csv$")

# 如果缺失，重新运行
source("prepare_data.R")
```

### 问题3: 模型预测结果异常

**症状**: 生存概率为0或超过1

**解决**:
- 检查输入特征范围（RS应在-5到5）
- 使用示例数据测试
- 查看 `models/model_report.txt` 了解模型参数范围

### 问题4: 应用界面显示不正常

**症状**: 按钮错位、颜色异常等

**解决**:
- 清除浏览器缓存（Ctrl+Shift+Delete）
- 尝试其他浏览器（推荐Chrome）
- 检查 `www/style.css` 是否存在

### 问题5: 端口被占用

**症状**: 启动时提示端口3838已被使用

**解决**:
```r
# 使用其他端口
shiny::runApp("app.R", port = 8080)

# 或在start_app.R中修改默认端口
```

---

## 📞 获取帮助

### 优先级顺序

1. **查阅文档**
   - `README.md` - 完整使用说明
   - `QUICKSTART.md` - 快速开始指南
   - 应用内「使用说明」标签页

2. **运行测试**
   - `source("test_components.R")`
   - 检查所有组件是否正常

3. **查看日志**
   - R控制台的错误信息
   - `models/model_report.txt`

4. **联系支持**
   - GitHub Issues（如已开源）
   - Email联系开发团队

---

## 📄 许可证和引用

### 许可证
本应用遵循 **MIT License**，允许：
- ✅ 商业使用
- ✅ 修改和再分发
- ✅ 私人使用
- ✅ 专利授权

但需保留原始版权声明。

### 引用

如果本应用对您的研究有帮助，请引用：

```bibtex
@software{hcc_prognosis_shiny,
  title = {HCC Prognosis Prediction Shiny Application},
  author = {Your Name},
  year = {2026},
  url = {https://github.com/yourrepo/hcc-prognosis}
}
```

基于的数据来源：
- TCGA-LIHC数据库
- ResNet50深度学习模型
- BayesPrism反卷积方法

---

## 🎓 学习资源

### 了解更多

- **Shiny**: https://shiny.rstudio.com/
- **Cox回归**: https://cran.r-project.org/web/packages/survival/
- **列线图**: `rms` 包文档
- **TCGA**: https://portal.gdc.cancer.gov/

### 相关论文

- Cox, D. R. (1972). Regression models and life-tables. *Journal of the Royal Statistical Society*
- He, K., et al. (2016). Deep Residual Learning for Image Recognition. *CVPR*
- [您的相关论文...]

---

## ✅ 最后检查清单

使用前请确认：

- [ ] R语言已安装（版本 >= 4.0.0）
- [ ] 已准备好TCGA原始数据文件
- [ ] 已运行 `source("requirements.R")`
- [ ] 已运行 `source("prepare_data.R")`
- [ ] 已运行 `source("build_model.R")`
- [ ] 已测试应用可以正常启动
- [ ] 已尝试使用示例数据预测
- [ ] 已阅读使用说明文档

全部完成后，您可以开始使用应用了！

---

## 📧 联系信息

- **开发者**: [您的名字]
- **Email**: [您的邮箱]
- **GitHub**: [项目地址]
- **版本**: 1.0.0
- **发布日期**: 2026-03-23

---

## 🙏 致谢

感谢以下项目和资源：
- TCGA Research Network
- RStudio团队（Shiny框架）
- R社区的各个包作者
- 所有测试用户的反馈

---

**祝您使用愉快！预测准确！研究顺利！** 🎉

---

*文档最后更新：2026-03-23*
