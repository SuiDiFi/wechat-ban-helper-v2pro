@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 微信举报模拟器 - Windows 一键部署脚本
:: 使用方式: 双击运行或在命令行执行 deploy.bat

echo.
echo =========================================
echo    微信举报模拟器 - Windows 部署脚本
echo =========================================
echo.

:: 检查 Node.js
echo [INFO] 检查 Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js 未安装，请先安装 Node.js 18+
    pause
    exit /b 1
)
for /f "tokens=2" %%a in ('node --version') do set NODE_VERSION=%%a
echo [SUCCESS] Node.js 版本: %NODE_VERSION%

:: 检查 npm
echo [INFO] 检查 npm...
npm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] npm 未安装
    pause
    exit /b 1
)
for /f %%a in ('npm --version') do set NPM_VERSION=%%a
echo [SUCCESS] npm 版本: %NPM_VERSION%

:: 安装依赖
echo.
echo [INFO] 安装项目依赖...
npm install --production
if %errorlevel% neq 0 (
    echo [ERROR] 依赖安装失败
    pause
    exit /b 1
)
echo [SUCCESS] 依赖安装完成

:: 创建测试数据库（使用 SQLite 作为备用方案）
echo.
echo [INFO] 检查数据库配置...
if not exist ".env" (
    echo [WARNING] .env 文件不存在，使用默认配置
    echo PORT=3000 > .env
    echo JWT_SECRET=default-secret-key-for-testing-only-must-change-in-production >> .env
    echo ADMIN_PASSWORD=admin123456 >> .env
    echo DEMO_CODE=DEMO-2026-TEST >> .env
    echo DEMO_MAX_USES=50 >> .env
    echo. >> .env
    echo DB_HOST=localhost >> .env
    echo DB_PORT=3306 >> .env
    echo DB_USER=root >> .env
    echo DB_PASSWORD=123456 >> .env
    echo DB_NAME=wechat_report >> .env
)
echo [SUCCESS] 环境配置检查完成

:: 检查端口占用
echo.
echo [INFO] 检查端口占用...
netstat -ano | findstr ":3000" >nul 2>&1
if %errorlevel% equ 0 (
    echo [WARNING] 端口 3000 已被占用，尝试使用端口 3001
    set PORT=3001
) else (
    set PORT=3000
)

:: 更新端口配置
set "envFile=.env"
set "tempFile=%temp%\env_temp.txt"
if exist "%tempFile%" del "%tempFile%"
for /f "usebackq delims=" %%a in ("%envFile%") do (
    set "line=%%a"
    if "!line:~0,5!"=="PORT=" (
        echo PORT=%PORT% >> "%tempFile%"
    ) else (
        echo !line! >> "%tempFile%"
    )
)
copy /y "%tempFile%" "%envFile%" >nul
del "%tempFile%"

:: 启动服务
echo.
echo [INFO] 启动服务...
echo [INFO] 服务端口: %PORT%
echo [INFO] 按 Ctrl+C 停止服务

node server.js

echo.
echo [INFO] 服务已停止
pause