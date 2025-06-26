# Thanos Stack Monitoring Chart

Comprehensive monitoring solution for Thanos Stack (built by OP Stack) with optimized service discovery, persistent storage, and Fargate compatibility.

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

## Features

- **Universal Service Discovery**: Single ServiceMonitor automatically discovers all Thanos Stack components
- **Persistent Storage**: EFS-based storage with static provisioning for data persistence
- **Fargate Compatible**: Optimized for AWS EKS Fargate environments
- **Pre-built Dashboards**: Three comprehensive Grafana dashboards for system, application, and health monitoring
- **L1 RPC Monitoring**: Blackbox exporter for L1 blockchain connectivity health checks
- **Intelligent Metric Collection**: Multi-endpoint scraping with proper job labeling

## Architecture

### Monitoring Stack Overview

```
┌─────────────────────────────────────────┐
│              Grafana                     │
│   - thanos-stack-system.json           │
│   - thanos-stack-application.json      │
│   - thanos-stack-health.json           │
│   + AWS ALB Ingress                    │
└─────────────────────────────────────────┘
                     │
┌─────────────────────────────────────────┐
│             Prometheus                   │
│   - 1 year retention                    │
│   - EFS persistent storage              │
│   - Universal service discovery         │
└─────────────────────────────────────────┘
                     │
┌─────────────────────────────────────────┐
│       Universal ServiceMonitor          │
│   - Auto-discovers Helm services        │
│   - Multi-endpoint scraping             │
│   - Dynamic job labeling                │
└─────────────────────────────────────────┘
                     │
┌─────────────────────────────────────────┐
│        Thanos Stack Services            │
│ op-geth │ op-node │ op-batcher │ op-proposer │
│      blockscout │ external-secrets      │
└─────────────────────────────────────────┘
```

### Storage Architecture

```
EFS File System (fs-xxxxxxxxx)
├── prometheus/          # Prometheus TSDB data
│   ├── chunks/
│   ├── wal/
│   └── ...
├── grafana/            # Grafana dashboards & config
│   ├── grafana.db
│   ├── plugins/
│   └── ...
├── op-geth/           # Thanos Stack data (shared)
└── op-node/           # Thanos Stack data (shared)
```

## Installation

### Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- Existing Thanos Stack deployment
- EFS file system (for persistent storage)

### Quick Start

```bash
# Install monitoring plugin via Rollup Hub SDK
trh-sdk install monitoring

# Uninstall monitoring plugin
trh-sdk uninstall monitoring
```


## Configuration

### Core Configuration

```yaml
# Global settings
global:
  l1RpcUrl: "https://ethereum-sepolia.example.com"
  storage:
    enabled: true                    # Enable persistent storage
    useStaticProvisioning: true      # Use existing EFS (recommended)
    efsFileSystemId: "fs-xxxxxxxxx"  # Your EFS file system ID

# Thanos Stack integration
thanosStack:
  chainName: "your-chain"           # Chain identifier
  namespace: "thanos-namespace"     # Thanos Stack namespace
  releaseName: "thanos-release"     # Thanos Stack release name

# Grafana credentials
kube-prometheus-stack:
  grafana:
    adminUser: admin
    adminPassword: "your-secure-password"
```

### Advanced Storage Configuration

```yaml
global:
  storage:
    enabled: true
    useStaticProvisioning: true
    efsFileSystemId: "fs-032bd032daed4455d"
    
# Automatically generates:
# - PersistentVolumes with proper subdirectories
# - PersistentVolumeClaims for Prometheus and Grafana
# - Volume mounts with correct paths
```

### Service Discovery Configuration

The Universal ServiceMonitor automatically discovers services with these patterns:

```yaml
# Automatic discovery criteria
selector:
  matchExpressions:
    - key: app.kubernetes.io/managed-by
      operator: In
      values: ["Helm"]

# Monitored endpoints
endpoints:
  - targetPort: 7300    # OP Stack components (op-node, op-batcher, op-proposer)
    path: /metrics
    interval: 30s
    
  - targetPort: 6060    # op-geth metrics
    path: /debug/metrics/prometheus
    interval: 30s
    
  - targetPort: 3000    # Blockscout metrics
    path: /metrics
    interval: 1m
```

### Custom Scrape Targets

```yaml
scrapeTargets:
  # Enable/disable specific components
  opNode:
    enabled: true
    port: 7300
    path: "/metrics"
    interval: "30s"
  
  opGeth:
    enabled: true
    port: 6060
    path: "/debug/metrics/prometheus"
    interval: "30s"
  
  blockscout:
    enabled: true
    port: 3000
    path: "/metrics"
    interval: "1m"
  
  # Add custom services
  customService:
    enabled: true
    port: 8080
    path: "/custom/metrics"
    interval: "15s"
```

## Monitoring Features

### Built-in Dashboards

The chart includes three comprehensive Grafana dashboards:

#### 1. **thanos-stack-system.json**
- Kubernetes cluster metrics
- Pod status and resource usage
- Node and namespace overview
- Storage and network metrics

#### 2. **thanos-stack-application.json**
- Thanos Stack component health
- op-geth, op-node, op-batcher, op-proposer metrics
- L1/L2 synchronization status

