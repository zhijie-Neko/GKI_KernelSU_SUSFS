# 🐛 编译调试指南

## 最新修复（2025-02-04）

### 问题
```
chmod: cannot access '/home/runner/work/.../kernel_patches/docker_lxc/apply_docker_lxc.sh': No such file or directory
```

### 原因
工作流缺少 `checkout` 步骤，导致仓库中的 `kernel_patches` 目录没有被复制到工作空间。

### 解决方案
已添加 `actions/checkout@v4` 步骤，并在 Setup Build Environment 中复制文件。

## 🔍 如何验证修复

### 1. 查看 Actions 日志

进入你的编译任务，查看 **Setup Build Environment** 步骤的输出，应该看到：

```bash
✓ Copied kernel_patches from repository
apply_docker_lxc.sh
cgroup_fix.patch
overlayfs_fix.patch
task_struct_kmi_fix.patch
✓ Copied scripts from repository
```

### 2. 查看 Apply Docker & LXC Support Patches 步骤

应该看到：

```bash
========================================
  Applying Docker & LXC Support
  按照用户提供的指南进行修改
========================================
Android Version: android14
Kernel Version: 6.1

[1/3] Applying cgroup fix patch (秋秋的补丁)...
✓ Cgroup patch applied successfully

[2/3] Applying overlayfs fix patch (Docker overlay2 驱动支持)...
✓ OverlayFS patch applied successfully

[3/3] Applying task_struct KMI-safe modifications...
使用 ANDROID_KABI_USE 和 _ANDROID_KABI_REPLACE 避免破坏 KMI
✓ Task_struct KMI-safe patch applied successfully
```

## 📋 完整的工作流程

### 步骤 1: Checkout Repository
```yaml
- name: Checkout Repository
  uses: actions/checkout@v4
  with:
    path: repo
```
**作用：** 将你的仓库代码 checkout 到 `repo` 目录

### 步骤 2: Setup Build Environment
```bash
# Copy kernel_patches from repository to workspace
if [ -d "repo/kernel_patches" ]; then
  cp -r repo/kernel_patches "$GITHUB_WORKSPACE/"
  echo "✓ Copied kernel_patches from repository"
fi
```
**作用：** 复制 `kernel_patches` 到工作空间

### 步骤 3: Clone AnyKernel3 and Other Dependencies
```bash
# Clone original kernel_patches for other patches
git clone https://github.com/WildKernels/kernel_patches.git kernel_patches_original

# Merge original patches with our Docker/LXC patches
for dir in kernel_patches_original/*/; do
  dirname=$(basename "$dir")
  if [ "$dirname" != "docker_lxc" ] && [ ! -d "kernel_patches/$dirname" ]; then
    cp -r "$dir" "kernel_patches/"
  fi
done
```
**作用：** 
- 克隆原始补丁到 `kernel_patches_original`
- 保留你的 `docker_lxc` 目录
- 合并其他需要的补丁（SUSFS 等）

### 步骤 4: Apply Docker & LXC Support Patches
```bash
chmod +x "$KERNEL_PATCHES/docker_lxc/apply_docker_lxc.sh"
"$KERNEL_PATCHES/docker_lxc/apply_docker_lxc.sh" "$KERNEL_ROOT" "$KERNEL_PATCHES" "android14" "6.1"
```
**作用：** 应用所有 Docker/LXC 补丁

## 🧪 测试编译

### 推荐配置
```yaml
Release Type: Actions        # 仅上传 Artifacts，不创建 Release
KernelSU Variant: WKSU       # Wild KernelSU
KSU Commit: [留空]           # 使用默认版本
Build Bypass: ✓ true         # 编译两个版本
```

### 预期结果

如果一切正常，编译应该：
1. ✅ 成功 checkout 仓库
2. ✅ 成功复制 kernel_patches
3. ✅ 成功应用所有补丁
4. ✅ 成功编译内核
5. ✅ 上传 AnyKernel3 ZIP 到 Artifacts

## 🚨 如果仍然失败

### 检查清单

1. **确认文件已推送到 GitHub**
   ```bash
   # 在本地检查
   git log --oneline -5
   
   # 应该看到：
   # 69b49aa Fix: Add checkout step to ensure kernel_patches directory is available
   # 81a7fd4 Fix: Use repository's own kernel_patches instead of cloning external one
   # 2a63b04 Fix: Add kernel_patches directory (was ignored by .gitignore)
   ```

2. **在 GitHub 网页上验证**
   - 打开：https://github.com/zhijie-Neko/GKI_KernelSU_SUSFS/tree/main/kernel_patches/docker_lxc
   - 应该看到 4 个文件：
     - apply_docker_lxc.sh
     - cgroup_fix.patch
     - overlayfs_fix.patch
     - task_struct_kmi_fix.patch

3. **检查 .gitignore**
   - 打开：https://github.com/zhijie-Neko/GKI_KernelSU_SUSFS/blob/main/.gitignore
   - 应该**不包含** `kernel_patches` 这一行

### 手动调试步骤

如果编译失败，在 Actions 日志中查找：

#### 错误 1: "No such file or directory"
```
chmod: cannot access '.../apply_docker_lxc.sh': No such file or directory
```
**原因：** checkout 步骤失败或文件未复制
**解决：** 检查 "Setup Build Environment" 步骤的输出

#### 错误 2: "patch: **** malformed patch"
```
patch: **** malformed patch at line X
```
**原因：** 补丁文件格式错误
**解决：** 检查补丁文件的换行符（应该是 LF，不是 CRLF）

#### 错误 3: "patch does not apply"
```
patch: **** patch does not apply
```
**原因：** 补丁与内核源码不匹配
**解决：** 这是正常的，脚本会继续执行

## 📊 成功的标志

### Artifacts 部分应该有：
- `6.1.118-android14-2025-01-Normal-WKSU-AnyKernel3.zip`
- `6.1.118-android14-2025-01-Bypass-WKSU-AnyKernel3.zip`

### 文件大小：
- 每个 ZIP 约 **30-50 MB**

### 编译时间：
- 总时间约 **30-60 分钟**

## 🎯 下一步

如果编译成功：
1. 下载 AnyKernel3 ZIP
2. 刷入到设备
3. 验证 Docker/LXC 支持
4. 享受！🎉

如果编译失败：
1. 复制完整的错误日志
2. 在 GitHub Issues 中报告
3. 包含以下信息：
   - 错误信息
   - 失败的步骤
   - Actions 运行链接

---

**最后更新：** 2025-02-04  
**状态：** ✅ 已修复，等待测试
