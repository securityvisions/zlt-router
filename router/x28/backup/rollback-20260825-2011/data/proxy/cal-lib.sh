#!/bin/sh
# cal-lib.sh — calendar, time, and visual rendering module.
#
# Owns: Jalali↔Gregorian conversion (breaks-table algorithm), Persian month
# labels, month-range computation, clock-skew validation, HTTP date epoch
# parsing, and share-bar rendering.
#
# All functions are pure (explicit inputs, no device calls). Sourceable
# standalone or via hnlib re-export.

hn_jalali_month_label() {
    case "${1:-}" in
        1) echo "فروردین" ;;
        2) echo "اردیبهشت" ;;
        3) echo "خرداد" ;;
        4) echo "تیر" ;;
        5) echo "مرداد" ;;
        6) echo "شهریور" ;;
        7) echo "مهر" ;;
        8) echo "آبان" ;;
        9) echo "آذر" ;;
        10) echo "دی" ;;
        11) echo "بهمن" ;;
        12) echo "اسفند" ;;
        *) echo "" ; return 1 ;;
    esac
}
hn_greg_to_jalali() {
    local in="$1" gy gm gd gm_n gd_n max
    case "$in" in ????-??-??) ;; *) echo ""; return 1 ;; esac
    gy=$(printf '%s' "$in" | cut -d- -f1)
    gm=$(printf '%s' "$in" | cut -d- -f2)
    gd=$(printf '%s' "$in" | cut -d- -f3)
    case "$gy" in *[!0-9]*) echo ""; return 1 ;; esac
    gm_n=$(printf '%s' "$gm" | sed 's/^0*//'); [ -z "$gm_n" ] && gm_n=0
    gd_n=$(printf '%s' "$gd" | sed 's/^0*//'); [ -z "$gd_n" ] && gd_n=0
    [ "$gm_n" -ge 1 ] 2>/dev/null && [ "$gm_n" -le 12 ] 2>/dev/null || { echo ""; return 1; }
    [ "$gd_n" -ge 1 ] 2>/dev/null && [ "$gd_n" -le 31 ] 2>/dev/null || { echo ""; return 1; }
    case "$gm_n" in
        1|3|5|7|8|10|12) max=31 ;;
        4|6|9|11) max=30 ;;
        2) if [ $((gy % 400)) -eq 0 ] || { [ $((gy % 4)) -eq 0 ] && [ $((gy % 100)) -ne 0 ]; }; then max=29; else max=28; fi ;;
    esac
    [ "$gd_n" -le "$max" ] 2>/dev/null || { echo ""; return 1; }
    awk -v gy="$gy" -v gm="$gm_n" -v gd="$gd_n" '
    function tdiv(a,b){return int(a/b)}
    function jmod(a,b){return a - tdiv(a,b)*b}
    function g2d(gy,gm,gd,  d){ d=tdiv((gy + tdiv(gm-8,6) + 100100)*1461,4)+tdiv(153*jmod(gm+9,12)+2,5)+gd-34840408; d=d-tdiv(tdiv(gy+100100+tdiv(gm-8,6),100)*3,4)+752; return d}
    function d2g(jdn,  j,i){ j=4*jdn+139361631; j=j+tdiv(tdiv(4*jdn+183187720,146097)*3,4)*4-3908; i=tdiv(jmod(j,1461),4)*5+308; D2G_GD=tdiv(jmod(i,153),5)+1; D2G_GM=jmod(tdiv(i,153),12)+1; D2G_GY=tdiv(j,1461)-100100+tdiv(8-D2G_GM,6) }
    function jalCal(jy,  _gy,_leapJ,_jp,_jm,_jump,_leap,_leapG,_march,_n,_i){ _gy=jy+621; _leapJ=-14; _jp=breaks[0]; _jump=0; for(_i=1;_i<bl;_i++){_jm=breaks[_i];_jump=_jm-_jp; if(jy < _jm) break; _leapJ=_leapJ+tdiv(_jump,33)*8+tdiv(jmod(_jump,33),4); _jp=_jm} _n=jy-_jp; _leapJ=_leapJ+tdiv(_n,33)*8+tdiv(jmod(_n,33)+3,4); if(jmod(_jump,33)==4 && _jump-_n==4) _leapJ++; _leapG=tdiv(_gy,4)-tdiv((tdiv(_gy,100)+1)*3,4)-150; _march=20+_leapJ-_leapG; if(_jump-_n<6) _n=_n-_jump+tdiv(_jump+4,33)*33; _leap=jmod(jmod(_n+1,33)-1,4); if(_leap==-1) _leap=4; JAL_LEAP=_leap; JAL_GY=_gy; JAL_MARCH=_march }
    function d2j(jdn,  _gy,_jy,_jdn1f,_k,_jm,_jd){ d2g(jdn); _gy=D2G_GY; _jy=_gy-621; jalCal(_jy); _jdn1f=g2d(_gy,3,JAL_MARCH); _k=jdn-_jdn1f; if(_k>=0){if(_k<=185){_jm=1+tdiv(_k,31);_jd=jmod(_k,31)+1; return _jy" "_jm" "_jd} else _k-=186} else {_jy--; _k+=179; if(JAL_LEAP==1) _k++} _jm=7+tdiv(_k,30); _jd=jmod(_k,30)+1; return _jy" "_jm" "_jd }
    BEGIN{
      breaks[0]=-61;breaks[1]=9;breaks[2]=38;breaks[3]=199;breaks[4]=426;breaks[5]=686;breaks[6]=756;breaks[7]=818;breaks[8]=1111;breaks[9]=1181;breaks[10]=1210;breaks[11]=1635;breaks[12]=2060;breaks[13]=2097;breaks[14]=2192;breaks[15]=2262;breaks[16]=2324;breaks[17]=2394;breaks[18]=2456;breaks[19]=3178; bl=20
      jdn=g2d(gy,gm,gd); res=d2j(jdn); split(res,r," "); printf "%04d-%02d-%02d\n", r[1], r[2], r[3]
    }' 2>/dev/null
}
hn_jalali_to_greg() {
    local in="$1" jy jm jd jm_n jd_n max
    case "$in" in ????-??-??) ;; *) echo ""; return 1 ;; esac
    jy=$(printf '%s' "$in" | cut -d- -f1)
    jm=$(printf '%s' "$in" | cut -d- -f2)
    jd=$(printf '%s' "$in" | cut -d- -f3)
    case "$jy" in *[!0-9]*) echo ""; return 1 ;; esac
    jm_n=$(printf '%s' "$jm" | sed 's/^0*//'); [ -z "$jm_n" ] && jm_n=0
    jd_n=$(printf '%s' "$jd" | sed 's/^0*//'); [ -z "$jd_n" ] && jd_n=0
    [ "$jm_n" -ge 1 ] 2>/dev/null && [ "$jm_n" -le 12 ] 2>/dev/null || { echo ""; return 1; }
    [ "$jd_n" -ge 1 ] 2>/dev/null && [ "$jd_n" -le 31 ] 2>/dev/null || { echo ""; return 1; }
    case "$jm_n" in 1|2|3|4|5|6) max=31 ;; 7|8|9|10|11) max=30 ;; 12) max=30 ;; esac
    [ "$jd_n" -le "$max" ] 2>/dev/null || { echo ""; return 1; }
    awk -v jy="$jy" -v jm="$jm_n" -v jd="$jd_n" '
    function tdiv(a,b){return int(a/b)}
    function jmod(a,b){return a - tdiv(a,b)*b}
    function g2d(gy,gm,gd,  d){ d=tdiv((gy + tdiv(gm-8,6) + 100100)*1461,4)+tdiv(153*jmod(gm+9,12)+2,5)+gd-34840408; d=d-tdiv(tdiv(gy+100100+tdiv(gm-8,6),100)*3,4)+752; return d}
    function jalCal(jy,  _gy,_leapJ,_jp,_jm,_jump,_leap,_leapG,_march,_n,_i){ _gy=jy+621; _leapJ=-14; _jp=breaks[0]; _jump=0; for(_i=1;_i<bl;_i++){_jm=breaks[_i];_jump=_jm-_jp; if(jy < _jm) break; _leapJ=_leapJ+tdiv(_jump,33)*8+tdiv(jmod(_jump,33),4); _jp=_jm} _n=jy-_jp; _leapJ=_leapJ+tdiv(_n,33)*8+tdiv(jmod(_n,33)+3,4); if(jmod(_jump,33)==4 && _jump-_n==4) _leapJ++; _leapG=tdiv(_gy,4)-tdiv((tdiv(_gy,100)+1)*3,4)-150; _march=20+_leapJ-_leapG; if(_jump-_n<6) _n=_n-_jump+tdiv(_jump+4,33)*33; _leap=jmod(jmod(_n+1,33)-1,4); if(_leap==-1) _leap=4; JAL_LEAP=_leap; JAL_GY=_gy; JAL_MARCH=_march }
    function j2d(jy,jm,jd){ jalCal(jy); return g2d(JAL_GY,3,JAL_MARCH)+(jm-1)*31-tdiv(jm,7)*(jm-7)+jd-1 }
    function d2g(jdn,  j,i){ j=4*jdn+139361631; j=j+tdiv(tdiv(4*jdn+183187720,146097)*3,4)*4-3908; i=tdiv(jmod(j,1461),4)*5+308; D2G_GD=tdiv(jmod(i,153),5)+1; D2G_GM=jmod(tdiv(i,153),12)+1; D2G_GY=tdiv(j,1461)-100100+tdiv(8-D2G_GM,6) }
    BEGIN{
      breaks[0]=-61;breaks[1]=9;breaks[2]=38;breaks[3]=199;breaks[4]=426;breaks[5]=686;breaks[6]=756;breaks[7]=818;breaks[8]=1111;breaks[9]=1181;breaks[10]=1210;breaks[11]=1635;breaks[12]=2060;breaks[13]=2097;breaks[14]=2192;breaks[15]=2262;breaks[16]=2324;breaks[17]=2394;breaks[18]=2456;breaks[19]=3178; bl=20
      if(jm==12 && jd==30){ jalCal(jy); if(JAL_LEAP!=0) exit 1 }
      jdn=j2d(jy,jm,jd); d2g(jdn); printf "%04d-%02d-%02d\n", D2G_GY, D2G_GM, D2G_GD
    }' 2>/dev/null
    _rc=$?
    if [ $_rc -ne 0 ]; then echo ""; return 1; fi
}
hn_jalali_month_range() {
    local in="$1" jy jm jm_n
    case "$in" in ????-??) ;; *) echo ""; return 1 ;; esac
    jy=$(printf '%s' "$in" | cut -d- -f1)
    jm=$(printf '%s' "$in" | cut -d- -f2)
    jm_n=$(printf '%s' "$jm" | sed 's/^0*//'); [ -z "$jm_n" ] && jm_n=0
    [ "$jm_n" -ge 1 ] 2>/dev/null && [ "$jm_n" -le 12 ] 2>/dev/null || { echo ""; return 1; }
    awk -v jy="$jy" -v jm="$jm_n" '
    function tdiv(a,b){return int(a/b)}
    function jmod(a,b){return a - tdiv(a,b)*b}
    function g2d(gy,gm,gd,  d){ d=tdiv((gy + tdiv(gm-8,6) + 100100)*1461,4)+tdiv(153*jmod(gm+9,12)+2,5)+gd-34840408; d=d-tdiv(tdiv(gy+100100+tdiv(gm-8,6),100)*3,4)+752; return d}
    function d2g(jdn,  j,i){ j=4*jdn+139361631; j=j+tdiv(tdiv(4*jdn+183187720,146097)*3,4)*4-3908; i=tdiv(jmod(j,1461),4)*5+308; D2G_GD=tdiv(jmod(i,153),5)+1; D2G_GM=jmod(tdiv(i,153),12)+1; D2G_GY=tdiv(j,1461)-100100+tdiv(8-D2G_GM,6) }
    function jalCal(jy,  _gy,_leapJ,_jp,_jm,_jump,_leap,_leapG,_march,_n,_i){ _gy=jy+621; _leapJ=-14; _jp=breaks[0]; _jump=0; for(_i=1;_i<bl;_i++){_jm=breaks[_i];_jump=_jm-_jp; if(jy < _jm) break; _leapJ=_leapJ+tdiv(_jump,33)*8+tdiv(jmod(_jump,33),4); _jp=_jm} _n=jy-_jp; _leapJ=_leapJ+tdiv(_n,33)*8+tdiv(jmod(_n,33)+3,4); if(jmod(_jump,33)==4 && _jump-_n==4) _leapJ++; _leapG=tdiv(_gy,4)-tdiv((tdiv(_gy,100)+1)*3,4)-150; _march=20+_leapJ-_leapG; if(_jump-_n<6) _n=_n-_jump+tdiv(_jump+4,33)*33; _leap=jmod(jmod(_n+1,33)-1,4); if(_leap==-1) _leap=4; JAL_LEAP=_leap; JAL_GY=_gy; JAL_MARCH=_march }
    function j2d(jy,jm,jd){ jalCal(jy); return g2d(JAL_GY,3,JAL_MARCH)+(jm-1)*31-tdiv(jm,7)*(jm-7)+jd-1 }
    BEGIN{
      breaks[0]=-61;breaks[1]=9;breaks[2]=38;breaks[3]=199;breaks[4]=426;breaks[5]=686;breaks[6]=756;breaks[7]=818;breaks[8]=1111;breaks[9]=1181;breaks[10]=1210;breaks[11]=1635;breaks[12]=2060;breaks[13]=2097;breaks[14]=2192;breaks[15]=2262;breaks[16]=2324;breaks[17]=2394;breaks[18]=2456;breaks[19]=3178; bl=20
      s_jdn=j2d(jy,jm,1)
      if(jm==12){ e_jdn=j2d(jy+1,1,1)-1 } else { e_jdn=j2d(jy,jm+1,1)-1 }
      d2g(s_jdn); printf "%04d-%02d-%02d ", D2G_GY,D2G_GM,D2G_GD; d2g(e_jdn); printf "%04d-%02d-%02d\n", D2G_GY,D2G_GM,D2G_GD
    }' 2>/dev/null
}
hn_clock_skew_ok() {
    local loc="${1:-}" rem="${2:-}" maxs="${3:-1800}" d
    case "$loc" in ""|*[!0-9-]*) echo "unknown"; return ;; esac
    case "$rem" in ""|*[!0-9-]*) echo "unknown"; return ;; esac
    d=$(( loc - rem )); [ "$d" -lt 0 ] && d=$(( -d ))
    [ "$d" -le "$maxs" ] && { echo "ok"; return; }
    echo "skewed"
}
hn_http_date_epoch() {
    printf '%s\n' "${1:-}" | awk '
        function tdiv(a,b){ return int(a/b) }
        function jmod(a,b){ return a - tdiv(a,b)*b }
        {
            # expect: Wdy, DD Mon YYYY HH:MM:SS GMT
            dday=$2; mon=$3; yy=$4; t=$5
            if (dday !~ /^[0-9]+$/ || t !~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) next
            m = (mon=="Jan")?1:(mon=="Feb")?2:(mon=="Mar")?3:(mon=="Apr")?4:(mon=="May")?5:(mon=="Jun")?6:(mon=="Jul")?7:(mon=="Aug")?8:(mon=="Sep")?9:(mon=="Oct")?10:(mon=="Nov")?11:(mon=="Dec")?12:0
            if (m == 0) next
            split(t, T, ":")
            # proven Gregorian day-number math (same body as the Jalali g2d)
            dn = tdiv((yy + tdiv(m-8,6) + 100100)*1461, 4) + tdiv(153*jmod(m+9,12)+2, 5) + dday - 34840408
            dn = dn - tdiv(tdiv(yy + 100100 + tdiv(m-8,6), 100)*3, 4) + 752
            print (dn - 2440588) * 86400 + T[1]*3600 + T[2]*60 + T[3]
            exit
        }'
}