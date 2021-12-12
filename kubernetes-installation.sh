#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

# MUST run script as root

# must have python3 and pip3

#Assignment - Platform Engineer
#Write an automated script that would run on a Linux server or VM to:
#Spin up a multi-node Kubernetes cluster using KinD or an alternative.
# TODO change to yum install kind
#brew install kind
# TODO must run in root
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/local/bin/kind

# TODO add docker cli here

## add kubectl here
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
yum install -y kubectl

# TODO change to multi node
kind_cluster_exist=$(kind get clusters)

if [[ $kind_cluster_exist != "kind" ]]
  then
    echo "kind Cluster not found, creating cluster"
    kind create cluster --config=kind-cluster.yaml
  else
    echo "kind Cluster found, skipping cluster creation"
fi


#Install and run the NGINX ingress controller.

# This is the default ingress inginx controller with enabled prometheus metrics
kubectl apply -f ingress-nginx.yaml
# cannot wait for a resource that does not exist
sleep 20
# this is a waiter for the nginx to be ready
kubectl wait \
--namespace ingress-nginx \
--for=condition=ready pod  \
--selector=app.kubernetes.io/component=controller  \
--timeout=90s

ingress_nginx_controller_pod_name=$(kubectl get pods --all-namespaces|grep ingress-nginx-controller|awk '{print $2}')
#Install and run Prometheus, and configure it to monitor the Ingress Controller pods and Ingress resources created by the controller.
monitoring_namespace_found=$(kubectl get namespaces | grep monitoring)
if [[ -z  $monitoring_namespace_found ]]
  then
    echo "monitoring namespace not found, creating namespace"
    kubectl create namespace monitoring
  else
    echo "monitoring namespace found, skipping namespace creation"
fi
kubectl apply -f clusterRole.yaml
kubectl apply -f config-map.yaml
kubectl apply  -f prometheus-deployment.yaml
kubectl wait --for=condition=available --timeout=600s deployment/prometheus-deployment -n monitoring


#kubectl get deployments --namespace=monitoring
# service for prometheus deployment
kubectl apply -f prometheus-service.yaml --namespace=monitoring
# ingress for prometheus service
kubectl apply -f prometheus-ingress.yaml


#Deploy an Ingress resource and two instances of a backend service using the “hashicorp/http-echo”. The Ingress should send requests
#with path “/foo” to one service; and path “/bar” to another. The services should respond with “foo” and “bar” respectively.
kubectl apply -f usage.yaml
# test if foo and bar applications are ok
sleep 20
foo_result=$(curl localhost/foo)
if [[ $foo_result == foo ]]
  then
    echo "Success"
  else
    echo "Failed"
    exit 1
fi

bar_result=$(curl localhost/bar)
if [[ $bar_result == bar ]]
  then
    echo "Success"
  else
    echo "Failed"
    exit 1
fi


# test if api server is ok



#Ensure the above configuration is healthy, using Kubernetes APIs.
# start proxy in background so that can interact with API using curl
kubectl proxy --port=8080 &
sleep 20
curl http://localhost:8080/livez?verbose
curl http://localhost:8080/readyz?verbose
curl http://localhost:8080/healthz?verbose

#Run a benchmarking tool of your choice against the Ingress.

pip3 install virtualenv
virtualenv -p python3 .venv
source .venv/bin/activate
#pip3 install locust
pip install -r requirements.txt

# start locust in the background. interact with its API
# 1 user, spawn rate of 1 user per second
locust --host=http://localhost --headless -u 1 -r 1 --run-time 10s
# 1 user, spawn_rate of 1 user per second, hit localhost/foo
#curl 'http://0.0.0.0:8089/swarm' \
#  -H 'Connection: keep-alive' \
#  -H 'Accept: */*' \
#  -H 'X-Requested-With: XMLHttpRequest' \
#  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.55 Safari/537.36' \
#  -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
#  -H 'Origin: http://0.0.0.0:8089' \
#  -H 'Referer: http://0.0.0.0:8089/' \
#  -H 'Accept-Language: en-US,en;q=0.9' \
#  --data-raw 'user_count=1&spawn_rate=1&host=http%3A%2F%2Flocalhost' \
#  --compressed \
#  --insecure


#Generate a CSV file of time-series data using PromQL to fetch the following metrics from Prometheus:
# https://www.robustperception.io/understanding-machine-cpu-usage
#Average requests per second
# rate(nginx_ingress_controller_requests[1m])
# let the swarm hit the server for awhile
#sleep 10
end_time=$(date +%s)
# starts 10s ago
start_time=$(($end_time-10))

python query_csv.py localhost 'rate(nginx_ingress_controller_requests{service="foo-service"}[10s])' "$start_time" "$end_time" query_reqs.csv

#Average memory usage per second
# rate(nginx_ingress_controller_nginx_process_resident_memory_bytes[1m])
python query_csv.py localhost 'rate(nginx_ingress_controller_nginx_process_resident_memory_bytes[10s])' "$start_time" "$end_time" query_mem.csv

#Average CPU usage per second
# gets cpu usage per second for that pod
# sum(rate(container_cpu_usage_seconds_total{pod="ingress-nginx-controller-b7b74c7b7-hj8p6"}[1m])) by (pod_name) * 100
python query_csv.py localhost "sum(rate(container_cpu_usage_seconds_total{pod=\"${ingress_nginx_controller_pod_name}\"}[1min])) by (pod_name) * 100" "$start_time" "$end_time" query_cpu.csv

echo "All done!"

#Put your script and any additional required resources in a GitHub public repository. Include documentation that tells us how to run your script
#(including instructions on pre-requisites). Send us the link to the repository.