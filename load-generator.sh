#!/bin/bash

# Get LoadBalancer URL
LB_URL=$(kubectl get svc autoscaler-demo-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$LB_URL" ]; then
    echo "❌ LoadBalancer URL not found! Waiting..."
    exit 1
fi

echo "🚀 Starting Load Generator..."
echo "📍 Target: http://$LB_URL/load"
echo "⏰ Duration: Continuous (Press Ctrl+C to stop)"
echo "=========================================="

# Install Apache Bench if not installed
if ! command -v ab &> /dev/null; then
    echo "Installing Apache Bench..."
    sudo apt-get update && sudo apt-get install -y apache2-utils
fi

# Generate massive load
echo "🔥 Generating HEAVY load..."
echo "This will trigger:"
echo "  1. HPA to scale pods (2 → 50 pods)"
echo "  2. Cluster Autoscaler to add nodes (2 → 10 nodes)"
echo ""

# Run multiple concurrent load tests
for i in {1..10}; do
    echo "Starting load batch $i..."
    ab -n 10000 -c 100 http://$LB_URL/load &
done

echo ""
echo "✅ Load generation started!"
echo "🔍 Open another terminal and run:"
echo "   watch -n 2 'kubectl get nodes'"
echo "   watch -n 2 'kubectl get hpa'"
echo "   watch -n 2 'kubectl get pods'"
