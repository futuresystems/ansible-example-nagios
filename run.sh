#!/usr/bin/env bash

docker='sudo docker'

export PS4='$LINENO: '
set -xe

N=5
venvdir=venv

name=$(basename $PWD)

############################################################ build

echo -e 'y\n' | ssh-keygen -f key -t rsa -N ''
$docker build -t $name .


############################################################ run

inventory_group() {
    local group=$1
    shift
    local addresses="$@"

    echo "[$group]"
    for a in $addresses; do
        echo $a
    done
    echo

}

start() {
    local ident=$1
    local image=$2
    $docker run -d --name=$ident $image
}

get_ip() {
    local name=$1
    $docker inspect -f "{{ .NetworkSettings.IPAddress }}" $name
}

# controller
start ${name}-0 $name
server_ip=$(get_ip ${name}-0)
    

# clients
client_ips=""
for i in `seq 1 $N`; do
    start ${name}-${i} $name
    client_ips="$client_ips $(get_ip ${name}-${i})"
done

# inventory file
inventory_group server  ${server_ip}   > inventory.txt
inventory_group clients ${client_ips}  >>inventory.txt


############################################################ deploy

if [ ! -d $venvdir ]; then
    virtualenv $venvdir
    . $venvdir/bin/activate
    pip install -r requirements.txt
fi

if [ -z $VIRTUAL_ENV ]; then
    . $venvdir/bin/activate
fi

ansible-playbook playbook.yml
