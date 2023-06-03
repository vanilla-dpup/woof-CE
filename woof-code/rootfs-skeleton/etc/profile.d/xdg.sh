#freedesktop base directory spec: standards.freedesktop.org/basedir-spec/latest/
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_DIRS=/usr/share:/usr/local/share
export XDG_CONFIG_DIRS=/etc/xdg #v2.14 changed from /usr/etc
export XDG_CACHE_HOME=$HOME/.cache
export XDG_RUNTIME_DIR=/tmp/runtime-${USER}
export XDG_STATE_HOME=$HOME/.local/state
[ ! -d $XDG_RUNTIME_DIR ] && mkdir -p $XDG_RUNTIME_DIR && chmod 0700 $XDG_RUNTIME_DIR
