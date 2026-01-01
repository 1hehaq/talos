@wordlists = "/opt/wordlists"
@resolvers = "@wordlists/resolvers.txt"
@resolvers_trusted = "@wordlists/resolvers_trusted.txt"
@subs_wordlist = "@wordlists/subdomains.txt"
@subs_wordlist_big = "@wordlists/subdomains_big.txt"
@permutations = "@wordlists/permutations.txt"
@nuclei_templates = "/root/nuclei-templates"

echo @rootsubs{file} #as:@inscopefile
echo @outscope{!file} #as:@outscopefile

subfinder -all -dL @inscopefile -nc -silent #as:@subfinder_subs{unique}
crt -s -json -l 10000 @z #for:@rootsubs:@z #as:@crt_raw
jq -r '.[].subdomain' 2>/dev/null #from:@crt_raw #as:@crt_subs{unique}
github-subdomains -d @z -k -q -t @env:GITHUB_TOKENS -o @outfile #for:@rootsubs:@z #as:@github_subs{unique}
gitlab-subdomains -d @z -t @env:GITLAB_TOKENS #for:@rootsubs:@z #as:@gitlab_subs{unique}
curl -s "https://ip.thc.org/sb/@z" | grep -v ";;" #for:@rootsubs:@z #as:@thc_subs{unique}
csprecon -d @z #for:@rootsubs:@z #as:@csp_subs{unique}
analyticsrelationships -ch #from:@rootsubs #as:@analytics_subs{unique}
cat @subfinder_subs{file} @crt_subs{file} @github_subs{file} @gitlab_subs{file} @thc_subs{file} @csp_subs{file} @analytics_subs{file} | sed 's/^\*\.//' | sort -u #as:@all_passive{unique} #notifylen{Passive Subdomains Found:}

puredns resolve @all_passive{file} -r @resolvers --resolvers-trusted @resolvers_trusted -l 5000 --rate-limit-trusted 500 --wildcard-tests 15 --wildcard-batch 1500000 -w @outfile #as:@resolved_subs{unique}

tlsx -san -cn -silent -ro -c 100 #from:@resolved_subs #as:@tls_raw{unique}
puredns resolve @tls_raw{file} -r @resolvers --resolvers-trusted @resolvers_trusted -w @outfile #as:@tls_subs{unique}

puredns bruteforce @subs_wordlist @z -r @resolvers --resolvers-trusted @resolvers_trusted -l 5000 --rate-limit-trusted 500 --wildcard-tests 15 --wildcard-batch 1500000 -w @outfile #for:@rootsubs:@z #as:@brute_subs{unique}
dnsx -d @z -r @resolvers -silent -rcode noerror -w @subs_wordlist #for:@rootsubs:@z #as:@noerror_raw
grep "\.$z$\|^$z$" #from:@noerror_raw #as:@noerror_subs{unique}

gotator -sub @resolved_subs{file} -perm @permutations -depth 1 -numbers 3 -md | head -100000 #as:@gotator_candidates
puredns resolve @gotator_candidates{file} -r @resolvers -w @outfile #as:@gotator_subs{unique}
ripgen -d @resolved_subs{file} | head -100000 #as:@ripgen_candidates
puredns resolve @ripgen_candidates{file} -r @resolvers -w @outfile #as:@ripgen_subs{unique}
regulator -t @z -f @resolved_subs{file} -o @outfile #for:@rootsubs:@z #as:@regex_subs{unique}
dsieve -if @resolved_subs{file} -f 5 #as:@dsieve_candidates
puredns resolve @dsieve_candidates{file} -r @resolvers -w @outfile #as:@dsieve_subs{unique}

cat @resolved_subs{file} | rev | cut -d. -f1-3 | rev | sort -u | grep "\.$z$" #as:@recursive_roots
subfinder -all -dL @recursive_roots{file} -nc -silent #as:@recursive_passive{unique}
puredns resolve @recursive_passive{file} -r @resolvers -w @outfile #as:@recursive_subs{unique}

httpx -silent -threads 50 -rl 150 -retries 2 -timeout 10 #from:@resolved_subs #as:@live_webs_raw
jq -r 'try .url' 2>/dev/null #from:@live_webs_raw #as:@live_webs{unique}
katana -silent -list @live_webs{file} -jc -kf all -c 20 -d 2 | unfurl -u domains | grep "@z$" #as:@scraped_subs{unique}
puredns resolve @scraped_subs{file} -r @resolvers -w @outfile #as:@scrape_resolved{unique}

cat @resolved_subs{file} @tls_subs{file} @brute_subs{file} @noerror_subs{file} @gotator_subs{file} @ripgen_subs{file} @regex_subs{file} @dsieve_subs{file} @recursive_subs{file} @scrape_resolved{file} | sort -u #as:@allsubs{unique} #notifylen{Total Unique Subdomains:}

dnsx -r @resolvers_trusted -recon -silent -retry 3 -json -o @outfile #from:@allsubs #as:@dns_records
dnsx -r @resolvers_trusted -a -silent -resp-only #from:@allsubs #as:@all_ips{unique}
grep -aEiv "^(127|10|169\.254|172\.1[6-9]|172\.2[0-9]|172\.3[0-1]|192\.168)\." #from:@all_ips #as:@public_ips{unique}
dnsx -r @resolvers_trusted -a -silent -resp #from:@allsubs #as:@subdomain_ip_map

dnstake -f @allsubs{file} -silent #as:@takeover_dnstake #notify:{Potential Takeover - Dnstake}
nuclei -l @allsubs{file} -t @nuclei_templates/http/takeovers -silent -j #as:@takeover_nuclei #notify:{Potential Takeover - Nuclei}
dnsx -axfr -silent #from:@allsubs #as:@zonetransfer #notify:{Zone Transfer Possible}

echo "Subdomain Enumeration Complete" #as:@status #notify:{Subdomain Enumeration Complete}
