#!/usr/bin/env bash

# Use a heredoc with a quoted delimiter to write the literal string to the file
cat <<'EOF' > inventory.ini
[Nodes]
%{ for addr in ip_addrs ~}
${addr}
%{ endfor ~}
EOF