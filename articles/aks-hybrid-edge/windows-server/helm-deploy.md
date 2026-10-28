---
title: Deploy applications with Helm
description: Learn how to use Helm to deploy applications in AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.reviewer: rbaziwane
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how to deploy applications on AKS using Helm.
# Keyword: Helm, Helm chart, Helm deployment

---

# Deploy applications with Helm

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

[Helm](https://helm.sh/) is an open-source packaging tool that helps you install and manage the lifecycle of Kubernetes applications. Similar to Linux package managers, such as **APT** and **Yum**, Helm manages Kubernetes charts, which are packages of pre-configured Kubernetes resources.

This article describes how to use Helm to package and deploy applications on AKS when you're using AKS on Windows Server.

## Before you begin

Verify that you have the following requirements set up:

* A [Kubernetes cluster](setup.md) with at least one Windows or Linux worker node that's up and running.
* You configured your local `kubectl` environment to point to your cluster. You can use the [Get-AksHciCredential](/azure/aks/aksarc/reference/ps/get-akshcicredential) PowerShell command to access your cluster using `kubectl`.
* [Helm v3](https://helm.sh/docs/intro/install/) command line and prerequisites installed.
* An available container registry, such as [DockerHub](https://hub.docker.com/) or [Azure Container Registry](https://azure.microsoft.com/services/container-registry/).

This article uses an ASP.NET Core application as an example. You can download the sample application from [this GitHub repository](https://github.com/baziwane/MyMicroservice).

Since the application is deployed to Kubernetes, the following example is a simple Dockerfile for the project:

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:5.0-alpine AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:5.0-alpine AS build
WORKDIR /src
COPY ["MyMicroservice.csproj", "./"]
RUN dotnet restore "MyMicroservice.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "MyMicroservice.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "MyMicroservice.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MyMicroservice.dll"]
```

## Build and push the sample application to a container registry

Navigate to the application folder and use the Dockerfile to build and push an image using the following command:

```console
docker build -f Dockerfile -t acr.azurecr.io/mymicroservice:0.1.0 .
```

> [!NOTE]
> The period (.) at the end of the command sets the location of the Dockerfile (in this case, the current directory).

This command creates the image `mymicroservice:0.1.0` on the local machine. To verify that the image was successfully created, run `docker images` to confirm:

```output
REPOSITORY              TAG     IMAGE ID       CREATED            SIZE  
acr.azurecr.io/mymicroservice 0.1.0   5be713db571b   About a minute ago 107MB
....
```

Next, push your image to a container registry, such as [DockerHub](https://hub.docker.com/) or [Azure Container Registry](https://azure.microsoft.com/services/container-registry/). In this example, the container image is pushed to Azure Container Registry. For more information, see [Pull images from an ACR to a Kubernetes cluster](/azure/container-registry/container-registry-auth-kubernetes):

```console
docker push acr.azurecr.io/mymicroservice:0.1.0
```

## Create your Helm chart

Now that the sample application is ready, the next step is to generate a Helm chart using the `helm create` command, as follows:

```console
helm create mymicroserviceapp
```

Update **mymicroserviceapp/values.yaml**, as follows:

* Change `image.repository` to `acr.azurecr.io/mymicroservice`.
* Change `service.type` to `NodePort`.

For example:

```yaml
# Default values for webfrontend.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

replicaCount: 1

image:
  repository: acr.azurecr.io/mymicroservice
  pullPolicy: IfNotPresent
...
service:
  type: NodePort
  port: 80
...
```

Navigate to the **mymicroserviceapp/templates/deployment.yaml** file to configure health checks. Kubernetes uses health checks to manage your application deployments. Replace the path to both `liveness` and `readiness` probes with `path: /weatherforecast`, as shown in the following example:

```yaml
...
 livenessProbe:
    httpGet:
      path: /weatherforecast
      port: http
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 1
    failureThreshold: 3
 readinessProbe:
    httpGet:
      path: /weatherforecast
      port: http
    successThreshold: 3
...
```

## Deploy your Helm chart to Kubernetes

Starting from the **charts\mymicroserviceapp** directory in the solution directory, run the following command:

```console
helm upgrade --install mymicroserviceapp . --namespace=local --set mymicroserviceapp.image.tag="0.1.0" 
```

This command creates (or upgrades) an existing release using the name `mymicroserviceapp` in the `local` namespace in the Kubernetes cluster, and produces output similar to this example:

```output
Release "mymicroserviceapp" does not exist. Installing it now.
NAME: mymicroserviceapp
LAST DEPLOYED: Fri Apr  2 08:47:24 2021
NAMESPACE: local
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export NODE_PORT=$(kubectl get --namespace local -o jsonpath="{.spec.ports[0].nodePort}" services mymicroserviceapp)
  export NODE_IP=$(kubectl get nodes --namespace local -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
```

After you deploy the Helm chart, you can check that the resources were correctly deployed by running `kubectl get all -n local`.

The output from running the command is:

```output
NAME                                     READY   STATUS    RESTARTS   AGE
pod/mymicroserviceapp-7849f949df-fwgbn   1/1     Running   0          101s

NAME                        TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/mymicroserviceapp   NodePort   10.100.149.1   <none>        80:30501/TCP   101s

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/mymicroserviceapp   1/1     1            1           101s

NAME                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/mymicroserviceapp-7849f949df   1         1         1       101s
```

## Test your deployment

The application deploys with a service and a node port, so you can call the API from outside the cluster. To make this call, send a request to: http://$NODE_IP:$NODE_PORT:

```console
curl http://10.193.2.103:30501/WeatherForeCast/
```

```output
StatusCode        : 200
StatusDescription : OK
Content           : [{"date":"2021-04-03T15:51:04.795216+00:00","temperatureC":45,"temperatureF":112,"summary":"Balmy"},{"date":"2021-04-04T15:51:04.
                    7952176+00:00","temperatureC":23,"temperatureF":73,"summary":"Cool"},{"...
RawContent        : HTTP/1.1 200 OK
                    Transfer-Encoding: chunked
                    Content-Type: application/json; charset=utf-8
                    Date: Fri, 02 Apr 2021 15:51:04 GMT
                    Server: Kestrel

                    [{"date":"2021-04-03T15:51:04.795216+00:00","tempera...
Forms             : {}
Headers           : {[Transfer-Encoding, chunked], [Content-Type, application/json; charset=utf-8], [Date, Fri, 02 Apr 2021 15:51:04 GMT], [Server,
                    Kestrel]}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : mshtml.HTMLDocumentClass
RawContentLength  : 494
```

## Clean up the cluster

The final step is to clean up the cluster. To delete Kubernetes deployment resources, run the following command:

```console
helm uninstall mymicroserviceapp -n local
```

You should get output similar to the following example:

```output
release "mymicroserviceapp" uninstalled
```

## Next steps

* [Connect your AKS clusters to Azure Arc](./connect-to-arc.md)
