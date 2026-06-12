echo "==========================================="
echo " SERVICO DE BALANCEAMENTO"
echo " Ubuntu WSL + Docker"
echo "==========================================="

sleep 2

echo "[1/8] Atualizando Ubuntu..."
sudo apt update -y

echo "[2/8] Instalando dependencias..."
sudo apt install -y \
docker.io \
docker-compose \
curl \
git

echo "[3/8] Iniciando Docker..."
sudo service docker start

echo "[4/8] Criando estrutura..."

mkdir -p ~/servico-balanceamento/{nginx/conf.d,frontend,servidor1,servidor2,servidor3}

cd ~/servico-balanceamento

echo "[5/8] Criando paginas dos servidores..."

cat > servidor1/status.json <<EOF
{
"servidor":"Servidor1",
"cor":"#22c55e"
}
EOF

cat > servidor2/status.json <<EOF
{
"servidor":"Servidor2",
"cor":"#3b82f6"
}
EOF

cat > servidor3/status.json <<EOF
{
"servidor":"Servidor3",
"cor":"#f59e0b"
}
EOF

echo "[6/8] Criando frontend..."

cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
<meta charset="UTF-8">
<title>Serviço de Balanceamento</title>

<style>

*{
margin:0;
padding:0;
box-sizing:border-box;
font-family:Arial,sans-serif;
}

body{
background:#0f172a;
height:100vh;
display:flex;
justify-content:center;
align-items:center;
overflow:hidden;
color:white;
}

.card{
width:700px;
padding:50px;
text-align:center;
border-radius:30px;
background:rgba(255,255,255,.08);
backdrop-filter:blur(15px);
box-shadow:0 0 30px rgba(0,255,255,.2);
transition:.5s;
animation:fade .6s ease;
}

.badge{
position:absolute;
top:20px;
right:20px;
background:#16a34a;
padding:10px 25px;
border-radius:20px;
font-weight:bold;
}

h1{
font-size:70px;
transition:.4s;
}

.online{
margin-top:20px;
font-size:25px;
animation:pulse 1s infinite;
}

.alerta{
margin-top:15px;
font-size:22px;
color:#ef4444;
}

@keyframes pulse{
0%{opacity:.4;}
50%{opacity:1;}
100%{opacity:.4;}
}

@keyframes fade{
from{
opacity:0;
transform:translateY(20px);
}
to{
opacity:1;
transform:translateY(0);
}
}

</style>
</head>

<body>

<div class="badge">
Serviço de Balanceamento
</div>

<div class="card">

<h1 id="serverName">
Carregando...
</h1>

<div class="online">
● ONLINE
</div>

<div class="alerta" id="alerta">
</div>

</div>

<script>

const ordem = [
"servidor1",
"servidor2",
"servidor3",
"servidor2",
"servidor1",
"servidor2",
"servidor3"
]

let index = 0

async function atualizar(){

const atual = ordem[index]

try{

const r =
await fetch(
"/api/" + atual + "/status.json?cache=" + Date.now()
)

if(!r.ok)
throw new Error()

const d = await r.json()

document
.getElementById("serverName")
.innerText = d.servidor

document
.getElementById("serverName")
.style.color = d.cor

document
.getElementById("alerta")
.innerText = ""

}catch(e){

document
.getElementById("alerta")
.innerText =
"⚠ " + atual + " caiu"

}

index++

if(index >= ordem.length)
index = 0

}

setInterval(atualizar,1000)

atualizar()

</script>

</body>
</html>
EOF

echo "[7/8] Criando nginx..."

cat > nginx/conf.d/loadbalancer.conf <<EOF
server {

listen 8090;

location / {
root /usr/share/nginx/html;
index index.html;
}

location /api/servidor1/ {
proxy_pass http://servidor1/;
proxy_connect_timeout 300ms;
proxy_read_timeout 300ms;
}

location /api/servidor2/ {
proxy_pass http://servidor2/;
proxy_connect_timeout 300ms;
proxy_read_timeout 300ms;
}

location /api/servidor3/ {
proxy_pass http://servidor3/;
proxy_connect_timeout 300ms;
proxy_read_timeout 300ms;
}

}
EOF

echo "[8/8] Criando docker-compose..."

cat > docker-compose.yml <<EOF
version: "3.9"

services:

  servidor1:
    image: nginx:alpine
    container_name: servidor1
    restart: "no"
    volumes:
      - ./servidor1:/usr/share/nginx/html

  servidor2:
    image: nginx:alpine
    container_name: servidor2
    restart: "no"
    volumes:
      - ./servidor2:/usr/share/nginx/html

  servidor3:
    image: nginx:alpine
    container_name: servidor3
    restart: "no"
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
    depends_on:
      - servidor1
      - servidor2
      - servidor3
EOF

echo "Subindo containers..."

sudo docker-compose down
sudo docker-compose up -d

echo ""
echo "================================="
echo " INSTALADO COM SUCESSO"
echo "================================="
echo ""
echo "Acesse:"
echo ""
echo http://localhost:8090/"
echo ""



