#!/bin/sh
# Prints the apps using the most memory, one per line:
#   <resident KiB> <TAB> <process count> <TAB> <executable name>
#
# Processes are grouped by executable, so an app split into many processes
# (browsers, Electron apps) counts once: Firefox's "Isolated Web Co" tab
# processes all group under the browser binary. When the executable can't be
# read (kernel threads, other users' processes), the process name is used.

limit="${1:-12}"

{
    find /proc -maxdepth 2 -path '/proc/[0-9]*/exe' -printf 'E %h %l\n' 2>/dev/null
    ps -eo pid=,rss=,comm= | sed 's/^ */P /'
} | awk '
$1 == "E" {
    split($2, parts, "/")
    path = $3
    sub(/ \(deleted\)$/, "", path)
    name = path
    sub(/.*\//, "", name)
    if (name != "")
        exe[parts[3]] = name
    next
}
$1 == "P" && $3 > 0 {
    pid = $2
    rss = $3
    $1 = $2 = $3 = ""
    name = $0
    sub(/^ +/, "", name)
    if (pid in exe)
        name = exe[pid]
    total[name] += rss
    count[name]++
}
END {
    for (name in total)
        print total[name] "\t" count[name] "\t" name
}' | sort -rn | head -n "$limit"
