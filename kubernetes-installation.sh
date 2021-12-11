#!/bin/bash

#Assignment - Platform Engineer
#Write an automated script that would run on a Linux server or VM to:
#Spin up a multi-node Kubernetes cluster using KinD or an alternative.
#Install and run the NGINX ingress controller.
#Install and run Prometheus, and configure it to monitor the Ingress Controller pods and Ingress resources created by the controller.

#Deploy an Ingress resource and two instances of a backend service using the “hashicorp/http-echo”. The Ingress should send requests
#with path “/foo” to one service; and path “/bar” to another. The services should respond with “foo” and “bar” respectively.

#Ensure the above configuration is healthy, using Kubernetes APIs.
#Run a benchmarking tool of your choice against the Ingress.
#Generate a CSV file of time-series data using PromQL to fetch the following metrics from Prometheus:
#Average requests per second
#Average memory usage per second
#Average CPU usage per second
#
#Put your script and any additional required resources in a GitHub public repository. Include documentation that tells us how to run your script
#(including instructions on pre-requisites). Send us the link to the repository.

