#!/bin/bash
# Talos Database Helper Functions
# Uses SQLite for storing recon data

DB_PATH="${TALOS_DB:-${HOME}/.talos/talos.db}"
SCHEMA_PATH="$(dirname "$0")/schema.sql"

db_init() {
    mkdir -p "$(dirname "$DB_PATH")"
    if [[ ! -f "$DB_PATH" ]]; then
        sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
        echo "[DB] Initialized database at $DB_PATH"
    fi
}

db_query() {
    sqlite3 -separator '|' "$DB_PATH" "$1"
}

db_exec() {
    sqlite3 "$DB_PATH" "$1"
}

scan_start() {
    local target="$1"
    local template="${2:-fullrecon}"
    local output_dir="$3"
    
    db_init
    db_exec "INSERT INTO scans (target, template, output_dir) VALUES ('$target', '$template', '$output_dir');"
    db_query "SELECT last_insert_rowid();"
}

scan_finish() {
    local scan_id="$1"
    local status="${2:-completed}"
    db_exec "UPDATE scans SET status='$status', finished_at=CURRENT_TIMESTAMP WHERE id=$scan_id;"
}

add_subdomains() {
    local scan_id="$1"
    local source="$2"
    local file="$3"
    
    if [[ ! -f "$file" ]]; then return 1; fi
    
    while IFS= read -r sub; do
        [[ -z "$sub" ]] && continue
        db_exec "INSERT OR IGNORE INTO subdomains (scan_id, subdomain, source) VALUES ($scan_id, '$sub', '$source');" 2>/dev/null
    done < "$file"
}

add_resolved_subdomain() {
    local scan_id="$1"
    local subdomain="$2"
    local ip="$3"
    local cdn="$4"
    
    db_exec "UPDATE subdomains SET resolved=1, ip='$ip', cdn='$cdn' WHERE scan_id=$scan_id AND subdomain='$subdomain';"
}

add_url() {
    local scan_id="$1"
    local url="$2"
    local status_code="$3"
    local title="$4"
    local source="$5"
    
    title=$(echo "$title" | sed "s/'/''/g")
    db_exec "INSERT OR IGNORE INTO urls (scan_id, url, status_code, title, source) VALUES ($scan_id, '$url', $status_code, '$title', '$source');" 2>/dev/null
}

add_urls_from_file() {
    local scan_id="$1"
    local source="$2"
    local file="$3"
    
    if [[ ! -f "$file" ]]; then return 1; fi
    
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        db_exec "INSERT OR IGNORE INTO urls (scan_id, url, source) VALUES ($scan_id, '$url', '$source');" 2>/dev/null
    done < "$file"
}

add_finding() {
    local scan_id="$1"
    local severity="$2"
    local type="$3"
    local name="$4"
    local url="$5"
    local host="$6"
    local matched="$7"
    local template_id="$8"
    local raw="$9"
    
    name=$(echo "$name" | sed "s/'/''/g")
    matched=$(echo "$matched" | sed "s/'/''/g")
    raw=$(echo "$raw" | sed "s/'/''/g")
    
    db_exec "INSERT INTO findings (scan_id, severity, type, name, url, host, matched, template_id, raw_output) VALUES ($scan_id, '$severity', '$type', '$name', '$url', '$host', '$matched', '$template_id', '$raw');"
}

parse_nuclei_json() {
    local scan_id="$1"
    local file="$2"
    
    if [[ ! -f "$file" ]]; then return 1; fi
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local severity=$(echo "$line" | jq -r '.info.severity // "unknown"')
        local name=$(echo "$line" | jq -r '.info.name // "unknown"')
        local template_id=$(echo "$line" | jq -r '."template-id" // ""')
        local host=$(echo "$line" | jq -r '.host // ""')
        local url=$(echo "$line" | jq -r '.matched // ""')
        local matched=$(echo "$line" | jq -r '.matcher_name // ""')
        
        add_finding "$scan_id" "$severity" "nuclei" "$name" "$url" "$host" "$matched" "$template_id" "$line"
    done < "$file"
}

add_port() {
    local scan_id="$1"
    local ip="$2"
    local port="$3"
    local service="$4"
    local version="$5"
    
    db_exec "INSERT OR IGNORE INTO ports (scan_id, ip, port, service, version) VALUES ($scan_id, '$ip', $port, '$service', '$version');" 2>/dev/null
}

