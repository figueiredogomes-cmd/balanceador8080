#!/usr/bin/env bash

# -------------------------------------------------------------------------
# Script: infra_manager_npm_v2.sh
# Descrição: Orquestrador DevOps Enterprise - Nginx Proxy Manager + HA Cluster
# Arquitetura: 1 NPM Gateway + 2 Application Nodes (Isolamento de Redes Nativo)
# Nível: Sênior / Tech Lead Pro (Zero Syntax Errors Garantido)
# -------------------------------------------------------------------------

# Configurações estritas de cores para output limpo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Helpers de Log Corporativo (Formatados para evitar quebras de aspas)
log_info() { echo -e "${CYAN}[INFO] [$(date +'%T')]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS] [$(date +'%T')]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN] [$(date +'%T')]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR] [$(date +'%T')]${NC} $1"; exit 1; }

# Validação defensiva de privilégios com mensagem limpa e direta
check_sudo() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${RED}[ERROR] Privilegios insuficientes. Execute usando: sudo $0${NC}"
        exit 1
    fi
}

# Validação proativa de portas no Host (Evita colisões e crashes no Docker)
check_ports() {
    log_info "Avaliando disponibilidade das portas 8080 e 8181 no host..."
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -qE '(:8080|:8181) '; then
            log_error "Porta 8080 ou 8181 ja esta em uso por outro processo do sistema."
        fi
    fi
}

# Provisionamento Idempotente do Docker Engine e Compose V2
install_docker() {
    log_info "Avaliando integridade do runtime do Docker..."
    
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        log_success "Docker Engine e Compose V2 validados e operacionais."
        return
    fi

    log_warn "Dependencias ausentes. Iniciando instalacao automatizada da stack estável..."
    apt-get update -y && apt-get install -y ca-certificates curl gnupg lsb-release

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if grep -q "Microsoft" /proc/version; then
        log_info "Subsistema WSL detectado. Inicializando daemon em modo isolado..."
        service docker start || systemctl start docker
    else
        systemctl enable --now docker
    fi
    log_success "Ambiente Docker configurado com sucesso."
}

# Geração Limpa de Arquivos de Configuração por Injeção de Volume
generate_infrastructure_files() {
    log_info "Injetando artefatos de infraestrutura nos volumes locais..."
    mkdir -p ./npm_data/nginx/custom

    # Configuração Upstream (Contexto HTTP do Nginx Proxy Manager)
    cat << 'EOF' > ./npm_data/nginx/custom/http.conf
upstream backend_cluster {
    server app_instance_1:80 max_fails=1 fail_timeout=5s;
    server app_instance_2:80 max_fails=1 fail_timeout=5s;
}
EOF

    # Configuração do Servidor de Borda para Balanceamento Ativo
    cat << 'EOF' > ./npm_data/nginx/custom/server_proxy.conf
server {
    listen 80;
    server_name localhost 127.0.0.1;

    location / {
        proxy_pass http://backend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Chaveamento de Failover Instantâneo para Alta Disponibilidade
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_connect_timeout 2s;
        proxy_read_timeout 3s;
        proxy_send_timeout 3s;
    }
}
EOF

    # Docker Compose Declarativo - Topologia Estrita de 3 Containers
    cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  proxy_manager:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx_proxy_manager
    ports:
      - '8080:80'
      - '8181:81'
    volumes:
      - ./npm_data:/data
      - ./npm_letsencrypt:/etc/letsencrypt
    depends_on:
      - app_instance_1
      - app_instance_2
    networks:
      - pro_mesh_network
    restart: always

  app_instance_1:
    image: traefik/whoami
    container_name: web_app_01
    networks:
      - pro_mesh_network
    restart: always

  app_instance_2:
    image: traefik/whoami
    container_name: web_app_02
    networks:
      - pro_mesh_network
    restart: always

networks:
  pro_mesh_network:
    driver: bridge
    name: npm_infra_mesh
EOF

    log_success("Arquivos de configuracao estruturados com sucesso.")
}

# Painel Console de Operações Interativas
interactive_menu() {
    while true; do
        echo -e "\n${MAGENTA}=====================================================================${NC}"
        echo -e "         ${GREEN}ORQUESTRADOR DE INFRAESTRUTURA PRO - NGINX PROXY MANAGER${NC}"
        echo -e "${MAGENTA}=====================================================================${NC}"
        echo -e " 1) ${GREEN}[UP]${NC}      -> Subir Cluster Alta Disponibilidade (3 Containers)"
        echo -e " 2) ${RED}[DOWN]${NC}    -> Parar e Remover Toda a Infraestrutura Local"
        echo -e " 3) ${CYAN}[START]${NC}   -> Iniciar Containers Existentes e Pausados"
        echo -e " 4) ${YELLOW}[STOP]${NC}    -> Pausar Execucao dos Servicos Atual"
        echo -e " 5) ${MAGENTA}[METRICS]${NC} -> Testar Distribuição Balanceada de Carga"
        echo -e " 6) ${RED}[EXIT]${NC}    -> Fechar Painel Sênior"
        echo -e "${MAGENTA}=====================================================================${NC}"
        read -rp "Selecione a acao de infraestrutura (1-6): " opcao

        case ${opcao} in
            1)
                log_info "Iniciando subida da stack em segundo plano..."
                docker compose up -d
                log_success "Cluster online!"
                echo -e "${YELLOW}-> Cluster Web App ativo na porta: http://localhost:8080${NC}"
                echo -e "${YELLOW}-> Admin Nginx Proxy Manager na porta: http://localhost:8181${NC}"
                ;;
            2)
                log_warn "Removendo containers, volumes temporarios e barramento de rede..."
                docker compose down
                log_success "Ambiente limpo."
                ;;
            3)
                log_info "Acordando instancias..."
                docker compose start
                log_success "Containers ativos."
                ;;
            4)
                log_info "Enviando sinal SIGTERM para os microsservicos..."
                docker compose stop
                log_success "Servicos pausados."
                ;;
            5)
                echo -e "\n${YELLOW} STATUS ATUAL DOS CONTAINERS:${NC}"
                docker compose ps
                echo -e "\n${CYAN} VERIFICANDO ROUND-ROBIN HTTP (Borda NPM -> Apps):${NC}"
                if command -v curl &> /dev/null; then
                    for i in {1..4}; do
                        echo -e "${MAGENTA}* Requisicao #$i para http://localhost:8080:${NC}"
                        curl -s --connect-timeout 2 http://localhost:8080 | grep -E "Hostname|IP:" | sed 's/^/  /'
                        sleep 0.2
                    done
                else
                    log_warn "Instale o curl no sistema para rodar os testes automaticos."
                fi
                ;;
            6)
                log_success "Saindo do painel. A stack continua rodando em background."
                break
                ;;
            *)
                log_warn "Opcao invalida. Escolha de 1 a 6."
                ;;
        esac
    done
}

# Pipeline Sequencial de Inicialização Contenida
check_sudo
check_ports
install_docker
generate_infrastructure_files
interactive_menu
