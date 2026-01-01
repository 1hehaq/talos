#!/bin/bash
set -o pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

TOOLS_DIR="${HOME}/Tools"
VERBOSE=${VERBOSE:-false}
FORCE=${FORCE:-false}
TOOLS_ONLY=${TOOLS_ONLY:-false}

msg()      { printf "${BLUE}[*]${RESET} %s\n" "$1"; }
msg_ok()   { printf "${GREEN}[+]${RESET} %s\n" "$1"; }
msg_warn() { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }
msg_err()  { printf "${RED}[-]${RESET} %s\n" "$1"; }

q() {
    if [[ $VERBOSE == "true" ]]; then "$@"; else "$@" &>/dev/null; fi
}

check_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        SUDO=""
    else
        SUDO="sudo"
    fi
}

declare -A GO_TOOLS=(
    ["subfinder"]="go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    ["httpx"]="go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
    ["nuclei"]="go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    ["dnsx"]="go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    ["katana"]="go install -v github.com/projectdiscovery/katana/cmd/katana@latest"
    ["tlsx"]="go install -v github.com/projectdiscovery/tlsx/cmd/tlsx@latest"
    ["mapcidr"]="go install -v github.com/projectdiscovery/mapcidr/cmd/mapcidr@latest"
    ["cdncheck"]="go install -v github.com/projectdiscovery/cdncheck/cmd/cdncheck@latest"
    ["interactsh-client"]="go install -v github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
    ["notify"]="go install -v github.com/projectdiscovery/notify/cmd/notify@latest"
    ["urlfinder"]="go install -v github.com/projectdiscovery/urlfinder/cmd/urlfinder@latest"
    ["ffuf"]="go install -v github.com/ffuf/ffuf/v2@latest"
    ["puredns"]="go install -v github.com/d3mondev/puredns/v2@latest"
    ["anew"]="go install -v github.com/tomnomnom/anew@latest"
    ["qsreplace"]="go install -v github.com/tomnomnom/qsreplace@latest"
    ["unfurl"]="go install -v github.com/tomnomnom/unfurl@v0.3.0"
    ["gf"]="go install -v github.com/tomnomnom/gf@latest"
    ["dalfox"]="go install -v github.com/hahwul/dalfox/v2@latest"
    ["crlfuzz"]="go install -v github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest"
    ["Gxss"]="go install -v github.com/KathanP19/Gxss@latest"
    ["subjs"]="go install -v github.com/lc/subjs@latest"
    ["github-subdomains"]="go install -v github.com/gwen001/github-subdomains@latest"
    ["gitlab-subdomains"]="go install -v github.com/gwen001/gitlab-subdomains@latest"
    ["github-endpoints"]="go install -v github.com/gwen001/github-endpoints@latest"
    ["gotator"]="go install -v github.com/Josue87/gotator@latest"
    ["roboxtractor"]="go install -v github.com/Josue87/roboxtractor@latest"
    ["analyticsrelationships"]="go install -v github.com/Josue87/analyticsrelationships@latest"
    ["dnstake"]="go install -v github.com/pwnesia/dnstake/cmd/dnstake@latest"
    ["gitdorks_go"]="go install -v github.com/damit5/gitdorks_go@latest"
    ["dsieve"]="go install -v github.com/trickest/dsieve@master"
    ["enumerepo"]="go install -v github.com/trickest/enumerepo@latest"
    ["inscope"]="go install -v github.com/tomnomnom/hacks/inscope@latest"
    ["smap"]="go install -v github.com/s0md3v/smap/cmd/smap@latest"
    ["hakip2host"]="go install -v github.com/hakluke/hakip2host@latest"
    ["mantra"]="go install -v github.com/Brosck/mantra@latest"
    ["crt"]="go install -v github.com/cemulus/crt@latest"
    ["s3scanner"]="go install -v github.com/sa7mon/s3scanner@latest"
    ["nmapurls"]="go install -v github.com/sdcampbell/nmapurls@latest"
    ["shortscan"]="go install -v github.com/bitquark/shortscan/cmd/shortscan@latest"
    ["sns"]="go install github.com/sw33tLie/sns@latest"
    ["ppmap"]="go install -v github.com/kleiton0x00/ppmap@latest"
    ["sourcemapper"]="go install -v github.com/denandz/sourcemapper@latest"
    ["jsluice"]="go install -v github.com/BishopFox/jsluice/cmd/jsluice@latest"
    ["cent"]="go install -v github.com/xm1k3/cent@latest"
    ["csprecon"]="go install github.com/edoardottt/csprecon/cmd/csprecon@latest"
    ["VhostFinder"]="go install -v github.com/wdahlenburg/VhostFinder@latest"
    ["misconfig-mapper"]="go install github.com/intigriti/misconfig-mapper/cmd/misconfig-mapper@latest"
    ["grpcurl"]="go install -v github.com/fullstorydev/grpcurl/cmd/grpcurl@latest"
    ["brutespray"]="go install -v github.com/x90skysn3k/brutespray@latest"
    ["Web-Cache-Vulnerability-Scanner"]="go install -v github.com/Hackmanit/Web-Cache-Vulnerability-Scanner@latest"
)

