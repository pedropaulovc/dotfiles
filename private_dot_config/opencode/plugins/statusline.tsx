/** @jsxImportSource @opentui/solid */
import type { AssistantMessage } from "@opencode-ai/sdk/v2";
import type {
  TuiPlugin,
  TuiPluginApi,
  TuiPluginModule,
} from "@opencode-ai/plugin/tui";
import { useTerminalDimensions } from "@opentui/solid";
import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { promisify } from "node:util";
import {
  createEffect,
  createMemo,
  createSignal,
  onCleanup,
  Show,
} from "solid-js";

const execFileAsync = promisify(execFile);

type GitState = {
  ahead: number;
  behind: number;
  branch?: string;
  dirty: boolean;
  linked: boolean;
  original?: string;
  repository: boolean;
  tracking: boolean;
};

const emptyGit: GitState = {
  ahead: 0,
  behind: 0,
  dirty: false,
  linked: false,
  repository: false,
  tracking: false,
};

function numberOption(value: unknown, fallback: number, minimum: number) {
  if (typeof value !== "number") return fallback;
  if (!Number.isFinite(value)) return fallback;
  return Math.max(minimum, value);
}

function compactPath(value: string) {
  const normalized = value.replaceAll("\\", "/");
  const home = homedir().replaceAll("\\", "/").replace(/\/$/, "");
  const relative =
    normalized === home
      ? "~"
      : normalized.startsWith(home + "/")
        ? "~" + normalized.slice(home.length)
        : normalized;
  const parts = relative.split("/");
  if (parts.length < 3) return relative;

  return parts
    .map((part, index) => {
      if (!part || part === "~" || index === parts.length - 1) return part;
      if (part.startsWith(".")) return part.slice(0, 2);
      return part[0];
    })
    .join("/");
}

async function gitOutput(directory: string, args: string[]) {
  try {
    const result = await execFileAsync("git", ["-C", directory, ...args], {
      encoding: "utf8",
      maxBuffer: 1024 * 1024,
      timeout: 1500,
    });
    return result.stdout.trimEnd();
  } catch {
    return "";
  }
}

function parseWorktrees(output: string, directory: string) {
  const worktrees = output
    .split(/\n\n+/)
    .map((block) => {
      const lines = block.split("\n");
      const path = lines.find((line) => line.startsWith("worktree "))?.slice(9);
      const branch = lines
        .find((line) => line.startsWith("branch refs/heads/"))
        ?.slice(18);
      return path ? { path, branch } : undefined;
    })
    .filter((item): item is { path: string; branch?: string } => !!item);

  const normalized = directory.replaceAll("\\", "/").replace(/\/$/, "");
  const current = worktrees
    .filter(
      (item) =>
        normalized === item.path ||
        normalized.startsWith(item.path.replace(/\/$/, "") + "/"),
    )
    .sort((left, right) => right.path.length - left.path.length)[0];
  const primary = worktrees[0];
  const linked = !!current && !!primary && current.path !== primary.path;

  return {
    branch: current?.branch,
    linked,
    original: linked ? primary.branch : undefined,
  };
}

