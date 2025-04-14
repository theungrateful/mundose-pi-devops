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
echo "Esperando 30 segundos para que Prometheus se inicialice..."
sleep 30
echo "Verificando los pods de Prometheus..."
kubectl -n monitoring get pods | grep prometheus

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
echo "kubectl -n monitoring port-forward svc/prometheus-server 9090:80"