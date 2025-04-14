#!/bin/bash
# Script para crear una instancia EC2 que funcionará como bastión para gestionar EKS

set -e

echo "=== Creando instancia EC2 como bastión para gestionar EKS ==="

# Verificar que AWS CLI está configurado
if ! aws sts get-caller-identity &> /dev/null; then
  echo "ERROR: AWS CLI no está configurado o no tiene permisos suficientes."
  echo "Por favor, configure AWS CLI con 'aws configure' o verifique sus credenciales."
  exit 1
fi

# Configuración de la instancia EC2
REGION="us-east-1"
AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --query "Parameters[0].Value" --output text --region $REGION)
INSTANCE_TYPE="t3.small"
KEY_NAME="devops-bastion-key"
SECURITY_GROUP_NAME="devops-bastion-sg"
IAM_ROLE_NAME="devops-eks-admin-role"
USER_DATA_FILE="ec2-user-data.sh"

# Crear archivo de user-data para la instancia
echo "=== Creando script de inicialización (user-data) ==="
cat <<EOF > $USER_DATA_FILE
#!/bin/bash
# Script de inicialización para la instancia EC2

# Actualizar sistema
yum update -y
yum install -y jq git vim htop unzip

# Instalar AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Instalar kubectl (última versión estable)
curl -LO "https://dl.k8s.io/release/\$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
echo 'source <(kubectl completion bash)' >> /etc/bashrc
echo 'alias k=kubectl' >> /etc/bashrc
echo 'complete -o default -F __start_kubectl k' >> /etc/bashrc

# Instalar eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_\$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
echo 'source <(eksctl completion bash)' >> /etc/bashrc

# Instalar Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Crear directorio para el proyecto
mkdir -p /home/ec2-user/eks-project
chown ec2-user:ec2-user /home/ec2-user/eks-project

# Mensaje de finalización
echo "Inicialización completada" > /home/ec2-user/init-complete.txt
EOF


# Crear par de claves SSH si no existe
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &> /dev/null; then
  echo "=== Creando par de claves SSH '$KEY_NAME' ==="
  aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text --region $REGION > "${KEY_NAME}.pem"
  chmod 400 "${KEY_NAME}.pem"
  echo "Par de claves guardado como ${KEY_NAME}.pem"
else
  echo "Par de claves '$KEY_NAME' ya existe"
fi

# Crear grupo de seguridad si no existe
if ! aws ec2 describe-security-groups --group-names $SECURITY_GROUP_NAME --region $REGION &> /dev/null 2>&1; then
  echo "=== Creando grupo de seguridad '$SECURITY_GROUP_NAME' ==="
  SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "Security group for DevOps EKS bastion host" --region $REGION --query 'GroupId' --output text)
  
  # Agregar reglas de entrada para SSH
  aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
  
  echo "Grupo de seguridad creado: $SECURITY_GROUP_ID"
else
  SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --group-names $SECURITY_GROUP_NAME --region $REGION --query 'SecurityGroups[0].GroupId' --output text)
  echo "Usando grupo de seguridad existente: $SECURITY_GROUP_ID"
fi

# Crear rol IAM para la instancia EC2 si no existe
if ! aws iam get-role --role-name $IAM_ROLE_NAME &> /dev/null 2>&1; then
  echo "=== Creando rol IAM '$IAM_ROLE_NAME' ==="
  
  # Crear documento de política de confianza
  cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  # Crear rol
  aws iam create-role --role-name $IAM_ROLE_NAME --assume-role-policy-document file://trust-policy.json

  # Adjuntar políticas al rol
  aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
  aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSServicePolicy
  aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonECR-FullAccess || aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonElasticContainerRegistryFullAccess
  aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKS-CNI-Policy
  aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
  aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
  aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
  
  # Crear perfil de instancia
  aws iam create-instance-profile --instance-profile-name $IAM_ROLE_NAME
  
  # Asociar rol al perfil de instancia
  aws iam add-role-to-instance-profile --instance-profile-name $IAM_ROLE_NAME --role-name $IAM_ROLE_NAME
  
  # Esperar a que el perfil de instancia esté disponible
  echo "Esperando a que el perfil de instancia esté disponible..."
  sleep 10
  
  echo "Rol IAM y perfil de instancia creados"
else
  echo "Usando rol IAM existente: $IAM_ROLE_NAME"
  
  # Verificar si existe el perfil de instancia
  if ! aws iam get-instance-profile --instance-profile-name $IAM_ROLE_NAME &> /dev/null 2>&1; then
    # Crear perfil de instancia
    aws iam create-instance-profile --instance-profile-name $IAM_ROLE_NAME
    
    # Asociar rol al perfil de instancia
    aws iam add-role-to-instance-profile --instance-profile-name $IAM_ROLE_NAME --role-name $IAM_ROLE_NAME
    
    # Esperar a que el perfil de instancia esté disponible
    echo "Esperando a que el perfil de instancia esté disponible..."
    sleep 10
  fi
fi

# Lanzar instancia EC2
echo "=== Lanzando instancia EC2 ==="
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SECURITY_GROUP_ID \
  --user-data file://$USER_DATA_FILE \
  --iam-instance-profile Name=$IAM_ROLE_NAME \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=DevOps-EKS-Bastion}]" \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instancia lanzada con ID: $INSTANCE_ID"

# Esperar a que la instancia esté en ejecución
echo "=== Esperando a que la instancia esté en ejecución ==="
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Obtener la IP pública de la instancia
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
PUBLIC_DNS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].PublicDnsName' --output text)

echo "=== Instancia EC2 creada exitosamente ==="
echo "ID de la instancia: $INSTANCE_ID"
echo "Dirección IP pública: $PUBLIC_IP"
echo "Nombre DNS público: $PUBLIC_DNS"
echo ""
echo "Para conectarte a la instancia, utiliza:"
echo "ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo ""
echo "IMPORTANTE: Espera aproximadamente 2-3 minutos para que la inicialización se complete"
echo "Puedes verificar que la inicialización ha terminado con:"
echo "ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP 'cat init-complete.txt'"
echo ""
echo "Los scripts del proyecto deben ser transferidos a la instancia usando:"
echo "scp -i ${KEY_NAME}.pem -r ./scripts/* ec2-user@$PUBLIC_IP:~/eks-project/"

# Limpiar archivos temporales
rm -f trust-policy.json $USER_DATA_FILE