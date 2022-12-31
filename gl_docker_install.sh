#!/bin/bash

echo "#####################################################"
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
echo "#####################################################"



if [ `sudo id -u` -ne 0 ]; then echo "Must run as root" && exit 1; fi

function check_args() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <temp password>"
        exit 1
    fi
} 

function check_docker() {
    if  [[ `which docker` == null ]] ; then
        echo "Docker is not installed..."
        echo "Do you want to install it? [y/n]"
        read -p "Are you sure? [y/n] " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          
          
        else
            echo "exiting..."
            exit 1
        fi
    fi
}

function check_gitlab() {
    if [[ $(docker ps -a | grep gitlab) ]]; then
        echo "Gitlab is running. Deleting container and starting new one."
        read -p "Are you sure? [y/n] " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo docker ps -a | grep gitlab | awk '{print $1}' | xargs sudo docker rm -f
        else
            echo "exiting..."
            exit 1
        fi
    fi
} 

function set_git_IP() {
    echo "Enumerating IP addresses on this machine and ommiting tun, lo, br, doc, vir, veth interfaces."
    echo "Please select the IP address you want to use for Gitlab:"
    INT=`ip link | awk -F: '$0 !~ "tun|lo|br|doc|vir|veth|vm"{print $2a;getline}' `
    x=0
    echo '' > /tmp/ipaddr.txt #should be cleared up later but just in case
    for i in $INT; do
        x=$((x+1))
        ip -o -4 addr show $i | awk '{print $4}' | cut -d '/' -f 1 >> /tmp/ipaddr.txt
    done 
    echo -e "\n\r\n\r\n\r" >> /tmp/ipaddr.txt
    cat /tmp/ipaddr.txt
    read -p "IP Address: " IPADDR
    if ! grep -q $IPADDR /tmp/ipaddr.txt; then
        echo "IP Address not not correct."
        exit 1
    fi
    echo "IP Address is: $IPADDR"
    unset $x
    unset $INT
    echo /tmp/ipaddr.txt
}

function create_docker_home() {
    # setting home to /opt/gitlab
    $GITLAB_HOME=/gitlab/
    echo "select gitlab home directory (default: /opt/gitlab/)"
    read -p "Gitlab home directory: " GITLAB_HOME
    if [ -z $GITLAB_HOME ]; then
        echo "directory does not exist. Do you want to use /opt/gitlab/ ? [y/n]"
        read -p "Selection: " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "using /opt/gitlab/"
            GITLAB_HOME=/gitlab/
        else
            create_docker_home || exit 1
        fi
    
    else
        echo "Selection is: $GITLAB_HOME"
        echo "is this correct? [y/n]"
        read -p "Selection: " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "using $GITLAB_HOME"
        else
            create_docker_home || exit 1
        fi
    fi
        export GITLAB_HOME=$GITLAB_HOME

}

function export_githome_vars() {
    # export docker git home variables
    export GITLAB_CONFIG=$GITLAB_HOME/config
    export GITLAB_LOGS=$GITLAB_HOME/logs
    export GITLAB_DATA=$GITLAB_HOME/data
    export GITPASSWORD= $1
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

echo "Gitlab is now running. Please visit https://$IPADDR:8443 to finish setup."
echo "Please use the following root and the password: $GITPASSWORD to login."
echo "Please change the password after login."

# reconfigure gitlab
sudo docker exec -it gitlab gitlab-ctl reconfigure
# delete last command in history
}

function_cleanup() {
    rm /tmp/ipaddr.txt
    #unset variables
    unset GITLAB_HOME  && echo 'Variable GITLAB_HOME is unset.'
    unset GITLAB_CONFIG && echo 'Variable GITLAB_CONFIGis unset.'
    unset GITLAB_LOGS && echo 'Variable GITLAB_LOGSis unset.'
    unset GITLAB_DATA && echo 'Variable GITLAB_DATAis unset.'
    unset GITPASSWORD && echo 'Variable GITPASSWORDis unset.'
    unset GITLAB_ROOT_PASSWORD && echo 'Variable GITLAB_ROOT_PASSWORDis unset.'
}

# if  null then exit


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
