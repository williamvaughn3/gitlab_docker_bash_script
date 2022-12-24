#!/bin/bash


echo -e "\n\r #####################################################"
echo "## Quick and Dirty Bash Script for Gitlab install  ##"
echo "## Using Docker and GitLab with Omnibus packages   ##"
echo "##                                                 ##"
echo "##        Did this for a specific purpose          ##"
echo "##                                                 ##"
echo "##   However....                                   ##"
echo "##   For other quick options see:                  ##"
echo "##                                                 ##"
echo "## HashiCorp vagrant vault, as well as tf / packer ##"
echo "## or some of Jeff Geerings Work for awesome       ##"
echo "## Ansible Resources                               ##"
echo -e "#####################################################\n\r"


if [ `sudo id -u` -ne 0 ]; then echo -e "\r\n Must run as root" && exit 1; fi

function check_args() {
    if [ $# -ne 1 ]; then
        echo -e "\r\n Usage: $0 <temp password>"
        exit 1
    else 
        export GITPASSWORD=$1
    fi
    
} 

function check_docker() {
    if  [[ `which docker` == null ]] ; then
        echo -e "\r\n Docker is not installed..."
        echo -e "\r\n Do you want to install it? [y/n]"
        read -p "Are you sure? [y/n] " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            curl -s https://raw.githubusercontent.com/williamvaughn3/gitlab_docker_bash_script/main/docker_depenencies.sh | bash -s 
        else
            echo -e "\r\n exiting..."
            exit 1
        fi
    fi
}

function check_gitlab() {
    if [[ $(docker ps -a | grep gitlab) ]]; then
        echo -e "\r\n Gitlab is running. Deleting container and starting new one."
        read -p "Are you sure? [y/n] " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\r\n    Deleting container..."
            sudo docker ps -a | grep gitlab | awk '{print $1}' | xargs sudo docker rm -f
        echo -e "\r\n  container deleted."
        else
            echo -e "\r\n exiting..."
            exit 1
        fi
    fi
} 

function set_git_IP() {
    echo -e "\n\r Enumerating IP addresses on this machine and ommiting tun, lo, br, doc, vir, veth interfaces."
    echo -e "\n\r Please select the IP address you want to use for Gitlab:"
    INT=`ip link | awk -F: '$0 !~ "tun|lo|br|doc|vir|veth|vm"{print $2a;getline}' `
    x=0
    echo '' > /tmp/ipaddr.txt #should be cleared up later but just in case
    for i in $INT; do
        x=$(($x+1))
        IPADDR=`ip -o -4 addr show $i | awk '{print $4}' | cut -d '/' -f 1 `
        if [[ $x == 1 ]] ; then
            IPADDR1=$IPADDR
        fi
        if [[ $IPADDR != 0 ]]; then
            echo -e "\n\r $x) $IPADDR" >> /tmp/ipaddr.txt
        fi
    done 
    echo -e "\n\r\n\r" >> /tmp/ipaddr.txt
    cat /tmp/ipaddr.txt
    read -p "IP Address: (default $IPADDR1)" IPADDR
    if [[ -z $IPADDR ]] ; then
        IPADDR=$IPADDR1
    # check if IPADDR is in /tmp/ipaddr.txt
    elif [[ `grep $IPADDR /tmp/ipaddr.txt` ]] ; then
        echo -e "\n\r IP Address is: $IPADDR"
    else
        echo -e "\n\r Invalid IP Address"
        set_git_IP
    fi
}

function create_docker_home() {
    echo -e "\r\n select gitlab home directory (default: /opt/gitlab/)"
    read -p "Gitlab home directory: " GITLAB_HOME
    if [[ -z $GITLAB_HOME ]] ; then
        echo -e "\r\n Using default: /opt/gitlab/"
        GITLAB_HOME=/opt/gitlab/{config,logs,data}
        elif [[ ! -d $GITLAB_HOME ]] ; then
            echo -e "\r\n Directory does not exist, creating..."
            mkdir -p $GITLAB_HOME/{config,logs,data}
            GITLAB_HOME=/opt/gitlab/
        else
            create_docker_home
    fi
        export GITLAB_HOME=$GITLAB_HOME

}

function export_githome_vars() {
    export GITLAB_CONFIG=$GITLAB_HOME/config
    export GITLAB_LOGS=$GITLAB_HOME/logs
    export GITLAB_DATA=$GITLAB_HOME/data
    export GITLAB_ROOT_PASSWORD= $GITPASSWORD # set this to your root password
}


function build_container() {

sudo docker run --detach \
    --hostname gitlab.example.com \
    --publish $IPADDR:8443:443 \
    --publish $IPADDR:8880:80 \
    --publish $IPADDR:8822:22 \
    --name gitlab \
    --restart always \
    --volume $GITLAB_HOME/config:/etc/gitlab \
    --volume $GITLAB_HOME/logs:/var/log/gitlab \
    --volume $GITLAB_HOME/data:/var/opt/gitlab \
    --shm-size 256m \
    gitlab/gitlab-ee:latest

sudo docker exec -it gitlab gitlab-ctl reconfigure
}

function_cleanup() {
    clear    # setting home to /opt/gitlab

    echo -e "\r\n Notes:"
    echo -e "\r\n Gitlab is now running. Please visit https://$IPADDR:8443 to finish setup, setup may still take a bit to finish."
    echo -e "\r\n\r Please use the following username: root, password: $GITLAB_ROOT_PASSWORD to login."
    echo -e "\r\n Please change the password after login."

    unset GITLAB_DATA && echo 'Variable GITLAB_DATA is unset.'
    unset GITPASSWORD && echo 'Variable GITPASSWORD is unset.'
    unset GITLAB_ROOT_PASSWORD && echo 'Variable GITLAB_ROOT_PASSWORD is unset.'

    
}


function main() {
    check_args $1 
    check_docker 
    check_gitlab 
    set_git_IP 
    create_docker_home
    export_githome_vars $1 
    build_container
    function_cleanup 
}


main $1

