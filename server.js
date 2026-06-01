const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const path = require('path');
const cors = require('cors');
require('dotenv').config();

const db = require('./db');
const { 
  initDatabase, 
  verifyActivationCode, 
  useActivationCode, 
  createTask, 
  updateTaskStatus,
  getTaskStats,
  getAllActivationCodes,
  createActivationCode,
  updateActivationCodeStatus,
  getSystemStats,
  createQueryLog,
  getQueryLogs,
  searchBanRecords
} = db;

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET;

app.use(cors());
app.use(express.json());
// 给静态文件添加缓存头，图片缓存 7 天
app.use((req, res, next) => {
  if (req.path.startsWith('/img/')) {
    res.setHeader('Cache-Control', 'public, max-age=604800');
  }
  next();
});
app.use(express.static('public'));

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: '未提供认证令牌' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: '无效的认证令牌' });
    }
    req.user = user;
    next();
  });
}

function generateRandomCode(length = 16) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/query', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'query.html'));
});

app.get('/query.html', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'query.html'));
});

app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

function parseDeviceInfo(userAgent = '') {
  const ua = userAgent.toLowerCase();
  if (ua.includes('iphone')) return 'iPhone';
  if (ua.includes('ipad')) return 'iPad';
  if (ua.includes('android')) return 'Android';
  if (ua.includes('windows phone')) return 'Windows Phone';
  if (ua.includes('macintosh') || ua.includes('mac os x')) return 'Mac';
  if (ua.includes('windows')) return 'Windows';
  return 'Unknown';
}

function getRequestIp(req) {
  return (req.headers['x-forwarded-for'] || req.connection.remoteAddress || '').split(',')[0].trim();
}

