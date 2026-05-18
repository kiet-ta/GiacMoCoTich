param(
    [string]$Url = "http://localhost:9080/mcp",
    [string]$Method = "tools/list",
    [string]$ParamsJson = "{}"
)

$ErrorActionPreference = "Stop"

try {
    $paramsObject = $ParamsJson | ConvertFrom-Json
} catch {
    Write-Error "ParamsJson must be valid JSON. Error: $($_.Exception.Message)"
    exit 1
}

$request = [ordered]@{
    jsonrpc = "2.0"
    id = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    method = $Method
    params = $paramsObject
}

$response = Invoke-RestMethod `
    -UseBasicParsing `
    -Uri $Url `
    -Method Post `
    -ContentType "application/json" `
    -Body ($request | ConvertTo-Json -Depth 32) `
    -TimeoutSec 30

$response | ConvertTo-Json -Depth 32

if ($response.error) {
    exit 1
}

if ($response.result -and $response.result.isError) {
    exit 1
}
