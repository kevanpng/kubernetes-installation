#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

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

# TODO change to mutli node
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

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
kubectl create namespace monitoring
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
locust &
sleep 20
# 1 user, spawn_rate of 1 user per second, hit localhost/foo
curl 'http://0.0.0.0:8089/swarm' \
  -H 'Connection: keep-alive' \
  -H 'Accept: */*' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.55 Safari/537.36' \
  -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
  -H 'Origin: http://0.0.0.0:8089' \
  -H 'Referer: http://0.0.0.0:8089/' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  --data-raw 'user_count=1&spawn_rate=1&host=http%3A%2F%2Flocalhost%2Ffoo' \
  --compressed \
  --insecure


#Generate a CSV file of time-series data using PromQL to fetch the following metrics from Prometheus:
# https://www.robustperception.io/understanding-machine-cpu-usage
#Average requests per second
# rate(nginx_ingress_controller_requests[1m])
# let the swarm hit the server for awhile
sleep 10
end_time=$(date +%s)
# starts 5 mins ago, which is 5 * 60 = 300 in epoch seconds
start_time=$(($end_time-300))
python query_csv.py localhost 'rate(nginx_ingress_controller_requests{service="foo-service"}[1m])' "$start_time" "$end_time" query_reqs.csv

#Average memory usage per second
# rate(nginx_ingress_controller_nginx_process_resident_memory_bytes[1m])
python query_csv.py localhost 'rate(nginx_ingress_controller_nginx_process_resident_memory_bytes[1m])' "$start_time" "$end_time" query_mem.csv

#Average CPU usage per second
# gets cpu usage per second for that pod
# sum(rate(container_cpu_usage_seconds_total{pod="ingress-nginx-controller-b7b74c7b7-hj8p6"}[1m])) by (pod_name) * 100
python query_csv.py localhost "sum(rate(container_cpu_usage_seconds_total{pod=\"${ingress_nginx_controller_pod_name}\"}[1m])) by (pod_name) * 100" "$start_time" "$end_time" query_cpu.csv

echo "All done!"

#Put your script and any additional required resources in a GitHub public repository. Include documentation that tells us how to run your script
#(including instructions on pre-requisites). Send us the link to the repository.