add_js_secret() {
    local scan_id="$1"
    local url="$2"
    local secret_type="$3"
    local value="$4"
    
    value=$(echo "$value" | sed "s/'/''/g")
    db_exec "INSERT INTO js_secrets (scan_id, url, secret_type, value) VALUES ($scan_id, '$url', '$secret_type', '$value');"
}

get_scan_stats() {
    local scan_id="$1"
    
    echo "=== Scan #$scan_id Statistics ==="
    echo "Subdomains: $(db_query "SELECT COUNT(*) FROM subdomains WHERE scan_id=$scan_id;")"
    echo "Resolved: $(db_query "SELECT COUNT(*) FROM subdomains WHERE scan_id=$scan_id AND resolved=1;")"
    echo "URLs: $(db_query "SELECT COUNT(*) FROM urls WHERE scan_id=$scan_id;")"
    echo "Findings:"
    echo "  Critical: $(db_query "SELECT COUNT(*) FROM findings WHERE scan_id=$scan_id AND severity='critical';")"
    echo "  High: $(db_query "SELECT COUNT(*) FROM findings WHERE scan_id=$scan_id AND severity='high';")"
    echo "  Medium: $(db_query "SELECT COUNT(*) FROM findings WHERE scan_id=$scan_id AND severity='medium';")"
    echo "  Low: $(db_query "SELECT COUNT(*) FROM findings WHERE scan_id=$scan_id AND severity='low';")"
    echo "  Info: $(db_query "SELECT COUNT(*) FROM findings WHERE scan_id=$scan_id AND severity='info';")"
    echo "Ports: $(db_query "SELECT COUNT(*) FROM ports WHERE scan_id=$scan_id;")"
    echo "JS Secrets: $(db_query "SELECT COUNT(*) FROM js_secrets WHERE scan_id=$scan_id;")"
}

list_scans() {
    echo "ID|Target|Template|Status|Started|Finished"
    db_query "SELECT id, target, template, status, started_at, finished_at FROM scans ORDER BY id DESC LIMIT 20;"
}

get_findings() {
    local scan_id="$1"
    local severity="$2"
    
    if [[ -n "$severity" ]]; then
        db_query "SELECT severity, name, url FROM findings WHERE scan_id=$scan_id AND severity='$severity';"
    else
        db_query "SELECT severity, name, url FROM findings WHERE scan_id=$scan_id ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END;"
    fi
}

export_scan_json() {
    local scan_id="$1"
    local output="${2:-scan_${scan_id}.json}"
    
    cat > "$output" << EOF
{
  "scan": $(db_query "SELECT json_object('id', id, 'target', target, 'template', template, 'status', status, 'started_at', started_at, 'finished_at', finished_at) FROM scans WHERE id=$scan_id;"),
  "subdomains": $(db_query "SELECT json_group_array(json_object('subdomain', subdomain, 'resolved', resolved, 'ip', ip, 'cdn', cdn)) FROM subdomains WHERE scan_id=$scan_id;"),
  "urls": $(db_query "SELECT json_group_array(json_object('url', url, 'status_code', status_code, 'title', title)) FROM urls WHERE scan_id=$scan_id;"),
  "findings": $(db_query "SELECT json_group_array(json_object('severity', severity, 'type', type, 'name', name, 'url', url, 'template_id', template_id)) FROM findings WHERE scan_id=$scan_id;"),
  "ports": $(db_query "SELECT json_group_array(json_object('ip', ip, 'port', port, 'service', service)) FROM ports WHERE scan_id=$scan_id;")
}
EOF
    echo "Exported to $output"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        init) db_init ;;
        start) scan_start "$2" "$3" "$4" ;;
        finish) scan_finish "$2" "$3" ;;
        stats) get_scan_stats "$2" ;;
        list) list_scans ;;
        findings) get_findings "$2" "$3" ;;
        export) export_scan_json "$2" "$3" ;;
        query) db_query "$2" ;;
        *)
            echo "Talos Database CLI"
            echo "Usage: $0 <command> [args]"
            echo ""
            echo "Commands:"
            echo "  init              Initialize database"
            echo "  start <target>    Start new scan, returns scan_id"
            echo "  finish <id>       Mark scan as complete"
            echo "  stats <id>        Show scan statistics"
            echo "  list              List recent scans"
            echo "  findings <id>     Show findings for scan"
            echo "  export <id>       Export scan to JSON"
            echo "  query <sql>       Run raw SQL query"
            ;;
    esac
fi
