@wordlists = "/opt/wordlists"
@resolvers = "@wordlists/resolvers.txt"
@resolvers_trusted = "@wordlists/resolvers_trusted.txt"
@subs_wordlist = "@wordlists/subdomains.txt"
@subs_wordlist_big = "@wordlists/subdomains_big.txt"
@fuzz_wordlist = "@wordlists/fuzz.txt"
@lfi_wordlist = "@wordlists/lfi.txt"
@ssti_wordlist = "@wordlists/ssti.txt"
@permutations = "@wordlists/permutations.txt"
@nuclei_templates = "/root/nuclei-templates"

echo @rootsubs{file} #as:@inscopefile
echo @outscope{!file} #as:@outscopefile

gitdorks_go -gd /opt/tools/gitdorks_go/Dorks/smalldorks.txt -nws 20 -target @z -tf @env:GITHUB_TOKENS -ew 3 #for:@rootsubs:@z #as:@gitdorks{unique}
github-subdomains -d @z -k -q -t @env:GITHUB_TOKENS -o @outfile #for:@rootsubs:@z #as:@github_subs{unique}
whois @z #for:@rootsubs:@z #as:@whois_info
EmailHarvester.py -d @z -e all -l 20 #for:@rootsubs:@z #as:@emails{unique}
cloud_enum -k @z #for:@rootsubs:@z #as:@cloud_assets{unique}

subfinder -all -dL @inscopefile -nc -silent #as:@passivesubs{unique}
crt -s -json -l 10000 @z #for:@rootsubs:@z #as:@crt_subs_raw
jq -r '.[].subdomain' #from:@crt_subs_raw #as:@crt_subs{unique}
curl -s "https://ip.thc.org/sb/@z" #for:@rootsubs:@z #as:@thc_subs{unique}
csprecon -d @z #for:@rootsubs:@z #as:@csp_subs{unique}
analyticsrelationships -ch #from:@rootsubs #as:@analytics_subs{unique}
cat @passivesubs{file} @crt_subs{file} @thc_subs{file} @csp_subs{file} @analytics_subs{file} @github_subs{file} | sort -u #as:@all_passive{unique}

puredns bruteforce @subs_wordlist @z -r @resolvers --resolvers-trusted @resolvers_trusted -w @outfile #for:@rootsubs:@z #as:@brute_subs{unique}
puredns resolve @all_passive{file} -r @resolvers --resolvers-trusted @resolvers_trusted -w @outfile #as:@resolved_passive{unique}
tlsx -san -cn -silent -ro -c 100 #from:@resolved_passive #as:@tls_subs{unique}
dnsx -d @z -r @resolvers -silent -rcode noerror -w @subs_wordlist #for:@rootsubs:@z #as:@noerror_subs{unique}
gotator -sub @resolved_passive{file} -perm @permutations -depth 1 -numbers 3 -md | head -100000 #as:@permut_candidates
puredns resolve @permut_candidates{file} -r @resolvers -w @outfile #as:@permut_subs{unique}
regulator -t @z -f @resolved_passive{file} -o @outfile #for:@rootsubs:@z #as:@regex_subs{unique}
ripgen -d @resolved_passive{file} | head -100000 #as:@ripgen_candidates
puredns resolve @ripgen_candidates{file} -r @resolvers -w @outfile #as:@ripgen_subs{unique}
cat @resolved_passive{file} @brute_subs{file} @tls_subs{file} @noerror_subs{file} @permut_subs{file} @regex_subs{file} @ripgen_subs{file} | sort -u #as:@allsubs{unique} #notifylen{Total Subdomains Found:}

dnsx -r @resolvers_trusted -recon -silent -retry 3 -json #from:@allsubs #as:@dns_records
dnsx -r @resolvers_trusted -a -silent -resp-only #from:@allsubs #as:@all_ips{unique}
grep -aEiv "^(127|10|169\.254|172\.1[6-9]|172\.2[0-9]|172\.3[0-1]|192\.168)\." #from:@all_ips #as:@public_ips{unique}
cdncheck -silent -resp -cdn -waf -nc #from:@public_ips #as:@cdn_results
dnsx -axfr -silent #from:@allsubs #as:@zonetransfer

httpx -silent -no-color -json -random-agent -threads 50 -rl 150 -retries 2 -timeout 10 -td -title -sc -server -ct #from:@allsubs #as:@web_info_raw
jq -r 'try .url' #from:@web_info_raw #as:@webs{unique} #notifylen{Live Websites Found:}
httpx -silent -no-color -json -random-agent -p 81,300,591,593,832,981,1010,1311,1099,2082,2095,2096,2480,3000,3128,3333,4243,4567,4711,4712,4993,5000,5104,5108,5280,5281,5601,5800,6543,7000,7001,7396,7474,8000,8001,8008,8014,8042,8060,8069,8080,8081,8083,8088,8090,8091,8095,8118,8123,8172,8181,8222,8243,8280,8281,8333,8337,8443,8500,8834,8880,8888,8983,9000,9001,9043,9060,9080,9090,9091,9200,9443,9502,9800,9981,10000,10250,11371,12443,15672,16080,17778,18091,18092,20720,32000,55440,55672 -threads 20 -rl 100 -retries 2 -timeout 15 #from:@allsubs #as:@web_uncommon_raw
jq -r 'try .url' #from:@web_uncommon_raw #as:@webs_uncommon{unique}
cat @webs{file} @webs_uncommon{file} | sort -u #as:@webs_all{unique}
nuclei -headless -id screenshot -V dir='screenshots' -silent #from:@webs_all #as:@screenshots #ignore
VhostFinder -ips @public_ips{file} -wordlist @allsubs{file} -verify #as:@vhosts{unique}

