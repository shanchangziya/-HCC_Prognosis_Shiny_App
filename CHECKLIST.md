# HCC预后预测Shiny应用 - 文件清单

## 生成时间
2026-03-23

## 目录结构

```
HCC_Prognosis_Shiny_App/
│
├── README.md                          # 完整使用说明（必读）
├── QUICKSTART.md                      # 5分钟快速开始指南
├── CHECKLIST.md                       # 本文件 - 文件清单
│
├── requirements.R                     # R包依赖安装脚本
├── prepare_data.R                     # 数据准备脚本
├── build_model.R                      # 模型构建脚本
├── app.R                             # 主应用程序 ⭐
├── start_app.R                        # 一键启动脚本
├── setup.sh                          # Bash自动设置脚本（Linux/Mac）
│
├── data/                             # 数据文件夹（运行prepare_data.R后生成）
│   ├── resnet_features.csv           # ResNet50特征
│   ├── clinical_data.csv             # 临床数据
│   ├── cell_fractions.csv            # 细胞类型分数
│   ├── drug_database.csv             # 药物数据库
│   └── example_patients.csv          # 示例数据
│
├── models/                           # 模型文件夹（运行build_model.R后生成）
│   ├── cox_model_objects.rds         # Cox模型主对象
│   ├── nomogram.rds                  # 列线图对象
│   ├── predict_function.rds          # 预测函数
│   ├── model_performance.pdf         # 模型性能图表
│   └── model_report.txt              # 模型性能文本报告
│
├── scripts/                          # 辅助脚本文件夹
│   └── model_functions.R             # 模型相关辅助函数
│
└── www/                              # 静态资源文件夹
    └── style.css                     # 自定义CSS样式
```

## 文件说明

### 核心文件（必需）

- [x] **app.R** - Shiny应用主程序，包含UI和Server逻辑
- [x] **README.md** - 完整的使用说明和文档
- [x] **requirements.R** - 自动安装所有必需的R包

### 数据准备（首次使用必需）

- [x] **prepare_data.R** - 从原始TCGA数据生成应用所需的CSV文件
- [x] **build_model.R** - 训练Cox回归模型并生成列线图

### 启动脚本（可选但推荐）

- [x] **start_app.R** - 一键启动脚本，自动检查环境
- [x] **setup.sh** - Bash自动化设置脚本（Linux/Mac用户）

### 辅助文件

- [x] **QUICKSTART.md** - 5分钟快速开始指南
- [x] **CHECKLIST.md** - 本清单文件
- [x] **scripts/model_functions.R** - 扩展功能函数库
- [x] **www/style.css** - UI美化样式

### 数据文件（运行后生成）

运行 `prepare_data.R` 后会在 `data/` 目录生成：
- [ ] resnet_features.csv
- [ ] clinical_data.csv
- [ ] cell_fractions.csv
- [ ] drug_database.csv
- [ ] example_patients.csv

### 模型文件（运行后生成）

运行 `build_model.R` 后会在 `models/` 目录生成：
- [ ] cox_model_objects.rds
- [ ] nomogram.rds
- [ ] predict_function.rds
- [ ] model_performance.pdf
- [ ] model_report.txt

## 必需的原始数据文件

在运行 `prepare_data.R` 之前，需要将以下文件放在正确位置：

- [ ] `../Resnet.Rdata` - ResNet50特征数据
- [ ] `../TCGA-LIHC_deconv_with_survival.csv` - 反卷积结果
- [ ] `../bulk/TCGA-LIHC.Rdata` - TCGA-LIHC bulk数据

如果这些文件在其他位置，需要修改 `prepare_data.R` 中的路径。

## 使用流程检查清单

### 首次设置

- [ ] 1. 安装R语言（版本 ≥ 4.0.0）
- [ ] 2. 安装RStudio（推荐但非必需）
- [ ] 3. 解压本应用程序包到任意目录
- [ ] 4. 准备原始TCGA数据文件
- [ ] 5. 运行 `source("requirements.R")` 安装依赖
- [ ] 6. 运行 `source("prepare_data.R")` 准备数据
- [ ] 7. 运行 `source("build_model.R")` 构建模型
- [ ] 8. 运行 `source("start_app.R")` 启动应用

