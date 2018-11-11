#!/bin/bash
function waitForMaster(){
    while : ; do
        file=$(sed  '/=$/d' /master/setup.conf)
        var="$(echo "$file" | tr ' ' '\n' | grep -F -m 1 'CONTRACT_ADD=' $1)"; var="${var#*=}"
        address=$var

        if [ -z "$address" ]; then
            echo "Waiting for Node 1 to deploy NetworkManager contract..."
            sleep 5
        else
            echo "CONTRACT_ADD=$address" >> /home/setup.conf
            break
        fi
                
    done
}
function main(){
    
    nodeName=$(basename `pwd`)
         
    cd node
    ./start_$nodeName.sh

    file=$(sed  '/=$/d' /home/setup.conf)

    var="$(echo "$file" | tr ' ' '\n' | grep -F -m 1 'CONTRACT_ADD=' $1)"; var="${var#*=}"
    address=$var   

    if [ -z "$address" ] ; then
        waitForMaster
    fi

    cd /root/quorum-maker/
    ./start_nodemanager.sh 22000 22003
}
main
