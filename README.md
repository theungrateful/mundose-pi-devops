# Proyecto Integrador DevOps - AWS EKS y Monitoring

Este proyecto implementa una infraestructura completa en AWS para el despliegue y monitoreo de aplicaciones containerizadas utilizando Kubernetes (EKS) y herramientas de observabilidad.

## Descripción General

El objetivo principal de este proyecto es aprender sobre distintas tecnologías DevOps mediante la implementación de un laboratorio práctico que integra múltiples herramientas y servicios. Se centra en:

1. Provisión de infraestructura en AWS
2. Creación y gestión de clusters Kubernetes
3. Despliegue de aplicaciones containerizadas
4. Monitoreo y observabilidad

## Estructura del Proyecto

```
pi-devops/
├── README.md                       # Documentación principal
├── scripts/                        # Scripts principales
│   ├── deploy-eks-cluster.sh       # Despliegue del cluster EKS
│   ├── deploy-nginx.sh             # Despliegue de Nginx
│   ├── install-monitoring.sh       # Instala Prometheus y Grafana
│   ├── install-kube-state-metrics.sh # Instala kube-state-metrics
│   ├── cleanup-resources.sh        # Limpieza de recursos
│   └── deploy-all.sh               # Script orquestador principal
├── config/                         # Archivos de configuración
│   ├── cluster-config.yaml         # Configuración del cluster EKS
│   ├── kube-state-metrics-values.yaml # Valores para kube-state-metrics
│   ├── prometheus-values.yaml      # Valores para Prometheus (generado)
│   └── grafana-values.yaml         # Valores para Grafana (generado)
├── infrastructure/                 # Gestión de infraestructura
│   ├── create-bastion.sh           # Crea instancia EC2 bastión
│   └── transfer-to-ec2.sh          # Transfiere archivos a EC2
└── keys/                           # Claves y credenciales (gitignore)
    └── devops-bastion-key.pem      # Clave privada para EC2
```

## Componentes Principales

### Amazon EKS (Elastic Kubernetes Service)

EKS es un servicio administrado de Kubernetes que facilita la ejecución de Kubernetes en AWS sin necesidad de instalar, operar y mantener su propio plano de control de Kubernetes. Características principales:

- **Alta disponibilidad**: Los planos de control se ejecutan en múltiples zonas de disponibilidad
- **Seguridad**: Integración con servicios de seguridad de AWS como IAM y VPC
- **Actualizaciones automáticas**: Actualizaciones del plano de control gestionadas por AWS
- **Compatibilidad**: 100% compatible con Kubernetes estándar

### Prometheus

Prometheus es un sistema de monitoreo y alerta de código abierto diseñado para entornos de contenedores:

- **Series temporales**: Almacena datos métricos como series temporales
- **Modelo de datos multidimensional**: Permite etiquetar y filtrar métricas
- **PromQL**: Lenguaje de consulta flexible para analizar datos métricos
- **Arquitectura pull**: Recopila métricas mediante scraping HTTP
- **Alertas**: Permite definir condiciones de alerta basadas en expresiones

### Grafana

Grafana es una plataforma de visualización y análisis para métricas:

- **Paneles interactivos**: Visualización flexible de datos
- **Soporte para múltiples fuentes de datos**: Compatible con Prometheus, InfluxDB, etc.
- **Alertas visuales**: Detección y notificación de condiciones anómalas
- **Anotaciones**: Permite marcar eventos en las gráficas
- **Dashboards predefinidos**: Biblioteca extensa de dashboards comunitarios

### Kube State Metrics

Kube State Metrics es un servicio que escucha al servidor API de Kubernetes y genera métricas sobre el estado de objetos de Kubernetes:

- **Objetos monitoreados**: Pods, deployments, nodos, etc.
- **Métricas de recursos**: CPU, memoria, almacenamiento
- **Estado operacional**: Disponibilidad, estado de salud, etc.

