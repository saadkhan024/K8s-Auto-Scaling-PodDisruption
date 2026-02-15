#!/bin/bash

echo "🎯 CLUSTER AUTOSCALER - LIVE MONITORING"
echo "========================================"

while true; do
    clear
    echo "🖥️  NODES (Watch for new nodes appearing!):"
    echo "-------------------------------------------"
    kubectl get nodes -o wide
    echo ""
    
    echo "📦 PODS (Watch count increase!):"
    echo "-------------------------------------------"
    kubectl get pods -l app=autoscaler-demo -o wide | head -20
    TOTAL_PODS=$(kubectl get pods -l app=autoscaler-demo --no-headers | wc -l)
    echo "TOTAL PODS: $TOTAL_PODS"
    echo ""
    
    echo "📊 HPA STATUS:"
    echo "-------------------------------------------"
    kubectl get hpa autoscaler-demo-hpa
    echo ""
    
    echo "🔄 CLUSTER AUTOSCALER STATUS:"
    echo "-------------------------------------------"
    kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml 2>/dev/null | grep "status:" -A 20
    echo ""
    
    echo "📈 RESOURCE USAGE:"
    echo "-------------------------------------------"
    kubectl top nodes 2>/dev/null
    echo ""
    
    echo "Last updated: $(date)"
    echo "Press Ctrl+C to stop"
    
    sleep 5
done
