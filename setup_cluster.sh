#!/bin/bash

PROJETO_DIR="$HOME/cluster-balanceado"

echo "================================================="
echo "   SISTEMA DE BALANCEAMENTO DE CARGA RESILIENTE  "
echo "================================================="

# 1. Checagem de Docker no WSL
if ! docker info >/dev/null 2>&1; then
    echo "[!] Docker não está respondendo. Por favor, certifique-se que o Docker Desktop (Windows) está aberto ou que o serviço está ativo."
    exit 1
fi

# 2. Instalação automática do Docker Compose Plugin
if ! docker compose version >/dev/null 2>&1; then
    echo "[*] Instalando Docker Compose Plugin..."
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

# 3. Preparação das Pastas e Limpeza
echo "[*] Preparando diretórios e removendo conflitos..."
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,srv1,srv2,srv3}
cd "$PROJETO_DIR" || exit
sudo docker compose down --remove-orphans >/dev/null 2>&1

# 4. Criando Arquivos de Status
echo '{"servidor":"Servidor Web 01","cor":"#22c55e"}' > srv1/status.json
echo '{"servidor":"Servidor Web 02","cor":"#3b82f6"}' > srv2/status.json
echo '{"servidor":"Servidor Web 03","cor":"#f59e0b"}' > srv3/status.json

# 5. Frontend com persistência de contagem
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head><meta charset="UTF-8"><title>Cluster Dashboard</title>
<style>
    body{background:#0f172a;color:#fff;font-family:sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;}
    .card{padding:30px;background:#1e293b;border-radius:15px;text-align:center;width:400px;}
    .counter{font-size:24px;font-weight:bold;margin:10px 0;}
</style>
</head>
<body>
<div class="card">
    <h1 id="status">Conectando...</h1>
    <div id="contadores">
        <p>Srv1: <span id="c1">0</span> | Srv2: <span id="c2">0</span> | Srv3: <span id="c3">0</span></p>
    </div>
</div>
<script>
    let counts = { "Servidor Web 01": 0, "Servidor Web 02": 0, "Servidor Web 03": 0 };
    async function update() {
        try {
            const r = await fetch('/api/status?t=' + Date.now());
            const d = await r.json();
            document.getElementById("status").innerText = d.servidor;
            document.getElementById("status").style.color = d.cor;
            counts[d.servidor]++;
            document.getElementById("c1").innerText = counts["Servidor Web 01"];
            document.getElementById("c2").innerText = counts["Servidor Web 02"];
            document.getElementById("c3").innerText = counts["Servidor Web 03"];
        } catch(e) { document.getElementById("status").innerText = "Servidor Offline"; }
    }
    setInterval(update, 800);
</script>
</body>
</html>
EOF

# 6. Nginx Config
cat > nginx/conf.d/loadbalancer.conf <<EOF
upstream cluster {
    server srv1:80 max_fails=1 fail_timeout=1s;
    server srv2:80 max_fails=1 fail_timeout=1s;
    server srv3:80 max_fails=1 fail_timeout=1s;
}
server {
    listen 8080;
    location / { root /usr/share/nginx/html; }
    location /api/status { proxy_pass http://cluster/status.json; proxy_connect_timeout 0.5s; }
}
EOF

# 7. Docker Compose
cat > docker-compose.yml <<EOF
services:
  srv1: { image: nginx:alpine, container_name: srv1, volumes: ["./srv1:/usr/share/nginx/html"] }
  srv2: { image: nginx:alpine, container_name: srv2, volumes: ["./srv2:/usr/share/nginx/html"] }
  srv3: { image: nginx:alpine, container_name: srv3, volumes: ["./srv3:/usr/share/nginx/html"] }
  balanceador:
    image: nginx:alpine
    container_name: balanceador
    ports: ["8080:8080"]
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./frontend:/usr/share/nginx/html
EOF

# 8. Execução
sudo docker compose up -d
echo "[+] Sucesso! Acesse http://localhost:8080"
