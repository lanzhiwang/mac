
-------------------------------------------------------------------------------------------

Q: 假设你是一位精通 mac 应用开发和使用的高级开发人员, mac 系统自带的 pkgutil 命令, 帮助文档如下:
```bash
$ pkgutil --help

Usage: pkgutil [OPTIONS] [COMMANDS] ...

Options:

  --only-files           List only files (not directories) in --files listing
  --only-dirs            List only directories (not files) in --files listing

  --verbose, -v          Show contextual information and format for easy reading

  --force, -f            Perform all operations without asking for confirmation

  --volume PATH          Perform all operations on the specified volume

  --edit-pkg PKGID       Adjust properties of package PKGID using --learn PATH

  --regexp               Try all PKGID arguments as regular expressions

  --help                 Show this usage guide

Receipt Database Commands:

  --pkgs, --packages     List all currently installed package IDs on --volume
  --pkgs-plist           List all package IDs on --volume in plist format
  --pkgs=REGEXP          List package IDs on --volume that match REGEXP

  --pkg-info PKGID       Show metadata about PKGID
  --pkg-info-plist PKGID Show metadata about PKGID in plist format

  --files PKGID          List files installed by the specified package
  --lsbom PKGID          List files in the same format as 'lsbom -s'

  --file-info PATH       Show metadata known about PATH
  --file-info-plist PATH Show metadata known about PATH in plist format

  --forget PKGID         Discard receipt data for the specified package

  --export-plist PKGID   Print all info about PKGID in plist format

  --learn PATH           Update --edit-pkg PKGID with actual metadata from PATH

  --groups               List all GROUPIDs on --volume
  --groups-plist         List all GROUPIDs on --volume in plist format
  --group-pkgs GROUPID   List all PKGIDs in GROUPID

  --pkg-groups PKGID     List all GROUPIDs that PKGID is a member of


File Commands:

  --expand PKG DIR       Expand the flat package PKG to DIR

  --flatten DIR PKG      Flatten the files at DIR as PKG

  --check-signature PATH Validate the signature of the pkg at PATH and print certificate information

  --payload-files PATH   List the paths archived within the (m)pkg at PATH

  --bom PATH             Extract any Bom files from the pkg at PATH into /tmp

$
```
请详细解释一下 pkgutil 命令的作用和使用场景, 以示例的方式说明使用方法和各个选项的含义

在 macOS 开发和系统架构中, `pkgutil` 是一个极其强大且底层的核心命令行工具. 作为一名 macOS 开发者或运维专家, 你可以把它理解为 macOS 的"包管理器与收据(Receipt)查询诊断器".

它主要处理 macOS 原生安装包(`.pkg` 和 `.mpkg`), 核心职能分为两大维度:

1. 系统收据管理(Receipt Database): 查询系统安装了哪些 pkg、这些 pkg 向系统写入了哪些文件、清理残留的安装记录.
2. 安装包解构与重构(Package File Operations): 无需实际安装即可拆解(Unpack)、修改、重新打包(Repack)`.pkg` 文件, 以及验证数字证书签名.

---

### 一、核心使用场景

1. "彻底干净"卸载软件(反向追踪文件):
   macOS 的 `.pkg` 安装包往往会把文件散落在 `/Library`、`/usr/local`、`/Applications`、`/Library/LaunchDaemons` 等各处. `pkgutil` 能准确告诉你某个 pkg 到底写入了哪些文件, 配合脚本可以实现真正的彻底卸载.

2. 审计与安全排查:
   排查某个系统路径下的二进制文件(如 `/usr/local/bin/node`)到底是哪个软件或安装包创建的; 在安装未知 pkg 之前, 检查其签名证书是否合法, 甚至解包检查其中的预安装/后安装脚本(`preinstall`/`postinstall`).

3. 企业分发与二次打包(Repackaging):
   逆向拆解厂商提供的 pkg, 修改里面的脚本、配置文件或 Payload, 再重新打成新的 pkg 分发给企业员工.

4. 清理损坏的升级记录:
   某软件因安装记录损坏导致无法覆盖升级或提示"已安装更高版本", 通过注销收据让系统"忘记"该安装.

---

### 二、实战命令分类与示例详解

#### 1. 收据数据库查询(Receipt Database Commands)

当安装器(Installer)运行完毕后, 会在系统数据库(`/var/db/receipts/`)中留下"收据".

##### ① 查找系统安装过的 Package ID (`--pkgs`, `--pkgs=REGEXP`)

macOS 用反向域名(Bundle ID 风格)来标识软件包, 例如 `com.apple.pkg.CLTools_Executables` 或 `org.nodejs.node.pkg`.

```bash
# 列出系统内所有的安装包 ID
pkgutil --pkgs

# 使用正则筛选 Node.js 或 Python 相关的安装包
pkgutil --pkgs='.*node.*'
pkgutil --pkgs='.*python.*'
```

##### ② 查看指定包的元信息 (`--pkg-info`)

获取版本号、安装时间、安装目标根目录(Install-location)等信息.

```bash
pkgutil --pkg-info org.nodejs.node.pkg
```

输出示例:

```bash
package-id: org.nodejs.node.pkg
version: v20.10.0
volume: /
location: usr/local
install-time: 1705000000
```

> 注意: `location` 是相对路径, 实际绝对路径为 `volume` + `location`(即 `/usr/local`).
>

##### ③ 列出包安装的所有文件 (`--files`, `--only-files`, `--only-dirs`)

这是彻底卸载软件的"神器".

```bash
# 列出该包释放的所有文件和目录
pkgutil --files org.nodejs.node.pkg

# 仅列出具体文件(排除目录), 常用于 rm 管道
pkgutil --only-files --files org.nodejs.node.pkg
```

##### ④ 反查: 这个文件是谁装进来的?  (`--file-info`)

如果你在系统目录发现了一个奇怪的文件, 想知道是谁留下的:

```bash
pkgutil --file-info /usr/local/bin/node
```

输出: 会显示该文件所属的 `pkg-id`、权限位、修改时间等信息.

##### ⑤ 让系统"遗忘"某个包 (`--forget`) ⚠️ 高危且重要