async function readGit(directory: string): Promise<GitState> {
  const [status, worktreeList] = await Promise.all([
    gitOutput(directory, ["status", "--short", "--branch"]),
    gitOutput(directory, ["worktree", "list", "--porcelain"]),
  ]);
  if (!status) return emptyGit;

  const [header = "", ...changes] = status.split("\n");
  const worktree = parseWorktrees(worktreeList, directory);
  const branch = worktree.branch ?? header.match(/^## ([^.\s]+)/)?.[1];

  return {
    ahead: Number(header.match(/ahead (\d+)/)?.[1] ?? 0),
    behind: Number(header.match(/behind (\d+)/)?.[1] ?? 0),
    branch,
    dirty: changes.length > 0,
    linked: worktree.linked,
    original: worktree.original,
    repository: true,
    tracking: header.includes("..."),
  };
}

function Separator(props: { api: TuiPluginApi }) {
  return <text fg={props.api.theme.current.textMuted}>·</text>;
}

function Statusline(props: {
  api: TuiPluginApi;
  compactThreshold: number;
  gitRefreshMs: number;
  sessionID: string;
}) {
  const dimensions = useTerminalDimensions();
  const [git, setGit] = createSignal<GitState>(emptyGit);
  const directory = createMemo(
    () =>
      props.api.state.session.get(props.sessionID)?.directory ??
      props.api.state.path.directory,
  );
  const messages = createMemo(() =>
    props.api.state.session.messages(props.sessionID),
  );
  const contextRemaining = createMemo(() => {
    const last = messages().findLast(
      (message): message is AssistantMessage =>
        message.role === "assistant" && message.tokens.output > 0,
    );
    if (!last) return;

    const model = props.api.state.provider.find(
      (provider) => provider.id === last.providerID,
    )?.models[last.modelID];
    if (!model?.limit.context) return;

    const used =
      last.tokens.input +
      last.tokens.output +
      last.tokens.reasoning +
      last.tokens.cache.read +
      last.tokens.cache.write;
    return Math.max(0, 100 - Math.round((used / model.limit.context) * 100));
  });

  let refreshID: ReturnType<typeof setInterval> | undefined;
  let generation = 0;
  const refresh = async () => {
    const current = ++generation;
    const value = await readGit(directory());
    if (current !== generation) return;
    setGit(value);
  };

  createEffect(() => {
    directory();
    void refresh();
    clearInterval(refreshID);
    refreshID = setInterval(() => void refresh(), props.gitRefreshMs);
  });
  onCleanup(() => {
    generation++;
    clearInterval(refreshID);
  });

  const showPath = createMemo(
    () => dimensions().width >= props.compactThreshold,
  );
  const showBranch = createMemo(
    () => dimensions().width >= props.compactThreshold + 25,
  );
  const showTracking = createMemo(
    () => dimensions().width >= props.compactThreshold + 50 && git().repository,
  );
  const showOriginal = createMemo(
    () => dimensions().width >= props.compactThreshold + 80 && !!git().original,
  );
  const theme = () => props.api.theme.current;

  return (
    <box flexDirection="row" flexShrink={0} gap={1}>
      <Show when={contextRemaining() !== undefined}>
        <text fg={theme().success}>Ur: {contextRemaining()}%</text>
      </Show>
      <Show when={showPath()}>
        <Separator api={props.api} />
        <text fg={theme().info}>{compactPath(directory())}</text>
      </Show>
      <Show when={showBranch() && git().branch}>
        <Separator api={props.api} />
        <text fg={git().dirty ? theme().warning : theme().secondary}>
          {git().linked ? "wt:" : ""}
          {git().branch}
          {git().dirty ? "*" : ""}
        </text>
      </Show>
      <Show when={showOriginal()}>
        <text fg={theme().info}>← {git().original}</text>
      </Show>
      <Show when={showTracking()}>
        <text fg={theme().info}>
          {git().tracking
            ? `${git().behind}↓ ${git().ahead}↑`
            : "custom worktree"}
        </text>
      </Show>
    </box>
  );
}

const tui: TuiPlugin = async (api, options) => {
  const compactThreshold = numberOption(options?.compactThreshold, 60, 20);
  const gitRefreshMs = numberOption(options?.gitRefreshMs, 5000, 1000);

  api.slots.register({
    order: 100,
    slots: {
      session_prompt_right(_context, props) {
        return (
          <Statusline
            api={api}
            compactThreshold={compactThreshold}
            gitRefreshMs={gitRefreshMs}
            sessionID={props.session_id}
          />
        );
      },
    },
  });
};

const plugin: TuiPluginModule & { id: string } = {
  id: "pedro.statusline",
  tui,
};

export default plugin;
