#!/bin/bash

function helpMe(){
    # output standard usage
    echo -e "Usage: `basename $0` <email_address> '<apache_password>'\n\nYour password should be placed in single quotes 'password'";
}

# check user's passed argument
if [[ $# == 0 ]]; then
    helpMe;
    exit;
else
    tmp_email=$(echo "$1" | tr '[:upper:]' '[:lower:]');
    if [[ $(grep -E "^[a-z0-9._+-]+@[a-z0-9.-]+\.[a-z]{2,10}$" <(echo ${1})) ]]; then
        perm_email=${tmp_email};
    else
        echo "Please enter in a valid email" 1>&2;
        exit;
    fi
    if [[ -z "$2" ]]; then
        echo "Password required as second argument" 1>&2;
        exit;
    else
        password=${2};
    fi
fi

function servPrep(){
    #add nagios group and user
    sudo groupadd nagcmd;
    sudo useradd -c "Nagios user" -G nagcmd nagios;

    # install build dependencies
    sudo apt-get update && sudo apt-get upgrade -y;
    apt-get install build-essential libgd2-xpm-dev openssl libssl-dev xinetd apache2-utils unzip -y;
}

function prereq(){
    sudo apt-get install apache2 php5-mysql php5 libapache2-mod-php5 php5-mcrypt php5-cli php5-cgi php5-common php5-curl -y;
    sed -i 's/index.html/index.php/1' /etc/apache2/mods-enabled/dir.conf;
    sed -i 's/index.php/index.html/2' /etc/apache2/mods-enabled/dir.conf;
    echo "ServerName ${HOSTNAME}" >> /etc/apache2/apache2.conf;
}

# install nagios core
function nagiosCore(){
    cd ~;
    curl -L -O https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.1.1.tar.gz;
    tar -xzvf nagios-4.1.1.tar.gz;
    cd nagios-*;
    ./configure --with-nagios-group=nagios --with-command-group=nagcmd;
    make all;
    sudo make install;
    sudo make install-commandmode;
    sudo make install-init;
    sudo make install-config;
    sudo /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf;
    sudo usermod -G nagcmd www-data;
}

# install nagios plugins
function nagiosPlugins(){
    cd ~;
    curl -L -O http://nagios-plugins.org/download/nagios-plugins-2.1.1.tar.gz;
    tar -xzvf nagios-plugins-*.tar.gz;
    cd nagios-plugins-*;
    ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl;
    make;
    sudo make install;
}

# install NRPE
function nagiosNRPE(){
    cd ~;
    curl -L -O http://downloads.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz;
    tar -xzvf nrpe-*;
    cd nrpe-*;
    ./configure --enable-command-args --with-nagios-user=nagios --with-nagios-group=nagios --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu;
    make all;
    make install;
    make install-xinetd;
    make install-daemon-config;
}

# configure nagios
function configureNagios(){
    # get private IP
    priv_ip=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address);
    sudo sed -i "/only_from/s/$/ ${priv_ip}/" /etc/xinetd.d/nrpe;
    sudo service xinetd restart;

    sed -i 's&#cfg_dir=.*servers&cfg_dir=/usr/local/nagios/etc/servers&1' /usr/local/nagios/etc/nagios.cfg;
    sudo echo -e "enable_event_handlers=1\ncommand_check_interval=30s" >> /usr/local/nagios/etc/nagios.cfg;
    sudo mkdir -p /usr/local/nagios/etc/servers;
    # create sample host configuration file
sudo cat << _EOF_ > /usr/local/nagios/etc/servers/sample.cfg.txt
define host {
    use                             linux-server
    host_name                       web1
    alias                           application node
    address                         10.134.9.156
    max_check_attempts              5
    check_period                    24x7
    notification_interval           30
    notification_period             24x7
}

define service {
    use                             generic-service
    host_name                       web1
    service_description             loadavg
    check_command                   check_nrpe!check_load
    max_check_attempts              5
    check_interval                  5
    retry_interval                  3
    check_period                    24x7
    notification_interval           30
    notification_period             24x7
    notification_options            w,c,r
}
_EOF_
    # uncomment if you want to run interactively on your server
    sed -i "s/nagios@localhost/${perm_emai}/" /usr/local/nagios/etc/objects/contacts.cfg
    # configure check_nrpe command
    echo "define command{
  command_name check_nrpe
  command_line \$USER1$/check_nrpe -H \$HOSTADDRESS$ -c \$ARG1$
}" >> /usr/local/nagios/etc/objects/commands.cfg

    #enable nagios site
    cd /etc/apache2/sites-available/;
    a2ensite nagios.conf;
    cd ~;
}

# configure check_nrpe commands



# configure nagiosuser
function accessControl(){
    sudo a2enmod rewrite;
    sudo a2enmod cgi;
    sudo htpasswd -b -c /usr/local/nagios/etc/htpasswd.users nagiosadmin ${password};

    # enable nagios to start on reboot
    sudo ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios;

    sudo service nagios start;
    sudo service apache2 restart;
}

servPrep;
prereq;
nagiosCore;
nagiosPlugins;
nagiosNRPE;
configureNagios;
accessControl;
