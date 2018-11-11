#!/bin/bash
set -u
set -e

NETID=#network_Id_value#
R_PORT=22000
W_PORT=22001
WS_PORT=22002
NODE_MANAGER_PORT=22003

CURRENT_NODE_IP=#node_ip#

GLOBAL_ARGS="--nodiscover --networkid $NETID --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3"

echo "[*] Starting #mNode# node" >> qdata/gethLogs/#mNode#.log
echo "[*] geth --mine --minerthreads 1 --verbosity 6 --datadir qdata" $GLOBAL_ARGS" --rpcport "$R_PORT "--port "$W_PORT "--nat extip:"$CURRENT_NODE_IP>> qdata/gethLogs/#mNode#.log

PRIVATE_CONFIG=qdata/#mNode#.ipc geth --mine --minerthreads 1 --verbosity 6 --datadir qdata $GLOBAL_ARGS --rpccorsdomain "*" --rpcport $R_PORT --port $W_PORT --ws --wsaddr 0.0.0.0 --wsport $WS_PORT --wsorigins '*' --wsapi --nat --nat extip:$CURRENT_NODE_IP 2>>qdata/gethLogs/#mNode#.log &

