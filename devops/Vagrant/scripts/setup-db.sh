#!/bin/sh
set -e

echo "=== Installing MariaDB Server ==="
apk add --no-cache mariadb mariadb-client

cat << 'EOF' > /etc/my.cnf.d/mariadb-server.cnf
[server]

[mysqld]
# Allow server to accept connections on all interfaces
bind-address = 0.0.0.0

[galera]

[embedded]
EOF

# Initialize database storage directory if initializing for the first time
if [ ! -d "/var/lib/mysql/mysql" ]; then
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

echo "=== Starting MariaDB Service ==="
rc-update add mariadb default
rc-service mariadb start

echo "=== Configuring Database Users ==="
mariadb -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS userstoryproj;
CREATE USER IF NOT EXISTS '${DB_USERSTORYPROJ_USER}'@'%' IDENTIFIED BY '${DB_USERSTORYPROJ_PASSWORD}';
GRANT ALL PRIVILEGES ON userstoryproj.* TO '${DB_USERSTORYPROJ_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo "=== MariaDB setup complete ==="