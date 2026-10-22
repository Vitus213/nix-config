#!/usr/bin/env python3
"""汇总本机 AI agent（Claude Code / Codex / omp）的活跃时长、token 与折算成本，
合并进 GitHub profile 仓库 `agent-usage` 分支的按主机历史，并渲染 README 卡片。

- Claude Code / Codex：token 与成本来自 ccusage（逐请求去重、按 LiteLLM 单价计算）。
- omp：会话里记录的 cost 依赖 models.yml 配置（多为 0 或非 USD），这里逐条 assistant
  消息按 LiteLLM 单价重新计价，并按单次请求的 prompt 大小应用长上下文分档价。
- 活跃时长：合并该 agent 全部会话事件时间戳，相邻事件间隔 <= 15 分钟计入（与 WakaTime 默认超时一致）。
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import glob
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path
from zoneinfo import ZoneInfo

AGENTS = {
    "claude": {"label": "Claude Code", "color": "#ff9e64"},
    "codex": {"label": "Codex", "color": "#7aa2f7"},
    "omp": {"label": "omp", "color": "#9ece6a"},
}
IDLE_SECONDS = 15 * 60
LITELLM_URL = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"
# 同名模型有多个 provider 条目时优先第一方定价
PROVIDER_PREFERENCE = ["", "openai/", "anthropic/", "deepseek/", "gemini/", "dashscope/", "xai/", "moonshot/", "zai/"]
# 用户删除/清理会话后，旧日期的新统计可能偏小；超过这个天数的日期保留历史较大值
STABLE_AFTER_DAYS = 25
DATA_VERSION = 1

HOME = Path.home()


def log(msg: str) -> None:
    print(f"agent-usage: {msg}", file=sys.stderr)


# ---------------------------------------------------------------- 时间戳 / 活跃时长


def parse_ts(value) -> float | None:
    if isinstance(value, (int, float)):
        return value / 1000 if value > 1e11 else float(value)
    if isinstance(value, str):
        try:
            return dt.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
        except ValueError:
            return None
    return None


def iter_jsonl(paths):
    for path in paths:
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    if '"timestamp"' not in line:
                        continue
                    try:
                        yield json.loads(line)
                    except json.JSONDecodeError:
                        continue
        except OSError:
            continue


def active_seconds_by_day(timestamps, tz) -> dict[str, float]:
    days: dict[str, float] = {}
    prev = None
    for ts in sorted(set(timestamps)):
        if prev is not None:
            gap = ts - prev
            if 0 < gap <= IDLE_SECONDS:
                day = dt.datetime.fromtimestamp(ts, tz).date().isoformat()
                days[day] = days.get(day, 0.0) + gap
        prev = ts
    return days


def agent_session_files(agent: str, omp_dir: Path) -> list[str]:
    if agent == "claude":
        return glob.glob(str(HOME / ".claude/projects/**/*.jsonl"), recursive=True)
    if agent == "codex":
        return glob.glob(str(HOME / ".codex/sessions/**/*.jsonl"), recursive=True)
    return glob.glob(str(omp_dir / "**/*.jsonl"), recursive=True)


def collect_timestamps(agent: str, omp_dir: Path) -> list[float]:
    out = []
    for obj in iter_jsonl(agent_session_files(agent, omp_dir)):
        if not isinstance(obj, dict):
            continue
        # Claude 的元数据行（快照、标题等）不代表交互
        if agent == "claude" and obj.get("type") not in ("user", "assistant"):
            continue
        ts = parse_ts(obj.get("timestamp"))
        if ts:
            out.append(ts)
    return out


# ---------------------------------------------------------------- ccusage


def run_ccusage(ccusage: str, args: list[str]) -> dict:
    proc = subprocess.run([ccusage, *args], capture_output=True, text=True, timeout=600)
    if proc.returncode != 0:
        raise RuntimeError(f"ccusage {' '.join(args)} 失败: {proc.stderr.strip()[:400]}")
    return json.loads(proc.stdout)


def empty_bucket() -> dict:
    return {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0, "tokens": 0,
            "cost": 0.0, "unpriced_tokens": 0, "models": {}, "active_seconds": 0.0}


def collect_ccusage(ccusage: str, agent: str, tz: str) -> dict[str, dict]:
    if agent == "claude":
        data = run_ccusage(ccusage, ["claude", "daily", "--json", "--breakdown", "--mode", "calculate", "--timezone", tz])
    else:
        data = run_ccusage(ccusage, ["codex", "daily", "--json", "--timezone", tz])
    days: dict[str, dict] = {}
    for row in data.get("daily", []):
        day = row.get("date") or row.get("period")
        b = empty_bucket()
        b["input"] = int(row.get("inputTokens", 0))
        b["output"] = int(row.get("outputTokens", 0))
        b["cache_read"] = int(row.get("cacheReadTokens", 0))
        b["cache_write"] = int(row.get("cacheCreationTokens", 0))
        b["tokens"] = int(row.get("totalTokens", 0))
        b["cost"] = float(row.get("totalCost", row.get("costUSD", 0.0)) or 0.0)
        if agent == "claude":
            models = {m["modelName"]: m.get("inputTokens", 0) + m.get("outputTokens", 0)
                      + m.get("cacheCreationTokens", 0) + m.get("cacheReadTokens", 0)
                      for m in row.get("modelBreakdowns", [])}
            unpriced = [m for m in row.get("modelBreakdowns", []) if not m.get("cost")]
        else:
            models = {k: v.get("totalTokens", 0) for k, v in (row.get("models") or {}).items()}
            unpriced = [v for v in (row.get("models") or {}).values() if v.get("isFallback")]
        b["models"] = models
        b["unpriced_tokens"] = sum(m.get("totalTokens", 0) or (m.get("inputTokens", 0) + m.get("outputTokens", 0)
                                   + m.get("cacheCreationTokens", 0) + m.get("cacheReadTokens", 0)) for m in unpriced)
        days[day] = b
    return days


# ---------------------------------------------------------------- omp 逐请求计价


class Pricing:
    def __init__(self, cache_dir: Path):
        cache = cache_dir / "litellm-prices.json"
        data = None
        try:
            with urllib.request.urlopen(LITELLM_URL, timeout=30) as resp:
                raw = resp.read()
            data = json.loads(raw)
            cache_dir.mkdir(parents=True, exist_ok=True)
            cache.write_bytes(raw)
        except Exception as exc:  # 网络失败时退回上次缓存
            log(f"拉取 LiteLLM 价格失败（{exc}），使用缓存")
            if cache.exists():
                data = json.loads(cache.read_text())
        if data is None:
            raise RuntimeError("没有可用的 LiteLLM 价格表")
        self.data = data
        self.resolved: dict[str, str | None] = {}

    def lookup(self, model: str):
        if model in self.resolved:
            key = self.resolved[model]
            return key, (self.data[key] if key else None)
        names = [model.split("/")[-1]]
        stripped = re.sub(r"-(\d{4}|\d{8}|\d{4}-\d{2}-\d{2})$", "", names[0])
        if stripped != names[0]:
            names.append(stripped)
        key = None
        for name in names:
            for prefix in PROVIDER_PREFERENCE:
                cand = prefix + name
                if cand in self.data and "input_cost_per_token" in self.data[cand]:
                    key = cand
                    break
            if key:
                break
        self.resolved[model] = key
        return key, (self.data[key] if key else None)


def tiered(price: dict, field: str, prompt_tokens: int) -> float:
    base = price.get(field)
    best_threshold = 0
    for k, v in price.items():
        m = re.fullmatch(re.escape(field) + r"_above_(\d+)k_tokens", k)
        if m and prompt_tokens > int(m.group(1)) * 1000 and int(m.group(1)) > best_threshold:
            best_threshold, base = int(m.group(1)), v
    return float(base or 0.0)


def collect_omp(omp_dir: Path, pricing: Pricing, tz) -> tuple[dict[str, dict], dict[str, str | None]]:
    days: dict[str, dict] = {}
    seen = set()
    for obj in iter_jsonl(agent_session_files("omp", omp_dir)):
        if not isinstance(obj, dict) or obj.get("type") != "message":
            continue
        msg = obj.get("message") or {}
        usage = msg.get("usage") or {}
        if msg.get("role") != "assistant" or not usage:
            continue
        key = msg.get("responseId") or obj.get("id")
        if key in seen:
            continue
        seen.add(key)
        inp, out = int(usage.get("input", 0)), int(usage.get("output", 0))
        cr, cw = int(usage.get("cacheRead", 0)), int(usage.get("cacheWrite", 0))
        total = inp + out + cr + cw
        if total == 0:
            continue
        ts = parse_ts(msg.get("timestamp")) or parse_ts(obj.get("timestamp"))
        day = dt.datetime.fromtimestamp(ts, tz).date().isoformat()
        b = days.setdefault(day, empty_bucket())
        b["input"] += inp
        b["output"] += out
        b["cache_read"] += cr
        b["cache_write"] += cw
        b["tokens"] += total
        model = msg.get("model") or "unknown"
        b["models"][model] = b["models"].get(model, 0) + total
        _, price = pricing.lookup(model)
        if price is None:
            b["unpriced_tokens"] += total
            continue
        prompt = inp + cr + cw
        in_rate = tiered(price, "input_cost_per_token", prompt)
        cr_rate = tiered(price, "cache_read_input_token_cost", prompt) if "cache_read_input_token_cost" in price else in_rate
        cw_rate = tiered(price, "cache_creation_input_token_cost", prompt) if "cache_creation_input_token_cost" in price else in_rate
        b["cost"] += inp * in_rate + out * tiered(price, "output_cost_per_token", prompt) + cr * cr_rate + cw * cw_rate
    return days, dict(pricing.resolved)


# ---------------------------------------------------------------- 采集 / 合并


def collect(args) -> dict:
    tz = ZoneInfo(args.timezone)
    omp_dir = Path(args.omp_sessions).expanduser()
    fresh: dict[str, dict[str, dict]] = {}
    pricing_map = {}
    for agent in AGENTS:
        try:
            if agent == "omp":
                if not omp_dir.exists():
                    continue
                days, pricing_map = collect_omp(omp_dir, Pricing(Path(args.cache_dir).expanduser()), tz)
            else:
                days = collect_ccusage(args.ccusage, agent, args.timezone)
        except Exception as exc:
            # 某个 agent 失败时不写入它的新数据，历史保持不变
            log(f"{agent} 统计失败：{exc}")
            continue
        for day, secs in active_seconds_by_day(collect_timestamps(agent, omp_dir), tz).items():
            days.setdefault(day, empty_bucket())["active_seconds"] = round(secs, 1)
        for day, bucket in days.items():
            bucket["cost"] = round(bucket["cost"], 6)
            fresh.setdefault(day, {})[agent] = bucket
    return {"days": fresh, "omp_pricing": pricing_map}


def merge(stored: dict, fresh: dict, today: dt.date) -> dict:
    days = {d: dict(v) for d, v in (stored.get("days") or {}).items()}
    for day, agents in fresh["days"].items():
        old_day = days.setdefault(day, {})
        age = (today - dt.date.fromisoformat(day)).days
        for agent, bucket in agents.items():
            old = old_day.get(agent)
            if old and age > STABLE_AFTER_DAYS and bucket["tokens"] < old.get("tokens", 0):
                continue
            old_day[agent] = bucket
    return {"version": DATA_VERSION, "days": dict(sorted(days.items())), "omp_pricing": fresh.get("omp_pricing", {})}


# ---------------------------------------------------------------- 汇总 / 渲染


def aggregate(host_files: list[dict], today: dt.date) -> dict:
    per_day: dict[str, dict[str, dict]] = {}
    for host in host_files:
        for day, agents in host.get("days", {}).items():
            for agent, b in agents.items():
                acc = per_day.setdefault(day, {}).setdefault(agent, {"tokens": 0, "cost": 0.0, "unpriced_tokens": 0, "active_seconds": 0.0})
                for k in acc:
                    acc[k] += b.get(k, 0)

    def window(n: int | None):
        res = {a: {"tokens": 0, "cost": 0.0, "unpriced_tokens": 0, "active_seconds": 0.0} for a in AGENTS}
        for day, agents in per_day.items():
            if n is not None and (today - dt.date.fromisoformat(day)).days >= n:
                continue
            for agent, b in agents.items():
                for k in res[agent]:
                    res[agent][k] += b[k]
        return res

    series = []
    for i in range(29, -1, -1):
        day = (today - dt.timedelta(days=i)).isoformat()
        series.append({"date": day, **{a: per_day.get(day, {}).get(a, {"tokens": 0, "active_seconds": 0.0}) for a in AGENTS}})
    first = min(per_day) if per_day else today.isoformat()
    return {"d7": window(7), "d30": window(30), "all": window(None), "series": series, "since": first, "per_day": per_day}


def fmt_tokens(n: float) -> str:
    for unit, div in (("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if n >= div:
            return f"{n / div:.2f}{unit}" if n < 10 * div else f"{n / div:.1f}{unit}"
    return f"{int(n)}"


def fmt_cost(c: float) -> str:
    return f"${c:,.0f}" if c >= 1000 else f"${c:,.2f}"


def fmt_dur(s: float) -> str:
    m = int(round(s / 60))
    return f"{m // 60}h {m % 60:02d}m" if m >= 60 else f"{m}m"


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


COLORS = {"bg": "#1a1b27", "title": "#70a5fd", "text": "#a9b1d6", "muted": "#565f89", "strong": "#c0caf5", "grid": "#2a2e42"}


def render(agg: dict, with_quota: bool, updated: str) -> str:
    W = 810
    active_agents = [a for a in AGENTS if agg["all"][a]["tokens"] or agg["all"][a]["active_seconds"]] or list(AGENTS)
    if with_quota:
        cols = [("Agent", 30, "start"), ("Active 30d", 250, "end"), ("Tokens 30d", 360, "end"), ("Cost 30d", 470, "end"),
                ("Tokens total", 600, "end"), ("Cost total", 720, "end")]
    else:
        cols = [("Agent", 30, "start"), ("Active 7d", 330, "end"), ("Active 30d", 520, "end"), ("Active total", 720, "end")]
    row_h, top = 26, 78
    rows = active_agents + ["__total__"]
    chart_top = top + row_h * len(rows) + 18
    chart_h = 70
    H = chart_top + chart_h + 46
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="AI agent usage">',
           "<style>text{font-family:'Segoe UI',Ubuntu,'Helvetica Neue',Sans-Serif}"
           f".t{{font-size:18px;font-weight:600;fill:{COLORS['title']}}}.s{{font-size:12px;fill:{COLORS['muted']}}}"
           f".h{{font-size:12px;font-weight:600;fill:{COLORS['muted']}}}.c{{font-size:14px;fill:{COLORS['text']}}}"
           f".b{{font-size:14px;font-weight:600;fill:{COLORS['strong']}}}.f{{font-size:11px;fill:{COLORS['muted']}}}</style>",
           f'<rect width="{W}" height="{H}" rx="6" fill="{COLORS["bg"]}"/>',
           f'<text x="30" y="36" class="t">{"AI Agent Usage" if with_quota else "AI Agent Time"}</text>',
           f'<text x="{W - 30}" y="36" class="s" text-anchor="end">since {agg["since"]} · updated {esc(updated)}</text>']
    for name, x, anchor in cols:
        out.append(f'<text x="{x}" y="{top - 14}" class="h" text-anchor="{anchor}">{name}</text>')
    out.append(f'<line x1="30" x2="{W - 30}" y1="{top - 6}" y2="{top - 6}" stroke="{COLORS["grid"]}"/>')
    note = False
    for i, agent in enumerate(rows):
        y = top + 14 + i * row_h
        total = agent == "__total__"
        cls = "b" if total else "c"

        def val(win, key):
            if total:
                return sum(agg[win][a][key] for a in active_agents)
            return agg[win][agent][key]

        def cost(win):
            unpriced = val(win, "unpriced_tokens")
            nonlocal note
            note = note or unpriced > 0
            return fmt_cost(val(win, "cost")) + ("*" if unpriced else "")

        if total:
            out.append(f'<line x1="30" x2="{W - 30}" y1="{y - 18}" y2="{y - 18}" stroke="{COLORS["grid"]}"/>')
            out.append(f'<text x="30" y="{y}" class="b">Total</text>')
        else:
            out.append(f'<circle cx="36" cy="{y - 5}" r="5" fill="{AGENTS[agent]["color"]}"/>')
            out.append(f'<text x="50" y="{y}" class="c">{AGENTS[agent]["label"]}</text>')
        if with_quota:
            cells = [fmt_dur(val("d30", "active_seconds")), fmt_tokens(val("d30", "tokens")), cost("d30"),
                     fmt_tokens(val("all", "tokens")), cost("all")]
        else:
            cells = [fmt_dur(val("d7", "active_seconds")), fmt_dur(val("d30", "active_seconds")), fmt_dur(val("all", "active_seconds"))]
        for (name, x, anchor), text in zip(cols[1:], cells):
            out.append(f'<text x="{x}" y="{y}" class="{cls}" text-anchor="{anchor}">{text}</text>')
    # 近 30 天每日柱状图（有额度版本按 token，无额度版本按活跃时长），按 agent 堆叠
    metric = "tokens" if with_quota else "active_seconds"
    series = agg["series"]
    peak = max((sum(d[a][metric] for a in active_agents) for d in series), default=0) or 1
    x0, x1 = 30, W - 30
    bw = (x1 - x0) / len(series)
    out.append(f'<text x="30" y="{chart_top - 4}" class="h">Daily {"tokens" if with_quota else "active time"} · last 30 days</text>')
    base_y = chart_top + chart_h
    for i, d in enumerate(series):
        y = base_y
        for a in active_agents:
            h = d[a][metric] / peak * (chart_h - 10)
            if h <= 0:
                continue
            y -= h
            out.append(f'<rect x="{x0 + i * bw + 1.5:.1f}" y="{y:.1f}" width="{bw - 3:.1f}" height="{h:.1f}" rx="1.5" fill="{AGENTS[a]["color"]}"/>')
    out.append(f'<line x1="{x0}" x2="{x1}" y1="{base_y}" y2="{base_y}" stroke="{COLORS["grid"]}"/>')
    out.append(f'<text x="{x0}" y="{base_y + 14}" class="f">{series[0]["date"][5:]}</text>')
    out.append(f'<text x="{x1}" y="{base_y + 14}" class="f" text-anchor="end">{series[-1]["date"][5:]}</text>')
    peak_txt = fmt_tokens(peak) if with_quota else fmt_dur(peak)
    out.append(f'<text x="{x1}" y="{chart_top - 4}" class="f" text-anchor="end">peak {peak_txt}/day</text>')
    if with_quota:
        foot = "Cost = public API list price via ccusage / LiteLLM, not actual billing (subscriptions differ)."
        if note:
            foot += " * some tokens have no public price"
    else:
        foot = "Active time = merged agent session events with gaps ≤ 15 min."
    out.append(f'<text x="30" y="{H - 14}" class="f">{esc(foot)}</text>')
    out.append("</svg>")
    return "\n".join(out) + "\n"


def render_compact(agg: dict, with_quota: bool, updated: str) -> str:
    # 400x190：与 github-readme-stats top-langs（compact、card_width=400、8 种语言）同尺寸，README 里并排放
    W, H = 400, 190
    active_agents = [a for a in AGENTS if agg["all"][a]["tokens"] or agg["all"][a]["active_seconds"]] or list(AGENTS)
    if with_quota:
        cols = [("Active", 205, "end"), ("Tokens", 290, "end"), ("Cost", 375, "end")]
    else:
        cols = [("7d", 205, "end"), ("30d", 290, "end"), ("Total", 375, "end")]
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="AI agent usage">',
           "<style>text{font-family:'Segoe UI',Ubuntu,'Helvetica Neue',Sans-Serif}"
           f".t{{font-size:18px;font-weight:600;fill:{COLORS['title']}}}.s{{font-size:11px;fill:{COLORS['muted']}}}"
           f".h{{font-size:11px;font-weight:600;fill:{COLORS['muted']}}}.c{{font-size:13px;fill:{COLORS['text']}}}"
           f".b{{font-size:13px;font-weight:600;fill:{COLORS['strong']}}}.f{{font-size:10px;fill:{COLORS['muted']}}}</style>",
           f'<rect width="{W}" height="{H}" rx="4.5" fill="{COLORS["bg"]}"/>',
           f'<text x="25" y="35" class="t">{"AI Agent Usage" if with_quota else "AI Agent Time"}</text>',
           f'<text x="{W - 25}" y="35" class="s" text-anchor="end">{"last 30 days" if with_quota else "active time"}</text>']
    top = 62
    for name, x, anchor in cols:
        out.append(f'<text x="{x}" y="{top}" class="h" text-anchor="{anchor}">{name}</text>')
    rows = active_agents + ["__total__"]
    row_h = min(22, (H - 26 - top - 8) // len(rows))
    note = False
    for i, agent in enumerate(rows):
        y = top + 22 + i * row_h
        total = agent == "__total__"
        agents = active_agents if total else [agent]

        def val(win, key):
            return sum(agg[win][a][key] for a in agents)

        if total:
            out.append(f'<line x1="25" x2="{W - 25}" y1="{y - 15}" y2="{y - 15}" stroke="{COLORS["grid"]}"/>')
            out.append(f'<text x="25" y="{y}" class="b">Total</text>')
        else:
            out.append(f'<circle cx="30" cy="{y - 4.5}" r="4.5" fill="{AGENTS[agent]["color"]}"/>')
            out.append(f'<text x="42" y="{y}" class="c">{AGENTS[agent]["label"]}</text>')
        if with_quota:
            unpriced = val("d30", "unpriced_tokens")
            note = note or unpriced > 0
            cells = [fmt_dur(val("d30", "active_seconds")), fmt_tokens(val("d30", "tokens")),
                     fmt_cost(val("d30", "cost")) + ("*" if unpriced else "")]
        else:
            cells = [fmt_dur(val(w, "active_seconds")) for w in ("d7", "d30", "all")]
        for (_, x, anchor), text in zip(cols, cells):
            out.append(f'<text x="{x}" y="{y}" class="{"b" if total else "c"}" text-anchor="{anchor}">{text}</text>')
    foot = ("Cost = API list price, not billing" + (" · * partly unpriced" if note else "")) if with_quota else "gaps ≤ 15 min"
    out.append(f'<text x="25" y="{H - 12}" class="f">{esc(foot)}</text>')
    out.append(f'<text x="{W - 25}" y="{H - 12}" class="f" text-anchor="end">{esc(updated)}</text>')
    out.append("</svg>")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- git


def git(repo: Path, *args, auth: str | None = None, check=True) -> subprocess.CompletedProcess:
    cmd = ["git"]
    if auth:
        cmd += ["-c", f"http.https://github.com/.extraheader=AUTHORIZATION: basic {auth}"]
    cmd += ["-C", str(repo), *args]
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_AUTHOR_NAME="agent-usage", GIT_AUTHOR_EMAIL="agent-usage@localhost",
               GIT_COMMITTER_NAME="agent-usage", GIT_COMMITTER_EMAIL="agent-usage@localhost")
    return subprocess.run(cmd, capture_output=True, text=True, check=check, env=env)


def read_token(paths: list[str]) -> str | None:
    for p in paths:
        try:
            tok = Path(p).read_text().strip()
            if tok:
                return tok
        except OSError:
            continue
    return None


BRANCH_README = """# agent-usage

