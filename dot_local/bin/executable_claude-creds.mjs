#!/usr/bin/env node
// claude-creds — save / swap / refresh / test multiple Claude Code credential profiles.
//
// Cross-platform (Linux + Windows). Zero dependencies (Node 18+, native fetch).
//
// Live credentials  : $CLAUDE_CONFIG_DIR/.credentials.json  (default ~/.claude/.credentials.json)
// Account identity   : $CLAUDE_CONFIG_DIR/.claude.json .oauthAccount  (or ~/.claude.json)
// Profile store      : $CLAUDE_CREDS_HOME               (default ~/.claude/cred-profiles)  — keep OUT of git.
//
// Each profile file stores only the `claudeAiOauth` block + captured account metadata.
// The live `mcpOAuth` block (MCP server tokens) is machine-level and left untouched on swap.

import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'

const OAUTH_CLIENT_ID = '9d1c250a-e61b-44d9-88ed-5944d1962f5e'
const TOKEN_URL = 'https://platform.claude.com/v1/oauth/token'
const HOME = os.homedir()
const IS_WIN = process.platform === 'win32'

const CONFIG_DIR = process.env.CLAUDE_CONFIG_DIR || path.join(HOME, '.claude')
const CREDS_PATH = path.join(CONFIG_DIR, '.credentials.json')
const PROFILES_DIR = process.env.CLAUDE_CREDS_HOME || path.join(HOME, '.claude', 'cred-profiles')

// refresh a token proactively when it is expired or within this window of expiring
const REFRESH_SKEW_MS = 5 * 60 * 1000

// ---------- tiny ansi ----------
const noColor = process.env.NO_COLOR || !process.stdout.isTTY
const c = (n) => (s) => (noColor ? s : `\x1b[${n}m${s}\x1b[0m`)
const bold = c(1), dim = c(2), red = c(31), green = c(32), yellow = c(33), cyan = c(36)
const ok = green('✓'), bad = red('✗'), warn = yellow('!')

function die(msg) { console.error(red('error: ') + msg); process.exit(1) }
function readJson(p) { return JSON.parse(fs.readFileSync(p, 'utf8')) }
function writeJson(p, obj, mode = 0o600) {
  fs.mkdirSync(path.dirname(p), { recursive: true })
  fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n', { mode })
  try { fs.chmodSync(p, mode) } catch {}
}
function backup(p) {
  if (!fs.existsSync(p)) return null
  const b = p + '.bak'
  fs.copyFileSync(p, b)
  try { fs.chmodSync(b, 0o600) } catch {}
  return b
}

// ---------- locate the big .claude.json (holds oauthAccount) ----------
function claudeJsonPath() {
  const inConfig = path.join(CONFIG_DIR, '.claude.json')
  const inHome = path.join(HOME, '.claude.json')
  if (fs.existsSync(inConfig)) return inConfig
  if (fs.existsSync(inHome)) return inHome
  return inConfig // default target if neither exists yet
}

// ---------- profile store ----------
function ensureStore() { fs.mkdirSync(PROFILES_DIR, { recursive: true, mode: 0o700 }) }
function profilePath(name) { return path.join(PROFILES_DIR, `${name}.json`) }
function listProfileNames() {
  ensureStore()
  return fs.readdirSync(PROFILES_DIR)
    .filter((f) => f.endsWith('.json'))
    .map((f) => f.slice(0, -5))
    .sort()
}
function loadProfile(name) {
  const p = profilePath(name)
  if (!fs.existsSync(p)) die(`no such profile: ${name}\n  available: ${listProfileNames().join(', ') || '(none)'}`)
  return readJson(p)
}

// ---------- live credentials ----------
function loadLiveCreds() {
  if (!fs.existsSync(CREDS_PATH)) return null
  return readJson(CREDS_PATH)
}
function liveAccount() {
  const p = claudeJsonPath()
  if (!fs.existsSync(p)) return null
  try { return readJson(p).oauthAccount || null } catch { return null }
}

// which saved profile matches the live creds (by stable refreshToken, fallback accessToken)
function activeProfileName() {
  const live = loadLiveCreds()
  const o = live && live.claudeAiOauth
  if (!o) return null
  for (const name of listProfileNames()) {
    const prof = loadProfile(name).claudeAiOauth || {}
    if ((o.refreshToken && prof.refreshToken === o.refreshToken) ||
        (o.accessToken && prof.accessToken === o.accessToken)) return name
  }
  return null
}

