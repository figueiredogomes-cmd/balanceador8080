#!/bin/bash

set -e

echo "=========================================="
echo " ASP.NET CORE + NGINX LOAD BALANCER"
echo " PORTA 8090"
echo "=========================================="

mkdir -p balanceador8090
cd balanceador8090

mkdir -p nginx api

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

cat > api/Program.cs <<'EOF'
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var nomeServidor =
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
Servidor: {nomeServidor}
Requisicoes: {contador}
=======================

");
});

app.MapGet("/health", () =>
{
return Results.Ok("UP");
});

app.Run("http://0.0.0.0:8080");
EOF

cat > api/App.csproj <<'EOF' <Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

</Project>
EOF

cat > api/Dockerfile <<'EOF'
FROM mcr.microsoft.com/dotnet/sdk:8.0

WORKDIR /src

COPY . .

RUN dotnet publish -c Release -o /app

EXPOSE 8080

ENTRYPOINT ["dotnet","/app/App.dll"]
EOF

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

docker compose up -d --build

echo
echo "=========================================="
echo "CLUSTER INICIADO"
echo "=========================================="
echo
echo "http://localhost:8090"
echo
echo "TESTE:"
echo "curl http://localhost:8090"
echo
echo "PARAR APP1:"
echo "docker stop app1"
echo
echo "PARAR APP2:"
echo "docker stop app2"
echo
echo "VOLTAR APP1:"
echo "docker start app1"
echo
echo "VOLTAR APP2:"
echo "docker start app2"
