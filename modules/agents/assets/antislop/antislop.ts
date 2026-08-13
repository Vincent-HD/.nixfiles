#!/usr/bin/env -S node --experimental-strip-types

let ANTISLOP_FILE = process.env.ANTISLOP_FILE || ".antislop.jsonl";
let ANTISLOP_DIR = ".antislop";
const AGENT = process.env.ANTISLOP_AGENT || process.env.OPENCODE_AGENT || process.env.CLAUDE_CODE_AGENT || "unknown";
const NOW = process.env.ANTISLOP_NOW ? new Date(process.env.ANTISLOP_NOW) : new Date();

function iso(): string {
  return NOW.toISOString();
}

function shortId(): string {
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  let id = "as_";
  for (let i = 0; i < 12; i++) id += chars[Math.floor(Math.random() * chars.length)];
  return id;
}

function readRecords(): any[] {
  try {
    const content = require("fs").readFileSync(ANTISLOP_FILE, "utf-8");
    return content.trim().split("\n").filter(Boolean).map((l: string) => {
      try { return JSON.parse(l); } catch { return null; }
    }).filter(Boolean);
  } catch {
    return [];
  }
}

function appendRecord(record: any): void {
  const fs = require("fs");
  const dir = require("path").dirname(ANTISLOP_FILE);
  if (dir !== ".") fs.mkdirSync(dir, { recursive: true });
  fs.appendFileSync(ANTISLOP_FILE, JSON.stringify(record) + "\n", "utf-8");
}

function terminalRuleIds(records: any[]): Set<string> {
  return new Set(
    records
      .filter((record: any) => record.kind === "resolve" || record.kind === "superseded")
      .map((record: any) => record.rule_id)
  );
}

function resolveId(prefix: string): string | null {
  const records = readRecords();
  const terminal = terminalRuleIds(records);
  const open = records.filter(
    (r: any) => r.kind === "rule" && !terminal.has(r.id)
  );
  const match = open.filter((r: any) => r.id.startsWith(prefix));
  if (match.length === 0) return null;
  if (match.length > 1) return null;
  return match[0].id;
}

function cmdAdd(text: string, tags: string[], severity: string, pattern: string | null, patternLang: string | null, prescription: string | null): void {
  const record: any = {
    kind: "rule",
    id: shortId(),
    ts: iso(),
    agent: AGENT,
    text,
    tags,
    severity,
  };
  if (pattern) record.pattern = pattern;
  if (patternLang) record.pattern_lang = patternLang;
  if (prescription) record.prescription = prescription;
  appendRecord(record);
  const out = { ok: true, data: { changed: true, record } };
  process.stdout.write(JSON.stringify(out) + "\n");
}

function cmdList(format: string, openOnly: boolean): void {
  const records = readRecords();
  const resolved = new Set(
    records.filter((r: any) => r.kind === "resolve").map((r: any) => r.rule_id)
  );
  const superseded = new Map(
    records
      .filter((r: any) => r.kind === "superseded")
      .map((r: any) => [r.rule_id, r.reason])
  );
  let rules = records.filter((r: any) => r.kind === "rule");
  if (openOnly) rules = rules.filter((r: any) => !resolved.has(r.id) && !superseded.has(r.id));
  rules.sort((a: any, b: any) => {
    const order = { blocker: 0, major: 1, minor: 2 };
    const sa = order[a.severity as keyof typeof order] ?? 2;
    const sb = order[b.severity as keyof typeof order] ?? 2;
    if (sa !== sb) return sa - sb;
    return b.ts.localeCompare(a.ts);
  });
  if (format === "md") {
    for (const r of rules) {
      const tags = r.tags?.length ? ` [${r.tags.join(", ")}]` : "";
      const reason = superseded.get(r.id);
      const status = resolved.has(r.id) ? "[x]" : reason ? "[~]" : "[ ]";
      const outcome = reason ? " **superseded**" : "";
      const detail = reason ? `\n  Reason: ${reason}` : "";
      const patternLine = r.pattern ? `\n  \`${r.pattern_lang || "ast-grep"}\`: \`${r.pattern}\`` : "";
      const rxLine = r.prescription ? `\n  \u2192 ${r.prescription}` : "";
      process.stdout.write(`${status} \`${r.id}\` **${r.severity}**${outcome}${tags} \u2014 ${r.ts}\n  ${r.text}${patternLine}${rxLine}${detail}\n\n`);
    }
  } else {
    const out = { ok: true, data: { rules, total: rules.length } };
    process.stdout.write(JSON.stringify(out) + "\n");
  }
}