app.post('/api/verify-code', async (req, res) => {
  try {
    const { code, target, reportType, accountCount } = req.body;
    const userAgent = req.headers['user-agent'] || '';
    const deviceInfo = parseDeviceInfo(userAgent);
    const ip = getRequestIp(req);

    if (!code) {
      return res.status(400).json({ error: '请输入激活码' });
    }

    const result = await verifyActivationCode(code);

    await createQueryLog({
      activationCodeId: result.valid ? result.activation.id : null,
      code,
      target: target || null,
      reportType: reportType || null,
      accountCount: accountCount || null,
      ip,
      userAgent,
      deviceInfo,
      status: result.valid ? 'success' : 'failed',
      message: result.valid ? '验证成功' : result.message
    });
    
    if (!result.valid) {
      return res.status(400).json({ error: result.message });
    }

    const stats = await getTaskStats(result.activation.id);
    
    res.json({
      valid: true,
      codeId: result.activation.id,
      remainingUses: result.activation.max_uses - result.activation.used_count,
      totalTasks: stats.total_tasks || 0,
      completedTasks: stats.completed_tasks || 0,
      totalSuccess: stats.total_success || 0,
      totalFail: stats.total_fail || 0
    });
  } catch (error) {
    console.error('验证激活码失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.get('/api/query-ban', async (req, res) => {
  try {
    const target = (req.query.target || '').trim();
    if (!target) {
      return res.status(400).json({ error: '请输入查询目标' });
    }
    const records = await searchBanRecords(target);
    console.log(`[DEBUG] /api/query-ban GET target='${target}' matches=${Array.isArray(records) ? records.length : 0}`);
    res.json({ success: true, records });
  } catch (error) {
    console.error('查询封号记录失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.post('/api/query-ban', async (req, res) => {
  try {
    const target = (req.body.target || '').trim();
    if (!target) {
      return res.status(400).json({ error: '请输入查询目标' });
    }
    const records = await searchBanRecords(target);
    console.log(`[DEBUG] /api/query-ban POST target='${target}' matches=${Array.isArray(records) ? records.length : 0}`);
    res.json({ success: true, records });
  } catch (error) {
    console.error('查询封号记录失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.post('/api/start-task', async (req, res) => {
  try {
    console.log('[DEBUG] /api/start-task 被调用，参数:', req.body);
    const { target, reportType, accountCount, codeId } = req.body;

    if (!target || !reportType || !accountCount || !codeId) {
      console.log('[DEBUG] 缺少必要参数');
      return res.status(400).json({ error: '缺少必要参数' });
    }

    const taskId = await createTask({
      target,
      reportType,
      accountCount,
      codeId
    });
    console.log('[DEBUG] 任务创建成功，taskId:', taskId);

    await useActivationCode(codeId);
    console.log('[DEBUG] 激活码使用次数已更新，codeId:', codeId);

    res.json({
      success: true,
      taskId,
      message: '任务已创建'
    });
  } catch (error) {
    console.error('[DEBUG] 启动任务失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.post('/api/update-task', async (req, res) => {
  try {
    console.log('[DEBUG] /api/update-task 被调用，参数:', req.body);
    const { taskId, status, successCount, failCount } = req.body;

    if (!taskId || !status) {
      console.log('[DEBUG] 缺少必要参数');
      return res.status(400).json({ error: '缺少必要参数' });
    }

    await updateTaskStatus(taskId, status, successCount, failCount);
    console.log('[DEBUG] 任务状态更新成功');

    res.json({ success: true });
  } catch (error) {
    console.error('[DEBUG] 更新任务状态失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.post('/api/admin/login', async (req, res) => {
  try {
    const { password } = req.body;

    if (!password || password.length < 6) {
      return res.status(400).json({ error: '请输入密码（至少6位）' });
    }

    const [rows] = await db.pool.execute(
      'SELECT password FROM users WHERE username = ? AND role = ?',
      ['admin', 'admin']
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: '管理员账户不存在' });
    }

    const isMatch = await bcrypt.compare(password, rows[0].password);
    
    if (!isMatch) {
      return res.status(401).json({ error: '密码错误' });
    }

    const token = jwt.sign(
      { username: 'admin', role: 'admin' },
      JWT_SECRET,
      { expiresIn: '8h' }
    );

    res.json({
      success: true,
      token,
      username: 'admin'
    });
  } catch (error) {
    console.error('管理员登录失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.get('/api/admin/stats', authenticateToken, async (req, res) => {
  try {
    const stats = await getSystemStats();
    res.json(stats);
  } catch (error) {
    console.error('获取统计信息失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.get('/api/admin/codes', authenticateToken, async (req, res) => {
  try {
    const codes = await getAllActivationCodes();
    res.json(codes);
  } catch (error) {
    console.error('获取激活码列表失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.get('/api/admin/query-logs', authenticateToken, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit, 10) || 100;
    const logs = await getQueryLogs(limit);
    res.json(logs);
  } catch (error) {
    console.error('获取查询日志失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.post('/api/admin/codes', authenticateToken, async (req, res) => {
  try {
    const { count, maxUses, expiresAt } = req.body;

    if (!count || !maxUses) {
      return res.status(400).json({ error: '缺少必要参数' });
    }

    const codes = [];
    for (let i = 0; i < count; i++) {
      const code = generateRandomCode();
      const codeId = await createActivationCode({
        code,
        maxUses,
        createdBy: 1,
        expiresAt: expiresAt || null
      });
      codes.push({ id: codeId, code, maxUses });
    }

    res.json({
      success: true,
      codes,
      message: `成功生成 ${count} 个激活码`
    });
  } catch (error) {
    console.error('生成激活码失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.patch('/api/admin/codes/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!status) {
      return res.status(400).json({ error: '缺少状态参数' });
    }

    await updateActivationCodeStatus(id, status);

    res.json({ success: true });
  } catch (error) {
    console.error('更新激活码状态失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.use((req, res) => {
  res.status(404).json({ error: '接口不存在' });
});

app.use((err, req, res, next) => {
  console.error('服务器错误:', err);
  res.status(500).json({ error: '服务器内部错误' });
});

async function startServer() {
  try {
    console.log('正在初始化数据库...');
    await initDatabase();
    
    app.listen(PORT, () => {
      console.log(`✓ 服务器已启动: http://localhost:${PORT}`);
      console.log(`✓ 管理后台: http://localhost:${PORT}/admin`);
      console.log(`✓ 演示激活码: ${process.env.DEMO_CODE}`);
    });
  } catch (error) {
    console.error('✗ 服务器启动失败:', error);
    process.exit(1);
  }
}

startServer();