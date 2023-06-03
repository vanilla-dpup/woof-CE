# set environment variables defined in /etc/environment
while read line ; do
        case "$line" in \#*) continue ;; esac
        export "$line"
done < /etc/environment
