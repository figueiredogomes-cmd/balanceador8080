#!/bin/bash

echo "======================================"
echo " ASP.NET CORE + NGINX LOAD BALANCER"
echo " Porta 8090"
echo "======================================"

mkdir -p balanceador8090/{nginx,api1,api2,api3}

cd balanceador8090

########################################
# NGINX
########################################

cat > nginx/nginx.conf <<'EOF'
events {}

http {

    upstream backend {

        server api1:8080 max_fails=3 fail_timeout=5s;
        server api2:8080 max_fails=3 fail_timeout=5s;
        server api3:8080 max_fails=3 fail_timeout=5s;

    }

    server {

        listen 80;

        location / {

            proxy_pass http://backend;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        }

    }

}
EOF

########################################
# API1
########################################

cat > api1/Program.cs <<'EOF'
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

int contador = 0;

app.MapGet("/", () =>
{
    contador++;

    return Results.Text($@"
================================
Servidor: API 1
Requisicoes: {contador}
================================
");
});

app.Run("http://0.0.0.0:8080");
EOF

########################################
# API2
########################################

cat > api2/Program.cs <<'EOF'
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

int contador = 0;

app.MapGet("/", () =>
{
    contador++;

    return Results.Text($@"
================================
Servidor: API 2
Requisicoes: {contador}
================================
");
});

app.Run("http://0.0.0.0:8080");
EOF

########################################
# API3
########################################

cat > api3/Program.cs <<'EOF'
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

int contador = 0;

app.MapGet("/", () =>
{
    contador++;

    return Results.Text($@"
================================
Servidor: API 3
Requisicoes: {contador}
================================
");
});

app.Run("http://0.0.0.0:8080");
EOF

########################################
# DOCKERFILES
########################################

for api in api1 api2 api3
do

cat > $api/Dockerfile <<'EOF'
FROM mcr.microsoft.com/dotnet/sdk:8.0

WORKDIR /app

COPY Program.cs .

RUN dotnet new web -n App

WORKDIR /app/App

COPY ../Program.cs Program.cs

RUN dotnet publish -c Release -o out

EXPOSE 8080

ENTRYPOINT ["dotnet","out/App.dll"]
EOF

done

########################################
# DOCKER COMPOSE
########################################

cat > docker-compose.yml <<'EOF'
services:

  api1:
    build: ./api1
    container_name: api1

  api2:
    build: ./api2
    container_name: api2

  api3:
    build: ./api3
    container_name: api3

  nginx:
    image: nginx:latest
    container_name: nginx_lb

    ports:
      - "8090:80"

    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf

    depends_on:
      - api1
      - api2
      - api3

EOF

########################################
# SUBIR CLUSTER
########################################

docker compose up -d --build

echo
echo "======================================"
echo " Cluster iniciado"
echo "======================================"
echo
echo "Acesse:"
echo
echo "http://localhost:8090"
echo
echo "Teste:"
echo
echo "curl http://localhost:8090"
echo
echo "A cada requisicao:"
echo
echo "API1 -> API2 -> API3 -> API1 ..."
echo
