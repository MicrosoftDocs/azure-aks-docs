---
title: Improving network fault tolerance in Azure Kubernetes Service using TCP keepalive
titleSuffix: Azure Kubernetes Service
description: Learn how to use TCP keepalive to enhance network fault tolerance in cloud applications hosted in Azure Kubernetes Service.
ms.topic: article
ms.author: rhulrai
author: rahulrai-in
ms.subservice: aks-networking
ms.date: 10/30/2024
---

# Improving network fault tolerance in Azure Kubernetes Service using TCP keepalive

In a standard Transmission Control Protocol (TCP) connection, no data flows between the peers when the connection is idle. Therefore, applications or API requests that use TCP to communicate with servers handling long-running requests might have to rely on connection timeouts to become aware of the termination or loss of connection. TCP connection losses can be more prominent in distributed architectures, which are susceptible to infrastructure failures, network disruptions, or unexpected application crashes. This article illustrates the use of TCP keepalive to enhance fault tolerance in applications hosted in Azure Kubernetes Service (AKS).

## Understanding TCP keepalive

Several Azure Networking services, such as Azure Load Balancer (ALB), enable you to [configure a timeout period](/azure/load-balancer/load-balancer-tcp-reset) after which an idle TCP connection is terminated. When a TCP connection remains idle for longer than the timeout duration configured on the networking service, any subsequent TCP packets sent in either direction might be dropped. Alternatively, they might receive a TCP Reset (RST) packet from the network service, depending on whether TCP resets were enabled on the service.

In AKS, the TCP Reset on idle is enabled on the Load Balancer by default with an idle timeout period of 30 minutes. You can adjust this timeout period with the following command that sets it to four minutes:

```azurecli-interactive
az aks update \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --load-balancer-idle-timeout 4
```

The idle timeout feature in an ALB is designed to terminate inactive connections between the client and server after a specified duration, optimizing resource utilization for both client and server applications. This timeout applies to both ingress and egress traffic managed by the ALB. When the timeout occurs, the client and server applications can stop processing the request and release resources associated with the connection. These resources can then be reused for other requests, improving the overall performance of the applications.

In AKS, apart from the north-south traffic (ingress and egress) that traverse the ALB, you also have the east-west traffic (pod to pod) that generally operates on the cluster network. The timeout period in such cases can be managed by configuring the [`kube-proxy` TCP settings](configure-kube-proxy.md). For example, the following `kube-proxy` configuration changes the default TCP timeout period of 15 minutes to 20 minutes when `kube-proxy` is running in IP Virtual Server (IPVS) mode:

```json
{
  "enabled": true,
  "mode": "IPVS",
  "ipvsConfig": {
    "scheduler": "LeastConnection",
    "TCPTimeoutSeconds": 1200,
    "TCPFINTimeoutSeconds": 120,
    "UDPTimeoutSeconds": 300
  }
}
```

When `kube-proxy` operates in iptables mode, it uses the default TCP timeout settings defined in the [kube-proxy specification](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/). The default TCP timeout settings for `kube-proxy` in iptables mode are as follows:

1. Network Address Translation (NAT) timeout for TCP connections in the `CLOSE_WAIT` state is 1 hour.
2. Idle timeout for established TCP connections is 24 hours.

For long-running operations, you might need a timeout longer than the networking service's configured duration, whether the client and server are both inside the AKS cluster or one of them is outside. To prevent the connection from staying idle beyond the configured duration on the network service, consider using the TCP keepalive feature. This feature also ensures that the server is still available while the client waits for a response (or the other way around), so you can retry the operation rather than wait for a connection timeout.