```bash
sudo pkgutil --forget org.nodejs.node.pkg
```

* 含义: 从 `/var/db/receipts` 中删除该安装包的收据记录.
* 开发者核心认知: `--forget` 不会删除磁盘上的任何实际文件! 它只是让系统以为"我从未装过这个东西".
* 标准彻底卸载流程示例:

```bash
PKGID="org.nodejs.node.pkg"

# 1. 切换到包安装的基准目录
cd /usr/local

# 2. 依次删除文件
pkgutil --only-files --files "$PKGID" | sudo xargs rm -f

# 3. 删除空目录(从深到浅)
pkgutil --only-dirs --files "$PKGID" | tail -r | sudo xargs -I {} rmdir "{}" 2>/dev/null

# 4. 从系统中注销收据
sudo pkgutil --forget "$PKGID"

```

---

#### 2. 安装包文件操作(File Commands)

这部分命令直接针对未安装的 `.pkg` 文件进行操作, 无需 Root 权限(解包时).

##### ① 展开/解包 Flat Package (`--expand`)

现代 macOS pkg 是类似 XAR 格式的容器. `--expand` 可以将 pkg 展开为普通目录, 暴露其内部结构.

```bash
pkgutil --expand MySoftware.pkg ./expanded_pkg
```

展开后的目录结构通常为:

* `Distribution` / `PackageInfo`: XML 格式的安装策略与配置
* `Scripts`: 存放 `preinstall`、`postinstall` 等 Shell 脚本(恶意代码或坑通常藏在这里)
* `Payload`: 真正的软件二进制归档(gzip 压缩的 cpio)
* `Bom`: 文件清单

##### ② 重新打包 (`--flatten`)

修改了展开目录里的文件后(例如修改了 `postinstall` 脚本中的逻辑), 将其重新打回 `.pkg`:

```bash
pkgutil --flatten ./expanded_pkg ./MySoftware_Patched.pkg
```

> 注意: 重新打包后, 原来的数字签名会失效, 如果你分发给他人, 需要重新用 `productsign` 签名.
>

##### ③ 验证签名与证书状态 (`--check-signature`)

在 macOS 上排查 Gatekeeper 拦截问题时, 用于确认安装包的签名链和时间戳.

```bash
pkgutil --check-signature Docker.pkg
```

输出示例:

```bash
Package "Docker.pkg":
   Status: signed by a developer certificate issued by Apple for code signing
   Signed with a trusted timestamp on: 2024-01-01 12:00:00 +0000
   Certificate Chain:
    1. Developer ID Installer: Docker Inc (9BNSXJN65R)
       SHA256 Fingerprint: ...
    2. Developer ID Certification Authority
    3. Apple Root CA
```

##### ④ 仅预览包内包含的文件 (`--payload-files`)

在不解压 Payload 的情况下, 快速查看该 pkg 会往系统写入哪些路径.

```bash
pkgutil --payload-files TargetInstaller.pkg
```

##### ⑤ 提取 BOM 文件 (`--bom`)

BOM(Bill of Materials)是二进制的文件清单. 该命令将 pkg 中的 BOM 文件直接提取到 `/tmp`, 随后你可以使用系统自带的 `lsbom` 命令去详细分析文件权限和哈希.

```bash
pkgutil --bom TargetInstaller.pkg
# 结合 lsbom 查看提取出来的清单
lsbom /tmp/TargetInstaller.pkg/*.bom
```

---

#### 3. 常见全局选项(Options)

* `--verbose`, `-v`: 详细输出模式. 调试脚本或排查错误时必带.

* `--force`, `-f`: 在执行类似 `--forget` 等命令时不进行确认提示, 常用于自动化 CI/CD 或卸载脚本中.

* `--volume PATH`: 指定目标卷(磁盘根目录). 例如你在恢复模式(Recovery)下或挂载了外接系统盘修复系统时:

```bash
pkgutil --volume /Volumes/MacintoshHD --pkgs
```

* `--export-plist PKGID` / `--pkg-info-plist`:
  直接输出标准的 Apple Plist (XML) 格式. 对于写自动化脚本(如 Python 结合 `plistlib`, 或 Swift 解析)非常有用, 不需要写正则去切分文本.

```bash
# 将包元信息输出为 plist 并转为 JSON 处理
pkgutil --pkg-info-plist org.nodejs.node.pkg | plutil -convert json -r - -o -
```

* `--edit-pkg PKGID` 与 `--learn PATH`:
  高级属性调整. 如果你在系统中手动更改了属于某个包的文件的权限或属性, 并希望系统收据数据库更新为当前的实际文件属性, 可以使用此组合命令(一般极少直接使用, 多数由系统补丁机制触发).

---

### 三、高级技巧与开发总结

1. 解压 Payload 内容:
   `pkgutil --expand` 只会解压出 `Payload` 文件本身, 但 `Payload` 还是一个 cpio 归档. 如果你想看安装包里最终释放的 App 文件, 配合以下命令链:

```bash
pkgutil --expand Example.pkg /tmp/expanded
cd /tmp/expanded
# 解压真正的应用 Payload
cat Payload | cpio -idmv
```

2. 区别认知:
   * 打包 App: 通常用 `pkgbuild` 或 `productbuild`.
   * 查看/拆解/维护包: 使用 `pkgutil`.

3. 企业 MDM 维护建议:
   在编写 Jamf Pro、Munki 或统一端点管理(UEM)的自动化安装/卸载脚本时, `pkgutil --pkg-info` 经常被作为检测应用是否已存在(App Detection Rule)的最佳低开销方案.

-------------------------------------------------------------------------------------------

Q: 我不小心使用 `pkgutil --forget` 让系统"遗忘"某个包, 事实是这个包并没有真的被卸载, 我应该如何恢复?

首先不用慌张, 这通常不是什么灾难性的事故.

### 一、先给你吃一颗定心丸(发生了什么?)

`pkgutil --forget <PKGID>` 做的事情非常单一且局部:

它仅仅是从 macOS 系统的收据目录(`/var/db/receipts/`)中删除了两个元数据文件:

