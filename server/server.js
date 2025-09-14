const express = require('express');
const multer = require('multer');
const sqlite3 = require('sqlite3').verbose();
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const cors = require('cors');

const app = express();
const port = 3000;

// 启用CORS
app.use(cors());
app.use(express.json());

// 创建uploads目录
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir);
}

// 初始化SQLite数据库
const db = new sqlite3.Database('./database.db');

// 创建images表
db.run(`
    CREATE TABLE IF NOT EXISTS images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hash TEXT UNIQUE NOT NULL,
        filename TEXT NOT NULL,
        original_name TEXT,
        mime_type TEXT,
        size INTEGER,
        uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
`);

// 配置multer用于文件上传
const storage = multer.memoryStorage();
const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 10 * 1024 * 1024 // 10MB限制
    }
});

// 计算文件hash
function calculateHash(buffer) {
    return crypto.createHash('md5').update(buffer).digest('hex');
}

// 检查hash是否存在
app.get('/check/:hash', (req, res) => {
    const { hash } = req.params;
    
    db.get('SELECT * FROM images WHERE hash = ?', [hash], (err, row) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        
        if (row) {
            res.json({ 
                exists: true, 
                url: `http://localhost:${port}/image/${hash}`,
                filename: row.filename,
                uploaded_at: row.uploaded_at
            });
        } else {
            res.json({ exists: false });
        }
    });
});

// 上传图片
app.post('/upload', upload.single('image'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    const buffer = req.file.buffer;
    const hash = calculateHash(buffer);
    const fileExtension = path.extname(req.file.originalname) || '.jpg';
    const filename = `${hash}${fileExtension}`;
    const filePath = path.join(uploadsDir, filename);

    // 检查是否已存在
    db.get('SELECT * FROM images WHERE hash = ?', [hash], (err, row) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }

        if (row) {
            // 文件已存在，直接返回URL
            return res.json({
                success: true,
                exists: true,
                hash: hash,
                url: `http://localhost:${port}/image/${hash}`,
                message: 'File already exists'
            });
        }

        // 保存文件
        fs.writeFile(filePath, buffer, (err) => {
            if (err) {
                return res.status(500).json({ error: 'Failed to save file' });
            }

            // 保存到数据库
            db.run(`
                INSERT INTO images (hash, filename, original_name, mime_type, size)
                VALUES (?, ?, ?, ?, ?)
            `, [hash, filename, req.file.originalname, req.file.mimetype, req.file.size], (err) => {
                if (err) {
                    // 删除已保存的文件
                    fs.unlinkSync(filePath);
                    return res.status(500).json({ error: 'Database error' });
                }

                res.json({
                    success: true,
                    exists: false,
                    hash: hash,
                    url: `http://localhost:${port}/image/${hash}`,
                    message: 'File uploaded successfully'
                });
            });
        });
    });
});

// 获取图片
app.get('/image/:hash', (req, res) => {
    const { hash } = req.params;
    
    db.get('SELECT * FROM images WHERE hash = ?', [hash], (err, row) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        
        if (!row) {
            return res.status(404).json({ error: 'Image not found' });
        }
        
        const filePath = path.join(uploadsDir, row.filename);
        
        // 检查文件是否存在
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'File not found on disk' });
        }
        
        // 设置正确的Content-Type
        res.setHeader('Content-Type', row.mime_type || 'image/jpeg');
        res.setHeader('Cache-Control', 'public, max-age=31536000'); // 1年缓存
        
        // 发送文件
        res.sendFile(filePath);
    });
});

// 获取所有图片列表（可选功能）
app.get('/images', (req, res) => {
    db.all('SELECT hash, original_name, size, uploaded_at FROM images ORDER BY uploaded_at DESC', (err, rows) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        
        const images = rows.map(row => ({
            hash: row.hash,
            original_name: row.original_name,
            size: row.size,
            uploaded_at: row.uploaded_at,
            url: `http://localhost:${port}/image/${row.hash}`
        }));
        
        res.json(images);
    });
});

// 健康检查
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(port, () => {
    console.log(`Smart Paste URL server running at http://localhost:${port}`);
    console.log(`Upload endpoint: POST http://localhost:${port}/upload`);
    console.log(`Check endpoint: GET http://localhost:${port}/check/{hash}`);
    console.log(`Image endpoint: GET http://localhost:${port}/image/{hash}`);
});

// 优雅关闭
process.on('SIGINT', () => {
    console.log('\nShutting down server...');
    db.close();
    process.exit();
});