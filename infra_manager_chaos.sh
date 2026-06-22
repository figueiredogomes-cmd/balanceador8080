#!/usr/bin/env bash

# -------------------------------------------------------------------------
# Script: cluster_orchestrator_v3.sh
# Descrição: Enterprise DevOps Chaos Engineering Sandbox (3 Nodes + Ultra Fast Teardown)
# Arquitetura: 1 Gateway de Borda (Porta 8080) + 3 Application Nodes Isolados
# Nível: Sênior / Tech Lead Pro (Zero Syntax Errors / Smart Port Recovery)
# -------------------------------------------------------------------------

# Configurações estritas de cores para output limpo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Helpers de Log Corporativo (Sintaxe corrigida sem parênteses nos argumentos)
log_info() { echo -e "${CYAN}[INFO] [$(date +'%T')]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS] [$(date +'%T')]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN] [$(date +'%T')]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR] [$(date +'%T')]${NC} $1"; exit 1; }

# Validação defensiva de privilégios de Superusuário
check_sudo() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${RED}[ERROR] Privilégios insuficientes. Execute usando: sudo $0${NC}"
        exit 1
    fi
}

# Validação inteligente de portas (Não derruba o script no início para permitir o DOWN)
check_ports_soft() {
    log_info "Avaliando disponibilidade da porta de borda 8080 no host..."
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ':8080 '; then
            log_warn "A porta 8080 já está em uso. Se for o seu cluster antigo, use a opção 2 do menu para limpá-lo!"
        fi
    fi
}

# Verificação estrita antes de subir a infraestrutura
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

# Provisionamento Idempotente do Docker Engine e Compose V2
install_docker() {
    log_info "Avaliando integridade do runtime do Docker..."
    
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        log_success "Docker Engine e Compose V2 validados e operacionais."
        return
    fi

    log_warn "Dependências ausentes. Iniciando instalação automatizada da stack estável..."
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

# Geração Limpa de Configurações com Distribuição Tripla (Alinhado com o Vídeo)
generate_infrastructure_files() {
    log_info "Injetando artefatos de infraestrutura nos volumes locais..."
    mkdir -p ./npm_data/nginx/custom

    # Configuração Upstream de Alta Disponibilidade para 3 Servidores
    cat << 'EOF' > ./npm_data/nginx/custom/http.conf
upstream backend_cluster {
    server app_instance_1:80 max_fails=1 fail_timeout=5s;
    server app_instance_2:80 max_fails=1 fail_timeout=5s;
    server app_instance_3:80 max_fails=1 fail_timeout=5s;
}
EOF

    # Configuração do Servidor de Borda com limit_rate para simular a carga visual do vídeo
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

        # Controla a taxa de entrega para simular o comportamento de análise visual
        limit_rate 150;
    }
}
EOF

    # Docker Compose Declarativo - Topologia com 3 Nós de Aplicação (Porta 8181 Removida)
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

# Painel Console de Operações Interativas (Chaos Engineering Edition)
interactive_menu() {
    while true; do
        echo -e "\n${MAGENTA}=====================================================================${NC}"
        echo -e "         ${GREEN}ORQUESTRADOR DE INFRAESTRUTURA PRO - 3 NODES CLUSTER${NC}"
        echo -e "${MAGENTA}=====================================================================${NC}"
        echo -e " 1) ${GREEN}[UP]${NC}             -> Subir Cluster Triplo (Modo Monitor Ativo)"
        echo -e " 2) ${RED}[DOWN INSTANT]${NC}   -> Derrubar IMEDIATAMENTE Toda a Infraestrutura (Tempo Zero)"
        echo -e " 3) ${CYAN}[START ALL]${NC}      -> Acordar Todos os Containers Pausados"
        echo -e " 4) ${YELLOW}[STOP ALL]${NC}       -> Pausar Execução de Todos os Serviços"
        echo -e " 5) ${MAGENTA}[METRICS]${NC}        -> Testar Distribuição de Carga Alternada (Vídeo)"
        echo -e "--------------------------- CHAOS ENGINEERING -----------------------"
        echo -e " 6) ${RED}[KILL SERV 1]${NC}    -> Apagar imediatamente o Servidor 1 (web_app_01)"
        echo -e " 7) ${RED}[KILL SERV 2]${NC}    -> Apagar imediatamente o Servidor 2 (web_app_02)"
        echo -e " 8) ${RED}[KILL SERV 3]${NC}    -> Apagar imediatamente o Servidor 3 (web_app_03)"
        echo -e " 9) ${GREEN}[RECOVER ALL]${NC}    -> Ressuscitar/Ligar todos os nós de uma vez"
        echo -e "10) ${RED}[EXIT]${NC}           -> Fechar Painel Sênior"
        echo -e "${MAGENTA}=====================================================================${NC}"
        read -rp "Selecione a ação de infraestrutura (1-10): " opcao

        case ${opcao} in
            1)
                check_ports_strict
                log_info "Iniciando subida da stack em segundo plano..."
                docker compose up -d
                log_success "Cluster online!"
                echo -e "${YELLOW}-> Monitor de Infraestrutura ativo na porta: http://localhost:8080${NC}"
                ;;
            2)
                log_warn "Executando KILL instantâneo na stack (--timeout 0)..."
                docker compose down --timeout 0 --volumes --remove-orphans
                log_success "Toda a infraestrutura foi eliminada instantaneamente."
                ;;
            3)
                log_info "Acordando instâncias globais..."
                docker compose start
                log_success "Containers ativos."
                ;;
            4)
                log_info "Enviando sinal SIGTERM para a stack..."
                docker compose stop
                log_success "Serviços pausados."
                ;;
            5)
                echo -e "\n${YELLOW} STATUS ATUAL DOS CONTAINERS:${NC}"
                docker compose ps
                echo -e "\n${CYAN} VERIFICANDO EQUILÍBRIO ATIVO (ROUND-ROBIN):${NC}"
                if command -v curl &> /dev/null; then
                    for i in {1..6}; do
                        echo -e "${MAGENTA}* Requisição #$i para http://localhost:8080:${NC}"
                        curl -s --connect-timeout 3 http://localhost:8080 | grep -E "Hostname|IP:" | sed 's/^/  /'
                        sleep 0.3
                    done
                else
                    log_warn "Instale o curl para rodar os testes automatizados do terminal."
                fi
                ;;
            6)
                log_warn "Derrubando IMEDIATAMENTE o Servidor 1 (web_app_01)..."
                docker stop --time 0 web_app_01
                log_success "Servidor 1 offline."
                ;;
            7)
                log_warn "Derrubando IMEDIATAMENTE o Servidor 2 (web_app_02)..."
                docker stop --time 0 web_app_02
                log_success "Servidor 2 offline."
                ;;
            8)
                log_warn "Derrubando IMEDIATAMENTE o Servidor 3 (web_app_03)..."
                docker stop --time 0 web_app_03
                log_success "Servidor 3 offline."
                ;;
            9)
                log_info "Enviando comando de boot para todos os nós individuais..."
                docker start web_app_01 web_app_02 web_app_03 nginx_proxy_manager
                log_success "Todos os nós foram restabelecidos com sucesso."
                ;;
            10)
                log_success "Saindo do painel. A infraestrutura continua ativa em background."
                break
                ;;
            *)
                log_warn "Opção inválida. Escolha de 1 a 10."
                ;;
        esac
    done
}

# Pipeline Executável Estrito e Sequencial
check_sudo
check_ports_soft
install_docker
generate_infrastructure_files
interactive_menu
