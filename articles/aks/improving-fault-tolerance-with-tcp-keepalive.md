---
title: Improving fault tolerance in Azure Kubernetes Service using TCP keepalive
titleSuffix: Azure Kubernetes Service
description: Learn how to use TCP keepalive to enhance fault tolerance in cloud applications hosted in Azure Kubernetes Service.
ms.topic: article
ms.author: rhulrai
author: rahulrai-in
ms.subservice: aks-networking
ms.date: 10/30/2024
---

In a standard TCP connection, no data flows between the peers when the connection is idle. Therefore, applications or API requests that use TCP to communicate with servers handling long-running requests might have to rely on connection timeouts to become aware of the termination or loss of connection. TCP connection losses can be more prominent in cloud environments, which are susceptible to infrastructure failures, network disruptions, or unexpected application crashes. In this article, you will learn to use TCP keepalive to enhance fault tolerance in cloud applications hosted in Azure Kubernetes Service (AKS).

## Understanding TCP keepalive

Several Azure Networking services, such as Azure Load Balancer, enable you to [configure a timeout period](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-tcp-reset) after which an idle TCP connection is terminated. When a TCP connection remains idle for longer than the timeout duration configured on the networking service, any subsequent TCP packets sent in either direction might be dropped or receive a TCP Reset (RST) packet from the network service, depending on whether TCP resets were enabled on the service.

The idle timeout feature helps to remove inactive connections from both the client and server in order to optimize resource utilization. However, for long-running operations, you might want to wait for a longer period than the configured timeout duration on the networking service. To ensure that the connection does not stay idle beyond the configured duration on the network service, or to ensure that the server is still available while the client is waiting for a response (or vice versa) so that you can retry the operation rather than waiting for a timeout, consider using the TCP keepalive feature.

The idle timeout feature helps to remove inactive connections from both the client and server in order to optimize resource utilization. However, for long-running operations, you might want to wait for a longer period than the configured timeout duration on the networking service. If you want to ensure that the connection does not stay idle beyond the configured duration on the network service, or want to ensure that the server is still available while the client is waiting for a response (or vice versa) so that you can retry the operation sooner rather than waiting for a timeout, you should consider using the TCP Keepalive feature.

