# Fetch Microsoft's Evergreen WebView2 bootstrapper and verify its publisher.
$ErrorActionPreference = 'Stop'
$destination = Join-Path $PSScriptRoot '../upstream/dll/MicrosoftEdgeWebview2Setup.exe'
$temporary = "$destination.download.exe"
try {
    Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $temporary
    $signature = Get-AuthenticodeSignature -LiteralPath $temporary
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(^|,\s*)O=Microsoft Corporation(,|$)') {
        throw 'WebView2 bootstrapper must have a valid Microsoft Corporation signature'
    }
    Move-Item -LiteralPath $temporary -Destination $destination -Force
} finally {
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Force
    }
}
