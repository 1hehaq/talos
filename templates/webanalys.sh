@wordlists = "/opt/wordlists"
@fuzz_wordlist = "@wordlists/fuzz.txt"

httpx -silent -no-color -json -random-agent -threads 50 -rl 150 -retries 2 -timeout 10 -td -title -sc -server -ct -location -websocket #from:@allsubs #as:@web_info_raw
jq -r 'try .url' #from:@web_info_raw #as:@webs{unique} #notifylen{Live Websites:}
jq -r 'try . | "\(.url) [\(.status_code)] [\(.title)] [\(.webserver)] \(.tech)"' #from:@web_info_raw #as:@web_info_plain

httpx -silent -no-color -json -random-agent -p 81,300,591,593,832,981,1010,1311,1099,2082,2095,2096,2480,3000,3128,3333,4243,4567,4711,4712,4993,5000,5104,5108,5280,5281,5601,5800,6543,7000,7001,7396,7474,8000,8001,8008,8014,8042,8060,8069,8080,8081,8083,8088,8090,8091,8095,8118,8123,8172,8181,8222,8243,8280,8281,8333,8337,8443,8500,8834,8880,8888,8983,9000,9001,9043,9060,9080,9090,9091,9200,9443,9502,9800,9981,10000,10250,11371,12443,15672,16080,17778,18091,18092,20720,32000,55440,55672 -threads 20 -rl 100 -retries 2 -timeout 15 #from:@allsubs #as:@web_uncommon_raw
jq -r 'try .url' #from:@web_uncommon_raw #as:@webs_uncommon{unique}
cat @webs{file} @webs_uncommon{file} | sort -u #as:@webs_all{unique}

wafw00f -i @webs_all{file} -o @outfile #as:@waf_results

katana -silent -list @webs_all{file} -jc -kf all -c 20 -d 3 -o @outfile #as:@katana_urls{unique}
urlfinder -d @z -all -silent #for:@rootsubs:@z #as:@urlfinder_urls{unique}
xnLinkFinder -i @webs_all{file} -sf @allsubs{file} -d 3 -o @outfile #as:@xnlinkfinder_urls{unique}
cat @katana_urls{file} @urlfinder_urls{file} @xnlinkfinder_urls{file} | urless | sort -u #as:@all_urls{unique} #notifylen{Total URLs Extracted:}

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
gf aws-keys #from:@all_urls #as:@gf_aws{unique}

grep -aEi "\.(7z|backup|bak|conf|config|db|env|json|log|old|php|sql|xml|yml|yaml|zip)($|/|\?)" #from:@all_urls #as:@interesting_ext{unique}

grep -iE '\.js([?#].*)?$' #from:@all_urls #as:@js_files_raw{unique}
httpx -follow-redirects -random-agent -silent -timeout 10 -threads 50 -rl 150 -status-code -content-type -retries 2 -no-color #from:@js_files_raw #as:@js_status
grep "\[200\]" #from:@js_status #as:@js_200
grep "javascript" #from:@js_200 #as:@js_live_raw
cut -d ' ' -f1 #from:@js_live_raw #as:@js_files{unique}
subjs -ua "Mozilla/5.0 (X11; Linux x86_64; rv:72.0) Gecko/20100101 Firefox/72.0" -c 40 #from:@js_files #as:@subjs_links{unique}
grep -Eiv "\.(eot|jpg|jpeg|gif|css|tif|tiff|png|ttf|otf|woff|woff2|ico|pdf|svg|txt|js)$" #from:@subjs_links #as:@nojs_links{unique}
xnLinkFinder -i @js_files{file} -sf @allsubs{file} -d 3 -o @outfile #as:@js_endpoints{unique}
mantra -s #from:@js_files #as:@js_secrets{unique} #notify:{JS Secrets Found}
jsluice urls #from:@js_files #as:@jsluice_urls{unique}
jsluice secrets #from:@js_files #as:@jsluice_secrets{unique}
sourcemapper -jsurl @z -output sourcemaps/@z #for:@js_files:@z #as:@sourcemap_status #ignore
python3 /opt/tools/getjswords.py @z #for:@js_files:@z #as:@js_words{unique}

arjun -i @webs_all{file} -oT @outfile -t 10 #as:@arjun_params

ffuf -w @fuzz_wordlist -u @z/FUZZ -mc 200,201,202,203,204,301,302,307,401,403,405,500 -t 40 -rate 150 -recursion -recursion-depth 2 -o @outfile -of json #for:@webs_all:@z #as:@fuzz_results
shortscan @z #for:@webs_all:@z #as:@iis_shortnames

gqlspection -l @webs_all{file} -v #as:@graphql_results

grpcurl -plaintext @z list #for:@webs_all:@z #as:@grpc_services #ignore

python3 /opt/tools/CMSeeK/cmseek.py -l @webs_all{file} --batch -r #as:@cms_results #ignore

unfurl -u keys #from:@all_urls #as:@dict_keys_raw
sed 's/[][]//g; s/[#]//g; s/[}{]//g' #from:@dict_keys_raw #as:@dict_keys{unique}
unfurl -u values #from:@all_urls #as:@dict_values_raw
sed 's/[][]//g; s/[#]//g; s/[}{]//g' #from:@dict_values_raw #as:@dict_values{unique}
tr "[:punct:]" "\n" #from:@all_urls #as:@dict_words{unique}
roboxtractor -m 1 -wb #from:@webs_all #as:@robots_wordlist{unique}

nuclei -headless -id screenshot -V dir='screenshots' -silent #from:@webs_all #as:@screenshots #ignore

VhostFinder -ips @public_ips{file} -wordlist @allsubs{file} -verify #as:@vhosts{unique}

echo "Web Analysis Complete" #as:@analysis_status #notify:{Web Analysis Complete}
