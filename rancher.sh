#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

script_name='install-docker-19.03.sh'
curl -fsSL https://releases.rancher.com/install-docker/19.03.sh -o "$script_name"
chmod +x "$script_name"
sh "$script_name"
apt-mark hold docker-ce docker-ce-cli

usermod -aG docker $(logname)

docker run -d --restart=unless-stopped \
  -p 8080:80 -p 8443:443 \
  --privileged \
  rancher/rancher:latest