#!/bin/bash
# Script de inicialización para la instancia EC2 bastión

# Actualizar el sistema
yum update -y
yum install -y jq git vim htop unzip

# Instalar AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Instalar kubectl
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.26.0/2023-01-30/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/
echo 'source <(kubectl completion bash)' >> /etc/bashrc
echo 'alias k=kubectl' >> /etc/bashrc
echo 'complete -o default -F __start_kubectl k' >> /etc/bashrc

# Instalar eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
echo 'source <(eksctl completion bash)' >> /etc/bashrc

# Instalar Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Instalar aws-iam-authenticator
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator
chmod +x ./aws-iam-authenticator
mv ./aws-iam-authenticator /usr/local/bin

# Crear directorios para el proyecto
mkdir -p /home/ec2-user/eks-project/{scripts,config}
chown -R ec2-user:ec2-user /home/ec2-user/eks-project

# Crear scripts en el directorio del proyecto
cat > /home/ec2-user/eks-project/scripts/deploy-nginx.sh << 'EOF'
#!/bin/bash
# Script para desplegar un pod de Nginx en el cluster EKS

set -e

echo "=== Iniciando despliegue de Nginx ==="

# Verificar conexión con el cluster
if ! kubectl get nodes &> /dev/null; then
  echo "ERROR: No se puede conectar al cluster EKS."
  echo "Verifique que el cluster está en ejecución y que kubeconfig está configurado correctamente."
  exit 1
fi

# Crear namespace para aplicaciones
echo "=== Creando namespace 'apps' ==="
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -

# Desplegar Nginx usando manifiestos YAML
echo "=== Creando deployment y service de Nginx ==="
cat <<YAMLEND | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: apps
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.23-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: apps
  labels:
    app: nginx
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: nginx
YAMLEND

# Esperar a que el deployment esté listo
echo "=== Esperando a que el deployment de Nginx esté listo ==="
kubectl -n apps rollout status deployment/nginx

# Verificar que los pods están ejecutándose
echo "=== Verificando pods de Nginx ==="
kubectl -n apps get pods -l app=nginx

# Verificar que el servicio está creado
echo "=== Verificando servicio de Nginx ==="
kubectl -n apps get svc nginx

# Esperar a que el balanceador de carga esté listo
echo "=== Esperando a que el balanceador de carga esté listo (puede tomar unos minutos) ==="
sleep 10

