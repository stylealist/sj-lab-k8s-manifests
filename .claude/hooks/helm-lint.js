#!/usr/bin/env node
// PostToolUse hook: Edit/Write/MultiEdit로 Helm 차트 파일이 바뀌면 자동으로 helm lint를 돌린다.
'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

function extractFilePaths(input) {
  const ti = input.tool_input || {};
  if (ti.file_path) return [ti.file_path];
  if (Array.isArray(ti.edits) && ti.file_path) return [ti.file_path];
  return [];
}

function findChartRoot(filePath, repoRoot) {
  let dir = path.dirname(path.resolve(filePath));
  while (dir.startsWith(repoRoot)) {
    if (fs.existsSync(path.join(dir, 'Chart.yaml'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

let raw;
try {
  raw = JSON.parse(readStdin() || '{}');
} catch {
  process.exit(0);
}

const repoRoot = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const files = extractFilePaths(raw).filter((f) => /\.ya?ml$/i.test(f));
if (files.length === 0) process.exit(0);

const checked = new Set();
let hadFailure = false;
const messages = [];

for (const file of files) {
  const chartRoot = findChartRoot(file, path.resolve(repoRoot));
  if (!chartRoot || checked.has(chartRoot)) continue;
  checked.add(chartRoot);

  const result = spawnSync('helm', ['lint', chartRoot], { encoding: 'utf8' });
  if (result.error) {
    // helm CLI가 없으면 조용히 건너뛴다.
    continue;
  }
  if (result.status !== 0) {
    hadFailure = true;
    messages.push(`[helm lint] ${path.relative(repoRoot, chartRoot)} 실패:\n${result.stdout}${result.stderr}`);
  }
}

if (hadFailure) {
  process.stderr.write(messages.join('\n\n') + '\n');
  process.exit(2);
}
process.exit(0);