curl -s "https://internetdb.shodan.io/@z" #for:@public_ips:@z #as:@shodan_ports
smap -iL @public_ips{file} #as:@smap_results

wafw00f -i @webs_all{file} -o @outfile #as:@waf_results
katana -silent -list @webs_all{file} -jc -kf all -c 20 -d 3 #as:@katana_urls{unique}
urlfinder -d @z -all -silent #for:@rootsubs:@z #as:@urlfinder_urls{unique}
cat @katana_urls{file} @urlfinder_urls{file} | urless | sort -u #as:@all_urls{unique}
gf xss #from:@all_urls #as:@gf_xss{unique}
gf sqli #from:@all_urls #as:@gf_sqli{unique}
gf ssrf #from:@all_urls #as:@gf_ssrf{unique}
gf lfi #from:@all_urls #as:@gf_lfi{unique}
gf redirect #from:@all_urls #as:@gf_redirect{unique}
gf ssti #from:@all_urls #as:@gf_ssti{unique}
gf idor #from:@all_urls #as:@gf_idor{unique}
gf rce #from:@all_urls #as:@gf_rce{unique}
gf debug_logic #from:@all_urls #as:@gf_debug{unique}
gf interestingparams #from:@all_urls #as:@gf_params{unique}
grep -iE '\.js([?#].*)?$' #from:@all_urls #as:@js_files{unique}
subjs -ua "Mozilla/5.0 (X11; Linux x86_64; rv:72.0) Gecko/20100101 Firefox/72.0" -c 40 #from:@js_files #as:@subjs_links{unique}
mantra -s #from:@js_files #as:@js_secrets{unique} #notify:{JS Secrets Found}
arjun -i @webs_all{file} -oT @outfile -t 10 #as:@arjun_params

nuclei -l @webs_all{file} -severity info -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j #as:@nuclei_info
nuclei -l @webs_all{file} -severity low -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j #as:@nuclei_low
nuclei -l @webs_all{file} -severity medium -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j #as:@nuclei_medium #notify:{Medium Severity Findings}
nuclei -l @webs_all{file} -severity high -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j #as:@nuclei_high #notify:{High Severity Findings}
nuclei -l @webs_all{file} -severity critical -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j #as:@nuclei_critical #notify:{Critical Severity Findings}
nuclei -l @allsubs{file} -t @nuclei_templates/http/takeovers -silent -j #as:@takeover_nuclei #notify:{Subdomain Takeover Found}
dnstake -f @allsubs{file} -silent #as:@takeover_dnstake
s3scanner -bucket-file @allsubs{file} #as:@s3_buckets{unique}
gqlspection -l @webs_all{file} -v #as:@graphql_results
shortscan @z #for:@webs_all:@z #as:@iis_shortnames

ffuf -w @fuzz_wordlist -u @z/FUZZ -mc 200,201,202,203,204,301,302,307,401,403,405,500 -t 40 -rate 150 -recursion -recursion-depth 2 -o @outfile -of json #for:@webs_all:@z #as:@fuzz_results

qsreplace FUZZ #from:@gf_xss #as:@xss_fuzz_urls
Gxss -c 100 -p Xss #from:@xss_fuzz_urls #as:@xss_reflected
dalfox pipe --silence --no-color --no-spinner --only-poc r --ignore-return 302,404,403 --skip-bav -w 50 #from:@xss_reflected #as:@xss_vulns #notify:{XSS Vulnerabilities Found}
python3 /opt/tools/Corsy/corsy.py -i @webs_all{file} -o @outfile #as:@cors_vulns
qsreplace FUZZ #from:@gf_redirect #as:@redirect_fuzz_urls
python3 /opt/tools/Oralyzer/oralyzer.py -l @redirect_fuzz_urls{file} -p /opt/tools/Oralyzer/payloads.txt #as:@redirect_vulns
crlfuzz -l @webs_all{file} -o @outfile #as:@crlf_vulns #notify:{CRLF Vulnerabilities Found}
qsreplace FUZZ #from:@gf_lfi #as:@lfi_fuzz_urls
ffuf -w @lfi_wordlist -u @z -mr "root:" -t 40 -rate 150 #for:@lfi_fuzz_urls:@z #as:@lfi_vulns
qsreplace FUZZ #from:@gf_ssti #as:@ssti_fuzz_urls
ffuf -w @ssti_wordlist -u @z -mr "ssti49" -t 40 -rate 150 #for:@ssti_fuzz_urls:@z #as:@ssti_vulns
ghauri -m @gf_sqli{file} --batch --force-ssl #as:@sqli_vulns #notify:{SQLi Vulnerabilities Found}
ppmap #from:@webs_all #as:@prototype_pollution
python3 /opt/tools/smuggler/smuggler.py -u @z #for:@webs_all:@z #as:@smuggling_vulns
Web-Cache-Vulnerability-Scanner -u @z #for:@webs_all:@z #as:@cache_vulns
nomore403 -u @z #for:@webs_all:@z #as:@bypass_403

testssl.sh --quiet --color 0 -U @z #for:@public_ips:@z #as:@ssl_results
grep "\[4" #from:@katana_urls #as:@broken_links{unique}

echo "Recon Complete - Subdomains: $(wc -l < @allsubs{file}) | Webs: $(wc -l < @webs_all{file}) | URLs: $(wc -l < @all_urls{file})" #as:@summary #notify:{Reconnaissance Summary}
