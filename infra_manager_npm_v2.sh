#!/usr/bin/env bash

# -------------------------------------------------------------------------
# Script: infra_manager_npm_v2.sh
# Descrição: Orquestrador DevOps - Cluster de Alta Disponibilidade com 3 Nós
# Visual: Terminal Cyberpunk Monitor Sincronizado com o Tráfego Real
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

check_ports() {
    log_info "Avaliando disponibilidade da porta 8080 no host..."
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ' :8080 '; then
            log_error "A porta 8080 já está em uso por outro processo do sistema."
        fi
    fi
}

install_docker() {
    log_info "Avaliando integridade do runtime do Docker..."
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        log_success "Docker Engine e Compose V2 validados e operacionais."
        return
    fi
    log_error "Docker ou Docker Compose não encontrados. Instale-os antes de prosseguir."
}

generate_infrastructure_files() {
    log_info "Injetando artefatos de configuração do balanceador de carga..."
    mkdir -p ./nginx_config

    # Configuração nativa de balanceamento Round Robin com 3 servidores ativos
    cat << 'EOF' > ./nginx_config/nginx.conf
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    
    upstream backend_cluster {
        server app_instance_1:3000;
        server app_instance_2:3000;
        server app_instance_3:3000;
    }

    server {
        listen 80;

        # Dashboard do Monitor
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }

        # Encaminhamento das requisições para os contêineres de aplicação
        location /status {
            proxy_pass http://backend_cluster;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        }
    }
}
EOF

    # Criação do arquivo declarativo docker-compose com os 3 nós solicitados
    cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  balanceador:
    image: nginx:alpine
    container_name: balanceador
    ports:
      - '8080:80'
    volumes:
      - ./nginx_config/nginx.conf:/etc/nginx/nginx.conf:ro
    command:
      - /bin/sh
      - -c
      - |
        # Criação do Front-End integrado no estilo Terminal Monitor do seu printscreen
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>TERMINAL MONITOR</title><style>body{background-color:#000000;color:#00ff00;font-family:"Courier New",Courier,monospace;padding:30px;display:flex;justify-content:center;} .main-box{border:3px solid #00ff00;padding:25px;border-radius:5px;width:100%;max-width:950px;box-shadow:0 0 15px rgba(0,255,0,0.3);} h1{text-align:center;font-size:1.7em;letter-spacing:2px;margin-bottom:10px;} .subtitle{text-align:center;font-size:0.9em;color:#00aa00;margin-bottom:30px;} .grid{display:flex;justify-content:space-between;gap:15px;} .card{border:1px solid #00ff00;width:32%;padding:20px;box-sizing:border-box;text-align:center;background:rgba(0,30,0,0.2);} .card-title{font-size:1.1em;font-weight:bold;border-bottom:1px dashed #00ff00;padding-bottom:10px;} .count{font-size:4.5em;font-weight:bold;margin:20px 0;text-shadow:0 0 10px #00ff00;} .status{font-size:0.9em;color:#00ff00;} .active-node{animation:blink 0.4s ease-in-out; background: rgba(0, 255, 0, 0.2);} @keyframes blink{0%{opacity: 0.4;} 100%{opacity: 1;}}</style></head><body><div class="main-box"><h1>>>> MONITOR DE INFRAESTRUTURA [BALANCEAMENTO REAL] <<<</h1><div class="subtitle">CONCEITO DE DISTRIBUIÇÃO EQUILIBRADA ATIVA - HTTP://LOCALHOST:8080</div><div class="grid"><div class="card" id="node1_card"><div class="card-title">[ SERVIDOR_01 ]</div><div class="count" id="c1">0</div><div class="status" id="s1">STATUS: ...</div></div><div class="card" id="node2_card"><div class="card-title">[ SERVIDOR_02 ]</div><div class="count" id="c2">0</div><div class="status" id="s2">STATUS: ...</div></div><div class="card" id="node3_card"><div class="card-title">[ SERVIDOR_03 ]</div><div class="count" id="c3">0</div><div class="status" id="s3">STATUS: ...</div></div></div></div><script>
        function dispararEAtualizar() {
            // Faz a requisição real passando pelo balanceador Nginx
            fetch("/status", { cache: "no-store" })
                .then(res => res.json())
                .then(data => {
                    // Remove destaques antigos
                    document.querySelectorAll(".card").forEach(c => c.classList.remove("active-node"));
                    
                    // Mapeia qual contêiner respondeu com base no ID retornado (ex: correspondente ao hostname)
                    if (data.machineName.includes("node1")) {
                        document.getElementById("c1").innerText = data.containerHits;
                        document.getElementById("s1").innerText = "STATUS: ONLINE (ID: " + data.machineName + ")";
                        document.getElementById("node1_card").classList.add("active-node");
                    } else if (data.machineName.includes("node2")) {
                        document.getElementById("c2").innerText = data.containerHits;
                        document.getElementById("s2").innerText = "STATUS: ONLINE (ID: " + data.machineName + ")";
                        document.getElementById("node2_card").classList.add("active-node");
                    } else if (data.machineName.includes("node3")) {
                        document.getElementById("c3").innerText = data.containerHits;
                        document.getElementById("s3").innerText = "STATUS: ONLINE (ID: " + data.machineName + ")";
                        document.getElementById("node3_card").classList.add("active-node");
                    }
                }).catch(err => console.log("Erro de comunicação..."));
        }
        
        // Executa uma requisição imediatamente ao carregar ou dar Refresh (F5) na página
        dispararEAtualizar();
        
        // Mantém requisições em lote simulando tráfego contínuo a cada 600ms
        setInterval(dispararEAtualizar, 600);
        </script></body></html>' > /usr/share/nginx/html/index.html
        nginx -g 'daemon off;'
    depends_on:
      - app_instance_1
      - app_instance_2
      - app_instance_3
    networks:
      - pro_mesh_network

  app_instance_1:
    image: node:18-alpine
    container_name: asr_node1
    command: >
      sh -c "echo 'const http = require(\"http\"); const os = require(\"os\"); let hits = 0; http.createServer((req, res) => { hits++; res.writeHead(200, { \"Content-Type\": \"application/json\" }); res.end(JSON.stringify({ status: \"online\", machineName: \"node1-\" + os.hostname().substring(0,6), containerHits: hits })); }).listen(3000);' > server.js && node server.js"
    networks:
      - pro_mesh_network

  app_instance_2:
    image: node:18-alpine
    container_name: asr_node2
    command: >
      sh -c "echo 'const http = require(\"http\"); const os = require(\"os\"); let hits = 0; http.createServer((req, res) => { hits++; res.writeHead(200, { \"Content-Type\": \"application/json\" }); res.end(JSON.stringify({ status: \"online\", machineName: \"node2-\" + os.hostname().substring(0,6), containerHits: hits })); }).listen(3000);' > server.js && node server.js"
    networks:
      - pro_mesh_network

  app_instance_3:
    image: node:18-alpine
    container_name: asr_node3
    command: >
      sh -c "echo 'const http = require(\"http\"); const os = require(\"os\"); let hits = 0; http.createServer((req, res) => { hits++; res.writeHead(200, { \"Content-Type\": \"application/json\" }); res.end(JSON.stringify({ status: \"online\", machineName: \"node3-\" + os.hostname().substring(0,6), containerHits: hits })); }).listen(3000);' > server.js && node server.js"
    networks:
      - pro_mesh_network

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
        echo -e "         ${GREEN}ORQUESTRADOR DE INFRAESTRUTURA PRO - HIGH AVAILABILITY${NC}"
        echo -e "${MAGENTA}=====================================================================${NC}"
        echo -e " 1) ${GREEN}[UP]${NC}      -> Subir Cluster com 3 Servidores + Balanceador"
        echo -e " 2) ${RED}[DOWN]${NC}    -> Parar e Remover Toda a Infraestrutura"
        echo -e " 3) ${RED}[EXIT]${NC}    -> Fechar Painel"
        echo -e "${MAGENTA}=====================================================================${NC}"
        read -rp "Selecione a ação (1-3): " opcao

        case ${opcao} in
            1)
                log_info "Subindo a estrutura em segundo plano..."
                docker compose up -d --remove-orphans
                log_success "Cluster online de forma real!"
                echo -e "${YELLOW}-> Acesse o painel gráfico em seu navegador: http://localhost:8080${NC}"
                ;;
            2)
                log_warn "Limpando contêineres e barramento de rede..."
                docker compose down -v
                log_success "Ambiente totalmente limpo."
                ;;
            3)
                log_success "Saindo. A stack continua rodando em background."
                break
                ;;
            *)
                log_warn "Opção inválida. Escolha de 1 a 3."
                ;;
        esac
    done
}

# Execução do Pipeline
check_sudo
check_ports
install_docker
generate_infrastructure_files
interactive_menu