1. `<PKGID>.plist`(记录包 ID、版本号、安装时间等信息)
2. `<PKGID>.bom`(记录该包写入的所有文件清单与权限)

它没有触动你的任何二进制文件、配置文件、动态库、或应用本身. 你的软件目前依然在正常运行.

如果你什么都不做, 唯一的"后遗症"是:

* 你无法再通过 `pkgutil --files <PKGID>` 查到它当初写入了哪些文件.
* 某些依赖收据检测版本的管理工具(如企业 MDM、Munki、Homebrew Cask 或某些自带的检查更新程序)可能会认为"该软件未安装", 导致检测状态不一致.

---

### 二、如何恢复? 三种解决方案

针对不同的场景, 你可以选择以下任一方案恢复收据:

#### 方案一: 最干净、官方推荐的方式 -- 直接用原 `.pkg` 覆盖安装

适用场景: 你手头还有当时的 `.pkg` 安装包, 或者能去官网重新下载一个相同版本的安装包.

macOS 的安装器(Installer)具有天然的幂等性(Idempotent), 覆盖安装不会删掉你原有的用户配置(如个人数据通常在 `~` 目录下, 而 pkg 一般装在 `/Library` 或 `/usr/local`).

1. 找到/下载对应的安装包(例如 `Node.js`、`Python`、某个驱动等).

2. 在终端直接静默安装, 让系统重新生成收据:

```bash
sudo installer -pkg /path/to/YourSoftware.pkg -target /
```

3. 验证收据是否找回:

```bash
pkgutil --pkg-info <PKGID>
```

这是最稳妥的办法, 它不仅会重新生成 `/var/db/receipts/<PKGID>.plist` 和 `.bom`, 还会帮你顺便校验文件权限.

---

#### 方案二: 从 Time Machine 或 APFS 本地快照还原

适用场景: 你开启了 Time Machine 备份, 或者系统自动创建了 APFS 本地快照.

既然 `--forget` 只是删除了 `/var/db/receipts/` 下的两个文件, 直接把文件拉回来即可:

1. 打开 Finder, 按 `Cmd + Shift + G`, 输入路径:

```bash
/var/db/receipts/
```

2. 进入 Time Machine, 找到你执行 `pkgutil --forget` 之前的时间点.

3. 找到并恢复对应的两个文件:
   * `<你的PKGID>.bom`
   * `<你的PKGID>.plist`

4. 恢复完成后无需重启, 执行 `pkgutil --pkgs | grep <你的PKGID>` 即可确认生效.

---

#### 方案三: 高级极客方案 -- 手动提取 BOM 并重建模拟收据

适用场景: 你有 `.pkg` 文件, 但不想重新执行一遍安装(比如包里面带有烦人的 `preinstall`/`postinstall` 脚本、重启提示, 或者该软件已经运行在生产环境中不能被打断).

你可以利用 `pkgutil` 自身的功能, 手动把收据塞回系统数据库:

##### 步骤 1: 从安装包中提取 BOM 文件

```bash
# 这一步会把 pkg 里的 bom 解压到 /tmp 下
pkgutil --bom /path/to/YourSoftware.pkg
```

提取完成后, 你会在 `/tmp/` 目录下看到解出的 `.bom` 文件(名字可能形如 `PackageName.pkg/Bom`).

##### 步骤 2: 将 BOM 文件放回收据目录

```bash
sudo cp /tmp/YourSoftware.pkg/Bom /var/db/receipts/<PKGID>.bom
sudo chmod 644 /var/db/receipts/<PKGID>.bom
sudo chown root:wheel /var/db/receipts/<PKGID>.bom
```

##### 步骤 3: 伪造并生成对应的 `.plist` 文件

在 `/var/db/receipts/<PKGID>.plist` 创建元数据信息:

```bash
sudo defaults write /var/db/receipts/<PKGID> PackageIdentifier "<PKGID>"
sudo defaults write /var/db/receipts/<PKGID> PackageVersion "x.y.z"
sudo defaults write /var/db/receipts/<PKGID> InstallDate "$(date +%s)"
sudo defaults write /var/db/receipts/<PKGID> InstallProcessName "installer"
sudo defaults write /var/db/receipts/<PKGID> PathURL "file://localhost/"
sudo defaults write /var/db/receipts/<PKGID> InstallPrefixPath "usr/local"  # 根据软件实际安装的基准路径设置
```

(将上述中的 `<PKGID>`、`x.y.z` 换成你的包名和版本号)

##### 步骤 4: 验证

```bash
pkgutil --pkg-info <PKGID>
pkgutil --files <PKGID>
```

只要能正常输出文件列表, 系统就彻底重新认回了这个包.

---

### 三、总结建议

如果你只是误忘了类似 Node.js、Go、Python、Wireshark 这类普通的开发者工具:

* 最省心的方式: 啥也不用做, 等下次需要升级时, 直接去下载新版本的 `.pkg` 安装一次, 新的安装过程会自动覆盖并创建全新的收据记录.

-------------------------------------------------------------------------------------------

Q: 对于使用 pkg 安装的软件, 最干净的卸载方法是什么? 如何保证卸载之后没有任何残留文件?

在 macOS 上, 彻底卸载一个由 `.pkg` 安装的软件, 是系统运维和逆向开发中最具挑战性的任务之一.

与常见的"直接把 `.app` 拖进废纸篓"不同, `.pkg` 安装包拥有 `root` 权限, 可以在系统任何角落写入文件, 并且往往包含常驻后台服务(Daemon/Agent)、内核/系统扩展、以及动态生成的配置文件.

要做到"完全干净、绝无残留", 你需要理解一个 `.pkg` 会在系统留下哪几类资产, 并按照标准流程执行逆向清理.

---

### 一、核心认知: `.pkg` 的文件分布三部曲

一个 `.pkg` 安装到系统后, 残留文件通常分为三类:

1. 静态清单文件(BOM Payload): 安装包释放的二进制、库文件(`pkgutil` 能追踪到).
2. 安装脚本动态生成的文件(Script Generated): `postinstall` 脚本在运行时创建的软链接、配置文件、环境变量、系统用户(`pkgutil` 无法追踪).
3. 运行时数据(Runtime Data): 软件启动后在用户目录(`~/Library`)或系统目录(`/Library`)生成的缓存、偏好设置、守护进程配置(`pkgutil` 同样无法追踪).