In a TCP connection, either of the peers can request keepalives for their side of the connection. Keepalives can be configured for the client, the server, both, or neither. The keepalive mechanism follows the standard specifications defined in [RFC1122](https://datatracker.ietf.org/doc/html/rfc1122#section-4.2.3.6). A keepalive probe is either an empty segment or a segment that contains only 1 byte. It features a sequence number that is one less than the largest Acknowledgment (ACK) number that has been received from the peer so far. Since the probe packet essentially mimics a packet that has already been received, the receiving side sends another ACK packet in response to indicate to the sender that the connection is still active.

The RFC1122 specification states that if either the probe or the ACK is lost, they aren't retransmitted. Therefore, if there's no response to a single keepalive probe, it doesn't necessarily mean that the connection stopped working. In this case, the sender must attempt to send the probe a few more times before terminating the connection. The idle time of the connection resets when an ACK is received for a probe, and the process is then repeated. Keepalive probes enable you to configure the following parameters to govern their behavior. In AKS, Linux-based nodes have the following default TCP keepalive settings which are the same as standard Linux Operating Systems:

- **Keepalive Time (in seconds)**: The duration of inactivity after which the first keepalive probe is sent. The default duration is 2 hours.
- **Keepalive Interval  (in seconds)**: The interval between subsequent keepalive probes if no acknowledgment is received. The default interval is 75 seconds.
- **Keepalive Probes**: The maximum number of unacknowledged probes before the connection is considered unusable. The default value is 9.

Keepalive probes are managed at the TCP layer. Therefore, during normal operations, they don't affect the requestor application. However, in other cases, if the probes weren't acknowledged due to the peer rebooting or crashing, the application receives a "connection timed out" error. If the peer sends a RESET (RST) response due to a crash, the application receives a "connection reset by peer" error. In the case where the peer's host is up but unreachable from the requestor due to a network error, the application may receive a "connection timed out" or another error.

## Configuring TCP keepalive on AKS

AKS allows cluster administrators to adjust the operating system of a node, and kubelet parameters, to align with the requirements of their workloads. When setting up the cluster or a new node pool, administrators can enable sysctls relevant to their workloads. Kubernetes categorizes the sysctls into two groups: **safe** and **unsafe**. 

Safe sysctls are those that are namespaced and properly isolated between pods on the same node. This means that configuring a safe sysctl for one pod does not affect other pods on the node, affect the node's health, or allow a pod to exceed its CPU or memory resource limits. Kubernetes enables these sysctls by default. As of Kubernetes 1.29, all TCP keepalive sysctls are considered safe:

- `net.ipv4.tcp_keepalive_time` 
- `net.ipv4.tcp_fin_timeout`
- `net.ipv4.tcp_keepalive_intvl`
- `net.ipv4.tcp_keepalive_probes` 

Unsafe sysctls are either not namespaced or not properly isolated between pods. Modifying these parameters can potentially impact the stability and security of the node or other pods. By default, Kubernetes disables unsafe sysctls. To use them, a cluster administrator must explicitly enable specific unsafe sysctls on each node by configuring the kubelet. For example to enable modification of inter-process communication (IPC) message queue settings, create a file named **linuxkubeletconfig.json** with the following contents:

```json
{
    "allowedUnsafeSysctls": [
        "kernel.msg*"
    ]
}
```

Next, create your cluster using the following command, ensuring that the path to the file you created is correct:

```azurecli-interactive
az aks create --name myAKSCluster --resource-group myResourceGroup --kubelet-config ./linuxkubeletconfig.json 
```

You can find more detailed information about the supported configurations for both the node operating system and kubelet in our [prescriptive guidance](custom-node-configuration.md).

> [!NOTE]
> Starting with Kubernetes 1.29, TCP keepalive sysctls are considered safe and are enabled by default. You don't need to enable them explicitly in your cluster.

You can configure TCP keepalive sysctls in your desired pod by setting the security context in your pod definitions as follows:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox-sysctls
spec:
  securityContext:
    sysctls:
      - name: "net.ipv4.tcp_keepalive_time"
        value: "45"
      - name: "net.ipv4.tcp_keepalive_probes"
        value: "5"
      - name: "net.ipv4.tcp_keepalive_intvl"
        value: "45"
  containers:
    - name: busybox
      image: busybox
      command: ["sleep", "3600"]
```

Applying the specification implements the following TCP keepalive behavior:

1. `net.ipv4.tcp_keepalive_time` configures keepalive probes to be sent out after 45 seconds of inactivity on the connection.
2. `net.ipv4.tcp_keepalive_probes` configures the operating system to send five unacknowledged keepalive probes before deeming the connection as unusable.
3. `net.ipv4.tcp_keepalive_intvl` sets the duration between dispatch of two keepalive probes to 45 seconds.

The TCP keepalive sysctls are namespaced in the Linux kernel, which means they can be set individually for each pod on a node. This segregation allows you to configure the keepalive settings through the pod's security context, which applies to all containers in the same pod.

Your pod is now ready to send and respond to keepalive probes. To verify the settings, you can execute the `sysctl` command on the pod as follows:

```shell
kubectl exec -it busybox-sysctls -- sh -c "sysctl net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes"
```

Executing the command should produce the following output:

```text
net.ipv4.tcp_keepalive_time = 45
net.ipv4.tcp_keepalive_intvl = 45
net.ipv4.tcp_keepalive_probes = 5
```

The next section covers how you can ensure that your applications have TCP keepalive enabled on their connections with the client.

## Configuring TCP keepalive in applications

The TCP client application needs to ensure that TCP keepalive is enabled to ensure that it sends keepalive probes to the server. Most programming languages and frameworks provide options to enable TCP keepalive on socket connections. Following is an example using Python's `socket` library:

```python
import socket
import sys

# Create a TCP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Enable TCP keepalive
sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)

