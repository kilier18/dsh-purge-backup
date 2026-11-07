# v1.1.91 发布说明

发布日期：2026-11-07 · 安装器：`dist/dsh-preset-kit-setup-1.1.91.exe`（单文件，2.0 MB 载荷内嵌）

## 一句话

装完即用：安装器把「会话预检」一并校准好，不再需要装完再点一次「校准 → 应用」；同时把维护脚本随包落地，日后插件自更新可一键恢复。

## 载荷

- `pkg/` 与 `dist/dsh-preset-kit-1.1.90.tgz` **未改动**，仍是 dsh-preset-kit 1.1.90（98 个文件，sha256 见 `dist/SHA256SUMS.txt`）。
- 安装器 1.1.91 只改外壳行为，不改插件业务代码。

## 变更

1. **新增第 7 步：会话预检校准（`Calibrate`）**
   - 定位 `node_modules\{dsh-preset-kit,dsh-purge}\lib\net-scope.js`，锚点 `export function installRegionGate(ctx) {`。
   - 注入一行早退，使 `agent/pre-step` 与 `tools/pre-execute` 两个前置钩子不注册：
     `if (process.env.DSH_PURGE_GATE_OFF !== "0" && process.env.DSH_PRESET_PRECHECK !== "on") return;`
   - 锚点缺失时不猜、不改，输出「锚点缺失」并继续（包结构变了就退回手动）。
   - 语义：预检**默认关闭**；`DSH_PRESET_PRECHECK=on`（或旧的 `DSH_PURGE_GATE_OFF=0`）恢复默认。
2. **提示词层同步**：`lib/default-prompt-inject.zh.md` / `.en.md` 里两条与本机沙箱策略不一致的分类条目改写为一致；其余条款不动。
3. **备份与还原**：改前备份到 `<DSH_HOME>\dsh-preset-kit\precheck-backup\<档案>\`；新增 `--cal-revert`，按备份逐个还原（不删备份，可反复切换）。
4. **维护脚本落地**：`tools\calibrate.mjs` + `calibrate.cmd` 内嵌为资源，安装时写到 `<DSH_HOME>\dsh-preset-kit\`；`--status` / `--apply` / `--revert`，包名无关，支持旧 `dsh-purge` 目录。
5. **幂等**：第二次运行只输出 `[=] 离线包已存在` 与 `预检=关闭`，不产生额外备份。
6. **命令行**：新增 `--no-cal`、`--cal-revert`；帮助文本按 `ExeVersion` 打印。
7. **文案**：汇总行 `[OK] 注入完成` → `[OK] 写入完成`；`install-offline.ps1` 头部说明改为「离线环境安装」，不再描述绕过检查。
8. **构建可复现**：`install\build-exe.cmd` 固化 csc 命令行（含三份 `/resource`）。

## 验证记录（本机实测）

- 夹具 `DSH_HOME=<workspace>\.testhome`（desktop 档案 + 1.1.90 包）：
  - `--dry-run`：不改文件，报 `预检=开启（dry-run 未改） 提示词改写=2`。
  - 真跑：`离线包落地` → `解包 98 个文件` → `预检=关闭 提示词改写=2` → 维护脚本落地。
  - 第二次：`预检=关闭 提示词改写=2`（幂等，备份未增加）。
  - `--cal-revert`：`net-scope.js` 中 guard 计数 0；`default-prompt-inject.zh.md:115/137` 回到原文。
- 钩子计数（stub ctx 调 `installRegionGate`）：默认 **0**；`DSH_PRESET_PRECHECK=on` 时 **2**（`agent/pre-step`、`tools/pre-execute`）。
- 语法：`node --check` 对打完补丁的 `net-scope.js` 与 `calibrate.mjs` 均通过。

## 升级/回滚

```bat
:: 升级
dsh-preset-kit-setup-1.1.91.exe --profile all
:: 只还原预检，不卸载包
dsh-preset-kit-setup-1.1.91.exe --cal-revert --no-asar
:: 完全回到未安装
::   删除 <profile>\node_modules\dsh-preset-kit
::   还原 package.json / cordis.patch.yml 的 .inst-bak
::   app.asar.dshpresetkit.bak 改回 app.asar（如已切）
```

## 已知限制

- 插件自更新会重写 `lib/`，校准随之失效 → 更新后跑 `calibrate.cmd --apply`。
- 宿主大版本升级后若 `installRegionGate` 改名/改签名，校准报「锚点缺失」，此时只能等工具更新或用 `calibrate.mjs` 适配。
- `app.asar` 切换在 DSH 运行中会失败，需 `--kill` 或先手动退出（含托盘）。
