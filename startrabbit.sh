#!/usr/bin/env bash

#set -euo pipefail

deprecatedEnvVars=(
	RABBITMQ_DEFAULT_PASS_FILE
	RABBITMQ_DEFAULT_USER_FILE
	RABBITMQ_MANAGEMENT_SSL_CACERTFILE
	RABBITMQ_MANAGEMENT_SSL_CERTFILE
	RABBITMQ_MANAGEMENT_SSL_DEPTH
	RABBITMQ_MANAGEMENT_SSL_FAIL_IF_NO_PEER_CERT
	RABBITMQ_MANAGEMENT_SSL_KEYFILE
	RABBITMQ_MANAGEMENT_SSL_VERIFY
	RABBITMQ_SSL_CACERTFILE
	RABBITMQ_SSL_CERTFILE
	RABBITMQ_SSL_DEPTH
	RABBITMQ_SSL_FAIL_IF_NO_PEER_CERT
	RABBITMQ_SSL_KEYFILE
	RABBITMQ_SSL_VERIFY
	RABBITMQ_VM_MEMORY_HIGH_WATERMARK
)
hasOldEnv=
for old in "${deprecatedEnvVars[@]}"; do
	if [ -n "${!old:-}" ]; then
		echo >&2 "error: $old is set but deprecated"
		hasOldEnv=1
	fi
done
if [ -n "$hasOldEnv" ]; then
	echo >&2 'error: deprecated environment variables detected'
	echo >&2
	echo >&2 'Please use a configuration file instead; visit https://www.rabbitmq.com/configure.html to learn more'
	echo >&2
	exit 1
fi


HOSTNAME=`env hostname`
echo "HOSTNAME " $HOSTNAME
echo ""
echo ""
echo "Starting RabbitMQ Server For host: " $HOSTNAME
hostname -f
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
      tail -f /var/log/rabbitmq/rabbit\@$HOSTNAME*.log
    fi
fi
