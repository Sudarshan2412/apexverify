const express = require('express');
const { spawn } = require('child_process');

const router = express.Router();

const RESOLVE_TTL_MS = 5 * 60 * 1000;
const _resolvedCache = new Map();

function _isDirectStreamUrl(url) {
  return url.includes('.m3u8') || url.includes('.ts') || url.includes('manifest');
}

function _cacheGet(url) {
  const entry = _resolvedCache.get(url);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    _resolvedCache.delete(url);
    return null;
  }
  return entry.value;
}

function _cacheSet(url, value) {
  _resolvedCache.set(url, { value, expiresAt: Date.now() + RESOLVE_TTL_MS });
}

function _runWithTimeout(command, args, { timeoutMs = 15000, binaryStdout = false } = {}) {
  return new Promise((resolve) => {
    let stdout = binaryStdout ? [] : '';
    let stderr = '';
    let timedOut = false;
    let finished = false;

    function finish(result) {
      if (finished) return;
      finished = true;
      resolve(result);
    }

    const child = spawn(command, args, {
      // Avoid spawning a shell; it complicates termination and can cause hangs
      // when the shell doesn't forward signals to grandchildren.
      shell: false,
      windowsHide: true,
      // On Unix, run in a new process group so we can SIGKILL the whole tree.
      detached: process.platform !== 'win32',
    });

    async function killTree() {
      try {
        if (process.platform === 'win32') {
          // Kill the whole tree so ffmpeg doesn't survive the shell.
          spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], {
            shell: true,
            windowsHide: true,
          });
        } else {
          // Kill the whole process group.
          try {
            process.kill(-child.pid, 'SIGKILL');
          } catch (_) {
            child.kill('SIGKILL');
          }
        }
      } catch (_) {
        try {
          child.kill();
        } catch (_) {
          // ignore
        }
      }
    }

    const timer = setTimeout(() => {
      timedOut = true;
      killTree();
      // Ensure we return even if the child never emits 'close'.
      finish({
        code: -1,
        stdout: binaryStdout ? Buffer.concat(stdout) : stdout,
        stderr,
        timedOut: true,
      });
    }, timeoutMs);

    if (binaryStdout) {
      child.stdout.on('data', (chunk) => stdout.push(chunk));
    } else {
      child.stdout.setEncoding('utf8');
      child.stdout.on('data', (chunk) => (stdout += chunk));
    }

    child.stderr.setEncoding('utf8');
    child.stderr.on('data', (chunk) => (stderr += chunk));

    child.on('close', (code) => {
      clearTimeout(timer);
      finish({
        code: typeof code === 'number' ? code : -1,
        stdout: binaryStdout ? Buffer.concat(stdout) : stdout,
        stderr,
        timedOut,
      });
    });

    child.on('error', (err) => {
      clearTimeout(timer);
      finish({ code: -1, stdout: binaryStdout ? Buffer.alloc(0) : '', stderr: String(err), timedOut });
    });
  });
}

async function _resolveStreamUrl(inputUrl) {
  if (_isDirectStreamUrl(inputUrl)) return inputUrl;

  const cached = _cacheGet(inputUrl);
  if (cached) return cached;

  // Prefer `yt-plb` if installed (requested). Fall back to `yt-dlp`.
  const candidates = ['yt-plb', 'yt-dlp'];

  for (const exe of candidates) {
    const res = await _runWithTimeout(
      exe,
      [
        '-g',
        '--no-playlist',
        '--no-check-certificate',
        '--geo-bypass',
        // Prefer MP4 when available, but fall back to whatever the extractor
        // can provide for this URL.
        '-f',
        'best[ext=mp4]/best',
        inputUrl,
      ],
      { timeoutMs: 30000, binaryStdout: false },
    );

    if (res.code === 0) {
      const resolvedLines = String(res.stdout || '')
        .split(/\r?\n/)
        .map((l) => l.trim())
        .filter(Boolean);
      const resolved = resolvedLines[0];
      if (resolved) {
        _cacheSet(inputUrl, resolved);
        return resolved;
      }
    }
  }

  return null;
}