## Guía de Implementación

### 1. Preparación del Entorno

El proyecto puede ejecutarse desde dos entornos:

#### Opción A: Desde tu máquina local

Asegúrate de tener instaladas las siguientes herramientas:
- AWS CLI configurado con credenciales
- kubectl
- eksctl
- Helm

#### Opción B: Desde una instancia EC2 (recomendado)

Esta opción proporciona un entorno consistente y evita problemas de red o configuración local.

```bash
# Crear la instancia EC2 bastión
./infrastructure/create-bastion.sh

# Transferir archivos a la instancia
./infrastructure/transfer-to-ec2.sh ./keys/devops-bastion-key.pem IP-PUBLICA-EC2
```

### 2. Despliegue del Cluster EKS

```bash
./scripts/deploy-eks-cluster.sh
```

Este script:
- Crea un cluster EKS en la región us-east-1
- Configura un nodegroup con instancias t3.small
- Establece la red y las políticas de seguridad
- Configura kubeconfig para acceder al cluster

### 3. Despliegue de Nginx

```bash
./scripts/deploy-nginx.sh
```

Este script:
- Crea un namespace "apps"
- Despliega pods de Nginx con recursos definidos
- Configura un servicio LoadBalancer para acceder a Nginx

### 4. Instalación de Prometheus y Grafana

```bash
./scripts/install-monitoring.sh
```

Este script:
- Crea un namespace "monitoring"
- Instala Prometheus usando Helm
- Instala Grafana usando Helm
- Configura Grafana para usar Prometheus como fuente de datos
- Importa dashboards predefinidos (IDs: 3119, 6417)

### 5. Instalación de Kube State Metrics (si es necesario)

Si necesitas reinstalar o configurar manualmente kube-state-metrics:

```bash
./scripts/install-kube-state-metrics.sh
```

Este script:
- Elimina la instalación existente de kube-state-metrics
- Crea un archivo de configuración personalizado
- Instala kube-state-metrics como un chart independiente
- Configura métricas adicionales para mejorar la visibilidad

### 6. Despliegue completo

Para ejecutar todos los pasos anteriores en secuencia:

```bash
./scripts/deploy-all.sh
```

### 7. Acceso a los Servicios

Después de la instalación, puedes acceder a:

**Nginx**:
```bash
kubectl -n apps get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Grafana**:
```bash
kubectl -n monitoring get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
- Usuario: admin
- Contraseña: EKS!sAWSome

**Prometheus**:

Hay varias formas de acceder a Prometheus:

1. **Port-forward local** (solo accesible desde la instancia EC2):
   ```bash
   kubectl -n monitoring port-forward svc/prometheus-server 9090:80
   ```
   Luego accede a `http://localhost:9090` (solo dentro de la instancia)

2. **Port-forward con acceso externo**:
   ```bash
   kubectl -n monitoring port-forward svc/prometheus-server 9090:80 --address 0.0.0.0
   ```
   Luego accede a `http://<IP-PUBLICA-EC2>:9090` desde tu máquina local.
   
   Asegúrate de que el grupo de seguridad de EC2 tenga abierto el puerto 9090.

3. **Túnel SSH** (desde tu máquina local):
   ```bash
   ssh -i keys/devops-bastion-key.pem -L 9090:localhost:9090 ec2-user@<IP-PUBLICA-EC2>
   ```
   
   En la sesión SSH, ejecuta:
   ```bash
   kubectl -n monitoring port-forward svc/prometheus-server 9090:80
   ```
   
   Luego accede a `http://localhost:9090` en tu máquina local.