---

### 二、最彻底的卸载实战工作流(6 步深度清理法)

#### 步骤 1: 停用常驻进程与扩展(防止文件锁死或变成孤儿进程)

如果软件有后台服务(LaunchDaemons / LaunchAgents)或系统扩展(System Extensions), 直接删文件会导致系统报错或服务不断崩溃重启.

1. 检查并卸载后台服务:

```bash
# 查看是否有该软件的常驻服务(以 example 为例)
sudo launchctl list | grep -i "example"

# 卸载对应的 plist 守护进程
sudo launchctl bootout system /Library/LaunchDaemons/com.example.daemon.plist 2>/dev/null
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.example.agent.plist 2>/dev/null
```

2. 检查系统扩展(Driver / Extension):

```bash
systemextensionsctl list | grep -i "example"
# 如果有系统扩展, 通常需要在其原 App 内点击"卸载", 或在 macOS 系统设置 -> 通用 -> 登录项与扩展中禁用
```

---

#### 步骤 2: 使用 `pkgutil` 清理静态清单文件

获取安装包信息, 并精准删除它释放的所有具体文件.

```bash
# 1. 声明你的 Package ID
PKGID="com.example.pkg"

# 2. 获取该包当初安装的基准路径(Location)
INSTALL_LOC=$(pkgutil --pkg-info "$PKGID" | awk -F': ' '/location/ {print $2}')
# 如果 location 是空的, 通常就是根目录 /
[[ -z "$INSTALL_LOC" ]] && TARGET_DIR="/" || TARGET_DIR="/$INSTALL_LOC"

cd "$TARGET_DIR"

# 3. 危险排查(先看后删): 打印将要删除的文件列表
pkgutil --only-files --files "$PKGID" | head -n 20

# 4. 精准删除属于该包的[具体文件](不删目录)
pkgutil --only-files --files "$PKGID" | sudo xargs -I {} rm -f "./{}"

# 5. 安全清理残留的[空目录](从最深路径向外删, 避免误删非空系统目录)
pkgutil --only-dirs --files "$PKGID" | tail -r | sudo xargs -I {} rmdir "./{}" 2>/dev/null
```

> ⚠️ 资深开发者警示: 绝不要使用 `rm -rf` 盲目删除目录! 比如如果一个包安装在 `/usr/local/bin/tool`, 盲目删除父级目录会导致整个 `/usr/local/bin` 被清空. 上述方案使用 `rm -f` 删文件 + `rmdir` 仅清空无用空目录, 是业内最安全的做法.
>

---

#### 步骤 3: 排查 `postinstall` 留下的隐蔽动态修改

这是 90% 的普通清理工具(如 AppCleaner)无法解决的部分. 你需要查看安装包的原始脚本:

1. 提取安装脚本审查:
   如果手头有原 `.pkg`, 解包查看脚本:

```bash
pkgutil --expand /path/to/installer.pkg /tmp/expanded_pkg
ls -la /tmp/expanded_pkg/Scripts/
```

   重点打开里面的 `postinstall` 文件查看:

   * 是否向 `/etc/paths.d/` 或 `/etc/manpaths.d/` 添加了环境变量文件?
   * 是否向 `/etc/sudoers.d/` 添加了提权规则?
   * 是否通过 `dscl` 创建了独立的系统用户/组(例如 `_mysql`)?

2. 常规系统级检查点:

```bash
# 检查环境路径注入
ls -la /etc/paths.d/
# 检查公用库目录
ls -la /Library/Application\ Support/
ls -la /Library/LaunchDaemons/
ls -la /Library/LaunchAgents/
```

---

#### 步骤 4: 清理运行时用户数据(User-Level Data)

`.pkg` 是以 `root` 权限跑在系统级的, 但软件打开后, 会在你当前登录用户的 `~/Library` 目录下创建文件. 根据 Apple 规范, 重点检查并清理以下路径:

```bash
NAME="ExampleApp"
BUNDLE_ID="com.example.app"

# 1. 软件持久化配置与容器
rm -rf ~/Library/Application\ Support/"$NAME"
rm -rf ~/Library/Containers/"$BUNDLE_ID"
rm -rf ~/Library/Group\ Containers/*."$BUNDLE_ID"*

# 2. 偏好设置与缓存
rm -f ~/Library/Preferences/"$BUNDLE_ID".plist
rm -rf ~/Library/Caches/"$BUNDLE_ID"
rm -rf ~/Library/Caches/"$NAME"

# 3. 日志与崩溃堆栈
rm -rf ~/Library/Logs/"$NAME"
rm -rf ~/Library/Saved\ Application\ State/"$BUNDLE_ID".savedState
```

---

#### 步骤 5: 注销系统收据(Deregister Receipt)

确认文件全部清理干净后, 通知系统数据库抹掉这条安装记录:

```bash
sudo pkgutil --forget "$PKGID"
```

此时系统完全恢复到了从未安装过该包的初始状态.

---

### 三、懒人与专家级排查工具推荐

如果不想手动编写 Shell 脚本执行上述繁琐步骤, 以下是 macOS 高级开发者/系统管理员最常用的两个专业工具:

1. Suspicious Package(强烈推荐, 完全免费)
   * 作用: 这是一个专为 `.pkg` 设计的 macOS 检查器.
   * 用法: 在安装未知软件之前, 用它打开 `.pkg`, 它会用直观的 UI 列出该包会安装的所有文件、拥有的所有权限、以及所有的 `preinstall`/`postinstall` 脚本源代码. 在安装前就摸清其底细, 卸载时照单全收即可.

2. AppCleaner
   * 局限性: 如果包内解压出了一个 `.app` 放在 `/Applications`, 把该 `.app` 拖进 AppCleaner, 它能非常方便地搜刮出 `~/Library` 下的偏好设置与缓存(对应上述步骤 4), 但无法清理步骤 1 和步骤 2 中分散在系统根目录(`/usr/local`、`/Library/LaunchDaemons`)的底层文件.

