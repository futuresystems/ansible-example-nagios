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

cleanup() {
    local docker_names="$@"
    for n in $docker_names; do
        $docker kill $n
        $docker rm $n
    done
}

running_names=""

# controller
run_name=${name}-0
start $run_name $name
server_ip=$(get_ip ${name}-0)
docker_names="$run_name $docker_names"

# clients
client_ips=""
for i in `seq 1 $N`; do
    run_name=${name}-${i}
    start ${run_name} $name
    client_ips="$client_ips $(get_ip ${name}-${i})"
    docker_names="$run_name $docker_names"
done

# inventory file
inventory_group server  ${server_ip}   > inventory.txt
inventory_group clients ${client_ips}  >>inventory.txt

# cleanup
trap "cleanup $docker_names" SIGINT SIGTERM SIGKILL

############################################################ deploy

if [ ! -d $venvdir ]; then
    virtualenv $venvdir
    . $venvdir/bin/activate
    pip install -r requirements.txt
fi

if [ -z $VIRTUAL_ENV ]; then
    . $venvdir/bin/activate
fi

# wait for containers to be running and responsive
sleep 5s
ansible-playbook playbook.yml
