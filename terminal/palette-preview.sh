#!/bin/sh
# Prints the 16 ANSI colours and a few typical terminal outputs, so a palette can be judged at a glance.
# Run inside the terminal you want to test: sh terminal/palette-preview.sh

esc=$(printf '\033')
# Dark label on the light backgrounds, light label on the dark ones.
label_fg() {
    case "$1" in 0|1|4|5|8) echo 97 ;; *) echo 30 ;; esac
}
names="black red green yellow blue magenta cyan white"

printf '\n  %sPalette%s  16 ANSI colours\n\n' "${esc}[1m" "${esc}[0m"
for base in 30 90; do
    printf '  '
    for i in 0 1 2 3 4 5 6 7; do printf '%s[%dm█████%s[0m  ' "$esc" $((base + i)) "$esc"; done
    printf '\n'
done
printf '\n  '
for n in $names; do printf '%-7s' "$n"; done
printf '\n\n'

printf '  %sbackgrounds%s\n  ' "${esc}[2m" "${esc}[0m"
for i in 0 1 2 3 4 5 6 7; do printf '%s[%d;%dm %2d %s[0m' "$esc" $((40 + i)) $(label_fg $i) "$i" "$esc"; done
printf '\n  '
for i in 0 1 2 3 4 5 6 7; do printf '%s[%d;%dm %2d %s[0m' "$esc" $((100 + i)) $(label_fg $((i + 8))) $((i + 8)) "$esc"; done
printf '\n\n'

printf '  %sls%s\n' "${esc}[2m" "${esc}[0m"
printf '  %s[34mdocs%s[0m  %s[34mservices%s[0m  %s[32mrun.sh%s[0m  %s[36mlink -> target%s[0m  shell.qml  %s[31mbroken.qml%s[0m\n\n' "$esc" "$esc" "$esc" "$esc" "$esc" "$esc" "$esc" "$esc" "$esc" "$esc"

printf '  %sgit diff%s\n' "${esc}[2m" "${esc}[0m"
printf '  %s[1mdiff --git a/shell.qml b/shell.qml%s[0m\n' "$esc" "$esc"
printf '  %s[36m@@ -12,7 +12,7 @@%s[0m Scope {\n' "$esc" "$esc"
printf '  %s[31m-    property int volume: 59%s[0m\n' "$esc" "$esc"
printf '  %s[32m+    property int volume: 69%s[0m\n\n' "$esc" "$esc"

printf '  %sstatus%s\n' "${esc}[2m" "${esc}[0m"
printf '  %s[32m✔%s[0m tests passed   %s[33m●%s[0m 2 warnings   %s[31m✘%s[0m 1 error   %s[90m# a comment, or a fish suggestion%s[0m\n\n' "$esc" "$esc" "$esc" "$esc" "$esc" "$esc" "$esc" "$esc"
