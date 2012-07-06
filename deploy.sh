#!/bin/sh

sudo rsync -axv --delete -H --exclude ".svn" --exclude "deploy.sh" /home/kawano/Murakumo_Node/ /home/smc/Murakumo_Node/
sudo chown -R root.root /home/smc/Murakumo_Node/

