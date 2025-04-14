## Acceso y Gestión del Cluster EKS

### Acceso desde Lens (Interfaz Gráfica de Kubernetes)

[Lens](https://k8slens.dev/) es una potente interfaz gráfica para gestionar clusters de Kubernetes. Para conectar Lens a tu cluster EKS:

1. **Actualiza tu kubeconfig local**:
   ```bash
   aws eks update-kubeconfig --name eks-cluster-devops --region us-east-1
   ```

2. **Configura permisos para tu usuario IAM**:
   Para que tu usuario IAM pueda acceder al cluster EKS, necesitas añadirlo al ConfigMap `aws-auth`. Desde la instancia EC2 (que ya tiene acceso), ejecuta:
   
   ```bash
   # Exportar la configuración actual
   kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth.yaml
   ```
   
   Edita el archivo `aws-auth.yaml` añadiendo tu usuario en la sección `mapUsers`:
   
   ```yaml
   apiVersion: v1
   data:
     mapRoles: |
       - groups:
         - system:bootstrappers
         - system:nodes
         rolearn: arn:aws:iam::123456789012:role/eksctl-eks-cluster-devops-nodegroup-ng-1-NodeInstanceRole-XXXXXXXXXXXX
         username: system:node:{{EC2PrivateDNSName}}
     mapUsers: |
       - userarn: arn:aws:iam::123456789012:user/TuUsuarioIAM
         username: usuario-eks
         groups:
           - system:masters
   kind: ConfigMap
   metadata:
     name: aws-auth
     namespace: kube-system
   ```
   
   Aplica los cambios:
   
   ```bash
   kubectl apply -f aws-auth.yaml
   ```

3. **Abre Lens en tu máquina local** y selecciona "Add Cluster" (o "+" en la interfaz)

4. **Selecciona "From Kubeconfig"** y usa la configuración de `~/.kube/config`

5. **Confirma y conéctate**: El cluster EKS debería aparecer en la lista de Lens y podrás acceder a él

Este método te permite gestionar visualmente tu cluster EKS, ver pods, deployments, services, logs y mucho más desde una interfaz gráfica intuitiva.