### 总结法则

> 最干净的卸载策略:
> 优先找官方 Uninstall 脚本(例如 Docker、Oracle JDK、Wireshark 通常在 App 内部或 DMG 里自带 `uninstall.sh`) ➔ 若没有, 则执行: 停服务 ➔ `pkgutil --files` 删静态文件 ➔ 查杀 `~/Library` 运行时配置 ➔ `pkgutil --forget` 抹掉收据.
>

-------------------------------------------------------------------------------------------

Q: 查看系统中的常驻服务, 输出如下:
```bash
$ sudo launchctl list
Password:
PID	Status	Label
-	0	com.apple.mobile.obliteration
219	0	com.apple.security.cryptexd
382	0	com.apple.CoreAuthentication.daemon
181	0	com.apple.coreservicesd
401	0	com.apple.modelcatalogd
358	0	com.apple.touchbarserver
792	0	com.apple.deleted_helper
-	0	com.apple.avbdeviced
694	0	com.apple.cvmsServ
-	0	com.apple.applessdstatistics
-	0	com.apple.corercd
-	0	com.apple.hdiejectd
-	0	com.apple.corestorage.corestoraged
261	0	com.apple.storagekitd
195	0	com.apple.biomed
6679	0	com.apple.ospredictiond
-	0	com.apple.storereceiptinstaller
453	0	com.apple.mobileactivationd
429	0	com.apple.seld
351	0	com.apple.PerfPowerTelemetryClientRegistrationService
-	0	com.apple.security.agent.login.00000000-0000-0000-0000-0000000186A2
394	0	com.apple.iconservices.iconservicesagent
-	0	com.apple.asr
350	0	com.apple.audiomxd
-	0	com.apple.logkextloadsd
...
167	0	com.apple.corebrightnessd
-	0	com.apple.tailspind
$
```
如何查看这些常驻服务的详细信息, 例如常驻服务的启动命令, 二进制文件位置, 配置文件位置, 属于那个 pkg 包等?
检查系统扩展的输出如下:
```bash
$ systemextensionsctl list
2 extension(s)
--- com.apple.system_extension.network_extension (Go to 'System Settings > General > Login Items & Extensions > Network Extensions' to modify these system extension(s))
enabled	active	teamID	bundleID (version)	name	[state]
*	*	6N6A2QF4TS	com.enlink.EnUES.Extension (3.1.1/3)	EnClientTunnelExtension	[activated enabled]
*	*	6N6A2QF4TS	com.enlink.EnClientApp.Extension (2.0.1/34)	EnClientTunnelExtension	[activated enabled]
$
```
同样如何查看这些系统扩展的详细信息?

在 macOS 底层架构中, 常驻服务(`launchd`)和系统扩展(`System Extensions`)是两套完全不同的生命周期和管理机制.

针对你提出的两个问题, 下面为你梳理最地道、最直接的排查方法和原理.

---

### 第一部分: 深入排查 `launchd` 常驻服务

你看到的 `sudo launchctl list` 输出中, 绝大部分以 `com.apple.*` 开头的是 macOS 系统自带服务. 对于任何一个服务, 排查的核心链条是:

运行态信息 ➔ 找到 `.plist` 配置文件 ➔ 提取启动命令与二进制 ➔ 反查所属 PKG.

#### 1. 一步到位: 使用 `launchctl print` 查看运行时详细信息

在现代 macOS(10.11+ 乃至当前系统)中, `launchctl list <label>` 已经过时, 官方推荐的诊断命令是 `launchctl print`.

macOS 服务按"域(Domain)"划分:

* 系统级服务(以 root 运行): `system/<Label>`
* 用户级服务(在登录 GUI 会话运行): `gui/<UID>/<Label>`(当前登录用户 UID 通常为 `501`)

示例: 排查系统中的某个服务(以 `com.apple.biomed` 或某个第三方服务为例)

```bash
$ sudo launchctl print system/com.apple.biomed
system/com.apple.biomed = {
	active count = 6
	path = /System/Library/LaunchDaemons/com.apple.biomed.plist
	type = LaunchDaemon
	state = running

	program = /System/Library/PrivateFrameworks/BiomeStreams.framework/Support/biomed
	arguments = {
		/System/Library/PrivateFrameworks/BiomeStreams.framework/Support/biomed
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		MallocSpaceEfficient => 1
		XPC_SERVICE_NAME => com.apple.biomed
	}

	domain = system
	username = _biome
	group = _biome

	minimum runtime = 10
	base minimum runtime = 10
	exit timeout = 5
	runs = 1
	pid = 195
	immediate reason = ipc (mach)
	forks = 0
	execs = 1
	initialized = 1
	trampolined = 1
	started suspended = 0
	proxy started suspended = 0
	last exit code = (never exited)

	semaphores = {
		provides events => 1
	}

	event triggers = {
		com.apple.TextInput.RemoveAllDynamicDictionariesNotification => {
			keepalive = 0
			service = com.apple.biomed
			stream = com.apple.notifyd.matching
			monitor = com.apple.notifyd
			descriptor = {
				"Notification" => "com.apple.TextInput.RemoveAllDynamicDictionariesNotification"
			}
		}
		com.apple.siri.history.deletion.requested => {
			keepalive = 0
			service = com.apple.biomed
			stream = com.apple.notifyd.matching
			monitor = com.apple.notifyd
			descriptor = {
				"Notification" => "com.apple.siri.history.deletion.requested"
			}
		}
		com.apple.suggestions.settingsChanged => {
			keepalive = 0
			service = com.apple.biomed
			stream = com.apple.notifyd.matching
			monitor = com.apple.notifyd
			descriptor = {
				"Notification" => "com.apple.suggestions.settingsChanged"
			}
		}
		AFAssistantEnablementDidChangeDarwinNotification => {
			keepalive = 0
			service = com.apple.biomed
			stream = com.apple.notifyd.matching
			monitor = com.apple.notifyd
			descriptor = {
				"Notification" => "AFAssistantEnablementDidChangeDarwinNotification"
			}
		}
		com.apple.Preferences.ResetPrivacyWarningsNotification => {
			keepalive = 0
			service = com.apple.biomed
			stream = com.apple.notifyd.matching
			monitor = com.apple.notifyd
			descriptor = {
				"Notification" => "com.apple.Preferences.ResetPrivacyWarningsNotification"
			}
		}
		com.apple.biome.prune-expired-events => {
			keepalive = 0
			service = com.apple.biomed
			stream = com.apple.xpc.activity
			monitor = com.apple.UserEventAgent-System
			descriptor = {
				"Repeating" => true
				"Interval" => 86400
				"RequiresClassC" => true
				"AllowBattery" => false
				"Priority" => "Maintenance"
			}
		}
	}

	endpoints = {
		"com.apple.biome.compute.publisher.service" = {
			port = 0x1700b
			active = 1
			managed = 1
			reset = 0
			hide = 0
			watching = 0
		}
		"com.apple.biome.compute.source" = {
			port = 0x1e50b
			active = 1
			managed = 1
			reset = 0
			hide = 0
			watching = 0
		}
		"com.apple.biome.access.system" = {
			port = 0x16af3
			active = 1
			managed = 1
			reset = 0
			hide = 0
			watching = 0
		}
	}

	event channels = {
		"com.apple.notifyd.matching" = {
			port = 0x1e403
			active = 1
			managed = 1
			reset = 0
			hide = 0
			watching = 0
		}
		"com.apple.xpc.activity" = {
			port = 0x1e303
			active = 1
			managed = 1
			reset = 0
			hide = 0
			watching = 0
		}
	}

	spawn type = adaptive (6)
	jetsam priority = 40
	jetsam memory limit (active, soft) = 15 MB
	jetsam memory limit (inactive, hard) = 15 MB
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default
	exponential throttling grace limit = 10
	probabilistic guard malloc policy = {
		activation rate = 1/1000
		sample rate = 1/0
	}

	properties = supports transactions | supports pressured exit | inferred program | system service | exponential throttling | tle system
}
$
```

