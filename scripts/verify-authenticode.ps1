# Check the final file before packaging or publishing it.
param([Parameter(Mandatory = $true)][string]$Path)

$ErrorActionPreference = 'Stop'
# Accept both OpenSSL colon-separated fingerprints and Windows thumbprints.
$expected = $env:SSL_CERT_SHA1 -replace '[\s:]', ''
if ($expected -notmatch '^[0-9A-Fa-f]{40}$') {
    throw 'SSL_CERT_SHA1 must contain the production leaf certificate SHA-1 thumbprint'
}

$signature = Get-AuthenticodeSignature -LiteralPath $Path
if ($signature.Status -ne 'Valid') {
    throw "Invalid signature for ${Path}: $($signature.Status) $($signature.StatusMessage)"
}
if ($signature.SignerCertificate.Thumbprint -ne $expected) {
    throw "Unexpected signing certificate for $Path"
}
if ($null -eq $signature.TimeStamperCertificate) {
    throw "Missing timestamp for $Path"
}

Write-Host "Verified: $Path"
Write-Host "Publisher: $($signature.SignerCertificate.Subject)"
