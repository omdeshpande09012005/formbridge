# API Gateway 403 Diagnostic & Fix Script (PowerShell Wrapper)
# For Windows users - calls the bash script or runs diagnostics natively
# Usage: .\diagnose-api-403.ps1 [-Region ap-south-1] [-ApiId 12mse3zde5] [-StageName Prod] [-FixPermissive]

param(
    [string]$Region = "ap-south-1",
    [string]$ApiId = "12mse3zde5",
    [string]$StageName = "Prod",
    [string]$ApiKeyId = "",
    [string]$UsagePlanName = "",
    [switch]$FixPermissive = $false
)

# Color codes
$Green = [ConsoleColor]::Green
$Red = [ConsoleColor]::Red
$Yellow = [ConsoleColor]::Yellow
$Blue = [ConsoleColor]::Cyan
$Normal = [ConsoleColor]::White

function Write-Banner {
    param([string]$Text)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $Blue
    Write-Host $Text -ForegroundColor $Blue
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $Blue
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor $Green
}

function Write-Error_ {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor $Red
}

function Write-Warning_ {
    param([string]$Text)
    Write-Host "⚠ $Text" -ForegroundColor $Yellow
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ $Text" -ForegroundColor $Blue
}

Write-Banner "PRECHECKS"

# Check for required tools
@("aws", "jq", "curl") | ForEach-Object {
    try {
        $cmd = Get-Command $_ -ErrorAction Stop
        Write-Success "$_ installed"
    }
    catch {
        Write-Error_ "$_ not found. Install it first."
        exit 1
    }
}

# Check AWS credentials
try {
    $identity = aws sts get-caller-identity --region $Region 2>$null | ConvertFrom-Json
    Write-Success "AWS credentials valid"
    Write-Info "Account: $($identity.Account)"
}
catch {
    Write-Error_ "AWS credentials not valid"
    exit 1
}

Write-Info "Configuration: API_ID=$ApiId, STAGE=$StageName, REGION=$Region"

Write-Banner "STEP 1: STAGE INFORMATION"

try {
    $stageInfo = aws apigateway get-stage --rest-api-id $ApiId --stage-name $StageName --region $Region | ConvertFrom-Json
    Write-Success "Found stage: $StageName"
    Write-Info "Endpoint: $($stageInfo.endpoint)"
    Write-Info "Logging: $($stageInfo.methodSettings[0].loggingLevel ?? 'OFF')"
}
catch {
    Write-Error_ "Stage $StageName not found"
    exit 1
}

Write-Banner "STEP 2: USAGE PLANS & API KEY BINDING"

try {
    $usagePlans = aws apigateway get-usage-plans --region $Region | ConvertFrom-Json
    Write-Info "Found $($usagePlans.items.Count) usage plan(s)"
    
    $matchingPlan = $null
    $usagePlans.items | ForEach-Object {
        if ($_.apiStages -and $_.apiStages.apiId -contains $ApiId) {
            $matchingPlan = $_
            Write-Success "Found usage plan: $($_.name) ($($_.id))"
            Write-Info "Associated with API: $ApiId"
        }
    }
    
    if ($matchingPlan) {
        $planKeys = aws apigateway get-usage-plan-keys --usage-plan-id $matchingPlan.id --region $Region | ConvertFrom-Json
        Write-Info "Found $($planKeys.items.Count) API key(s)"
        
        $planKeys.items | ForEach-Object {
            Write-Info "  - $($_.name) ($($_.id))"
            if ([string]::IsNullOrEmpty($ApiKeyId)) {
                $ApiKeyId = $_.id
            }
        }
    }
}
catch {
    Write-Warning_ "Could not fetch usage plans: $_"
}

Write-Banner "STEP 3: API KEY VALUE"

if (![string]::IsNullOrEmpty($ApiKeyId)) {
    try {
        $apiKey = aws apigateway get-api-key --api-key $ApiKeyId --include-value --region $Region | ConvertFrom-Json
        Write-Success "API key retrieved"
        $keyPreview = $apiKey.value.Substring(0, 10) + "..." + $apiKey.value.Substring($apiKey.value.Length - 10)
        Write-Info "Key: $keyPreview"
        $ApiKeyValue = $apiKey.value
    }
    catch {
        Write-Warning_ "Could not retrieve API key value"
    }
}
else {
    Write-Warning_ "No API key ID found"
}