function cmdResolve(prefix: string): void {
  const id = resolveId(prefix);
  if (!id) {
    const err = { ok: false, error: { code: "not_found", message: `No open anti-slop rule matches prefix "${prefix}"` } };
    process.stderr.write(JSON.stringify(err) + "\n");
    process.exit(66);
  }
  appendRecord({ kind: "resolve", id: shortId(), ts: iso(), rule_id: id });
  const out = { ok: true, data: { rule_id: id } };
  process.stdout.write(JSON.stringify(out) + "\n");
}

function cmdSupersede(prefix: string, reason: string): void {
  const id = resolveId(prefix);
  if (!id) {
    const err = { ok: false, error: { code: "not_found", message: `No open anti-slop rule matches prefix "${prefix}"` } };
    process.stderr.write(JSON.stringify(err) + "\n");
    process.exit(66);
  }
  appendRecord({ kind: "superseded", id: shortId(), ts: iso(), rule_id: id, reason });
  const out = { ok: true, data: { rule_id: id, reason } };
  process.stdout.write(JSON.stringify(out) + "\n");
}

function cmdClean(): void {
  const records = readRecords();
  const resolved = new Set(
    records.filter((r: any) => r.kind === "resolve").map((r: any) => r.rule_id)
  );
  const keep = records.filter(
    (r: any) => !(r.kind === "rule" && resolved.has(r.id)) && !(r.kind === "resolve" && resolved.has(r.rule_id))
  );
  const removed = records.length - keep.length;
  const fs = require("fs");
  fs.writeFileSync(ANTISLOP_FILE, keep.map((r: any) => JSON.stringify(r)).join("\n") + "\n", "utf-8");
  const out = { ok: true, data: { removed, remaining: keep.length } };
  process.stdout.write(JSON.stringify(out) + "\n");
}

function cmdApply(prefix: string, outDir: string | null): void {
  const records = readRecords();
  const terminal = terminalRuleIds(records);
  const open = records.filter(
    (r: any) => r.kind === "rule" && !terminal.has(r.id)
  );
  const match = open.filter((r: any) => r.id.startsWith(prefix));
  if (match.length === 0) {
    const err = { ok: false, error: { code: "not_found", message: `No open anti-slop rule matches prefix "${prefix}"` } };
    process.stderr.write(JSON.stringify(err) + "\n");
    process.exit(66);
  }
  if (match.length > 1) {
    const err = { ok: false, error: { code: "ambiguous", message: `Multiple rules match prefix "${prefix}"` } };
    process.stderr.write(JSON.stringify(err) + "\n");
    process.exit(66);
  }
  const rule = match[0];
  if (!rule.pattern) {
    const err = { ok: false, error: { code: "no_pattern", message: `Rule ${rule.id} has no pattern to apply` } };
    process.stderr.write(JSON.stringify(err) + "\n");
    process.exit(65);
  }
  const lang = rule.pattern_lang || "ast-grep";
  const dir = outDir || ANTISLOP_DIR;
  const fs = require("fs");
  const path = require("path");
  fs.mkdirSync(dir, { recursive: true });
  let filePath: string;
  let content: string;
  if (lang === "ast-grep") {
    filePath = path.join(dir, `${rule.id}.yml`);
    content = `id: ${rule.id}
message: ${rule.text}
severity: ${rule.severity === "blocker" ? "error" : rule.severity === "major" ? "warning" : "info"}
rule:
  pattern: ${rule.pattern}
`;
  } else if (lang === "oxlint") {
    filePath = path.join(dir, `${rule.id}.rs`);
    content = `// oxlint rule: ${rule.id}
// ${rule.text}
// severity: ${rule.severity}
// TODO: implement as oxlint rule or use ast-grep equivalent
`;
  } else if (lang === "grit") {
    filePath = path.join(dir, `${rule.id}.grit`);
    content = `// ${rule.id}: ${rule.text}
\`${rule.pattern}\` => . where {
  // TODO: add replacement
}
`;
  } else {
    const err = { ok: false, error: { code: "unsupported_lang", message: `Unsupported pattern language: ${lang}` } };
    process.stderr.write(JSON.stringify(err) + "\n");
    process.exit(65);
  }
  fs.writeFileSync(filePath, content, "utf-8");
  const out = { ok: true, data: { rule_id: rule.id, file: filePath, lang } };
  process.stdout.write(JSON.stringify(out) + "\n");
}

