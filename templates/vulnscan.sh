@wordlists = "/opt/wordlists"
@nuclei_templates = "/root/nuclei-templates"
@lfi_wordlist = "@wordlists/lfi.txt"
@ssti_wordlist = "@wordlists/ssti.txt"
@fuzz_wordlist = "@wordlists/fuzz.txt"

nuclei -ut -silent #as:@nuclei_update #ignore

nuclei -l @webs{file} -severity info -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j -o @outfile #as:@nuclei_info
nuclei -l @webs{file} -severity low -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j -o @outfile #as:@nuclei_low
nuclei -l @webs{file} -severity medium -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j -o @outfile #as:@nuclei_medium #notify:{Medium Severity Findings}
nuclei -l @webs{file} -severity high -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j -o @outfile #as:@nuclei_high #notify:{High Severity Findings}
nuclei -l @webs{file} -severity critical -nh -rl 150 -silent -retries 2 -t @nuclei_templates -j -o @outfile #as:@nuclei_critical #notify:{Critical Severity Findings}
jq -r '["[" + .["template-id"] + "] [" + .info.severity + "] " + (.["matched-at"] // .host)] | .[]' #from:@nuclei_critical #as:@nuclei_critical_parsed
jq -r '["[" + .["template-id"] + "] [" + .info.severity + "] " + (.["matched-at"] // .host)] | .[]' #from:@nuclei_high #as:@nuclei_high_parsed

nuclei -l @allsubs{file} -t @nuclei_templates/http/takeovers -silent -j -o @outfile #as:@takeover_nuclei #notify:{Subdomain Takeover - Nuclei}
dnstake -f @allsubs{file} -silent #as:@takeover_dnstake #notify:{Subdomain Takeover - Dnstake}

gf xss #from:@all_urls #as:@gf_xss{unique}
qsreplace FUZZ #from:@gf_xss #as:@xss_fuzz_prep
sed '/FUZZ/!d' #from:@xss_fuzz_prep #as:@xss_fuzz_urls{unique}
Gxss -c 100 -p Xss #from:@xss_fuzz_urls #as:@xss_reflected{unique}
dalfox pipe --silence --no-color --no-spinner --only-poc r --ignore-return 302,404,403 --skip-bav -w 50 -d 2 #from:@xss_reflected #as:@xss_vulns #notify:{XSS Vulnerabilities Found}

gf sqli #from:@all_urls #as:@gf_sqli{unique}
qsreplace FUZZ #from:@gf_sqli #as:@sqli_fuzz_prep
sed '/FUZZ/!d' #from:@sqli_fuzz_prep #as:@sqli_fuzz_urls{unique}
ghauri -m @sqli_fuzz_urls{file} --batch --force-ssl -o @outfile #as:@sqli_ghauri #notify:{SQLi Found - Ghauri}

gf ssrf #from:@all_urls #as:@gf_ssrf{unique}
interactsh-client -o @outfile &
sleep 2
tail -n1 @outfile | cut -c 16- #as:@collab_server
qsreplace "FFUFHASH.@collab_server" #from:@gf_ssrf #as:@ssrf_fuzz_urls{unique}
ffuf -v -t 40 -rate 150 -w @ssrf_fuzz_urls{file} -u FUZZ | grep "URL" | sed 's/| URL | //' #as:@ssrf_requested
ffuf -v -w @webs{file}:W1 -w /opt/tools/headers_inject.txt:W2 -H "W2: @collab_server" -t 40 -rate 150 -u W1 #as:@ssrf_headers

gf lfi #from:@all_urls #as:@gf_lfi{unique}
qsreplace FUZZ #from:@gf_lfi #as:@lfi_fuzz_prep
sed '/FUZZ/!d' #from:@lfi_fuzz_prep #as:@lfi_fuzz_urls{unique}
ffuf -v -r -t 40 -rate 150 -w @lfi_wordlist -u @z -mr "root:" #for:@lfi_fuzz_urls:@z #as:@lfi_vulns #notify:{LFI Vulnerabilities Found}

gf ssti #from:@all_urls #as:@gf_ssti{unique}
qsreplace FUZZ #from:@gf_ssti #as:@ssti_fuzz_prep
sed '/FUZZ/!d' #from:@ssti_fuzz_prep #as:@ssti_fuzz_urls{unique}
ffuf -v -r -t 40 -rate 150 -w @ssti_wordlist -u @z -mr "ssti49" #for:@ssti_fuzz_urls:@z #as:@ssti_vulns #notify:{SSTI Vulnerabilities Found}

python3 /opt/tools/Corsy/corsy.py -i @webs{file} -o @outfile #as:@cors_vulns

gf redirect #from:@all_urls #as:@gf_redirect{unique}
cat @gf_ssrf{file} #as:@gf_redirect{add}
qsreplace FUZZ #from:@gf_redirect #as:@redirect_fuzz_prep
sed '/FUZZ/!d' #from:@redirect_fuzz_prep #as:@redirect_fuzz_urls{unique}
python3 /opt/tools/Oralyzer/oralyzer.py -l @redirect_fuzz_urls{file} -p /opt/tools/Oralyzer/payloads.txt #as:@redirect_vulns

crlfuzz -l @webs{file} -o @outfile #as:@crlf_vulns #notify:{CRLF Vulnerabilities Found}

gf rce #from:@all_urls #as:@gf_rce{unique}

ppmap #from:@webs #as:@prototype_pollution #notify:{Prototype Pollution Found}

python3 /opt/tools/smuggler/smuggler.py -u @z #for:@webs:@z #as:@smuggling_vulns

Web-Cache-Vulnerability-Scanner -u @z #for:@webs:@z #as:@cache_vulns

nomore403 -u @z #for:@webs:@z #as:@bypass_403

httpx -follow-redirects -random-agent -status-code -threads 50 -rl 150 -timeout 10 -silent -retries 2 -no-color #from:@all_urls #as:@url_status
grep "\[4" #from:@url_status #as:@broken_links{unique}

testssl.sh --quiet --color 0 -U @z #for:@webs:@z #as:@ssl_vulns

echo "Vulnerability Scanning Complete" #as:@vuln_status #notify:{Vulnerability Scanning Complete}
