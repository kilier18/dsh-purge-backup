# DSH 面板装不上时的成因与解法（dsh-preset-kit）

先说清一件事：**本机（0.2.1-rc.5 + pnpm 11.28.5）我是通过 `pnpm add github:...#v1.1.90` 装上的，没有遇到"被拒"**。
所以下面不是猜的机制，是把 DSH 安装链路里**唯一几个真的会拦人的点**逐个挖出来，配可复现的验证命令，最后给一套"完全不经过安装器"的落地法。新机器上撞到哪条，走哪条的解法。

DSH 的安装入口只有一处实现：`resources/app/dsh/node_modules/@deepseek-ai/dsh-plugin-manager/lib/index.js`

- `parseInstallSpec()`（:73）决定**哪些 spec 形式合法**
- `classifyInstallFailure()`（:889）+ `LOG_KINDS`（:874）决定**失败怎么归类**
- profile 里 `allowBuilds`（:1099–:1149）决定**构建脚本放不放行**

---

## 限制点 1：构建脚本（最常见的"装不上"）

**症状**：面板报装失败；日志里 `ERR_PNPM_IGNORED_BUILDS`，或 `Ignored build scripts: dsh-preset-kit`。
**归类**：`LOG_KINDS[0] = ["build-blocked", /ERR_PNPM_IGNORED_BUILDS|Ignored build scripts/]`。
**原因**：`pkg/package.json` 里有 `"postinstall": "node scripts/ensure-profile-bundle.mjs"`。pnpm 11 默认不跑陌生包的构建脚本，直接判 ignored，`pnpm add` 非 0 退出，面板就显示安装失败。

**验证**：

```bash
cd ~/.dsh/profiles/desktop
pnpm add file:<REPO_DIR>/dist/dsh-preset-kit-1.1.90.tgz
# 看是否出现 ERR_PNPM_IGNORED_BUILDS
```

**解法 A（推荐，脚本已实现）**：不跑 postinstall，自己跑同一个文件。

```bash
pnpm add file:<REPO_DIR>/dist/dsh-preset-kit-1.1.90.tgz --ignore-scripts
node node_modules/dsh-preset-kit/scripts/ensure-profile-bundle.mjs
# 期望输出：already in bundles / insert already in cordis.patch.yml
```

**解法 B**：在 profile 的 `cordis.patch.yml` 里显式放行（DSH 自己就是这么存的，`allowBuilds` 是映射）：

```yaml
allowBuilds:
  dsh-preset-kit: true
```

> 别用 `pnpm --allow-build`：pnpm 11.28 里**没有**这个选项（`[ERROR] Unknown option: 'allow-build'`），那是 pnpm 10 的写法。

---

## 限制点 2：安装 spec 形式（`parseInstallSpec`）

只接受四类，别的一律 `invalid`：

| 形式 | 例子 | 说明 |
|---|---|---|
| registry | `dsh-preset-kit@1.1.90` | 会走 registry —— **别用**，npm 上那个 `dsh-preset-kit` 是第三方 Android 分支（maintainer `panda11445`），不是上游 |
| git | `github:YuJunZhiXue/dsh-preset-kit#v1.1.90` | 要网络 + 代理，ref 一旦被删就废 |
| tarball | `file:D:/.../dsh-preset-kit-1.1.90.tgz` | **本仓库首选**，离线、不可变 |
| 本地路径 | `file:<REPO_DIR>/pkg` | 目录直连，改代码立即生效（调试用） |

```js
// :95-102  非 tgz 的裸 URL 会被直接拒
if (/^https?:\/\//i.test(spec)) {
  if (TARBALL_SPEC.test(spec)) return { kind: "tarball", ... };
  throw invalid(spec, "a URL must point at a git repository or a tarball");
}
```

**所以**：`http://.../raw/main/package.json` 这种链接永远装不上；要 URL 就给 `.tgz`。

---

## 限制点 3：市场里根本搜不到

`dsh-plugin-market` / `dsh-plugin-market-index` 里没有任何 `blocklist` / `deny` 逻辑（grep 过，零命中）——
搜不到更可能只是**市场索引里本来就没有这个包**（它是 GitHub 上的个人项目，不是官方目录项）。
这不是"被禁"，是"不在货架上"，所以走市场 UI 必然卡住。

**解法**：跳出安装器，直接改 profile（等价于面板做的事，一共三处）：