function cmdGenRule(pattern: string, lang: string, text: string | null): void {
  const record: any = {
    kind: "rule",
    id: shortId(),
    ts: iso(),
    agent: AGENT,
    text: text || "auto-generated from pattern",
    pattern,
    pattern_lang: lang,
    tags: ["auto"],
    severity: "minor",
  };
  appendRecord(record);
  const out = { ok: true, data: { changed: true, record } };
  process.stdout.write(JSON.stringify(out) + "\n");
}

function cmdSchema(): void {
  const schema = {
    contract: 2,
    commands: {
      add: { args: ["text"], options: ["--global", "--tag", "--severity", "--pattern", "--pattern-lang", "--prescription"], appends: true },
      list: { options: ["--global", "--format", "--all"], appends: false },
      resolve: { args: ["id"], options: ["--global"], appends: true },
      supersede: { args: ["id", "reason"], options: ["--global"], appends: true },
      apply: { args: ["id"], options: ["--global", "--out"], appends: false },
      "gen-rule": { args: ["pattern"], options: ["--global", "--lang", "--text"], appends: true },
      clean: { options: ["--global"], appends: true },
      schema: { appends: false },
    },
    env: { ANTISLOP_FILE: { default: ".antislop.jsonl" }, ANTISLOP_AGENT: {}, ANTISLOP_NOW: {} },
    record_shapes: {
      rule: { kind: "rule", id: "string", ts: "ISO8601", agent: "string", text: "string", tags: "string[]", severity: "minor|major|blocker", pattern: "string?", pattern_lang: "string?", prescription: "string?" },
      resolve: { kind: "resolve", id: "string", ts: "ISO8601", rule_id: "string" },
      superseded: { kind: "superseded", id: "string", ts: "ISO8601", rule_id: "string", reason: "string" },
    },
    exit_codes: { ok: 0, usage: 2, bad_input: 65, not_found: 66, internal: 70 },
  };
  process.stdout.write(JSON.stringify(schema, null, 2) + "\n");
}

const rawArgs = process.argv.slice(2);
const isGlobal = rawArgs.includes("--global");
const isHelp = rawArgs.includes("--help") || rawArgs.includes("-h");
const args = rawArgs.filter((a: string) => a !== "--global" && a !== "--help" && a !== "-h");
const cmd = args[0] || "help";

if (isGlobal && !process.env.ANTISLOP_FILE) {
  const path = require("path");
  const homedir = require("os").homedir();
  ANTISLOP_DIR = path.join(homedir, ".antislop");
  ANTISLOP_FILE = path.join(homedir, ".antislop.jsonl");
}

if (isHelp && cmd !== "help" && cmd !== "schema") {
  const helps: Record<string, string> = {
    add: "Usage: antislop add [--global] <text> [--tag <tag>] [--severity minor|major|blocker]",
    list: "Usage: antislop list [--global] [--format json|md] [--all]",
    resolve: "Usage: antislop resolve [--global] <id>",
    supersede: "Usage: antislop supersede [--global] <id> <reason>",
    apply: "Usage: antislop apply [--global] <id> [--out <dir>]",
    "gen-rule": "Usage: antislop gen-rule [--global] <pattern> [--lang ast-grep|oxlint|grit] [--text <description>]",
    clean: "Usage: antislop clean [--global]",
  };
  const usage = helps[cmd];
  if (usage) {
    process.stdout.write(usage + "\n");
    process.exit(0);
  }
}

