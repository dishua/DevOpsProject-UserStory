#!/bin/sh
set -eu

# Verify required environment variables
: "${DB_IP:?DB_IP environment variable is required}"
: "${DB_USERSTORYPROJ_USER:?DB_USERSTORYPROJ_USER environment variable is required}"
: "${DB_USERSTORYPROJ_PASSWORD:?DB_USERSTORYPROJ_PASSWORD environment variable is required}"

echo "=== Installing OpenJDK 17, Maven, and Git ==="
apk add --no-cache openjdk17 maven git

echo "=== Fetching Repository ==="
REPO_URL="https://github.com/dishua/DevOpsProject-UserStory.git"
TARGET_DIR="/tmp/backend_repo"

rm -rf "$TARGET_DIR"
git clone --depth=1 --filter=blob:none --sparse -b master "$REPO_URL" "$TARGET_DIR"

cd "$TARGET_DIR"
git sparse-checkout set backend

echo "=== Building Backend ==="
cd "$TARGET_DIR/backend"
mvn clean package -DskipTests

echo "=== Deploying Application ==="
mkdir -p /opt/backend /var/log/backend

JAR_FILE=$(find target -name "*.jar" ! -name "*original*" | head -n 1)

if [ -z "$JAR_FILE" ]; then
  echo "Error: No JAR file found in target directory." >&2
  exit 1
fi

cp "$JAR_FILE" /opt/backend/app.jar

rm -rf "$TARGET_DIR"

echo "=== Configuring OpenRC Service ==="
cat<<EOF > /etc/conf.d/backend
export  DB_USERSTORYPROJ_URL="jdbc:mariadb://${DB_IP}:3306/userstoryproj"
export  DB_USERSTORYPROJ_USER="${DB_USERSTORYPROJ_USER}"
export  DB_USERSTORYPROJ_PASSWORD="${DB_USERSTORYPROJ_PASSWORD}"
EOF

cat <<'EOF' > /etc/init.d/backend
#!/sbin/openrc-run

name="backend"
description="UserStory SpringBoot Backend Service"
command="/usr/bin/java"
command_args="-jar /opt/backend/app.jar"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/backend.log"
error_log="/var/log/backend.log"

depend() {
    need net
}
EOF

chmod +x /etc/init.d/backend


echo "=== Starting Backend Service ==="
rc-update add backend default'

if rc-service backend status >/dev/null 2>&1; then
  rc-service backend restart
else
  rc-service backend start
fi

echo "=== Backend Setup Complete ==="