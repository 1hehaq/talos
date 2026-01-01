@wordlists = "/opt/wordlists"
@resolvers_trusted = "@wordlists/resolvers_trusted.txt"

dnsx -r @resolvers_trusted -a -silent -resp-only #from:@allsubs #as:@all_ips{unique}
grep -aEiv "^(127|10|169\.254|172\.1[6-9]|172\.2[0-9]|172\.3[0-1]|192\.168)\." #from:@all_ips #as:@public_ips{unique} #notifylen{Public IPs Found:}
dnsx -r @resolvers_trusted -aaaa -silent -resp-only #from:@allsubs #as:@ipv6_ips{unique}

cdncheck -silent -resp -cdn -waf -nc #from:@public_ips #as:@cdn_providers
grep -i "cdn\|waf" #from:@cdn_providers #as:@cdn_ips{unique}
comm -23 <(sort -u @public_ips{file}) <(cut -d'[' -f1 @cdn_providers{file} | sed 's/[[:space:]]*$//' | sort -u) #as:@nocdn_ips{unique}

curl -s "https://internetdb.shodan.io/@z" #for:@public_ips:@z #as:@shodan_results
jq -r '"\(.ip) ports: \(.ports | join(",")) vulns: \(.vulns | join(","))"' #from:@shodan_results #as:@shodan_parsed
smap -iL @nocdn_ips{file} #as:@smap_results

nmap -sV -sC -T4 --top-ports 1000 -iL @nocdn_ips{file} -oA portscan_active -oX @outfile #as:@nmap_results

nmapurls #from:@nmap_results #as:@nmap_webs{unique}
/opt/tools/ultimate-nmap-parser/ultimate-nmap-parser.sh portscan_active.xml #as:@nmap_parsed #ignore

python3 /opt/tools/fav-up/favUp.py -w @z -sc -o @outfile #for:@rootsubs:@z #as:@favicon_results

curl -s "https://ipinfo.io/widget/demo/@z" #for:@public_ips:@z #as:@geo_info

whois -h whois.cymru.com " -v @z" #for:@public_ips:@z #as:@asn_info

dnsx -ptr -silent -resp-only #from:@public_ips #as:@ptr_records{unique}

tlsx -cn -san -so -silent -c 100 #from:@public_ips #as:@tls_info

echo "Host Scan Complete" #as:@host_status #notify:{Host Scan Complete}
