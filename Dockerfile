FROM archlinux:latest

LABEL maintainer="1hehaq"
LABEL description="talos runs with talosplus"

ENV GOPATH=/root/go
ENV CARGOPATH=/root/.cargo/bin
ENV PATH="${GOPATH}/bin:${CARGOPATH}:/root/.local/bin:/usr/local/bin:${PATH}"

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
        base-devel git go rust python python-pip python-pipx \
        curl wget jq bind whois nmap libpcap openssl \
        libffi libxml2 libxslt zlib zip unzip cmake gcc make ruby && \
    pacman -Scc --noconfirm

RUN mkdir -p /opt/tools /opt/wordlists /root/.gf /root/.config/notify /root/.config/subfinder /data

WORKDIR /opt/talosplus

COPY . .

RUN go install github.com/tarunKoyalwar/talosplus/cmd/talosplus@latest

RUN mkdir -p /opt/talosplus/templates && \
    wget -q "https://raw.githubusercontent.com/1hehaq/talos/main/templates/installtools.sh" -O /opt/talosplus/templates/installtools.sh && \
    wget -q "https://raw.githubusercontent.com/1hehaq/talos/main/templates/fullrecon.sh" -O /opt/talosplus/templates/fullrecon.sh && \
    wget -q "https://raw.githubusercontent.com/1hehaq/talos/main/templates/hostscan.sh" -O /opt/talosplus/templates/hostscan.sh && \
    wget -q "https://raw.githubusercontent.com/1hehaq/talos/main/templates/osint.sh" -O /opt/talosplus/templates/osint.sh && \
    wget -q "https://raw.githubusercontent.com/1hehaq/talos/main/templates/passiveonly.sh" -O /opt/talosplus/templates/passiveonly.sh && \
    wget -q "https://raw.githubusercontent.com/1hehaq/talos/main/templates/quickrecon.sh" -O /opt/talosplus/templates/quickrecon.sh && \
    wget -q "https://raw.githubusercontent.com/1hehaq/talos/main/templates/subenum.sh" -O /opt/talosplus/templates/subenum.sh && \
    wget -q "https://raw.githubusercontent.com/1hehaq/talos/main/templates/vulnscan.sh" -O /opt/talosplus/templates/vulnscan.sh && \
    wget -q "https://raw.githubusercontent.com/1hehaq/talos/main/templates/webanalys.sh" -O /opt/talosplus/templates/webanalys.sh

RUN wget -q "https://gist.github.com/six2dez/a307a04a222fab5a57466c51e1569acf/raw" -O /opt/wordlists/subdomains.txt && \
    wget -q "https://raw.githubusercontent.com/n0kovo/n0kovo_subdomains/main/n0kovo_subdomains_huge.txt" -O /opt/wordlists/subdomains_big.txt && \
    wget -q "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" -O /opt/wordlists/resolvers.txt && \
    wget -q "https://gist.githubusercontent.com/six2dez/ae9ed7e5c786461868abd3f2344401b6/raw" -O /opt/wordlists/resolvers_trusted.txt && \
    wget -q "https://raw.githubusercontent.com/six2dez/OneListForAll/main/onelistforallmicro.txt" -O /opt/wordlists/fuzz.txt && \
    wget -q "https://gist.githubusercontent.com/six2dez/a89a0c7861d49bb61a09822d272d5395/raw" -O /opt/wordlists/lfi.txt && \
    wget -q "https://gist.githubusercontent.com/six2dez/ab5277b11da7369bf4e9db72b49ad3c1/raw" -O /opt/wordlists/ssti.txt && \
    wget -q "https://gist.github.com/six2dez/ffc2b14d283e8f8eff6ac83e20a3c4b4/raw" -O /opt/wordlists/permutations.txt

WORKDIR /data

ENTRYPOINT ["/bin/bash", "-c", "talosplus run installtools.sh && exec talosplus run fullrecon.sh \"$@\"", "--"]
CMD ["--help"]