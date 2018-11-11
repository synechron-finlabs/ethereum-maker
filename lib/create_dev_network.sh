#!/bin/bash

source em.variables
source lib/common.sh

DOCKER_NETWORK_IP=10.50.0.

function generateSetupConf(){
    echo 'NODENAME='node$1 > $projectName/node$1/setup.conf
    echo 'CURRENT_IP='${DOCKER_NETWORK_IP}$(($1+1)) >> $projectName/node$1/setup.conf
    echo 'THIS_NODEMANAGER_PORT=22004' >> $projectName/node$1/setup.conf
    echo 'RPC_PORT=22000' >> $projectName/node$1/setup.conf        
    echo 'ROLE=' >> $projectName/node$1/setup.conf
    echo 'CONTRACT_ADD=' >> $projectName/node$1/setup.conf
    echo 'REGISTERED=' >> $projectName/node$1/setup.conf
    echo 'MODE=ACTIVE' >> $projectName/node$1/setup.conf
    echo 'STATE=I' >> $projectName/node$1/setup.conf
}

#function to create start node script with --raft flag
function copyStartTemplate(){
    
    PATTERN="s|#network_Id_value#|${NET_ID}|g"
    cp lib/dev/start_ethereum_template.sh $projectName/node$1/node/start_node$1.sh
    sed -i $PATTERN $projectName/node$1/node/start_node$1.sh
    PATTERN="s/#mNode#/node$1/g"
    sed -i $PATTERN $projectName/node$1/node/start_node$1.sh
    PATTERN="s/#node_ip#/${DOCKER_NETWORK_IP}$(($1+1))/g"
    sed -i $PATTERN $projectName/node$1/node/start_node$1.sh
    
    chmod +x $projectName/node$1/node/start_node$1.sh

    cp lib/dev/start_template.sh $projectName/node$1/start.sh

    cp lib/common.sh $projectName/node$1/node/common.sh
}

#function to generate enode
function generateEnode(){
    bootnode -genkey nodekey
    nodekey=$(cat nodekey)
	bootnode -nodekey nodekey 2>enode.txt &
	pid=$!
	sleep 5
	kill -9 $pid
	wait $pid 2> /dev/null
	re="enode://(.*)@"
	enodestr=$(cat enode.txt)
    
    if [[ $enodestr =~ $re ]];
    	then
        enode=${BASH_REMATCH[1]};
        echo $enode > $projectName/node$1/enode.txt
        
        COMMA=","
        if [ $i -eq $nodeCount ]; then
            COMMA=""
        fi
        echo \"enode://$enode@${DOCKER_NETWORK_IP}$(($1+1)):22001\"$COMMA >> $projectName/static-nodes.json
        
    fi
    
    cp nodekey $projectName/node$1/node/qdata/geth/.
  
    rm enode.txt
    rm nodekey
}

