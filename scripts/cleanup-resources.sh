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
  helm uninstall grafana --namespace monitoring
  helm uninstall prometheus --namespace monitoring
  
  # Eliminar el namespace de monitoreo
  echo "=== Eliminando namespace 'monitoring' ==="
  kubectl delete namespace monitoring --timeout=60s
  
  # Eliminar el deployment y servicio de Nginx
  echo "=== Eliminando recursos de Nginx ==="
  kubectl delete deployment nginx -n apps --timeout=60s
  kubectl delete service nginx -n apps --timeout=60s
  
  # Eliminar el namespace de aplicaciones
  echo "=== Eliminando namespace 'apps' ==="
  kubectl delete namespace apps --timeout=60s
  
  echo "=== Recursos de Kubernetes eliminados exitosamente ==="
fi

# Verificar si el archivo de configuración existe
CONFIG_FILE="cluster-config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ADVERTENCIA: No se encontró el archivo de configuración $CONFIG_FILE"
  echo "Se intentará eliminar el cluster usando su nombre."
  
  # Preguntar al usuario si desea continuar
  read -p "¿Desea eliminar el cluster 'eks-cluster-devops'? (s/n): " RESPUESTA
  if [[ "$RESPUESTA" != "s" ]]; then
    echo "Operación cancelada."
    exit 0
  fi
  
  # Eliminar el cluster usando su nombre
  echo "=== Eliminando cluster EKS 'eks-cluster-devops' ==="
  eksctl delete cluster --name eks-cluster-devops
else
  # Preguntar al usuario si desea continuar
  read -p "¿Desea eliminar el cluster definido en $CONFIG_FILE? (s/n): " RESPUESTA
  if [[ "$RESPUESTA" != "s" ]]; then
    echo "Operación cancelada."
    exit 0
  fi
  
  # Eliminar el cluster usando el archivo de configuración
  echo "=== Eliminando cluster EKS usando configuración ==="
  eksctl delete cluster -f "$CONFIG_FILE"
fi

# Eliminar archivos temporales
echo "=== Eliminando archivos temporales ==="
rm -f prometheus-values.yaml grafana-values.yaml

# Verificar si la clave SSH existe
if aws ec2 describe-key-pairs --key-names eks-key &> /dev/null; then
  # Preguntar al usuario si desea eliminar la clave SSH
  read -p "¿Desea eliminar el par de claves SSH 'eks-key'? (s/n): " RESPUESTA
  if [[ "$RESPUESTA" == "s" ]]; then
    # Eliminar el par de claves SSH
    echo "=== Eliminando par de claves SSH 'eks-key' ==="
    aws ec2 delete-key-pair --key-name eks-key
    rm -f eks-key.pem
  fi
fi

echo "=== Limpieza de recursos completada ==="
echo "Todos los recursos han sido eliminados exitosamente."