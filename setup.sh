#!/bin/bash

PROJETO_DIR="$HOME/cluster-balanceado"

echo "=========================================================="
echo " CLUSTER NGINX LOAD BALANCER (Porta 8090)"
echo "=========================================================="

# 1. Verificação de ambiente
if ! docker info >/dev/null 2>&1; then
    echo "[!] Docker não detectado. Inicie o Docker Desktop (Windows) ou o daemon do Docker."
    exit 1
fi

# 2. Instalação do Plugin Docker Compose (se necessário)
if ! docker compose version >/dev/null 2>&1; then
    echo "[*] Instalando Docker Compose Plugin..."
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

# 3. Preparação
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,srv1,srv2,srv3}
cd "$PROJETO_DIR" || exit

# 4. Criando arquivos de status
echo '{"servidor":"Servidor 01","cor":"#22c55e"}' > srv1/status.json
echo '{"servidor":"Servidor 02","cor":"#3b82f6"}' > srv2/status.json
echo '{"servidor":"Servidor 03","cor":"#f59e0b"}' > srv3/status.json

# 5. Frontend (Monitoramento em tempo real)
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>LB 8090 Monitor</title>
<style>
body{background:#0f172a;color:#fff;font-family:sans-serif;text-align:center;padding-top:50px;}
.card{display:inline-block;padding:20px;background:#1e293b;border-radius:10px;}
</style>
</head>
<body>
<div class="card">
    <h1 id="status">Conectando...</h1>
    <p>Srv1: <span id="c1">0</span> | Srv2: <span id="c2">0</span> | Srv3: <span id="c3">0</span></p>
</div>
<script>
    let counts = {"Servidor 01": 0, "Servidor 02": 0, "Servidor 03": 0};
    async function update() {
        try {
            const r = await fetch('/api/status?t=' + Date.now());
            const d = await r.json();
            document.getElementById("status").innerText = d.servidor;
            document.getElementById("status").style.color = d.cor;
            counts[d.servidor]++;
            document.getElementById("c1").innerText = counts["Servidor 01"];
            document.getElementById("c2").innerText = counts["Servidor 02"];
            document.getElementById("c3").innerText = counts["Servidor 03"];
        } catch(e) { document.getElementById("status").innerText = "OFFLINE"; }
    }
    setInterval(update, 500);
</script>
</body>
</html>
EOF

# 6. Configuração Nginx (Upstream com max_fails)
cat > nginx/conf.d/loadbalancer.conf <<EOF
upstream cluster {
    server srv1:80 max_fails=1 fail_timeout=1s;
    server srv2:80 max_fails=1 fail_timeout=1s;
    server srv3:80 max_fails=1 fail_timeout=1s;
}
server {
    listen 8090;
    location / { root /usr/share/nginx/html; }
    location /api/status { proxy_pass http://cluster/status.json; proxy_connect_timeout 0.5s; }
}
EOF

# 7. Docker Compose (Nomes fixos para evitar conflito)
cat > docker-compose.yml <<EOF
services:
  srv1: { image: nginx:alpine, container_name: srv1, volumes: ["./srv1:/usr/share/nginx/html"] }
  srv2: { image: nginx:alpine, container_name: srv2, volumes: ["./srv2:/usr/share/nginx/html"] }
  srv3: { image: nginx:alpine, container_name: srv3, volumes: ["./srv3:/usr/share/nginx/html"] }
  balanceador:
    image: nginx:alpine
    container_name: balanceador
    ports: ["8090:8090"]
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./frontend:/usr/share/nginx/html
EOF

# 8. Menu de Gestão
echo "[+] Iniciando cluster..."
sudo docker compose down --remove-orphans
sudo docker compose up -d

while true; do
    echo "------------------------------------"
    echo "GESTÃO DO CLUSTER (Acesse http://localhost:8090)"
    echo "1) Parar servidor 1 | 2) Iniciar servidor 1"
    echo "3) Parar servidor 2 | 4) Iniciar servidor 2"
    echo "5) Parar servidor 3 | 6) Iniciar servidor 3"
    echo "7) Sair do menu (Cluster continua rodando)"
    read -p "Escolha: " opt
    case $opt in
        1) sudo docker compose stop srv1 ;;
        2) sudo docker compose start srv1 ;;
        3) sudo docker compose stop srv2 ;;
        4) sudo docker compose start srv2 ;;
        5) sudo docker compose stop srv3 ;;
        6) sudo docker compose start srv3 ;;
        7) break ;;
    esac
done