### Linux/Mac用户快捷方式

- [ ] 1. 准备原始数据文件
- [ ] 2. 在终端运行 `bash setup.sh`
- [ ] 3. 等待自动完成所有设置
- [ ] 4. 应用将自动启动

### 日常使用

- [ ] 直接运行 `source("start_app.R")` 或
- [ ] 在RStudio中打开 `app.R` 并点击 "Run App" 或
- [ ] 运行 `shiny::runApp("app.R")`

## 功能检查清单

启动应用后，检查以下功能是否正常：

- [ ] 首页显示正常，包含模型性能指标
- [ ] 个体预测功能可以输入数据并获得结果
- [ ] 加载示例数据按钮工作正常
- [ ] 列线图正确显示
- [ ] 列线图可以下载为PDF
- [ ] 模型性能页面的图表显示正常
- [ ] 生存分析的KM曲线显示正常
- [ ] 药物推荐功能返回合理结果
- [ ] 批量预测可以上传CSV文件
- [ ] 批量预测结果可以下载
- [ ] 所有标签页都可以正常切换

## 常见问题检查

如果遇到问题，按以下顺序检查：

1. **应用无法启动**
   - [ ] 检查R版本是否 ≥ 4.0.0
   - [ ] 检查所有R包是否安装（运行 `requirements.R`）
   - [ ] 检查工作目录是否正确

2. **提示缺少数据文件**
   - [ ] 检查 `data/` 目录是否存在且包含所有CSV文件
   - [ ] 如果缺失，运行 `source("prepare_data.R")`

3. **提示缺少模型文件**
   - [ ] 检查 `models/` 目录是否存在且包含RDS文件
   - [ ] 如果缺失，运行 `source("build_model.R")`

4. **预测结果异常**
   - [ ] 检查输入特征的值范围是否合理
   - [ ] 使用"加载示例数据"测试
   - [ ] 查看 `models/model_report.txt` 了解模型参数

5. **界面显示异常**
   - [ ] 清除浏览器缓存
   - [ ] 尝试使用其他浏览器（推荐Chrome或Firefox）
   - [ ] 检查 `www/style.css` 文件是否存在

## 系统要求检查

- [ ] 操作系统：Windows 10+, macOS 10.14+, 或 Linux
- [ ] R版本：≥ 4.0.0（建议 ≥ 4.2.0）
- [ ] 内存：≥ 4 GB（建议 ≥ 8 GB）
- [ ] 硬盘空间：≥ 1 GB可用空间
- [ ] 网络：首次安装R包时需要网络连接

## 测试数据检查

如果没有真实TCGA数据，可以使用模拟数据测试：

- [ ] 修改 `prepare_data.R` 以生成模拟数据（已包含代码）
- [ ] 使用应用内的示例数据进行测试
- [ ] 查看 `data/example_patients.csv` 了解数据格式

## 版本信息

- **应用版本**: 1.0.0
- **创建日期**: 2026-03-23
- **R版本要求**: ≥ 4.0.0
- **Shiny版本要求**: ≥ 1.7.0

## 更新日志

### v1.0.0 (2026-03-23)
- 初始版本发布
- 实现核心预后预测功能
- 支持列线图可视化
- 集成药物推荐系统
- 提供批量预测功能

## 下一步计划

- [ ] 添加更多临床特征支持
- [ ] 集成更多药物数据库
- [ ] 支持自定义风险分层阈值
- [ ] 添加生存曲线比较功能
- [ ] 开发移动端适配界面
- [ ] 支持多语言（中英文切换）

## 联系与反馈

如有问题或建议：
- 查阅 `README.md` 完整文档
- 查看应用内的"使用说明"标签页
- 联系开发团队

## 许可证

本应用遵循 MIT License，可自由使用和修改。

---

**检查完成日期**: ___________

**检查人**: ___________

**备注**: ___________
