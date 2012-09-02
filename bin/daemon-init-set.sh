#!/bin/sh

api_init="/etc/init.d/murakumo_node_api"
if ! test -e $api_init;
then
  echo "$api_init make"
  cd /etc/init.d/
  ln -s /home/smc/murakumo_node/bin/Murakumo_Node_api.init $api_init
  chmod +x $api_init
fi
api_init_filename=`basename $api_init`
/sbin/chkconfig $api_init_filename on

job_init="/etc/init.d/murakumo_node_job"
if ! test -e $job_init;
then
  echo "$job_init make"
  cd /etc/init.d/
  ln -s /home/smc/murakumo_node/bin/Murakumo_Node_job.init $job_init
  chmod +x $job_init
fi
job_init_filename=`basename $job_init`
/sbin/chkconfig $job_init_filename on

submit_init="/etc/init.d/murakumo_node_submit"
if ! test -e $submit_init;
then
  echo "$submit_init make"
  cd /etc/init.d/
  ln -s /home/smc/murakumo_node/bin/Murakumo_Node_submit.init $submit_init
  chmod +x $submit_init
fi
submit_init_filename=`basename $submit_init`
/sbin/chkconfig $submit_init_filename on

echo "#########################################"
$job_init stop
$job_init start

$submit_init stop
$submit_init start

$api_init stop
$api_init start
echo "#########################################"

