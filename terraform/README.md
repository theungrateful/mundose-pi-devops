# Proyecto Integrador DevOps con Terraform

Este directorio contiene los archivos de Terraform necesarios para desplegar la infraestructura completa del proyecto integrador DevOps, incluyendo un cluster EKS y una instancia bastión para gestionarlo.

## Estructura de Archivos

```
terraform/
├── main.tf                # Configuración principal de la infraestructura
├── variables.tf           # Definición de variables
├── outputs.tf             # Outputs al finalizar el despliegue
└── scripts/
    └── user-data.sh       # Script de inicialización para la instancia bastión
```

## Recursos Creados

Este código Terraform crea los siguientes recursos:

- VPC con subredes públicas y privadas
- Instancia EC2 bastión para gestionar el cluster
- Cluster EKS con un grupo de nodos gestionados
- Roles y políticas IAM necesarios
- Grupo de seguridad para la instancia bastión

## Requisitos Previos

1. [Terraform](https://www.terraform.io/downloads.html) v1.0.0 o superior
2. [AWS CLI](https://aws.amazon.com/cli/) configurado con credenciales válidas
3. Un par de claves SSH para conectarse a la instancia bastión

## Variables

Las principales variables que puedes personalizar son:

| Variable | Descripción | Valor por Defecto |
|----------|-------------|-------------------|
| `region` | Región de AWS | us-east-1 |
| `project_name` | Nombre del proyecto | devops-eks |
| `cluster_name` | Nombre del cluster EKS | eks-cluster-devops |
| `cluster_version` | Versión de Kubernetes | 1.26 |
| `bastion_instance_type` | Tipo de instancia para el bastión | t3.small |
| `ssh_public_key_path` | Ruta a la clave SSH pública | ~/.ssh/id_rsa.pub |
| `aws_admin_user` | Usuario IAM para acceso local | TerraformUser |

## Uso

### 1. Inicializar Terraform

```bash
terraform init
```

### 2. Planificar el Despliegue

```bash
terraform plan -out=tfplan
```

### 3. Aplicar el Despliegue

```bash
terraform apply tfplan
```

### 4. Conectarse a la Instancia Bastión

Una vez completado el despliegue, Terraform mostrará la IP pública de la instancia bastión y el comando SSH para conectarse:

```bash
ssh -i ~/.ssh/id_rsa ec2-user@<BASTION_PUBLIC_IP>
```

### 5. Configurar kubectl en la Instancia Bastión

```bash
aws eks update-kubeconfig --name eks-cluster-devops --region us-east-1
```

### 6. Desplegar Aplicaciones

En la instancia bastión, ejecuta:

```bash
cd ~/eks-project
./scripts/deploy-nginx.sh
./scripts/install-monitoring.sh
```

### 7. Acceder a las Aplicaciones

- **Nginx**: El script mostrará la URL del balanceador de carga
- **Grafana**: Accede a través de la URL del balanceador de carga (usuario: admin, contraseña: EKS!sAWSome)
- **Prometheus**: Disponible a través de port-forward desde la instancia bastión

### 8. Limpieza de Recursos

Para eliminar todos los recursos creados:

```bash
terraform destroy
```

## Configuración de Acceso Local

Para acceder al cluster EKS desde tu máquina local, asegúrate de que:

1. El usuario IAM especificado en `aws_admin_user` existe en AWS
2. Ejecuta en tu máquina local:
   ```bash
   aws eks update-kubeconfig --name eks-cluster-devops --region us-east-1
   ```

Si necesitas acceso adicional para usuarios o roles, modifica el bloque `aws_auth_users` en `main.tf`.

## Solución de Problemas

1. **Error de acceso al cluster**: Verifica que el usuario IAM tiene los permisos necesarios
2. **Problemas con EBS**: Asegúrate de que el driver EBS CSI está instalado
3. **Errores de timeout**: La creación del cluster EKS puede tardar 15-20 minutos

## Personalización

Para personalizar la configuración del cluster EKS o la instancia bastión, modifica los archivos:

- `variables.tf`: Para cambiar valores predeterminados
- `main.tf`: Para modificar la arquitectura o añadir recursos

## Notas de Seguridad

- La instancia bastión está expuesta a Internet en el puerto 22 (SSH)
- El puerto 9090 está abierto para acceder a Prometheus desde fuera
- Para entornos de producción, considera restringir el acceso a IPs específicas
- Se aplica el principio de privilegio mínimo en los roles IAM, excepto para el rol de bastión que tiene permisos amplios para facilitar la administración

---

Para más información sobre los componentes desplegados, consulta el README principal del proyecto.