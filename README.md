# Kubernetes Cluster Autoscaler with PodDisruptionBudgets

> Production-ready Kubernetes autoscaling on AWS EKS with real-time monitoring

![Kubernetes](https://img.shields.io/badge/kubernetes-v1.30-blue)
![AWS](https://img.shields.io/badge/AWS-EKS-orange)
![Python](https://img.shields.io/badge/python-3.9-green)


---
![Uploading AWS-EKS-Project.png…]()

## 🎯 What This Project Does

Automatically scales your Kubernetes cluster based on demand:

1. **Traffic increases** → HPA adds more pods
2. **Nodes are full** → Cluster Autoscaler adds new EC2 nodes
3. **Traffic decreases** → HPA removes pods
4. **Nodes are empty** → Cluster Autoscaler removes nodes (safely with PDB)

**Result:** Cost-efficient, self-healing infrastructure that scales automatically!

---

## ✨ What We Built

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| **Cluster Autoscaler** | Auto-adds/removes EC2 nodes | Min: 2, Max: 8 nodes |
| **HPA** | Auto-scales pods based on CPU | Min: 2, Max: 20 pods, Target: 30% CPU |
| **PodDisruptionBudget** | Ensures zero-downtime during scaling | Always keep 2 pods running |
| **Prometheus + Grafana** | Real-time monitoring & visualization | Custom dashboards |
| **Demo App** | Flask app with CPU-intensive endpoint | `/load` endpoint for testing |

---
## 📁 Project Structure
```
k8s-cluster-autoscaler/
├── app/                          # Flask application
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── kubernetes/                   # K8s manifests
│   ├── cluster-config.yaml      # EKS cluster config
│   ├── cluster-autoscaler.yaml  # Autoscaler deployment
│   ├── deployment.yaml          # App deployment
│   ├── hpa.yaml                 # Horizontal Pod Autoscaler
│   └── pdb.yaml                 # PodDisruptionBudget
├── monitoring/                   # Grafana dashboards
│   └── pdb-dashboard.json
├── scripts/                      # Helper scripts
│   └── complete-test.sh
└── README.md
## 🚀 Quick Start

### Prerequisites
```bash
# Required tools: AWS CLI, kubectl, eksctl, helm, docker
aws --version
kubectl version --client
eksctl version
helm version
docker --version
```

### 1. Create EKS Cluster (15-20 min)
```bash
eksctl create cluster -f kubernetes/cluster-config.yaml
```

### 2. Build & Push Docker Image
```bash
cd app

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1

# Create ECR repo
aws ecr create-repository --repository-name autoscaler-demo-app --region $AWS_REGION

# Build and push
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker build -t autoscaler-demo-app:v1 .
docker tag autoscaler-demo-app:v1 $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/autoscaler-demo-app:v1
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/autoscaler-demo-app:v1

cd ..
```

### 3. Deploy Everything
```bash
# Update deployment with your image
export IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/autoscaler-demo-app:v1"
sed -i "s|IMAGE_PLACEHOLDER|$IMAGE_URI|g" kubernetes/deployment.yaml

# Deploy
kubectl apply -f kubernetes/cluster-autoscaler.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/hpa.yaml
kubectl apply -f kubernetes/pdb.yaml

# Verify
kubectl get nodes
kubectl get pods
kubectl get hpa
kubectl get pdb
```

### 4. Install Monitoring
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --set grafana.adminPassword=admin123

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 --address 0.0.0.0 &
echo "Grafana: http://YOUR_IP:3000 (admin/admin123)"
```

---

## 🧪 Test Autoscaling

### Generate Load
```bash
# Get LoadBalancer URL
LB_URL=$(kubectl get svc autoscaler-demo-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Generate heavy load
for i in {1..50}; do
    ab -n 100000 -c 300 http://$LB_URL/load &
done
```

### Watch Scaling
```bash
# Terminal 1: Watch nodes
watch -n 2 kubectl get nodes

# Terminal 2: Watch pods
watch -n 2 kubectl get pods

# Terminal 3: Watch HPA
watch -n 2 kubectl get hpa

# Browser: Open Grafana and watch dashboards
```

### Expected Results

| Time | Nodes | Pods | Event |
|------|-------|------|-------|
| T+0 | 2 | 2 | Initial state |
| T+1m | 2 | 10 | HPA scales pods |
| T+2m | 5 | 20 | **Cluster Autoscaler adds nodes!** |
| T+10m | 5 | 5 | Load stops, HPA scales down |
| T+15m | 3 | 2 | **PDB protects minimum pods** |
| T+20m | 2 | 2 | Back to baseline |

---

## 🔍 How It Works
```
User Traffic → CPU Usage ↑ → HPA Scales Pods → Pods Pending (no space)
                                    ↓
                    Cluster Autoscaler Detects → Adds EC2 Nodes
                                    ↓
                    Pods Scheduled → Load Handled
                                    ↓
            Traffic Stops → HPA Scales Down → PDB Protects Minimum
                                    ↓
                    Cluster Autoscaler Removes Unused Nodes
```

### Key Features Explained

**🔄 Cluster Autoscaler**
- Watches for pods stuck in "Pending" state
- Calls AWS API to add/remove EC2 instances
- Respects PodDisruptionBudgets during scale-down

**📈 HPA (Horizontal Pod Autoscaler)**
- Monitors CPU usage via Metrics Server
- Scales pods when CPU > 30%
- Range: 2-20 replicas

**🛡️ PodDisruptionBudget**
- Ensures minimum 2 pods always running
- Prevents all pods being deleted at once
- Enables zero-downtime deployments

**📊 Monitoring**
- Prometheus collects metrics
- Grafana visualizes in real-time
- Track node count, pod status, PDB protection

---

## 🧹 Cleanup

**Delete everything to avoid AWS charges:**
```bash
# Delete cluster (takes 10-15 minutes)
eksctl delete cluster --name autoscaler-cluster --region us-east-1

# Delete ECR repository
aws ecr delete-repository --repository-name autoscaler-demo-app --force --region us-east-1

# Verify cleanup
aws eks list-clusters --region us-east-1
```

---

## 💰 Cost

**Approximate cost for 3-hour demo:**
- EKS Control Plane: $0.30
- EC2 Instances (2-8 × t3.small): $0.50-$2.00
- Load Balancer: $0.08
- **Total: ~$1-3**

---

## 📊 Grafana Dashboards

Import these dashboards:

1. **Kubernetes Cluster Monitoring** (ID: 15759)
   - Node count over time
   - Pod distribution
   - CPU/Memory usage

2. **PDB Dashboard** (Custom)
   - Current vs required pods
   - Disruption allowed status
   - Import from: `monitoring/pdb-dashboard.json`

---

## 🐛 Troubleshooting

**Cluster Autoscaler not scaling?**
```bash
kubectl logs -f deployment/cluster-autoscaler -n kube-system
```

**Pods stuck in Pending?**
```bash
kubectl describe pod <pod-name>
```

**Metrics not available?**
```bash
kubectl top nodes
```

---

## 📚 Key Learnings

1. **Cluster Autoscaler** ≠ HPA
   - CA scales **nodes**, HPA scales **pods**
2. **PDB prevents downtime** during node removal
3. **Scale-up is fast** (~2 min), **scale-down is slow** (~10 min)
4. **Monitoring is essential** to understand autoscaling behavior

---

## 🤝 Contributing

Contributions welcome! Open an issue or submit a PR.

---

## 📄 License

MIT License

---
