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
cat <<EOF | kubectl apply -f -
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
EOF

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