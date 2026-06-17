#!/bin/bash

# Define o local do projeto
PROJETO_DIR="$HOME/servico-balanceamento"

echo "==========================================="
echo " SERVICO DE BALANCEAMENTO (Interativo)"
echo " Ubuntu WSL + Docker"
echo "==========================================="

sleep 2

echo "[1/8] Atualizando e instalando dependencias..."
sudo apt update -y
sudo apt install -y docker.io curl git

echo "[3/8] Iniciando Docker..."
sudo service docker start

echo "[4/8] Criando estrutura..."
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,servidor1,servidor2,servidor3}
cd "$PROJETO_DIR" || exit

echo "[5/8] Criando paginas dos servidores..."
echo '{"servidor":"Servidor 1","cor":"#22c55e"}' > servidor1/status.json
echo '{"servidor":"Servidor 2","cor":"#3b82f6"}' > servidor2/status.json
echo '{"servidor":"Servidor 3","cor":"#f59e0b"}' > servidor3/status.json

echo "[6/8] Criando frontend com contador..."
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
    <p style="color: #94a3b8; text-transform: uppercase; letter-spacing: 1px;">Última requisição respondida por:</p>
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
// Contadores locais de requisições recebidas de cada servidor
const contadores = {
    "Servidor 1": 0,
    "Servidor 2": 0,
    "Servidor 3": 0
};

async function fazerRequisicaoBalancada(){
    const serverEl = document.getElementById("serverName");
    const alertaEl = document.getElementById("alerta");

    try {
        // Bate na rota única do balanceador. O Nginx vai decidir quem responde.
        const r = await fetch("/api/status?cache=" + Date.now());
        if(!r.ok) throw new Error("Erro no servidor");
        
        const d = await r.json();
        
        // Atualiza a tela com o servidor que respondeu agora
        serverEl.innerText = d.servidor;
        serverEl.style.color = d.cor;
        alertaEl.innerText = ""; 

        // Incrementa o contador do servidor que respondeu
        if(contadores[d.servidor] !== undefined) {
            contadores[d.servidor]++;
            const idBuscar = "count-" + d.servidor.toLowerCase().replace(" ", "");
            document.getElementById(idBuscar).innerText = contadores[d.servidor];
        }

    } catch(e) { 
        serverEl.innerText = "FALHA NO BALANCEADOR";
        serverEl.style.color = "#ef4444";
        alertaEl.innerText = "⚠ Não foi possível obter resposta de nenhum servidor ativo."; 
    }
}

// Faz requisições rápidas a cada 1 segundo para ver o balanceamento acontecer em tempo real
setInterval(fazerRequisicaoBalancada, 1000);
fazerRequisicaoBalancada();
</script>
</body>
</html>
EOF

echo "[7/8] Criando configuração de Load Balancer do Nginx..."
cat > nginx/conf.d/loadbalancer.conf <<EOF
# Define o grupo de servidores para balanceamento (Round Robin padrão)
upstream meus_servidores {
    server servidor1:80 max_fails=1 fail_timeout=2s;
    server servidor2:80 max_fails=1 fail_timeout=2s;
    server servidor3:80 max_fails=1 fail_timeout=2s;
}

server {
    listen 8090;

    # Serve o Frontend estático
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    # Rota da API que distribui a carga entre os servidores do upstream
    location /api/status {
        proxy_pass http://meus_servidores/status.json;
        proxy_connect_timeout 1s;
        proxy_read_timeout 1s;
        
        # Passa cabeçalhos importantes para os servidores saberem a origem do tráfego
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "[8/8] Criando docker-compose..."
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

echo "Subindo containers..."
sudo docker compose down
sudo docker compose up -d

echo "========================================================"
echo " INSTALADO COM SUCESSO!"
echo " Acesse: http://localhost:8090/"
echo " "
echo " O que mudou:"
echo " 1. O Nginx agora usa 'upstream' para balancear de verdade."
echo " 2. A requisição vai sempre para a mesma URL (/api/status)."
echo " 3. A tela mostra o contador de requisições de cada servidor."
echo " "
echo " TESTE DE QUEDA: rode 'sudo docker compose stop servidor2'"
echo " Veja que o contador do Servidor 2 para, mas os outros continuam!"
echo "========================================================"
