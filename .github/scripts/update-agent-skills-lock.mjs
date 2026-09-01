#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import {
  mkdtempSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const defaultLockFile = join(
  repositoryRoot,
  "dot_agents",
  "dot_skill-lock.json",
);

function parseArguments(argumentsList) {
  let lockFile = defaultLockFile;
  let timestamp = new Date().toISOString();

  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--lock-file" || argument === "--now") {
      const value = argumentsList[index + 1];
      if (!value) {
        throw new Error(`${argument} requires a value.`);
      }
      if (argument === "--lock-file") {
        lockFile = resolve(value);
      } else {
        timestamp = value;
      }
      index += 1;
      continue;
    }
    if (argument === "--help" || argument === "-h") {
      console.log(
        "Usage: update-agent-skills-lock.mjs [--lock-file path] [--now timestamp]",
      );
      process.exit(0);
    }
    throw new Error(`Unknown argument: ${argument}`);
  }

  return { lockFile, timestamp };
}

function runGit(argumentsList, cwd) {
  try {
    return execFileSync("git", argumentsList, {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch (error) {
    const stderr = String(error.stderr || "").trim();
    const detail = stderr ? `: ${stderr}` : "";
    throw new Error(`git ${argumentsList.join(" ")} failed${detail}`);
  }
}

function getUpstreamHead(sourceUrl) {
  const output = runGit(["ls-remote", sourceUrl, "HEAD"], repositoryRoot);
  const head = output.split(/\s+/)[0] || "";
  if (!/^[0-9a-f]{40}$/i.test(head)) {
    throw new Error(`Could not resolve a commit for ${sourceUrl}.`);
  }
  return head.toLowerCase();
}

function getSkillFolder(skillPath) {
  if (skillPath === "SKILL.md") {
    return "";
  }
  if (!/\/SKILL\.md$/.test(skillPath)) {
    throw new Error(`Unsupported skill path: ${skillPath}`);
  }

  const folder = skillPath.slice(0, -9);
  if (!folder || folder.startsWith("/") || folder.split("/").includes("..")) {
    throw new Error(`Unsafe skill path: ${skillPath}`);
  }
  return folder;
}

function cloneAtCommit(sourceUrl, commit, repositories, temporaryRoot) {
  const key = `${sourceUrl}\0${commit}`;
  const existingRepository = repositories.get(key);
  if (existingRepository) {
    return existingRepository;
  }

  const repositoryDirectory = mkdtempSync(join(temporaryRoot, "repo-"));
  runGit(
    [
      "clone",
      "--filter=blob:none",
      "--no-checkout",
      "--",
      sourceUrl,
      repositoryDirectory,
    ],
    repositoryRoot,
  );
  runGit(["fetch", "--depth=1", "origin", commit], repositoryDirectory);
  runGit(["checkout", "--detach", commit], repositoryDirectory);

  const checkedOutCommit = runGit(["rev-parse", "HEAD"], repositoryDirectory);
  if (checkedOutCommit !== commit) {
    throw new Error(
      `Fetched commit mismatch for ${sourceUrl}: expected ${commit}, got ${checkedOutCommit}.`,
    );
  }

  repositories.set(key, repositoryDirectory);
  return repositoryDirectory;
}

function getSkillTreeHash(repositoryDirectory, commit, skillPath) {
  runGit(["cat-file", "-e", `${commit}:${skillPath}`], repositoryDirectory);
  const skillFolder = getSkillFolder(skillPath);
  const revisionPath = skillFolder
    ? `${commit}:${skillFolder}`
    : `${commit}^{tree}`;
  const hash = runGit(
    ["rev-parse", "--verify", "--end-of-options", revisionPath],
    repositoryDirectory,
  );
  if (!/^[0-9a-f]{40}$/i.test(hash)) {
    throw new Error(`Invalid tree hash for ${skillPath}: ${hash}`);
  }
  return hash.toLowerCase();
}

function writeLockFile(lockFile, contents) {
  const temporaryDirectory = mkdtempSync(
    join(dirname(lockFile), ".agent-skills-lock-"),
  );
  const temporaryFile = join(temporaryDirectory, "lock.json");

  try {
    writeFileSync(temporaryFile, contents);
    renameSync(temporaryFile, lockFile);
  } finally {
    rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

function main() {
  const { lockFile, timestamp } = parseArguments(process.argv.slice(2));
  const lockContents = readFileSync(lockFile, "utf8");
  const lock = JSON.parse(lockContents);
  if (!lock.skills || typeof lock.skills !== "object" || Array.isArray(lock.skills)) {
    throw new Error(`Invalid skill lock: ${lockFile}`);
  }

  const entries = Object.entries(lock.skills);
  if (entries.length === 0) {
    console.log("No managed agent skills found.");
    return;
  }

  const sourceHeads = new Map();
  for (const [name, entry] of entries) {
    if (!entry || typeof entry.sourceUrl !== "string" || !entry.sourceUrl) {
      throw new Error(`Skill ${name} has no sourceUrl.`);
    }
    if (typeof entry.skillPath !== "string" || !entry.skillPath) {
      throw new Error(`Skill ${name} has no skillPath.`);
    }
    if (!sourceHeads.has(entry.sourceUrl)) {
      sourceHeads.set(entry.sourceUrl, getUpstreamHead(entry.sourceUrl));
    }
  }

  const temporaryRoot = mkdtempSync(join(tmpdir(), "agent-skills-update-"));
  const repositories = new Map();
  const nextLock = JSON.parse(JSON.stringify(lock));
  const updates = [];

  try {
    for (const [sourceUrl, commit] of sourceHeads) {
      cloneAtCommit(sourceUrl, commit, repositories, temporaryRoot);
    }

    for (const [name, entry] of entries) {
      const commit = sourceHeads.get(entry.sourceUrl);
      const repositoryDirectory = repositories.get(`${entry.sourceUrl}\0${commit}`);
      const skillFolderHash = getSkillTreeHash(
        repositoryDirectory,
        commit,
        entry.skillPath,
      );
      if (
        entry.ref === commit &&
        entry.skillFolderHash === skillFolderHash
      ) {
        continue;
      }

      nextLock.skills[name] = {
        ...entry,
        ref: commit,
        skillFolderHash,
        updatedAt: timestamp,
      };
      updates.push({
        name,
        oldRef: entry.ref,
        newRef: commit,
        oldHash: entry.skillFolderHash,
        newHash: skillFolderHash,
      });
    }

    if (updates.length === 0) {
      console.log("All managed agent skills are current.");
      return;
    }

    const ending = lockContents.endsWith("\n") ? "\n" : "";
    writeLockFile(lockFile, `${JSON.stringify(nextLock, null, 2)}${ending}`);
    for (const update of updates) {
      console.log(`${update.name}: ${update.oldRef} -> ${update.newRef}`);
      if (update.oldHash !== update.newHash) {
        console.log(`  tree: ${update.oldHash} -> ${update.newHash}`);
      }
    }
  } finally {
    rmSync(temporaryRoot, { recursive: true, force: true });
  }
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
