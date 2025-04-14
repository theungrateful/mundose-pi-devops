#!/bin/bash
# Script principal para orquestar todo el despliegue desde la instancia EC2

set -e

echo "==================================================="
echo "=== Proyecto integrador DevOps - EKS y Monitoring ==="
echo "==================================================="

# Determinar directorio del script y raíz del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Verificar que estamos en una instancia EC2
if [ ! -f /etc/amazon-linux-release ] && [ ! -f /etc/system-release ]; then
  echo "ADVERTENCIA: Este script está diseñado para ejecutarse en una instancia EC2 de Amazon Linux."
  echo "Algunos comandos podrían no funcionar correctamente en este entorno."
fi

# Verificar que los archivos de configuración existen
CONFIG_FILE="${PROJECT_ROOT}/config/cluster-config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: No se encontró el archivo de configuración del cluster en $CONFIG_FILE"
  echo "Asegúrate de que la estructura de directorios es correcta."
  exit 1
fi

# Verificar que las herramientas necesarias están instaladas
echo "=== Verificando herramientas necesarias ==="
TOOLS_OK=true

if ! command -v aws &> /dev/null; then
  echo "ERROR: AWS CLI no está instalado."
  TOOLS_OK=false
fi

if ! command -v kubectl &> /dev/null; then
  echo "ERROR: kubectl no está instalado."
  TOOLS_OK=false
fi

if ! command -v eksctl &> /dev/null; then
  echo "ERROR: eksctl no está instalado."
  TOOLS_OK=false
fi

if ! command -v helm &> /dev/null; then
  echo "ERROR: Helm no está instalado."
  TOOLS_OK=false
fi

if [ "$TOOLS_OK" = false ]; then
  echo "Faltan herramientas necesarias. Por favor, ejecuta el script de configuración del entorno."
  exit 1
fi

# Verificar permisos en los scripts
chmod +x "${SCRIPT_DIR}/deploy-eks-cluster.sh" "${SCRIPT_DIR}/deploy-nginx.sh" "${SCRIPT_DIR}/install-monitoring.sh" "${SCRIPT_DIR}/cleanup-resources.sh"

# Paso 1: Desplegar el cluster EKS
echo "=== PASO 1: Desplegar el cluster EKS ==="
"${SCRIPT_DIR}/deploy-eks-cluster.sh"
echo ""

# Preguntar al usuario si desea continuar
read -p "¿Continuar con el despliegue de Nginx? (s/n): " RESPUESTA
if [[ "$RESPUESTA" != "s" ]]; then
  echo "Proceso detenido. Se ha desplegado el cluster EKS."
  exit 0
fi

# Paso 2: Desplegar Nginx
echo "=== PASO 2: Desplegar Nginx ==="
"${SCRIPT_DIR}/deploy-nginx.sh"
echo ""

# Preguntar al usuario si desea continuar
read -p "¿Continuar con la instalación de Prometheus y Grafana? (s/n): " RESPUESTA
if [[ "$RESPUESTA" != "s" ]]; then
  echo "Proceso detenido. Se ha desplegado Nginx en el cluster EKS."
  exit 0
fi

# Paso 3: Instalar Prometheus y Grafana
echo "=== PASO 3: Instalar Prometheus y Grafana ==="
"${SCRIPT_DIR}/install-monitoring.sh"
echo ""

echo "==================================================="
echo "=== Despliegue completado exitosamente ==="
echo "==================================================="
echo ""
echo "Para limpiar todos los recursos cuando ya no sean necesarios, ejecute:"
echo "${SCRIPT_DIR}/cleanup-resources.sh"