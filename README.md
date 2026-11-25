# Antigravity + Veee 免 TUN 代理配置方案（macOS & Windows）

> 不开启全局 TUN 虚拟网卡、不修改 Antigravity 安装包、不破坏官方应用签名，直接点击原版 **Antigravity** 图标即可通过 **Veee**（或任意本地 HTTP 代理型 VPN）稳定访问。

---

## 为什么开着 Veee 却连不上 Antigravity？

- **Veee 等系统代理型 VPN** 连接后会在本机开放一个本地 HTTP/HTTPS 代理端口（macOS & Windows 版 Veee 均默认 HTTP `127.0.0.1:15236`，SOCKS5 `127.0.0.1:15235`），并自动设置操作系统的“系统代理”，但**不会接管全局 TUN 虚拟网卡**。
- **Antigravity** 的后台核心进程（`language_server`）默认**不读取系统代理**，但会正常识别进程环境变量（`HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY`）。
- 图形化双击打开的桌面应用默认不会继承终端里的环境变量，因此只需将本地代理地址写入**系统级用户会话环境变量**（macOS 用 `launchctl setenv` + `LaunchAgent`，Windows 用用户级环境变量 + 广播刷新 + 可选开机静默同步），就能让原版 Antigravity 开机自动走 Veee。

---

## 目录结构

```text
antigravity-veee-proxy/
├── README.md
├── LICENSE
├── macos/
│   ├── detect-proxy.sh          # 自动探测当前系统代理端口并测试连通性
│   ├── install.sh               # 立即注入 launchctl 环境变量 + 创建开机自启 LaunchAgent
│   └── uninstall.sh             # 一键卸载 LaunchAgent 并清空代理环境变量
└── windows/
    ├── detect-proxy.ps1         # 自动读取 Windows 系统代理端口并测试连通性
    ├── install-autostart.ps1    # 方案 A 增强版（推荐）：写入环境变量 + 注册开机无黑框静默自检同步
    ├── auto-sync.ps1            # 开机自检脚本：自动识别 Veee 进程端口（防 Clash 误覆盖）并同步环境变量
    ├── run-hidden.vbs           # 静默启动封装：通过 wscript.exe 消除 PowerShell 开机闪窗
    ├── uninstall-autostart.ps1  # 一键移除开机自启项并清空用户级代理环境变量
    ├── install.ps1              # 方案 A 基础版：仅写入用户级永久环境变量（无需管理员）
    ├── launch-antigravity.ps1   # 方案 B：单应用隔离启动脚本（不改全局环境变量）
    └── uninstall.ps1            # 一键清除用户级代理环境变量
```

---

## 一、macOS 使用指南（已实机验证）

> 适用环境：macOS（Apple Silicon / Intel）+ Veee（默认本地 HTTP 端口 `127.0.0.1:15236`）或任意本地 HTTP 代理。

### 1. 先连接 Veee，再一键安装（推荐）

```bash
git clone https://github.com/THUdzy51/antigravity-veee-proxy.git
cd antigravity-veee-proxy

# 方式 A：自动探测当前已连接的 Veee 系统代理端口并安装开机自启
bash macos/install.sh

# 方式 B：手动指定端口（例如 Veee 未连接时，已知默认端口为 15236）
bash macos/install.sh --proxy http://127.0.0.1:15236
```

### 2. 重启 Antigravity 生效
1. 保持 **Veee** 已连接（无需再开 Clash / TUN）。
2. 按 `⌘ + Q` 完全退出 Antigravity，再直接点原版 **`Antigravity`** 图标打开即可。

### 3. 检测当前代理端口 / 一键卸载还原

```bash
# 查看当前系统代理端口并实测连通性
bash macos/detect-proxy.sh

# 一键彻底卸载（移除 LaunchAgent 并清除全部代理环境变量）
bash macos/uninstall.sh
```

### 实现机制说明
- 写入轻量级 `~/Library/LaunchAgents/com.user.veee-proxy-env.plist`，仅在开机登录时运行一次 `launchctl setenv` 后立即退出，**零后台常驻进程、零内存/CPU 占用**。
- 同时设置大小写 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` 和 `NO_PROXY="localhost,127.0.0.1,::1"`，避免影响本地回环通信。

---

## 二、Windows 使用指南（已实机验证）

> 适用环境：Windows 10/11 + Veee（Windows 版同样默认本地 HTTP 端口 `127.0.0.1:15236`，SOCKS5 `127.0.0.1:15235`）或任意本地 HTTP 代理。

Windows 上提供**三种模式**，按你的日常使用习惯选择即可：

| 方案 | 脚本 | 特点 | 适合场景 |
| :--- | :--- | :--- | :--- |
| **方案 A 增强版（最推荐）：永久环境变量 + 开机无黑框静默同步** | `windows\install-autostart.ps1` | 无需管理员权限；开机零闪窗自动自检，仅同步归属 `Veee` 进程的端口（防 Clash 等误覆盖），零后台常驻进程；直接点原版图标即用 | 希望开机自动就绪，只要开着 Veee 就能稳定用 Antigravity |
| **方案 A 基础版：仅用户级永久环境变量** | `windows\install.ps1` | 无需管理员权限；一次性写入用户级环境变量，不注册开机自启项 | 端口固定，不需要开机自检同步 |
| **方案 B：单应用隔离启动器** | `windows\launch-antigravity.ps1` | 不修改系统/用户全局环境变量，仅对本次启动的 Antigravity 注入代理并禁用 QUIC | 经常关闭 Veee，不想影响其他软件联网 |

### 前提：连接 Veee 并确认本地端口
打开 PowerShell，进入仓库目录：

```powershell
git clone https://github.com/THUdzy51/antigravity-veee-proxy.git
cd antigravity-veee-proxy

