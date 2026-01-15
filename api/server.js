const express = require('express');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const crypto = require('crypto');

const app = express();
app.use(express.json({ limit: '50mb' })); // Support large scripts

const PORT = 3000;
const MASTER_KEY = process.env.MASTER_KEY || "LUASEC.CC";
const LUA_CMD = process.platform === "win32" ? "lua" : "lua5.1"; // Auto-detect Windows

// Auth Middleware
const auth = (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || authHeader !== `Bearer ${MASTER_KEY}`) {
        return res.status(401).json({ error: "Unauthorized" });
    }
    next();
};

// Queue System Configuration
const CONCURRENCY = 1; // Safety for 1GB RAM
const CLEANUP_AGE = 3600 * 1000; // 1 Hour

const jobs = new Map(); // Store job details: id -> { status, url, ... }
const queue = [];       // Queue of job IDs waiting for processing
let activeJobs = 0;

// Serve obfuscated files statically
app.use('/files/lua', express.static(path.join(__dirname, 'temp')));

// Helper: Process Queue
const processQueue = () => {
    if (activeJobs >= CONCURRENCY || queue.length === 0) return;

    const jobId = queue.shift();
    activeJobs++;

    const job = jobs.get(jobId);
    if (!job) {
        activeJobs--;
        return processQueue();
    }

    job.status = 'processing';
    job.startedAt = Date.now();
    console.log(`[${jobId}] Processing started... (Queue: ${queue.length})`);

    // Extract job details for execution
    const { script, profile, options, runId, LUA_CMD } = job.payload;
    const tempDir = path.join(__dirname, 'temp');
    const inputFile = path.join(tempDir, `${runId}.in.lua`);
    const outputFile = path.join(tempDir, `${runId}.lua`);

    try {
        fs.writeFileSync(inputFile, script);

        // Build command arguments
        const scriptPath = path.resolve(__dirname, '..', 'lua.rip.lua');
        let cmd = `${LUA_CMD} "${scriptPath}" "${inputFile}" "${outputFile}"`;

        if (profile === 'luasec' || (options && options.preset === 'luasec')) {
            cmd += ` --preset-luasec`;
        } else {
            const safeProfile = (['speed', 'balanced', 'maximum'].includes(profile)) ? profile : 'balanced';
            cmd += ` --profile ${safeProfile}`;
        }

        if (options) {
            if (options.vm) cmd += ` --vm`;
            if (options.junk_yard) cmd += ` --junk-yard`;
        }

        exec(cmd, { cwd: path.join(__dirname, '..') }, (error, stdout, stderr) => {
            const duration = (Date.now() - job.startedAt) / 1000;
            activeJobs--;

            if (fs.existsSync(outputFile)) {
                const stats = fs.statSync(outputFile);

                // Construct URL (using stored req context or relative)
                // We'll trust the user knows their domain for now or store it
                const fileUrl = `${job.baseUrl}/files/lua/${runId}.lua`;

                job.status = 'completed';
                job.completedAt = Date.now();
                job.result = {
                    success: true,
                    url: fileUrl,
                    stats: {
                        original_size: script.length,
                        obfuscated_size: stats.size,
                        ratio: (stats.size / script.length).toFixed(2) + "x",
                        time: duration
                    }
                };
                console.log(`[${jobId}] Completed in ${duration}s`);
            } else {
                job.status = 'failed';
                job.error = stderr || "Unknown error";
                console.error(`[${jobId}] Failed: ${stderr}`);
            }

            // Cleanup Inputs
            if (fs.existsSync(inputFile)) fs.unlinkSync(inputFile);

            // Schedule final cleanup
            setTimeout(() => {
                jobs.delete(jobId); // Remove from memory
                if (fs.existsSync(outputFile)) fs.unlinkSync(outputFile);
            }, CLEANUP_AGE);

            // Trigger next
            processQueue();
        });

    } catch (e) {
        job.status = 'failed';
        job.error = e.message;
        activeJobs--;
        processQueue();
    }
};

// Endpoints

// Global API Status
app.get('/status', (req, res) => {
    res.json({
        status: "online",
        version: "2.1.0",
        queue: {
            waiting: queue.length,
            active: activeJobs,
            total_jobs_stored: jobs.size
        }
    });
});

// Job Status Check
app.get('/status/:id', (req, res) => {
    const job = jobs.get(req.params.id);
    if (!job) {
        return res.status(404).json({ error: "Job not found or expired" });
    }

    const response = {
        id: job.id,
        status: job.status,
        submitted_at: job.submittedAt,
    };

    if (job.status === 'completed') {
        response.result = job.result;
    } else if (job.status === 'failed') {
        response.error = job.error;
    } else if (job.status === 'queued') {
        response.position = queue.indexOf(job.id) + 1;
    }

    res.json(response);
});

app.get('/type', (req, res) => {
    res.json({ type: "premium_api", engine: "lua.rip v2.0" });
});

app.get('/features', (req, res) => {
    res.json({
        presets: ["speed", "balanced", "maximum", "luasec"],
        options: ["junk_yard", "vm", "anti_tamper", "watermark"],
        limits: { max_size_mb: 50, queue_enabled: true }
    });
});

app.post('/obfuscate', auth, (req, res) => {
    const { script, profile, options } = req.body;

    if (!script) {
        return res.status(400).json({ error: "No script provided" });
    }

    const jobId = crypto.randomBytes(12).toString('hex'); // Public Job ID
    const runId = crypto.randomBytes(16).toString('hex'); // Internal File ID

    const protocol = req.headers['x-forwarded-proto'] || req.protocol;
    const host = req.headers['x-forwarded-host'] || req.get('host');
    const baseUrl = `${protocol}://${host}`;

    const job = {
        id: jobId,
        status: 'queued',
        submittedAt: Date.now(),
        baseUrl: baseUrl,
        payload: {
            script,
            profile,
            options,
            runId,
            LUA_CMD
        }
    };

    jobs.set(jobId, job);
    queue.push(jobId);

    // Trigger processing
    processQueue();

    // Return immediate response
    res.json({
        success: true,
        job_id: jobId,
        status: "queued",
        status_url: `${baseUrl}/status/${jobId}`,
        queue_position: queue.length
    });
});

const server = app.listen(PORT, () => {
    console.log(`lua.rip API v2.1 (Queue System) running on port ${PORT}`);
    console.log(`Master Key: ${MASTER_KEY}`);
});

// Increase timeout for Junk Yard builds
server.timeout = 120000; // 2 minutes
