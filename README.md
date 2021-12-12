#Put your script and any additional required resources in a GitHub public repository. Include documentation that tells us how to run your script
#(including instructions on pre-requisites). Send us the link to the repository.

# Description
Automatically installs a local kubernetes cluster, some services, ingress and prometheus


# Requirements
- Must be run in a Centos Linux environment. Supports running in EC2 instances, see below for more details
- Assumes VM has internet connection to install packages from public internet
- Assumes the following packages are already installed:
  - python3.6 (or above)
  - pip3
  - curl
  - git
- `kubernetes-installation.sh` must be run as root user
> Tested on Linux EC2 Amazon Linux 2 AMI (HVM) - Kernel 5.10, SSD Volume Type
> t2.medium instance, 2 vCPUs, 4GB memory

# How To Run
Switch user to the root

`sudo su -`

Clone this to the Linux environment

`git clone https://github.com/kevanpng/kubernetes-installation.git`

cd into the directory

`cd kubernetes-installation`

Add execute permissions to the script

`chmod +x kubernetes-installation.sh`

Run the script

`./kubernetes-installation.sh`

The script will:
- Install other packages needed
- Provision the multi-node cluster, with 1 control and 2 worker nodes
- Setup Nginx Ingress controller
- Setup Prometheus to monitor the cluster
- Provision backend services
- Check health of the cluster through kubernetes API server livez, healthz and readyz API
- Check ingress routing and asserts the responses
- Installs python dependencies, including Locust, the load testing tool
- Runs Locust and load tests the ingress controller
- Use a python script to query the prometheus server using PromQL and outputs a CSV for memory, CPI usage and requests per second.

After the script is run, look at `query_cpu.csv`, `query_mem.csv`, and `query_reqs.csv` for the PromQL query results.
# Possible improvements
- use Helm