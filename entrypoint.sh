#!/bin/sh
set -e

echo "Génération de la config runtime..."
cat <<EOF > /usr/share/nginx/html/assets/env.js
window.env = {
  AUTH_URL: "${AUTH_URL}",
  FRIENDS_URL: "${FRIENDS_URL}",
  MESSAGES_URL: "${MESSAGES_URL}",
  TEAMS_URL: "${TEAMS_URL}"
};
EOF

exec nginx -g 'daemon off;'
