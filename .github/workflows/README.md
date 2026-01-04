# GitHub Actions 自动构建说明

本项目已配置 GitHub Actions 自动构建和发布流程。

## 自动构建触发条件

工作流会在以下情况下自动触发：

1. **推送到主分支** - 当代码推送到 `master` 或 `main` 分支时
2. **提交 Pull Request** - 当创建或更新 PR 时
3. **创建版本标签** - 当推送 `v*` 格式的标签时（例如：`v1.0.0`, `v2.1.3`）
4. **手动触发** - 在 GitHub Actions 页面手动运行工作流

## 构建流程

构建过程包括以下步骤：

1. **检出代码** - 克隆仓库和所有子模块
2. **设置 MSYS2 环境** - 安装 MinGW64 和必要的构建工具
3. **准备构建环境** - 运行 `prepare.sh` 下载 Lua 并创建符号链接
4. **编译项目** - 使用 `make` 编译所有组件
5. **运行测试** - 执行自动化测试验证构建
6. **打包发布** - 将所有必要文件打包成 zip 文件
7. **上传构建产物** - 将打包文件上传为构建产物（保留 30 天）
8. **创建 Release**（仅标签触发）- 自动创建 GitHub Release 并上传文件

## 获取构建产物

### 方式一：从 Releases 下载（推荐）

访问 [Releases 页面](https://github.com/cmcxn/skynet-mingw/releases) 下载已发布的版本。

要创建新的 Release：
```bash
git tag v1.0.0
git push origin v1.0.0
```

### 方式二：从 Actions 下载

1. 访问 [Actions 页面](https://github.com/cmcxn/skynet-mingw/actions)
2. 选择一个成功的工作流运行
3. 在页面底部的 "Artifacts" 部分下载 `skynet-mingw-windows.zip`

注意：Artifacts 会在 30 天后自动删除。

## 发布包内容

下载的 `skynet-mingw-windows.zip` 包含：

- `skynet.exe` - 主程序
- `platform.dll`, `lua54.dll`, `skynet.dll` - 必需的 DLL 文件
- `libgcc_s_seh-1.dll`, `libwinpthread-1.dll` - MinGW 运行时依赖
- `luaclib/`, `cservice/` - 编译后的模块
- `examples/`, `lualib/`, `service/`, `test/` - 示例和库文件
- `BUILD_INFO.txt` - 构建信息（提交哈希、日期等）

## 本地测试工作流

虽然不能在本地完全运行 GitHub Actions，但可以通过以下方式验证构建过程：

在 MSYS2 MinGW64 环境中：
```bash
# 准备环境
bash prepare.sh

# 构建
make

# 测试
./skynet.exe autotest/config

# 手动打包
mkdir release
cp -r luaclib cservice examples lualib service test platform.dll lua54.dll skynet.dll skynet.exe release/
cd release && zip -r ../skynet-mingw-windows.zip * && cd ..
```

## 故障排查

### 构建失败

1. 检查 [Actions 日志](https://github.com/cmcxn/skynet-mingw/actions) 查看详细错误信息
2. 确认子模块已正确更新
3. 检查 Makefile 和 prepare.sh 是否有语法错误

### 测试失败

如果自动化测试失败，工作流会停止且不会创建发布。检查测试日志找出失败原因。

### Release 未自动创建

确保：
1. 推送的是格式为 `v*` 的标签（如 `v1.0.0`）
2. 构建和测试都成功通过
3. 仓库设置中允许 Actions 创建 releases

## 工作流配置文件

工作流配置位于 `.github/workflows/build-windows.yml`。

如需修改：
- 构建环境：修改 `msystem` 和 `install` 部分
- 触发条件：修改 `on` 部分
- 构建步骤：修改 `steps` 部分
- 发布内容：修改 `Package release` 和 `Create Release` 步骤
