#!/bin/bash
# 微信举报模拟器 - 一键部署脚本
# 使用方式: bash deploy.sh [选项]
# 选项:
#   --install          完整安装（默认）
#   --nginx            仅配置 Nginx
#   --ssl              获取 SSL 证书
#   --test             运行测试

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
PROJECT_NAME="wechat-report-system"
PROJECT_DIR="/www/wwwroot/$PROJECT_NAME"
NODE_VERSION="18"
PORT="3000"
DB_NAME="wechat_report"
DB_USER="wechat_user"

# 打印信息
info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] INFO: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] SUCCESS: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "命令 $1 未找到，请先安装"
    fi
}

# 检查 root 权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        error "请使用 root 用户运行此脚本"
    fi
}

# 检查操作系统
check_os() {
    if [ -f /etc/centos-release ]; then
        OS="centos"
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
        OS="debian"
    else
        error "不支持的操作系统，请使用 CentOS 7+ 或 Ubuntu 18.04+"
    fi
    info "检测到操作系统: $OS"
}

# 安装基础依赖
install_dependencies() {
    info "安装系统依赖..."
    
    if [ "$OS" = "centos" ]; then
        yum update -y
        yum install -y gcc-c++ make python3 openssl-devel nginx wget curl
    else
        apt update && apt upgrade -y
        apt install -y build-essential python3 libssl-dev nginx wget curl
    fi
    
    success "系统依赖安装完成"
}

# 安装 Node.js
install_node() {
    info "安装 Node.js $NODE_VERSION..."
    
    if command -v node &> /dev/null; then
        CURRENT_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$CURRENT_VERSION" -ge "$NODE_VERSION" ]; then
            success "Node.js 版本满足要求: $(node --version)"
            return
        fi
    fi
    
    # 使用 nvm 安装
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    
    success "Node.js 安装完成: $(node --version)"
}

# 安装 PM2
install_pm2() {
    info "安装 PM2..."
    npm install -g pm2
    success "PM2 安装完成"
}

# 安装 Certbot
install_certbot() {
    info "安装 Certbot..."
    
    if [ "$OS" = "centos" ]; then
        yum install -y certbot python3-certbot-nginx
    else
        apt install -y certbot python3-certbot-nginx
    fi
    
    success "Certbot 安装完成"
}

# 创建项目目录
create_project_dir() {
    info "创建项目目录..."
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    success "项目目录创建完成: $PROJECT_DIR"
}

# 安装项目依赖
install_project_deps() {
    info "安装项目依赖..."
    npm install --production
    success "项目依赖安装完成"
}

# 配置数据库
configure_database() {
    info "配置数据库..."
    
    # 检查 MySQL 是否安装
    if ! command -v mysql &> /dev/null; then
        info "安装 MySQL..."
        if [ "$OS" = "centos" ]; then
            yum install -y mariadb-server mariadb
            systemctl start mariadb
            systemctl enable mariadb
        else
            apt install -y mariadb-server
            systemctl start mariadb
            systemctl enable mariadb
        fi
        success "MySQL 安装完成"
    fi
    
    # 创建数据库和用户
    info "创建数据库..."
    
    # 生成随机密码
    DB_PASS=$(openssl rand -hex 16)
    
    mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    success "数据库配置完成"
    
    # 保存数据库密码到临时文件
    echo "$DB_PASS" > /tmp/db_password.txt
}

# 配置环境变量
configure_env() {
    info "配置环境变量..."
    
    # 生成安全的 JWT_SECRET
    JWT_SECRET=$(openssl rand -hex 32)
    ADMIN_PASS=$(openssl rand -hex 12)
    DB_PASS=$(cat /tmp/db_password.txt)
    
    cat > .env << EOF
PORT=$PORT
JWT_SECRET=$JWT_SECRET
ADMIN_PASSWORD=$ADMIN_PASS
DEMO_CODE=DEMO-2026-TEST
DEMO_MAX_USES=50

DB_HOST=localhost
DB_PORT=3306
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
DB_NAME=$DB_NAME
EOF
    
    # 设置文件权限
    chmod 600 .env
    
    # 保存管理员密码
    echo "管理员密码: $ADMIN_PASS" > /tmp/admin_password.txt
    
    success "环境变量配置完成"
    warning "管理员密码已保存到: /tmp/admin_password.txt"
    warning "数据库密码已保存到: /tmp/db_password.txt"
}