// ---------- formatting helpers ----------
function fmtExpiry(expiresAt) {
  if (!expiresAt) return dim('no expiry')
  const ms = expiresAt - Date.now()
  const mins = Math.round(Math.abs(ms) / 60000)
  const h = Math.floor(mins / 60), m = mins % 60
  const span = h ? `${h}h${m}m` : `${m}m`
  return ms >= 0 ? green(`valid ${span}`) : red(`EXPIRED ${span} ago`)
}
function accountLabel(prof) {
  const a = prof.account || {}
  const email = a.emailAddress || prof.email || dim('unknown')
  const sub = (prof.claudeAiOauth && prof.claudeAiOauth.subscriptionType) || a.organizationType || ''
  return `${email}${sub ? dim(` (${sub})`) : ''}`
}

// ---------- claude binary (for `check`) ----------
function runClaude(args, extraEnv = {}) {
  const bin = process.env.CLAUDE_BIN || 'claude'
  return spawnSync(bin, args, {
    env: { ...process.env, ...extraEnv },
    encoding: 'utf8',
    shell: IS_WIN, // resolve claude.cmd on Windows
  })
}

// =====================================================================
// commands
// =====================================================================

function cmdSave(name) {
  if (!name) die('usage: claude-creds save <name>')
  const live = loadLiveCreds()
  if (!live || !live.claudeAiOauth) die(`no live credentials at ${CREDS_PATH} — run \`claude auth login\` first`)
  ensureStore()
  const p = profilePath(name)
  if (fs.existsSync(p)) backup(p)
  const account = liveAccount()
  const prof = {
    claudeAiOauth: live.claudeAiOauth,
    account: account || undefined,
    email: account && account.emailAddress,
    savedAt: new Date().toISOString(),
  }
  writeJson(p, prof)
  console.log(`${ok} saved profile ${bold(name)} → ${dim(p)}`)
  console.log(`  account: ${accountLabel(prof)}`)
  console.log(`  token:   ${fmtExpiry(prof.claudeAiOauth.expiresAt)}`)
}

async function cmdUse(name, opts) {
  if (!name) die('usage: claude-creds use <name>')
  let prof = loadProfile(name)
  if (!prof.claudeAiOauth) die(`profile ${name} has no claudeAiOauth block`)

  // 0) renew the token first if it's expired / about to expire
  prof = await ensureFresh(name, prof)

  // 1) write credentials, preserving existing mcpOAuth
  const live = loadLiveCreds() || {}
  backup(CREDS_PATH)
  const next = { ...live, claudeAiOauth: prof.claudeAiOauth }
  writeJson(CREDS_PATH, next)

  // 2) patch oauthAccount in .claude.json so `claude` shows the right identity
  if (!opts.noAccount && prof.account) {
    const cj = claudeJsonPath()
    if (fs.existsSync(cj)) {
      try {
        backup(cj)
        const doc = readJson(cj)
        doc.oauthAccount = prof.account
        writeJson(cj, doc, 0o644)
      } catch (e) {
        console.log(`${warn} could not patch oauthAccount in ${cj}: ${e.message}`)
      }
    }
  }
  console.log(`${ok} switched to ${bold(name)} — ${accountLabel(prof)}`)
  console.log(`  ${fmtExpiry(prof.claudeAiOauth.expiresAt)}`)
}

// cycle to the next saved profile (wrapping around); `swap <name>` still targets a specific one
async function cmdSwap(name, opts) {
  if (name) return cmdUse(name, opts)
  const names = listProfileNames()
  if (names.length < 2) die(`need at least 2 profiles to cycle through (have ${names.length})`)
  const active = activeProfileName()
  const idx = active ? names.indexOf(active) : -1
  const nextName = names[(idx + 1) % names.length]
  console.log(dim(`swap: ${active || '(unknown)'} → ${nextName}`))
  return cmdUse(nextName, opts)
}

function cmdList() {
  const names = listProfileNames()
  if (!names.length) {
    console.log(dim(`no profiles yet in ${PROFILES_DIR}`))
    console.log(dim('save the current login with:  claude-creds save <name>'))
    return
  }
  const active = activeProfileName()
  console.log(bold(`profiles ${dim(`(${PROFILES_DIR})`)}`))
  for (const name of names) {
    const prof = loadProfile(name)
    const mark = name === active ? green('● active') : dim('  ')
    const o = prof.claudeAiOauth || {}
    console.log(`${mark} ${bold(name.padEnd(16))} ${accountLabel(prof)}  ${fmtExpiry(o.expiresAt)}`)
  }
}