teste:http://localhost:8090/









echo "==========================================="
echo " SERVICO DE BALANCEAMENTO"
echo " Ubuntu WSL + Docker"
echo "==========================================="

sleep 2

echo "[1/8] Atualizando Ubuntu..."
sudo apt update -y

echo "[2/8] Instalando dependencias..."
sudo apt install -y \
docker.io \
docker-compose \
curl \
git

echo "[3/8] Iniciando Docker..."
sudo service docker start

echo "[4/8] Criando estrutura..."

mkdir -p ~/servico-balanceamento/{nginx/conf.d,frontend,servidor1,servidor2,servidor3}

cd ~/servico-balanceamento

echo "[5/8] Criando paginas dos servidores..."

cat > servidor1/status.json <<EOF
{
"servidor":"Servidor1",
"cor":"#22c55e"
}
EOF

cat > servidor2/status.json <<EOF
{
"servidor":"Servidor2",
"cor":"#3b82f6"
}
EOF

cat > servidor3/status.json <<EOF
{
"servidor":"Servidor3",
"cor":"#f59e0b"
}
EOF

echo "[6/8] Criando frontend..."

cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
<meta charset="UTF-8">
<title>Serviço de Balanceamento</title>

<style>

*{
margin:0;
padding:0;
box-sizing:border-box;
font-family:Arial,sans-serif;
}

body{
background:#0f172a;
height:100vh;
display:flex;
justify-content:center;
align-items:center;
overflow:hidden;
color:white;
}

.card{
width:700px;
padding:50px;
text-align:center;
border-radius:30px;
background:rgba(255,255,255,.08);
backdrop-filter:blur(15px);
box-shadow:0 0 30px rgba(0,255,255,.2);
transition:.5s;
animation:fade .6s ease;
}

.badge{
position:absolute;
top:20px;
right:20px;
background:#16a34a;
padding:10px 25px;
border-radius:20px;
font-weight:bold;
}

h1{
font-size:70px;
transition:.4s;
}

.online{
margin-top:20px;
font-size:25px;
animation:pulse 1s infinite;
}

.alerta{
margin-top:15px;
font-size:22px;
color:#ef4444;
}

@keyframes pulse{
0%{opacity:.4;}
50%{opacity:1;}
100%{opacity:.4;}
}

@keyframes fade{
from{
opacity:0;
transform:translateY(20px);
}
to{
opacity:1;
transform:translateY(0);
}
}

</style>
</head>

<body>

<div class="badge">
Serviço de Balanceamento
</div>

<div class="card">

<h1 id="serverName">
Carregando...
</h1>

<div class="online">
● ONLINE
</div>

<div class="alerta" id="alerta">
</div>

</div>

<script>

const ordem = [
"servidor1",
"servidor2",
"servidor3",
"servidor2",
"servidor1",
"servidor2",
"servidor3"
]

let index = 0

async function atualizar(){

const atual = ordem[index]

try{

const r =
await fetch(
"/api/" + atual + "/status.json?cache=" + Date.now()
)

if(!r.ok)
throw new Error()

const d = await r.json()

document
.getElementById("serverName")
.innerText = d.servidor

document
.getElementById("serverName")
.style.color = d.cor

document
.getElementById("alerta")
.innerText = ""

}catch(e){

document
.getElementById("alerta")
.innerText =
"⚠ " + atual + " caiu"

}

index++

if(index >= ordem.length)
index = 0

}

setInterval(atualizar,1000)

atualizar()

</script>

</body>
</html>
EOF

echo "[7/8] Criando nginx..."

cat > nginx/conf.d/loadbalancer.conf <<EOF
server {

listen 8090;

location / {
root /usr/share/nginx/html;
index index.html;
}

location /api/servidor1/ {
proxy_pass http://servidor1/;
proxy_connect_timeout 300ms;
proxy_read_timeout 300ms;
}

location /api/servidor2/ {
proxy_pass http://servidor2/;
proxy_connect_timeout 300ms;
proxy_read_timeout 300ms;
}

location /api/servidor3/ {
proxy_pass http://servidor3/;
proxy_connect_timeout 300ms;
proxy_read_timeout 300ms;
}

}
EOF

echo "[8/8] Criando docker-compose..."

cat > docker-compose.yml <<EOF
version: "3.9"

services:

  servidor1:
    image: nginx:alpine
    container_name: servidor1
    restart: "no"
    volumes:
      - ./servidor1:/usr/share/nginx/html

  servidor2:
    image: nginx:alpine
    container_name: servidor2
    restart: "no"
    volumes:
      - ./servidor2:/usr/share/nginx/html

  servidor3:
    image: nginx:alpine
    container_name: servidor3
    restart: "no"
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
    depends_on:
      - servidor1
      - servidor2
      - servidor3
EOF

echo "Subindo containers..."

sudo docker-compose down
sudo docker-compose up -d

echo ""
echo "================================="
echo " INSTALADO COM SUCESSO"
echo "================================="
echo ""
echo "Acesse:"
echo ""
echo http://localhost:8090/"
echo ""



