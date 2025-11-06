# FormBridge Email Sender via API
# Send email using your FormBridge service

param([string]$To = "om.deshpande@mitwpu.edu.in")

$ApiUrl = "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit"
$Template = ".\email_templates\base.html"

Write-Host "`n===== FormBridge Email Sender =====" -ForegroundColor Cyan

if (-not (Test-Path $Template)) {
    Write-Host "Template not found: $Template" -ForegroundColor Red
    exit 1
}

Write-Host "Loading template..." -ForegroundColor Yellow
$TemplateSize = (Get-Item $Template).Length
Write-Host "Template size: $TemplateSize bytes" -ForegroundColor Green

$JsonPayload = @{
    form_id = "email-test"
    name = "Om Deshpande"
    email = "om.deshpande@mitwpu.edu.in"
    message = "Testing FormBridge with base.html template"
    page = "https://omdeshpande09012005.github.io/formbridge/"
} | ConvertTo-Json

Write-Host "`nSending email..." -ForegroundColor Yellow
Write-Host "API: $ApiUrl"
Write-Host "To: $To`n"

try {
    $Response = Invoke-WebRequest -Uri $ApiUrl -Method POST `
        -Headers @{"Content-Type" = "application/json"} `
        -Body $JsonPayload -ErrorAction Stop
    
    $Result = $Response.Content | ConvertFrom-Json
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "Response:`n$($Result | ConvertTo-Json -Depth 3 | Out-String)"
    exit 0
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