In a TCP connection, either of the peers can request keepalives for their side of the connection. Keepalives can be configured for the client, the server, both, or neither. The keepalive mechanism follows the standard specifications defined in [RFC1122](https://datatracker.ietf.org/doc/html/rfc1122#section-4.2.3.6). A keepalive probe is either an empty segment or a segment that contains only one byte, featuring a sequence number that is one less than the largest Acknowledgment (ACK) number received from the peer so far. Since the receiving side has already acknowledged the original packet, the probe packet essentially mimics a packet that has already been received. In response, the receiving side sends another ACK packet as response to indicate to the sender that the connection is still active.

The RFC1122 specification states that if either the probe or the ACK is lost, they are not retransmitted. Therefore, if there is no response to a single Keepalive probe, it does not necessarily mean that the connection has stopped working. In this case, the sender must attempt to send the probe a certain number of times before terminating the connection. The idle time of the connection resets when an ACK is received for a probe, and the process is then repeated. Keepalive probes enable you to configure the following parameters to govern their behavior. The parameters are listed together with their default values on Linux-based OSes:

- **Keepalive Time (in seconds)**: The duration of inactivity after which the first Keepalive probe is sent. The default duration is 2 hours.
- **Keepalive Interval  (in seconds)**: The interval between subsequent Keepalive probes if no acknowledgment is received. The default interval is 75 seconds.
- **Keepalive Probes**: The maximum number of unacknowledged probes before the connection is considered unusable. The default value is 9.

Keepalive probes are managed at the TCP layer. Therefore, during normal operations, they don't affect the requestor application. However, in other cases, if the probes weren't acknowledged due to the peer rebooting or crashing, the application will receive a "connection timed out" error. If the peer sends a RESET (RST) response due to a crash, the application will receive a "connection reset by peer" error. In the case where the peer's host is up but unreachable from the requestor due to a network error, the application may receive a "connection timed out" or another error.

## Configuring TCP keepalive on AKS

AKS allows cluster administrators to adjust the operating system of a node, as well as kubelet parameters, to align with the requirements of their workloads. When setting up the cluster or a new node pool, administrators can modify the related sysctls to configure the Keepalive probes. To do this, create a file named **linuxkubeletconfig.json** with the following contents:

```json
{
    "allowedUnsafeSysctls": [
        "net.ipv4.tcp_keepalive_time",
        "net.ipv4.tcp_keepalive_intvl",
        "net.ipv4.tcp_keepalive_probes"
    ]
}
```

Next, create your cluster using the following command, ensuring that the path to the file you created is correct:

```shell
az aks create --name myAKSCluster --resource-group myResourceGroup --kubelet-config ./linuxkubeletconfig.json --generate-ssh-keys
```

To add a node pool to an existing cluster, use the customized configuration file created in the previous step to specify the kubelet configuration as follows:

```shell
az aks nodepool add --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --kubelet-config ./linuxkubeletconfig.json
```

You can find more detailed information about the supported configurations for both the node operating system and kubelet in our [prescriptive guidance](https://learn.microsoft.com/en-us/azure/aks/custom-node-configuration).

After the cluster is ready, you can configure TCP Keepalive sysctls in your desired pod by setting the security context in your pod definitions as follows:

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

Applying the specification will implement the following TCP Keepalive behavior:

1. `net.ipv4.tcp_keepalive_time` will configure Keepalive probes to be sent out after 45 seconds of inactivity on the connection.
2. `net.ipv4.tcp_keepalive_probes` will configure the operating system send 5 unacknowledged Keepalive probes before deeming the connection as unusable.
3. `net.ipv4.tcp_keepalive_intvl` will set the duration between dispatch of two Keepalive probes as 45 seconds.

Your pod is now ready to send and respond to Keepalive probes. To verify the settings, you can execute the `sysctl` command on the pod as follows:

```shell
kubectl exec -it busybox-sysctls -- sh -c "sysctl net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes"
```

Executing the command should produce the following output:

```text
net.ipv4.tcp_keepalive_time = 45
net.ipv4.tcp_keepalive_intvl = 45
net.ipv4.tcp_keepalive_probes = 5
```

 Now you need to ensure that your applications have TCP Keepalive enabled, which is what we will discuss next.

## Configuring TCP keepalive in applications

The TCP client application needs to ensure that TCP Keepalive is enabled to ensure that it sends Keepalive probes to the server. Most programming languages and frameworks provide options to enable TCP keepalive on socket connections. Below is an example using Python's `socket` library:

```python
import socket
import sys

# Create a TCP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Enable TCP keepalive
sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)

# Set TCP keepalive parameters (Linux specific).
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

In this example, the application activates Keepalive probes, which are sent to the server after 60 seconds of inactivity. If there are five probe failures, the connection will be closed. Keep in mind that the socket-level TCP Keepalive probe configurations take precedence over any OS-level settings.

> [!NOTE]
> The socket level TCP Keepalive settings configured through the application in the previous code listing will override the settings that you applied via the kubelet configuration earlier. If you don't set the socket level TCP Keepalive configuration values and only enable TCP Keepalive on the socket, the settings will default to the values set by the kubelet.

If you are using .NET, the following code will produce the same result:

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

Enabling TCP Keepalive helps to maintain the connection, especially when the server is placed behind a load balancer and uses NAT for outgoing traffic. In this way, the client can promptly detect server failures and switch to another instance without waiting for a timeout.

## HTTP/2 Keepalive

If you are using HTTP/2 based communication protocols such as gRPC, the TCP Keepalive settings won't affect your applications. HTTP/2 follows the [RFC 7540 specifications](https://httpwg.org/specs/rfc7540.html), which mandates that the client send a PING frame to the server and that the server immediately replies with a PING ACK frame. Since HTTP/2 transport is reliable as opposed to TCP, the only Keepalive configuration necessary in HTTP/2 transport is timeout. If the PING ACK is not received before the configured timeout period, the connection is disconnected.

When using the HTTP/2 transport, the server is responsible for supporting Keepalives and defining its behavior. The client's Keepalive settings must be compatible with the server's settings. For example, if the client sends the PING frame more frequently than what the server is willing to accept, the connection will be terminated with a HTTP2 GOAWAY frame response from the server.

For gRPC applications, the following Keepalive settings and the default values can be customized by the client and the server, as described in the [GRPC specification](https://grpc.io/docs/guides/keepalive/):

| Channel Argument                 | Availability      | Description                                                                                                                                                   | Client Default     | Server Default     |
| -------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------ |
| `KEEPALIVE_TIME`                 | Client and server | The interval in milliseconds between PING frames.                                                                                                             | INT_MAX (Disabled) | 7200000 (2 hours)  |
| `KEEPALIVE_TIMEOUT`              | Client and server | The timeout in milliseconds for a PING frame to be acknowledged. If sender does not receive an acknowledgment within this time, it will close the connection. | 20000 (20 seconds) | 20000 (20 seconds) |
| `KEEPALIVE_WITHOUT_CALLS`        | Client            | Determines if it is permissible to send keepalive pings from the client without any outstanding streams.                                                      | 0 (false)          | N/A                |
| `PERMIT_KEEPALIVE_WITHOUT_CALLS` | Server            | Determines if it is permissible to send keepalive pings from the client without any outstanding streams.                                                      | N/A                | 0 (false)          |
| `PERMIT_KEEPALIVE_TIME`          | Server            | Minimum allowed time between a server receiving successive ping frames without sending any data/header frame.                                                 | N/A                | 300000 (5 minutes) |
| `MAX_CONNECTION_IDLE`            | Server            | Maximum time that a channel may have no outstanding rpcs, after which the server will close the connection.                                                   | N/A                | INT_MAX (Infinite) |
| `MAX_CONNECTION_AGE`             | Server            | Maximum time that a channel may exist.                                                                                                                        | N/A                | INT_MAX (Infinite) |
| `MAX_CONNECTION_AGE_GRACE`       | Server            | Grace period after the channel reaches its max age.                                                                                                           | N/A                | INT_MAX (Infinite) |

The gRPC GitHub repository includes examples that demonstrate client and server applications that implement gRPC Keepalive:

| Programming Language | Example                                                                                                         | Documentation                                                                                                                                       |
| -------------------- | --------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| C++                  | [C++ Example](https://github.com/grpc/grpc/tree/master/examples/cpp/keepalive)                                  | [C++ Documentation](https://github.com/grpc/grpc/blob/master/doc/keepalive.md)                                                                      |
| Go                   | [Go Example](https://github.com/grpc/grpc-go/tree/master/examples/features/keepalive)                           | [Go Documentation](https://github.com/grpc/grpc-go/blob/master/Documentation/keepalive.md)                                                          |
| Java                 | [Java Example](https://github.com/grpc/grpc-java/tree/master/examples/src/main/java/io/grpc/examples/keepalive) | [Java Documentation](https://grpc.github.io/grpc-java/javadoc/io/grpc/ManagedChannelBuilder.html#keepAliveTime-long-java.util.concurrent.TimeUnit-) |
| Python               | [Python Example](https://github.com/grpc/grpc/tree/master/examples/python/keep_alive)                           | [Python Documentation](https://github.com/grpc/grpc/blob/master/doc/keepalive.md)                                                                   |

## Considerations

While Keepalive probes can improve the fault tolerance of your applications, they can also consume additional bandwidth. Additionally, on mobile devices, increased network activity may impact the device's battery life. Therefore, it's important to adhere to the following best practices:

- **Customize Parameters**: Adjust Keepalive settings based on application requirements and network conditions.
- **Application-Level Keepalives**: For encrypted connections (e.g., TLS/SSL), consider implementing keepalive mechanisms at the application layer to ensure probes are sent over secure channels.
- **Monitoring and Logging**: Implement logging to monitor keepalive-induced connection closures for troubleshooting.
- **Fallback Mechanisms**: Design applications to handle disconnections gracefully, including retry logic and failover strategies.

## See also

