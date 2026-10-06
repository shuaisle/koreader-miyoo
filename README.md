# KOReader for Miyoo Mini (V4) — GitHub Actions 云编译移植包

在 GitHub 上用 Actions 云编译 KOReader 的 Miyoo Mini (Onion OS) 版本，无需本地安装任何编译环境（不需要 WSL2 / Docker）。

## 目录结构

```
miyoo-port/
├── .github/workflows/build-miyoo.yml   # GitHub Actions 云编译配置
├── build-miyoo.sh                      # 容器内执行：打补丁→编译→打包（勿改）
├── miyoo/
│   ├── device.lua                      # Miyoo 设备后端（fbdev 显示 + evdev 输入）
│   ├── event_map_miyoo.lua             # 按键映射（当前为占位，实机后校准）
│   └── powerd.lua                      # 最小电源管理（读 sysfs）
└── app/
    ├── config.json                     # Onion App 配置
    ├── launch.sh                       # Onion 启动入口
    └── icon.png                        # 应用图标
```

## 用户操作步骤（约 15 分钟操作 + 1~2 小时自动编译）

### 1. 准备 GitHub 仓库
1. 打开 https://github.com 登录（没有账号先注册）。
2. 右上角 `+` → **New repository**：
   - Repository name：`koreader-miyoo`（随意）
   - 公开 Private 均可（建议 Private 也行；公共仓库免费额度更足）
   - **不要**勾选 "Add a README / .gitignore / license"
   - 点 **Create repository**

### 2. 上传本移植包
1. 把本目录 `miyoo-port` **里面的全部内容**（`.github` 文件夹、`build-miyoo.sh`、`miyoo/`、`app/`）上传到仓库根目录：
   - 进入新仓库页面 → **Add file → Upload files**
   - 注意 `.github` 是隐藏文件夹：上传时直接拖入即可，GitHub 网页支持。
   - 拖入后点 **Commit changes**。

### 3. 触发云编译
1. 仓库页面上方点 **Actions** 标签。
2. 左侧选 **Build KOReader for Miyoo Mini**。
3. 右侧点 **Run workflow** → 绿色 **Run workflow** 按钮。
4. 任务开始运行（黄色圆点）。**预计 1~2 小时**（QEMU 模拟 ARM 较慢，正常现象）。

### 4. 下载编译产物
1. 任务完成后点进该次运行，展开 **Artifacts**。
2. 下载 **koreader-miyoo-onion** 压缩包（约 40~60 MB）。

### 5. 安装到 Miyoo Mini V4
1. 解压下载的压缩包，里面是 `Apps/KOReader/` 目录。
2. 把 `Apps` 目录整个拷到 SD 卡根目录（与 `Miyoo`、`Media` 等目录平级）。
3. 开机 → Onion 菜单 → **Apps** → 应能看到 **KOReader** 图标 → 启动测试。

### 6. 测试与反馈
启动后观察：
- 是否进入 KOReader 界面（中文/英文均可）
- 按键是否响应（方向键、A/B、翻页）
- 能否打开 EPUB/PDF/TXT

如果按键错乱或无效：把 Miyoo 的按键键码发给我（见下方「实机取证」），我更新 `event_map_miyoo.lua` 后你重新触发一次编译即可。

## 实机取证（可选，但强烈建议）

编译等待期间，可用 SSH 登录 Miyoo 收集参数，帮助首版一次成功：

1. Miyoo 上开启 SSH：**Apps → Tweaks → Network → SSH → Enable**（默认账号 `onion` / `onion`）。
2. 电脑连同一 WiFi，`ssh onion@<Miyoo的IP>`。
3. 依次执行并回传输出：

```sh
uname -a
cat /proc/bus/input/devices
ls -l /dev/input/
ls /lib/ld-linux* /lib/libc.so* 2>/dev/null; ldd --version 2>&1 | head -1
cat /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null
free -m
df -h /mnt/SDCARD | tail -1
```

关键确认点：
- **glibc 版本**（`ldd --version`）：需 ≥ 2.35，否则官方构建无法运行，需要换编译方案（编译时告知我）。
- **按键键码**：`cat /proc/bus/input/devices` 里 keypad 设备的 `EV=120013` 那行 `KEY=` 位图可推算支持的键码；更直接的办法是 `cat /dev/input/eventX | hexdump -C` 后逐个按键观察（每个事件 24 字节，第 3-4 字节是键码）。
- fb0 分辨率/位深、内存余量（128MB 跑 KOReader 是否吃力）。

## 技术说明（移植原理）

- **显示**：KOReader 自带 `ffi/framebuffer_linux.lua`，直接 mmap `/dev/fb0`（RGB565），LCD 无需 eink 刷新协议（KOReader 默认 refresh 即 no-op）。
- **输入**：官方 `libkoreader-input` evdev 模块（Kobo/Kindle 同款），纯 Lua 设备后端即可驱动。
- **编译**：官方 CI 的 linux-armhf 方式原样搬进 Actions：QEMU 模拟 arm/v7 + 官方 `koreader/koappimage` 镜像 native 编译。
- **补丁**（build-miyoo.sh 自动完成）：
  1. `koreader_targets.cmake`：允许 USE_SDL(linux) 目标也编译 `libkoreader-input`；
  2. `frontend/device.lua`：探测 `_miyoo` 平台标记 → 加载 `device/miyoo/device`；
  3. `git-rev` 改写为 `..._miyoo`，`koreader.sh` 去掉 `KO_MULTIUSER`（防止走桌面 SDL 分支）。
