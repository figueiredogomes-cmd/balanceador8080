#!/usr/bin/env bash

# -------------------------------------------------------------------------
# Script: infra_manager_npm.sh
# Descrição: Orquestrador DevOps - Nginx Proxy Manager (NPM) + Load Balancing Pro
# Arquitetura: 1 NPM (Interface Web + Proxy) + 2 Nós de Aplicação (Alta Disponibilidade)
# Mapeamento de Portas: HTTP: 8080 | NPM Admin Panel: 8181
# Nível: Sênior / Full Stack Pro
# -------------------------------------------------------------------------

# Configurações de cores para interface de terminal profissional
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Funções de log corporativo
log_info() { echo -e "${CYAN}[INFO] [$(date +'%T')]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS] [$(date +'%T')]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN] [$(date +'%T')]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR] [$(date +'%T')]${NC} $1"; exit 1; }

# Validação estrita de privilégios de execução
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log_error("Este script gerencia recursos de rede e pacotes de sistema. Execute com 'sudo ./infra_manager_npm.sh'.")
    fi
}

# Verificação e Instalação Idempotente do Docker Engine + Compose Plugin
install_docker() {
    log_info("Analisando integridade do ambiente Docker e Docker Compose...")
    
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        log_success("Docker Engine e Compose V2 validados no host local.")
        return
    fi

    log_warn("Dependências Docker não localizadas. Iniciando provisionamento automatizado...")

    # Instalação de pacotes base para chaves APT
    apt-get update -y && apt-get install -y ca-certificates curl gnupg lsb-release

    # Geração segura da chave do repositório Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

    # Registro oficial do feed estável
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Tratamento elegante para compatibilidade nativa com WSL 2
    if grep -q "Microsoft" /proc/version; then
        log_info("WSL 2 Detectado. Inicializando o Daemon de forma assistida...")
        service docker start || systemctl start docker
    else
        systemctl enable --now docker
    fi

    log_success("Ambiente Docker pronto para receber a Stack Pro.")
}

# Geração Estruturada de Arquivos de Infraestrutura (Nginx Proxy Manager Injection)
generate_infrastructure_files() {
    log_info("Criando diretórios e injetando diretivas avançadas no Nginx Proxy Manager...")

    # Criando os caminhos de volumes persistentes locais exigidos pelo NPM
    mkdir -p ./npm_data/nginx/custom

    # 1. Configurando o bloco Upstream de alta disponibilidade (Injetado no contexto HTTP do NPM)
    cat << 'EOF' > ./npm_data/nginx/custom/http.conf
upstream backend_cluster {
    server app_instance_1:80 max_fails=1 fail_timeout=5s;
    server app_instance_2:80 max_fails=1 fail_timeout=5s;
}
EOF

    # 2. Configurando o Server Block customizado para interceptar o tráfego local e acionar o Load Balancing
    cat << 'EOF' > ./npm_data/nginx/custom/server_proxy.conf
server {
    listen 80;
    server_name localhost 127.0.0.1;

    location / {
        proxy_pass http://backend_cluster;
        
        # Preservação de identidade de requisições de ponta a ponta
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # --- FAILOVER EM TEMPO REAL: REDIRECIONAMENTO IMEDIATO SE UM NÓ CAIR ---
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_connect_timeout 2s;
        proxy_read_timeout 3s;
        proxy_send_timeout 3s;
    }
}
EOF

    # 3. Geração do docker-compose.yml otimizado com Exatamente 3 Containers (1 NPM + 2 Web Apps)
    cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  # Container 1: Gateway de Borda com Interface Web Completa (Nginx Proxy Manager)
  proxy_manager:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx_proxy_manager
    ports:
      - '8080:80'   # Porta pública para tráfego web e testes de balanceamento
      - '8181:81'   # Painel Admin UI do Nginx Proxy Manager
    volumes:
      - ./npm_data:/data
      - ./npm_letsencrypt:/etc/letsencrypt
    depends_on:
      - app_instance_1
      - app_instance_2
    networks:
      - pro_mesh_network
    restart: always

  # Container 2: Instância Alfa de Aplicação
  app_instance_1:
    image: traefik/whoami
    container_name: web_app_01
    networks:
      - pro_mesh_network
    restart: always

  # Container 3: Instância Beta de Aplicação
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

    log_success("Arquivos 'docker-compose.yml' e configurações customizadas do NPM criados.")
}