在输出的大量信息中, 重点看以下几行:

* `path = ...`: 配置文件的绝对物理路径(极重要! 告诉你这个 plist 在哪).
* `program = ...`: 启动的二进制可执行文件路径.
* `arguments = { ... }`: 完整的启动命令及参数.
* `state = running / waiting`: 运行状态及退出码.

---

#### 2. 定位服务的 `.plist` 配置文件位置

如果你没有通过 `launchctl print` 找到路径, 可以了解 macOS 存放 `.plist` 的 5 大标准目录:

| 目录路径 | 权限等级 | 归属 | 常见类型 |
| :--- | :--- | :--- | :--- |
| `/Library/LaunchDaemons` | Root 权限 | 第三方软件 | 开机自启服务、系统守护进程 |
| `/Library/LaunchAgents` | 登录用户 | 第三方软件 | 随任意用户登录启动的后台进程 |
| `~/Library/LaunchAgents` | 当前用户 | 用户私有 | 个人配置的开机项 |
| `/System/Library/LaunchDaemons` | Root (SIP只读) | macOS 官方 | 系统核心守护进程 |
| `/System/Library/LaunchAgents` | 用户 (SIP只读) | macOS 官方 | 系统 GUI/会话代理进程 |

快速检索文件命令:

```bash
# 在第三方服务的目录中搜索包含指定关键字的 plist
grep -rn "com.example.service" /Library/LaunchDaemons/ /Library/LaunchAgents/ ~/Library/LaunchAgents/ 2>/dev/null
```

---

#### 3. 查看 `.plist` 的配置细节与启动二进制

找到 `.plist` 后, 可以直接用系统自带的 `plutil` 或 `defaults` 查看它到底执行了什么:

```bash
# 美化输出 plist 内容
$ plutil -p /System/Library/LaunchDaemons/com.apple.biomed.plist
{
  "EnablePressuredExit" => 1
  "EnableTransactions" => 1
  "GroupName" => "_biome"
  "Label" => "com.apple.biomed"
  "LaunchEvents" => {
    "com.apple.notifyd.matching" => {
      "AFAssistantEnablementDidChangeDarwinNotification" => {
        "Notification" => "AFAssistantEnablementDidChangeDarwinNotification"
      }
      "com.apple.Preferences.ResetPrivacyWarningsNotification" => {
        "Notification" => "com.apple.Preferences.ResetPrivacyWarningsNotification"
      }
      "com.apple.siri.history.deletion.requested" => {
        "Notification" => "com.apple.siri.history.deletion.requested"
      }
      "com.apple.suggestions.settingsChanged" => {
        "Notification" => "com.apple.suggestions.settingsChanged"
      }
      "com.apple.TextInput.RemoveAllDynamicDictionariesNotification" => {
        "Notification" => "com.apple.TextInput.RemoveAllDynamicDictionariesNotification"
      }
    }
    "com.apple.xpc.activity" => {
      "com.apple.biome.prune-expired-events" => {
        "AllowBattery" => 0
        "Interval" => 86400
        "Priority" => "Maintenance"
        "Repeating" => 1
        "RequiresClassC" => 1
      }
    }
  }
  "MachServices" => {
    "com.apple.biome.access.system" => 1
    "com.apple.biome.compute.publisher.service" => 1
    "com.apple.biome.compute.source" => 1
  }
  "ProcessType" => "Adaptive"
  "ProgramArguments" => [
    0 => "/System/Library/PrivateFrameworks/BiomeStreams.framework/Support/biomed"
  ]
  "PublishesEvents" => {
    "com.apple.biome.compute.publisher" => {
      "RequireTrusted" => 1
    }
  }
  "UserName" => "_biome"
}
$
```

重点查看两个 Key:

* `Program`: 直接指定的可执行程序路径.
* `ProgramArguments`: 启动命令数组, 第一个元素为可执行程序, 后面为参数.

---

#### 4. 溯源: 这个常驻服务属于哪个 `.pkg`?

一旦拿到了 `.plist` 文件路径或对应的可执行程序路径, 直接调用我们在上一节讲的 `pkgutil --file-info`:

