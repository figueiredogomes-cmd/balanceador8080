#!/usr/bin/env bash

# -------------------------------------------------------------------------
# Script: cluster_orchestrator_v3.sh
# Descrição: Enterprise DevOps Chaos Engineering Sandbox (3 Nodes + Ultra Fast Teardown)
# -------------------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO] [$(date +'%T')]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS] [$(date +'%T')]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN] [$(date +'%T')]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR] [$(date +'%T')]${NC} $1"; exit 1; }

check_sudo() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${RED}[ERROR] Privilégios insuficientes. Execute usando: sudo $0${NC}"
        exit 1
    fi
}

# TOQUE DE SÊNIOR: Permite abrir o menu mesmo com a porta ocupada para que possa usar a Opção 2!
check_ports_soft() {
    log_info "Avaliando disponibilidade da porta de borda 8080 no host..."
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ':8080 '; then
            log_warn "A porta 8080 já está em uso. Se for o seu cluster antigo, use a opção 2 do menu para limpá-lo!"
        fi
    fi
}

check_ports_strict() {
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ':8080 '; then
            log_warn "Conflito detectado: A porta 8080 está ocupada por outro processo."
            read -rp "Deseja tentar forçar uma limpeza automática do Docker antes de subir? (s/N): " limpar
            if [[ "$limpar" =~ ^[Ss]$ ]]; then
                log_info "Executando purga preventiva de containers antigos na porta 8080..."
                docker rm -f nginx_proxy_manager web_app_01 web_app_02 web_app_03 &> /dev/null
                sleep 1
            else
                log_error "Abortando subida do cluster para evitar colisão de portas."
            fi
        fi
    fi
}

install_docker() {
    log_info "Avaliando integridade do runtime do Docker..."
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        log_success "Docker Engine e Compose V2 validados e operacionais."
        return
    fi

    log_warn "Dependências ausentes. Iniciando instalação automatizada..."
    apt-get update -y && apt-get install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if grep -q "Microsoft" /proc/version; then
        service docker start || systemctl start docker
    else
        systemctl enable --now docker
    fi
}

generate_infrastructure_files() {
    log_info "Injetando artefatos de infraestrutura nos volumes locais..."
    mkdir -p ./npm_data/nginx/custom

    # Configuração Upstream de Alta Disponibilidade para 3 Servidores (Igual ao Vídeo)
    cat << 'EOF' > ./npm_data/nginx/custom/http.conf
upstream backend_cluster {
    server app_instance_1:80 max_fails=1 fail_timeout=5s;
    server app_instance_2:80 max_fails=1 fail_timeout=5s;
    server app_instance_3:80 max_fails=1 fail_timeout=5s;
}
EOF

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

        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_connect_timeout 2s;
        proxy_read_timeout 3s;
        proxy_send_timeout 3s;
    }
}
EOF

    # Docker Compose com a topologia exata de 3 instâncias de aplicação
    cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  proxy_manager:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx_proxy_manager
    ports:
      - '8080:80'
    volumes:
      - ./npm_data:/data
      - ./npm_letsencrypt:/etc/letsencrypt
    depends_on:
      - app_instance_1
      - app_instance_2
      - app_instance_3
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

  app_instance_3:
    image: traefik/whoami
    container_name: web_app_03
    networks:
      - pro_mesh_network
    restart: always

networks:
  pro_mesh_network:
    driver: bridge
    name: npm_infra_mesh
EOF

    log_success "Arquivos de configuração estruturados com sucesso."
}

interactive_menu() {
    while true; do
        echo -e "\n${MAGENTA}=====================================================================${NC}"
        echo -e "         ${GREEN}ORQUESTRADOR DE INFRAESTRUTURA PRO - 3 NODES CLUSTER${NC}"
        echo -e "${MAGENTA}=====================================================================${NC}"
        echo -e " 1) ${GREEN}[UP]${NC}             -> Subir Cluster Triplo + Balanceador"
        echo -e " 2) ${RED}[DOWN INSTANT]${NC}   -> Derrubar IMEDIATAMENTE Toda a Infraestrutura"
        echo -e " 3) ${CYAN}[START ALL]${NC}      -> Acordar Todos os Containers Pausados"
        echo -e " 4) ${YELLOW}[STOP ALL]${NC}       -> Pausar Execução de Todos os Serviços"
        echo -e " 5) ${MAGENTA}[METRICS]${NC}        -> Testar Distribuição de Carga Alternada"
        echo -e "10) ${RED}[EXIT]${NC}           -> Fechar Painel Sênior"
        echo -e "${MAGENTA}=====================================================================${NC}"
        read -rp "Selecione a ação (1-10): " opcao

        case ${opcao} in
            1)
                check_ports_strict
                log_info "Iniciando subida da stack..."
                docker compose up -d
                log_success "Cluster online na porta http://localhost:8080!"
                ;;
            2)
                log_warn "Executando KILL instantâneo na stack..."
                docker compose down --timeout 0 --volumes --remove-orphans
                log_success "Toda a infraestrutura foi eliminada instantaneamente."
                ;;
            3) docker compose start ;;
            4) docker compose stop ;;
            5)
                echo -e "\n${CYAN} VERIFICANDO EQUILÍBRIO ATIVO (ROUND-ROBIN):${NC}"
                for i in {1..6}; do
                    curl -s --connect-timeout 2 http://localhost:8080 | grep -E "Hostname|IP:" | sed 's/^/  /'
                    sleep 0.2
                done
                ;;
            10) break ;;
            *) log_warn "Opção inválida." ;;
        esac
    done
}

check_sudo
check_ports_soft
install_docker
generate_infrastructure_files
interactive_menu
