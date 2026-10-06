#!/bin/sh
# /root/tg-presenter.sh — Unified Telegram HTML Card Presenter
# Pure presentation & rendering helpers shared across AX3000T and X28.
# Deterministic text builders only (no router state, no network I/O).

tg_pres_esc() { # tg_pres_esc <text> — escape HTML entities
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

tg_pres_verdict() { # tg_pres_verdict <health_line>
    case "$1" in
        *GREEN*) echo "✅ $1" ;;
        *RED*)   echo "❌ $1" ;;
        *WARN*)  echo "⚠️ $1" ;;
        "")      echo "⚠️ unknown" ;;
        *)       echo "ℹ️ $1" ;;
    esac
}

tg_pres_card() { # tg_pres_card <title> <content>
    printf '<b>%s</b>\n<pre>%s</pre>' "$1" "$2"
}

tg_pres_blockquote() { # tg_pres_blockquote <title> <content>
    printf '<b>%s</b>\n<blockquote expandable>%s</blockquote>' "$1" "$2"
}

tg_pres_bar() { # tg_pres_bar <pct> [width=10]
    awk -v p="$1" -v w="${2:-10}" 'BEGIN{
        full=(p>=100)?w:(p<=0)?0:int(p/100*w+0.5);
        if (full>w) full=w; if (full<0) full=0;
        line=""; for (i=0;i<full;i++) line=line "▰"; for (i=full;i<w;i++) line=line "▱";
        print line
    }'
}

tg_pres_spark() { # tg_pres_spark <pipe-separated-numbers>
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

tg_pres_temp_badge() { # tg_pres_temp_badge <temp_C>
    awk -v t="$1" 'BEGIN{ if (t=="") print ""; else if (t+0<60) print "🟢"; else if (t+0<75) print "🟠"; else print "🔴" }'
}
