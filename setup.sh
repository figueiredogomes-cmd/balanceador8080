#!/bin/bash

# --- Configurações ---
PROJETO="$HOME/cluster-balanceado"
PUERTO_ACCESO="8090" # Porta para acessar o balanceador a partir do host

# --- Verificação de Privilégios ---
# Garante que o script seja executado com root/sudo para as operações de instalação e Docker.
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script como root ou use sudo."
  exit 1
fi

# --- Instalação Robusta do Docker e Docker Compose ---
echo "Instalando Docker e Docker Compose (Método Oficial do Docker)..."

# 1. Remover pacotes Docker antigos e conflitos potenciais.
echo "Removendo versões antigas do Docker e dependências conflitantes..."
# Redireciona a saída para /dev/null para não poluir o terminal com avisos de pacotes não instalados.
apt-get remove docker docker-engine docker.io containerd runc -y > /dev/null 2>&1
apt-get autoremove -y > /dev/null 2>&1

# 2. Instalar pré-requisitos para o repositório HTTPS do Docker.
echo "Instalando pré-requisitos para o repositório Docker..."
apt-get update
apt-get install -y \
    ca-certificates \
    gnupg \
    lsb-release \
    curl \
    software-properties-common

# 3. Adicionar a chave GPG oficial do Docker para verificar a autenticidade dos pacotes.
echo "Adicionando chave GPG oficial do Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 4. Configurar o repositório estável do Docker para Ubuntu.
echo "Configurando o repositório do Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Atualizar a lista de pacotes para incluir o novo repositório do Docker.
echo "Atualizando lista de pacotes após adicionar o repositório Docker..."
apt-get update

# 6. Instalar o Docker Engine, CLI, Containerd e o plugin Docker Compose.
# A instalação via repositório oficial do Docker é mais confiável para resolver conflitos.
echo "Instalando Docker Engine, CLI, Containerd e Docker Compose Plugin..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 7. Habilitar e iniciar o serviço Docker.
echo "Habilitando e iniciando o serviço Docker..."
systemctl enable docker
systemctl start docker
echo "Docker instalado e em execução."

# --- Verificação da Instalação ---
echo "Verificando as versões do Docker e Docker Compose..."
docker --version
docker compose version # Usa o plugin instalado

# --- Limpeza de Ambiente Anterior ---
# Remove quaisquer contêineres de execuções anteriores para garantir um ambiente limpo.
echo "Limpando ambiente anterior (contêineres Docker)..."
# '-f' força a remoção, '2>/dev/null || true' ignora erros se os contêineres não existirem.
docker rm -f balanceador srv1 srv2 srv3 > /dev/null 2>&1 || true

# --- Criação da Estrutura de Diretórios do Projeto ---
echo "Criando estrutura de diretórios para o projeto em '$PROJETO'..."
mkdir -p "$PROJETO"
# Navega para o diretório do projeto. Se falhar, o script sai.
cd "$PROJETO" || { echo "Erro: Falha ao acessar o diretório do projeto '$PROJETO'. Saindo."; exit 1; }
mkdir -p nginx/conf.d
mkdir -p srv1
mkdir -p srv2
mkdir -p srv3

# --- Criação de Conteúdo HTML Simples para os Servidores ---
echo "Criando arquivos HTML de exemplo para os servidores..."
cat > srv1/index.html <<EOF
<h1>Servidor 1</h1>
EOF

cat > srv2/index.html <<EOF
<h1>Servidor 2</h1>
EOF

cat > srv3/index.html <<EOF
<h1>Servidor 3</h1>
EOF

# --- Configuração do Nginx para Balanceamento de Carga ---
# Este arquivo define como o Nginx irá distribuir o tráfego entre os servidores de backend.
echo "Configurando o arquivo de configuração do Nginx (nginx/conf.d/default.conf)..."
cat > nginx/conf.d/default.conf <<EOF
# Define um grupo de servidores que o Nginx usará para balanceamento
upstream backend {
    # Lista os servidores backend. O Nginx distribuirá as requisições entre eles.
    # max_fails=3: Considera o servidor indisponível após 3 falhas consecutivas.
    # fail_timeout=10s: Espera 10 segundos antes de tentar reconectar um servidor indisponível.
    server srv1:80 max_fails=3 fail_timeout=10s;
    server srv2:80 max_fails=3 fail_timeout=10s;
    server srv3:80 max_fails=3 fail_timeout=10s;
}