```bash
# 1) 依赖
#    ~/.dsh/profiles/desktop/package.json
#    "dependencies": { "dsh-preset-kit": "file:<REPO_DIR>/dist/dsh-preset-kit-1.1.90.tgz" }
# 2) 启用
#    "dsh": { "profile": { "bundles": [ ..., "dsh-preset-kit" ] } }
# 3) 载入配置
#    ~/.dsh/profiles/desktop/cordis.patch.yml
#      insert:
#        - id: dsh-preset-kit
#          enabled: true
```

这三步 `install/wire-profile.mjs` 已经做成幂等脚本，手改怕写坏就跑它：

```bash
node install/wire-profile.mjs --profile desktop --spec "file:<REPO_DIR>/dist/dsh-preset-kit-1.1.90.tgz"
```

改完 `pnpm install`（或 `--ignore-scripts` + 手跑 ensure 脚本），重启桌面端。

---

## 限制点 4：版本不匹配（新机器上最容易被当成"拒绝安装"）

presetkit 会自检宿主的 `dshTargets`。1.1.90 里是 `["0.2.1-rc.2", "0.2.1-rc.5"]`：

```bash
node -e "const p=require('%USERPROFILE%/.dsh/profiles/desktop/node_modules/dsh-preset-kit/package.json');console.log(p.dsh)"
```

- 宿主是 **0.2.1-rc.5**（本机）→ 绿，不报未适配
- 宿主是别的版本（rc.6 / 0.3.x / 更老）→ 面板显示"未适配"，应用动作会被挡

**解法**：装 rc.5 原版；或者临时放宽 `dshTargets`（`pkg/package.json` 里那个数组加一行），
代价是补丁 pattern 可能对不上，应用后看 `0 drifted` 是否为真——对不上就别硬上，回退。

---

## 限制点 5：供应链 / lockfile 策略

`pnpm install` 打 `✓ Lockfile passes supply-chain policies` 时用的是一套 lockfile 策略。换 spec（`github:` → `file:`）会让 lockfile 与 `package.json` 不一致，可能报 `ERR_PNPM_OUTDATED_LOCKFILE`。

```bash
pnpm install --no-frozen-lockfile        # 让它重算
# 本机实测：lockfile 命中时输出 "✓ Lockfile passes supply-chain policies"
```

tarball 走的是本地文件，没有 registry 元数据可供校验，所以这类策略基本无对象可查。

---

## 终极兜底：连 pnpm 都不碰

pnpm 只是把包从 tgz 解到 `node_modules/dsh-preset-kit`。这一步手工做完全等价：

```bash
cd ~/.dsh/profiles/desktop
mkdir -p node_modules/dsh-preset-kit
tar -xzf <REPO_DIR>/dist/dsh-preset-kit-1.1.90.tgz -C node_modules/dsh-preset-kit --strip-components=1
node node_modules/dsh-preset-kit/scripts/ensure-profile-bundle.mjs     # 接线 bundles + patch yml
node -e "require('./package.json')"                               # 确认 json 没写坏
```

`node_modules` 是 pnpm 的目录，手放进去的包下次 `pnpm install` 会被清掉 —— 所以**同时**要把 `package.json` 的依赖写成 `file:` tgz（`wire-profile.mjs` 会做），这样重装也回得来。

> `work` 档注意：`~/.dsh/profiles/work/node_modules` 是指向 `profiles/desktop/node_modules` 的**符号链接**。
> 在 work 里删装任何包 = 同时动 desktop。要么只在 desktop 操作，要么先 `pnpm install` 复原。

---

## 装完之后：代码层还要过 asar 这一关

插件装好、面板「应用」成功，**仍然可能不生效**，因为 Electron 优先读 `resources\app.asar`：

```bash
curl -s localhost:64841 >/dev/null   # 仅确认桌面端在跑；判定看下面这条
# 面板/CLI 里出现 "app.asar 还在。补丁写在解开目录，当前进程读不到" = 没生效
```

`install/windows/swap-to-app-dir.cmd` 做的事：杀进程 → 把 `app.asar` 改名成 `app.asar.dshpresetkit.bak` → 重启 → 20 秒自检 → 起不来就自动改名回滚。
日志：`%TEMP%\dsh-preset-kit-manual-swap.log`。本机实测输出 `OK: desktop is running from resources\app`。

之后 `presetkit_status` 里 `app.asar 还在` 这条告警应当**消失**，drifted 归零。

---

## 一句总结

新机器上按顺序试：
`install.cmd`（= tgz + --ignore-scripts + 手跑 ensure + 幂等接线）→ 重启 → 面板校准/应用 → `swap-to-app-dir.cmd` → `/presetkit status` 验 0 drifted。
任何一步报错，照上面五道限制点里的验证命令定位，别重装第二遍。