uid=$(id -u "$SPOTIFAST_USER")
soloist_process='\("soloist",pid=([0-9]+),fd=[0-9]+\)'

ipset -exist create soloist-connect-next bitmap:port range 1-65535 timeout 5

while true; do
  ipset flush soloist-connect-next
  listeners=$(ss -4 -Hlntpe)
  while read -r _ _ _ address _ details; do
    [[ $address == 0.0.0.0:* && " $details " == *" uid:$uid "* ]] || continue
    [[ $details =~ $soloist_process ]] || continue
    executable=$(readlink -- "/proc/${BASH_REMATCH[1]}/exe") || continue
    [[ $executable == "$SPOTIFAST_STATE/soloist/builds/"*/soloist ]] || continue
    port=${address##*:}
    [[ $port =~ ^[0-9]{1,5}$ ]] || continue
    ipset -exist add soloist-connect-next "$port"
  done <<< "$listeners"
  ipset swap soloist-connect-next soloist-connect
  sleep 2
done
