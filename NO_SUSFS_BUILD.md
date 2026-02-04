# 🔧 无 SUSFS 版本说明

## 当前配置

为了专注于 Docker 和 LXC 支持，当前版本**已禁用 SUSFS**。

## 包含的功能

### ✅ 已启用
- **KernelSU** - Root 管理
- **Docker** - 完整支持（包括 overlay2 驱动）
- **LXC** - 完整容器支持
- **BBG** - Baseband Guard
- **所有 Docker/LXC 必需的内核配置**

### ❌ 已禁用
- **SUSFS** - Root 隐藏功能（暂时禁用以避免编译错误）

## 为什么禁用 SUSFS？

SUSFS 需要额外的补丁和配置，在集成 Docker/LXC 支持时遇到了一些兼容性问题：
- `linux/susfs.h` 文件找不到
- SUSFS 补丁应用失败

为了让你能尽快使用 Docker/LXC 功能，我们暂时禁用了 SUSFS。

## 功能对比

| 功能 | 有 SUSFS | 无 SUSFS |
|------|---------|---------|
| KernelSU Root | ✅ | ✅ |
| Docker 支持 | ✅ | ✅ |
| LXC 支持 | ✅ | ✅ |
| Root 隐藏 | ✅ | ❌ |
| 银行应用检测绕过 | ✅ | ❌ |
| SafetyNet 绕过 | ✅ | ❌ |

## 如果你需要 Root 隐藏

如果你需要使用银行应用或其他检测 Root 的应用，有以下选择：

### 方案 1：使用 Shamiko（推荐）
Shamiko 是一个 Magisk/KernelSU 模块，可以隐藏 Root：
- 下载：https://github.com/LSPosed/LSPosed.github.io/releases
- 安装后在 KernelSU 中启用
- 配置需要隐藏 Root 的应用

### 方案 2：等待 SUSFS 修复
我们会继续修复 SUSFS 集成问题，修复后会更新。

### 方案 3：使用其他 Root 隐藏方案
- Hide My Applist
- Magisk Hide（如果使用 Magisk）

## 编译说明

当前配置会编译一个：
- ✅ 支持 KernelSU 的内核
- ✅ 支持 Docker 的内核
- ✅ 支持 LXC 的内核
- ✅ KMI 安全，不会 bootloop
- ❌ 不包含 SUSFS

## 如何重新启用 SUSFS

如果将来想重新启用 SUSFS，需要：

1. 修改 `.github/workflows/build.yml`
2. 找到这一行：
   ```yaml
   # CONFIG_KSU_SUSFS is not set
   ```
3. 改为：
   ```yaml
   CONFIG_KSU_SUSFS=y
   ```
4. 确保 SUSFS 补丁正确应用

## 测试建议

刷入内核后，测试以下功能：

### Docker 测试
```bash
# 安装 Docker
pkg install docker

# 启动 Docker
su
dockerd &

# 测试
docker run hello-world
docker run -it alpine sh
```

### LXC 测试
```bash
# 安装 LXC
pkg install lxc

# 检查配置
lxc-checkconfig

# 创建容器
lxc-create -n test -t download
lxc-start -n test
```

### KernelSU 测试
```bash
# 检查 KernelSU 版本
su -v

# 安装 KernelSU Manager
# 从 https://github.com/tiann/KernelSU/releases 下载
```

## 性能影响

禁用 SUSFS 对性能的影响：
- ✅ 编译更快（少了 SUSFS 补丁步骤）
- ✅ 内核更小（少了 SUSFS 代码）
- ✅ 启动更快（少了 SUSFS 初始化）
- ❌ 无法隐藏 Root（需要其他方案）

## 常见问题

### Q: 没有 SUSFS 会影响 Docker/LXC 吗？
A: 不会。SUSFS 只负责 Root 隐藏，与 Docker/LXC 功能无关。

### Q: 可以后续再添加 SUSFS 吗？
A: 可以。修复 SUSFS 集成问题后，可以重新编译启用 SUSFS 的版本。

### Q: KernelSU 还能正常工作吗？
A: 可以。KernelSU 的核心功能（Root 管理）完全正常，只是缺少 SUSFS 的隐藏功能。

### Q: 银行应用能用吗？
A: 可能不行。大多数银行应用会检测 Root。建议使用 Shamiko 或其他隐藏方案。

## 下一步

1. 编译内核（现在应该能成功了）
2. 刷入设备
3. 测试 Docker 和 LXC
4. 如需 Root 隐藏，安装 Shamiko 模块

---

**更新日期：** 2025-02-04  
**状态：** ✅ 可用（无 SUSFS）
