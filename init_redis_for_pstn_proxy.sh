# Configurar servidores dispatcher en Redis (grupo 1 para Asterisk)
redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB HSET "dispatcher:1:sip:$ASTERISK1_IP:5060" flags 0 priority 1 attrs "weight=10" description "Asterisk Server 1"
redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB HSET "dispatcher:1:sip:$ASTERISK2_IP:5060" flags 0 priority 2 attrs "weight=10" description "Asterisk Server 2"
redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB HSET "dispatcher:1:sip:$ASTERISK3_IP:5060" flags 0 priority 3 attrs "weight=10" description "Asterisk Server 3"

# Configurar direcciones permitidas (grupo 1 para Asterisk)
redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB HSET "address:1:$ASTERISK1_IP:32:0" tag "asterisk1"
redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB HSET "address:1:$ASTERISK2_IP:32:0" tag "asterisk2"
redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB HSET "address:1:$ASTERISK3_IP:32:0" tag "asterisk3"