# 微信封号助手 v2.0 Pro

微信举报模拟与仿真演示系统，支持批量头像库、举报任务管理、封号记录查询等功能。

## 功能特性

- **举报模拟系统**：仿真微信举报流程，可视化展示封号机制
- **任务管理后台**：创建/跟踪举报任务，查看执行状态与统计
- **头像库**：内置 100+ 真实风格头像素材（`public/img/`）
- **封号记录查询**：支持多条件搜索封号历史
- **激活码管理**：后台生成/核销激活码，控制使用权限
- **JWT 认证**：安全的用户认证与权限校验

## 技术栈

| 层级 | 技术 |
|------|------|
| 后端框架 | Node.js + Express |
| 数据库 | MySQL（mysql2） |
| 认证 | JWT + bcryptjs |
| 部署 | PM2 / Docker / GitHub Actions |

## 快速开始

```bash
# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
# 编辑 .env 填写数据库连接、JWT密钥等

# 初始化数据库
npm run init-db

# 启动服务
npm start
```

访问 `http://localhost:3000`，管理后台：`http://localhost:3000/admin`

## 部署

支持三种部署方式：**GitHub Actions 自动部署**、**一键脚本部署**、**Docker 部署**。详见 [快速部署指南](./快速部署指南.md)。

## 目录结构

```
├── server.js          # 主服务入口
├── db.js              # 数据库操作层
├── package.json       # 项目配置
├── shujuku.sql        # 数据库初始化 SQL
├── .env.example       # 环境变量模板
├── deploy.bat/.sh     # 一键部署脚本
├── public/            # 前端静态资源
│   ├── index.html     # 主页面
│   ├── admin.html     # 管理后台
│   ├── query.html     # 查询页面
│   └── img/           # 头像素材库（100+）
└── data/              # 运行数据
```

## License

MIT