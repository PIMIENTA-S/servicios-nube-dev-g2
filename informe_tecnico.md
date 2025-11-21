# Informe Técnico de Infraestructura Cloud

**Proyecto:** Servicios Nube - Piloto Intranet NexaCloud  
**Fecha:** 21 de Noviembre de 2025  
**Entorno:** Desarrollo (`dev`)  
**Región AWS:** us-east-1

---

## 1. Resumen Ejecutivo

Este documento detalla la arquitectura de infraestructura implementada como código (IaC) utilizando Terraform en Amazon Web Services (AWS). La solución despliega una aplicación web escalable y segura, utilizando una arquitectura de tres capas con componentes serverless, balanceo de carga y alta disponibilidad.

La infraestructura está organizada en **6 módulos Terraform**:
- `networking`: VPC, subredes, endpoints y grupos de seguridad
- `storage`: S3 y RDS PostgreSQL
- `compute`: Lambda, EC2, ALB y ASG
- `api`: API Gateway REST
- `monitoring`: CloudWatch Alarms
- `app-config`: SSM Parameter Store

---

## 2. Topología de Red Detallada

### 2.1 Arquitectura de VPC

**CIDR de VPC:** `10.0.0.0/16`

La red está diseñada con **alta disponibilidad Multi-AZ** (us-east-1a, us-east-1b) y segmentación por capas:

#### Subredes Públicas
- **CIDR:** `10.0.1.0/24` (AZ-a), `10.0.2.0/24` (AZ-b)
- **Propósito:** Alojan únicamente el Application Load Balancer (ALB)
- **Conectividad:** Acceso directo a Internet vía **Internet Gateway (IGW)**
- **Componentes:** ALB, NAT Gateway

#### Subredes Privadas (Aplicación)
- **CIDR:** `10.0.101.0/24` (AZ-a), `10.0.102.0/24` (AZ-b)
- **Propósito:** Alojan instancias EC2 y funciones Lambda
- **Conectividad:** Salida a Internet a través de **NAT Gateway** (single NAT en AZ-a para reducir costos)
- **Componentes:** EC2 Auto Scaling Group, Lambda Functions

#### Subredes de Base de Datos
- **CIDR:** `10.0.201.0/24` (AZ-a), `10.0.202.0/24` (AZ-b)
- **Propósito:** Aislamiento de la capa de datos
- **Conectividad:** Sin acceso directo a Internet
- **Componentes:** RDS PostgreSQL (Multi-AZ opcional)

### 2.2 VPC Endpoints (PrivateLink)

Para reducir costos de transferencia de datos y mejorar la seguridad, se utilizan **VPC Endpoints** que permiten conectividad privada a servicios de AWS sin salir a Internet pública:

#### Interface Endpoints (ENI en subredes privadas)
| Servicio | Propósito | Puerto |
|:---------|:----------|:-------|
| `ssm` | AWS Systems Manager para gestión de EC2 | 443 |
| `ssmmessages` | Mensajería de Session Manager | 443 |
| `ec2messages` | Comunicación de agentes EC2 | 443 |
| `logs` | CloudWatch Logs | 443 |
| `secretsmanager` | Secrets Manager | 443 |

**Security Group de Endpoints:** Permite tráfico HTTPS (443) desde cualquier IP dentro de la VPC (`10.0.0.0/16`)

#### Gateway Endpoint
| Servicio | Propósito | Configuración |
|:---------|:----------|:--------------|
| `s3` | Acceso a S3 sin NAT Gateway | Asociado a tablas de rutas privadas |

### 2.3 Flujo de Tráfico

```
Internet → IGW → ALB (Subnets Públicas) → EC2 (Subnets Privadas)
                                         ↓
                                    RDS (Subnets DB)

API Gateway (Regional) → Lambda (Subnets Privadas) → RDS / S3
```

---

## 3. Grupos de Seguridad (Firewall de Red)

Se aplica el **principio de mínimo privilegio** con reglas estrictas de entrada y salida:

### 3.1 SG del Application Load Balancer
**Nombre:** `servicios-nube-dev-alb-sg`

| Dirección | Puerto | Protocolo | Origen/Destino | Descripción |
|:----------|:-------|:----------|:---------------|:------------|
| Inbound | 80 | TCP | `0.0.0.0/0` | HTTP público |
| Inbound | 443 | TCP | `0.0.0.0/0` | HTTPS público |
| Outbound | Todos | Todos | `0.0.0.0/0` | Tráfico de salida |

### 3.2 SG de Instancias EC2 Web
**Nombre:** `servicios-nube-dev-web-sg`

