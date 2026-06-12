        Instituto Federal de Educação, Ciência e Tecnologia de Mato Grosso Campus Cuiabá - Octayde Jorge da Silva
       Curso: Tecnologia em Análise e Desenvolvimento de Sistemas / Redes
      Disciplina: Programação Para Redes
       Data: 12 de junho de 2026
    #Implementação de Balanceamento de Carga e
    Failover Dinâmico com NGINX e Docker
    Identificador do Projeto: #balanceador8090
        
1 Visão Geral:
   
   Este projeto apresenta a implementação prática de um laboratório de infraestrutura de redes
    resiliente e de alta disponibilidade, estruturado de acordo com os princípios de Infraestrutura
    como Código (IaC).
    O principal objetivo deste ambiente é simular um cenário real de tráfego web, no qual o
    balanceador central distribui requisições entre servidores de aplicação redundantes. O sistema
    integra as seguintes funcionalidades críticas:
    - Balanceamento de Carga Automatizado (Round-Robin): Distribuição equitativa e alternada das requisições web externas entre as instâncias internas de backend.
    - Tolerância a Falhas Dinâmica (Failover): Monitorização passiva dos nós de backend.
    Caso um servidor falhe, ele é expurgado das rotas de encaminhamento instantaneamente.
    - Auto-Recuperação (Self-Healing): Reinserção automática do nó recuperado ao cluster
    de balanceamento, sem necessidade de reinicialização do proxy reverso (NGINX) ou de
    intervenção manual do utilizador.
       Arquitetura do Sistema
       A infraestrutura foi desenhada para separar claramente a camada de receção de tráfego externo da camada de processamento de   dados (backend).

   Zona Descrição
   Balanceador (Edge) Ponto de entrada de tráfego configurado na porta pública 8090. Utiliza o NGINX para intercetar as chamadas e delegá-las aos servidores internos.