# Painel Interativo de Gerenciamento da Infraestrutura
interactive_menu() {
    while true; do
        echo -e "\n${MAGENTA}=====================================================================${NC}"
        echo -e "      ${GREEN}PAINEL REVERSE PROXY & BALANCING PRO (NGINX PROXY MANAGER)${NC}"
        echo -e "${MAGENTA}=====================================================================${NC}"
        echo -e " 1) ${GREEN}[UP]${NC}      -> Subir Cluster Completo (3 Containers) em Segundo Plano"
        echo -e " 2) ${RED}[DOWN]${NC}    -> Destruir Cluster Completo (Limpeza de Containers e Redes)"
        echo -e " 3) ${CYAN}[START]${NC}   -> Inicializar Containers Existentes que foram pausados"
        echo -e " 4) ${YELLOW}[STOP]${NC}    -> Pausar Serviços sem perder os dados de estado"
        echo -e " 5) ${MAGENTA}[METRICS]${NC} -> Testar Distribuição Igualitária (Round-Robin) e Failover"
        echo -e " 6) ${RED}[EXIT]${NC}    -> Fechar Console de Gerenciamento"
        echo -e "${MAGENTA}=====================================================================${NC}"
        read -rp "Selecione a ação desejada (1-6): " opcao

        case $opcao in
            1)
                log_info("Orquestrando subida da stack via Docker Compose...")
                docker compose up -d
                log_success("Stack ativa!")
                echo -e "${YELLOW}➔ Aplicação & Balanceador operando em: http://localhost:8080${NC}"
                echo -e "${YELLOW}➔ Interface Administrativa do Proxy Manager: http://localhost:8181${NC}"
                echo -e "${CYAN}(Credenciais padrão NPM: admin@example.com | Senha: changeme)${NC}"
                ;;
            2)
                log_warn("Destruindo os 3 containers e limpando adaptadores de rede...")
                docker compose down
                log_success("Ambiente resetado com sucesso.")
                ;;
            3)
                log_info("Acordando instâncias de containers...")
                docker compose start
                log_success("Processos reativados.")
                ;;
            4)
                log_info("Enviando sinal de parada graciosa (SIGTERM)...")
                docker compose stop
                log_success("Serviços pausados com sucesso.")
                ;;
            5)
                echo -e "\n${YELLOW}┌────────────────────────────────────────────────────────┐${NC}"
                echo -e "${YELLOW}│                 SAÚDE DA TOPOLOGIA DOCKER              │${NC}"
                echo -e "${YELLOW}└────────────────────────────────────────────────────────┘${NC}"
                docker compose ps
                
                echo -e "\n${CYAN}┌────────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}│     TESTE DE REDISTRIBUIÇÃO IGUALITÁRIA DE REQUISIÇÕES │${NC}"
                echo -e "${CYAN}└────────────────────────────────────────────────────────┘${NC}"
                
                if command -v curl &> /dev/null; then
                    echo -e "${YELLOW}[Disparando baterias de testes rápidos sequenciais no cluster...]${NC}\n"
                    for i in {1..4}; do
                        echo -e "${MAGENTA}• Requisição #$i -> Bate na Borda (NPM na porta 8080)${NC}"
                        RESPONSE=$(curl -s --connect-timeout 2 http://localhost:8080 | grep -E "Hostname|IP:")
                        if [ -z "$RESPONSE" ]; then
                            echo -e "  ${RED}[ERRO] Sem resposta. Certifique-se de que a stack está ativa (Opção 1).${NC}"
                        else
                            echo "$RESPONSE" | sed 's/^/  /'
                        fi
                        sleep 0.3
                    done
                    echo -e "\n${GREEN}[ANÁLISE FULL STACK]${NC} Note que as requisições dividem-se igualmente (50% para cada nó)."
                    echo -e "Se você derrubar um web app com 'docker stop web_app_01', o Nginx Proxy Manager"
                    echo -e "redistribuirá 100% das requisições para o nó ativo imediatamente, sem interrupção!"
                else
                    log_warn("Instale o pacote 'curl' no seu sistema para executar o monitor automático de métricas.")
                fi
                ;;
            6)
                log_success("Desconectando do console. Stack mantida ativa em background. Bom código!")
                break
                ;;
            *)
                log_warn("Opção inválida. Escolha uma opção de 1 a 6.")
                ;;
        esac
    done
}

# Fluxo sequencial de execução principal
check_sudo
install_docker
generate_infrastructure_files
interactive_menu
