#!/bin/bash

# Configuration
NAMESPACE="retail-app"

echo "----------------------------------------------------"
echo "Checking Deployment Status for: $NAMESPACE"
echo "----------------------------------------------------"

# 1. Get Pod Status
echo "=== Pods in $NAMESPACE ==="
kubectl get pods -n $NAMESPACE
echo ""

# 2. Get Ingress / DNS Name
echo "=== Ingress / External DNS URL ==="
# This retrieves the long AWS ELB address
DNS_NAME=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

if [ -z "$DNS_NAME" ]; then
    echo "Status: Load Balancer is still provisioning. Please wait 2-3 minutes."
else
    echo "Application URL: https://africodes.com"
    echo "AWS ELB Address: http://$DNS_NAME"
fi

echo ""
echo "----------------------------------------------------"
echo "To access the app via local tunnel (optional):"
echo "  kubectl port-forward svc/retail-store-sample-app-ui -n $NAMESPACE 8080:80"
echo "Then open: http://localhost:8080"
echo "----------------------------------------------------"
