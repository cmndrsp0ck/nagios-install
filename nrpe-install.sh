#!/bin/bash

function helpMe(){
    # output standard usage
    echo -e "Usage: `basename $0` nagios_serv_private_ip";
}

# check user args
if [[ $# == 0 ]]; then
    helpMe;
    exit;
else
    master_priv_ip=$1;
fi

# install nrpe
function installNRPE(){
    sudo apt-get update;
    sudo apt-get install nagios-plugins nagios-nrpe-server -y;
}

# configure NRPE
function configureNRPE(){
    sudo sed -i "/allowed_hosts=127.0.0.1/s/$/,${master_priv_ip}/" /etc/nagios/nrpe.cfg;
    old_load_setting='command\[check_load\]=\/usr\/lib\/nagios\/plugins\/check_load -w';
    # get number of CPUs
    num_cpu=$(grep -c "model name" /proc/cpuinfo);

    case $num_cpu in
        1 )
            sudo sed -i '/^command\[check_load\]/c\command[check_load]=/usr/lib/nagios/plugins/check_load -w 1.0,0.7,0.6 -c 1.2,1.0,0.8' /etc/nagios/nrpe.cfg;
        ;;
        2 )
            sudo sed -i '/^command\[check_load\]/c\command[check_load]=/usr/lib/nagios/plugins/check_load -w 2.0,1.4,1.2 -c 2.4,2.0,1.6' /etc/nagios/nrpe.cfg;
        ;;
        4 )
            sudo sed -i '/^command\[check_load\]/c\command[check_load]=/usr/lib/nagios/plugins/check_load -w 4.0,3.2,3.0 -c 4.6,4.0,3.4' /etc/nagios/nrpe.cfg;
        ;;
        8 )
            sudo sed -i '/^command\[check_load\]/c\command[check_load]=/usr/lib/nagios/plugins/check_load -w 8.0,5.6,4.8 -c 8.8,8.0,6.4' /etc/nagios/nrpe.cfg;
        ;;
        12 )
            sudo sed -i '/^command\[check_load\]/c\command[check_load]=/usr/lib/nagios/plugins/check_load -w 12.0,8.4,7.2 -c 14.4,12.0,9.6' /etc/nagios/nrpe.cfg;
        ;;
        16 )
            sudo sed -i '/^command\[check_load\]/c\command[check_load]=/usr/lib/nagios/plugins/check_load -w 16.0,11.2,9.6 -c 19.2,16.0,12.8' /etc/nagios/nrpe.cfg;
        ;;
        20 )
            sudo sed -i '/^command\[check_load\]/c\command[check_load]=/usr/lib/nagios/plugins/check_load -w 20.0,14.0,12 -c 24.0,20.0,16.0' /etc/nagios/nrpe.cfg;
        ;;
     esac
    #get private IP
    node_priv_ip=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address);

    #configure server address
    sudo sed -i "s/#server_address=127.0.0.1/server_address=${node_priv_ip}/1" /etc/nagios/nrpe.cfg;
    sudo sed -i "s&/dev/hda1&/dev/vda1&" /etc/nagios/nrpe.cfg;

    sudo service nagios-nrpe-server restart;
}

installNRPE;
configureNRPE;
