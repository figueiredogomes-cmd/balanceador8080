#!/bin/bash

PROJETO_DIR="$HOME/cluster-balanceado"

echo "=========================================================="
echo " CONFIGURANDO CLUSTER RESILIENTE (Nginx Load Balancer)"
echo "=========================================================="

# 1. Validação de Docker
if ! docker info >/dev/null 2>&1; then
    echo "[ERRO] Docker não está rodando no seu WSL/Ubuntu."
    echo "Dica: Abra o Docker Desktop no Windows e certifique-se que a integração está ativa."
    exit 1
fi

# 2. Instalação do Docker Compose Plugin
if ! docker compose version >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

# 3. Preparação do ambiente
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,srv1,srv2,srv3}
cd "$PROJETO_DIR" || exit

# 4. Limpeza total de conflitos (para não dar erro de container existente)
docker compose down --remove-orphans >/dev/null 2>&1

# 5. Criando arquivos de status dos servidores
echo '{"servidor":"Servidor 01","cor":"#22c55e"}' > srv1/status.json
echo '{"servidor":"Servidor 02","cor":"#3b82f6"}' > srv2/status.json
echo '{"servidor":"Servidor 03","cor":"#f59e0b"}' > srv3/status.json

# 6. Criando Dashboard com persistência de contagem
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Monitor 8090</title>
<style>
body{background:#0f172a;color:#fff;font-family:sans-serif;text-align:center;padding:50px;}
.box{display:inline-block;padding:20px;background:#1e293b;border-radius:10px;}
</style>
</head>
<body>
<div class="box">
    <h1 id="status">Monitorando...</h1>
    <p>Srv1: <span id="c1">0</span> | Srv2: <span id="c2">0</span> | Srv3: <span id="c3">0</span></p>
</div>
<script>
    let counts = {"Servidor 01":0, "Servidor 02":0, "Servidor 03":0};
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

# 7. Configuração Nginx (O "Segredo" do Load Balancer)
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

# 8. Configuração do Docker Compose
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

# 9. Execução Automática
docker compose up -d

echo "=========================================================="
echo " CLUSTER RODANDO! ACESSE: http://localhost:8090"
echo " Comandos disponíveis nesta pasta:"
echo " - Parar cluster: docker compose stop"
echo " - Subir cluster: docker compose up -d"
echo " - Parar servidor 1: docker compose stop srv1"
echo "=========================================================="