Backend (Websites) Composto por três instâncias Docker isoladas (server1, server2, e
server3) executando NGINX sobre a distribuição leve Alpine Linux,
respondendo internamente na porta 80.
Monitorização Um script em Bash corre em ciclo contínuo, validando o estado de
prontidão de cada container no sistema e relatando qualquer anomalia diretamente na consola.
Esquema da Arquitetura do Sistema (#balanceador8090)
Utilizador
(Porta 8090)
✲
Balanceador
NGINX
Proxy Reverso
✟✟✟
✟✟✟✯
✲
❍❍❍❍❍❍❥
Servidor 1
(Porta 80)
Servidor 2
(Porta 80)
Servidor 3
(Porta 80)
Fluxo de tráfego de rede e roteamento inteligente do proxy reverso.

2  Requisitos do Sistema e Homologação
   
*  O ambiente foi desenvolvido com foco em eficiência de recursos, sendo extremamente leve e
executável em máquinas domésticas convencionais.
    - Processador (CPU): Mínimo de 1 Núcleo físico (Recomendado: 2 Núcleos ou superior).
    - Memória RAM disponível: Mínimo de 2 GB livres.
    - Espaço em Disco: Mínimo de 500 MB livres para as imagens base do Docker (NGINX e
    Alpine).

  3
Especificações do Ambiente de Homologação
Hardware Utilizado nos Testes de Homologação
Sistema Operativo Arquitetura CPU Memória RAM Armazenamento Mínimo
Windows 10/11 + WSL 2 (Ubuntu) Intel/AMD x86_64 4 GB Dedicados 10 GB Livres (Geral)

Passo 1:
Instalação do WSL e do Ubuntu
Abra o PowerShell do Windows como Administrador e execute o seguinte comando para instalar o subsistema e a distribuição padrão (Ubuntu):
wsl --install -d Ubuntu
Após a execução do comando, reinicie o seu computador se solicitado. Ao reiniciar, o Ubuntu
será inicializado automaticamente e pedirá a criação de um utilizador e palavra-passe padrão
de administração (sudo).

 Passo 2: Atualização do Ambiente Interno do Ubuntu
Dentro do terminal do seu Ubuntu recém-instalado, execute o comando de atualização de segurança do sistema:
sudo apt update && sudo apt upgrade -y


        Passo 3:
        
           git clone https://github.com/figueiredogomes-cmd/balanceador8090.git
           
            cd servico-balanceamento
            
            ls 
            
           bash ./setup.sh
    
 
   #Execução do Script de Automação
Com o repositório clonado localmente, basta executar o instalador integrado, que configurará
as dependências do Docker e iniciará todos os containers:
bash ./setup.sh
  
  * No seu navegador ou web browser
    cole http://localhost:8090/
    
  * Remocao de containers legados para evitar conflitos de portas e de um refresh ou ctrl r ou f5 e atualize a página pois o navegador gravou essa página em memória temporária e verá que a página não foi encontrado atualmente 
    sudo docker-compose down

 * para se certificar que deu tudo certo de
   o comando e vai ver que não tem nenhum container instalado :
      sudo docker ps   
    
     Inicializacao dos containers em modo background
         docker-compose up -d
       echo "Ambiente iniciado com sucesso!"
      echo "Pressione [CTRL+C] para encerrar a monitorizacao."
      echo "==========================================="
      Ciclo infinito de monitorizacao de saude dos servidores de backend
   while true
    do
  docker ps --format "{{.Names}}" | grep -q server1 || echo "ALERTA: SERVER1 OFFLINE"
  docker ps --format "{{.Names}}" | grep -q server2 || echo "ALERTA: SERVER2 OFFLINE"
 docker ps --format "{{.Names}}" | grep -q server3 || echo "ALERTA: SERVER3 OFFLINE"
 sleep 5
 done

     Configuração das Regras do Balanceador (nginx.conf)
     Configura a distribuição do tráfego do NGINX usando a diretiva upstream. Define também o
     limiar de tolerância a falhas (max_fails=2 fail_timeout=10s) e as regras de fallback.
      Listing 2: Ficheiro nginx.conf
      events {}
      http {
                # Definio do cluster de servidores de aplicacao
            upstream backend {
            server server1:80 max_fails=2 fail_timeout=10s;
            5
            server server2:80 max_fails=2 fail_timeout=10s;
            server server3:80 max_fails=2 fail_timeout=10s;
            }
            server {
            listen 80;
            location / {
            # Define quais falhas do upstream forcam o roteamento para o proximo nó livre
            proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
            proxy_pass http://backend;
            }
            }
            }
            6
            
            Orquestração de Recursos (docker-compose.yml)
            Orquestra a criação automática da rede local virtualizada e define as propriedades de isolamento e execução contínua de                 cada container de aplicação.
            Listing 3: Ficheiro docker-compose.yml
            version: "3.8"
            services:
            nginx:
            image: nginx:latest
            container_name: balanceador
            restart: always
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
            restart: always
            server2:
            image: nginx:alpine
            container_name: server2
            restart: always
            server3:
            image: nginx:alpine
            container_name: server3
            restart: always

            
         Resultado Esperado: 
               O terminal e o navegador alternam entre as instâncias seguindo o
            modelo cíclico de distribuição:
            Servidor 1 → Servidor 2 → Servidor 3 → Servidor 1.
            
              Simulação de Falha de Infraestrutura (Failover)
             
           Abra uma janela de terminal paralela no WSL Ubuntu e execute o encerramento manual da
            instância número 2:
            docker stop server2
            
            - Comportamento da Monitorização (install.sh): O terminal exibirá ativamente após 5
            segundos:
             ALERTA: SERVER2 OFFLINE
          - Comportamento do Balanceador: O NGINX deteta a falha na comunicação com o socket
            do server2, marca o nó como inativo temporariamente e desvia o tráfego.
            - Resultado Esperado: Sem que o utilizador note qualquer erro no ecrã (como falhas 502
            Bad Gateway), o fluxo passa a ser:
            Servidor 1 → Servidor 3 → Servidor 1 → Servidor 3.
            
          
          Cenário de Teste: Recuperação de Serviços (Self-Healing)
            Inicie novamente o serviço que simulou a falha:
            docker start server2
        
             
                   Comportamento da Monitorização (install.sh): 
                  O alerta sobre o estado offline do server2
               deixa de ser exibido na consola de forma imediata.
          - Comportamento do Balanceador: O NGINX, de forma autónoma e sem requerer o reinício do seu serviço ou alteração manual de             ficheiros, reincorpora o server2 no cluster.
            - Resultado Esperado: O comportamento nominal inicial é restabelecido no navegador:
            Servidor 1 → Servidor 2 → Servidor 3 → Servidor 1.
            
             Conclusão
            Este laboratório demonstra de forma pragmática o poder da combinação entre Docker e NGINX
            no provisionamento de infraestruturas modernas e robustas. Ao simular falhas de sistema em
            ambiente controlado e isolado através do ecossistema WSL, conclui-se que soluções de alta
            disponibilidade de nível empresarial podem ser replicadas, validadas e testadas usando pouquíssimos recursos computacionais             domésticos. O projeto serve como uma excelente base de conhecimento prático de engenharia de redes para disciplinas de computação e desenvolvimento de sistemas distribuídos.
            
