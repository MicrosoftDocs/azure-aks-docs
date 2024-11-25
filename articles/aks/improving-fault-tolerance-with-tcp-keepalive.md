---
title: Improving network fault tolerance in Azure Kubernetes Service using TCP keepalive
titleSuffix: Azure Kubernetes Service
description: Learn how to use TCP keepalive to enhance network fault tolerance in cloud applications hosted in Azure Kubernetes Service.
ms.topic: conceptual
ms.author: rhulrai
author: rahulrai-in
ms.subservice: aks-networking
ms.date: 10/30/2024
---

# Improving network fault tolerance in Azure Kubernetes Service using TCP keepalive

In a standard Transmission Control Protocol (TCP) connection, no data flows between the peers when the connection is idle. Therefore, applications or API requests that use TCP to communicate with servers handling long-running requests might have to rely on connection timeouts to become aware of the termination or loss of connection. This article illustrates the use of TCP keepalive to enhance fault tolerance in applications hosted in Azure Kubernetes Service (AKS).

## Understanding TCP keepalive

Several Azure Networking services, such as Azure Load Balancer (ALB), enable you to [configure a timeout period](/azure/load-balancer/load-balancer-tcp-reset) after which an idle TCP connection is terminated. When a TCP connection remains idle for longer than the timeout duration configured on the networking service, any subsequent TCP packets sent in either direction might be dropped. Alternatively, they might receive a TCP Reset (RST) packet from the network service, depending on whether TCP resets were enabled on the service.

The idle timeout feature in an ALB is designed optimize resource utilization for both client and server applications. This timeout applies to both ingress and egress traffic managed by the ALB. When the timeout occurs, the client and server applications can stop processing the request and release resources associated with the connection. These resources can then be reused for other requests, improving the overall performance of the applications.

