[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int] $Port = 8765,
    [switch] $NoBrowser
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'index.html') -PathType Leaf)) {
    throw '找不到 index.html。请解压完整网页包后，在包内运行启动器。'
}

if (-not ('MuteLocalWebServer' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;

public static class MuteLocalWebServer
{
    public static void Queue(TcpClient client, string root, string authority)
    {
        ThreadPool.QueueUserWorkItem(_ => Serve(client, root, authority));
    }

    private static void Serve(TcpClient client, string root, string authority)
    {
        using (client)
        {
            try
            {
                client.ReceiveTimeout = 10000;
                client.SendTimeout = 10000;
                using (var stream = client.GetStream())
                {
                    string request = ReadRequest(stream);
                    if (request == null)
                        return;

                    string[] lines = request.Split(new[] { "\r\n" }, StringSplitOptions.None);
                    string[] parts = lines[0].Split(' ');
                    int hostCount = 0;
                    foreach (string line in lines)
                    {
                        if (!line.StartsWith("Host:", StringComparison.OrdinalIgnoreCase))
                            continue;
                        // 浏览器只能通过显示给玩家的环回地址访问，拒绝指向本机的外部域名。
                        hostCount += line.Substring(5).Trim() == authority ? 1 : 2;
                    }

                    if (parts.Length != 3 || !parts[1].StartsWith("/", StringComparison.Ordinal) ||
                        (parts[2] != "HTTP/1.1" && parts[2] != "HTTP/1.0") || hostCount != 1)
                    {
                        Respond(stream, "400 Bad Request", 0);
                        return;
                    }

                    bool headOnly = parts[0] == "HEAD";
                    if (!headOnly && parts[0] != "GET")
                    {
                        Respond(stream, "405 Method Not Allowed", 0, "Allow: GET, HEAD\r\n");
                        return;
                    }

                    string path = FindFile(root, parts[1]);
                    if (path == null)
                    {
                        Respond(stream, "404 Not Found", 0);
                        return;
                    }

                    using (var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
                    {
                        Respond(stream, "200 OK", file.Length, "Content-Type: " + ContentType(path) + "\r\n");
                        if (!headOnly)
                            file.CopyTo(stream);
                    }
                }
            }
            catch (IOException error)
            {
                Console.Error.WriteLine("本机 HTTP 请求中断：{0}", error.Message);
            }
            catch (UnauthorizedAccessException error)
            {
                Console.Error.WriteLine("本机 HTTP 无法读取文件：{0}", error.Message);
            }
        }
    }

    private static string ReadRequest(NetworkStream stream)
    {
        var buffer = new byte[16384];
        int total = 0;
        while (total < buffer.Length)
        {
            int read = stream.Read(buffer, total, buffer.Length - total);
            if (read == 0)
                return null;

            int start = Math.Max(0, total - 3);
            total += read;
            for (int i = start; i + 3 < total; i++)
            {
                if (buffer[i] == 13 && buffer[i + 1] == 10 && buffer[i + 2] == 13 && buffer[i + 3] == 10)
                    return Encoding.ASCII.GetString(buffer, 0, i);
            }
        }
        return "";
    }

    private static string FindFile(string root, string target)
    {
        int query = target.IndexOf('?');
        string relative = Uri.UnescapeDataString(query < 0 ? target : target.Substring(0, query)).Substring(1);
        if (relative.Length == 0)
            relative = "index.html";

        string path = root;
        var attributes = FileAttributes.Directory;
        char[] invalid = Path.GetInvalidFileNameChars();
        try
        {
            foreach (string segment in relative.Split('/'))
            {
                // 逐段检查 Windows 路径，禁止盘符、反斜杠、点路径和通向包外的链接。
                if (segment.Length == 0 || segment.EndsWith(".", StringComparison.Ordinal) ||
                    segment.EndsWith(" ", StringComparison.Ordinal) || segment.IndexOfAny(invalid) >= 0 ||
                    (attributes & FileAttributes.Directory) == 0)
                    return null;
                path = Path.Combine(path, segment);
                attributes = File.GetAttributes(path);
                if ((attributes & (FileAttributes.ReparsePoint | FileAttributes.Device)) != 0)
                    return null;
            }
        }
        catch (FileNotFoundException) { return null; }
        catch (DirectoryNotFoundException) { return null; }
        return (attributes & FileAttributes.Directory) == 0 ? path : null;
    }

    private static void Respond(NetworkStream stream, string status, long length, string extra = "")
    {
        string header = "HTTP/1.1 " + status + "\r\nConnection: close\r\nCache-Control: no-store\r\n" +
            "Content-Length: " + length.ToString(System.Globalization.CultureInfo.InvariantCulture) + "\r\n" + extra + "\r\n";
        byte[] bytes = Encoding.ASCII.GetBytes(header);
        stream.Write(bytes, 0, bytes.Length);
    }

    private static string ContentType(string path)
    {
        switch (Path.GetExtension(path).ToLowerInvariant())
        {
            case ".html": return "text/html; charset=utf-8";
            case ".js":
            case ".mjs": return "text/javascript; charset=utf-8";
            case ".json": return "application/json";
            case ".wasm": return "application/wasm";
            case ".txt": return "text/plain; charset=utf-8";
            // 网页显式请求 .gz 并自行解压，服务端不添加 Content-Encoding。
            case ".gz": return "application/gzip";
            default: return "application/octet-stream";
        }
    }
}
'@
}

$authority = "127.0.0.1:$Port"
$address = "http://$authority/"
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.ExclusiveAddressUse = $true
$listener.Start()
try {
    Write-Host "Mute 已启动：$address"
    Write-Host '保持此窗口打开，按 Ctrl+C 停止。'
    if (-not $NoBrowser) {
        Start-Process -FilePath $address
    }

    while ($true) {
        if ($listener.Pending()) {
            [MuteLocalWebServer]::Queue($listener.AcceptTcpClient(), $PSScriptRoot, $authority)
        } else {
            Start-Sleep -Milliseconds 50
        }
    }
} finally {
    $listener.Stop()
}
