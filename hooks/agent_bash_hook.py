#!/usr/bin/env python3
"""PreToolUse hook for the Bash tool (Claude Code settings.json and Codex hooks.json share this shape).

If a shell command is still running after 20 s it is put on the island as "still running" and removed
when it exits. Skipped when the agent registered its own (measured) job in the meantime.
Returns immediately; the waiting happens in a detached child."""
import glob, json, os, re, subprocess, sys, time

HOME = os.path.expanduser(os.environ.get("ISLAND_HOME") or "~/.island")
WAIT = float(os.environ.get("ISLAND_HOOK_DELAY") or 20)


def ps():
    rows = []
    for line in subprocess.run(["ps", "-axo", "pid=,ppid=,etime=,command="], capture_output=True, text=True).stdout.splitlines():
        m = re.match(r"\s*(\d+)\s+(\d+)\s+(\S+)\s+(.*)", line)
        if m:
            t = [int(x) for x in re.split("[-:]", m.group(3))]
            sec = t[-1] + 60 * (t[-2] if len(t) > 1 else 0) + 3600 * (t[-3] if len(t) > 2 else 0) + 86400 * (t[-4] if len(t) > 3 else 0)
            rows.append((int(m.group(1)), int(m.group(2)), sec, m.group(4)))
    return rows


def main():
    try:
        d = json.load(sys.stdin)
    except Exception:
        return
    ti = d.get("tool_input") or {}
    cmd = ti.get("command") or ""
    if isinstance(cmd, list):
        cmd = " ".join(map(str, cmd))
    if not cmd or re.search(r"(^|[\s/;&|(])island(\s|$)", cmd):
        return  # the command talks to the island itself
    title = (ti.get("description") or re.sub(r"\s+", " ", cmd).strip()).strip()[:16] or "Running"
    table = {p: pp for p, pp, _, _ in ps()}
    anc, p = [], os.getppid()          # hook → shell → agent: commands are siblings somewhere up here
    for _ in range(3):
        if p in table:
            anc.append(p); p = table[p]
    t0 = time.time()
    if os.fork():
        return
    os.setsid()
    if os.fork():
        os._exit(0)
    nul = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(nul, fd)
    time.sleep(WAIT)
    age = time.time() - t0
    snippet = re.sub(r"\s+", " ", cmd.strip().splitlines()[0])[:28]
    me = os.getpid()
    cands = [(sec, pid, c) for pid, pp, sec, c in ps() if pp in anc and pid != me and age - 6 <= sec <= age + 2 and "agent_bash_hook.py" not in c]
    if not cands:
        os._exit(0)                    # finished within the delay
    hit = [x for x in cands if snippet and snippet in re.sub(r"\s+", " ", x[2])] or cands
    pid = max(hit)[1]
    for f in glob.glob(os.path.join(HOME, "jobs", "*.json")):
        try:
            j = json.load(open(f))
            if not j["id"].startswith("auto-") and j["started"] >= t0 - 2:
                os._exit(0)            # the agent registered a real job for this
        except Exception:
            pass
    subprocess.run([os.path.join(HOME, "bin", "island"), "watch", f"auto-{pid}", "--title", title, "--pid", str(pid)])
    os._exit(0)


if __name__ == "__main__":
    main()