async function _resolveStreamUrlWithDebug(inputUrl) {
  if (_isDirectStreamUrl(inputUrl)) return { streamUrl: inputUrl, debug: null };

  const cached = _cacheGet(inputUrl);
  if (cached) return { streamUrl: cached, debug: null };

  const candidates = ['yt-plb', 'yt-dlp'];
  let lastStderr = '';

  for (const exe of candidates) {
    const res = await _runWithTimeout(
      exe,
      [
        '-g',
        '--no-playlist',
        '--no-check-certificate',
        '--geo-bypass',
        '-f',
        'best[ext=mp4]/best',
        inputUrl,
      ],
      { timeoutMs: 30000, binaryStdout: false },
    );

    lastStderr = res.stderr || lastStderr;

    if (res.code === 0) {
      const resolvedLines = String(res.stdout || '')
        .split(/\r?\n/)
        .map((l) => l.trim())
        .filter(Boolean);
      const resolved = resolvedLines[0];
      if (resolved) {
        _cacheSet(inputUrl, resolved);
        return { streamUrl: resolved, debug: null };
      }
    }
  }

  const debug = lastStderr
    ? String(lastStderr)
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 500)
    : null;
  return { streamUrl: null, debug };
}

router.get('/frame', async (req, res) => {
  const url = (req.query.url || '').toString().trim();
  if (!url) {
    return res.status(400).send('Missing required query param: url');
  }

  const tRaw = (req.query.t || '').toString().trim();
  const t = Number.isFinite(Number(tRaw)) ? Math.max(0, Math.floor(Number(tRaw))) : 0;

  try {
    const { streamUrl, debug } = await _resolveStreamUrlWithDebug(url);
    if (!streamUrl) {
      const suffix = debug ? ` Details: ${debug}` : '';
      return res.status(502).send(`Failed to resolve stream URL (yt-plb/yt-dlp).${suffix}`);
    }

    const isHls = streamUrl.includes('.m3u8') || streamUrl.includes('manifest');
    const canSeek = t > 0;

    const baseArgs = [
      '-y',
      '-nostdin',
      '-hide_banner',
      '-loglevel', 'error',
      '-rw_timeout', '15000000', // 15s (microseconds)
      ...(isHls ? ['-live_start_index', '-1'] : []),
    ];

    const argsWithSeek = [
      ...baseArgs,
      ...(canSeek ? ['-ss', String(t)] : []),
      '-i', streamUrl,
      '-vframes', '1',
      '-f', 'image2pipe',
      '-vcodec', 'png',
      'pipe:1',
    ];

    let ff = await _runWithTimeout('ffmpeg', argsWithSeek, { timeoutMs: 15000, binaryStdout: true });

    // If seeking isn't supported for this URL type, retry once without -ss.
    if ((ff.timedOut || ff.code !== 0 || !ff.stdout || ff.stdout.length === 0) && canSeek) {
      const argsNoSeek = [
        ...baseArgs,
        '-i', streamUrl,
        '-vframes', '1',
        '-f', 'image2pipe',
        '-vcodec', 'png',
        'pipe:1',
      ];
      ff = await _runWithTimeout('ffmpeg', argsNoSeek, { timeoutMs: 15000, binaryStdout: true });
    }

    if (ff.timedOut) {
      // Most common cause: expired / stalled stream URL.
      _resolvedCache.delete(url);
      return res.status(504).send('ffmpeg timed out while grabbing a frame');
    }

    if (ff.code !== 0 || !ff.stdout || ff.stdout.length === 0) {
      // If the stream URL expired, clear cache so next request re-resolves.
      _resolvedCache.delete(url);
      return res.status(502).send(ff.stderr || 'ffmpeg failed to produce frame output');
    }

    res.setHeader('Content-Type', 'image/png');
    return res.status(200).send(ff.stdout);
  } catch (err) {
    _resolvedCache.delete(url);
    return res.status(500).send(String(err));
  }
});

module.exports = router;
