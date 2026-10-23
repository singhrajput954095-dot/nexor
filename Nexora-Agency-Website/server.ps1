$port = 8888
$folder = $PSScriptRoot
if (-not $folder) { $folder = (Get-Location).Path }

$maxPort = $port + 50
while ($port -lt $maxPort) {
    try {
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:$port/")
        $listener.Start()
        break
    } catch {
        $port++
    }
}

if (-not $listener.IsListening) {
    Write-Error "Could not start server on ports 8080-8100"
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Nexora Studio Preview Server Started!" -ForegroundColor Green
Write-Host "  URL: http://localhost:$port/" -ForegroundColor Yellow
Write-Host "  Folder: $folder" -ForegroundColor Gray
Write-Host "  Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

Start-Process "http://localhost:$port/"

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".ico"  = "image/x-icon"
    ".json" = "application/json"
    ".woff" = "font/woff"
    ".woff2"= "font/woff2"
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $rawPath = $request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($rawPath) -or $rawPath -eq '/') {
            $rawPath = "index.html"
        }
        
        $filePath = Join-Path $folder $rawPath
        if (-not (Test-Path $filePath -PathType Leaf)) {
            $filePath = Join-Path $folder "index.html"
        }
        
        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mime = $mimeTypes[$ext]
            if (-not $mime) { $mime = "application/octet-stream" }
            
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentType = $mime
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
        }
        $response.Close()
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
