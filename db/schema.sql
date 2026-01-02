CREATE TABLE IF NOT EXISTS scans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    target TEXT NOT NULL,
    template TEXT NOT NULL,
    status TEXT DEFAULT 'running',
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME,
    output_dir TEXT
);

CREATE TABLE IF NOT EXISTS subdomains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_id INTEGER NOT NULL,
    subdomain TEXT NOT NULL,
    source TEXT,
    resolved INTEGER DEFAULT 0,
    ip TEXT,
    cdn TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (scan_id) REFERENCES scans(id),
    UNIQUE(scan_id, subdomain)
);

CREATE TABLE IF NOT EXISTS urls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_id INTEGER NOT NULL,
    url TEXT NOT NULL,
    status_code INTEGER,
    title TEXT,
    tech TEXT,
    source TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (scan_id) REFERENCES scans(id),
    UNIQUE(scan_id, url)
);

CREATE TABLE IF NOT EXISTS findings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_id INTEGER NOT NULL,
    severity TEXT NOT NULL,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    url TEXT,
    host TEXT,
    matched TEXT,
    template_id TEXT,
    raw_output TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (scan_id) REFERENCES scans(id)
);

CREATE TABLE IF NOT EXISTS ports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_id INTEGER NOT NULL,
    ip TEXT NOT NULL,
    port INTEGER NOT NULL,
    service TEXT,
    version TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (scan_id) REFERENCES scans(id),
    UNIQUE(scan_id, ip, port)
);

CREATE TABLE IF NOT EXISTS js_secrets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_id INTEGER NOT NULL,
    url TEXT NOT NULL,
    secret_type TEXT,
    value TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (scan_id) REFERENCES scans(id)
);

CREATE INDEX IF NOT EXISTS idx_subdomains_scan ON subdomains(scan_id);
CREATE INDEX IF NOT EXISTS idx_urls_scan ON urls(scan_id);
CREATE INDEX IF NOT EXISTS idx_findings_scan ON findings(scan_id);
CREATE INDEX IF NOT EXISTS idx_findings_severity ON findings(severity);
CREATE INDEX IF NOT EXISTS idx_ports_scan ON ports(scan_id);
