#!/bin/bash

# Define o local do projeto
PROJETO_DIR="$HOME/cluster-balanceado"

echo "=========================================================="
echo " CONFIGURANDO CLUSTER NGINX (Porta 8090)"
echo "=========================================================="

# 1. Verifica se o Docker está acessível
if ! docker info >/dev/null 2>&1; then
    echo "[ERRO] Docker não está rodando no WSL."
    echo "Dica: Abra o Docker Desktop no Windows e ative a integração WSL."
    exit 1
fi

# 2. Prepara diretórios
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,srv1,srv2,srv3}
cd "$PROJETO_DIR" || exit

# 3. Limpa containers antigos para evitar conflitos (Mitigação de erro)
docker compose down --remove-orphans > /dev/null 2>&1

# 4. Cria os arquivos de status dos servidores
echo '{"servidor":"Servidor 01","cor":"#22c55e"}' > srv1/status.json
echo '{"servidor":"Servidor 02","cor":"#3b82f6"}' > srv2/status.json
echo '{"servidor":"Servidor 03","cor":"#f59e0b"}' > srv3/status.json

# 5. Cria o Frontend
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>LB 8090 - Monitor</title>
<style>
body{background:#0f172a;color:#fff;font-family:sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;}
.card{padding:30px;background:#1e293b;border-radius:15px;text-align:center;}
</style>
</head>
<body>
<div class="card">
    <h1 id="status">Monitorando...</h1>
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

# 6. Configuração Nginx (Porta 8090)
cat > nginx/conf.d/loadbalancer.conf <<EOF
upstream cluster {
    server srv1:80 max_fails=1 fail_timeout=1s;
    server srv2:80 max_fails=1 fail_timeout=1s;
    server srv3:80 max_fails=1 fail_timeout=1s;
}
server {
    listen 8090;
    location / { root /usr/share/nginx/html; index index.html; }
    location /api/status { proxy_pass http://cluster/status.json; }
}
EOF

# 7. Arquivo Docker Compose
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

# 8. Inicia tudo
docker compose up -d

echo "=========================================================="
echo " CLUSTER ATIVO NA PORTA 8090"
echo " Acesse: http://localhost:8090"
echo "=========================================================="
