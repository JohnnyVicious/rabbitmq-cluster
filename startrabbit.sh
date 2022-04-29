#!/bin/bash

# Bash script for booting Rabbits with defined configuration
# All the ports are exposed on host system
# . ~/.bashrc

HOSTNAME=`env hostname`
echo "HOSTNAME " $HOSTNAME
echo ""
echo ""
echo "Starting RabbitMQ Server For host: " $HOSTNAME
change_default_user() {
  # change default user only if ENV is provided
  if [ -z $RABBITMQ_DEFAULT_USER ] && [ -z $RABBITMQ_DEFAULT_PASS ]; then
      echo "Maintaining default 'guest' user"
  else
      echo "Removing 'guest' user and adding ${RABBITMQ_DEFAULT_USER}"
      rabbitmqctl delete_user guest
      rabbitmqctl add_user $RABBITMQ_DEFAULT_USER $RABBITMQ_DEFAULT_PASS
      rabbitmqctl set_user_tags $RABBITMQ_DEFAULT_USER administrator
      rabbitmqctl set_permissions -p / $RABBITMQ_DEFAULT_PASS ".*" ".*" ".*"
  fi
}

if [ -z "$CLUSTERED" ]; then
    # If not clustered then start it normally as standalone server
    rabbitmq-server &
    rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit\@$HOSTNAME.pid
    change_default_user
    tail -f /var/log/rabbitmq/rabbit\@$HOSTNAME*.log
else
    if [ -z "$CLUSTER_WITH" ]; then
        # If clustered, but cluster with is not specified then again start normally, could be the first server in the cluster
        rabbitmq-server &
        sleep 5
        rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit\@$HOSTNAME.pid
        tail -f /var/log/rabbitmq/rabbit\@$HOSTNAME*.log
    else
      rabbitmq-server -detached
      rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit\@$HOSTNAME.pid
      rabbitmqctl stop_app
      if [ -z "$RAM_NODE" ]; then
          rabbitmqctl join_cluster rabbit@$CLUSTER_WITH
      else
          rabbitmqctl join_cluster --ram rabbit@$CLUSTER_WITH
      fi
      rabbitmqctl start_app

      #tail to keep foreground process active ...
      tail -f /var/log/rabbitmq/*.log
    fi
fi
