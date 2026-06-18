#!/bin/bash

set -e

echo "=========================================="
echo " ASP.NET CORE + NGINX LOAD BALANCER"
echo " Ubuntu 22.04+ / WSL"
echo " Porta 8090"
echo "=========================================="

if ! command -v docker >/dev/null 2>&1; then

```
echo "[1/5] Instalando Docker..."

sudo apt update

sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update

sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
```

fi

if ! sudo docker compose version >/dev/null 2>&1; then

```
echo "[2/5] Instalando Docker Compose Plugin..."

sudo apt update
sudo apt install -y docker-compose-plugin
```

fi

mkdir -p balanceador8090
cd balanceador8090

mkdir -p nginx api

echo "[3/5] Criando Nginx..."

cat > nginx/nginx.conf <<'EOF'
events {}

http {

```
upstream backend {

    server app1:8080 max_fails=1 fail_timeout=5s;
    server app2:8080 max_fails=1 fail_timeout=5s;
    server app3:8080 max_fails=1 fail_timeout=5s;

}

server {

    listen 80;

    location / {

        proxy_pass http://backend;

        proxy_http_version 1.1;

        proxy_next_upstream error
                            timeout
                            invalid_header
                            http_500
                            http_502
                            http_503
                            http_504;

        proxy_connect_timeout 2s;
        proxy_read_timeout 5s;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    }

}
```

}
EOF

echo "[4/5] Criando API ASP.NET Core..."

cat > api/App.csproj <<'EOF' <Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

</Project>
EOF

cat > api/Program.cs <<'EOF'
var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

var servidor =
Environment.GetEnvironmentVariable("SERVER_NAME")
?? "DESCONHECIDO";

int contador = 0;

app.MapGet("/", () =>
{
contador++;

```
return Results.Text($@"
```

================================
Servidor: {servidor}
Requisicoes: {contador}
=======================

");
});

app.MapGet("/health", () => Results.Ok("UP"));

app.Run("http://0.0.0.0:8080");
EOF

cat > api/Dockerfile <<'EOF'
FROM mcr.microsoft.com/dotnet/sdk:8.0

WORKDIR /src

COPY . .

RUN dotnet publish -c Release -o /app

EXPOSE 8080

ENTRYPOINT ["dotnet","/app/App.dll"]
EOF

echo "[5/5] Criando Docker Compose..."

cat > docker-compose.yml <<'EOF'
services:

app1:
build: ./api
container_name: app1
environment:
SERVER_NAME: APP1

app2:
build: ./api
container_name: app2
environment:
SERVER_NAME: APP2

app3:
build: ./api
container_name: app3
environment:
SERVER_NAME: APP3

nginx:
image: nginx:latest
container_name: nginx_lb

```
ports:
  - "8090:80"

volumes:
  - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro

depends_on:
  - app1
  - app2
  - app3
```

EOF

echo
echo "Subindo cluster..."

sudo docker compose up -d --build

echo
echo "=========================================="
echo "CLUSTER INICIADO"
echo "=========================================="
echo
echo "Acesse:"
echo "http://localhost:8090"
echo
echo "Teste:"
echo "curl http://localhost:8090"
echo
echo "------------------------------------------"
echo "COMANDOS"
echo "------------------------------------------"
echo
echo "Parar APP1"
echo "sudo docker stop app1"
echo
echo "Iniciar APP1"
echo "sudo docker start app1"
echo
echo "Parar APP2"
echo "sudo docker stop app2"
echo
echo "Iniciar APP2"
echo "sudo docker start app2"
echo
echo "Parar APP3"
echo "sudo docker stop app3"
echo
echo "Iniciar APP3"
echo "sudo docker start app3"
echo
echo "Parar Cluster"
echo "sudo docker compose stop"
echo
echo "Iniciar Cluster"
echo "sudo docker compose start"
echo
echo "Destruir Cluster"
echo "sudo docker compose down -v"
echo
echo "Ver Containers"
echo "sudo docker ps"
echo
echo "=========================================="
echo "Balanceamento:"
echo "3 APIs = 33% cada"
echo "2 APIs = 50% cada"
echo "1 API = 100%"
echo "=========================================="