# 启动服务
start_service() {
    info "启动服务..."
    
    # 停止已运行的服务
    pm2 delete "$PROJECT_NAME" 2>/dev/null || true
    
    # 启动服务
    pm2 start server.js --name "$PROJECT_NAME"
    
    # 设置开机自启
    pm2 save
    pm2 startup
    
    success "服务启动完成"
    info "服务状态:"
    pm2 status
}

# 配置 Nginx
configure_nginx() {
    info "配置 Nginx..."
    
    # 获取域名
    read -p "请输入您的域名（如: example.com）: " DOMAIN
    
    # 创建 Nginx 配置
    cat > /etc/nginx/conf.d/"$PROJECT_NAME.conf" << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Frame-Options DENY;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/javascript application/json;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    access_log /var/log/nginx/$PROJECT_NAME.access.log combined;
    error_log /var/log/nginx/$PROJECT_NAME.error.log warn;
}
EOF
    
    # 测试配置并重启
    nginx -t || error "Nginx 配置错误"
    systemctl reload nginx
    
    success "Nginx 配置完成"
    
    # 保存域名配置
    echo "$DOMAIN" > /tmp/domain.txt
}

# 获取 SSL 证书
get_ssl_certificate() {
    info "获取 SSL 证书..."
    
    DOMAIN=$(cat /tmp/domain.txt 2>/dev/null)
    if [ -z "$DOMAIN" ]; then
        read -p "请输入您的域名（如: example.com）: " DOMAIN
    fi
    
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --agree-tos --email admin@"$DOMAIN"
    
    success "SSL 证书获取完成"
}

# 运行测试
run_tests() {
    info "运行自动化测试..."
    
    # 等待服务启动
    sleep 5
    
    # 运行测试
    node test-full.js
    
    if [ $? -eq 0 ]; then
        success "所有测试通过！"
    else
        error "测试失败"
    fi
}

# 防火墙配置
configure_firewall() {
    info "配置防火墙..."
    
    if [ "$OS" = "centos" ]; then
        firewall-cmd --add-service=http --permanent
        firewall-cmd --add-service=https --permanent
        firewall-cmd --reload
    else
        ufw allow 'Nginx Full'
        ufw enable
    fi
    
    success "防火墙配置完成"
}

# 显示部署信息
show_deployment_info() {
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}      部署完成！${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${BLUE}项目地址:${NC} $PROJECT_DIR"
    echo -e "${BLUE}前台页面:${NC} https://$(cat /tmp/domain.txt 2>/dev/null || echo 'your-domain.com')"
    echo -e "${BLUE}管理后台:${NC} https://$(cat /tmp/domain.txt 2>/dev/null || echo 'your-domain.com')/admin"
    echo -e "${BLUE}管理员密码:${NC} $(cat /tmp/admin_password.txt 2>/dev/null | cut -d':' -f2 | tr -d ' ' || echo '查看 /tmp/admin_password.txt')"
    echo -e "${BLUE}演示激活码:${NC} DEMO-2026-TEST"
    echo ""
    echo -e "${YELLOW}注意:${NC}"
    echo "  - 管理员密码已保存到: /tmp/admin_password.txt"
    echo "  - 数据库密码已保存到: /tmp/db_password.txt"
    echo "  - 请及时修改默认密码"
    echo ""
    echo -e "${GREEN}=========================================${NC}"
}

# 主函数
main() {
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  微信举报模拟器一键部署脚本${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    
    # 检查参数
    ACTION="${1:---install}"
    
    case "$ACTION" in
        --install)
            # 完整安装
            check_root
            check_os
            install_dependencies
            install_node
            install_pm2
            install_certbot
            create_project_dir
            install_project_deps
            configure_database
            configure_env
            configure_firewall
            start_service
            configure_nginx
            get_ssl_certificate
            run_tests
            show_deployment_info
            ;;
        
        --nginx)
            # 仅配置 Nginx
            check_root
            configure_nginx
            get_ssl_certificate
            show_deployment_info
            ;;
        
        --ssl)
            # 获取 SSL 证书
            check_root
            install_certbot
            get_ssl_certificate
            success "SSL 证书配置完成"
            ;;
        
        --test)
            # 运行测试
            run_tests
            ;;
        
        *)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --install          完整安装（默认）"
            echo "  --nginx            仅配置 Nginx"
            echo "  --ssl              获取 SSL 证书"
            echo "  --test             运行测试"
            exit 1
            ;;
    esac
}

main "$@"