# 探测 Veee 当前写入 Windows 系统代理的本地端口并测试连通性
powershell -ExecutionPolicy Bypass -File .\windows\detect-proxy.ps1
```

### 方案 A 增强版（推荐）：开机无黑框静默自检 + 永久环境变量

```powershell
# 立即同步环境变量，并注册 HKCU 开机静默自启项（wscript.exe -> run-hidden.vbs -> auto-sync.ps1）
powershell -ExecutionPolicy Bypass -File .\windows\install-autostart.ps1

# 如需指定默认回退端口（默认 http://127.0.0.1:15236）
powershell -ExecutionPolicy Bypass -File .\windows\install-autostart.ps1 -DefaultProxy "http://127.0.0.1:15236"
```

**增强机制说明：**
- 通过 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\AntigravityVeeeProxy` 调用 `wscript.exe` 执行 `windows\run-hidden.vbs`，开机登录时**完全无黑框闪窗**，执行完即退出，**零常驻进程占用**。
- `windows\auto-sync.ps1` 会校验系统代理端口的监听进程名是否匹配 `Veee`：若 Veee 已连接且改过端口则自动同步；若同时装有 Clash Verge 等其他代理或开机时 Veee 尚未连接，则安全回退到 `http://127.0.0.1:15236`，避免端口被误覆盖。
- 每次同步会保留最近 20 条记录到 `windows\sync.log`（已被 `.gitignore` 忽略），方便排查。

**一键卸载还原（方案 A 增强版）：**
```powershell
powershell -ExecutionPolicy Bypass -File .\windows\uninstall-autostart.ps1
```

### 方案 A 基础版：一键写入用户级永久环境变量

```powershell
# 自动读取当前 Veee 系统代理端口并写入用户级环境变量
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1

# 或者手动指定端口（如探测到的是 15236 或 7890 等）
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1 -Proxy "http://127.0.0.1:15236"
```

安装完成后：
1. 完全退出 Antigravity（包括右下角托盘图标右键退出）。
2. 直接双击桌面/开始菜单里的原版 **Antigravity** 打开即可。

**一键卸载还原（方案 A 基础版）：**
```powershell
powershell -ExecutionPolicy Bypass -File .\windows\uninstall.ps1
```

### 方案 B：单应用隔离启动（不污染全局环境变量）

```powershell
# 自动读取当前 Veee 系统代理端口，仅给 Antigravity 注入代理并启动
powershell -ExecutionPolicy Bypass -File .\windows\launch-antigravity.ps1

# 或手动指定代理地址与 Antigravity.exe 路径
powershell -ExecutionPolicy Bypass -File .\windows\launch-antigravity.ps1 -Proxy "http://127.0.0.1:15236"
```

> 提示：你也可以为 `launch-antigravity.ps1` 创建一个桌面快捷方式，目标填写：
> `powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\你的路径\antigravity-veee-proxy\windows\launch-antigravity.ps1"`

---

## 常见问题（FAQ）

### 1. 如果我彻底关闭了 Veee，其他命令行工具连不上网怎么办？
- 因为环境变量指向本地代理端口（如 `127.0.0.1:15236`），当 Veee 处于**完全关闭**状态时，读取 `HTTP_PROXY` 的命令行工具会尝试连接已关闭的本地端口。
- **解决办法**：平时保持 Veee 运行即可；如果临时不用 VPN，执行对应平台的 `uninstall` 脚本即可一键恢复直连（Windows 也可直接选用不改全局环境的 **方案 B**）。

### 2. Veee 重启或更新后端口号变了怎么办？
- 若使用了 Windows **方案 A 增强版**（`install-autostart.ps1`），每次开机登录时 `auto-sync.ps1` 会自动检测 Veee 进程的新端口并同步，也可以手动再运行一次 `auto-sync.ps1`。
- 其他方案下，先连上 Veee，运行 `detect-proxy.sh`（macOS）或 `detect-proxy.ps1`（Windows）查看新端口，再重新跑一遍 `install` 脚本即可自动覆盖更新。

### 3. Windows 下某些版本 Antigravity 登录页或特定组件仍超时怎么办？
- 优先使用 **`windows\launch-antigravity.ps1`**（它除了环境变量外，还会显式传递 `--proxy-server` 和 `--disable-quic` 参数，解决 Electron/Chromium 走 UDP QUIC 绕过 HTTP 代理的问题）。
- 如果仍受限于个别无视环境变量的子进程，可考虑开源社区的独立启动器（如 [Local-Route-Launcher](https://github.com/oliver804/Local-Route-Launcher)）。

### 4. 安全与隐私说明
- 本仓库脚本全部为纯明文 Shell / PowerShell / VBScript，**零二进制、零第三方依赖、不修改任何应用安装包、不读取或上传任何账号与凭据**。
- 仅将你本机已运行的代理端口配置到系统环境变量中。

---

## License

[MIT](LICENSE)
