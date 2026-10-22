#!/bin/sh
# Prints one CPU-time sample, used to rank apps by current CPU use:
#   T <TAB> <total CPU time of the machine, in clock ticks>
#   <pid> <TAB> <CPU time of the process, in clock ticks> <TAB> <executable name>
#
# Use comes from the difference between two samples. Processes are named by
# executable (see top-memory.sh), falling back to the process name.

{
    head -n 1 /proc/stat
    find /proc -maxdepth 2 -path '/proc/[0-9]*/exe' -printf 'E %h %l\n' 2>/dev/null
    cat /proc/[0-9]*/stat 2>/dev/null | sed 's/^/S /'
} | awk '
$1 == "cpu" {
    total = 0
    for (i = 2; i <= 9; i++)
        total += $i
    print "T\t" total
    next
}
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
$1 == "S" {
    line = substr($0, 3)
    pid = line + 0
    # The process name sits in parentheses and may itself contain spaces or
    # parentheses, so split on the last ")".
    lparen = index(line, "(")
    rparen = 0
    for (i = length(line); i > lparen; i--)
        if (substr(line, i, 1) == ")") { rparen = i; break }
    if (rparen == 0)
        next
    comm = substr(line, lparen + 1, rparen - lparen - 1)
    split(substr(line, rparen + 2), field, " ")
    ticks = field[12] + field[13]    # utime + stime
    name = (pid in exe) ? exe[pid] : comm
    print pid "\t" ticks "\t" name
}'