由 nix-config 的 `agent-usage-report`（home-manager 定时任务）自动生成，分支只保留一个提交。

- `data/<host>.json`：每台主机的每日统计历史（Claude Code / Codex / omp）
- `agent-usage-compact.svg` / `agent-usage.svg`：活跃时长 + token + 折算成本（有额度，400×190 / 810 宽）
- `agent-time-compact.svg` / `agent-time.svg`：仅活跃时长（无额度，400×190 / 810 宽）
- `summary.json`：汇总结果
"""


def write_outputs(target: Path, host_files: list[dict], today: dt.date, updated: str) -> dict:
    agg = aggregate(host_files, today)
    (target / "agent-usage.svg").write_text(render(agg, True, updated))
    (target / "agent-time.svg").write_text(render(agg, False, updated))
    (target / "agent-usage-compact.svg").write_text(render_compact(agg, True, updated))
    (target / "agent-time-compact.svg").write_text(render_compact(agg, False, updated))
    summary = {k: agg[k] for k in ("d7", "d30", "all", "since")}
    summary["updated"] = updated
    (target / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
    return summary


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--host", default="")
    p.add_argument("--ccusage", default="ccusage")
    p.add_argument("--timezone", default="Asia/Shanghai")
    p.add_argument("--omp-sessions", default="~/.omp/agent/sessions")
    p.add_argument("--repo", default="Vitus213/Vitus213")
    p.add_argument("--branch", default="agent-usage")
    p.add_argument("--state-dir", default="~/.local/state/agent-usage")
    p.add_argument("--cache-dir", default="~/.cache/agent-usage")
    p.add_argument("--token-file", action="append", default=[])
    p.add_argument("--render-only", metavar="DIR", help="只在本地目录渲染，不读写远端")
    args = p.parse_args()

    host = re.sub(r"[^A-Za-z0-9_-]", "-", args.host or socket.gethostname().split(".")[0])
    tz = ZoneInfo(args.timezone)
    now = dt.datetime.now(tz)
    today = now.date()
    updated = now.strftime("%Y-%m-%d %H:%M %Z")
    fresh = collect(args)
    if not fresh["days"]:
        log("本机没有任何 agent 数据，跳过")
        return 0

    if args.render_only:
        out = Path(args.render_only)
        out.mkdir(parents=True, exist_ok=True)
        data = merge({}, fresh, today)
        (out / f"{host}.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        print(json.dumps(write_outputs(out, [data], today, updated), indent=2, ensure_ascii=False))
        return 0

    token = read_token(args.token_file)
    if not token:
        log("找不到 GitHub token，跳过推送")
        return 1
    auth = base64.b64encode(f"x-access-token:{token}".encode()).decode()
    repo = Path(args.state_dir).expanduser() / "repo"
    if not (repo / ".git").exists():
        repo.mkdir(parents=True, exist_ok=True)
        git(repo, "init", "-q")
    git(repo, "remote", "remove", "origin", check=False)
    git(repo, "remote", "add", "origin", f"https://github.com/{args.repo}.git")

    for attempt in range(3):
        fetched = git(repo, "fetch", "-q", "--depth", "1", "origin", args.branch, auth=auth, check=False)
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            old_sha = ""
            if fetched.returncode == 0:
                old_sha = git(repo, "rev-parse", "FETCH_HEAD").stdout.strip()
                files = git(repo, "ls-tree", "-r", "--name-only", old_sha).stdout.split()
                for name in files:
                    dest = work / name
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(subprocess.run(["git", "-C", str(repo), "show", f"{old_sha}:{name}"],
                                                    capture_output=True, check=True).stdout)
            data_dir = work / "data"
            data_dir.mkdir(exist_ok=True)
            host_path = data_dir / f"{host}.json"
            stored = json.loads(host_path.read_text()) if host_path.exists() else {}
            host_path.write_text(json.dumps(merge(stored, fresh, today), indent=2, ensure_ascii=False) + "\n")
            host_files = [json.loads(f.read_text()) for f in sorted(data_dir.glob("*.json"))]
            write_outputs(work, host_files, today, updated)
            (work / "README.md").write_text(BRANCH_README)

            index = Path(tmp + ".index")
            env = dict(os.environ, GIT_INDEX_FILE=str(index))
            git_wt = ["git", f"--git-dir={repo / '.git'}", f"--work-tree={work}"]
            subprocess.run([*git_wt, "add", "-A", "."], env=env, check=True, cwd=work)
            tree = subprocess.run([*git_wt, "write-tree"], env=env, capture_output=True, text=True,
                                  check=True, cwd=work).stdout.strip()
            index.unlink(missing_ok=True)
            if old_sha and git(repo, "rev-parse", f"{old_sha}^{{tree}}").stdout.strip() == tree:
                log("数据无变化")
                return 0
            commit = git(repo, "commit-tree", tree, "-m", f"agent-usage: update {host} {updated}").stdout.strip()
            lease = f"--force-with-lease=refs/heads/{args.branch}:{old_sha}"
            pushed = git(repo, "push", "-q", lease, "origin", f"{commit}:refs/heads/{args.branch}", auth=auth, check=False)
            if pushed.returncode == 0:
                log(f"已推送 {args.repo}@{args.branch}（{host}）")
                return 0
            log(f"推送失败（第 {attempt + 1} 次）：{pushed.stderr.strip()[:300]}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
