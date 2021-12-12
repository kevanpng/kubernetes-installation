#!/bin/bash

#Assignment - Platform Engineer
#Write an automated script that would run on a Linux server or VM to:
#Spin up a multi-node Kubernetes cluster using KinD or an alternative.
brew install kind
cat <<EOF | kind create cluster --config=-kind: Clusterapi
Version: kind.x-k8s.io/v1alpha4nodes:
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

# this is a waiter for the inginx to be ready
kubectl wait --namespace ingress-nginx \\n  --for=condition=ready pod \\n  --selector=app.kubernetes.io/component=controller \\n  --timeout=90s


#Install and run Prometheus, and configure it to monitor the Ingress Controller pods and Ingress resources created by the controller.
kubectl create namespace monitoring
kubectl create -f clusterRole.yaml
kubectl create -f config-map.yaml
kubectl create  -f prometheus-deployment.yaml
kubectl get deployments --namespace=monitoring
# service for prometheus deployment
kubectl apply -f prometheus-service.yaml --namespace=monitoring
# ingress for prometheus service
kubectl apply -f prometheus-ingress.yaml


#Deploy an Ingress resource and two instances of a backend service using the “hashicorp/http-echo”. The Ingress should send requests
#with path “/foo” to one service; and path “/bar” to another. The services should respond with “foo” and “bar” respectively.
kubectl apply -f usage.yaml
# test if foo and bar applications are ok
curl localhost/foo
curl localhost/bar

# test if api server is ok
#curl -k https://localhost:6443/livez\?verbose

# proxy
kubectl proxy --port=8080
curl http://localhost:8080/livez?verbose
curl http://localhost:8080/readyz?verbose
curl http://localhost:8080/healthz?verbose

#Ensure the above configuration is healthy, using Kubernetes APIs.
#Run a benchmarking tool of your choice against the Ingress.

sudo pip3 install virtualenv
virtualenv -p python3 .venv
source .venv/bin/activate
pip3 install locust

locust
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

# navigate to endpoint,
#Generate a CSV file of time-series data using PromQL to fetch the following metrics from Prometheus:
# https://www.robustperception.io/understanding-machine-cpu-usage
#Average requests per second
# rate(nginx_ingress_controller_requests[1m])
python query_csv.py localhost 'rate(nginx_ingress_controller_requests{service="foo-service"}[1m])' 1639233546 1639233846 query_reqs.csv

#Average memory usage per second
# rate(nginx_ingress_controller_nginx_process_resident_memory_bytes[1m])
python query_csv.py localhost 'rate(nginx_ingress_controller_nginx_process_resident_memory_bytes[1m])' 1639233546 1639233846 query_mem.csv

#Average CPU usage per second
# gets cpu usage per second for that pod
# sum(rate(container_cpu_usage_seconds_total{pod="ingress-nginx-controller-b7b74c7b7-hj8p6"}[1m])) by (pod_name) * 100
python query_csv.py localhost 'sum(rate(container_cpu_usage_seconds_total{pod="ingress-nginx-controller-b7b74c7b7-hj8p6"}[1m])) by (pod_name) * 100' 1639233546 1639233846 query_cpu.csv


#Put your script and any additional required resources in a GitHub public repository. Include documentation that tells us how to run your script
#(including instructions on pre-requisites). Send us the link to the repository.

