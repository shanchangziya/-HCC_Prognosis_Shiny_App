#!/bin/bash
# HCC预后预测Shiny应用 - 自动设置脚本
# 此脚本会自动完成所有准备工作

echo "================================================="
echo "HCC预后预测 Shiny应用 - 自动设置"
echo "================================================="
echo ""

# 检查R是否安装
if ! command -v Rscript &> /dev/null; then
    echo "✗ 错误: 未找到R语言环境"
    echo "请先安装R (https://www.r-project.org/)"
    exit 1
fi

echo "✓ R语言环境已安装"
R_VERSION=$(Rscript --version 2>&1 | head -n1)
echo "  $R_VERSION"
echo ""

# 进入脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "工作目录: $SCRIPT_DIR"
echo ""

# 步骤1: 安装R包
echo "================================================="
echo "[1/3] 安装R包依赖"
echo "================================================="
echo "这可能需要5-10分钟，请耐心等待..."
echo ""

Rscript requirements.R
if [ $? -ne 0 ]; then
    echo ""
    echo "✗ R包安装失败"
    echo "请检查错误信息并手动运行: Rscript requirements.R"
    exit 1
fi

echo ""
echo "✓ R包安装完成"
echo ""

# 步骤2: 准备数据
echo "================================================="
echo "[2/3] 准备数据文件"
echo "================================================="
echo ""

# 检查原始数据文件
RESNET_FILE="../Resnet.Rdata"
DECONV_FILE="../TCGA-LIHC_deconv_with_survival.csv"
BULK_FILE="../bulk/TCGA-LIHC.Rdata"

if [ ! -f "$RESNET_FILE" ]; then
    echo "⚠ 警告: 未找到 $RESNET_FILE"
    echo "请确保将 Resnet.Rdata 复制到正确位置"
    echo "或修改 prepare_data.R 中的文件路径"
    echo ""
    echo "继续设置（使用模拟数据）？ [y/N]"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "设置已取消"
        exit 1
    fi
fi

Rscript prepare_data.R
if [ $? -ne 0 ]; then
    echo ""
    echo "✗ 数据准备失败"
    echo "请检查错误信息并手动运行: Rscript prepare_data.R"
    exit 1
fi

echo ""
echo "✓ 数据准备完成"
echo ""

# 步骤3: 构建模型
echo "================================================="
echo "[3/3] 构建预测模型"
echo "================================================="
echo "这可能需要2-5分钟..."
echo ""

Rscript build_model.R
if [ $? -ne 0 ]; then
    echo ""
    echo "✗ 模型构建失败"
    echo "请检查错误信息并手动运行: Rscript build_model.R"
    exit 1
fi

echo ""
echo "✓ 模型构建完成"
echo ""

# 完成
echo "================================================="
echo "✓ 设置完成！"
echo "================================================="
echo ""
echo "所有准备工作已完成，您可以："
echo ""
echo "  1. 在R中运行:"
echo "     source('start_app.R')"
echo ""
echo "  2. 或使用RStudio打开 app.R 并点击 'Run App'"
echo ""
echo "  3. 或在终端运行:"
echo "     Rscript start_app.R"
echo ""
echo "应用将在浏览器中自动打开。"
echo ""

# 询问是否立即启动
echo "是否现在启动应用？ [Y/n]"
read -r response
if [[ "$response" =~ ^[Nn]$ ]]; then
    echo "您可以稍后手动启动应用。"
    exit 0
fi

echo ""
echo "正在启动应用..."
echo ""

Rscript start_app.R
