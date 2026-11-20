#!/bin/bash
# <xbar.title>Unofficial Fellow Corvo Kettle</xbar.title>
# <xbar.desc>local wifi control for Fellow EKG kettles. not affiliated with Fellow.</xbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# refreshes every 10s. every action goes through ~/.local/bin/kettle and
# reports the kettle's confirmed result as a notification.

export PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
[ -f "$HOME/.config/kettle/config" ] && . "$HOME/.config/kettle/config"
IP="$KETTLE_IP"
K="$HOME/.local/bin/kettle"
if [ -z "$IP" ]; then
  echo " ? | sfimage=cup.and.saucer"; echo "---"
  echo "no kettle configured. run 'kettle find' in Terminal | color=gray"; exit 0
fi
j="$(curl -s -m 3 "http://$IP/temp")"

if [ -z "$j" ]; then
  echo " – | sfimage=cup.and.saucer"
  echo "---"
  echo "kettle offline at $IP | color=gray"
  echo "(it drops off wifi during a boil, back when it's done) | color=gray size=11"
  echo "open kettle panel | href=http://localhost:8737 sfimage=macwindow"
  echo "refresh | refresh=true"
  exit 0
fi

temp=$(echo "$j"  | jq -r '.temp|round')
tset=$(echo "$j"  | jq -r '.temp_set|round')
state=$(echo "$j" | jq -r '.state | sub("^S_";"") | ascii_downcase')
s="$("$HOME/.local/bin/kettle-api" read 2>/dev/null)"
g() { echo "$s" | jq -r "$1"; }

if [ "$state" = "off" ]; then
  echo " ${temp}° | sfimage=cup.and.saucer"
else
  echo " ${temp}° ↑ | sfimage=cup.and.saucer.fill"
fi
echo "---"
if [ "$state" = "off" ]; then
  echo "water ${temp}°C · off | color=gray"
else
  echo "water ${temp}°C · ${state} toward ${tset}°C | color=gray"
fi

act() { # label, kettle args..., extra
  local label="$1"; shift
  local params="" i=1
  for a in "$@"; do params="$params param$i=$a"; i=$((i+1)); done
  echo "$label | bash=$K$params terminal=false refresh=true"
}
chk() { [ "$1" = "$2" ] && echo " checked=true"; }

if [ -z "$s" ]; then
  echo "settings unavailable | color=gray"
  echo "---"
  act "heat" on; act "stop" off
  echo "refresh | refresh=true"; exit 0
fi

tgt=$(g '.target_c'); son=$(g '.schedule_on')
echo "target ${tgt}°C · hold $(g 'if .hold_min == 0 then "off" else "\(.hold_min) min" end') · pre-boil $(g 'if .preboil then "on" else "off" end') | color=gray"
[ "$son" = "true" ] && echo "scheduled $(g '.schedule_time') → $(g '.schedule_temp_c|round')°C | color=gray sfimage=alarm"
echo "---"
echo "heat | bash=$K param1=on terminal=false refresh=true sfimage=flame"
echo "stop | bash=$K param1=off terminal=false refresh=true sfimage=stop.circle"
echo "notify me when ready | bash=$K param1=wait terminal=false sfimage=bell"
echo "---"

# temperature
echo "temperature: ${tgt}°C | sfimage=thermometer.medium"
for t in 40 70 80 85 90 93 96 100; do
  echo "--${t}°C | bash=$K param1=n param2=set param3=temp param4=$t terminal=false refresh=true$(chk "$t" "${tgt%.0}")"
done
echo "--custom… | bash=$K param1=ask param2=temp terminal=false refresh=true"

# schedule
if [ "$son" = "true" ]; then
  echo "schedule: $(g '.schedule_time') | sfimage=alarm"
  echo "--$(g '.schedule_time') → $(g '.schedule_temp_c|round')°C | color=gray"
  echo "--change… | bash=$K param1=ask param2=schedule terminal=false refresh=true"
  echo "--cancel schedule | bash=$K param1=n param2=schedule param3=off terminal=false refresh=true"
else
  echo "schedule: none | sfimage=alarm"
  echo "--set schedule… | bash=$K param1=ask param2=schedule terminal=false refresh=true"
fi

# everything else from the kettle's own menu
echo "kettle settings | sfimage=gearshape"
hold=$(g '.hold_min')
echo "--hold: $(g 'if .hold_min == 0 then "off" else "\(.hold_min) min" end')"
for h in 0 15 30 45 60; do
  lbl=$([ "$h" = 0 ] && echo off || echo "$h min")
  echo "----$lbl | bash=$K param1=n param2=set param3=hold param4=$h terminal=false refresh=true$(chk "$h" "$hold")"
done
pb=$(g 'if .preboil then "on" else "off" end')
echo "--pre-boil: $pb"
for v in on off; do echo "----$v | bash=$K param1=n param2=set param3=preboil param4=$v terminal=false refresh=true$(chk "$v" "$pb")"; done
un=$(g '.units')
echo "--units: °$un"
for v in C F; do echo "----°$v | bash=$K param1=n param2=set param3=units param4=$v terminal=false refresh=true$(chk "$v" "$un")"; done
cf=$(g '.clock_mode')
echo "--clock: $(g '.clock') · $cf"
for v in analog digital off; do echo "----$v face | bash=$K param1=n param2=set param3=clockface param4=$v terminal=false refresh=true$(chk "$v" "$cf")"; done
echo "-----"
echo "----sync with this Mac | bash=$K param1=n param2=clock terminal=false refresh=true"
echo "----set time… | bash=$K param1=ask param2=clock terminal=false refresh=true"
ch=$(g '.chime')
echo "--chime: $([ "$ch" = 0 ] && echo off || echo "$ch")"
for v in 0 2 4 6 8 10; do
  lbl=$([ "$v" = 0 ] && echo off || echo "$v")
  echo "----$lbl | bash=$K param1=n param2=set param3=chime param4=$v terminal=false refresh=true$(chk "$v" "$ch")"
done
lang=$(g '.language')
echo "--language: $lang"
for v in english french spanish chinese-simplified chinese-traditional korean japanese; do
  echo "----$v | bash=$K param1=n param2=set param3=language param4=$v terminal=false refresh=true$(chk "$v" "$lang")"
done
echo "--altitude: $(g '.altitude_m') m"
echo "----change… | bash=$K param1=ask param2=altitude terminal=false refresh=true"

echo "---"
echo "open kettle panel | href=http://localhost:8737 sfimage=macwindow"
echo "beep | bash=$K param1=beep terminal=false sfimage=speaker.wave.2"
echo "refresh | refresh=true"