testecho "==========================================="
echo " SERVICO DE BALANCEAMENTO"
echo " Ubuntu WSL + Docker"
echo "==========================================="

sleep 2

echo "[1/8] Atualizando Ubuntu..."
sudo apt update -y

echo "[2/8] Instalando dependencias..."
sudo apt install -y \
docker.io \
docker-compose \
curl \
git

echo "[3/8] Iniciando Docker..."
sudo service docker start

echo "[4/8] Criando estrutura..."

mkdir -p ~/servico-balanceamento/{nginx/conf.d,frontend,servidor1,servidor2,servidor3}

cd ~/servico-balanceamento

echo "[5/8] Criando paginas dos servidores..."

cat > servidor1/status.json <<EOF
{
"servidor":"Servidor1",
"cor":"#22c55e"
}
EOF

cat > servidor2/status.json <<EOF
{
"servidor":"Servidor2",
"cor":"#3b82f6"
}
EOF

cat > servidor3/status.json <<EOF
{
"servidor":"Servidor3",
"cor":"#f59e0b"
}
EOF

echo "[6/8] Criando frontend..."

cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
<meta charset="UTF-8">
<title>Serviço de Balanceamento</title>

<style>

*{
margin:0;
padding:0;
box-sizing:border-box;
font-family:Arial,sans-serif;
}

body{
background:#0f172a;
height:100vh;
display:flex;
justify-content:center;
align-items:center;
overflow:hidden;
color:white;
}

.card{
width:700px;
padding:50px;
text-align:center;
border-radius:30px;
background:rgba(255,255,255,.08);
backdrop-filter:blur(15px);
box-shadow:0 0 30px rgba(0,255,255,.2);
transition:.5s;
animation:fade .6s ease;
}

.badge{
position:absolute;
top:20px;
right:20px;
background:#16a34a;
padding:10px 25px;
border-radius:20px;
font-weight:bold;
}

h1{
font-size:70px;
transition:.4s;
}

.online{
margin-top:20px;
font-size:25px;
animation:pulse 1s infinite;
}

.alerta{
margin-top:15px;
font-size:22px;
color:#ef4444;
}

@keyframes pulse{
0%{opacity:.4;}
50%{opacity:1;}
100%{opacity:.4;}
}

@keyframes fade{
from{
opacity:0;
transform:translateY(20px);
}
to{
opacity:1;
transform:translateY(0);
}
}

</style>
</head>

<body>

<div class="badge">
Serviço de Balanceamento
</div>

<div class="card">

<h1 id="serverName">
Carregando...
</h1>

<div class="online">
● ONLINE
</div>

<div class="alerta" id="alerta">
</div>

</div>

<script>

const ordem = [
"servidor1",
"servidor2",
"servidor3",
"servidor2",
"servidor1",
"servidor2",
"servidor3"
]

let index = 0

async function atualizar(){

const atual = ordem[index]

try{

const r =
await fetch(
"/api/" + atual + "/status.json?cache=" + Date.now()
)

if(!r.ok)
throw new Error()

const d = await r.json()

document
.getElementById("serverName")
.innerText = d.servidor

document
.getElementById("serverName")
.style.color = d.cor

document
.getElementById("alerta")
.innerText = ""

}catch(e){

document
.getElementById("alerta")
.innerText =
"⚠ " + atual + " caiu"

}

index++

if(index >= ordem.length)
index = 0

}

setInterval(atualizar,1000)

atualizar()

</script>

</body>
</html>
EOF

echo "[7/8] Criando nginx..."

cat > nginx/conf.d/loadbalancer.conf <<EOF
server {

listen 8090;

location / {
root /usr/share/nginx/html;
index index.html;
}

location /api/servidor1/ {
proxy_pass http://servidor1/;
proxy_connect_timeout 300ms;
proxy_read_timeout 300ms;
}

location /api/servidor2/ {
proxy_pass http://servidor2/;
proxy_connect_timeout 300ms;
proxy_read_timeout 300ms;
}

location /api/servidor3/ {
proxy_pass http://servidor3/;
proxy_connect_timeout 300ms;
proxy_read_timeout 300ms;
}

}
EOF

echo "[8/8] Criando docker-compose..."

cat > docker-compose.yml <<EOF
version: "3.9"

services:

  servidor1:
    image: nginx:alpine
    container_name: servidor1
    restart: "no"
    volumes:
      - ./servidor1:/usr/share/nginx/html

  servidor2:
    image: nginx:alpine
    container_name: servidor2
    restart: "no"
    volumes:
      - ./servidor2:/usr/share/nginx/html

  servidor3:
    image: nginx:alpine
    container_name: servidor3
    restart: "no"
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
    depends_on:
      - servidor1
      - servidor2
      - servidor3
EOF

echo "Subindo containers..."

sudo docker-compose down
sudo docker-compose up -d

echo ""
echo "================================="
echo " INSTALADO COM SUCESSO"
echo "================================="
echo ""
echo "Acesse:"
echo ""
echo http://localhost:8090/"
echo ""



teste:http://localhost:8090/









e:http://localhost:8090/










