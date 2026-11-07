# 新电脑复原顺序（dsh-preset-kit 部分）

前提：DSH 已装好、能启动（目标是 **0.2.1-rc.5**，presetkit 1.1.90 的 `dshTargets` 里有 rc.2/rc.5）。
本仓库只讲 dsh-preset-kit 这条链，其余插件的清单与安装顺序不在本文范围内。

> **最快路径**：下载 release 里的 `dsh-preset-kit-setup-1.1.91.exe`，`--dry-run` 确认定位，再去掉 `--dry-run` 跑一遍 —— 第 1～3 节它全包了。下面各节是等价的手工/脚本流程，用于 exe 跑不动时排查。

---

## 0. 准备

```bat
:: 把本仓库放到固定位置，例如 D:\AI\dsh-preset-kit-backup
:: 确认存在：dist\dsh-preset-kit-1.1.90.tgz（2.0 MB）
```

需要一个 node 与 pnpm。新机器上 DSH 自带一份：

```
%LOCALAPPDATA%\Programs\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\
  node\bin\node.exe
  pnpm\bin\pnpm.cjs        <- 注意在 pnpm\bin\ 下，pnpm 根目录没有
```

`install-offline.ps1` 会自动按这个路径找，找不到才退回 PATH。PATH 里没有 node/pnpm 是正常现象。

---

## 1. 关掉桌面端

托盘图标也要退出。asar 被运行中的进程独占锁着，不退出后面改不动。

---

## 2. 装插件（离线 tarball）

```bat
install\install.cmd
:: 指定其它档案：install\install.cmd -Profile work
```

它做四件事：

1. `pnpm add file:<tgz> --ignore-scripts` —— 跳过 postinstall，避开 `ERR_PNPM_IGNORED_BUILDS`
2. 手跑 `node_modules/dsh-preset-kit/scripts/ensure-profile-bundle.mjs` —— 等价于 postinstall 的接线
3. `wire-profile.mjs` —— 幂等确保 `dependencies.dsh-preset-kit` / `dsh.profile.bundles` / `cordis.patch.yml` 的 `- id: dsh-preset-kit`
4. 打印装到的版本

手工版（想自己控制每一步）：

```bash
cd ~/.dsh/profiles/desktop
node "$LOCALAPPDATA/Programs/DeepSeek Harness/resources/runtime/primary-runtime/dependencies/pnpm/bin/pnpm.cjs" \
     add file:<REPO_DIR>/dist/dsh-preset-kit-1.1.90.tgz --ignore-scripts
node node_modules/dsh-preset-kit/scripts/ensure-profile-bundle.mjs
node <REPO_DIR>/install/wire-profile.mjs --profile desktop --spec file:<REPO_DIR>/dist/dsh-preset-kit-1.1.90.tgz
```

> `work` 档的 `node_modules` 是指向 desktop 的符号链接，桌面装好即共用；不用在 work 里再装一遍。

---

## 3. 启动 → 应用

1. 启动 DeepSeek Harness
2. 会话标题旁的 **dsh-preset-kit** → 面板
3. 先「校准」（revert 残留 .dshpresetkit.bak），再「应用」
4. 应用成功会写 `~/.dsh/dsh-preset-kit/applied.json`（`{"version":"1.1.90","sha":"apply:1.1.90",...}`）

**重启不会自动应用**：插件自带的 `node_modules/dsh-preset-kit/cordis.patch.yml` 里 `autoApplyOnStart: false`。

---

## 4. 切加载路径（关键，否则代码补丁白打）

```bat
install\windows\swap-to-app-dir.cmd
:: 装在非默认盘：install\windows\swap-to-app-dir.cmd "D:\Apps\DeepSeek Harness"
```

脚本会：杀进程 → `app.asar` 改名 `app.asar.dshpresetkit.bak` → 重启 → 20s 自检 → 起不来自动改名回滚。
期望日志（`%TEMP%\dsh-preset-kit-manual-swap.log`）：

```
renamed: app.asar -> app.asar.dshpresetkit.bak (rollback copy kept)
OK: desktop is running from resources\app
```

> 插件自己也会派一个 `%TEMP%\dsh-preset-kit-asar-swap-*.ps1`，本机（Defender ASR/策略）从 %TEMP% 起的 PowerShell 被拦、一条日志都没有。
> 所以用这个 cmd 兜底；`install/windows/dsh-preset-kit-swap-to-app-dir.ps1` 是同一逻辑的 ps1 版，路径已写死为本机，仅作参考。

---

## 5. 验收（缺一条都不算完成）

| 检查 | 期望 |
|---|---|
| 面板分组计数 | 68/70 applied、0 pending、**0 drifted** |
| `app.asar 还在` 告警 | **不存在** |
| 运行时 checkout | `...\resources\app\dsh\`（不是 `resources\app.asar\dsh\`） |
| 代码层证据 | `dsh-user-approval/lib/index.js`、`dsh-sandbox/lib/index.js`、`dsh-agent-loop/lib/index.js` 里有 `[dsh-preset-kit]` 标记 |
| 行为证据 | 审批策略从"自动拒绝"变"自动通过（policy=never）" |
| 版本 | `node -e "console.log(require('C:/Users/<你>/.dsh/profiles/desktop/node_modules/dsh-preset-kit/package.json').version)"` → `1.1.90` |

已知无害项：`shim 目录: 未定位`（`lib/core.js:1806 findShimDir()` 只在 PATH / npm prefix 找带 `dsh` 启动器的目录；官方安装的 node/pnpm 都在 runtime 里，所以找不到）。桌面端不走这条路径，可忽略。

---

## 6. 官方更新之后

DSH 官方更新会**重建 `resources\app.asar`**，桌面端回到封包加载，代码补丁再次失效（提示词层不受影响，它每轮实时注入）。

```bat
:: 更新完、桌面端退出后重跑一次
install\windows\swap-to-app-dir.cmd
```

补丁应用状态还在 `~/.dsh/dsh-preset-kit/applied.json`，一般不用重新点「应用」；如果面板显示 drifted 变多，再点一次「应用」。

---

## 7. 出问题时的最短排查链

1. `pnpm add` 报 `ERR_PNPM_IGNORED_BUILDS` → 漏了 `--ignore-scripts`；补上再手跑 ensure 脚本
2. 面板显示"未适配" → 宿主版本不在 `dshTargets` 里（见 `docs/INSTALL-TROUBLESHOOTING.md` 排查第 4 条）
3. 装好但面板打不开 / 无此插件 → `package.json` 的 `dsh.profile.bundles` 少了 `dsh-preset-kit`，或 `cordis.patch.yml` 没 insert 块
4. 应用成功但 checkout 仍是 `resources\app.asar\dsh` → 第 4 步没做，或被更新重建了 asar
5. `swap` 脚本报 `ABORT: app.asar still locked` → 进程没退干净（含托盘/后台），先手动 `taskkill /F /IM "DeepSeek Harness.exe"`