Balanceamento de Carga e Failover Dinâmico com NGINX e Docker

    📖1  Visão Geral
Este projeto apresenta a implementação prática de um laboratório de infraestrutura de redes resiliente e de alta disponibilidade, estruturado de acordo com os princípios de Infraestrutura como Código (IaC).

O objetivo é simular um cenário real de tráfego web, no qual o balanceador central distribui requisições entre servidores de aplicação redundantes.

        2 -Funcionalidades
🔄 Balanceamento de Carga (Round-Robin): distribuição alternada e justa das requisições.

⚠️ Failover Dinâmico: remoção imediata de servidores que falham.

♻️ Auto-Recuperação (Self-Healing): reinserção automática de servidores recuperados no cluster.

3 - 🏗️ Arquitetura do Sistema
A infraestrutura separa a camada de recepção de tráfego externo da camada de processamento de dados (backend).

Balanceador: NGINX Proxy Reverso (porta 8090).

Backend: três instâncias Docker (server1, server2, server3) rodando NGINX sobre Alpine Linux (porta 80).

Monitoramento: script em Bash que valida continuamente o estado dos containers.

Esquema Simplificado
Código
Usuário (Porta 8080)
        |
   Balanceador (NGINX Proxy Reverso)
        |
   -------------------------------
   |             |               |
Servidor 1    Servidor 2     Servidor 3
(Porta 80)   (Porta 80)     (Porta 80)

⚙️ 4 - Requisitos do Sistema
🖥️ CPU: mínimo 1 núcleo físico (recomendado 2 ou mais).

💾 Memória RAM: mínimo 2 GB livres.

📂 Disco: mínimo 500 MB livres para imagens Docker (NGINX + Alpine).

Como executar seguindo :
Instalação do WSL e do Ubuntu
            Vá em iniciar e escreva  PowerShell do Windows como Administrador ou cmd como administrador também e execute o seguinte comando para instalar o subsistema e a    distribuição                 padrão (Ubuntu):
            wsl --install -d Ubuntu
            Após a execução do comando, reinicie o seu computador se solicitado. Ao reiniciar, o Ubuntu
            será inicializado automaticamente e pedirá a criação de um utilizador e palavra-passe padrão
            de administração (sudo).


🚀 Como Executar
Passo 1 
. Clonar o repositório
Código
     git clone https://github.com/figueiredogomes-cmd/balanceador8090.git
     
    cd balanceador8090
    sudo ./infra_lb.sh up
     
 
Passo 2- No seu navegador ou web browser cole http://localhost:8090/

Passo 3- 
Cenário de Teste: Recuperação de Serviços (Self-Healing)
Inicie novamente o serviço que simulou a falha seja no servidor 2 como mostrado no comando ou servidor1 ou servidor3 :

   cd .
   
  cd ..
  
  ls
  
  cd servico-balanceamento
  
  sudo docker-compose start servidor2 ou sudo docker compose start servidor2

Passo 4-Simulação de Falha de Infraestrutura (Failover)
Abra uma janela de terminal paralela no WSL Ubuntu e execute o encerramento manual da
instância de qual servidor quer para no caso paramos o servidor2 como no comando abaixo,  mais poderia ser servidor 1 ou servidor 3 :

       cd .
       cd ..
       ls
       cd servico-balanceamento
       sudo docker-compose stop servidor2 ou sudo docker compose stop servidor2
       
       
        
Passo 5 -Para Remoção de containers entre usando os comandos para encontrar a pasta servico-balanceamento :
  
       cd .
       cd ..
       ls
     cd servico-balanceamento 
    sudo docker-compose down ou sudo docker compose down
                                     
Passo 6- Agora faça um refresh ou ctrl +r  ou f5 e atualize a página pois o navegador gravou essa página em memória temporária e verá que a página não foi encontrado atualmente ou copie e cole http://localhost:8090/  assim verá que a página para de carregar automaticamente .

Passo 7- Para se certificar que deu tudo certo de o comando : sudo docker ps ou sudo docker-compose
ps , e vai ver que não tem nenhum container instalado

        
 Autor
Lucas De Figueiredo Gomes  
Instituto Federal de Educação, Ciência e Tecnologia de Mato Grosso – Campus Cuiabá Octayde Jorge da Silva
Curso: Tecnologia Em Redes De Computadores

   Conclusão
        Este laboratório demonstra de forma pragmática o poder da combinação entre Docker e NGINX
        no provisionamento de infraestruturas modernas e robustas. Ao simular falhas de sistema em
        ambiente controlado e isolado através do ecossistema WSL, conclui-se que soluções de alta
        disponibilidade de nível empresarial podem ser replicadas, validadas e testadas usando pouquíssimos recursos computacionais             domésticos. O projeto serve como uma excelente base de conhecimento prático de engenharia de redes para disciplinas de computação e desenvolvimento de sistemas distribuídos.          

Disciplina: Programação Para Redes
Data: 12 de junho de 2026