# Optional: Set TCP keepalive parameters (Linux specific).
sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPIDLE, 60)    # Idle time before keepalive probes
sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPINTVL, 10)   # Interval between keepalive probes
sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPCNT, 5)      # Number of keepalive probes

# Connect to the server
server_address = ('server.example.com', 12345)
print(f'Connecting to {server_address[0]} port {server_address[1]}')
sock.connect(server_address)

try:
    # Send and receive data
    message = 'This is a test message.'
    print(f'Sending: {message}')
    sock.sendall(message.encode())

    # Wait for a response
    data = sock.recv(1024)
    print(f'Received: {data.decode()}')

finally:
    print('Closing connection')
    sock.close()
```

In this example, the application enables TCP keepalive probes, which are sent to the server after 60 seconds of inactivity. If five consecutive probes fail, the connection is closed. It's important to note that socket-level TCP keepalive settings override system-level configurations set via `sysctl`. Therefore, if you configure the application's TCP keepalive settings, they take effect. To have the application adhere to the system's TCP keepalive configurations, enable the TCP keepalive option on the socket without specifying individual parameters within the application.

> [!NOTE]
> The application-level TCP keepalive settings in the previous code listing override those configured via the kubelet. To maintain consistent TCP keepalive behavior across your applications, set the desired parameters at the operating system level. Allow individual applications to override these defaults only when necessary.

If you're using .NET, the following code produces the same result:

```csharp
static async Task Main()
{
    using SocketsHttpHandler handler = new SocketsHttpHandler();

    handler.ConnectCallback = async (ctx, ct) =>
    {
        var s = new Socket(SocketType.Stream, ProtocolType.Tcp) { NoDelay = true };
        try
        {
            s.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.KeepAlive, true);
            s.SetSocketOption(SocketOptionLevel.Tcp, SocketOptionName.TcpKeepAliveTime,60);
            s.SetSocketOption(SocketOptionLevel.Tcp, SocketOptionName.TcpKeepAliveInterval, 10);
            s.SetSocketOption(SocketOptionLevel.Tcp, SocketOptionName.TcpKeepAliveRetryCount, 5);
            await s.ConnectAsync(ctx.DnsEndPoint, ct);
            return new NetworkStream(s, ownsSocket: true);
        }
        catch
        {
            s.Dispose();
            throw;
        }
    };

    // Create an HttpClient object
    using HttpClient client = new HttpClient(handler);

    // Call asynchronous network methods in a try/catch block to handle exceptions
    try
    {
        HttpResponseMessage response = await client.GetAsync("<service url>");

        response.EnsureSuccessStatusCode();

        string responseBody = await response.Content.ReadAsStringAsync();
        Console.WriteLine($"Read {responseBody.Length} characters");
    }
    catch (HttpRequestException e)
    {
        Console.WriteLine("\nException Caught!");
        Console.WriteLine($"Message: {e.Message} ");
    }
}
```
For more information, see the [`ConnectCallback` handler] (/dotnet/api/system.net.http.socketshttphandler.connectcallback).

Enabling TCP keepalive helps to maintain the connection, especially when the server is placed behind a load balancer and uses NAT for outgoing traffic. In this way, the client can promptly detect server failures and switch to another instance without waiting for a timeout.

## HTTP/2 keepalive

If you use HTTP/2 based communication protocols, such as gRPC, the TCP keepalive settings do not affect your applications. HTTP/2 follows the [RFC7540 specifications](https://httpwg.org/specs/rfc7540.html), which mandates that the client sends a PING frame to the server and that the server immediately replies with a PING ACK frame. Since HTTP/2 transport is reliable as opposed to TCP, the only keepalive configuration necessary in HTTP/2 transport is timeout. If the PING ACK isn't received before the configured timeout period, the connection is disconnected.

When applications use the HTTP/2 transport, the server is responsible for supporting keepalives and defining its behavior. The client's keepalive settings must be compatible with the server's settings. For example, if the client sends the PING frame more frequently than the server allows, the server terminates the connection with an HTTP/2 GOAWAY frame response.

For gRPC applications, the client and the server can customize the following keepalive settings and default values, as described in the [gRPC specification](https://grpc.io/docs/guides/keepalive/):

| Channel Argument                 | Availability      | Description                                                                                                                                              | Client Default     | Server Default     |
| -------------------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------ |
| `KEEPALIVE_TIME`                 | Client and server | The interval in milliseconds between PING frames.                                                                                                        | INT_MAX (Disabled) | 7200000 (2 hours)  |
| `KEEPALIVE_TIMEOUT`              | Client and server | The timeout in milliseconds for a PING frame to be acknowledged. If sender doesn't receive an acknowledgment within this time, it closes the connection. | 20000 (20 seconds) | 20000 (20 seconds) |
| `KEEPALIVE_WITHOUT_CALLS`        | Client            | Determines if it's permissible to send keepalive pings from the client without any outstanding streams.                                                  | 0 (false)          | N/A                |
| `PERMIT_KEEPALIVE_WITHOUT_CALLS` | Server            | Determines if it's permissible to send keepalive pings from the client without any outstanding streams.                                                  | N/A                | 0 (false)          |
| `PERMIT_KEEPALIVE_TIME`          | Server            | Minimum allowed time between a server receiving successive ping frames without sending any data/header frame.                                            | N/A                | 300000 (5 minutes) |
| `MAX_CONNECTION_IDLE`            | Server            | Maximum time that a channel may have no outstanding rpcs, after which the server closes the connection.                                                  | N/A                | INT_MAX (Infinite) |
| `MAX_CONNECTION_AGE`             | Server            | Maximum time that a channel may exist.                                                                                                                   | N/A                | INT_MAX (Infinite) |
| `MAX_CONNECTION_AGE_GRACE`       | Server            | Grace period after the channel reaches its max age.                                                                                                      | N/A                | INT_MAX (Infinite) |

Refer to the programming language-specific examples and documentation listed in the [gRPC specification](https://grpc.io/docs/guides/keepalive/) that demonstrate client and server applications using keepalive.

## Considerations

While keepalive probes can improve the fault tolerance of your applications, they can also consume additional bandwidth, which might impact network capacity and lead to additional charges. Additionally, on mobile devices, increased network activity may affect battery life. Therefore, it's important to adhere to the following best practices:

- **Customize parameters**: Adjust keepalive settings based on application requirements and network conditions.
- **Application-Level keepalives**: For encrypted connections (for example, TLS/SSL), consider implementing keepalive mechanisms at the application layer to ensure probes are sent over secure channels.
- **Monitoring and logging**: Implement logging to monitor keepalive-induced connection closures for troubleshooting.
- **Fallback mechanisms**: Design applications to handle disconnections gracefully, including retry logic and failover strategies.

## See also

