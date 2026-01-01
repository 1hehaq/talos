@github_tokens = "@env:GITHUB_TOKENS"
@gitlab_tokens = "@env:GITLAB_TOKENS"

echo @rootsubs{file} #as:@inscopefile

python3 /opt/tools/dorks_hunter/dorks_hunter.py -d @z -o @outfile #for:@rootsubs:@z #as:@google_dorks

gitdorks_go -gd /opt/tools/gitdorks_go/Dorks/smalldorks.txt -nws 20 -target @z -tf @github_tokens -ew 3 #for:@rootsubs:@z #as:@github_dorks{unique} #notify:{GitHub Dorks Results}
github-subdomains -d @z -k -q -t @github_tokens -o @outfile #for:@rootsubs:@z #as:@github_subs{unique}
github-endpoints -d @z -t @github_tokens -o @outfile #for:@rootsubs:@z #as:@github_endpoints{unique}

gitlab-subdomains -d @z -t @gitlab_tokens #for:@rootsubs:@z #as:@gitlab_subs{unique}

echo @z | unfurl format %r #for:@rootsubs:@z #as:@company_names
enumerepo -token-string @github_tokens -usernames @company_names{file} -o @outfile #as:@company_repos

whois @z #for:@rootsubs:@z #as:@whois_info
python3 /opt/tools/msftrecon/msftrecon.py -d @z #for:@rootsubs:@z #as:@azure_tenant
python3 /opt/tools/Scopify/scopify.py -c @z #for:@company_names:@z #as:@scopify_results

python3 /opt/tools/EmailHarvester/EmailHarvester.py -d @z -e all -l 20 #for:@rootsubs:@z #as:@emails_raw
grep "@" #from:@emails_raw #as:@emails{unique} #notify:{Emails Found}
python3 /opt/tools/LeakSearch/LeakSearch.py -k @z -o @outfile #for:@rootsubs:@z #as:@leaked_creds #notify:{Leaked Credentials Found}

python3 /opt/tools/metagoofil/metagoofil.py -d @z -t pdf,docx,xlsx -l 10 -w -o /tmp/metagoofil_@z/ #for:@rootsubs:@z #as:@metagoofil_status

porch-pirate -s @z -l 25 --dump #for:@rootsubs:@z #as:@postman_leaks{unique}
python3 /opt/tools/SwaggerSpy/swaggerspy.py @z | grep -i "[*]\|URL" #for:@rootsubs:@z #as:@swagger_leaks{unique}
trufflehog filesystem @postman_leaks{file} -j 2>/dev/null | jq -c #as:@postman_trufflehog

misconfig-mapper -target @z -service "*" | grep -v "\-\]" | grep -v "Failed" #for:@company_names:@z #as:@misconfigs{unique} #notify:{Third Party Misconfigs}

cloud_enum -k @z -k @company_names #for:@rootsubs:@z #as:@cloud_enum{unique}
s3scanner -bucket-file @rootsubs{file} #as:@s3_buckets{unique}
python3 /opt/tools/CloudHunter/cloudhunter.py -p /opt/tools/CloudHunter/permutations.txt -r /opt/tools/CloudHunter/resolvers.txt -t 50 @z #for:@rootsubs:@z #as:@cloudhunter{unique}

dig +short TXT @z #for:@rootsubs:@z #as:@txt_records
dig +short TXT _dmarc.@z #for:@rootsubs:@z #as:@dmarc_records
python3 /opt/tools/Spoofy/spoofy.py -d @z #for:@rootsubs:@z #as:@spoof_results

echo "OSINT Gathering Complete" #as:@osint_status #notify:{OSINT Complete}
