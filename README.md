Balanceamento de Carga e Failover Dinâmico com NGINX e Docker
📖 Visão Geral
Este projeto apresenta a implementação prática de um laboratório de infraestrutura de redes resiliente e de alta disponibilidade, estruturado de acordo com os princípios de Infraestrutura como Código (IaC).

O objetivo é simular um cenário real de tráfego web, no qual o balanceador central distribui requisições entre servidores de aplicação redundantes.

Funcionalidades
🔄 Balanceamento de Carga (Round-Robin): distribuição alternada e justa das requisições.

⚠️ Failover Dinâmico: remoção imediata de servidores que falham.

♻️ Auto-Recuperação (Self-Healing): reinserção automática de servidores recuperados no cluster.

🏗️ Arquitetura do Sistema
A infraestrutura separa a camada de recepção de tráfego externo da camada de processamento de dados (backend).

Balanceador: NGINX Proxy Reverso (porta 8090).

Backend: três instâncias Docker (server1, server2, server3) rodando NGINX sobre Alpine Linux (porta 80).

Monitoramento: script em Bash que valida continuamente o estado dos containers.

Esquema Simplificado
Código
Usuário (Porta 8090)
        |
   Balanceador (NGINX Proxy Reverso)
        |
   -------------------------------
   |             |               |
Servidor 1    Servidor 2     Servidor 3
(Porta 80)   (Porta 80)     (Porta 80)
⚙️ Requisitos do Sistema
🖥️ CPU: mínimo 1 núcleo físico (recomendado 2 ou mais).

💾 Memória RAM: mínimo 2 GB livres.

📂 Disco: mínimo 500 MB livres para imagens Docker (NGINX + Alpine).

🚀 Como Executar
1. Clonar o repositório
Código
git clone https://github.com/seuusuario/balanceador8090.git
cd balanceador8090
2. Criar os arquivos necessários
Crie os seguintes arquivos na raiz do projeto:

docker-compose.yml
Código
version: '3.8'

services:
  load_balancer:
    image: nginx:alpine
    container_name: load_balancer
    ports:
      - "8090:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - server1
      - server2
      - server3

  server1:
    image: nginx:alpine
    container_name: server1
    ports:
      - "8081:80"

  server2:
    image: nginx:alpine
    container_name: server2
    ports:
      - "8082:80"

  server3:
    image: nginx:alpine
    container_name: server3
    ports:
      - "8083:80"
nginx.conf
Código
events { }

http {
    upstream backend {
        server server1:80;
        server server2:80;
        server server3:80;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
        }
    }
}
monitor.sh
Código
#!/bin/bash
while true; do
  for server in server1 server2 server3; do
    if ! docker exec $server curl -s http://localhost:80 > /dev/null; then
      echo "⚠️ Falha detectada em $server"
    else
      echo "✅ $server está ativo"
    fi
  done
  sleep 5
done
3. Subir os containers
Código
docker-compose up -d
4. Testar o balanceamento
Acesse no navegador:

Código
http://localhost:8090
🧑‍💻 Autor
Lucas De Figueiredo Gomes  
Instituto Federal de Educação, Ciência e Tecnologia de Mato Grosso – Campus Cuiabá Octayde Jorge da Silva
Curso: Tecnologia em Análise e Desenvolvimento de Sistemas / Redes
Disciplina: Programação Para Redes
Data: 12 de junho de 2026