switch (cmd) {
  case "add":
  case "log": {
    const textIdx = args.findIndex((a: string, i: number) => i > 0 && !a.startsWith("-"));
    const text = textIdx > 0 ? args[textIdx] : args[1];
    if (!text || text.startsWith("-")) {
      const err = { ok: false, error: { code: "bad_input", message: "Usage: antislop add <text> [--tag <tag>] [--severity minor|major|blocker]" } };
      process.stderr.write(JSON.stringify(err) + "\n");
      process.exit(65);
    }
    const tags: string[] = [];
    for (let i = 0; i < args.length; i++) {
      if (args[i] === "--tag" && args[i + 1]) {
        tags.push(args[i + 1]);
        i++;
      }
    }
    const sevIdx = args.indexOf("--severity");
    const severity = sevIdx >= 0 && args[sevIdx + 1] ? args[sevIdx + 1] : "minor";
    const patternIdx = args.indexOf("--pattern");
    const pattern = patternIdx >= 0 && args[patternIdx + 1] ? args[patternIdx + 1] : null;
    const plIdx = args.indexOf("--pattern-lang");
    const patternLang = plIdx >= 0 && args[plIdx + 1] ? args[plIdx + 1] : null;
    const rxIdx = args.indexOf("--prescription");
    const prescription = rxIdx >= 0 && args[rxIdx + 1] ? args[rxIdx + 1] : null;
    cmdAdd(text, tags, severity, pattern, patternLang, prescription);
    break;
  }
  case "list": {
    const formatIdx = args.indexOf("--format");
    const format = formatIdx >= 0 && args[formatIdx + 1] ? args[formatIdx + 1] : "json";
    const openOnly = !args.includes("--all");
    cmdList(format, openOnly);
    break;
  }
  case "resolve": {
    const id = args[1];
    if (!id) {
      const err = { ok: false, error: { code: "bad_input", message: "Usage: antislop resolve <id>" } };
      process.stderr.write(JSON.stringify(err) + "\n");
      process.exit(65);
    }
    cmdResolve(id);
    break;
  }
  case "supersede": {
    const id = args[1];
    const reason = args.slice(2).join(" ");
    if (!id || !reason) {
      const err = { ok: false, error: { code: "bad_input", message: "Usage: antislop supersede <id> <reason>" } };
      process.stderr.write(JSON.stringify(err) + "\n");
      process.exit(65);
    }
    cmdSupersede(id, reason);
    break;
  }
  case "apply": {
    const id = args[1];
    if (!id) {
      const err = { ok: false, error: { code: "bad_input", message: "Usage: antislop apply <id> [--out <dir>]" } };
      process.stderr.write(JSON.stringify(err) + "\n");
      process.exit(65);
    }
    const outIdx = args.indexOf("--out");
    const outDir = outIdx >= 0 && args[outIdx + 1] ? args[outIdx + 1] : null;
    cmdApply(id, outDir);
    break;
  }
  case "gen-rule": {
    const pattern = args[1];
    if (!pattern) {
      const err = { ok: false, error: { code: "bad_input", message: "Usage: antislop gen-rule <pattern> [--lang ast-grep|oxlint|grit]" } };
      process.stderr.write(JSON.stringify(err) + "\n");
      process.exit(65);
    }
    const langIdx = args.indexOf("--lang");
    const lang = langIdx >= 0 && args[langIdx + 1] ? args[langIdx + 1] : "ast-grep";
    const textIdx = args.indexOf("--text");
    const text = textIdx >= 0 && args[textIdx + 1] ? args[textIdx + 1] : null;
    cmdGenRule(pattern, lang, text);
    break;
  }
  case "clean": {
    cmdClean();
    break;
  }
  case "schema": {
    cmdSchema();
    break;
  }
  default: {
    process.stdout.write(`antislop \u2014 anti-pattern rule tracker

Usage:
  antislop add [--global] <text> [--tag <tag>] [--severity minor|major|blocker]
  antislop add [--global] <text> [--tag <tag>] [--severity minor|major|blocker]
              [--pattern <pattern>] [--pattern-lang lang] [--prescription <text>]
  antislop list [--global] [--format json|md] [--all]
  antislop resolve [--global] <id>
  antislop supersede [--global] <id> <reason>
  antislop apply [--global] <id> [--out <dir>]
  antislop gen-rule [--global] <pattern> [--lang ast-grep|oxlint|grit] [--text <description>]
  antislop clean [--global]
  antislop schema
  antislop help

Flags:
  --global        use ~/.antislop.jsonl and ~/.antislop/ instead of .antislop.jsonl and .antislop/

Env:
  ANTISLOP_FILE   \u2014 path to JSONL file (default: .antislop.jsonl, or ~/.antislop.jsonl with --global)
  ANTISLOP_AGENT  \u2014 agent name (auto-detected)
  ANTISLOP_NOW    \u2014 ISO timestamp override (for reproducible runs)
`);
    process.exit(cmd === "help" ? 0 : 2);
  }
}
