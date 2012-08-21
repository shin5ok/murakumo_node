#!/bin/sh

api_init="/etc/init.d/murakumo_node_api"
if ! test -e $api_init;
then
  echo "$api_init make"
  cd /etc/init.d/
  ln -s /home/smc/murakumo_node/bin/Murakumo_Node_api.init $api_init
  chmod +x $api_init
  /sbin/chkconfig $api_init on
fi

job_init="/etc/init.d/murakumo_node_job"
if ! test -e $job_init;
then
  echo "$job_init make"
  cd /etc/init.d/
  ln -s /home/smc/murakumo_node/bin/Murakumo_Node_job.init $job_init
  chmod +x $job_init
  /sbin/chkconfig $job_init on
fi

retry_init="/etc/init.d/murakumo_node_retry"
if ! test -e $retry_init;
then
  echo "$retry_init make"
  cd /etc/init.d/
  ln -s /home/smc/murakumo_node/bin/Murakumo_Node_retry.init $retry_init
  chmod +x $retry_init
  /sbin/chkconfig $retry_init on
fi

submit_init="/etc/init.d/murakumo_node_submit"
if ! test -e $submit_init;
then
  echo "$submit_init make"
  cd /etc/init.d/
  ln -s /home/smc/murakumo_node/bin/Murakumo_Node_submit.init $submit_init
  chmod +x $submit_init
  /sbin/chkconfig $submit_init on
fi

echo "#########################################"
$job_init stop
$job_init start

$retry_init stop
$retry_init start

$submit_init stop
$submit_init start

$api_init stop
$api_init start
echo "#########################################"


