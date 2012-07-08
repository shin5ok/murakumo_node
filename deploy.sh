#!/bin/sh

sudo rsync -axv --delete -H --exclude ".svn" --exclude ".git" --exclude "deploy.sh" /home/kawano/murakumo_node/ /home/smc/murakumo_node/
sudo chown -R root.root /home/smc/murakumo_node/