declare -A PIPX_TOOLS=(
    ["dnsvalidator"]="vortexau/dnsvalidator"
    ["interlace"]="codingo/Interlace"
    ["wafw00f"]="EnableSecurity/wafw00f"
    ["commix"]="commixproject/commix"
    ["urless"]="xnl-h4ck3r/urless"
    ["ghauri"]="r0oth3x49/ghauri"
    ["xnLinkFinder"]="xnl-h4ck3r/xnLinkFinder"
    ["xnldorker"]="xnl-h4ck3r/xnldorker"
    ["porch-pirate"]="MandConsultingGroup/porch-pirate"
    ["p1radup"]="iambouali/p1radup"
    ["subwiz"]="hadriansecurity/subwiz"
    ["arjun"]="s0md3v/Arjun"
    ["gqlspection"]="doyensec/GQLSpection"
    ["cloud_enum"]="initstring/cloud_enum"
)

declare -A REPOS=(
    ["dorks_hunter"]="six2dez/dorks_hunter"
    ["Corsy"]="s0md3v/Corsy"
    ["CMSeeK"]="Tuhinshubhra/CMSeeK"
    ["fav-up"]="pielco11/fav-up"
    ["massdns"]="blechschmidt/massdns"
    ["Oralyzer"]="r0075h3ll/Oralyzer"
    ["testssl.sh"]="drwetter/testssl.sh"
    ["JSA"]="w9w/JSA"
    ["CloudHunter"]="belane/CloudHunter"
    ["ultimate-nmap-parser"]="shifty0g/ultimate-nmap-parser"
    ["pydictor"]="LandGrey/pydictor"
    ["smuggler"]="defparam/smuggler"
    ["regulator"]="cramppet/regulator"
    ["gitleaks"]="gitleaks/gitleaks"
    ["trufflehog"]="trufflesecurity/trufflehog"
    ["nomore403"]="devploit/nomore403"
    ["SwaggerSpy"]="UndeadSec/SwaggerSpy"
    ["LeakSearch"]="JoelGMSec/LeakSearch"
    ["ffufPostprocessing"]="Damian89/ffufPostprocessing"
    ["Spoofy"]="MattKeeley/Spoofy"
    ["msftrecon"]="Arcanum-Sec/msftrecon"
    ["Scopify"]="Arcanum-Sec/Scopify"
    ["metagoofil"]="opsdisk/metagoofil"
    ["EmailHarvester"]="maldevel/EmailHarvester"
    ["sqlmap"]="sqlmapproject/sqlmap"
    ["gf"]="tomnomnom/gf"
    ["Gf-Patterns"]="1ndianl33t/Gf-Patterns"
    ["sus_params"]="g0ldencybersec/sus_params"
)