#function to create node accout to prepare for Genesis creation
function createAccount(){
    mAccountAddress="$(geth --datadir datadir --password lib/dev/passwords.txt account new 2>> /dev/null)"
    re="\{([^}]+)\}"
    if [[ $mAccountAddress =~ $re ]];
    then
        mAccountAddress="0x"${BASH_REMATCH[1]};
        echo $mAccountAddress > $projectName/node$1/coinbase.txt
    fi

    cp datadir/keystore/* $projectName/node$1/node/qdata/keystore/node$1key

    COMMA=","
    if [ $i -eq $nodeCount ]; then
        COMMA=""
    fi

    echo "\"$mAccountAddress\": {\"balance\": \"1000000000000000000000000000\"}$COMMA">> $projectName/accountsBalances.txt
    
    rm -rf datadir
}

function addNodeToDC(){
    echo "  node"$1: >> $projectName/docker-compose.yml
    echo "    container_name: node"$1 >> $projectName/docker-compose.yml
    echo "    image: "$dockerImage >> $projectName/docker-compose.yml
    echo "    working_dir: /node"$1 >> $projectName/docker-compose.yml
    echo "    command: [\"bash\" , \"start.sh\"]" >> $projectName/docker-compose.yml
    echo "    volumes:" >> $projectName/docker-compose.yml
    echo "      - ./node$1:/node$1" >> $projectName/docker-compose.yml
    echo "      - ./node$1:/home" >> $projectName/docker-compose.yml
    echo "      - ./node1:/master" >> $projectName/docker-compose.yml
  
    if [ -f .em_export_ports ]; then
        i=$1

        if [ $i -lt 10 ]; then 
            i="0"$i
        fi
        echo "    ports:" >> $projectName/docker-compose.yml
        echo "      - \"2${i}00:22000\"" >> $projectName/docker-compose.yml
        echo "      - \"2${i}01:22001\"" >> $projectName/docker-compose.yml
        echo "      - \"2${i}02:22002\"" >> $projectName/docker-compose.yml
        echo "      - \"2${i}03:22003\"" >> $projectName/docker-compose.yml
        
    fi

    echo "    networks:" >> $projectName/docker-compose.yml
    echo "      vpcbr:" >> $projectName/docker-compose.yml
    echo "        ipv4_address: $DOCKER_NETWORK_IP$(($1+1))" >> $projectName/docker-compose.yml
    

}

function createNodeDirs(){
    i=1
    while : ; do
        mkdir -p $projectName/node$i/node/keys
        mkdir -p $projectName/node$i/node/qdata/{keystore,geth,gethLogs}
        
        copyStartTemplate $i
        generateEnode $i
        createAccount $i
        generateSetupConf $i
        addNodeToDC $i

        displayProgress $nodeCount $i

        if [ $i -eq $nodeCount ]; then
            break;
        fi
        let "i++"
    done
}

function copyStaticNodeJson(){
    i=1
    while : ; do
        cp $projectName/static-nodes.json $projectName/node$i/node/qdata
        
        if [ $i -eq $nodeCount ]; then
            break;
        fi
        let "i++"
    done
}

function generateGenesis(){

    touch $projectName/accountsBalances.txt

    PATTERN="s|#CHAIN_ID#|${NET_ID}|g"
    cat lib/dev/genesis_template.json >> $projectName/genesis.json
    sed -i $PATTERN $projectName/genesis.json

    DATA=`cat $projectName/accountsBalances.txt | tr -d '[:space:]' | tr -d '\n'`

    PATTERN="s/#AccountBalance#/$DATA/g"
    sed -i $PATTERN $projectName/genesis.json
}

function initNodes(){

    i=1
    while : ; do        
        cp $projectName/genesis.json $projectName/node$i/node
        pushd $projectName/node$i/node
        geth --datadir qdata init genesis.json 2>> /dev/null
        popd
        
        if [ $i -eq $nodeCount ]; then
            break;
        fi
        let "i++"
    done
}

function cleanup() {
    rm -rf $projectName
    mkdir $projectName
        
    NET_ID=$(awk -v min=10000 -v max=99999 -v freq=1 'BEGIN{srand(); for(i=0;i<freq;i++)print int(min+rand()*(max-min+1))}')
    
    PATTERN="s/#DOCKER_NETWORK_IP#/$DOCKER_NETWORK_IP/g"
    sed $PATTERN lib/dev/header.yml > $projectName/docker-compose.yml
}


function readParameters() {
    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
        key="$1"

        case $key in
            -p|--project)
            projectName="$2"
            shift # past argument
            shift # past value
            ;;
            -n|--nodecount)
            nodeCount="$2"
            shift # past argument
            shift # past value
            ;;
            -h|--help)
            help
            
            ;;
            *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
        esac
    done
    set -- "${POSITIONAL[@]}" # restore positional parameters

    if [[ -z "$projectName" && -z "$nodeCount" ]]; then
        return
    fi

    if [[ -z "$projectName" || -z "$nodeCount" ]]; then
        help
    fi

    NON_INTERACTIVE=true
}

function main(){    

    readParameters $@

    if [ -z "$NON_INTERACTIVE" ]; then
        getInputWithDefault 'Please enter a project name' "TestNetwork" projectName $RED
        getInputWithDefault 'Please enter number of nodes to be created' 3 nodeCount $GREEN
    fi
   
    echo -e $BLUE'Creating '$projectName' with '$nodeCount' nodes. Please wait... '$COLOR_END

    displayProgress $nodeCount 0

    cleanup

    echo [ > $projectName/static-nodes.json
    createNodeDirs
    echo ] >> $projectName/static-nodes.json

    copyStaticNodeJson
    generateGenesis

    initNodes

    echo -e $GREEN'Project '$projectName' created successfully. Please execute docker-compose up from '$projectName' directory'$COLOR_END
}
main $@
