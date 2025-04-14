#!/bin/bash
# Script para desplegar un cluster EKS utilizando eksctl y la configuración YAML

set -e

echo "=== Iniciando despliegue del cluster EKS ==="

# Verificar si el usuario tiene AWS CLI configurado
if ! aws sts get-caller-identity &> /dev/null; then
  echo "ERROR: AWS CLI no está configurado o no tiene permisos suficientes."
  echo "Por favor, configure AWS CLI con 'aws configure' o verifique sus credenciales."
  exit 1
fi

# Determinar ruta al archivo de configuración según el directorio desde donde se ejecuta
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "${SCRIPT_DIR}/../config/cluster-config.yaml" ]; then
  # Si se ejecuta desde scripts/
  CONFIG_FILE="${SCRIPT_DIR}/../config/cluster-config.yaml"
elif [ -f "${PROJECT_ROOT}/config/cluster-config.yaml" ]; then
  # Si se ejecuta desde la raíz del proyecto
  CONFIG_FILE="${PROJECT_ROOT}/config/cluster-config.yaml"
else
  echo "ERROR: No se encontró el archivo de configuración 'config/cluster-config.yaml'"
  echo "Asegúrese de ejecutar este script desde el directorio raíz del proyecto o desde el directorio 'scripts/'."
  exit 1
fi

echo "=== Usando archivo de configuración: $CONFIG_FILE ==="

echo "=== Creando cluster EKS (esto puede tomar 15-20 minutos) ==="
eksctl create cluster -f "$CONFIG_FILE"

echo "=== Configurando kubeconfig para acceder al cluster ==="
eksctl utils write-kubeconfig --cluster eks-cluster-devops --region us-east-1

echo "=== Verificando los nodos del cluster ==="
kubectl get nodes -o wide

echo "=== Verificando los pods del sistema ==="
kubectl get pods -A

echo "=== Cluster EKS desplegado exitosamente ==="
echo "Nombre del cluster: eks-cluster-devops"
echo "Para eliminar el cluster cuando ya no sea necesario, ejecute:"
echo "eksctl delete cluster -f $CONFIG_FILE"