function cmdCurrent() {
  const active = activeProfileName()
  const acct = liveAccount()
  const live = loadLiveCreds()
  if (!live) return console.log(dim('no live credentials'))
  const email = (acct && acct.emailAddress) || dim('unknown')
  const o = live.claudeAiOauth || {}
  console.log(`active profile: ${active ? bold(active) : yellow('(unsaved / unknown)')}`)
  console.log(`account:        ${email}${o.subscriptionType ? dim(` (${o.subscriptionType})`) : ''}`)
  console.log(`token:          ${fmtExpiry(o.expiresAt)}`)
  if (!active) console.log(dim('  tip: `claude-creds save <name>` to track the current login'))
}

async function refreshOne(prof) {
  const o = prof.claudeAiOauth || {}
  if (!o.refreshToken) throw new Error('no refreshToken in profile')
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'refresh_token',
      refresh_token: o.refreshToken,
      client_id: OAUTH_CLIENT_ID,
    }),
  })
  const text = await res.text()
  let body = {}
  try { body = JSON.parse(text) } catch {}
  if (!res.ok) {
    const msg = (body.error && (body.error.message || body.error)) || body.error_description || text
    throw new Error(`HTTP ${res.status}: ${typeof msg === 'string' ? msg : JSON.stringify(msg)}`)
  }
  const next = { ...o }
  next.accessToken = body.access_token || o.accessToken
  next.refreshToken = body.refresh_token || o.refreshToken
  if (body.expires_in) next.expiresAt = Date.now() + Number(body.expires_in) * 1000
  if (body.scope) next.scopes = String(body.scope).split(' ')
  return { ...prof, claudeAiOauth: next, refreshedAt: new Date().toISOString() }
}

// true when the token is expired or close enough to expiry that we should renew now
function needsRefresh(o) {
  if (!o || !o.expiresAt) return false
  return o.expiresAt - Date.now() <= REFRESH_SKEW_MS
}

// renew a profile's token if it's expired/near-expiry, persisting the result; returns the profile to apply
async function ensureFresh(name, prof) {
  const o = prof.claudeAiOauth || {}
  if (!needsRefresh(o)) return prof
  if (!o.refreshToken) {
    console.log(`  ${warn} token ${fmtExpiry(o.expiresAt)} but no refreshToken — using as-is`)
    return prof
  }
  process.stdout.write(`  token ${fmtExpiry(o.expiresAt)} — refreshing … `)
  try {
    const updated = await refreshOne(prof)
    backup(profilePath(name))
    writeJson(profilePath(name), updated)
    console.log(`${ok} ${fmtExpiry(updated.claudeAiOauth.expiresAt)}`)
    return updated
  } catch (e) {
    console.log(`${bad} ${red(e.message)}${dim(' — applying stale token, claude may still auto-refresh')}`)
    return prof
  }
}

async function cmdRefresh(name, opts) {
  const targets = opts.all ? listProfileNames() : (name ? [name] : [activeProfileName()].filter(Boolean))
  if (!targets.length) die('usage: claude-creds refresh <name> | --all   (or run on the active profile)')
  const active = activeProfileName()
  for (const t of targets) {
    process.stdout.write(`refreshing ${bold(t)} … `)
    try {
      const updated = await refreshOne(loadProfile(t))
      backup(profilePath(t))
      writeJson(profilePath(t), updated)
      // keep live in sync if this profile is the active one
      if (t === active) {
        const live = loadLiveCreds() || {}
        backup(CREDS_PATH)
        writeJson(CREDS_PATH, { ...live, claudeAiOauth: updated.claudeAiOauth })
      }
      console.log(`${ok} ${fmtExpiry(updated.claudeAiOauth.expiresAt)}${t === active ? dim(' (live updated)') : ''}`)
    } catch (e) {
      console.log(`${bad} ${red(e.message)}`)
    }
  }
}