#### 3. **thanos-stack-health.json**
- Service availability monitoring
- L1 RPC connectivity checks

### Metric Collection

#### Automatic Job Labeling

Services are automatically labeled with appropriate job names:

```yaml
# Regex-based job labeling
- sourceLabels: [__meta_kubernetes_service_name]
  targetLabel: job
  regex: ".*-(op-[^-]+).*"      # op-node, op-batcher, op-proposer
  replacement: "${1}"

- sourceLabels: [__meta_kubernetes_service_name]
  targetLabel: job
  regex: ".*(geth).*"           # op-geth
  replacement: "op-geth"

- sourceLabels: [__meta_kubernetes_service_name]
  targetLabel: job
  regex: ".*blockscout.*"       # blockscout
  replacement: "blockscout"
```

#### Collected Metrics

**OP Stack Components:**
- `op_node_*`: L2 node synchronization and processing
- `op_batcher_*`: Batch submission to L1
- `op_proposer_*`: L2 block proposals
- `geth_*`: Blockchain node metrics (blocks, transactions, peers)

**System Metrics:**
- `kube_*`: Kubernetes cluster state
- `container_*`: Container resource usage
- `probe_*`: L1 RPC health checks

### L1 RPC Monitoring

Blackbox exporter monitors L1 blockchain connectivity:

```yaml
# Automatic L1 RPC health checks
modules:
  http_post_eth_node_synced_2xx:    # Sync status check
  http_post_eth_block_number_2xx:   # Block number check
  tcp_connect:                      # TCP connectivity

# Monitored endpoints
- eth_syncing: Checks if L1 node is synced
- eth_blockNumber: Validates L1 block production
```

## Accessing the Monitoring Stack

### Grafana Dashboard

```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/monitoring-[timestamp]-grafana 3000:80

# Access via browser
http://localhost:3000
# Username: admin
# Password: [configured password]
```

### Prometheus Interface

```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/monitoring-[timestamp]-kube-prometheus 9090:9090

# Access via browser
http://localhost:9090
```

### AWS Load Balancer (Production)

```bash
# Get ALB URL
kubectl get ingress -n monitoring

# Access Grafana via ALB
http://k8s-thanosmonitoring-[ID]-[REGION].elb.amazonaws.com
```

## Troubleshooting

### Common Issues

#### 1. Services Not Discovered

```bash
# Check ServiceMonitor status
kubectl get servicemonitor -n monitoring
kubectl describe servicemonitor -n monitoring

# Verify target discovery
kubectl port-forward -n monitoring svc/monitoring-[timestamp]-kube-prometheus 9090:9090
# Visit http://localhost:9090/targets
```

#### 2. Missing Metrics

```bash
# Check service endpoints
kubectl get endpoints -n [chain-namespace]

# Verify service labels
kubectl get svc -n [chain-namespace] --show-labels

# Check Prometheus logs
kubectl logs -n monitoring prometheus-monitoring-[timestamp]-kube-prometheus-0 -c prometheus
```

#### 3. Storage Issues

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Verify EFS mount
kubectl describe pv monitoring-[timestamp]-prometheus
kubectl describe pv monitoring-[timestamp]-grafana

# Check pod storage mounts
kubectl describe pod -n monitoring prometheus-monitoring-[timestamp]-kube-prometheus-0
```

#### 4. Grafana Dashboard Issues

```bash
# Check Grafana pod status
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# View Grafana logs
kubectl logs -n monitoring deployment/monitoring-[timestamp]-grafana

# Restart Grafana
kubectl rollout restart deployment/monitoring-[timestamp]-grafana -n monitoring
```

### Debugging Commands

```bash
# Get all monitoring resources
kubectl get all -n monitoring

# Check ServiceMonitor targets
kubectl get servicemonitor -n monitoring -o yaml

# Verify Prometheus configuration
kubectl get prometheus -n monitoring -o yaml

# Check storage configuration
kubectl get storageclass
kubectl get pv | grep monitoring
```

### Performance Tuning

#### Resource Optimization

```yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      resources:
        requests:
          cpu: 1500m      # Adjust based on load
          memory: 3Gi     # Adjust based on metrics volume
        
      retention: 1y         # Adjust retention period
      retentionSize: 10GB   # Adjust storage size
  
  grafana:
    resources:
      requests:
        cpu: 1500m
        memory: 4Gi
```

#### Scrape Interval Optimization

```yaml
# Adjust scrape intervals based on requirements
scrapeTargets:
  opNode:
    interval: "15s"    # High-frequency for critical components
  opGeth:
    interval: "30s"    # Standard interval
  blockscout:
    interval: "2m"     # Lower frequency for less critical metrics
```

## Dependencies

- **kube-prometheus-stack**: v65.1.1
- **prometheus-blackbox-exporter**: v8.17.0
- **Kubernetes**: v1.19+
- **Helm**: v3.8+
- **EFS CSI Driver**: v1.4.0+ (for persistent storage)

## Security Considerations

- Grafana admin password should be stored securely
- Consider enabling Grafana authentication integration
- Restrict ALB access using security groups
- Use RBAC for Prometheus ServiceMonitor access

## License

Licensed under the MIT License. See [LICENSE](../../LICENSE) for details. 