#/bin/bash

# Variáveis de ambiente
REPO_URL="https://github.com/NeckBlick/gs-linux.git"
DOMAIN="nicolas.local"
ZONE_DIR="/etc/bind/zones"
ZONE_FILE="$ZONE_DIR/$DOMAIN.zone"
IP_NS1=$(ip -4 addr show enp0s1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
IP_NS2=""
HTML_DIR="/var/www/html"
GREEN="\e[00;32m"
END="\e[00m"


confirmar() {
    echo -e "\n\n $GREEN [+] Deseja continuar a instalação ? (s/n): $END \n\n"
    read resposta
    if [[ "$resposta" != "s" && "$resposta" != "S" ]]; then
        echo "Instalação cancelada pelo usuário."
        exit 1
    fi
}

# Atualização e instalação dos pacotes
update() {
    echo -e "\n\n $GREEN [+] Atualizando os pacotes do sistema... $END \n\n"
    sudo apt update -y
    echo "Atualização concluída."

    echo -e "\n\n $GREEN [+] Instalando pacotes necessários... $END \n\n"
    sudo apt install apache2 bind9 git -y
    echo "Pacotes instalados."
}

# Download do repositório e configuração do Apache
download_html_and_configuring_apache() {
    confirmar
    echo -e "\n\n $GREEN [+] Removendo arquivos antigos... $END \n\n"
    rm -rf $HTML_DIR/*

    echo -e "\n\n $GREEN [+] Clonando o repositório... $END \n\n"
    git clone $REPO_URL
    cd gs-linux
    cp -r * $HTML_DIR
    echo "Arquivos copiados."

    echo -e "\n\n $GREEN [+] Configurando permissões... $END \n\n" 
    sudo chown -R www-data:www-data $HTML_DIR
    sudo chmod -R 755 $HTML_DIR
    echo "Permissões configuradas."

    echo -e "\n\n $GREEN [+] Configurando o Apache...$END \n\n"
    sudo a2enmod rewrite
    sudo systemctl start apache2
    sudo systemctl restart apache2
    sudo systemctl enable apache2
    echo "Apache configurado."
}

# Configuração do DNS
config_dns(){
    confirmar
    echo -e "\n\n $GREEN [+] Configurando o DNS... $END \n\n"
    sed -i '1s/^/# /' /etc/apt/sources.list
    mkdir -p $ZONE_DIR
    zone=$(cat <<EOF
zone "$DOMAIN" IN {
    type master;
    file "$ZONE_FILE";
};
EOF
)
    echo "$zone" | tee -a /etc/bind/named.conf.local
    echo "Zona configuração."
register=$(cat <<EOF
\$TTL 300
@   IN  SOA $DOMAIN. admin.$DOMAIN. (
    2024090401   ; Serial
    86400        ; Refresh
    7200         ; Retry
    3600000      ; Expire
    172000       ; Minimum TTL
)

@   IN  NS  ns1.$DOMAIN.
@   IN  NS  ns2.$DOMAIN.
@   IN  MX  10 mail.$DOMAIN.

ns1 IN  A   $IP_NS1
ns2 IN  A   $IP_NS2
www IN  A   $IP_NS1
mail    IN  A   $IP_NS1
EOF
)

    echo "$register" | tee -a $ZONE_FILE
    echo "Arquivo de zona criado."

    echo -e "\n\n $GREEN [+] Reiniciando o serviço do DNS... $END \n\n"
    sudo systemctl restart bind9
    sudo systemctl enable bind9
    sudo systemctl start bind9
}

# Execução do script
main(){
    confirmar
    update
    download_html_and_configuring_apache
    config_dns

    echo -e "\n\n $GREEN [+] Instalação concluída. $END \n\n"
}

main