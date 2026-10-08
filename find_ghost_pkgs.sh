#!/bin/bash
# ==============================================================================
# find_ghost_pkgs.sh
# 作用: 批量扫描 macOS 中已安装的 PKG 收据, 找出文件已被删除的"幽灵包"
# ==============================================================================

# set -x

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否具备 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[错误] 必须使用 root 权限运行此脚本, 以避免系统受保护目录出现 Permission denied 导致误判! ${NC}"
    echo -e "${YELLOW}请使用以下命令运行:${NC}"
    echo -e "  sudo $0 $@"
    exit 1
fi

# 临时结果存储
GHOST_PKGS=()
BROKEN_PKGS=()

# 是否跳过苹果核心系统包(默认跳过系统核心组件, 如 CLTools/XProtect, 避免误判)
# 传参数 -a 或 --all 则扫描所有包
SCAN_ALL=false
if [[ "$1" == "-a" || "$1" == "--all" ]]; then
    SCAN_ALL=true
fi

echo -e "${BLUE}===> 开始扫描已安装的 PKG 收据...${NC}"
if [ "$SCAN_ALL" = false ]; then
    echo -e "${YELLOW}提示: 默认已过滤系统底层包(CLTools/XProtect等). 若需全量扫描, 请加参数: $0 --all${NC}\n"
fi

ALL_PKGS=$(pkgutil --pkgs)
TOTAL_COUNT=$(echo "$ALL_PKGS" | wc -l | tr -d ' ')
CURRENT=0

while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    ((CURRENT++))

    # 默认跳过苹果系统核心底层规则包
    if [ "$SCAN_ALL" = false ]; then
        case "$pkg" in
        com.apple.pkg.CLTools_* | com.apple.pkg.XProtect* | com.apple.pkg.MRT* | com.apple.pkg.Gatekeeper*)
            continue
            ;;
        esac
    fi

    # 获取安装基准路径 (严格处理边界斜杠)
    PKG_INFO=$(pkgutil --pkg-info "$pkg" 2>/dev/null)
    VOLUME=$(echo "$PKG_INFO" | awk -F': ' '/volume/ {print $2}')
    LOCATION=$(echo "$PKG_INFO" | awk -F': ' '/location/ {print $2}')

    BASE_DIR="${VOLUME%/}/${LOCATION#/}"
    BASE_DIR="${BASE_DIR%/}"
    [ -z "$BASE_DIR" ] && BASE_DIR="/"

    # 获取文件列表(只取真实文件, 忽略目录)
    FILES=$(pkgutil --only-files --files "$pkg" 2>/dev/null)
    if [ -z "$FILES" ]; then
        # 没有记录具体文件的包(通常是纯脚本包)跳过
        continue
    fi

    # 智能采样检测 (最多抽检前 40 个文件, 兼顾速度与准确度)
    TOTAL_CHECK=0
    MISSING_COUNT=0

    # 逐行读取文件, 严格保留空格 (IFS= read -r)
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        ((TOTAL_CHECK++))

        # 组装原始目标路径, 全程严格双引号包裹
        TARGET_PATH="${BASE_DIR}/${file#/}"

        # 检查原始路径是否存在 (兼容软链接)
        if [ -e "$TARGET_PATH" ] || [ -L "$TARGET_PATH" ]; then
            continue
        fi

        # ----------------------------------------------------------------------
        # 二级验证机制: 针对微软 MAU / 可重定位 App Bundle 的 Fallback 探测
        # 很多软件安装在临时缓存区后, 被安装器或更新进程挪到了 /Applications
        # ----------------------------------------------------------------------
        IS_FOUND=false
        if [[ "$file" == *".app"* ]]; then
            # 提取出 App 的包名 (例如 "Microsoft Word.app") 以及包内相对子路径
            APP_NAME=$(echo "$file" | sed -E 's|^([^/]+\.app)(/.*)?$|\1|')
            SUB_PATH=$(echo "$file" | sed -E 's|^[^/]+\.app(/.*)?$|\1|')

            # 候选回退目录列表
            FALLBACK_CANDIDATES=(
                "/Applications/${APP_NAME}${SUB_PATH}"
                "/System/Applications/${APP_NAME}${SUB_PATH}"
                "/Applications/Utilities/${APP_NAME}${SUB_PATH}"
                "/Users/${SUDO_USER:-root}/Applications/${APP_NAME}${SUB_PATH}"
            )

            for cand in "${FALLBACK_CANDIDATES[@]}"; do
                if [ -e "$cand" ] || [ -L "$cand" ]; then
                    IS_FOUND=true
                    break
                fi
            done
        fi

        if [ "$IS_FOUND" = false ]; then
            ((MISSING_COUNT++))
        fi

    done <<<"$FILES"

    # 3. 统计判定
    if [ "$TOTAL_CHECK" -gt 0 ]; then
        if [ "$MISSING_COUNT" -eq "$TOTAL_CHECK" ]; then
            echo -e "[${CURRENT}/${TOTAL_COUNT}] ${RED}[ 👻 100% 幽灵包 ]${NC} $pkg"
            GHOST_PKGS+=("$pkg")
            # elif [ "$MISSING_COUNT" -gt $((TOTAL_CHECK * 7 / 10)) ]; then
            # 丢失率超过 70% 判定为严重残缺
        elif [ "$MISSING_COUNT" -gt 0 ]; then
            LOSS_RATE=$((MISSING_COUNT * 100 / TOTAL_CHECK))
            echo -e "[${CURRENT}/${TOTAL_COUNT}] ${YELLOW}[ ⚠️  文件严重残缺 ]${NC} $pkg (丢失率: ${LOSS_RATE}%)"
            BROKEN_PKGS+=("$pkg")
        fi
    fi

done <<<"$ALL_PKGS"

# ==============================================================================
# 输出扫描结果
# ==============================================================================
echo -e "\n========================================================"
echo -e "${BLUE}扫描报告完成:${NC}"
echo -e "发现 ${RED}${#GHOST_PKGS[@]}${NC} 个完全幽灵收据 (文件已全部不复存在)"
echo -e "发现 ${YELLOW}${#BROKEN_PKGS[@]}${NC} 个严重残缺收据 (大部分主体文件已丢失)"
echo -e "========================================================"

if [ ${#GHOST_PKGS[@]} -gt 0 ]; then
    echo -e "\n${RED}[建议抹除的幽灵包](可复制以下命令批量清理收据):${NC}"
    echo "--------------------------------------------------------"
    for p in "${GHOST_PKGS[@]}"; do
        echo "sudo pkgutil --forget \"$p\""
    done
    echo "--------------------------------------------------------"
fi

if [ ${#BROKEN_PKGS[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}[严重残缺的包](建议使用 'pkgutil --files <包名>' 确认后再清理):${NC}"
    for p in "${BROKEN_PKGS[@]}"; do
        echo "  - $p"
    done
fi
