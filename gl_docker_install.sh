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
        export IPADDR=$IPADDR1
    elif  [[ $IPADDR =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "\n\r IP Address is: $IPADDR"
        export $IPADDR
    else
        echo -e "\n\r Invalid IP Address"
        sleep 2
        set_git_IP
    fi
}

function create_docker_home() {
    echo -e "\r\n select gitlab home directory (default: /opt/gitlab/)"
    read -p "Gitlab home directory: " GITLAB_HOME
    if [[ $GITLAB_HOME ]] ; then
        echo -e "\r\n Using $GITLAB_HOME"
        rm -rf $GITLAB_HOME/* || true #clear out the directory
        for i in config logs data; do
            mkdir -p $GITLAB_HOME/$i
        done     
    elif [[ -z $GITLAB_HOME ]] ; then 
        echo -e "\r\n Using default: /opt/gitlab/"
        GITLAB_HOME=/opt/gitlab/
        rm -rf $GITLAB_HOME/* || true #clear out the directory
        for i in config logs data; do
            mkdir -p $GITLAB_HOME/$i
        done
    elif [[ ! -d $GITLAB_HOME ]] ; then
        echo -e "\r\n Directory does not exist, creating..."
        mkdir -p $GITLAB_HOME
        for i in config logs data; do
            mkdir -p $GITLAB_HOME/$i
        done
            GITLAB_HOME=/opt/gitlab/
    else
        create_docker_home
    fi
export GITLAB_HOME=$GITLAB_HOME
}

function custom_ports_hostname() {
    echo -e "\r\n Ports and hostname values are 
    \r\n Ports: 8443 is for HTTPS, 8880 is for HTTP, 8822 is for SSH
    \r\n Hostname: gitlab.local \r\n"
    # ask if they want to use default ports and hostname
    read -p "Do you want to use the default ports and hostname? [y/n]" REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\r\n Using default ports and hostname"
        export HTTP_PORT=8880
        export HTTPS_PORT=8443
        export SSH_PORT=8822
        export GITHOSTNAME=gitlab.local
    else
        echo -e "\r\n Select custom ports for Gitlab (default: 8443, 8880, 8822)"
        read -p "HTTP port: " HTTP_PORT
        if [[ -z $HTTP_PORT ]] ; then
            echo -e "\r\n Using default: 8880"
            export HTTP_PORT=8880
        fi
        read -p "HTTPS port: " HTTPS_PORT
        if [[ -z $HTTPS_PORT ]] ; then
            echo -e "\r\n Using default: 8443"
            export HTTPS_PORT=8443
        fi
        read -p "SSH port: " SSH_PORT
        if [[ -z $SSH_PORT ]] ; then
            echo -e "\r\n Using default: 8822"
            export SSH_PORT=8822
        fi
        read -p  "\r\n Enter host name Gitlab (default: gitlab.local)" GITHOSTNAME
        if [[ -z $GITHOSTNAME ]] ; then
            echo -e "\r\n Using default: gitlab.local"
            export GITHOSTNAME=gitlab.local
        fi
    fi

}

function export_githome_vars() {
    export GITLAB_HOME=$GITLAB_HOME
    export GITLAB_CONFIG=$GITLAB_HOME/config
    export GITLAB_LOGS=$GITLAB_HOME/logs
    export GITLAB_DATA=$GITLAB_HOME/data

}


function set_rails_env() {
    echo 'waiting for gitlab to start...'
    
    while [[ -z $GITPASSWORD || -z `echo $GITPASSWORD | grep -v 'No' ` ]] ; do
        GITPASSWORD=`sudo docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password`
        echo -e "\r\n Gitlab password is not set...waiting..."
        sleep 2
        clear
    done

    echo $GITPASSWORD > /tmp/gitpassword.txt
    echo -e "\r\n Gitlab password is: $GITPASSWORD \r\n"
    read -p "Press any key to continue after you have copied the password..." -n1 -s

    export GITLAB_ROOT_PASSWORD=`cat /tmp/gitpassword.txt | awk '{print $2}'`
}


function cleanup() {

    echo -e "Cleaning up and removing variable exports"
    unset GITLAB_DATA && echo 'Variable GITLAB_DATA is unset.'
    unset GITPASSWORD && echo 'Variable GITPASSWORD is unset.'
    unset GITLAB_ROOT_PASSWORD && echo 'Variable GITLAB_ROOT_PASSWORD is unset.'
    unset GITLAB_HOME && echo 'Variable GITLAB_HOME is unset.'
    unset GITLAB_CONFIG && echo 'Variable GITLAB_CONFIG is unset.'
    unset GITLAB_LOGS && echo 'Variable GITLAB_LOGS is unset.'
    unset IPADDR && echo 'Variable IPADDR is unset.'
    unset HTTP_PORT && echo 'Variable HTTP_PORT is unset.'
    unset HTTPS_PORT && echo 'Variable HTTPS_PORT is unset.'
    unset SSH_PORT && echo 'Variable SSH_PORT is unset.'
    unset GITHOSTNAME && echo 'Variable GITHOSTNAME is unset.'

    echo -e "\r\n removing /tmp/gitlab.sh"
    sudo rm -rf /tmp/gitlab.sh || true
    echo -e "\r\n removing /tmp/gitpassword.txt"
    sudo rm -rf /tmp/gitpassword.txt || true
    echo -e "\r\n removing /tmp/gitlab.rb"
    sudo rm -rf /tmp/gitlab.rb || true
}



function post_install(){

    echo -e "\r\n After you have changed your password, we can finish.  
    \r\n Please login to Gitlab and change your password, then press any key to continue"
    read -p "Press any key to continue... " -n1 -s
    read -p "Are you ready to finish the setup? [y/n]" REPLY
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\r\n Finishing Gitlab setup"
        echo -e "\r\n Please wait, this may take a few minutes"
        echo "Creating gitlab.rb file"
        echo '#!/bin/bash' | tee  /tmp/gitlab.sh
        echo "gitlab-ctl reconfigure && sleep 30s" | tee -a /tmp/gitlab.sh
        echo "gitlab-ctl restart" | tee -a /tmp/gitlab.sh

        chmod +x /tmp/gitlab.sh
        sudo docker cp /tmp/gitlab.sh gitlab:/tmp/gitlab.sh

        echo 'Last warning, running cleanup, press any key to continue...'
        read -p "Press any key to continue... " -n1 -s
    
        sudo docker exec -it gitlab /tmp/gitlab.sh
        sleep 1s
        sudo docker exec -it gitlab gitlab-ctl status
        cleanup
    fi 
}



function main() {

check_docker 
check_gitlab 
set_git_IP 
create_docker_home
custom_ports_hostname
export_githome_vars

# Run Gitlab container
echo -e "\r\n Creating Gitlab container..."

sudo docker run --detach \
    --hostname $GITHOSTNAME \
    --publish $HTTPS_PORT:443 \
    --publish $HTTP_PORT:80 \
    --publish $SSH_PORT:22 \
    --name gitlab \
    --restart always \
    --volume $GITLAB_CONFIG:/etc/gitlab \
    --volume $GITLAB_LOGS:/var/log/gitlab \
    --volume $GITLAB_DATA:/var/opt/gitlab \
    gitlab/gitlab-ce:latest

echo -e "\r\n Gitlab container created."


set_rails_env
for i in  {1..60}; do
    docker logs gitlab
    sleep 2
done

echo -e "\n\r Notes:"
echo -e "\n\r Gitlab is now running. Please visit https://$IPADDR:$HTTP_PORT or to finish setup, setup may still take a bit to finish."
echo -e "\n\r Please use the following \n\r username: root \n\r Password: `cat /tmp/gitpassword.txt && rm /tmp/gitpassword.txt` to login."
echo -e "\r\n Please change the password after login."

post_install

}


main


