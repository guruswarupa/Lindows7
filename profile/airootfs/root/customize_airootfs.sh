#!/usr/bin/env bash

set -e -u

useradd -m -G wheel -s /bin/bash liveuser
chpasswd <<< "liveuser:liveuser"

# arch-chroot doesn't run any services by default. Several of the steps below
# (pkexec calls in AeroThemePlasma's own scripts, our headless theme bake)
# need a working system D-Bus + polkitd to talk to. Best-effort: if these
# don't come up cleanly in this chroot, the steps that depend on them just
# fail individually further down without aborting the whole build.
mkdir -p /run/dbus
dbus-daemon --system --fork || true
/usr/lib/polkit-1/polkitd --no-debug --replace &
POLKITD_PID=$!
sleep 2

# AeroThemePlasma must NOT be built/installed as root (its install.sh refuses
# to run meaningfully as root); build it as liveuser, who already has
# passwordless sudo for the privileged `cmake --install` steps inside it.
su - liveuser -c '
set -e -u
cd /tmp
git clone https://gitgud.io/aeroshell/atp/aerothemeplasma.git
cd aerothemeplasma
CMAKE_GENERATOR=Ninja bash install.sh
'

# Bake the theme in: apply the Global Theme non-interactively (safe, config-only),
# then start a throwaway headless Plasma session so the panel/taskbar layout
# template (which only applies through a live plasmashell instance, there is no
# static config for it) gets written into liveuser's own config. Best-effort:
# a failure here should not fail the whole ISO build, it just means the live
# session falls back to the OOTB wizard / a plain default panel on first login.
# ALSO experimental/unverified in this exact chroot build context.
cat > /tmp/bake-atp-theme.sh <<'BAKE_EOF'
#!/bin/bash
set +e

plasma-apply-lookandfeel -a authui7

if [ -d /tmp/aerothemeplasma/repos/aeroshell-workspace ]; then
    wallpaper_script=$(find /tmp/aerothemeplasma/repos/aeroshell-workspace -iname "*wallpaper*" \( -name "*.sh" -o -name "*.js" \) | head -1)
    if [ -n "$wallpaper_script" ]; then
        echo "bake-atp-theme: found possible wallpaper setup script: $wallpaper_script"
        bash "$wallpaper_script" || echo "bake-atp-theme: wallpaper script failed, continuing without it"
    else
        echo "bake-atp-theme: no wallpaper setup script found in aeroshell-workspace, skipping"
    fi
fi

export XDG_RUNTIME_DIR=/tmp/xdg-runtime-liveuser
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
export WAYLAND_DISPLAY=wayland-atpbuild
export PLASMA_DEFAULT_SHELL=io.gitgud.wackyideas.desktop
export XDG_CONFIG_DIRS="/etc/xdg/aerothemeplasma:/etc/xdg:${XDG_CONFIG_DIRS:-}"

dbus-run-session -- bash -c '
kwin_wayland --virtual --width 1920 --height 1080 --no-lockscreen --exit-with-session=plasmashell &
SESSION_PID=$!

layout_js=/usr/share/plasma/layout-templates/io.gitgud.wackyideas.taskbar/contents/layout.js
if [ -f "$layout_js" ]; then
    ready=0
    for i in $(seq 1 30); do
        if busctl --user list 2>/dev/null | grep -q org.kde.plasmashell; then
            ready=1
            break
        fi
        sleep 1
    done
    if [ "$ready" = 1 ]; then
        sleep 3
        busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "$(cat "$layout_js")"
        sleep 3
    else
        echo "bake-atp-theme: plasmashell never came up in the headless session, skipping layout bake"
    fi
else
    echo "bake-atp-theme: layout.js not found at $layout_js, skipping layout bake"
fi

kquitapp6 plasmashell 2>/dev/null
kill "$SESSION_PID" 2>/dev/null
wait "$SESSION_PID" 2>/dev/null
'

exit 0
BAKE_EOF
chmod +x /tmp/bake-atp-theme.sh
su - liveuser -c /tmp/bake-atp-theme.sh

# Explicitly requested: also run every script under deprecated/, on top of
# install.sh, even though install.sh already covers the same ground.
# Two of these (compile.sh, install_kwin_components.sh) reference a repo
# layout (top-level kwin/, misc/libplasma/) that no longer exists upstream --
# they were checked against the actual clone and those paths are gone, so
# those two will mostly just error past missing paths harmlessly (compile.sh's
# failed `cd`s fall through to re-running install.sh a few extra times instead).
# The other three (install_plasma_components.sh, install_kwin_components.sh's
# working parts, install_misc_components.sh, install_plasmoids.sh) still match
# the current layout and do real (if redundant) per-user kpackage/theme installs.
# All wrapped non-fatally with stdin from /dev/null so interactive `read`
# prompts in install_misc_components.sh default to "skip" instead of hanging.
cat > /tmp/run-deprecated.sh <<'DEPRECATED_EOF'
#!/bin/bash
set +e
[ -d /tmp/aerothemeplasma/deprecated ] || exit 0

for script in compile.sh install_kwin_components.sh install_misc_components.sh install_plasma_components.sh install_plasmoids.sh; do
    echo "run-deprecated: running $script"
    ( cd /tmp/aerothemeplasma && CMAKE_GENERATOR=Ninja bash "deprecated/$script" </dev/null )
    rc=$?
    echo "run-deprecated: $script finished (exit $rc)"
done

exit 0
DEPRECATED_EOF
chmod +x /tmp/run-deprecated.sh
su - liveuser -c /tmp/run-deprecated.sh

# Safety net: don't let any lingering background process from the steps above
# (headless kwin_wayland/plasmashell, install_plasmoids.sh's `setsid
# plasmashell --replace &`, polkitd) survive into the image or block mkarchiso
# from unmounting the chroot afterward.
pkill -u liveuser 2>/dev/null || true
sleep 1
pkill -9 -u liveuser 2>/dev/null || true
kill "$POLKITD_PID" 2>/dev/null || true
pkill dbus-daemon 2>/dev/null || true

rm -rf /tmp/aerothemeplasma /tmp/bake-atp-theme.sh /tmp/run-deprecated.sh /tmp/xdg-runtime-liveuser

# Carry the baked AeroShell look (global theme, Kvantum, panel layout) over to
# every user created by the installer: Calamares builds new homes from /etc/skel,
# not from liveuser's home. Repo-provided skel files (e.g. the OOTB flag) win.
# The baked panel layout replaces the skel placeholder.
if [ -d /home/liveuser/.config ]; then
    mkdir -p /etc/skel/.config /etc/skel/.local/share
    [ -f /home/liveuser/.config/plasma-org.kde.plasma.desktop-appletsrc ] && \
        rm -f /etc/skel/.config/plasmashell-appletsrc
    cp -an /home/liveuser/.config/. /etc/skel/.config/
    [ -d /home/liveuser/.local/share ] && cp -an /home/liveuser/.local/share/. /etc/skel/.local/share/
    rm -rf /etc/skel/.config/session /etc/skel/.config/*/*.lock 2>/dev/null || true
fi
