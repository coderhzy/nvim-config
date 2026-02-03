#!/bin/bash

# craftzdog dotfiles 自动更新脚本
# 会保留你的自定义配置 (claude.lua)

set -e

REPO_URL="https://github.com/craftzdog/dotfiles-public.git"
TEMP_DIR="/tmp/craftzdog-dotfiles"
NVIM_CONFIG="$HOME/.config/nvim"
CUSTOM_PLUGINS="$NVIM_CONFIG/lua/plugins/claude.lua"
LOG_FILE="$HOME/.config/nvim/update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 备份自定义配置
backup_custom() {
    if [ -f "$CUSTOM_PLUGINS" ]; then
        cp "$CUSTOM_PLUGINS" "/tmp/claude.lua.backup"
        log "已备份 claude.lua"
    fi
}

# 恢复自定义配置
restore_custom() {
    if [ -f "/tmp/claude.lua.backup" ]; then
        cp "/tmp/claude.lua.backup" "$CUSTOM_PLUGINS"
        log "已恢复 claude.lua"
    fi
}

# 检查更新
check_update() {
    log "检查 craftzdog/dotfiles-public 更新..."

    # 获取远程最新 commit
    REMOTE_COMMIT=$(git ls-remote "$REPO_URL" HEAD | cut -f1)

    # 获取本地记录的 commit
    LOCAL_COMMIT=""
    if [ -f "$NVIM_CONFIG/.craftzdog-commit" ]; then
        LOCAL_COMMIT=$(cat "$NVIM_CONFIG/.craftzdog-commit")
    fi

    if [ "$REMOTE_COMMIT" = "$LOCAL_COMMIT" ]; then
        log "已是最新版本: ${REMOTE_COMMIT:0:7}"
        return 1
    else
        log "发现新版本: ${REMOTE_COMMIT:0:7}"
        return 0
    fi
}

# 执行更新
do_update() {
    log "开始更新..."

    # 清理临时目录
    rm -rf "$TEMP_DIR"

    # 克隆最新版本
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

    # 备份自定义配置
    backup_custom

    # 更新配置文件（保留 plugins 目录中的自定义文件）
    rsync -av --exclude='plugins/claude.lua' \
        "$TEMP_DIR/.config/nvim/" "$NVIM_CONFIG/"

    # 恢复自定义配置
    restore_custom

    # 记录当前 commit
    cd "$TEMP_DIR"
    git rev-parse HEAD > "$NVIM_CONFIG/.craftzdog-commit"

    # 清理
    rm -rf "$TEMP_DIR"

    log "更新完成！"

    # 同步插件
    log "同步插件..."
    nvim --headless "+Lazy sync" +qa 2>/dev/null || true
    log "插件同步完成"
}

# 主函数
main() {
    log "========== 开始检查更新 =========="

    if check_update; then
        do_update
    fi

    log "========== 检查完成 =========="
}

# 运行
main