declare -A WORDLISTS=(
    ["subs_wordlist"]="https://gist.github.com/six2dez/a307a04a222fab5a57466c51e1569acf/raw"
    ["subs_wordlist_big"]="https://raw.githubusercontent.com/n0kovo/n0kovo_subdomains/main/n0kovo_subdomains_huge.txt"
    ["resolvers"]="https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt"
    ["resolvers_trusted"]="https://gist.githubusercontent.com/six2dez/ae9ed7e5c786461868abd3f2344401b6/raw"
    ["fuzz_wordlist"]="https://raw.githubusercontent.com/six2dez/OneListForAll/main/onelistforallmicro.txt"
    ["lfi_wordlist"]="https://gist.githubusercontent.com/six2dez/a89a0c7861d49bb61a09822d272d5395/raw"
    ["ssti_wordlist"]="https://gist.githubusercontent.com/six2dez/ab5277b11da7369bf4e9db72b49ad3c1/raw"
    ["permutations_list"]="https://gist.github.com/six2dez/ffc2b14d283e8f8eff6ac83e20a3c4b4/raw"
    ["headers_inject"]="https://gist.github.com/six2dez/d62ab8f8ffd28e1c206d401081d977ae/raw"
    ["jsluice_patterns"]="https://gist.githubusercontent.com/six2dez/2aafa8dc2b682bb0081684e71900e747/raw"
)

install_system_packages() {
    msg "Installing system packages..."
    
    if [[ -f /etc/debian_version ]]; then
        $SUDO apt-get update -y
        $SUDO apt-get install -y \
            python3 python3-pip python3-venv pipx python3-virtualenv \
            build-essential gcc cmake ruby whois git curl libpcap-dev wget zip \
            python3-dev pv dnsutils libssl-dev libffi-dev libxml2-dev libxslt1-dev \
            zlib1g-dev nmap jq apt-transport-https lynx medusa xvfb libxml2-utils \
            procps bsdmainutils libdata-hexdump-perl
    elif [[ -f /etc/redhat-release ]]; then
        $SUDO yum groupinstall "Development Tools" -y
        $SUDO yum install -y epel-release || true
        $SUDO yum install -y \
            python3 python3-pip gcc cmake ruby git curl libpcap whois wget pipx zip pv \
            bind-utils openssl-devel libffi-devel libxml2-devel libxslt-devel zlib-devel \
            nmap jq lynx medusa xorg-x11-server-xvfb
    elif [[ -f /etc/arch-release ]]; then
        $SUDO pacman -Sy --noconfirm \
            python python-pip base-devel gcc cmake ruby git curl libpcap python-pipx \
            whois wget zip pv bind openssl libffi libxml2 libxslt zlib nmap jq lynx medusa \
            xorg-server-xvfb
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew update
        brew install --formula \
            bash coreutils gnu-getopt gnu-sed python pipx massdns jq gcc cmake ruby \
            git curl wget zip pv bind whois nmap lynx medusa shodan
    else
        msg_err "Unsupported OS. Please install dependencies manually."
        return 1
    fi
    
    msg_ok "System packages installed"
}

install_golang() {
    msg "Installing/updating Go..."
    
    local version
    version=$(curl -s https://go.dev/VERSION?m=text | head -1 || echo "go1.22.0")
    
    if command -v go &>/dev/null; then
        local current
        current="$(go version | awk '{print $3}')"
        if [[ "$version" == "$current" ]]; then
            msg_ok "Go already up to date ($version)"
            return 0
        fi
    fi
    
    local arch_suffix=""
    case "$(uname -m)" in
        arm64|aarch64)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                arch_suffix="darwin-arm64"
            else
                arch_suffix="linux-arm64"
            fi
            ;;
        x86_64|amd64)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                arch_suffix="darwin-amd64"
            else
                arch_suffix="linux-amd64"
            fi
            ;;
        *)
            msg_err "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
    
    local url="https://dl.google.com/go/${version}.${arch_suffix}.tar.gz"
    local archive="/tmp/${version}.${arch_suffix}.tar.gz"
    
    wget -q "$url" -O "$archive" || { msg_err "Failed to download Go"; return 1; }
    
    $SUDO rm -rf /usr/local/go
    $SUDO tar -C /usr/local -xzf "$archive"
    rm -f "$archive"
    
    export GOROOT=/usr/local/go
    export GOPATH="${HOME}/go"
    export PATH="$GOPATH/bin:$GOROOT/bin:$PATH"
    
    msg_ok "Go $version installed"
}

install_rust() {
    msg "Installing Rust..."
    
    if command -v rustc &>/dev/null; then
        msg_ok "Rust already installed"
        return 0
    fi
    
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "${HOME}/.cargo/env"
    
    cargo install ripgen
    
    msg_ok "Rust installed"
}