```bash
$ pkgutil --file-info /System/Library/LaunchDaemons/com.apple.biomed.plist
volume: /
path: /System/Library/LaunchDaemons/com.apple.biomed.plist

$ pkgutil --file-info /System/Library/PrivateFrameworks/BiomeStreams.framework/Support/biomed
volume: /
path: /System/Library/PrivateFrameworks/BiomeStreams.framework/Support/biomed
$

```

如果该文件是由安装包部署的, 命令会直接打印:

```bash
pkg-id: com.vendor.example.pkg
pkg-version: 1.2.3
...
```

(注: 如果查询的是 Apple 原生在 `/System/Library` 的服务, 它是随着 APFS 系统只读系统镜像刷入的, 通常不会有独立的第三方 pkg-id).

---

### 第二部分: 深入排查系统扩展(System Extensions)

从你的 `systemextensionsctl list` 输出可以看到两个激活的网络扩展(Network Extensions):

* TeamID: `6N6A2QF4TS`
* BundleID: `com.enlink.EnUES.Extension` 和 `com.enlink.EnClientApp.Extension`
* 供应商: 这是联软科技(Enlink / UniAccess)的企业安全客户端 / VPN 核心网络隧道扩展.

```bash
$ systemextensionsctl list
2 extension(s)
--- com.apple.system_extension.network_extension (Go to 'System Settings > General > Login Items & Extensions > Network Extensions' to modify these system extension(s))
enabled	active	teamID	bundleID (version)	name	[state]
*	*	6N6A2QF4TS	com.enlink.EnUES.Extension (3.1.1/3)	EnClientTunnelExtension	[activated enabled]
*	*	6N6A2QF4TS	com.enlink.EnClientApp.Extension (2.0.1/34)	EnClientTunnelExtension	[activated enabled]
$
```

System Extension 是现代 macOS 替代传统内核扩展(Kext)的安全技术, 它有非常特殊的物理生命周期: 必须内嵌在一个宿主 `.app` 应用程序内, 由宿主 App 向系统注册激活.

#### 1. 找到该系统扩展的宿主 App(它是从哪来的?)

系统扩展本身内嵌在某个主应用中(通常路径是: `宿主.app/Contents/Library/SystemExtensions/xxx.systemextension`).

方法 A: 通过 Spotlight 元数据快速反查

```bash
mdfind "kMDItemCFBundleIdentifier == 'com.enlink.EnUES.Extension'"
```

或者按应用名称直接查找联软客户端:

```bash
find /Applications -maxdepth 3 -name "*Enlink*" -o -name "*EnClient*" 2>/dev/null
```

方法 B: 在系统的 Staging(临时暂存)目录中查看

当系统扩展被批准激活后, macOS 会把扩展拷贝到受保护的目录 `/Library/SystemExtensions/` 下:

```bash
# 查看系统激活的扩展文件
$ sudo ls -la /Library/SystemExtensions/
Password:
total 8
drwxr-xr-x   6 root  wheel   192 10  6 11:13 .
drwxr-xr-x  69 root  wheel  2208  6 14  2025 ..
drwxr-xr-x   2 root  wheel    64 10  6 11:13 .staging
drwxr-xr-x   3 root  wheel    96  6 27  2023 1AD41445-F2C6-42C6-922A-9FBFE8D55D06
drwxr-xr-x   3 root  wheel    96  6 21  2023 94B15069-FA77-44F0-AA47-1163BBBD0818
-rw-r--r--   1 root  wheel  3639  6 27  2023 db.plist
$

$ tree -a /Library/SystemExtensions/
/Library/SystemExtensions/
├── .staging
├── 1AD41445-F2C6-42C6-922A-9FBFE8D55D06
│   └── com.enlink.EnClientApp.Extension.systemextension
│       └── Contents
│           ├── Info.plist
│           ├── MacOS
│           │   └── com.enlink.EnClientApp.Extension
│           ├── _CodeSignature
│           │   └── CodeResources
│           └── embedded.provisionprofile
├── 94B15069-FA77-44F0-AA47-1163BBBD0818
│   └── com.enlink.EnUES.Extension.systemextension
│       └── Contents
│           ├── Info.plist
│           ├── MacOS
│           │   └── com.enlink.EnUES.Extension
│           ├── Resources
│           │   ├── English.lproj
│           │   │   └── MainMenu.nib
│           │   │       ├── keyedobjects-101300.nib
│           │   │       └── keyedobjects.nib
│           │   ├── LICENSE.txt
│           │   └── README.markdown
│           ├── _CodeSignature
│           │   └── CodeResources
│           └── embedded.provisionprofile
└── db.plist

15 directories, 13 files
$

$ plutil -p /Library/SystemExtensions/db.plist
{
  "bootUUID" => "1B366D1F-E421-4BCD-A072-875A991FDBFB"
  "developerMode" => 0
  "extensionPolicies" => [
  ]
  "extensions" => [
    0 => {
      "additionalLaunchdPlistEntries" => {length = 805, bytes = 0x62706c69 73743030 d4010203 04050607 ... 00000000 0000026d }
      "bundleVersion" => {
        "CFBundleShortVersionString" => "2.0.1"
        "CFBundleVersion" => "34"
      }
      "categories" => [
        0 => "com.apple.system_extension.network_extension"
      ]
      "container" => {
        "bundlePath" => "/Applications/EnClient.app"
      }
      "identifier" => "com.enlink.EnClientApp.Extension"
      "originPath" => "/Applications/EnClient.app/Contents/Library/SystemExtensions/com.enlink.EnClientApp.Extension.systemextension"
      "references" => [
        0 => {
          "appIdentifier" => "com.enlink.EnClientApp"
          "appRef" => "file:///.file/id=6571367.67615769/"
          "teamID" => "6N6A2QF4TS"
        }
      ]
      "stagedBundleURL" => {
        "relative" => "file:///Library/SystemExtensions/1AD41445-F2C6-42C6-922A-9FBFE8D55D06/com.enlink.EnClientApp.Extension.systemextension/"
      }
      "stagedCdhashes" => {
        "6bae17b6f46ebe893eb27c5dd12e2ebae7cdd7b9" => {
          "cpusubtype" => 0
          "cputype" => 16777228
        }
        "8275e38c85865e2ae80fb7aa4251e60380027363" => {
          "cpusubtype" => 3
          "cputype" => 16777223
        }
      }
      "state" => "activated_enabled"
      "teamID" => "6N6A2QF4TS"
      "uniqueID" => "1AD41445-F2C6-42C6-922A-9FBFE8D55D06"
    }
    1 => {
      "additionalLaunchdPlistEntries" => {length = 797, bytes = 0x62706c69 73743030 d4010203 04050607 ... 00000000 00000265 }
      "bundleVersion" => {
        "CFBundleShortVersionString" => "3.1.1"
        "CFBundleVersion" => "3"
      }
      "categories" => [
        0 => "com.apple.system_extension.network_extension"
      ]
      "container" => {
        "bundlePath" => "/Applications/EnUES.app"
      }
      "identifier" => "com.enlink.EnUES.Extension"
      "originPath" => "/Applications/EnUES.app/Contents/Library/SystemExtensions/com.enlink.EnUES.Extension.systemextension"
      "references" => [
        0 => {
          "appIdentifier" => "com.enlink.EnUES"
          "appRef" => "file:///.file/id=6571367.67616094/"
          "teamID" => "6N6A2QF4TS"
        }
      ]
      "stagedBundleURL" => {
        "relative" => "file:///Library/SystemExtensions/94B15069-FA77-44F0-AA47-1163BBBD0818/com.enlink.EnUES.Extension.systemextension/"
      }
      "stagedCdhashes" => {
        "72f2a0910c54b4485d1f3fdafb97a66bebfafd35" => {
          "cpusubtype" => 0
          "cputype" => 16777228
        }
        "5702d6263298c4fb08355363b27d6928a206ecc3" => {
          "cpusubtype" => 3
          "cputype" => 16777223
        }
      }
      "state" => "activated_enabled"
      "teamID" => "6N6A2QF4TS"
      "uniqueID" => "94B15069-FA77-44F0-AA47-1163BBBD0818"
    }
  ]
  "version" => 1
}
$
```

