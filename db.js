const mysql = require('mysql2/promise');
require('dotenv').config();

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'wechat_report'
};

const pool = mysql.createPool({
  ...dbConfig,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

const createIndex = async (conn, table, column, indexName) => {
  try {
    await conn.execute(`CREATE INDEX ${indexName} ON ${table}(${column})`);
  } catch (e) {
    if (e.code === 'ER_DUP_KEYNAME') {
      // 索引已存在，忽略错误
      console.log(`  - 索引 ${indexName} 已存在，跳过`);
    } else {
      throw e;
    }
  }
};

async function initDatabase() {
  try {
    let connection;
    try {
      connection = await pool.getConnection();
    } catch (error) {
      if (error.code === 'ER_BAD_DB_ERROR') {
        console.log('数据库不存在，正在创建...');
        const tempConn = await mysql.createConnection({
          host: dbConfig.host,
          port: dbConfig.port,
          user: dbConfig.user,
          password: dbConfig.password
        });
        await tempConn.execute(`CREATE DATABASE IF NOT EXISTS ${dbConfig.database} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
        await tempConn.end();
        connection = await pool.getConnection();
      } else {
        throw error;
      }
    }
    
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        role ENUM('admin', 'user') DEFAULT 'user',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS activation_codes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        code VARCHAR(32) UNIQUE NOT NULL,
        max_uses INT NOT NULL DEFAULT 1,
        used_count INT NOT NULL DEFAULT 0,
        status ENUM('active', 'expired', 'disabled') DEFAULT 'active',
        created_by INT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP NULL,
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tasks (
        id INT AUTO_INCREMENT PRIMARY KEY,
        target VARCHAR(100) NOT NULL,
        report_type VARCHAR(50) NOT NULL,
        account_count INT NOT NULL,
        activation_code_id INT,
        status ENUM('pending', 'running', 'completed', 'failed') DEFAULT 'pending',
        success_count INT DEFAULT 0,
        fail_count INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        completed_at TIMESTAMP NULL,
        FOREIGN KEY (activation_code_id) REFERENCES activation_codes(id) ON DELETE SET NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS task_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        task_id INT NOT NULL,
        account_id VARCHAR(50) NOT NULL,
        account_name VARCHAR(100),
        action VARCHAR(100),
        status ENUM('pending', 'success', 'failed') DEFAULT 'pending',
        error_message TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS query_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        activation_code_id INT NULL,
        code VARCHAR(32) NULL,
        target VARCHAR(100) NULL,
        report_type VARCHAR(50) NULL,
        account_count INT NULL,
        ip VARCHAR(45) NULL,
        user_agent TEXT NULL,
        device_info VARCHAR(200) NULL,
        status ENUM('success', 'failed') DEFAULT 'success',
        message VARCHAR(255) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (activation_code_id) REFERENCES activation_codes(id) ON DELETE SET NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS ban_records (
        id INT AUTO_INCREMENT PRIMARY KEY,
        target VARCHAR(100) NOT NULL,
        account_id VARCHAR(100) NULL,
        nickname VARCHAR(100) NULL,
        status ENUM('banned', 'suspected', 'clean') DEFAULT 'suspected',
        report_count INT DEFAULT 0,
        reason VARCHAR(255) NULL,
        last_reported_at TIMESTAMP NULL,
        details TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

await createIndex(connection, 'activation_codes', 'code', 'idx_activation_codes_code');
await createIndex(connection, 'activation_codes', 'status', 'idx_activation_codes_status');
await createIndex(connection, 'tasks', 'activation_code_id', 'idx_tasks_activation_code');
await createIndex(connection, 'tasks', 'status', 'idx_tasks_status');
await createIndex(connection, 'task_logs', 'task_id', 'idx_task_logs_task_id');
await createIndex(connection, 'query_logs', 'activation_code_id', 'idx_query_logs_activation_code');
await createIndex(connection, 'ban_records', 'target', 'idx_ban_records_target');
await createIndex(connection, 'users', 'username', 'idx_users_username');

    const [adminRows] = await connection.execute(
      'SELECT id FROM users WHERE username = ?',
      ['admin']
    );

    if (adminRows.length === 0) {
      const bcrypt = require('bcryptjs');
      const hashedPassword = await bcrypt.hash(process.env.ADMIN_PASSWORD || 'admin123456', 10);
      await connection.execute(
        'INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
        ['admin', hashedPassword, 'admin']
      );
      console.log('✓ 默认管理员账户已创建');
    }

    const demoCode = process.env.DEMO_CODE || 'DEMO-2026-TEST';
    const demoMaxUses = parseInt(process.env.DEMO_MAX_USES) || 50;

    const [codeRows] = await connection.execute(
      'SELECT id FROM activation_codes WHERE code = ?',
      [demoCode]
    );

    if (codeRows.length === 0) {
      await connection.execute(
        'INSERT INTO activation_codes (code, max_uses, used_count, status) VALUES (?, ?, 0, ?)',
        [demoCode, demoMaxUses, 'active']
      );
      console.log(`✓ 演示激活码已创建: ${demoCode} (${demoMaxUses}次)`);
    }

    const [banRows] = await connection.execute(
      'SELECT id FROM ban_records LIMIT 1'
    );

    if (banRows.length === 0) {
      await connection.execute(
        `INSERT INTO ban_records (target, account_id, nickname, status, report_count, reason, last_reported_at, details) \
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        ['wxid_demo123', 'wxid_demo123', '演示目标', 'banned', 18, '违规内容大量举报', new Date(), '该账号因多次恶意行为被系统判定为高风险封号目标。']
      );
      console.log('✓ 默认封号记录已创建，方便查询演示');
    }

    connection.release();
    console.log('✓ 数据库初始化完成');
  } catch (error) {
    console.error('✗ 数据库初始化失败:', error.message);
    throw error;
  }
}

async function verifyActivationCode(code) {
  try {
    const [rows] = await pool.execute(
      'SELECT * FROM activation_codes WHERE code = ? AND status = ?',
      [code, 'active']
    );

    if (rows.length === 0) {
      return { valid: false, message: '激活码无效或已失效' };
    }

    const activation = rows[0];

    if (activation.expires_at && new Date(activation.expires_at) < new Date()) {
      await pool.execute(
        'UPDATE activation_codes SET status = ? WHERE id = ?',
        ['expired', activation.id]
      );
      return { valid: false, message: '激活码已过期' };
    }

    if (activation.used_count >= activation.max_uses) {
      await pool.execute(
        'UPDATE activation_codes SET status = ? WHERE id = ?',
        ['expired', activation.id]
      );
      return { valid: false, message: '激活码使用次数已达上限' };
    }

    return { valid: true, activation };
  } catch (error) {
    console.error('验证激活码失败:', error);
    return { valid: false, message: '服务器错误' };
  }
}

async function useActivationCode(codeId) {
  try {
    console.log('[DEBUG] useActivationCode 被调用，codeId:', codeId);
    
    // 先查询当前激活码信息
    const [before] = await pool.execute(
      'SELECT * FROM activation_codes WHERE id = ?',
      [codeId]
    );
    console.log('[DEBUG] 更新前激活码信息:', before[0]);
    
    // 更新使用次数
    const [result] = await pool.execute(
      'UPDATE activation_codes SET used_count = used_count + 1 WHERE id = ?',
      [codeId]
    );
    console.log('[DEBUG] 更新使用次数影响行数:', result.affectedRows);
    
    // 查询更新后的信息
    const [after] = await pool.execute(
      'SELECT * FROM activation_codes WHERE id = ?',
      [codeId]
    );
    console.log('[DEBUG] 更新后激活码信息:', after[0]);
    
    // 检查是否达到最大使用次数，如果达到则标记为 expired
    const [statusResult] = await pool.execute(`
      UPDATE activation_codes 
      SET status = 'expired' 
      WHERE id = ? AND used_count >= max_uses AND status = 'active'
    `, [codeId]);
    console.log('[DEBUG] 更新状态影响行数:', statusResult.affectedRows);
    
  } catch (error) {
    console.error('[DEBUG] 更新激活码使用次数失败:', error);
  }
}

async function createTask(taskData) {
  try {
    const [result] = await pool.execute(
      `INSERT INTO tasks (target, report_type, account_count, activation_code_id, status) 
       VALUES (?, ?, ?, ?, ?)`,
      [taskData.target, taskData.reportType, taskData.accountCount, taskData.codeId, 'pending']
    );
    return result.insertId;
  } catch (error) {
    console.error('创建任务失败:', error);
    throw error;
  }
}

async function updateTaskStatus(taskId, status, successCount = 0, failCount = 0) {
  try {
    console.log('[DEBUG] updateTaskStatus 被调用，参数:', { taskId, status, successCount, failCount });
    
    const updates = ['status = ?', 'completed_at = ?'];
    const values = [status, new Date()];

    if (successCount > 0) {
      updates.push('success_count = ?');
      values.push(successCount);
    }

    if (failCount > 0) {
      updates.push('fail_count = ?');
      values.push(failCount);
    }

    values.push(taskId);
    
    console.log('[DEBUG] 执行 SQL:', `UPDATE tasks SET ${updates.join(', ')} WHERE id = ?`, values);
    const [result] = await pool.execute(
      `UPDATE tasks SET ${updates.join(', ')} WHERE id = ?`,
      values
    );
    console.log('[DEBUG] 更新任务状态影响行数:', result.affectedRows);
    
  } catch (error) {
    console.error('[DEBUG] 更新任务状态失败:', error);
  }
}

async function getTaskStats(codeId) {
  try {
    const [rows] = await pool.execute(
      `SELECT 
        COUNT(*) as total_tasks,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
        SUM(success_count) as total_success,
        SUM(fail_count) as total_fail
      FROM tasks 
      WHERE activation_code_id = ?`,
      [codeId]
    );
    return rows[0];
  } catch (error) {
    console.error('获取任务统计失败:', error);
    return { total_tasks: 0, completed_tasks: 0, total_success: 0, total_fail: 0 };
  }
}

async function getAllActivationCodes() {
  try {
    const [rows] = await pool.execute(`
      SELECT 
        ac.*,
        u.username as created_by_name,
        COALESCE(ts.total_tasks, 0) as total_tasks
      FROM activation_codes ac
      LEFT JOIN users u ON ac.created_by = u.id
      LEFT JOIN (
        SELECT activation_code_id, COUNT(*) as total_tasks
        FROM tasks
        GROUP BY activation_code_id
      ) ts ON ac.id = ts.activation_code_id
      ORDER BY ac.created_at DESC
    `);
    return rows;
  } catch (error) {
    console.error('获取激活码列表失败:', error);
    return [];
  }
}

async function createQueryLog(logData) {
  try {
    const [result] = await pool.execute(
      `INSERT INTO query_logs (
         activation_code_id, code, target, report_type, account_count,
         ip, user_agent, device_info, status, message
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        logData.activationCodeId || null,
        logData.code || null,
        logData.target || null,
        logData.reportType || null,
        logData.accountCount || null,
        logData.ip || null,
        logData.userAgent || null,
        logData.deviceInfo || null,
        logData.status || 'success',
        logData.message || null
      ]
    );
    return result.insertId;
  } catch (error) {
    console.error('创建查询日志失败:', error);
    throw error;
  }
}

async function getQueryLogs(limit = 100) {
  try {
    const [rows] = await pool.execute(
      `SELECT ql.*, ac.code as activation_code, ac.status as activation_status
       FROM query_logs ql
       LEFT JOIN activation_codes ac ON ql.activation_code_id = ac.id
       ORDER BY ql.created_at DESC
       LIMIT ?`,
      [limit]
    );
    return rows;
  } catch (error) {
    console.error('获取查询日志失败:', error);
    return [];
  }
}

async function searchBanRecords(target) {
  try {
    const query = `%${target}%`;
    const [rows] = await pool.execute(
      `SELECT *, 'ban_records' AS source FROM ban_records
       WHERE target = ?
          OR account_id = ?
          OR target LIKE ?
          OR account_id LIKE ?
          OR nickname LIKE ?
       ORDER BY last_reported_at DESC, created_at DESC
       LIMIT 20`,
      [target, target, query, query, query]
    );

    if (rows.length > 0) {
      return rows;
    }

    const [taskRows] = await pool.execute(
      `SELECT target, created_at
       FROM tasks
       WHERE target = ?
         OR target LIKE ?
       ORDER BY created_at DESC
       LIMIT 20`,
      [target, query]
    );

    if (taskRows.length > 0) {
      return taskRows.map((row) => ({
        target: row.target,
        account_id: row.target,
        nickname: null,
        status: 'reported',
        report_count: null,
        reason: '已提交举报任务记录',
        last_reported_at: row.created_at,
        source: 'tasks'
      }));
    }

    return [];
  } catch (error) {
    console.error('查询封号记录失败:', error);
    return [];
  }
}

async function createActivationCode(codeData) {
  try {
    const [result] = await pool.execute(
      `INSERT INTO activation_codes (code, max_uses, created_by, expires_at) 
       VALUES (?, ?, ?, ?)`,
      [codeData.code, codeData.maxUses, codeData.createdBy, codeData.expiresAt || null]
    );
    return result.insertId;
  } catch (error) {
    console.error('创建激活码失败:', error);
    throw error;
  }
}

async function updateActivationCodeStatus(codeId, status) {
  try {
    await pool.execute(
      'UPDATE activation_codes SET status = ? WHERE id = ?',
      [status, codeId]
    );
  } catch (error) {
    console.error('更新激活码状态失败:', error);
  }
}

async function getSystemStats() {
  try {
    const [codeStats] = await pool.execute(`
      SELECT 
        COUNT(*) as total_codes,
        SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_codes,
        SUM(used_count) as total_uses,
        SUM(max_uses) as total_max_uses
      FROM activation_codes
    `);

    const [taskStats] = await pool.execute(`
      SELECT 
        COUNT(*) as total_tasks,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
        SUM(success_count) as total_success,
        SUM(fail_count) as total_fail
      FROM tasks
    `);

    return {
      codes: codeStats[0],
      tasks: taskStats[0]
    };
  } catch (error) {
    console.error('获取系统统计失败:', error);
    return {
      codes: { total_codes: 0, active_codes: 0, total_uses: 0, total_max_uses: 0 },
      tasks: { total_tasks: 0, completed_tasks: 0, total_success: 0, total_fail: 0 }
    };
  }
}

module.exports = {
  pool,
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
};

if (require.main === module && process.argv.includes('--init')) {
  initDatabase().then(() => {
    process.exit(0);
  }).catch((error) => {
    console.error(error);
    process.exit(1);
  });
}