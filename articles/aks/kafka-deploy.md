## Kafka Design 
The Strimzi Operator allows us to declaratively define a Kafka Cluster on AKS. Beginning with Strimzi 0.46, Kafka clusters no longer require ZooKeeper. Instead, Kafka clusters will leverage KRaft. A KRaft Kafka Cluster consists of Kafka brokers, which handle data storage and processing, and Kafka controllers, which manage metadata using the Raft consensus protocol, eliminating the need for ZooKeeper. Strimzi uses a KafkaNodePool customer resource to create the brokers and controllers that will make up the Kafka cluster. KafkaNodePools must be assigned a specific role: broker, controller, or both. For the desired architecture, two KafkaNodePools are defined for broker and controllers, respectively. This setup simplifies the architecture, improves scalability, and enhances fault tolerance. Each broker and controller exists as its own respective set of pods within AKS and can be scaled or changed independently. 


### Zonal Distribution (Rack awareness, Topology spread constraints)
The KafkaNodePools are configured with Topology Spread Constraints so that the resulting pods are evenly distributed across availability zones and AKS nodes. This ensures resiliency in case of an availability zone outage or a node outage. A pod affinity rule with a preferredduringscheduling rule is also configured between broker pods and controller pods. This ensures optimal use of node resources within a given availability zone if cluster autoscaler is enabled.  Otherwise, if a new node is added, there could be a scenario that a broker pod runs on an existing node and the controller pod on the scaled node. 

### KRaft Cluster (No Zookeper)

## Deploy Strimzi Components  
### Strimzi Operator
### Drain Cleaner
### Kafka Exporter


## Deploy Kafka Cluster
### Config Map for Managed Prometheus 
### Pod Monitor for Managed Prometheus
### Kafka Node Pools, Kafka Cluster, Topic/User Operator, and Cruise Control 
### Kafka Rebalance
### Kafka Topic (declaratively create demo topic)


## Accessing the Kafka Cluster
### via ClusterIP
### Via ELB
### Via ILB + Private Endpoint