# Obtener la URL del balanceador de carga
NGINX_URL=$(kubectl -n apps get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "=== Nginx desplegado exitosamente ==="
echo "URL de Nginx: http://$NGINX_URL"
echo "Para probar la conexión, ejecute: curl -I http://$NGINX_URL"
EOF

cat > /home/ec2-user/eks-project/scripts/install-monitoring.sh << 'EOF'
#!/bin/bash
# Script para instalar Prometheus y Grafana en el cluster EKS

set -e

echo "=== Iniciando instalación de Prometheus y Grafana ==="

# Verificar conexión con el cluster
if ! kubectl get nodes &> /dev/null; then
  echo "ERROR: No se puede conectar al cluster EKS."
  echo "Verifique que el cluster está en ejecución y que kubeconfig está configurado correctamente."
  exit 1
fi

# Crear namespace para monitoreo
echo "=== Creando namespace 'monitoring' ==="
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Agregar repositorios de Helm para Prometheus y Grafana
echo "=== Agregando repositorios de Helm ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Crear archivo de valores para Prometheus
echo "=== Configurando valores para Prometheus ==="
cat <<PROMVALUES > prometheus-values.yaml
alertmanager:
  persistentVolume:
    storageClass: "gp2"
    size: 10Gi
server:
  persistentVolume:
    storageClass: "gp2"
    size: 10Gi
  securityContext:
    runAsUser: 0
    runAsNonRoot: false
    runAsGroup: 0
    fsGroup: 0
PROMVALUES

# Instalar Prometheus
echo "=== Instalando Prometheus ==="
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  -f prometheus-values.yaml

# Esperar a que Prometheus esté listo
echo "=== Esperando a que Prometheus esté listo ==="
kubectl -n monitoring rollout status statefulset/prometheus-server || echo "Esperando 30 segundos adicionales..."
sleep 30

# Crear archivo de valores para Grafana
echo "=== Configurando valores para Grafana ==="
cat <<GRAFVALUES > grafana-values.yaml
persistence:
  enabled: true
  storageClassName: "gp2"
  size: 10Gi
adminPassword: "EKS!sAWSome"
service:
  type: LoadBalancer
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.monitoring.svc.cluster.local
      access: proxy
      isDefault: true
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards/default
dashboards:
  default:
    kubernetes-cluster:
      gnetId: 3119
      revision: 2
      datasource: Prometheus
    kubernetes-pods:
      gnetId: 6417
      revision: 1
      datasource: Prometheus
GRAFVALUES

# Instalar Grafana
echo "=== Instalando Grafana ==="
helm install grafana grafana/grafana \
  --namespace monitoring \
  -f grafana-values.yaml

# Esperar a que Grafana esté listo
echo "=== Esperando a que Grafana esté listo ==="
kubectl -n monitoring rollout status deployment/grafana

# Obtener la URL del balanceador de carga de Grafana
GRAFANA_URL=$(kubectl -n monitoring get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Obtener la contraseña de admin de Grafana (aunque ya la establecimos, podemos verificarla)
GRAFANA_PASSWORD=$(kubectl -n monitoring get secret grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "=== Prometheus y Grafana instalados exitosamente ==="
echo "URL de Grafana: http://$GRAFANA_URL"
echo "Usuario: admin"
echo "Contraseña: $GRAFANA_PASSWORD"
echo ""
echo "Los dashboards de Kubernetes ya han sido preconfigurados para ti:"
echo "- Kubernetes Cluster Monitoring (ID: 3119)"
echo "- Kubernetes Pod Monitoring (ID: 6417)"
echo ""
echo "Para acceder a Prometheus directamente, puedes usar port-forward:"
echo "kubectl -n monitoring port-forward svc/prometheus-server 9090:80 --address 0.0.0.0"
EOF

cat > /home/ec2-user/eks-project/scripts/install-kube-state-metrics.sh << 'EOF'
#!/bin/bash
# Script para reinstalar kube-state-metrics como un chart independiente

set -e

echo "=== Creando archivo de configuración para kube-state-metrics ==="
cat <<VALUESFILE > kube-state-metrics-values.yaml
# Configuración personalizada para kube-state-metrics
args:
  - --port=8080
  - --resources=certificatesigningrequests,configmaps,cronjobs,daemonsets,deployments,endpoints,horizontalpodautoscalers,ingresses,jobs,leases,limitranges,mutatingwebhookconfigurations,namespaces,networkpolicies,nodes,persistentvolumeclaims,persistentvolumes,poddisruptionbudgets,pods,replicasets,replicationcontrollers,resourcequotas,secrets,services,statefulsets,storageclasses,validatingwebhookconfigurations,volumeattachments
  - --metric-labels-allowlist=pods=[*],nodes=[*]
  - --metric-annotations-allowlist=pods=[*],nodes=[*]
  - --collectors=pods,nodes,services,namespaces,deployments,resourcequotas,replicasets,limitranges,storageclasses,horizontalpodautoscalers,daemonsets,statefulsets
VALUESFILE

echo "=== Desinstalando el kube-state-metrics actual ==="
kubectl -n monitoring delete deployment prometheus-kube-state-metrics 2>/dev/null || echo "No se encontró el deployment, continuando..."

echo "=== Agregando y actualizando repositorios de Helm ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "=== Instalando kube-state-metrics como un chart independiente ==="
helm install kube-state-metrics prometheus-community/kube-state-metrics \
  --namespace monitoring \
  -f kube-state-metrics-values.yaml

echo "=== Verificando la instalación ==="
kubectl -n monitoring get pods | grep kube-state-metrics

echo "=== Esperando a que kube-state-metrics esté listo ==="
kubectl -n monitoring rollout status deployment kube-state-metrics

echo "=== Instalación completada exitosamente ==="
echo "Para verificar que las métricas están disponibles, ejecuta:"
echo "kubectl -n monitoring port-forward svc/kube-state-metrics 8080:8080"
echo "Y en otra terminal:"
echo "curl localhost:8080/metrics | grep kube_pod_container_resource"
EOF

cat > /home/ec2-user/eks-project/scripts/cleanup-resources.sh << 'EOF'
#!/bin/bash
# Script para limpiar todos los recursos creados en AWS

set -e

echo "=== Iniciando limpieza de recursos ==="

# Verificar conexión con el cluster
if ! kubectl get nodes &> /dev/null; then
  echo "ADVERTENCIA: No se puede conectar al cluster EKS."
  echo "Es posible que ya haya sido eliminado o que kubeconfig esté mal configurado."
  echo "Continuando con el proceso de limpieza..."
else
  # Eliminar recursos de Grafana y Prometheus
  echo "=== Eliminando Grafana y Prometheus ==="
  helm uninstall grafana --namespace monitoring 2>/dev/null || echo "Grafana no encontrado, continuando..."
  helm uninstall prometheus --namespace monitoring 2>/dev/null || echo "Prometheus no encontrado, continuando..."
  helm uninstall kube-state-metrics --namespace monitoring 2>/dev/null || echo "kube-state-metrics no encontrado, continuando..."
  
  # Eliminar el namespace de monitoreo
  echo "=== Eliminando namespace 'monitoring' ==="
  kubectl delete namespace monitoring --timeout=60s 2>/dev/null || echo "Namespace monitoring no encontrado, continuando..."
  
  # Eliminar el deployment y servicio de Nginx
  echo "=== Eliminando recursos de Nginx ==="
  kubectl delete deployment nginx -n apps --timeout=60s 2>/dev/null || echo "Deployment nginx no encontrado, continuando..."
  kubectl delete service nginx -n apps --timeout=60s 2>/dev/null || echo "Service nginx no encontrado, continuando..."
  
  # Eliminar el namespace de aplicaciones
  echo "=== Eliminando namespace 'apps' ==="
  kubectl delete namespace apps --timeout=60s 2>/dev/null || echo "Namespace apps no encontrado, continuando..."
  
  echo "=== Recursos de Kubernetes eliminados exitosamente ==="
fi

echo "=== Limpieza de recursos completada ==="
echo "Los recursos de Kubernetes han sido eliminados exitosamente."
echo "Para eliminar el cluster EKS, ejecute 'terraform destroy' desde su máquina local."
EOF

# Dar permisos de ejecución a los scripts
chmod +x /home/ec2-user/eks-project/scripts/*.sh

# Mensaje de bienvenida
cat >> /home/ec2-user/.bashrc << 'EOF'

echo "=================================================="
echo "  ¡Bienvenido a la instancia bastión para EKS!"
echo "=================================================="
echo "Esta instancia tiene todas las herramientas necesarias para gestionar EKS:"
echo "- AWS CLI v2"
echo "- kubectl"
echo "- eksctl"
echo "- Helm"
echo "- aws-iam-authenticator"
echo ""
echo "El directorio del proyecto está en: ~/eks-project"
echo "Para acceder al cluster EKS, ejecuta:"
echo "aws eks update-kubeconfig --name eks-cluster-devops --region us-east-1"
echo ""
echo "Para desplegar Nginx, ejecuta:"
echo "cd ~/eks-project && ./scripts/deploy-nginx.sh"
echo ""
echo "Para instalar Prometheus y Grafana, ejecuta:"
echo "cd ~/eks-project && ./scripts/install-monitoring.sh"
echo "=================================================="
EOF

# Mensaje de finalización
echo "Inicialización completada" > /home/ec2-user/init-complete.txt