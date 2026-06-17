#!/bin/bash

# Define o local do projeto
PROJETO_DIR="$HOME/cluster-balanceado"

echo "================================================="
echo "   SISTEMA DE BALANCEAMENTO DE CARGA NATIVO      "
echo "   Nginx Load Balancer + 3 Servidores Web        "
echo "================================================="
sleep 1

# 1. Limpeza de resquícios de instalações antigas travadas
echo "[1/6] Limpando repositórios e travas do APT..."
sudo rm -f /etc/apt/sources.list.d/docker*.list
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null

# 2. Instalação limpa e oficial do Docker + Compose (Padrão Ubuntu 24.04)
echo "[2/6] Instalando Docker e Docker Compose de forma automatizada..."
sudo apt update -y && sudo apt install -y curl
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm -f get-docker.sh

# 3. Inicialização e garantia do serviço do Docker no WSL
echo "[3/6] Iniciando o motor do Docker..."
sudo service docker start
sleep 3

# 4. Criação da estrutura de diretórios para o Cluster
echo "[4/6] Criando pastas do projeto..."
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,srv1,srv2,srv3}
cd "$PROJETO_DIR" || exit

# 5. Criando os arquivos de status que simulam as aplicações web
echo "[5/6] Gerando páginas internas dos servidores..."
echo '{"servidor":"Servidor Web 01","cor":"#22c55e"}' > srv1/status.json
echo '{"servidor":"Servidor Web 02","cor":"#3b82f6"}' > srv2/status.json
echo '{"servidor":"Servidor Web 03","cor":"#f59e0b"}' > srv3/status.json

# 6. Criando a interface gráfica (Dashboard) para ver o balanceamento acontecer
echo "[6/6] Criando interface visual de monitoramento..."
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <title>Dashboard Load Balancer Nginx</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box;font-family:sans-serif;}
        body{background:#0f172a;height:100vh;display:flex;flex-direction:column;justify-content:center;align-items:center;color:#fff;}
        .card{width:650px;padding:40px;text-align:center;border-radius:20px;background:rgba(255,255,255,.05);backdrop-filter:blur(10px);box-shadow:0 10px 30px rgba(0,0,0,0.5);}
        h1{font-size:2.3rem;margin-bottom:20px;}
        .cluster{display:flex;justify-content:space-between;margin-top:30px;gap:15px;}
        .box{flex:1;padding:15px;background:#1e293b;border-radius:10px;border-bottom:4px solid #475569;}
        .count{font-size:1.8rem;font-weight:bold;margin-top:5px;}
    </style>
</head>
<body>

<div class="card">
    <p style="color:#94a3b8; text-transform:uppercase; font-size:12px; letter-spacing:1px;">Requisição HTTP Processada por:</p>
    <h1 id="srv_nome">Conectando ao Balanceador...</h1>

    <div class="cluster">
        <div class="box" style="border-bottom-color:#22c55e;">
            <div>Servidor 1</div>
            <div class="count" id="c_srv1" style="color:#22c55e;">0</div>
        </div>
        <div class="box" style="border-bottom-color:#3b82f6;">
            <div>Servidor 2</div>
            <div class="count" id="c_srv2" style="color:#3b82f6;">0</div>
        </div>
        <div class="box" style="border-bottom-color:#f59e0b;">
            <div>Servidor 3</div>
            <div class="count" id="c_srv3" style="color:#f59e0b;">0</div>
        </div>
    </div>
</div>

<script>
const contadores = {"Servidor Web 01": 0, "Servidor Web 02": 0, "Servidor Web 03": 0};
const ids = {"Servidor Web 01": "c_srv1", "Servidor Web 02": "c_srv2", "Servidor Web 03": "c_srv3"};

async function enviarRequisicao(){
    try {
        // Envia requisição para a rota única do balanceador. O Nginx distribui o tráfego nativamente.
        const r = await fetch('/api/status?cache=' + Date.now());
        const d = await r.json();
        
        document.getElementById("srv_nome").innerText = d.servidor;
        document.getElementById("srv_nome").style.color = d.cor;

        if(contadores[d.servidor] !== undefined){
            contadores[d.servidor]++;
            document.getElementById(ids[d.servidor]).innerText = contadores[d.servidor];
        }
    } catch(e) {
        document.getElementById("srv_nome").innerText = "ERRO: Sem resposta do cluster";
        document.getElementById("srv_nome").style.color = "#ef4444";
    }
}
// Dispara uma requisição a cada 800ms para ver o balanceamento dinâmico
setInterval(enviarRequisicao, 800);
enviarRequisicao();
</script>
</body>
</html>
EOF

# 7. Configurando o arquivo de Load Balancing Nativo do Nginx (Upstream)
echo "[+] Configurando Nginx Upstream (Round-Robin nativo)..."
cat > nginx/conf.d/loadbalancer.conf <<EOF
upstream cluster_aplicacao {
    # Nginx distribui as requisições de forma transparente e uniforme entre estes 3 nós
    server srv1:80 max_fails=1 fail_timeout=2s;
    server srv2:80 max_fails=1 fail_timeout=2s;
    server srv3:80 max_fails=1 fail_timeout=2s;
}

server {
    listen 8080;

    # Entrega a interface web de monitoramento
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    # Proxy reverso inteligente que envia o tráfego HTTP para o upstream balanceado
    location /api/status {
        proxy_pass http://cluster_aplicacao/status.json;
        proxy_connect_timeout 1s;
        proxy_read_timeout 1s;
    }
}
EOF

# 8. Construindo a Infraestrutura com Docker Compose
echo "[+] Criando arquitetura docker-compose.yml..."
cat > docker-compose.yml <<EOF
services:
  srv1:
    image: nginx:alpine
    container_name: srv1
    volumes:
      - ./srv1:/usr/share/nginx/html

  srv2:
    image: nginx:alpine
    container_name: srv2
    volumes:
      - ./srv2:/usr/share/nginx/html

  srv3:
    image: nginx:alpine
    container_name: srv3
    volumes:
      - ./srv3:/usr/share/nginx/html

  balanceador:
    image: nginx:alpine
    container_name: balanceador
    ports:
      - "8080:8080"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./frontend:/usr/share/nginx/html
EOF

# 9. Inicializando todo o ecossistema
echo "[+] Subindo infraestrutura e aplicando balanceamento de carga..."
sudo docker compose down --remove-orphans
sudo docker compose up -d

# Menu interativo para gerenciamento dos containers
while true; do
    echo ""
    echo "=========================================================="
    echo " ACESSE NO NAVEGADOR: http://localhost:8080"
    echo "=========================================================="
    echo " [1] LIGAR / INICIAR todos os containers (up -d)"
    echo " [2] DESLIGAR / PARAR os containers temporariamente (stop)"
    echo " [3] DESTRUIR / REMOVER toda a estrutura (down)"
    echo " [4] SAIR do gerenciador (Mantém o estado atual)"
    echo "=========================================================="
    read -p "Escolha um comando [1-4]: " OPT

    case $OPT in
        1)
            echo "Ligando containers..."
            sudo docker compose up -d
            ;;
        2)
            echo "Pausando containers..."
            sudo docker compose stop
            ;;
        3)
            echo "Removendo e destruindo containers..."
            sudo docker compose down --remove-orphans
            ;;
        4)
            echo "Saindo... Cluster executando em segundo plano!"
            break
            ;;
        *)
            echo "Opção inválida."
            ;;
    esac
done