install_go_tools() {
    msg "Installing Go tools (${#GO_TOOLS[@]} total)..."
    
    local ok=0 skip=0 fail=0
    local total=${#GO_TOOLS[@]}
    local i=0
    
    for tool in "${!GO_TOOLS[@]}"; do
        ((i++))
        
        if [[ $FORCE != "true" ]] && command -v "$tool" &>/dev/null; then
            ((skip++))
            [[ $VERBOSE == "true" ]] && msg_warn "[$i/$total] $tool (skip)"
            continue
        fi
        
        if q bash -lc "${GO_TOOLS[$tool]}"; then
            ((ok++))
            msg_ok "[$i/$total] $tool"
        else
            ((fail++))
            msg_err "[$i/$total] $tool (failed)"
        fi
    done
    
    msg "Go tools: $ok installed, $skip skipped, $fail failed"
}

install_pipx_tools() {
    msg "Installing pipx tools (${#PIPX_TOOLS[@]} total)..."
    
    q pipx ensurepath
    
    local ok=0 skip=0 fail=0
    local total=${#PIPX_TOOLS[@]}
    local i=0
    
    for tool in "${!PIPX_TOOLS[@]}"; do
        ((i++))
        
        if [[ $FORCE != "true" ]] && command -v "$tool" &>/dev/null; then
            ((skip++))
            [[ $VERBOSE == "true" ]] && msg_warn "[$i/$total] $tool (skip)"
            continue
        fi
        
        if q pipx install "git+https://github.com/${PIPX_TOOLS[$tool]}"; then
            q pipx upgrade "$tool"
            ((ok++))
            msg_ok "[$i/$total] $tool"
        else
            ((fail++))
            msg_err "[$i/$total] $tool (failed)"
        fi
    done
    
    msg "pipx tools: $ok installed, $skip skipped, $fail failed"
}

install_repos() {
    msg "Cloning repositories (${#REPOS[@]} total)..."
    
    mkdir -p "$TOOLS_DIR"
    
    local ok=0 skip=0 fail=0
    local total=${#REPOS[@]}
    local i=0
    
    for repo in "${!REPOS[@]}"; do
        ((i++))
        local repo_path="${TOOLS_DIR}/${repo}"
        
        if [[ $FORCE != "true" ]] && [[ -d "$repo_path" ]]; then
            ((skip++))
            [[ $VERBOSE == "true" ]] && msg_warn "[$i/$total] $repo (skip)"
            continue
        fi
        
        if [[ -d "$repo_path" ]]; then
            rm -rf "$repo_path"
        fi
        
        if q git clone --depth 1 "https://github.com/${REPOS[$repo]}" "$repo_path"; then
            ((ok++))
            msg_ok "[$i/$total] $repo"
            
            if [[ -f "${repo_path}/requirements.txt" ]]; then
                pushd "$repo_path" >/dev/null
                python3 -m venv venv 2>/dev/null || true
                source venv/bin/activate 2>/dev/null || true
                q pip3 install -r requirements.txt || true
                deactivate 2>/dev/null || true
                popd >/dev/null
            fi
            
            case "$repo" in
                "massdns")
                    make -C "$repo_path" &>/dev/null
                    $SUDO cp "${repo_path}/bin/massdns" /usr/local/bin/ 2>/dev/null || true
                    ;;
                "gitleaks")
                    make -C "$repo_path" build &>/dev/null
                    $SUDO cp "${repo_path}/gitleaks" /usr/local/bin/ 2>/dev/null || true
                    ;;
                "nomore403"|"ffufPostprocessing")
                    pushd "$repo_path" >/dev/null
                    go build &>/dev/null || true
                    popd >/dev/null
                    ;;
                "gf")
                    mkdir -p "${HOME}/.gf"
                    cp -r "${repo_path}/examples/"* "${HOME}/.gf/" 2>/dev/null || true
                    ;;
                "Gf-Patterns")
                    mkdir -p "${HOME}/.gf"
                    cp "${repo_path}/"*.json "${HOME}/.gf/" 2>/dev/null || true
                    ;;
                "sus_params")
                    mkdir -p "${HOME}/.gf"
                    cp "${repo_path}/gf-patterns/"*.json "${HOME}/.gf/" 2>/dev/null || true
                    ;;
            esac
        else
            ((fail++))
            msg_err "[$i/$total] $repo (failed)"
        fi
    done
    
    msg "Repos: $ok cloned, $skip skipped, $fail failed"
}