| Dirección | Puerto | Protocolo | Origen/Destino | Descripción |
|:----------|:-------|:----------|:---------------|:------------|
| Inbound | 3000 | TCP | `alb-sg` (referencia) | **Solo** el ALB puede conectarse |
| Outbound | Todos | Todos | `0.0.0.0/0` | Tráfico de salida |

> [!IMPORTANT]
> **Sin puerto SSH (22)**: La gestión se realiza mediante AWS Systems Manager Session Manager a través de VPC Endpoints.

### 3.3 SG de Funciones Lambda
**Nombre:** `servicios-nube-dev-lambda-sg`

| Dirección | Puerto | Protocolo | Origen/Destino | Descripción |
|:----------|:-------|:----------|:---------------|:------------|
| Outbound | Todos | Todos | `0.0.0.0/0` | Acceso a RDS, S3 y servicios AWS |

> [!NOTE]
> Las Lambdas no tienen reglas de entrada (inbound) porque se invocan mediante eventos de API Gateway, no por conexiones de red directas.

### 3.4 SG de RDS PostgreSQL
**Nombre:** `servicios-nube-dev-rds-sg`

| Dirección | Puerto | Protocolo | Origen/Destino | Descripción |
|:----------|:-------|:----------|:---------------|:------------|
| Inbound | 5432 | TCP | `lambda-sg` (referencia) | Acceso desde Lambdas |
| Inbound | 5432 | TCP | `web-sg` (referencia) | Acceso desde EC2 |
| Outbound | Todos | Todos | `0.0.0.0/0` | Tráfico de salida |

**Acceso público:** Deshabilitado (`publicly_accessible = false`)

### 3.5 SG de VPC Endpoints
**Nombre:** `servicios-nube-dev-vpce-sg`

| Dirección | Puerto | Protocolo | Origen/Destino | Descripción |
|:----------|:-------|:----------|:---------------|:------------|
| Inbound | 443 | TCP | `10.0.0.0/16` | HTTPS desde la VPC |
| Outbound | Todos | Todos | `0.0.0.0/0` | Tráfico de salida |

---

## 4. Componentes Desplegados y Configuración

### 4.1 Capa de Computación (Compute)

#### EC2 Auto Scaling Group
**Configuración:**
- **AMI:** Amazon Linux 2023 (x86_64, última versión disponible)
- **Tipo de instancia:** `t3.small` (2 vCPU, 2 GB RAM)
- **Capacidad:** Min=1, Desired=2, Max=5
- **Subredes:** Privadas (10.0.101.0/24, 10.0.102.0/24)
- **Volumen EBS:**
  - Tamaño: 40 GB
  - Tipo: `gp3` (3000 IOPS, 125 MB/s throughput)
  - **Encriptado:** Sí
- **Health Check:** EC2 (basado en estado de instancia)
- **Instance Refresh:** Rolling con 90% de instancias saludables mínimo

**IAM Role:** `servicios-nube-dev-ec2-ssm`
- Política adjunta: `AmazonSSMManagedInstanceCore` (gestión sin SSH)

**User Data:** Script `app.sh` que inicializa la aplicación web en el puerto 3000

#### AWS Lambda Functions
**Runtime:** Python 3.12  
**Arquitectura:** x86_64  
**Timeout:** 30 segundos  
**Memoria:** 256 MB  
**Configuración de VPC:** Desplegadas en subredes privadas con SG `lambda-sg`

##### Lambda: `images-handler`
- **Propósito:** Lista y procesa imágenes desde S3
- **Handler:** `app.handler`
- **Variables de entorno:**
  - `S3_BUCKET`: `servicios-nube-dev-images-pimienta`
  - `S3_PREFIX`: `images`
- **Permisos IAM:**
  - `s3:ListBucket` en el bucket
  - `s3:GetObject` en objetos del bucket
- **CloudWatch Logs:** `/aws/lambda/servicios-nube-dev-images-handler` (14 días retención)

##### Lambda: `students-writer`
- **Propósito:** Registra información de estudiantes en RDS
- **Handler:** `app.handler`
- **Variables de entorno:** Configurables vía `students_env`
- **Permisos IAM:** Acceso a VPC y CloudWatch Logs
- **CloudWatch Logs:** `/aws/lambda/servicios-nube-dev-students-writer` (14 días retención)

##### Lambda: `db-init`
- **Propósito:** Inicialización del esquema de base de datos
- **Handler:** `app.handler`
- **Variables de entorno:** Configurables vía `db_init_env`
- **CloudWatch Logs:** `/aws/lambda/servicios-nube-dev-db-init` (14 días retención)

