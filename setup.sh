#!/bin/bash

# Define o local do projeto
PROJETO_DIR="$HOME/servico-balanceamento"

echo "================================================="
echo "   SERVICO DE BALANCEAMENTO (Correção Ubuntu 24)"
echo "   Ubuntu WSL + Docker & Docker Compose Plugin   "
echo "================================================="

sleep 2

echo "[1/8] Removendo pacotes antigos ou mal configurados..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null
sudo rm -f /etc/apt/sources.list.d/docker.list

echo "[2/8] Instalando Docker via Script Oficial (Evita erro de GPG no Ubuntu Noble)..."
sudo apt update -y
sudo apt install -y curl

# Script oficial do Docker que detecta e configura as chaves GPG perfeitamente para o Ubuntu 24.04
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo "[3/8] Iniciando o serviço do Docker..."
# Comandos alternativos para garantir que o daemon do Docker suba no ambiente WSL
sudo service docker start
sleep 3

echo "[4/8] Criando estrutura de arquivos..."
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,servidor1,servidor2,servidor3}
cd "$PROJETO_DIR" || exit

echo "[5/8] Criando paginas dos servidores..."
echo '{"servidor":"Servidor 1","cor":"#22c55e"}' > servidor1/status.json
echo '{"servidor":"Servidor 2","cor":"#3b82f6"}' > servidor2/status.json
echo '{"servidor":"Servidor 3","cor":"#f59e0b"}' > servidor3/status.json

echo "[6/8] Criando frontend com contador de carga..."
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <title>Monitoramento de Balanceamento</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box;font-family:Arial,sans-serif;}
        body{background:#0f172a;height:100vh;display:flex;flex-direction:column;justify-content:center;align-items:center;color:white;}
        .card{width:600px;padding:40px;text-align:center;border-radius:20px;background:rgba(255,255,255,.05);backdrop-filter:blur(15px);box-shadow: 0 4px 30px rgba(0,0,0,0.5);}
        h1{font-size: 2.5rem; margin-bottom: 20px;}
        .stats {margin-top: 30px; display: flex; justify-content: space-around; border-top: 1px solid #334155; padding-top: 20px;}
        .stat-box {padding: 10px; border-radius: 8px; background: #1e293b; width: 30%;}
        .stat-count {font-size: 1.8rem; font-weight: bold; margin-top: 5px;}
        #alerta {color:#ef4444; margin-top: 20px; font-size: 16px; font-weight: bold;}
    </style>
</head>
<body>

<div class="card">
    <p style="color: #94a3b8; text-transform: uppercase; letter-spacing: 1px;">Requisição enviada ao Balanceador:</p>
    <h1 id="serverName">Conectando...</h1>
    
    <div id="alerta"></div>

    <div class="stats">
        <div class="stat-box" style="border-bottom: 4px solid #22c55e;">
            <div>Servidor 1</div>
            <div class="stat-count" id="count-servidor1" style="color: #22c55e;">0</div>
        </div>
        <div class="stat-box" style="border-bottom: 4px solid #3b82f6;">
            <div>Servidor 2</div>
            <div class="stat-count" id="count-servidor2" style="color: #3b82f6;">0</div>
        </div>
        <div class="stat-box" style="border-bottom: 4px solid #f59e0b;">
            <div>Servidor 3</div>
            <div class="stat-count" id="count-servidor3" style="color: #f59e0b;">0</div>
        </div>
    </div>
</div>

<script>
const contadores = {
    "Servidor 1": 0,
    "Servidor 2": 0,
    "Servidor 3": 0
};

async function fazerRequisicaoBalancada(){
    const serverEl = document.getElementById("serverName");
    const alertaEl = document.getElementById("alerta");

    try {
        const r = await fetch("/api/status?cache=" + Date.now());
        if(!r.ok) throw new Error("Erro de resposta");
        
        const d = await r.json();
        
        serverEl.innerText = d.servidor;
        serverEl.style.color = d.cor;
        alertaEl.innerText = ""; 

        if(contadores[d.servidor] !== undefined) {
            contadores[d.servidor]++;
            const idBuscar = "count-" + d.servidor.toLowerCase().replace(" ", "");
            document.getElementById(idBuscar).innerText = contadores[d.servidor];
        }

    } catch(e) { 
        serverEl.innerText = "ERRO DE CONEXÃO";
        serverEl.style.color = "#ef4444";
        alertaEl.innerText = "⚠ Nenhum servidor respondeu a tempo."; 
    }
}

setInterval(fazerRequisicaoBalancada, 1000);
fazerRequisicaoBalancada();
</script>
</body>
</html>
EOF

echo "[7/8] Criando configuracao do Nginx Load Balancer..."
cat > nginx/conf.d/loadbalancer.conf <<EOF
upstream grupo_servidores {
    server servidor1:80 max_fails=1 fail_timeout=2s;
    server servidor2:80 max_fails=1 fail_timeout=2s;
    server servidor3:80 max_fails=1 fail_timeout=2s;
}

server {
    listen 8090;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /api/status {
        proxy_pass http://grupo_servidores/status.json;
        proxy_connect_timeout 1s;
        proxy_read_timeout 1s;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "[8/8] Criando docker-compose.yml..."
cat > docker-compose.yml <<EOF
services:
  servidor1:
    image: nginx:alpine
    container_name: servidor1
    volumes:
      - ./servidor1:/usr/share/nginx/html
  servidor2:
    image: nginx:alpine
    container_name: servidor2
    volumes:
      - ./servidor2:/usr/share/nginx/html
  servidor3:
    image: nginx:alpine
    container_name: servidor3
    volumes:
      - ./servidor3:/usr/share/nginx/html
  balanceador:
    image: nginx:alpine
    container_name: balanceador
    ports:
      - "8090:8090"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./frontend:/usr/share/nginx/html
EOF

echo "Iniciando os containers..."
# Remove o script temporário do instalador do docker
rm -f get-docker.sh

# Executa o compose usando a ferramenta nativa instalada pelo script
sudo docker compose down --remove-orphans
sudo docker compose up -d

echo "========================================================"
echo " Concluído! O Docker foi instalado com sucesso via script oficial."
echo " Acesse no seu navegador: http://localhost:8090/"
echo "========================================================"
