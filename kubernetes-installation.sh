#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

#Spin up a multi-node Kubernetes cluster using KinD or an alternative.
#curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
#chmod +x ./kind
#mv ./kind /usr/local/bin/kind
#
#os_name=$(cat /etc/os-release  | grep "^NAME"  | awk --field-separator="=" {'print $2'})
## FOR EC2 instance only
#if [[ $os_name == '"Amazon Linux"' ]]
#  then
#    echo "Installing docker for EC2 instance"
#    amazon-linux-extras install -y docker
#  else
#    echo "Not in EC2 environment, installing docker according to official docs"
#    yum install -y yum-utils
#    yum-config-manager \
#        --add-repo \
#        https://download.docker.com/linux/centos/docker-ce.repo
#    yum install docker-ce docker-ce-cli containerd.io
#fi
#
#systemctl start docker
#systemctl enable docker
#
### add kubectl here
#cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
#[kubernetes]
#name=Kubernetes
#baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
#enabled=1
#gpgcheck=1
#repo_gpgcheck=1
#gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
#EOF
#yum install -y kubectl

kind_cluster_exist=$(kind get clusters)

if [[ $kind_cluster_exist != "kind" ]]
  then
    echo "kind Cluster not found, creating cluster"
    kind create cluster --config=kind-cluster.yaml
  else
    echo "kind Cluster found, skipping cluster creation"
fi

#Install and run the NGINX ingress controller.
# This is the default ingress nginx controller with enabled prometheus metrics
kubectl apply -f ingress-nginx.yaml
# sleep because kubectl cannot wait for a resource that does not exist
echo "sleeping for 20s..."
sleep 20
kubectl wait \
--namespace ingress-nginx \
--for=condition=ready pod  \
--selector=app.kubernetes.io/component=controller  \
--timeout=90s

ingress_nginx_controller_pod_name=$(kubectl get pods --all-namespaces|grep ingress-nginx-controller|awk '{print $2}')
#Install and run Prometheus, and configure it to monitor the Ingress Controller pods and Ingress resources created by the controller.
monitoring_namespace_found=$(kubectl get namespaces | grep monitoring || :;)
# if empty str
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

# service for prometheus deployment
kubectl apply -f prometheus-service.yaml --namespace=monitoring
# ingress for prometheus service
kubectl apply -f prometheus-ingress.yaml

#Deploy an Ingress resource and two instances of a backend service using the “hashicorp/http-echo”. The Ingress should send requests
#with path “/foo” to one service; and path “/bar” to another. The services should respond with “foo” and “bar” respectively.
kubectl apply -f usage.yaml
echo "sleeping for 20s..."
sleep 20

#Ensure the above configuration is healthy, using Kubernetes APIs.
# start proxy in background so that can interact with API using curl
kubectl proxy --port=8080 &
echo "sleeping for 20s..."
sleep 20

# check health of API server
curl http://localhost:8080/livez?verbose
curl http://localhost:8080/readyz?verbose
curl http://localhost:8080/healthz?verbose

# check pod health
echo "Checking application pod statuses"
app_statuses=$(curl http://localhost:8080/api/v1/namespaces/default/pods | jq '.items[] | select(.metadata.name | test("bar-app||foo-app")) | {"phase": .status["phase"]} | .phase | contains("Running")')
for i in "${app_statuses[@]}"
do
  if [[ $i ]];
  then
    echo "Pod status is 'Running'."
  else
    echo "Pod status is not 'Running'."
    exit 1
  fi
done
echo "All application pods are running and ready"

ingress_status=$(curl http://localhost:8080/api/v1/namespaces/ingress-nginx/pods | jq '.items[] | select(.metadata.name | contains("ingress-nginx-controller")) | {"phase": .status["phase"]} | .phase | contains("Running")')
if [[ $ingress_status ]];
  then
    echo "Ingress status is 'Running'"
  else
    echo "Ingress status is not 'Running'"
    exit 1
fi

# test if foo and bar applications are ok
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

#Run a benchmarking tool of your choice against the Ingress.

pip3 install virtualenv
virtualenv -p python3 .venv
source .venv/bin/activate
pip install -r requirements.txt

# 1 user, spawn rate of 1 user per second, uses locustfile.py that will hit localhost/foo
locust --host=http://localhost --headless -u 1 -r 1 --run-time 10s

end_time=$(date +%s)
# starts 10s ago
start_time=$(($end_time-10))

# Average requests per second
python query_csv.py localhost 'rate(nginx_ingress_controller_requests{service="foo-service"}[10s])' "$start_time" "$end_time" query_reqs.csv "Requests Per Second"

#Average memory usage per second
python query_csv.py localhost 'rate(nginx_ingress_controller_nginx_process_resident_memory_bytes[1m])' "$start_time" "$end_time" query_mem.csv "Memory Usage (Bytes)"

#Average CPU usage (in %) per second
python query_csv.py localhost "sum(rate(container_cpu_usage_seconds_total{pod=\"${ingress_nginx_controller_pod_name}\"}[1m])) by (pod_name) * 100" "$start_time" "$end_time" query_cpu.csv "CPU Usage (%)"

echo "All done!"