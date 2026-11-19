# Agent Island　靈動島進度

**把長時間工作的進度顯示在 Mac 瀏海兩側——給 Claude Code、Codex，以及任何在終端機裡跑的東西用。**

![示範](docs/demo.gif)

AI 代理幫你算圖、編譯、下載、跑測試的時候，你通常只能盯著終端機等。Agent Island 把這件事搬到瀏海上：現在在跑什麼、跑到哪、還要多久，還有一個倒掛在光條上跑步的火柴人，讓你一眼知道它還活著。

- **不擋路**：跟瀏海同高、滑鼠點得穿、不搶焦點，沒有工作時自己結束。
- **自動**：掛鉤會把任何跑超過 20 秒的指令自動掛上去，不靠代理記得。
- **有數字就給數字**：數檔案、讀紀錄檔、看檔案長大、從管線讀百分比。
- **不綁特定代理**：一支指令、每個工作一個 JSON 檔。

## 安裝

需要 macOS 14 以上、Swift 編譯器（`xcode-select --install`）、Python 3.8 以上。

```sh
git clone https://github.com/benrio0923/agent-island.git
cd agent-island && ./install.sh
island demo            # 看一遍所有狀態
island setup claude    # 接上 Claude Code
island setup codex     # 接上 Codex
```

全部裝在 `~/.island`，指令連到 `~/.local/bin/island`。`setup` 會先備份它要改的檔案，只新增自己的項目。

## 用法

```sh
island run --title "編譯" -- make -j8                                   # 包住一個指令
ffmpeg … 2>&1 | island pipe --title "轉檔" --regex '(\d+)%'              # 輸出裡有百分比
island watch render --title "算圖" --dir out --glob '*.png' --total 168  # 數檔案
island watch train --title "訓練" --log train.log --regex 'step (\d+)' --total 5000
island watch dl --title "下載" --size model.bin --total 4200000000       # 看檔案長大
island watch job --title "建索引" --pid 12345                            # 量不到，只顯示還在跑
island watch b --title "壓片" --log enc.log --regex '(\d+)%' --percent --after render   # 排隊
island set job 37/120 --title "搬資料"；island done job [--fail]         # 自己回報
```

不想用指令也可以直接寫 `~/.island/jobs/<id>.json`，格式見[英文說明](README.md#no-cli-write-a-file)。

## 設定

`ISLAND_LANG=zh|en`（完成／失敗的語言）、`ISLAND_EAR`（兩側寬度，預設 122）、`ISLAND_NO_RUNNER`（關掉火柴人）、`ISLAND_HOOK_DELAY`（掛鉤幾秒後才顯示，預設 20）、`ISLAND_HOME`（安裝位置）。

## 授權

MIT © Benrio 班里歐 / OOO.STUDIO。與 Apple、Anthropic、OpenAI 無關。