Write-Banner "STEP 4: /SUBMIT POST METHOD CONFIGURATION"

try {
    $resources = aws apigateway get-resources --rest-api-id $ApiId --region $Region | ConvertFrom-Json
    $submitResource = $resources.items | Where-Object { $_.path -eq "/submit" }
    
    if (!$submitResource) {
        Write-Error_ "/submit resource not found"
        Write-Info "Available resources:"
        $resources.items | ForEach-Object { Write-Info "  - $($_.path)" }
        exit 1
    }
    
    Write-Success "Found /submit resource: $($submitResource.id)"
    
    $methodConfig = aws apigateway get-method --rest-api-id $ApiId --resource-id $submitResource.id --http-method POST --region $Region | ConvertFrom-Json
    
    Write-Info "API Key Required: $($methodConfig.apiKeyRequired)"
    Write-Info "Authorization Type: $($methodConfig.authorizationType)"
    
    if ($methodConfig.apiKeyRequired -ne $true) {
        Write-Warning_ "API key is NOT required for POST /submit (should be true)"
    }
    else {
        Write-Success "API key is required"
    }
}
catch {
    Write-Error_ "Could not fetch method config: $_"
}

Write-Banner "STEP 5: RESOURCE POLICY ANALYSIS"

try {
    $policyJson = aws apigateway get-resource-policy --rest-api-id $ApiId --region $Region 2>$null | ConvertFrom-Json
    
    if ($policyJson.policy) {
        $policy = $policyJson.policy | ConvertFrom-Json
        Write-Info "Resource policy found with $($policy.Statement.Count) statement(s)"
        
        $denys = $policy.Statement | Where-Object { $_.Effect -eq "Deny" }
        if ($denys) {
            Write-Warning_ "Found DENY statements"
            $denys | ForEach-Object { Write-Info "  - Principal: $($_.Principal)" }
        }
    }
    else {
        Write-Success "No restrictive resource policy (permissive by default)"
    }
}
catch {
    Write-Success "No resource policy found (permissive by default)"
}

Write-Banner "STEP 6: TEST-INVOKE-METHOD"

try {
    $testBody = '{"form_id":"k6-test","message":"test from diagnose"}'
    $testResult = aws apigateway test-invoke-method `
        --rest-api-id $ApiId `
        --resource-id $submitResource.id `
        --http-method POST `
        --body $testBody `
        --region $Region | ConvertFrom-Json
    
    Write-Info "Test invoke status: $($testResult.status)"
    if ($testResult.body) {
        Write-Info "Response: $($testResult.body.Substring(0, [Math]::Min(100, $testResult.body.Length)))"
    }
}
catch {
    Write-Warning_ "Test invoke failed: $_"
}

Write-Banner "STEP 7: SANITY CHECK - CURL COMMANDS"

$endpointUrl = "https://$ApiId.execute-api.$Region.amazonaws.com/$StageName/submit"
Write-Info "Endpoint: $endpointUrl"
Write-Info ""
Write-Info "Test WITHOUT API Key:"
Write-Host ""
Write-Host "curl -i -X POST `"$endpointUrl`" \" -ForegroundColor $Yellow
Write-Host "  -H 'Content-Type: application/json' \" -ForegroundColor $Yellow
Write-Host "  -d '{""form_id"":""test"",""message"":""hello""}'`n" -ForegroundColor $Yellow

if (![string]::IsNullOrEmpty($ApiKeyValue)) {
    Write-Info "Test WITH API Key:"
    Write-Host ""
    Write-Host "curl -i -X POST `"$endpointUrl`" \" -ForegroundColor $Green
    Write-Host "  -H 'Content-Type: application/json' \" -ForegroundColor $Green
    Write-Host "  -H 'X-Api-Key: $ApiKeyValue' \" -ForegroundColor $Green
    Write-Host "  -d '{""form_id"":""test"",""message"":""hello""}'`n" -ForegroundColor $Green
}

Write-Banner "NEXT STEPS"

Write-Info "1. Run the curl commands above to test your endpoint"
Write-Info "2. Check CloudWatch logs:"
Write-Host "   aws logs tail /aws/apigateway/$ApiId/$StageName --follow --region $Region" -ForegroundColor $Yellow
Write-Info "3. Verify API key in X-Api-Key header is being sent"
Write-Info "4. If still 403, enable execution logging in AWS Console"

Write-Banner "DIAGNOSTIC COMPLETE"
