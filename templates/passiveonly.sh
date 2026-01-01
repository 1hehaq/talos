@github_tokens = "@env:GITHUB_TOKENS"
@gitlab_tokens = "@env:GITLAB_TOKENS"

echo @rootsubs{file} #as:@inscopefile

subfinder -all -dL @inscopefile -nc -silent #as:@subfinder_subs{unique}
crt -s -json -l 10000 @z #for:@rootsubs:@z #as:@crt_raw
jq -r '.[].subdomain' 2>/dev/null #from:@crt_raw #as:@crt_subs{unique}
github-subdomains -d @z -k -q -t @github_tokens -o @outfile #for:@rootsubs:@z #as:@github_subs{unique}
gitlab-subdomains -d @z -t @gitlab_tokens #for:@rootsubs:@z #as:@gitlab_subs{unique}
curl -s "https://ip.thc.org/sb/@z" | grep -v ";;" #for:@rootsubs:@z #as:@thc_subs{unique}
csprecon -d @z #for:@rootsubs:@z #as:@csp_subs{unique}
analyticsrelationships -ch #from:@rootsubs #as:@analytics_subs{unique}
cat @subfinder_subs{file} @crt_subs{file} @github_subs{file} @gitlab_subs{file} @thc_subs{file} @csp_subs{file} @analytics_subs{file} | sed 's/^\*\.//' | sort -u #as:@passive_subs{unique} #notifylen{Passive Subdomains Found:}

curl -s "https://api.shodan.io/dns/domain/@z?key=@env:SHODAN_API_KEY" | jq -r '.data[].value' 2>/dev/null #for:@rootsubs:@z #as:@shodan_ips{unique}

curl -s "https://internetdb.shodan.io/@z" #for:@shodan_ips:@z #as:@shodan_ports
jq -r '"\(.ip) ports: \(.ports | join(","))"' #from:@shodan_ports #as:@port_data

urlfinder -d @z -all -silent #for:@rootsubs:@z #as:@wayback_urls{unique}
cat @wayback_urls{file} | urless | sort -u #as:@passive_urls{unique}

whois @z #for:@rootsubs:@z #as:@whois_info
gitdorks_go -gd /opt/tools/gitdorks_go/Dorks/smalldorks.txt -nws 20 -target @z -tf @github_tokens -ew 3 #for:@rootsubs:@z #as:@github_dorks{unique}
python3 /opt/tools/dorks_hunter/dorks_hunter.py -d @z -o @outfile #for:@rootsubs:@z #as:@google_dorks
python3 /opt/tools/EmailHarvester/EmailHarvester.py -d @z -e all -l 20 #for:@rootsubs:@z #as:@emails_raw
grep "@" #from:@emails_raw #as:@emails{unique}
python3 /opt/tools/LeakSearch/LeakSearch.py -k @z -o @outfile #for:@rootsubs:@z #as:@leaked_creds
porch-pirate -s @z -l 25 --dump #for:@rootsubs:@z #as:@postman_leaks{unique}

cloud_enum -k @z #for:@rootsubs:@z #as:@cloud_assets{unique}

dig +short TXT @z #for:@rootsubs:@z #as:@txt_records
dig +short TXT _dmarc.@z #for:@rootsubs:@z #as:@dmarc_records

echo "Passive Reconnaissance Complete" #as:@passive_status #notify:{Passive Recon Complete}