# Configuração do servidor principal (o balanceador)
server {
    listen 80; # O balanceador escuta na porta 80 dentro do contêiner.

    location / {
        # proxy_pass direciona o tráfego para o grupo 'backend'.
        proxy_pass http://backend;

        # Headers importantes para que o backend saiba quem fez a requisição original.
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # proxy_next_upstream: Define o que fazer se a requisição falhar.
        # Tenta o próximo servidor em caso de erro, timeout, ou erros HTTP específicos (502, 503, 504).
        # Isso é crucial para a resiliência: se um servidor falha, o Nginx tenta outro.
        proxy_next_upstream error timeout http_502 http_503 http_504;

        # Tempos de timeout curtos para detectar falhas rapidamente.
        proxy_connect_timeout 1s;
        proxy_send_timeout 1s;
        proxy_read_timeout 1s;
    }
}
EOF

# --- Definição do Arquivo docker-compose.yml ---
# Este arquivo define os serviços (contêineres) que compõem nosso cluster.
echo "Definindo o arquivo docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  srv1:
    image: nginx:alpine
    container_name: srv1
    restart: unless-stopped # Reinicia o contêiner se ele parar, a menos que seja explicitamente parado.
    volumes:
      - ./srv1:/usr/share/nginx/html # Monta o diretório local com conteúdo HTML no contêiner.
    # Healthcheck: Monitora a saúde do contêiner. Essencial para o balanceador.
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"] # Comando para testar a saúde. '-f' retorna erro se não for 2xx/3xx.
      interval: 30s       # Intervalo entre as verificações de saúde.
      timeout: 10s        # Tempo máximo para a verificação ser concluída.
      retries: 3          # Número de tentativas falhas antes de marcar o contêiner como 'unhealthy'.
      start_period: 30s   # Período de carência para as verificações iniciais.

  srv2:
    image: nginx:alpine
    container_name: srv2
    restart: unless-stopped
    volumes:
      - ./srv2:/usr/share/nginx/html
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  srv3:
    image: nginx:alpine
    container_name: srv3
    restart: unless-stopped
    volumes:
      - ./srv3:/usr/share/nginx/html
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  balanceador:
    image: nginx:alpine
    container_name: balanceador
    restart: unless-stopped
    ports:
      - "${PUERTO_ACCESO}:80" # Mapeia a porta 80 do contêiner para a porta ${PUERTO_ACCESO} do host.
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d # Monta o diretório de configuração do Nginx.
    # 'depends_on' com 'condition: service_healthy' garante que este serviço
    # só será iniciado após todos os serviços listados (srv1, srv2, srv3)
    # estarem marcados como saudáveis pelo Docker.
    depends_on:
      srv1:
        condition: service_healthy
      srv2:
        condition: service_healthy
      srv3:
        condition: service_healthy
EOF

# --- Subindo o Cluster com Docker Compose ---
echo "Iniciando o cluster balanceado com Docker Compose..."
# 'down' para parar e remover contêineres, redes e volumes anteriores.
docker-compose down
# 'up -d' para criar e iniciar os contêineres em segundo plano.
docker-compose up -d

echo ""
echo "=================================================="
echo "  Cluster balanceado iniciado com sucesso!        "
echo "=================================================="
echo ""
echo "Acesse o balanceador em: http://localhost:${PUERTO_ACCESO}"
echo ""
echo "Status atual dos contêineres Docker:"
docker ps # Mostra os contêineres em execução
echo ""
echo "Para parar o cluster, navegue até o diretório '$PROJETO'"
echo "e execute: sudo docker-compose down"