**IAM Role Compartido:** `servicios-nube-dev-lambda-exec`
- `AWSLambdaBasicExecutionRole` (CloudWatch Logs)
- `AWSLambdaVPCAccessExecutionRole` (ENIs en VPC)
- Política inline para S3

#### Application Load Balancer
**Nombre:** `servicios-nube-dev-alb`  
**Tipo:** Application Load Balancer  
**Esquema:** Internet-facing  
**Subredes:** Públicas (10.0.1.0/24, 10.0.2.0/24)

**Target Group:**
- **Nombre:** `servicios-nube-dev-tg`
- **Puerto:** 3000
- **Protocolo:** HTTP
- **Health Check:**
  - Path: `/`
  - Matcher: `200`
  - Intervalo: 30s
  - Timeout: 5s
  - Healthy threshold: 2
  - Unhealthy threshold: 3

**Listener:**
- Puerto 80 (HTTP) → Forward a Target Group

### 4.2 Capa de Almacenamiento (Storage)

#### Amazon S3
**Bucket:** `servicios-nube-dev-images-pimienta`

**Configuración de seguridad:**
- **Bloqueo de acceso público:** Habilitado (todas las opciones)
- **Ownership:** BucketOwnerEnforced
- **Encriptación:** SSE-S3 (AES-256) por defecto
- **Versionado:** Habilitado
- **Política de bucket:** Deniega conexiones no TLS (`aws:SecureTransport = false`)

**Lifecycle Rules:**
| Regla | Días | Acción |
|:------|:-----|:-------|
| Versiones antiguas | 30 | Transición a `STANDARD_IA` |
| Versiones antiguas | 90 | Transición a `GLACIER_IR` |
| Versiones antiguas | 180 | Expiración (eliminación) |

#### Amazon RDS PostgreSQL
**Identificador:** `servicios-nube-dev`

**Configuración de motor:**
- **Motor:** PostgreSQL 16.3
- **Clase de instancia:** `db.t4g.micro` (Graviton2, 2 vCPU, 1 GB RAM)
- **Multi-AZ:** Deshabilitado (dev)
- **Nombre de BD:** `appdb`
- **Usuario maestro:** `appuser`
- **Puerto:** 5432

**Almacenamiento:**
- **Tipo:** `gp3` (SSD de propósito general)
- **Tamaño inicial:** 20 GB
- **Auto-scaling:** Hasta 100 GB
- **Encriptado:** Sí

**Respaldos:**
- **Retención:** 7 días
- **Ventana de respaldo:** Automática
- **Skip final snapshot:** Habilitado (dev)

**Logs exportados a CloudWatch:** `postgresql`

**Subnet Group:** Subredes de base de datos (10.0.201.0/24, 10.0.202.0/24)

**Acceso público:** Deshabilitado

### 4.3 Capa de API (API Gateway)

**Nombre:** `servicios-nube-dev-api`  
**Tipo:** REST API  
**Endpoint:** Regional  
**Autenticación:** API Key (header `x-api-key`)

#### Recursos y Métodos

| Recurso | Método | Integración | Autenticación |
|:--------|:-------|:------------|:--------------|
| `/images` | GET | Lambda Proxy → `images-handler` | API Key requerida |
| `/students` | POST | Lambda Proxy → `students-writer` | API Key requerida |

**Stage:** `prod`

**Logging:**
- **Destination:** CloudWatch Log Group `/apigw/servicios-nube-dev`
- **Formato:** JSON con requestId, IP, método, recurso, status
- **Retención:** 14 días

**API Key:**
- **Nombre:** `servicios-nube-dev-api-key`
- **Estado:** Habilitado
- **Usage Plan:** `servicios-nube-dev-plan` (sin límites de throttling configurados)

**Permisos Lambda:**
- `AllowAPIGWInvokeImages`: Permite a API Gateway invocar `images-handler`
- `AllowAPIGWInvokeStudents`: Permite a API Gateway invocar `students-writer`

### 4.4 Monitoreo (CloudWatch)

#### Alarmas Configuradas

| Alarma | Métrica | Threshold | Período | Evaluaciones |
|:-------|:--------|:----------|:--------|:-------------|
| `rds-free-storage` | RDS FreeStorageSpace | < 2 GB | 5 min | 2 |
| `alb-5xx` | ALB HTTPCode_ELB_5XX_Count | > 5 | 1 min | 1 |
| `apigw-5xx` | API Gateway 5XXError | > 1 | 1 min | 1 |

