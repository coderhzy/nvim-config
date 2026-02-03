#!/bin/bash

# craftzdog dotfiles 自动更新脚本
# 更新后自动提交到你的 GitHub 仓库

set -e

REPO_URL="https://github.com/craftzdog/dotfiles-public.git"
TEMP_DIR="/tmp/craftzdog-dotfiles"
NVIM_CONFIG="$HOME/.config/nvim"
CUSTOM_PLUGINS="$NVIM_CONFIG/lua/plugins/claude.lua"
LOG_FILE="$NVIM_CONFIG/update.log"

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

    REMOTE_COMMIT=$(git ls-remote "$REPO_URL" HEAD | cut -f1)

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

    rm -rf "$TEMP_DIR"
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

    backup_custom

    rsync -av --exclude='plugins/claude.lua' --exclude='.git' \
        "$TEMP_DIR/.config/nvim/" "$NVIM_CONFIG/"

    restore_custom

    cd "$TEMP_DIR"
    git rev-parse HEAD > "$NVIM_CONFIG/.craftzdog-commit"

    rm -rf "$TEMP_DIR"

    log "更新完成！"

    # 同步插件
    log "同步插件..."
    nvim --headless "+Lazy sync" +qa 2>/dev/null || true
    log "插件同步完成"
}

# 提交到 GitHub
git_commit() {
    log "提交更新到 GitHub..."

    cd "$NVIM_CONFIG"

    # 检查是否有变更
    if git diff --quiet && git diff --staged --quiet; then
        log "没有变更需要提交"
        return 0
    fi

    git add -A
    git commit -m "Auto-update from craftzdog $(date '+%Y-%m-%d')"
    git push origin main

    log "已推送到 GitHub"
}

# 主函数
main() {
    log "========== 开始检查更新 =========="

    if check_update; then
        do_update
        git_commit
    fi

    log "========== 检查完成 =========="
}

main