function checkOne(name) {
  const prof = loadProfile(name)
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'cc-check-'))
  try {
    // give claude an isolated config dir containing only this profile's creds
    writeJson(path.join(tmp, '.credentials.json'), { claudeAiOauth: prof.claudeAiOauth })
    const r = runClaude(['auth', 'status', '--json'], { CLAUDE_CONFIG_DIR: tmp })
    if (r.status !== 0 || !r.stdout) {
      return { name, valid: false, detail: (r.stderr || r.stdout || `exit ${r.status}`).trim().split('\n')[0] }
    }
    let js = {}
    try { js = JSON.parse(r.stdout) } catch {}
    return { name, valid: !!js.loggedIn, sub: js.subscriptionType, detail: js.loggedIn ? 'loggedIn' : 'not logged in' }
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true })
  }
}

function cmdCheck(name, opts) {
  const targets = opts.all || !name ? listProfileNames() : [name]
  if (!targets.length) return console.log(dim('no profiles to check'))
  // verify claude is available once
  const probe = runClaude(['--version'])
  if (probe.status !== 0) die("`claude` CLI not found on PATH (set CLAUDE_BIN to its path)")
  const results = []
  for (const t of targets) {
    const prof = loadProfile(t)
    const r = checkOne(t)
    results.push(r)
    const sym = r.valid ? ok : bad
    const expiry = fmtExpiry(prof.claudeAiOauth && prof.claudeAiOauth.expiresAt)
    console.log(`${sym} ${bold(t.padEnd(16))} ${accountLabel(prof)}  ${expiry}  ${dim(r.detail)}`)
  }
  const badCount = results.filter((r) => !r.valid).length
  if (badCount) process.exitCode = 1
}

function cmdRemove(name) {
  if (!name) die('usage: claude-creds rm <name>')
  const p = profilePath(name)
  if (!fs.existsSync(p)) die(`no such profile: ${name}`)
  fs.rmSync(p)
  console.log(`${ok} removed ${bold(name)}`)
}

function usage() {
  console.log(`${bold('claude-creds')} — manage multiple Claude Code credential profiles

${bold('usage:')} claude-creds <command> [args]

  ${cyan('list')}, ls                 list saved profiles (● marks the active one)
  ${cyan('current')}, whoami          show the active profile / account
  ${cyan('save')} <name>              snapshot the current login into a profile
  ${cyan('use')} <name>, switch       switch the live login to a saved profile ${dim('(auto-refreshes if expiring)')}
      ${dim('--no-account')}           don't patch oauthAccount in .claude.json
  ${cyan('swap')} [name]              cycle to the next profile ${dim('(or switch to <name>)')}
  ${cyan('refresh')} [name] [--all]   renew token(s) via the refresh_token grant
  ${cyan('check')} [name] [--all]     test validity via \`claude auth status\`  (alias: ${cyan('-p')})
  ${cyan('rm')} <name>                delete a profile

${bold('paths')}
  live creds : ${dim(CREDS_PATH)}
  profiles   : ${dim(PROFILES_DIR)} ${dim('(keep out of git)')}
  env        : ${dim('CLAUDE_CONFIG_DIR, CLAUDE_CREDS_HOME, CLAUDE_BIN, NO_COLOR')}

${bold('new login')}  run ${cyan('claude setup-token')} (or ${cyan('claude auth login')}), then ${cyan('claude-creds save <name>')}.`)
}

// =====================================================================
// dispatch
// =====================================================================
const argv = process.argv.slice(2)
const positional = argv.filter((a) => !a.startsWith('-'))
const flags = new Set(argv.filter((a) => a.startsWith('-')))
const opts = { all: flags.has('--all') || flags.has('-a'), noAccount: flags.has('--no-account') }
// `-p` / `--ping` is a flag-shaped alias for `check`
const pingAlias = flags.has('-p') || flags.has('--ping')
const cmd = pingAlias ? 'check' : positional[0]
const arg1 = positional[pingAlias ? 0 : 1]

try {
  switch (cmd) {
    case 'list': case 'ls': cmdList(); break
    case 'current': case 'whoami': cmdCurrent(); break
    case 'save': cmdSave(arg1); break
    case 'use': case 'switch': await cmdUse(arg1, opts); break
    case 'swap': case 'cycle': case 'next': await cmdSwap(arg1, opts); break
    case 'refresh': case 'renew': await cmdRefresh(arg1, opts); break
    case 'check': case 'test': case 'validate': cmdCheck(arg1, opts); break
    case 'rm': case 'remove': case 'delete': cmdRemove(arg1); break
    case undefined: case 'help': case '--help': case '-h': usage(); break
    default:
      die(`unknown command: ${cmd}\nrun \`claude-creds help\``)
  }
} catch (e) {
  die(e.stack || e.message)
}
