---
name: island-progress
description: Show live progress of long-running work (renders, exports, batch jobs, downloads, installs, training, any command over ~30 s) on the Mac notch island via the `island` CLI. Use whenever you start or wait on such work, without being asked.
---

# Agent Island — progress in the notch

The user has Agent Island installed: a pill around the MacBook notch that shows what is running, how far along it is and the time left. Use it for anything the user will wait on.

## Pick one

| Situation | Command |
|---|---|
| Wrap a command | `island run --title "Build" -- make -j8` |
| Output prints percentages | `cmd 2>&1 \| island pipe --title "Export" --regex '(\d+)%'` |
| Job writes N files | `island watch render --title "Render" --dir out --glob '*.png' --total 168` |
| Job logs "step n" | `island watch train --title "Training" --log train.log --regex 'step (\d+)' --total 5000` |
| One big file | `island watch dl --title "Download" --size model.bin --total 4200000000` |
| Can't measure | `island watch job --title "Indexing" --pid 12345` |
| You know the number | `island set job 37/120` … `island done job` |

- Several stages: register each, chain with `--after <previous id>`; queued stages show as "+N".
- Titles: short (≈12 characters), in the user's language, no paths.
- If you stop a job or it fails: `island done <id> --fail`.
- `watch` returns immediately and keeps a tiny background watcher; do not poll in a loop yourself.
- A hook already covers plain shell commands that run longer than 20 s ("still running"); register a measured job when you can do better.
