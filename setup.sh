#!/bin/bash

echo "==========================================="
echo " SERVICO DE BALANCEAMENTO (Corrigido)"
echo " Ubuntu WSL + Docker"
echo "==========================================="

sleep 2

echo "[1/8] Atualizando e instalando dependencias..."
sudo apt update -y
sudo apt install -y docker.io curl git

echo "[3/8] Iniciando Docker..."
sudo service docker start

echo "[4/8] Criando estrutura..."
mkdir -p ~/servico-balanceamento/{nginx/conf.d,frontend,servidor1,servidor2,servidor3}
cd ~/servico-balanceamento

echo "[5/8] Criando paginas dos servidores..."
echo '{"servidor":"Servidor1","cor":"#22c55e"}' > servidor1/status.json
echo '{"servidor":"Servidor2","cor":"#3b82f6"}' > servidor2/status.json
echo '{"servidor":"Servidor3","cor":"#f59e0b"}' > servidor3/status.json

echo "[6/8] Criando frontend..."
# (Mantive seu HTML original aqui)
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head><meta charset="UTF-8"><title>Serviço de Balanceamento</title>
<style>
*{margin:0;padding:0;box-sizing:border-box;font-family:Arial,sans-serif;}
body{background:#0f172a;height:100vh;display:flex;justify-content:center;align-items:center;color:white;}
.card{width:700px;padding:50px;text-align:center;border-radius:30px;background:rgba(255,255,255,.08);backdrop-filter:blur(15px);}
</style>
</head>
<body>
<div class="card"><h1 id="serverName">Carregando...</h1><div id="alerta" style="color:#ef4444;"></div></div>
<script>
const ordem = ["servidor1", "servidor2", "servidor3", "servidor2", "servidor1", "servidor2", "servidor3"];
let index = 0;
async function atualizar(){
  const atual = ordem[index];
  try{
    const r = await fetch("/api/" + atual + "/status.json?cache=" + Date.now());
    if(!r.ok) throw new Error();
    const d = await r.json();
    document.getElementById("serverName").innerText = d.servidor;
    document.getElementById("serverName").style.color = d.cor;
    document.getElementById("alerta").innerText = "";
  }catch(e){ document.getElementById("alerta").innerText = "⚠ " + atual + " caiu"; }
  index = (index + 1) % ordem.length;
}
setInterval(atualizar, 1000);
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
    location /api/servidor1/ { proxy_pass http://servidor1/; }
    location /api/servidor2/ { proxy_pass http://servidor2/; }
    location /api/servidor3/ { proxy_pass http://servidor3/; }
}
EOF

echo "[8/8] Criando docker-compose..."
cat > docker-compose.yml <<EOF
services:
  servidor1: { image: nginx:alpine, volumes: ["./servidor1:/usr/share/nginx/html"] }
  servidor2: { image: nginx:alpine, volumes: ["./servidor2:/usr/share/nginx/html"] }
  servidor3: { image: nginx:alpine, volumes: ["./servidor3:/usr/share/nginx/html"] }
  balanceador:
    image: nginx:alpine
    ports: ["8090:8090"]
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./frontend:/usr/share/nginx/html
EOF

echo "Subindo containers..."
sudo docker compose down
sudo docker compose up -d

echo "================================="
echo " INSTALADO COM SUCESSO!"
echo " Acesse: http://localhost:8090/"
echo "================================="
