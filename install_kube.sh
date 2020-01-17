#!/bin/bash

#$1: last result
#$2: awaited result
#$3: custom message
checkResult() {
    if [ $1 -ne $2 ]
    then
        msg=$3
        if [[ -z "$1" ]]; then
            msg="See output log"
        fi
        echo -e "Error occured: $msg."
        exit 1
    fi
}


#Remove any older installations of Docker that may be on your system
echo "[TASK 1] Remove any older installations of Docker that may be on your system"
read -p "Appuyer sur une touche pour continuer ..."
sudo apt-get autoremove -y --purge docker-engine docker docker.io docker-ce

checkResult $? 0 "Git error"

#Install packages to allow apt to use a repository over HTTPS
sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common

#RKE fournit un script d'installation de docker
date
echo echo "[TASK 2] installation de docker" ;
sleep 5
#https://rancher.com/docs/rke/latest/en/os/#opening-port-tcp-6443-using-iptables
#curl https://releases.rancher.com/install-docker/18.06.sh | sh
curl https://releases.rancher.com/install-docker/18.09.2.sh | sh

# Enable docker service
echo "[TASK 3] Enable and start docker service"
read -p "Appuyer sur une touche pour continuer ..."
systemctl enable docker >/dev/null 2>&1
systemctl start docker

 if [ $? -eq 0 ]
    then 
        sudo systemctl unmask docker.service
        sudo systemctl unmask docker.socket
        sudo systemctl start docker.service
    fi


sleep 5

#Création et ajout d'un user utilisés par RKE pour administrer les nœud du cluster
echo "Création et ajout d'un user utilisés par RKE pour administrer les nœud du cluster"
read -p "Appuyer sur une touche pour continuer ..."

useradd manager
usermod -aG docker manager
mkdir -p /home/manager/.ssh

#vérifier le manager est bien parti de group docker
getent group docker | grep manager | wc -l
checkResult $? 1 "Manager n'appartient pas au groupe root"

# Add apt repo file for Kubernetes
echo "[TASK 5] Add apt repo file for Kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update

#Add Xenial Kubernetes Repository on both the nodes
#sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

# Install Kubernetes
echo "[TASK 6] Install Kubernetes (kubeadm, kubelet and kubectl)"
apt install -y -q kubeadm kubelet kubectl kubernetes-cni >/dev/null 2>&1

# Start and Enable kubelet service
echo "[TASK 7] Enable and start kubelet service"
systemctl enable kubelet >/dev/null 2>&1
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/sysconfig/kubelet
systemctl start kubelet >/dev/null 2>&1
systemctl status kubelet
sleep 5

# Install additional required packages
echo "[TASK 8] Install additional packages"
apt install -y -q which net-tools sudo sshpass less >/dev/null 2>&1


#Unable to start Docker Service in Ubuntu 16.04
#https://stackoverflow.com/questions/37227349/unable-to-start-docker-service-in-ubuntu-16-04
#sudo systemctl unmask docker.service
#sudo systemctl unmask docker.socket
#sudo systemctl start docker.service
