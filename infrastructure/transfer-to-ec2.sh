#!/bin/bash
# Script para transferir los archivos del proyecto a la instancia EC2

set -e

# Verificar parámetros
if [ $# -ne 2 ]; then
  echo "Uso: $0 <ruta-clave-pem> <ip-instancia>"
  echo "Ejemplo: $0 ./devops-bastion-key.pem 54.234.123.45"
  exit 1
fi

KEY_PATH=$1
EC2_IP=$2

echo "=== Transfiriendo archivos al servidor EC2 ==="

# Verificar que existe la clave
if [ ! -f "$KEY_PATH" ]; then
  echo "ERROR: No se encontró la clave en $KEY_PATH"
  exit 1
fi

# Verificar acceso SSH
echo "=== Verificando acceso SSH ==="
if ! ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ec2-user@$EC2_IP "echo SSH OK"; then
  echo "ERROR: No se puede conectar a la instancia a través de SSH"
  echo "Verifica que la instancia está en ejecución y accesible"
  exit 1
fi

# Crear directorio en la instancia EC2 (para evitar errores)
ssh -i "$KEY_PATH" ec2-user@$EC2_IP "mkdir -p ~/eks-project"

# Transferir archivos de configuración
echo "=== Transfiriendo archivos de configuración ==="
ssh -i "$KEY_PATH" ec2-user@$EC2_IP "mkdir -p ~/eks-project/config"
scp -i "$KEY_PATH" ../config/cluster-config.yaml ec2-user@$EC2_IP:~/eks-project/config/

# Transferir scripts
echo "=== Transfiriendo scripts ==="
ssh -i "$KEY_PATH" ec2-user@$EC2_IP "mkdir -p ~/eks-project/scripts"
scp -i "$KEY_PATH" ../scripts/deploy-eks-cluster.sh ../scripts/deploy-nginx.sh ../scripts/install-monitoring.sh ../scripts/cleanup-resources.sh ../scripts/deploy-all.sh ec2-user@$EC2_IP:~/eks-project/scripts/

# Dar permisos de ejecución a los scripts
echo "=== Configurando permisos ==="
ssh -i "$KEY_PATH" ec2-user@$EC2_IP "chmod +x ~/eks-project/scripts/*.sh"

echo "=== Trasferencia completada exitosamente ==="
echo "Los archivos han sido transferidos a ~/eks-project/ en la instancia EC2"
echo ""
echo "Para conectarte a la instancia y ejecutar los scripts:"
echo "ssh -i $KEY_PATH ec2-user@$EC2_IP"
echo "cd ~/eks-project"
echo "./deploy-all.sh"