---
title: Enhancing Concurrency Control with Entity Tags (eTags) in Azure Kubernetes Service
description: Learn how to use eTags (Entity Tags) to enable concurrency control and avoid racing conditions or overwriting scenarios. 
ms.topic: how-to
ms.date: 06/10/2024
author: schaffererin
ms.author: schaffererin
ms.custom: aks, etag, concurrency-control
ms.subservice: aks-nodes
# Customer intent: As a cloud engineer, I want to implement eTags for entity-level concurrency control in Azure Kubernetes Service, so that I can prevent conflicting requests and ensure data integrity during resource updates.
---

# Enhance concurrency control with entity tags (eTags) in Azure Kubernetes Service 

To prevent conflicting requests in Azure Kubernetes Service (AKS), eTags (Entity Tags) serve as unique identifiers that enable concurrency control. When a request to the cluster is made, the system checks whether the provided eTag matches the latest version stored in the database. If there is a mismatch, the request fails early, ensuring that no unintended overwrites occur.

## Utilizing eTag Headers

There are two options for applying eTags through headers:

**`–-if-match`** Header: Ensures that the operation is performed only if the existing eTag matches the value provided in this header.

**`–-if-none-match`** Header: Ensures that the operation is performed only if none of the eTags matches the value provided in this header. This header type can only be empty or a `*`. 

### Find existing ETags

You can do either a `LIST` or a `GET` call to your cluster or node pool to see the existing ETag. An ETag looks something like the following example:
```
"agentPoolProfiles": [
    {"eTag": "5e5ffdce-356b-431b-b050-81b45eef2a12"}
]
```

### What would modify existing ETags

ETags can exist at both the cluster and agent pool levels. Depending on the scope of the operations you are performing, you can pass in the corresponding eTag. When you perform a cluster-level operation, both the cluster-level eTag and agent pool eTag are updated. When you perform an agent pool operation, only the agent pool eTag is updated.

### Include ETags in operation headers

Headers are optional to use. The following examples show how to use `–-if-match` and `-–if-none-match` headers. 

**Example 1**: The CLI command below deletes an existing cluster `MyManagedCluster` if the eTag matches with `yvjvt`

Suppose you want to delete an AKS cluster using its eTag. (For illustration, replace `"yvjvt"` with the actual eTag value you retrieved from the resource.)

```shell
az aks delete -g $RG_NAME -n $CLUSTER_NAME --if-match "yvjvt"
```

**Example 2**: The CLI command below creates a new cluster. If `*` is provided in the `–if-none-match` header, that means to validate the resource does not exist.

First, create a resource group:

```azurecli
export RANDOM_SUFFIX=$(head -c 3 /dev/urandom | xxd -p)
export RG_NAME="my-resource-group$RANDOM_SUFFIX"
export REGION="eastus2"

az group create --name $RG_NAME --location $REGION 
```

Then, create a new AKS cluster with a random suffix to ensure uniqueness:

```azurecli
export CLUSTER_NAME="my-managed-cluster$RANDOM_SUFFIX"

az aks create -g $RG_NAME -n $CLUSTER_NAME --location $REGION --if-none-match "*"
```

Results: 

<!-- expected_similarity=0.3 --> 

```output
{
  "aadProfile": null,
  "addonProfiles": null,
  "agentPoolProfiles": [
    {
      "eTag": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      ...
    }
  ],
  "apiServerAccessProfile": null,
  "autoScalerProfile": null,
  ...
  "name": "my-managed-clusterxxx",
  ...
  "provisioningState": "Succeeded",
  ...
  "resourceGroup": "my-resource-groupxxx",
  ...
}
```

### Configurations and Expected Behavior

The table below outlines the expected behavior of HTTP operations (PUT, PATCH, and DELETE) based on different eTag configurations and resource existence. They show how the presence of `--if-match` or `--if-none-match` headers affects the response status codes, ensuring concurrency control and preventing unintended modifications.


**PUT** | **Resource does not exist** | **Resource exists**
--- | --- | ---
**`--if-match = ""`** | 201 – Created | 200 - Ok
**`--if-match = "*"`** | 412 - Precondition Failed | 200 - OK
**`--if-match = "xyz"`** | 412 - Precondition Failed | 200 - OK OR 412 - Precondition Failed
**`--if-none-match = "*"`** | 201 - Created | 412 - Precondition Failed


**PATCH** | **Resource does not exist** | **Resource exists**
--- | --- | ---
**`--if-match = ""`** | 404 - Not Found | 200 - OK
**`--if-match = "*"`** | 404 - Not Found | 200 - OK
**`--if-match = "xyz"`** | 404 - Not Found | 200 - OK OR 412 - Precondition Failed


**DELETE** | **Resource does not exist** | **Resource exists**
--- | --- | ---
**`--if-match = ""`** | 204 - No Content | 200 - OK
**`--if-match = "*"`** | 204 - No Content | 200 - OK
**`--if-match = "xyz"`** | 204 - No Content | 200 - OK OR 412 - Precondition Failed

## Common Issues and Recommended Mitigations

### **Scenario 1**: `BadRequest` – `--if-none-match` header is not empty or not set to `*`

This fails the prevalidation checks. The `--if-none-match` header can only be empty or take a value of `*`. 

### **Scenario 2**: `BadRequest`  - `--if-match` header is not empty AND `--if-none-match` header is  `*`

This fails the prevalidation checks. Both headers cannot be used at the same time. 

### **Scenario 3**: `PreConditionFailed` - `--if-none-match` is `*` and the given resource already exists

The request is rejected if a  `*` (wildcard of any) value is passed into `--if-none-match` header and the resource already exists. 

### **Scenario 4**: `PreConditionFailed`  - The value of `--if-match` header does not match the latest eTag value of the resource

The request is rejected if the header provided does not match with the eTag value. A new GET operation is needed to get the latest eTag on the resource and update the header value in the request. 