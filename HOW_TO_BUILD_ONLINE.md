# 📱 如何在线编译内核（GitHub Actions）

## 🎯 超简单！5 步完成

### 第 1 步：进入 Actions 页面

1. 打开你的仓库：https://github.com/zhijie-Neko/GKI_KernelSU_SUSFS
2. 点击顶部的 **Actions** 标签

![Actions Tab](https://user-images.githubusercontent.com/placeholder/actions-tab.png)

### 第 2 步：选择工作流

在左侧列表中，选择：
- **Build Single Kernel (6.1.118)** - 编译单个内核版本

或者选择：
- **Build All Kernels** - 编译所有版本（需要更长时间）

### 第 3 步：运行工作流

1. 点击右侧的 **Run workflow** 按钮
2. 会弹出一个配置面板

### 第 4 步：配置选项

```
┌─────────────────────────────────────┐
│ Run workflow                        │
├─────────────────────────────────────┤
│ Use workflow from: main             │
│                                     │
│ Release Type:                       │
│ ▼ Actions                          │  ← 选择发布类型
│   - Actions (仅 Artifacts)         │
│   - Pre-Release (预发布)           │
│   - Release (正式发布)             │
│                                     │
│ KernelSU Variant:                   │
│ ▼ WKSU                             │  ← 选择 KSU 变体
│   - WKSU (推荐)                    │
│   - KSU                            │
│   - Next                           │
│   - RKSU                           │
│                                     │
│ KSU Commit:                         │
│ [留空使用默认]                      │  ← 可选，指定提交
│                                     │
│ Build Bypass:                       │
│ ☑ true                             │  ← 是否编译 Bypass 版本
│                                     │
│        [Run workflow]               │  ← 点击这里开始
└─────────────────────────────────────┘
```

**推荐配置：**
- Release Type: `Actions`（测试用）或 `Release`（正式发布）
- KernelSU Variant: `WKSU`
- KSU Commit: 留空
- Build Bypass: `true`（编译 Normal 和 Bypass 两个版本）

### 第 5 步：等待编译完成

1. 点击 **Run workflow** 后，会出现一个新的运行任务
2. 点击任务名称查看详细进度
3. 编译时间：约 **30-60 分钟**

```
✓ Setup Build Environment
✓ Clone AnyKernel3 and Other Dependencies
✓ Initialize and Sync Kernel Source
✓ Apply Docker & LXC Support Patches    ← 自动应用补丁
✓ Configure Kernel Options               ← 自动配置 Docker/LXC
✓ Build Kernel
✓ Prepare AnyKernel3 Zip
✓ Upload Artifacts
```

## 📦 下载编译产物

### 方法 1：从 Artifacts 下载（Actions 模式）

1. 编译完成后，滚动到页面底部
2. 找到 **Artifacts** 部分
3. 下载 `6.1.118-android14-2025-01-Normal-AnyKernel3.zip`
4. 如果启用了 Bypass，还会有 `...-Bypass-AnyKernel3.zip`

### 方法 2：从 Releases 下载（Release 模式）

1. 如果选择了 Release 模式，会自动创建 GitHub Release
2. 进入仓库的 **Releases** 页面
3. 下载最新的 Release 中的 ZIP 文件

## 🔧 刷入内核

### 使用 TWRP/Recovery

1. 下载 AnyKernel3 ZIP 文件到手机
2. 重启到 Recovery 模式
3. 选择 **Install** / **安装**
4. 找到并选择下载的 ZIP 文件
5. 滑动确认刷入
6. 刷入完成后，选择 **Reboot System** / **重启系统**

### 使用 KernelFlasher（需要 Root）

1. 安装 KernelFlasher 应用
2. 打开应用，选择下载的 ZIP 文件
3. 点击 Flash 刷入
4. 重启设备

## ✅ 验证安装

### 检查内核版本

```bash
# 使用 ADB
adb shell uname -r

# 或在 Termux 中
uname -r

# 应该显示类似：
# 6.1.118-android14-2025-01-Wild
```

### 检查 Docker/LXC 支持

```bash
# 推送检查脚本
adb push scripts/check_docker_lxc_support.sh /sdcard/

# 运行检查
adb shell su -c "sh /sdcard/check_docker_lxc_support.sh"

# 应该显示：
# ✅ All critical features are enabled!
```

### 测试 Docker

```bash
# 在 Termux 中安装 Docker
pkg install docker

# 启动 Docker
su
dockerd &

# 测试
docker run hello-world
```

## 🐛 常见问题

### Q: 编译失败了怎么办？

**A:** 检查 Actions 日志：
1. 点击失败的任务
2. 展开失败的步骤
3. 查看错误信息
4. 如果有 `.rej` 文件，会在 Artifacts 中上传

### Q: 找不到 Artifacts？

**A:** 确保：
1. 编译已完成（绿色 ✓）
2. 滚动到页面最底部
3. Artifacts 部分在日志下方

### Q: 刷入后无法开机？

**A:** 
1. 重启到 Recovery
2. 刷入之前的内核备份
3. 或刷入官方内核
4. 检查设备是否支持 GKI

### Q: Docker 无法启动？

**A:**
1. 检查内核配置：`zcat /proc/config.gz | grep CONFIG_OVERLAY_FS`
2. 检查 SELinux：`getenforce`（可能需要设置为 Permissive）
3. 查看 Docker 日志：`dockerd` 的输出

## 📊 编译选项说明

### Release Type

- **Actions**: 仅上传到 Artifacts，适合测试
- **Pre-Release**: 创建预发布版本，标记为 pre-release
- **Release**: 创建正式发布版本

### KernelSU Variant

- **WKSU**: Wild KernelSU（推荐，功能最全）
- **KSU**: 官方 KernelSU
- **Next**: KernelSU-Next
- **RKSU**: rsuntk 的 KernelSU

### Build Bypass

- **true**: 同时编译 Normal 和 Bypass 两个版本
- **false**: 仅编译 Normal 版本

**Bypass 版本说明：**
- 绕过模块版本检查
- 可以加载非官方编译的模块
- 适合开发和测试

## 🎉 成功！

如果一切顺利，你现在应该有一个：
- ✅ 支持 KernelSU 的内核
- ✅ 支持 SUSFS 的内核
- ✅ 支持 Docker 的内核
- ✅ 支持 LXC 的内核
- ✅ KMI 安全，不会 bootloop

## 📚 更多信息

- 📖 [快速入门指南](./DOCKER_LXC_QUICKSTART.md)
- 📖 [详细技术文档](./GKI_LXC_DOCKER_GUIDE.md)
- 📖 [更改日志](./CHANGES.md)
- 💬 [提交 Issue](https://github.com/zhijie-Neko/GKI_KernelSU_SUSFS/issues)

---

**提示：** 第一次编译建议选择 `Actions` 模式，测试成功后再使用 `Release` 模式。
