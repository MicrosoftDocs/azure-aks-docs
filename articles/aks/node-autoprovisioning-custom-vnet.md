## Node auto provisioning Metrics
You can enable [control plane metrics (Preview)](./monitor-control-plane-metrics.md) to see the logs and operations from [node auto provisioning](./control-plane-metrics-default-list.md#minimal-ingestion-for-default-off-targets) with the [Azure Monitor managed service for Prometheus add-on](/azure/azure-monitor/essentials/prometheus-metrics-overview)

## Monitoring selection events

Node auto provisioning produces cluster events that can be used to monitor deployment and scheduling decisions being made. You can view events through the Kubernetes events stream.

```
kubectl get events -A --field-selector source=karpenter -w
```


## Custom Virtual Networks and node autoprovisioning

AKS allows you to add a cluster with node autoprovisioning enabled in a custom virtual network via the `--vnet-subnet-id` parameter. The following sections detail how to:

- Create a virtual network
- Create a managed identity with permissions over the virtual network  
- Create a node autoprovisioning-enabled cluster in a custom virtual network 

### Create a virtual network

Create a virtual network using the [`az network vnet create`][az-network-vnet-create] command. Create a cluster subnet using the [`az network vnet subnet create`][az-network-vnet-subnet-create] command.

When using a custom virtual network with node autoprovisioning, you must create and delegate an API server subnet to `Microsoft.ContainerService/managedClusters`, which grants the AKS service permissions to inject the API server pods and internal load balancer into that subnet. You can't use the subnet for any other workloads, but you can use it for multiple AKS clusters located in the same virtual network. The minimum supported API server subnet size is a */28*.

```azurecli-interactive
az network vnet create --name ${VNET_NAME} \
--resource-group ${RG_NAME} \
--location ${LOCATION} \
--address-prefixes 172.19.0.0/16

az network vnet subnet create --resource-group ${RG_NAME} \
--vnet-name ${VNET_NAME} \
--name clusterSubnet \
--delegations Microsoft.ContainerService/managedClusters \
--address-prefixes 172.19.0.0/28
```

All traffic within the virtual network is allowed by default. But if you added Network Security Group (NSG) rules to restrict traffic between different subnets, see our [Network Security Group documentation][network-security-group] for the proper permissions.  

### Create a managed identity and give it permissions on the virtual network

Create a managed identity using the [`az identity create`][az-identity-create] command and retrieve the principal ID. Assign the **Network Contributor** role on virtual network to the managed identity using the [`az role assignment create`][az-role-assignment-create] command.

```azurecli-interactive
az identity create --resource-group ${RG_NAME} \
--name ${IDENTITY_NAME} \
--location ${LOCATION}
IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group ${RG_NAME} --name ${IDENTITY_NAME} \
--query principalId -o tsv)

az role assignment create --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}" \
--role "Network Contributor" \
--assignee ${IDENTITY_PRINCIPAL_ID}
```

### Create an AKS cluster in a custom virtual network and with node autoprovisioning enabled

In the following command, an Azure Kubernetes Service (AKS) cluster is created as part of a custom virtual network using the [az aks create][az-aks-create] command. To create a customer virtual network

```azurecli-interactive
        az aks create --name $(AZURE_CLUSTER_NAME) --resource-group $(AZURE_RESOURCE_GROUP) \
            --enable-managed-identity --generate-ssh-keys -o none --network-dataplane cilium --network-plugin azure --network-plugin-mode overlay \
            --vnet-subnet-id "/subscriptions/$(AZURE_SUBSCRIPTION_ID)/resourceGroups/$(AZURE_RESOURCE_GROUP)/providers/Microsoft.Network/virtualNetworks/$(CUSTOM_VNET_NAME)/subnets/$(CUSTOM_SUBNET_NAME)" \
            --node-provisioning-mode Auto
```

```azurecli-interactive
az aks create --resource-group ${RG_NAME} \
--name ${CLUSTER_NAME} \
--location ${LOCATION} \
--vnet-subnet-id "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/clusterSubnet" \
--assign-identity "/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${RG_NAME}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}" \
--node-provisioning-mode Auto
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster.

Configure `kubectl` to connect to your Kubernetes cluster using the [az aks get-credentials][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

```azurecli-interactive
az aks get-credentials --resource-group ${RG_NAME} --name ${CLUSTER_NAME}
```

Verify the connection to your cluster using the [kubectl get][kubectl-get] command. This command returns a list of the cluster nodes.

```bash
kubectl get nodes
```

<!-- LINKS -->
[az-network-vnet-create]: /cli/azure/network/vnet#az-network-vnet-create
[az-network-vnet-subnet-create]: /cli/azure/network/vnet/subnet#az-network-vnet-subnet-create
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[network-security-group]: /azure/virtual-network/network-security-groups-overview
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get