#!/bin/sh

sudo rsync -axv --delete -H --exclude ".svn" --exclude ".git" --exclude "*.swp" --exclude "deploy.sh" --exclude "job.db" --delete $HOME/murakumo_node/ /home/smc/murakumo_node/
sudo chown -R root.root /home/smc/murakumo_node/