**Acción:** Sin acciones configuradas (solo alarma)

#### Log Groups
- `/aws/lambda/servicios-nube-dev-images-handler`
- `/aws/lambda/servicios-nube-dev-students-writer`
- `/aws/lambda/servicios-nube-dev-db-init`
- `/apigw/servicios-nube-dev`
- RDS logs exportados automáticamente

---

## 5. Gestión de Credenciales y Secretos

### 5.1 Contraseña de RDS

**Generación:**
- Contraseña aleatoria de 20 caracteres (sin caracteres especiales)
- Generada por Terraform usando `random_password`

**Almacenamiento:**
- **SSM Parameter Store:** `/{project}/{environment}/db/master_password`
- **Tipo:** `SecureString` (encriptado con KMS por defecto)
- **Acceso:** Solo roles IAM autorizados

### 5.2 API Key de API Gateway

**Generación:**
- Generada automáticamente por AWS API Gateway

**Almacenamiento:**
- **SSM Parameter Store:** `/{project}/{environment}/lambda/s3/apikey` y `/{project}/{environment}/lambda/db/apikey`
- **Tipo:** `SecureString`

### 5.3 Parámetros de Configuración (SSM)

Todos los parámetros se almacenan en SSM Parameter Store bajo el prefijo `/{project}/{environment}/`:

| Parámetro | Tipo | Descripción |
|:----------|:-----|:------------|
| `/db/host` | String | Endpoint de RDS |
| `/db/port` | String | Puerto de RDS (5432) |
| `/db/name` | String | Nombre de la base de datos |
| `/db/user` | String | Usuario de la base de datos |
| `/db/master_password` | SecureString | Contraseña maestra de RDS |
| `/lambda/s3/url` | String | URL del endpoint `/images` |
| `/lambda/db/url` | String | URL del endpoint `/students` |
| `/lambda/s3/apikey` | SecureString | API Key para autenticación |
| `/lambda/db/apikey` | SecureString | API Key para autenticación |
| `/stress/path` | String | Ruta para pruebas de estrés |
| `/alb/url` | String | DNS del ALB |

---

## 6. Endpoints y URLs de Acceso

### 6.1 Endpoints Públicos

| Servicio | URL | Autenticación |
|:---------|:----|:--------------|
| **ALB (Aplicación Web)** | `http://{alb-dns-name}` | Ninguna |
| **API Gateway** | `https://{api-id}.execute-api.us-east-1.amazonaws.com/prod` | API Key |

### 6.2 Endpoints de API

| Endpoint | Método | Función | Header Requerido |
|:---------|:-------|:--------|:-----------------|
| `/images` | GET | Listar imágenes de S3 | `x-api-key: {api-key-value}` |
| `/students` | POST | Registrar estudiante en RDS | `x-api-key: {api-key-value}` |

### 6.3 Endpoints Internos (VPC)

| Servicio | Endpoint | Acceso |
|:---------|:---------|:-------|
| **RDS** | `{identifier}.{random}.us-east-1.rds.amazonaws.com:5432` | Desde Lambda y EC2 |
| **S3 (VPC Endpoint)** | `vpce-{id}.s3.us-east-1.vpce.amazonaws.com` | Desde subredes privadas |

---

## 7. Configuración de Seguridad Adicional

### 7.1 Protección de Datos en Tránsito
- **ALB → EC2:** HTTP interno (dentro de VPC privada)
- **API Gateway → Lambda:** HTTPS (AWS gestionado)
- **Lambda/EC2 → RDS:** PostgreSQL nativo (dentro de VPC)
- **S3:** Política de bucket fuerza TLS 1.2+

### 7.2 Protección de Datos en Reposo
- **EBS (EC2):** Encriptado con KMS por defecto
- **RDS:** Encriptado con KMS por defecto
- **S3:** SSE-S3 (AES-256)
- **SSM Parameters (SecureString):** Encriptado con KMS

### 7.3 Gestión de Acceso (IAM)
- **Principio de mínimo privilegio:** Cada rol tiene solo los permisos necesarios
- **Sin credenciales hardcodeadas:** Todo se gestiona vía IAM Roles
- **Session Manager:** Acceso a EC2 sin SSH keys

### 7.4 Auditoría y Cumplimiento
- **CloudWatch Logs:** Retención de 14 días para auditoría
- **RDS Backups:** 7 días de retención
- **S3 Versioning:** Protección contra eliminación accidental
- **Terraform State:** Almacenado en S3 con encriptación y lockfile

---
