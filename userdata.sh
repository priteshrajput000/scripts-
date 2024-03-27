#!/bin/bash
sudo -u ubuntu bash << 'EOS'
whoami
rm -rf /home/ubuntu/bloodhound-server
rsync -av -e "ssh -o StrictHostKeyChecking=no" ubuntu@********:/home/ubuntu/bloodhound-server /home/ubuntu/
sudo -u ubuntu -i
whoami
. ~/.nvm/nvm.sh && . ~/.profile && . ~/.bashrc 
cd /home/ubuntu/bloodhound-server/
npm i
pm2 -v
sleep 10s
NODE_ENV=staging pm2 start server.js -i max
EOS
whoami