install_wordlists() {
    msg "Downloading wordlists..."
    
    local wordlist_dir="${TOOLS_DIR}/wordlists"
    mkdir -p "$wordlist_dir"
    
    for name in "${!WORDLISTS[@]}"; do
        local dest="${wordlist_dir}/${name}.txt"
        
        if [[ $FORCE != "true" ]] && [[ -f "$dest" ]]; then
            [[ $VERBOSE == "true" ]] && msg_warn "$name (skip)"
            continue
        fi
        
        if wget -q "${WORDLISTS[$name]}" -O "$dest"; then
            msg_ok "$name"
        else
            msg_err "$name (failed)"
        fi
    done
    
    msg_ok "Wordlists downloaded to $wordlist_dir"
}

install_nuclei_templates() {
    msg "Installing nuclei templates..."
    
    local templates_dir="${HOME}/nuclei-templates"
    
    if [[ -d "$templates_dir" ]]; then
        q git -C "$templates_dir" pull
    else
        q git clone https://github.com/projectdiscovery/nuclei-templates "$templates_dir"
    fi
    
    nuclei -update-templates 2>/dev/null || true
    
    msg_ok "Nuclei templates installed"
}

setup_configs() {
    msg "Setting up configuration directories..."
    
    mkdir -p "${HOME}/.gf"
    mkdir -p "${HOME}/.config/notify"
    mkdir -p "${HOME}/.config/subfinder"
    mkdir -p "${HOME}/.config/nuclei"
    mkdir -p "$TOOLS_DIR"
    
    touch "${TOOLS_DIR}/.github_tokens"
    touch "${TOOLS_DIR}/.gitlab_tokens"
    
    if [[ ! -f "${HOME}/.config/notify/provider-config.yaml" ]]; then
        wget -q "https://gist.githubusercontent.com/six2dez/23a996bca189a11e88251367e6583053/raw" \
            -O "${HOME}/.config/notify/provider-config.yaml" || true
    fi
    
    msg_ok "Configurations set up"
}

show_summary() {
    printf "\n${GREEN}======================================${RESET}\n"
    printf "${GREEN}    Installation Complete!${RESET}\n"
    printf "${GREEN}======================================${RESET}\n\n"
    
    printf "${YELLOW}Remember to configure:${RESET}\n"
    printf "  - subfinder: ${HOME}/.config/subfinder/provider-config.yaml\n"
    printf "  - GitHub tokens: ${TOOLS_DIR}/.github_tokens\n"
    printf "  - GitLab tokens: ${TOOLS_DIR}/.gitlab_tokens\n"
    printf "  - notify: ${HOME}/.config/notify/provider-config.yaml\n"
    printf "\n"
    printf "${CYAN}Tools directory: ${TOOLS_DIR}${RESET}\n"
    printf "${CYAN}Wordlists: ${TOOLS_DIR}/wordlists${RESET}\n"
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tools-only) TOOLS_ONLY=true; shift ;;
            --verbose|-v) VERBOSE=true; shift ;;
            --force|-f) FORCE=true; shift ;;
            --help|-h)
                printf "Usage: %s [--tools-only] [--verbose] [--force]\n" "$0"
                printf "\nOptions:\n"
                printf "  --tools-only  Only install tools (skip system packages)\n"
                printf "  --verbose     Show detailed output\n"
                printf "  --force       Force reinstall of existing tools\n"
                exit 0
                ;;
            *) msg_err "Unknown option: $1"; exit 1 ;;
        esac
    done
    
    check_root
    
    printf "\n${CYAN}╔════════════════════════════════════════╗${RESET}\n"
    printf "${CYAN}║     talosplus Tools Installer          ║${RESET}\n"
    printf "${CYAN}╚════════════════════════════════════════╝${RESET}\n\n"
    
    if [[ $TOOLS_ONLY != "true" ]]; then
        install_system_packages
    fi
    
    install_golang
    install_rust
    setup_configs
    install_go_tools
    install_pipx_tools
    install_repos
    install_wordlists
    install_nuclei_templates
    
    show_summary
}

main "$@"
