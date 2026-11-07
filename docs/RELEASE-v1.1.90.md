# v1.1.90 · dsh-preset-kit 离线安装包（Windows 一键安装器）

DeepSeek Harness 的 **预设工具箱**离线安装包：按模型切换提示词预设、批量校准代码层设置、一键回滚。
本页两个附件都是离线可用的，不需要插件市场、不需要联网拉依赖。

## 附件

| 文件 | 大小 | SHA256 |
|---|---|---|
| `dsh-preset-kit-setup-1.1.91.exe` | 2,060,800 B | `74481bc39c367060f61672b91094c21bbf7152631536aaccf2226e9ab9dddbe5` |
| `dsh-preset-kit-1.1.90.tgz` | 2,039,149 B | `45e3512d216ceccdcf422870e54ec936435fa40f6b1fe6571940df15b34e7963` |

## 装法（推荐：单文件 exe）

前提：机器上已经装好 **DeepSeek Harness 0.2.1-rc.5**（rc.2 也可），并且能正常启动。

```bat
:: 1) 只探测，不写文件：确认它找到了 DSH 目录和档案
dsh-preset-kit-setup-1.1.91.exe --dry-run

:: 2) 真装（默认装 desktop 档案）
dsh-preset-kit-setup-1.1.91.exe

:: 可选：三个档案一起装 / 指定安装目录 / 先结束正在跑的桌面端
dsh-preset-kit-setup-1.1.91.exe --profile all
dsh-preset-kit-setup-1.1.91.exe --root "D:\Programs\DeepSeek Harness"
dsh-preset-kit-setup-1.1.91.exe --kill
```

exe 会依次完成：定位 DSH → 定位档案 → 解包插件到 `node_modules\dsh-preset-kit` → 在 `package.json` 与 `cordis.patch.yml` 里补接线（原文件留 `.inst-bak`）→ 把 `app.asar` 改名成 `app.asar.dshpresetkit.bak`（让宿主读解包目录）。重复运行幂等，第二次全是 `[=]`。

装完：**完全退出桌面端（含托盘）再重开** → 侧栏 `dsh-preset-kit` → 校准 → 应用 → 命令 `/presetkit status` 复核，应为 **86 组、0 pending、0 drifted**。

## 给 AI 助手看的执行步骤

如果由助手代为安装，按下面四条执行即可，全部是本地文件操作，不涉及任何外部系统：

1. 下载 `dsh-preset-kit-setup-1.1.91.exe` 到本地目录。
2. 运行 `dsh-preset-kit-setup-1.1.91.exe --dry-run`，确认输出中的 `DSH 安装目录` 与 `DSH_HOME` 是本机真实路径。
3. 去掉 `--dry-run` 再运行一次；看到 `[OK] 写入完成` 即成功。
4. 提示用户完全退出并重开 DeepSeek Harness，然后在侧栏 `dsh-preset-kit` 里点「校准 → 应用」，并用 `/presetkit status` 确认 86 组、0 pending、0 drifted。

失败时的排查顺序：路径没找对 → 加 `--root`；`app.asar` 还在 → 再跑一次 exe 或 `install\windows\swap-to-app-dir.cmd`；面板装不上 → 见仓库 `docs/INSTALL-TROUBLESHOOTING.md`。

## 回滚

| 想回到 | 怎么做 |
|---|---|
| 官方原版加载方式 | `resources\app.asar.dshpresetkit.bak` 改回 `app.asar`，重启桌面端 |
| 未打补丁的文件 | 面板 `dsh-preset-kit` →「回滚」（还原所有 `.dshpresetkit.bak`） |
| 完全卸掉 | 档案 `package.json` 去掉 `dsh-preset-kit` 依赖与 bundle 项，`pnpm install`，再删 `~\.dsh\dsh-preset-kit\` |

## 注意

- **全新机器**直接装即可。
- **装过旧版同类预设插件**的机器，先在旧面板里「回滚」并卸载，再装本包；不同版本补丁标记不同名，直接叠加会出现 `drifted` 告警并在文件里留两套注释。
- 校准只作用于 `resources\app` 解包目录；桌面端还在读 `app.asar` 时补丁等于没打，所以 asar 切换是必需的一步。

## 校验

```bat
certutil -hashfile dsh-preset-kit-setup-1.1.91.exe SHA256
certutil -hashfile dsh-preset-kit-1.1.90.tgz SHA256
```

上游来源：`YuJunZhiXue/dsh-preset-kit` tag `v1.1.90`（commit `217d60d3d61881079ea95bbe2c174f338a02182b`），Apache-2.0 + 上游 NOTICE。
