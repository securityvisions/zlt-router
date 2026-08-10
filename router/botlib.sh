#!/bin/sh
# botlib.sh — pure rendering helpers shared by botcmd.sh, tg.sh and tests.
# Deterministic text builders only (no router state, no network I/O).
# Tests source the canonical copy at router/botlib.sh.

esc() {  # esc <text>  — escape the three mandatory HTML entities
    printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

card() {  # card <title_html> <pre_body>  — panel Card: title, rule, monospace block
    printf '%s\n──────────────\n<pre>%s</pre>' "$1" "$2"
}

pad() {  # pad <text> <width>  — left-align ASCII text in a column
    printf "%-${2:-1}s" "$1"
}

bar() {  # bar <percent> [width=10]  — progress gauge: ▰ filled / ▱ empty
    awk -v p="$1" -v w="${2:-10}" 'BEGIN{
        full=(p>=100)?w:(p<=0)?0:int(p/100*w+0.5);
        if (full>w) full=w; if (full<0) full=0;
        line=""; for (i=0;i<full;i++) line=line "▰"; for (i=full;i<w;i++) line=line "▱";
        print line
    }'
}

spark() {  # spark <pipe-separated-numbers>  — 8-level trend ▁▂▃▄▅▆▇█
    echo "$1" | tr '|' ' ' | awk '
    BEGIN { L[1]="▁"; L[2]="▂"; L[3]="▃"; L[4]="▄"; L[5]="▅"; L[6]="▆"; L[7]="▇"; L[8]="█" }
    {
        for (i=1;i<=NF;i++){ v[i]=$i; n++ }
    } END {
        if (n==0) exit
        min=v[1]; max=v[1]
        for (i=2;i<=n;i++){ if (v[i]<min) min=v[i]; if (v[i]>max) max=v[i] }
        if (max==min) { for (i=1;i<=n;i++) printf "%s", L[4]; print ""; exit }
        out=""
        for (i=1;i<=n;i++){
            d=int((v[i]-min)/(max-min)*7+0.5)
            if (d<0) d=0; if (d>7) d=7
            out=out L[d+1]
        }
        print out
    }'
}

temp_badge() {  # temp_badge <temp_C>  — 🟢 <60 · 🟠 <75 · 🔴 else · blank unknown
    awk -v t="$1" 'BEGIN{ if (t=="") print ""; else if (t+0<60) print "🟢"; else if (t+0<75) print "🟠"; else print "🔴" }'
}

dev_usage_rows() {  # stdin: "name|<meta>|bytes" → aligned "name  ▰▰▰▱▱  GB" rows
    awk -F'|' '
    BEGIN { for (x=0;x<=10;x++){ s=""; for(y=0;y<x;y++) s=s "▰"; for(y=x;y<10;y++) s=s "▱"; B[x]=s } }
    {   if (NF>=3 && $1!=""){ i++; nm[i]=substr($1,1,16); by[i]=($3<0)?-$3:$3; if (by[i]>mx) mx=by[i] } }
    END {
        if (i==0) exit
        for (j=1;j<=i;j++){
            pct=(mx>0)?int(by[j]/mx*10+0.5):0; if (pct>10) pct=10
            printf "%-16s %s  %7.2f GB\n", nm[j], B[pct], by[j]/1073741824
        }
    }'
}

alert_text() {  # alert_text <title> <body>  — alert Card: title, rule, plain body
    printf '%s\n──────────────\n%s' "$1" "$2"
}

balance_body() {  # balance_body <pct> <remain_gb> <quota_gb> <expires> <expdays> <drain> <series>
    # → gauge + plan + trend + drain lines (for the `<pre>` block)
    local pct="$1" remain="$2" quota="$3" expires="$4" expdays="$5" drain="$6" series="$7"
    local sp nd
    sp=$(spark "$series")
    nd=$(echo "$series" | tr '|' '\n' | sed '/^$/d' | wc -l | tr -d ' ')
    {
        printf 'Gauge    %s   %s%% · %s GB left\n' "$(bar "$pct")" "$pct" "$remain"
        printf 'Plan     %s GB · expires %s (%s)\n' "${quota:-?}" "${expires:-?}" "${expdays:-?d}"
        printf 'Trend    %s  last %sd\n' "${sp:-—}" "${nd:-0}"
        [ -n "$drain" ] && printf 'Drain    %s\n' "$drain"
    }
}

dashboard_body() {  # dashboard_body <bal_pct> <bal_remain> <bal_days> <proxy> <dev> <usage> <disk_pct> <disk_free> <load> <temp>
    # → the 5-line Panel summary inside the `<pre>` block
    local bp="$1" br="$2" bd="$3" proxy="$4" dev="$5" usage="$6" dp="$7" dfree="$8" load="$9" temp="${10}"
    [ "$bd" = "0" ] && bd=""  # treat 0-day history as no history
    printf 'Data     %s  %s%% · %s GB left%s\n' "$(bar "$bp")" "$bp" "${br:-—}" "${bd:+ · ${bd}d}"
    printf 'Proxy    %s\n' "$proxy"
    printf 'Devices  %s online · %s today\n' "${dev:-0}" "${usage:-—}"
    printf 'Disk     %s  %s%% used (%s free)\n' "$(bar "$dp")" "$dp" "$dfree"
    printf 'Load     %s  %s°C\n' "$load" "$temp"
}