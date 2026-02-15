#!/bin/bash

echo "🚀 Cluster Autoscaler + PDB Complete Test"
echo "=========================================="
echo ""

# Get LoadBalancer URL
LB_URL=$(kubectl get svc autoscaler-demo-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$LB_URL" ]; then
    echo "❌ LoadBalancer URL not found!"
    echo "Creating service..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: autoscaler-demo-service
spec:
  selector:
    app: autoscaler-demo
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5000
  type: LoadBalancer
EOF
    echo "Waiting for LoadBalancer..."
    sleep 60
    LB_URL=$(kubectl get svc autoscaler-demo-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi

echo "LoadBalancer: $LB_URL"
echo ""

# Phase 1: Show initial state
echo "📊 PHASE 1: Initial State"
echo "=========================="
echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "Pods: $(kubectl get pods -l app=autoscaler-demo --no-headers | wc -l)"
kubectl get pdb autoscaler-demo-pdb
echo ""
echo "✅ Check Grafana now - note the baseline"
read -p "Press Enter to start load test..."

# Phase 2: Generate load
echo ""
echo "🔥 PHASE 2: Generating Heavy Load"
echo "=================================="
echo "This will:"
echo "  1. Increase pod CPU usage"
echo "  2. Trigger HPA to scale pods"
echo "  3. Fill up nodes"
echo "  4. Trigger Cluster Autoscaler to add nodes"
echo ""

# Start load in background
for i in {1..30}; do
    ab -n 50000 -c 200 http://$LB_URL/load > /dev/null 2>&1 &
done

echo "✅ Load generation started!"
echo ""
echo "👀 WATCH THESE IN DIFFERENT TERMINALS:"
echo "  Terminal 2: watch -n 2 'kubectl get nodes'"
echo "  Terminal 3: watch -n 2 'kubectl get pods -l app=autoscaler-demo'"
echo "  Terminal 4: watch -n 2 'kubectl get hpa'"
echo "  Grafana: Watch PDB metrics updating"
echo ""
echo "You should see:"
echo "  - Pods increasing (2 → 10 → 20)"
echo "  - Some pods in Pending state"
echo "  - NEW NODES appearing (3 → 4 → 5 → 6)"
echo "  - PDB showing higher 'current healthy' count"
echo ""

# Wait and monitor
for i in {1..10}; do
    NODES=$(kubectl get nodes --no-headers | wc -l)
    PODS=$(kubectl get pods -l app=autoscaler-demo --no-headers | wc -l)
    echo "[$i/10] Nodes: $NODES | Pods: $PODS"
    sleep 30
done

echo ""
echo "📊 CURRENT STATE:"
kubectl get nodes
echo ""
kubectl get pods -l app=autoscaler-demo
echo ""
kubectl get pdb autoscaler-demo-pdb
echo ""
read -p "Press Enter to STOP load and watch scale down..."

# Phase 3: Stop load
echo ""
echo "🛑 PHASE 3: Stopping Load"
echo "========================="
killall ab 2>/dev/null
echo "✅ Load stopped"
echo ""
echo "Now watch the scale-down:"
echo "  - HPA will reduce pods"
echo "  - PDB will PROTECT minimum 2 pods"
echo "  - Cluster Autoscaler will wait for PDB"
echo "  - Nodes will be removed one by one (safely!)"
echo ""
echo "In Grafana PDB dashboard, you'll see:"
echo "  - 'Current Healthy' decreasing"
echo "  - When it hits 'Minimum Required' (2):"
echo "  - 'Disruption Allowed' will turn RED (NO)"
echo "  - 'Allowed Disruptions' will be 0"
echo ""

# Monitor scale down
for i in {1..20}; do
    NODES=$(kubectl get nodes --no-headers | wc -l)
    PODS=$(kubectl get pods -l app=autoscaler-demo --no-headers | wc -l)
    PDB_STATUS=$(kubectl get pdb autoscaler-demo-pdb -o jsonpath='{.status.currentHealthy}')
    echo "[$i/20] Nodes: $NODES | Pods: $PODS | Healthy: $PDB_STATUS"
    sleep 30
done

echo ""
echo "=========================================="
echo "✅ TEST COMPLETE!"
echo "=========================================="
echo ""
echo "Final State:"
kubectl get nodes
echo ""
kubectl get pods -l app=autoscaler-demo
echo ""
kubectl get pdb autoscaler-demo-pdb
echo ""
echo "Check Grafana to see the complete timeline!"