---

#### 2. 查看系统扩展的详细信息(权限、网络规则、证书)

定位到 `.systemextension` 文件后(它本质上也是一个 Bundle 目录):

##### ① 查看其 `Info.plist`(网络扩展的关键配置)

```bash
# 查看其 NetworkExtension 过滤规则、Provider
$ plutil -p /Library/SystemExtensions/1AD41445-F2C6-42C6-922A-9FBFE8D55D06/com.enlink.EnClientApp.Extension.systemextension/Contents/Info.plist
{
  "BuildMachineOSBuild" => "21F79"
  "CFBundleDevelopmentRegion" => "en"
  "CFBundleDisplayName" => "EnClientTunnelExtension"
  "CFBundleExecutable" => "com.enlink.EnClientApp.Extension"
  "CFBundleIdentifier" => "com.enlink.EnClientApp.Extension"
  "CFBundleInfoDictionaryVersion" => "6.0"
  "CFBundleName" => "com.enlink.EnClientApp.Extension"
  "CFBundlePackageType" => "SYSX"
  "CFBundleShortVersionString" => "2.0.1"
  "CFBundleSupportedPlatforms" => [
    0 => "MacOSX"
  ]
  "CFBundleVersion" => "34"
  "DTCompiler" => "com.apple.compilers.llvm.clang.1_0"
  "DTPlatformBuild" => "13F17a"
  "DTPlatformName" => "macosx"
  "DTPlatformVersion" => "12.3"
  "DTSDKBuild" => "21E226"
  "DTSDKName" => "macosx12.3"
  "DTXcode" => "1340"
  "DTXcodeBuild" => "13F17a"
  "LSMinimumSystemVersion" => "10.15"
  "NetworkExtension" => {
    "NEMachServiceName" => "6N6A2QF4TS.group.com.enlink.EnClientApp"
    "NEProviderClasses" => {
      "com.apple.networkextension.packet-tunnel" => "PacketTunnelProvider"
    }
    "NSExtensionPointIdentifier" => "com.apple.networkextension.packet-tunnel"
    "NSExtensionPrincipalClass" => "com_enlink_EnClientApp_Extension.PacketTunnelProvider"
  }
  "NSSystemExtensionUsageDescription" => ""
}
$
```

##### ② 查看它的数字签名与特权声明(Entitlements)

系统扩展需要 Apple 专门颁发的特殊特权(如 `com.apple.developer.networking.networkextension`). 可以用 `codesign` 探查:

```bash
codesign -dvvv --entitlements :- /Applications/EnClient.app/Contents/Library/SystemExtensions/com.enlink.EnUES.Extension.systemextension
```

* 这会打印出开发者证书链(验证 TeamID `6N6A2QF4TS` 是否合法)以及它申请的系统特权.

---

#### 3. 溯源该扩展属于哪个 `.pkg` 包

一旦定位到了宿主 App(例如 `/Applications/EnClient.app`):

```bash
$ pkgutil --file-info /Applications/EnUES.app

volume: /
path: /Applications/EnUES.app

pkgid: com.mygreatcompany.pkg.EnUES
pkg-version: 1.0
install-time: 1688697083
uid: 0
gid: 80
mode: 40755
$
```

或者查询整个系统包中包含该扩展的 pkg:

```bash
pkgutil --pkgs | grep -i enlink
```

---

### 三、 总结: 实战一键排查脚本

如果你以后想一键定位某个第三方 `launchd` 服务, 可以保存这个命令组合(将 `TARGET_LABEL` 替换为要查的服务):

```bash
TARGET="com.apple.biomed" # 换成你要查的 Label

# 1. 抓取 plist 路径与启动命令
sudo launchctl print system/"$TARGET" 2>/dev/null | grep -E "(path =|program =)"

# 2. 假设拿到了路径, 直接追溯 PKG
TARGET_PATH="/Library/LaunchDaemons/$TARGET.plist"
if [ -f "$TARGET_PATH" ]; then
    echo "=== PKG Receipt Info ==="
    pkgutil --file-info "$TARGET_PATH"
fi
```

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------
