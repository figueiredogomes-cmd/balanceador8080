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
echo '{"servidor":"Servidor1","cor":"#22c55e"}' > servidor1/status.json
echo '{"servidor":"Servidor2","cor":"#3b82f6"}' > servidor2/status.json
echo '{"servidor":"Servidor3","cor":"#f59e0b"}' > servidor3/status.json

echo "[6/8] Criando frontend..."
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head><meta charset="UTF-8"><title>Monitoramento de Servidores</title>
<style>
  *{margin:0;padding:0;box-sizing:border-box;font-family:Arial,sans-serif;}
  body{background:#0f172a;height:100vh;display:flex;justify-content:center;align-items:center;color:white;}
  .card{width:700px;padding:50px;text-align:center;border-radius:30px;background:rgba(255,255,255,.08);backdrop-filter:blur(15px);}
</style>
</head>
<body>
<div class="card">
    <h1 id="serverName">Carregando...</h1>
    <div id="alerta" style="color:#ef4444; margin-top: 20px; font-size: 20px;"></div>
</div>
<script>
const servidores = ["servidor1", "servidor2", "servidor3"];
let index = 0;

async function atualizar(){
  const atual = servidores[index];
  const serverEl = document.getElementById("serverName");
  const alertaEl = document.getElementById("alerta");

  try{
    const r = await fetch("/api/" + atual + "/status.json?cache=" + Date.now());
    if(!r.ok) throw new Error();
    const d = await r.json();
    serverEl.innerText = d.servidor;
    serverEl.style.color = d.cor;
    alertaEl.innerText = ""; 
  } catch(e){ 
    serverEl.innerText = atual.toUpperCase() + " (OFF)";
    serverEl.style.color = "#ef4444";
    alertaEl.innerText = "⚠ " + atual + " está fora do ar"; 
  }
  
  index = (index + 1) % servidores.length;
}
setInterval(atualizar, 2000);
atualizar();
</script>
</body>
</html>
EOF

echo "[7/8] Criando nginx..."
cat > nginx/conf.d/loadbalancer.conf <<EOF
server {
    listen 8090;
    location / { root /usr/share/nginx/html; index index.html; }
    location /api/servidor1/ { proxy_pass http://servidor1/; proxy_connect_timeout 1s; }
    location /api/servidor2/ { proxy_pass http://servidor2/; proxy_connect_timeout 1s; }
    location /api/servidor3/ { proxy_pass http://servidor3/; proxy_connect_timeout 1s; }
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
echo " DICA: Use 'sudo docker compose stop servidor1' para testar."
echo "========================================================"
