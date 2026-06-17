#!/bin/bash

# Diretório do projeto
PROJETO_DIR="$HOME/cluster-balanceado"

echo "=========================================================="
echo " CONFIGURANDO CLUSTER NGINX (LB 8090) - REESTRUTURADO"
echo "=========================================================="

# 1. Instalar Docker e Docker Compose Plugin se não existirem
if ! command -v docker &> /dev/null; then
    echo "[*] Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
fi

if ! docker compose version &> /dev/null; then
    echo "[*] Instalando Docker Compose Plugin..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
fi

# 2. Aguardar Docker estar pronto (Crucial para WSL)
echo "[*] Verificando conexão com Docker..."
timeout=20
while ! docker info >/dev/null 2>&1; do
    echo "    Aguardando o Docker Desktop iniciar (no Windows)..."
    sleep 2
    ((timeout--))
    if [ $timeout -le 0 ]; then
        echo "[!] Erro: Docker não está respondendo. Verifique o Docker Desktop."
        exit 1
    fi
done

# 3. Preparação do ambiente
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,srv1,srv2,srv3}
cd "$PROJETO_DIR" || exit

# 4. Limpeza (Evita erro de Conflict)
echo "[*] Limpando instâncias anteriores..."
docker compose down --remove-orphans >/dev/null 2>&1

# 5. Criando arquivos de status
echo '{"servidor":"Servidor 01","cor":"#22c55e"}' > srv1/status.json
echo '{"servidor":"Servidor 02","cor":"#3b82f6"}' > srv2/status.json
echo '{"servidor":"Servidor 03","cor":"#f59e0b"}' > srv3/status.json

# 6. Frontend de Monitoramento
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

# 7. Configuração Nginx (Conforme o seu quadro)
cat > nginx/conf.d/loadbalancer.conf <<EOF
upstream cluster {
    server srv1:80;
    server srv2:80;
    server srv3:80;
}
server {
    listen 8090;
    location / { root /usr/share/nginx/html; }
    location /api/status { proxy_pass http://cluster/status.json; }
}
EOF

# 8. Docker Compose
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

# 9. Iniciar
echo "[*] Subindo cluster..."
docker compose up -d

echo "=========================================================="
echo " CONFIGURAÇÃO FINALIZADA!"
echo " Acesse: http://localhost:8090"
echo "=========================================================="
