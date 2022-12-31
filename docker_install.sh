#!/bin/bash

######
# install docker requirements
#######



if [[ $EUID -ne 0 ]]; then
  echo "run as root"
  exit 1
fi

echoerror() {
    printf "Echo 'error' ${RC} * ERROR${EC}: $@\n" 1>&2;
}

SYSTEM_KERNEL="$(uname -s)"

echo "$dkrNfo Checking distribution list and product version"

if [ "$oskern == "Linux" ]; then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    case "$lsb_dist" in
        ubuntu)
            if [ -x "$(command -v lsb_release)" ]; then
                dist_ver="$(lsb_release --codename | cut -f2)"
            fi
            if [ -z "$dist_ver" ] && [ -r /etc/lsb-release ]; then
                dist_ver="$(. /etc/lsb-release && echo "$flavor")"
            fi
            sed -i "s/\(^deb cdrom.*$\)/\#/g" /etc/apt/sources.list
        ;;
        debian|raspbian)
            dist_ver="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
            case "$dist_ver" in
                9) dist_ver="stretch";;
                8) dist_ver="jessie";;
                7) dist_ver="wheezy";;
            esac
            sed -i "s/\(^deb cdrom.*$\)/\#/g" /etc/apt/sources.list
        ;;
        centos)
            if [ -z "$dist_ver" ] && [ -r /etc/os-release ]; then
                dist_ver="$(. /etc/os-release && echo "$VERSION_ID")"
            fi
        ;;
        rhel|ol|sles)
            ee_notice "$lsb_dist"
            exit 1
            ;;
        *)
            if [ -x "$(command -v lsb_release)" ]; then
                dist_ver="$(lsb_release --release | cut -f2)"
            fi
            if [ -z "$dist_ver" ] && [ -r /etc/os-release ]; then
                dist_ver="$(. /etc/os-release && echo "$VERSION_ID")"
            fi
        ;;
    esac
    ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not verify distribution or version of the OS (Error Code: $ERROR)."
    fi

elif [ "$oskern == "Darwin" ]; then
    productid="$(sw_vers -productName)"
    productver="$(sw_vers -productVersion)"
    buildver="$(sw_vers -buildVersion)"
else
	echo error
fi
install_curl(){

    case "$lsb_dist" in
        ubuntu|debian|raspbian)
            apt-get install -y curl >> $logfile 2>&1
        ;;
        centos|rhel)
            yum install curl >> $logfile 2>&1
        ;;
        *)
            exit 1
        ;;
    esac
    ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install curl for $lsb_dist $dist_ver (Error Code: $ERROR)."
        exit 1
    fi
}

install_docker(){
    curl -fsSL get.docker.com -o get-docker.sh >> $logfile 2>&1
    chmod +x get-docker.sh >> $logfile 2>&1
    ./get-docker.sh >> $logfile 2>&1
    ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install docker via convenience script (Error Code: $ERROR)."
        if [ -x "$(command -v snap)" ]; then
            snapver=$(snap version | grep -w 'snap' | awk '{print $2}')
            echo "dkrNfo Snap v$snapver is available. Trying to install docker via snap.."
            snap install docker >> $logfile 2>&1
            ERROR=$?
            if [ $ERROR -ne 0 ]; then
                echoerror "Could not install docker via snap (Error Code: $ERROR)."
                exit 1
            fi
        else
          echo'error'
            exit 1
        fi
    fi
}
install_docker_compose(){

    curl -L https://github.com/docker/compose/releases/download/1.23.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose >> $logfile 2>&1
    chmod +x /usr/local/bin/docker-compose >> $logfile 2>&1
    ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install docker-compose (Error Code: $ERROR)."
        exit 1
    fi
}
if [ "$oskern == "Linux" ]; then
    if [ -x "$(command -v curl)" ]; then

    else
        install_curl
    fi
    if [ -x "$(command -v docker)" ]; then

    else
        install_docker
    fi

    if [ -x "$(command -v docker-compose)" ]; then

    else
        install_docker_compose
    fi
else
    if [ -x "$(command -v docker)" ] && [ -x "$(command -v docker-compose)" ]; then

    else

        exit 1
    fi
