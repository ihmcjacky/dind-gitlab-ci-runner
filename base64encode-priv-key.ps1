param(
    [Parameter(Mandatory=$true)]
    [string]$KeyFilePath = "./certificates/key.pem"
)

function Base64EncodePrivateKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyFilePath
    )
    $bytes = [System.IO.File]::ReadAllBytes($KeyFilePath)
    return [System.Convert]::ToBase64String($bytes)
}

function Main {
    if (-not (Test-Path $KeyFilePath)) {
        Write-Host "File not found: $KeyFilePath"
        Write-Host "Please specify the correct path to the private key file"
        exit 1
    }
    # Convert the byte array to a Base64 string
    $base64String = Base64EncodePrivateKey $KeyFilePath
    Write-Host "Base64 encoded private key:"
    Write-Host $base64String
}

Main