param(
    [string]$Sender = "omdeshpande123456789@gmail.com",
    [string]$Recipient = "om.deshpande@mitwpu.edu.in"
)

$Api = "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit"
$Template = ".\email_templates\base.html"

Write-Host ""
Write-Host "--- FormBridge Email Sender ---" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Template)) {
    Write-Host "ERROR: Template not found" -ForegroundColor Red
    exit 1
}

$Size = (Get-Item $Template).Length
Write-Host "Template loaded: $Size bytes" -ForegroundColor Green

$Payload = @{
    form_id = "email-test"
    name = "Om Deshpande"
    email = $Sender
    message = "Testing FormBridge with base.html template"
} | ConvertTo-Json

Write-Host ""
Write-Host "Sending from: $Sender" -ForegroundColor Yellow
Write-Host "Sending to: $Recipient" -ForegroundColor Yellow
Write-Host ""

try {
    $Response = Invoke-WebRequest -Uri $Api `
        -Method POST `
        -Headers @{"Content-Type" = "application/json"} `
        -Body $Payload `
        -ErrorAction Stop
    
    $Result = $Response.Content | ConvertFrom-Json
    Write-Host "SUCCESS! Email sent" -ForegroundColor Green
    Write-Host "Response: $($Result | ConvertTo-Json)" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check AWS Lambda logs for details"
    exit 1
}