4. **Mediante LoadBalancer** (solución permanente):
   ```bash
   kubectl patch svc prometheus-server -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
   ```
   
   Obtén la URL:
   ```bash
   kubectl -n monitoring get svc prometheus-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
   
   Accede usando la URL del LoadBalancer (tiene un costo adicional en AWS).

### 8. Limpieza de Recursos

Cuando termines, puedes eliminar todos los recursos:

```bash
./scripts/cleanup-resources.sh
```

## Solución de Problemas Comunes

### Métricas no aparecen en Grafana

Si los dashboards muestran "N/A" o no tienen datos:

1. **Verificar kube-state-metrics**:
   ```bash
   kubectl -n monitoring get pods | grep kube-state-metrics
   ```

2. **Verificar métricas disponibles**:
   ```bash
   kubectl -n monitoring port-forward svc/kube-state-metrics 8080:8080
   curl localhost:8080/metrics | grep kube_pod_container_resource
   ```

3. **Instalar kube-state-metrics independiente** si es necesario:
   ```bash
   ./scripts/install-kube-state-metrics.sh
   ```

### Problemas con EBS CSI Driver

Si encuentras errores relacionados con almacenamiento persistente:

1. Verifica el estado del driver:
   ```bash
   kubectl get pods -n kube-system | grep ebs-csi
   ```

2. Asegúrate de que el rol IAM apropiado está configurado:
   ```bash
   eksctl create addon --name aws-ebs-csi-driver --cluster eks-cluster-devops --service-account-role-arn arn:aws:iam::<cuenta-aws>:role/AmazonEKS_EBS_CSI_DriverRole --force
   ```

### Problemas de conexión con servicios

Si no puedes acceder a Prometheus o Grafana:

1. Verifica que los servicios están en ejecución:
   ```bash
   kubectl -n monitoring get svc
   ```

2. Comprueba las reglas de seguridad de la instancia EC2:
   ```bash
   aws ec2 describe-security-groups --group-ids $(aws ec2 describe-instances --instance-ids <tu-instancia-id> --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" --output text)
   ```

3. Añade reglas de entrada si es necesario:
   ```bash
   aws ec2 authorize-security-group-ingress --group-id <group-id> --protocol tcp --port 9090 --cidr 0.0.0.0/0
   ```

## Conceptos Clave

### Kubernetes

Kubernetes es una plataforma de orquestación de contenedores que automatiza el despliegue, escalado y gestión de aplicaciones en contenedores. Proporciona:

- **Descubrimiento de servicios**: Localización automática de componentes
- **Balanceo de carga**: Distribución de tráfico entre pods
- **Auto-escalado**: Ajuste dinámico de recursos según demanda
- **Auto-reparación**: Reemplazo automático de pods con fallos
- **Despliegue progresivo**: Estrategias de actualización sin tiempo de inactividad

### Helm

Helm es un gestor de paquetes para Kubernetes que simplifica el despliegue de aplicaciones:

- **Charts**: Paquetes predefinidos para desplegar aplicaciones
- **Releases**: Instancias de charts desplegadas en un cluster
- **Repositorios**: Colecciones de charts disponibles para instalar
- **Values**: Configuración personalizable para los charts
- **Templates**: Plantillas de manifiestos de Kubernetes

### DevOps

DevOps es una filosofía que combina desarrollo y operaciones para mejorar la entrega de software:

- **Integración Continua (CI)**: Integración frecuente de código
- **Entrega Continua (CD)**: Automatización del proceso de entrega
- **Infraestructura como Código (IaC)**: Gestión de infraestructura mediante código
- **Monitoreo continuo**: Observabilidad constante de sistemas
- **Retroalimentación rápida**: Detección temprana de problemas

## Referencias y Recursos Adicionales

- [Documentación de EKS](https://docs.aws.amazon.com/eks/)
- [Documentación de Prometheus](https://prometheus.io/docs/)
- [Documentación de Grafana](https://grafana.com/docs/)
- [Kubernetes Dashboard IDs para Grafana](https://grafana.com/grafana/dashboards/?search=kubernetes)
- [Repositorio de kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)

---

Este proyecto fue desarrollado como parte de una certificación universitaria en DevOps.