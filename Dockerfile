FROM rabbitmq:management

LABEL MAINTAINER="JohnnyVicious"
LABEL image="rabbitmq:management"

#WORKDIR /rabbitmq/
#RUN apk add --no-cache procps # Refer https://github.com/docker-library/rabbitmq/issues/162

ADD rabbitmq.conf /etc/rabbitmq/
ADD erlang.cookie /var/lib/rabbitmq/.erlang.cookie

#Add startup script in /opt/rabbitmq
ADD startrabbit.sh /opt/rabbitmq/

#Provide necessary permissions to config files
RUN chmod u+rw /etc/rabbitmq/rabbitmq.conf \
&& chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie \
&& chmod 400 /var/lib/rabbitmq/.erlang.cookie \
&& mkdir -p /opt/rabbitmq \
&& chmod a+x /opt/rabbitmq/startrabbit.sh

RUN set eux; \
rabbitmq-plugins enable --offline rabbitmq_mqtt rabbitmq_stomp rabbitmq_federation rabbitmq_federation_management; \
&& apt-get update; \
&& apt-get install -y --no-install-recommends python3; \
&& rm -rf /var/lib/apt/lists/*; \
&& rabbitmqadmin --version

# 5672  - Used by AMQP 0-9-1 and 1.0 clients with and without TLS
# 15672 - HTTP API clients, Management UI & rabbitmqadmin
# 25672 - Used for inter-node & CLI tools communication (Erlang distribution server port), computed as AMQP default port (5672) + 20000
# 4369  - erlang port mapper daemon (epmd) a peer discovery service used by RabbitMQ nodes and CLI Tools
# 9100-04 - ?

EXPOSE 5672 \
15672 \
25672 \
4369 \
9100 \
9101 \
9102 \
9103 \
9104

CMD /opt/rabbitmq/startrabbit.sh
