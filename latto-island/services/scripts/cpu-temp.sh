#!/bin/sh
# Prints the CPU temperature in millidegrees C, or 0 if no CPU sensor is found.
# thermal_zone0 is often not the CPU (on many Intel laptops it is INT3400, a
# placeholder stuck at 20°C), so known CPU sensors are looked for by name:
#   1. hwmon: Intel coretemp "Package id 0", AMD k10temp/zenpower "Tctl"/"Tdie"
#   2. thermal zones: x86_pkg_temp, TCPU, cpu-thermal (ARM)

for hwmon in /sys/class/hwmon/hwmon*; do
    name="$(cat "$hwmon/name" 2>/dev/null)"
    case "$name" in
        coretemp|k10temp|zenpower) ;;
        *) continue ;;
    esac
    for label in "$hwmon"/temp*_label; do
        [ -f "$label" ] || continue
        case "$(cat "$label")" in
            "Package id 0"|Tctl|Tdie)
                cat "${label%_label}_input"
                exit 0
                ;;
        esac
    done
    # No package label: the first sensor of a CPU driver.
    [ -f "$hwmon/temp1_input" ] && { cat "$hwmon/temp1_input"; exit 0; }
done

for zone in /sys/class/thermal/thermal_zone*; do
    case "$(cat "$zone/type" 2>/dev/null)" in
        x86_pkg_temp|TCPU|cpu-thermal|cpu_thermal)
            cat "$zone/temp"
            exit 0
            ;;
    esac
done

echo 0
