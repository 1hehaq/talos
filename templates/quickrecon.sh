@wordlists = "/opt/wordlists"
@resolvers = "@wordlists/resolvers.txt"
@resolvers_trusted = "@wordlists/resolvers_trusted.txt"
@nuclei_templates = "/root/nuclei-templates"

echo @rootsubs{file} #as:@inscopefile

subfinder -all -dL @inscopefile -nc -silent #as:@subfinder_subs{unique}
crt -s -json -l 5000 @z #for:@rootsubs:@z #as:@crt_raw
jq -r '.[].subdomain' 2>/dev/null #from:@crt_raw #as:@crt_subs{unique}
cat @subfinder_subs{file} @crt_subs{file} | sed 's/^\*\.//' | sort -u #as:@passive_subs{unique}
puredns resolve @passive_subs{file} -r @resolvers --resolvers-trusted @resolvers_trusted -w @outfile #as:@allsubs{unique} #notifylen{Resolved Subdomains:}

httpx -silent -no-color -json -random-agent -threads 100 -rl 200 -retries 1 -timeout 5 -td -title -sc -server #from:@allsubs #as:@web_info_raw
jq -r 'try .url' #from:@web_info_raw #as:@webs{unique} #notifylen{Live Websites:}

dnstake -f @allsubs{file} -silent #as:@takeover #notify:{Potential Takeover}

dnsx -r @resolvers_trusted -a -silent -resp-only #from:@allsubs #as:@all_ips{unique}
grep -aEiv "^(127|10|169\.254|172\.1[6-9]|172\.2[0-9]|172\.3[0-1]|192\.168)\." #from:@all_ips #as:@public_ips{unique}

katana -silent -list @webs{file} -jc -kf all -c 30 -d 2 #as:@katana_urls{unique}
urlfinder -d @z -all -silent #for:@rootsubs:@z #as:@urlfinder_urls{unique}
cat @katana_urls{file} @urlfinder_urls{file} | urless | sort -u #as:@all_urls{unique}

gf xss #from:@all_urls #as:@gf_xss{unique}
gf sqli #from:@all_urls #as:@gf_sqli{unique}
gf ssrf #from:@all_urls #as:@gf_ssrf{unique}
gf lfi #from:@all_urls #as:@gf_lfi{unique}

nuclei -l @webs{file} -severity high -nh -rl 200 -silent -retries 1 -t @nuclei_templates -j #as:@nuclei_high #notify:{High Severity Findings}
nuclei -l @webs{file} -severity critical -nh -rl 200 -silent -retries 1 -t @nuclei_templates -j #as:@nuclei_critical #notify:{Critical Severity Findings}

grep -iE '\.js([?#].*)?$' #from:@all_urls #as:@js_files{unique}
mantra -s #from:@js_files #as:@js_secrets{unique} #notify:{JS Secrets}

curl -s "https://internetdb.shodan.io/@z" #for:@public_ips:@z #as:@shodan_ports

echo "Quick Recon Complete" #as:@quick_status #notify:{Quick Recon Complete}