In AKS, the TCP Reset on idle is enabled on the Load Balancer by default with an idle timeout period of 30 minutes. You can adjust this timeout period with the [`az aks update`](/cli/azure/aks#az_aks_update) command. The following example sets the timeout period to 45 minutes.

```azurecli-interactive
az aks update \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --load-balancer-idle-timeout 45
```

Make sure you consider the timeout duration carefully before adjusting it:
- A duration that's too short can cause long-running operations to terminate prematurely, resulting in failed requests, and a poor user experience. It can also lead to frequent timeouts that increase error rates and making your applications seem unreliable. 
- A duration that's too long can drain server resources by keeping idle connections open, reducing the capacity available for handling new requests. It can also delay the detection of server issues, leading to longer downtimes and inefficient load balancing.

In AKS, apart from the north-south traffic (ingress and egress) that traverse the ALB, you also have the east-west traffic (pod to pod) that generally operates on the cluster network. The timeout period in such cases is defined by the `kube-proxy` TCP settings and the pod's TCP sysctl settings. By default, `kube-proxy` runs in iptables mode and it uses the default TCP timeout settings defined in the [kube-proxy specification](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/). The default TCP timeout settings for `kube-proxy` are as follows:

1. Network Address Translation (NAT) timeout for TCP connections in the `CLOSE_WAIT` state is 1 hour.
2. Idle timeout for established TCP connections is 24 hours.

For certain long-running operations, where client and server are both inside the AKS cluster or if one of them is outside, you may need a timeout longer than the duration configured for networking services like the Azure Load Balancer, or Azure NAT Gateway. To prevent the connection from staying idle beyond the configured duration on the network service, consider using the TCP keepalive feature. This feature keeps both the server and client available while waiting for responses, allowing you to retry operations instead of experiencing connection timeouts.

In a TCP connection, either of the peers can request keepalives for their side of the connection. Keepalives can be configured for the client, the server, both, or neither. The keepalive mechanism follows the standard specifications defined in [RFC1122](https://datatracker.ietf.org/doc/html/rfc1122#section-4.2.3.6). A keepalive probe is either an empty segment or a segment that contains only 1 byte. It features a sequence number that is one less than the largest acknowledgment (ACK) number received from the peer so far. The probe packet mimics a packet that was received. In response, the receiving side sends another ACK packet. This indicates to the sender that the connection is still active.

The RFC1122 specification states that if either the probe or the ACK is lost, they aren't retransmitted. Therefore, if there's no response to a single keepalive probe, it doesn't necessarily mean that the connection stopped working. In this case, the sender must attempt to send the probe a few more times before terminating the connection. The idle time of the connection resets when an ACK is received for a probe, and the process is then repeated. Keepalive probes enable you to configure the following parameters to govern their behavior. In AKS, Linux-based nodes have the following default TCP keepalive settings which are the same as standard Linux Operating Systems:

- **Keepalive Time (in seconds)**: The duration of inactivity after which the first keepalive probe is sent. The default duration 7200 seconds or 2 hours.
- **Keepalive Interval  (in seconds)**: The interval between subsequent keepalive probes if no acknowledgment is received. The default interval is 75 seconds.
- **Keepalive Probes**: The maximum number of unacknowledged probes before the connection is considered unusable. The default value is 9.

Keepalive probes are managed at the TCP layer. When enabled, the probes can result in the following outcomes for the requestor application:

- **Normal Operations**: Keepalive probes don't affect the requestor application.
- **Peer Reboot or Crash (Probes Not Acknowledged)**: The application receives a "connection timed out" error.
- **Peer Reboot or Crash (RESET RST Response)**: The application receives a "connection reset by peer" error.
- **Network Issues with Peer’s Host**: The application may receive a "connection timed out" or another related error.

The next section explains how to change the sysctl settings for your cluster and application pod to set up TCP keepalive.

## Configuring TCP keepalive on AKS

AKS allows cluster administrators to adjust the operating system of a node, and kubelet parameters, to align with the requirements of their workloads. When setting up the cluster or a new node pool, administrators can enable sysctls relevant to their workloads. Kubernetes categorizes the sysctls into two groups: **safe** and **unsafe**. 

Safe sysctls are the ones that are namespaced and properly isolated between pods on the same node. This isolation means that configuring a safe sysctl for one pod doesn't affect other pods on the node, the node's health, or allow a pod to exceed its CPU or memory resource limits. Kubernetes enables the safe sysctls by default. As of Kubernetes 1.29, all TCP keepalive sysctls are considered safe:

- `net.ipv4.tcp_keepalive_time` 
- `net.ipv4.tcp_fin_timeout`
- `net.ipv4.tcp_keepalive_intvl`
- `net.ipv4.tcp_keepalive_probes` 

To learn more about safe and unsafe sysctls and their configuration, see [Customize node configuration for Azure Kubernetes Service (AKS) node pools](custom-node-configuration.md).

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

- `net.ipv4.tcp_keepalive_time` configures keepalive probes to be sent out after 45 seconds of inactivity on the connection.
- `net.ipv4.tcp_keepalive_probes` configures the operating system to send 5 unacknowledged keepalive probes before deeming the connection as unusable.
- `net.ipv4.tcp_keepalive_intvl` sets the duration between dispatch of two keepalive probes to 45 seconds.

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

The TCP client application should enable TCP keepalive so that keepalive probes are sent to the server. Most programming languages and frameworks provide options to enable TCP keepalive on socket connections. The following example uses Python's `socket` library:

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

In this example:
- The application enables TCP keepalive.
- The keepalive probes are sent after 60 seconds of inactivity.
- The keepalive probes are sent at intervals of 10 seconds.
- If 5 consecutive probes fail, the connection closes.

> [!NOTE]
> Note that any system-level TCP keepalive configuration set via `sysctl` in the kubelet are overridden by an application's TCP keepalive settings. To maintain consistent keepalive behavior across your applications, set keepalive parameters at the kubelet level. Then, enable the keepalive option on the socket without specifying individual parameters within the application so the system-level keepalive parameters are used for the application. Only allow individual applications to override the system-level parameter values, like in the previous example, when absolutely necessary.

If you're using .NET, the following code produces the same result as the previous Python example:

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
For more information, see the [ConnectCallback handler](/dotnet/api/system.net.http.socketshttphandler.connectcallback).

## HTTP/2 keepalive

If you use HTTP/2 based communication protocols, such as gRPC, the TCP keepalive settings don't affect your applications. HTTP/2 follows the [RFC7540 specifications](https://httpwg.org/specs/rfc7540.html), which mandates that the client sends a PING frame to the server and that the server immediately replies with a PING ACK frame. HTTP/2 operates at layer 7 of the network stack and benefits from the data delivery guarantees provided by TCP, which operates at layer 4. Since every HTTP/2 request is guaranteed a response, the only keepalive configuration necessary for HTTP/2 transport is the timeout setting. If the PING ACK isn't received before the configured timeout period, the connection is disconnected.

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

## Best practices

While keepalive probes can improve the fault tolerance of your applications, they can also consume more bandwidth, which might impact network capacity and lead to extra charges. Additionally, on mobile devices, increased network activity may affect battery life. Therefore, it's important to adhere to the following best practices:

- **Customize parameters**: Adjust keepalive settings based on application requirements and network conditions.
- **Application-Level keepalives**: For encrypted connections (for example, TLS/SSL), consider implementing keepalive mechanisms at the application layer to ensure probes are sent over secure channels.
- **Monitoring and logging**: Implement logging to monitor keepalive-induced connection closures for troubleshooting.
- **Fallback mechanisms**: Design applications to handle disconnections gracefully, including retry logic and failover strategies.


