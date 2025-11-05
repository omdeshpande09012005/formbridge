#############################################################################
# teardown-formbridge.ps1
# Interactive safe cleanup script (PowerShell) for FormBridge infrastructure
# Deletes stacks/resources in correct dependency order
#
# Usage (dry-run, safe):
#   & .\scripts\teardown-formbridge.ps1 -DryRun
#
# Usage (real):
#   & .\scripts\teardown-formbridge.ps1 -ReallyDestroy
#
# Options:
#   -DryRun              Show what would be deleted (no changes)
#   -ReallyDestroy       Actually delete resources
#   -PurgeSecrets        Also delete SSM Parameters and Secrets Manager
#   -KeepData            Keep DynamoDB tables (don't delete)
#   -KeepSNS             Keep SNS topics (don't delete)
#   -KeepBudget          Keep AWS Budget (don't delete)
#############################################################################

param(
    [switch]$DryRun,
    [switch]$ReallyDestroy,
    [switch]$PurgeSecrets,
    [switch]$KeepData,
    [switch]$KeepSNS,
    [switch]$KeepBudget,
    [string]$Region = $env:REGION ?? "ap-south-1",
    [string]$Profile = $env:AWS_PROFILE ?? "default"
)

$ErrorActionPreference = "Stop"

# Colors
$Colors = @{
    Red     = "Red"
    Green   = "Green"
    Yellow  = "Yellow"
    Cyan    = "Cyan"
    Magenta = "Magenta"
    Gray    = "Gray"
}

# Tracking
$Deleted = @()
$Skipped = @()
$Kept = @()

#############################################################################
# Utility Functions
#############################################################################

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warn", "Error", "Prompt", "Delete")]
        [string]$Level = "Info"
    )
    
    $prefix = switch ($Level) {
        "Info" { "[INFO] " }
        "Success" { "[✓] " }
        "Warn" { "[WARN] " }
        "Error" { "[ERROR] " }
        "Prompt" { "[?] " }
        "Delete" { "[DEL] " }
    }
    
    $color = switch ($Level) {
        "Info" { $Colors.Cyan }
        "Success" { $Colors.Green }
        "Warn" { $Colors.Yellow }
        "Error" { $Colors.Red }
        "Prompt" { $Colors.Magenta }
        "Delete" { $Colors.Red }
    }
    
    Write-Host "$prefix$Message" -ForegroundColor $color
}

function Confirm-Destruction {
    if ($DryRun) {
        Write-Log "DRY RUN MODE: No resources will be deleted" "Info"
        return $true
    }
    
    Write-Log "========== DESTRUCTIVE OPERATION ==========" "Warn"
    Write-Log "This will DELETE FormBridge infrastructure!" "Warn"
    Write-Host ""
    Write-Log "Type 'yes, really destroy FormBridge' to confirm:" "Prompt"
    
    $response = Read-Host
    
    if ($response -ne "yes, really destroy FormBridge") {
        Write-Log "Destruction cancelled by user" "Error"
        exit 1
    }
    
    Write-Log "Confirmed. Proceeding with teardown..." "Info"
    return $true
}

#############################################################################
# CloudFormation Stacks
#############################################################################

function Remove-CloudFormationStacks {
    Write-Log "Checking for CloudFormation stacks..." "Info"
    
    try {
        $stacks = aws cloudformation list-stacks `
            --region $Region `
            --profile $Profile `
            --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE `
            --query "StackSummaries[?contains(StackName, 'formbridge') || contains(StackName, 'FormBridge')].StackName" `
            --output text 2>$null
        
        if ([string]::IsNullOrEmpty($stacks)) {
            Write-Log "No active CloudFormation stacks found" "Info"
            return
        }
        
        foreach ($stack in $stacks.Split()) {
            if ($DryRun) {
                Write-Log "[DRY] Would delete CloudFormation stack: $stack" "Delete"
                $script:Deleted += "Stack: $stack"
            }
            else {
                Write-Log "Deleting CloudFormation stack: $stack" "Delete"
                aws cloudformation delete-stack `
                    --stack-name $stack `
                    --region $Region `
                    --profile $Profile
                
                Write-Log "Waiting for stack deletion..." "Info"
                aws cloudformation wait stack-delete-complete `
                    --stack-name $stack `
                    --region $Region `
                    --profile $Profile 2>$null
                
                Write-Log "Stack deleted: $stack" "Success"
                $script:Deleted += "Stack: $stack"
            }
        }
    }
    catch {
        Write-Log "Error deleting stacks: $_" "Warn"
    }
}

#############################################################################
# Event Source Mappings
#############################################################################

function Remove-EventSourceMappings {
    Write-Log "Checking for SQS event source mappings..." "Info"
    
    try {
        $functions = aws lambda list-functions `
            --region $Region `
            --profile $Profile `
            --query "Functions[?contains(FunctionName, 'formbridge') || contains(FunctionName, 'FormBridge')].FunctionName" `
            --output text 2>$null
        
        if ([string]::IsNullOrEmpty($functions)) {
            return
        }
        
        foreach ($func in $functions.Split()) {
            $mappings = aws lambda list-event-source-mappings `
                --function-name $func `
                --region $Region `
                --profile $Profile `
                --query "EventSourceMappings[].UUID" `
                --output text 2>$null
            
            if ([string]::IsNullOrEmpty($mappings)) {
                continue
            }
            
            foreach ($mapping in $mappings.Split()) {
                if ($DryRun) {
                    Write-Log "[DRY] Would delete event source mapping: $mapping" "Delete"
                    $script:Deleted += "ESM: $mapping"
                }
                else {
                    Write-Log "Deleting event source mapping: $mapping" "Delete"
                    aws lambda delete-event-source-mapping `
                        --uuid $mapping `
                        --region $Region `
                        --profile $Profile 2>$null
                    
                    Write-Log "Event source mapping deleted" "Success"
                    $script:Deleted += "ESM: $mapping"
                }
            }
        }
    }
    catch {
        Write-Log "Error deleting event source mappings: $_" "Warn"
    }
}

#############################################################################
# Consumer Lambda
#############################################################################

function Remove-ConsumerLambda {
    Write-Log "Checking for consumer Lambda functions..." "Info"
    
    try {
        $func = aws lambda list-functions `
            --region $Region `
            --profile $Profile `
            --query "Functions[?FunctionName=='formbridgeWebhookDispatcher'].FunctionName" `
            --output text 2>$null
        
        if ([string]::IsNullOrEmpty($func)) {
            return
        }
        
        if ($DryRun) {
            Write-Log "[DRY] Would delete Lambda: $func" "Delete"
            $script:Deleted += "Lambda: $func"
        }
        else {
            Write-Log "Deleting Lambda: $func" "Delete"
            aws lambda delete-function `
                --function-name $func `
                --region $Region `
                --profile $Profile 2>$null
            
            Write-Log "Lambda deleted" "Success"
            $script:Deleted += "Lambda: $func"
        }
    }
    catch {
        Write-Log "Error deleting consumer Lambda: $_" "Warn"
    }
}

#############################################################################
# SQS Queues
#############################################################################

function Remove-SQSQueues {
    Write-Log "Checking for SQS queues..." "Info"
    
    foreach ($queue in @("formbridge-webhook-queue", "formbridge-webhook-dlq")) {
        try {
            $queueUrl = aws sqs get-queue-url `
                --queue-name $queue `
                --region $Region `
                --profile $Profile `
                --query QueueUrl `
                --output text 2>$null
            
            if ([string]::IsNullOrEmpty($queueUrl)) {
                Write-Log "Queue not found (skipping): $queue" "Info"
                $script:Skipped += "Queue: $queue"
                continue
            }
            
            if ($DryRun) {
                Write-Log "[DRY] Would delete SQS queue: $queue" "Delete"
                $script:Deleted += "Queue: $queue"
            }
            else {
                Write-Log "Deleting SQS queue: $queue" "Delete"
                aws sqs delete-queue `
                    --queue-url $queueUrl `
                    --region $Region `
                    --profile $Profile
                
                Write-Log "Queue deleted: $queue" "Success"
                $script:Deleted += "Queue: $queue"
            }
        }
        catch {
            Write-Log "Error with queue $queue : $_" "Warn"
        }
    }
}

#############################################################################
# API Gateway
#############################################################################

function Remove-APIGateway {
    Write-Log "Checking for API Gateway resources..." "Info"
    
    try {
        $apiId = aws apigateway get-rest-apis `
            --region $Region `
            --profile $Profile `
            --query "items[0].id" `
            --output text 2>$null
        
        if ([string]::IsNullOrEmpty($apiId) -or $apiId -eq "None") {
            Write-Log "No API Gateway found" "Info"
            return
        }
        
        if ($DryRun) {
            Write-Log "[DRY] Would delete API Gateway: $apiId" "Delete"
            $script:Deleted += "API Gateway: $apiId"
        }
        else {
            Write-Log "Deleting API Gateway: $apiId" "Delete"
            aws apigateway delete-rest-api `
                --rest-api-id $apiId `
                --region $Region `
                --profile $Profile 2>$null
            
            Write-Log "API Gateway deleted" "Success"
            $script:Deleted += "API Gateway: $apiId"
        }
    }
    catch {
        Write-Log "Error deleting API Gateway: $_" "Warn"
    }
}

#############################################################################
# Main Lambda
#############################################################################

function Remove-MainLambda {
    Write-Log "Checking for main contact form Lambda..." "Info"
    
    try {
        $func = aws lambda list-functions `
            --region $Region `
            --profile $Profile `
            --query "Functions[?FunctionName=='contactFormProcessor'].FunctionName" `
            --output text 2>$null
        
        if ([string]::IsNullOrEmpty($func)) {
            Write-Log "Main Lambda not found" "Info"
            return
        }
        
        if ($DryRun) {
            Write-Log "[DRY] Would delete Lambda: $func" "Delete"
            $script:Deleted += "Lambda: $func"
        }
        else {
            Write-Log "Deleting Lambda: $func" "Delete"
            aws lambda delete-function `
                --function-name $func `
                --region $Region `
                --profile $Profile 2>$null
            
            Write-Log "Lambda deleted" "Success"
            $script:Deleted += "Lambda: $func"
        }
    }
    catch {
        Write-Log "Error deleting main Lambda: $_" "Warn"
    }
}

#############################################################################
# DynamoDB Tables
#############################################################################

function Remove-DynamoDBTables {
    if ($KeepData) {
        Write-Log "Keeping DynamoDB tables (--KeepData flag set)" "Info"
        $script:Kept += "DynamoDB: contact-form-submissions (user kept)"
        $script:Kept += "DynamoDB: formbridge-config (user kept)"
        return
    }
    
    Write-Log "Checking for DynamoDB tables..." "Info"
    
    foreach ($table in @("contact-form-submissions", "formbridge-config")) {
        try {
            $tableStatus = aws dynamodb describe-table `
                --table-name $table `
                --region $Region `
                --profile $Profile `
                --query "Table.TableStatus" `
                --output text 2>$null
            
            if ([string]::IsNullOrEmpty($tableStatus)) {
                Write-Log "Table not found (skipping): $table" "Info"
                $script:Skipped += "DynamoDB: $table"
                continue
            }
            
            if ($DryRun) {
                Write-Log "[DRY] Would delete DynamoDB table: $table" "Delete"
                $script:Deleted += "DynamoDB: $table"
            }
            else {
                Write-Log "Deleting DynamoDB table: $table" "Delete"
                aws dynamodb delete-table `
                    --table-name $table `
                    --region $Region `
                    --profile $Profile
                
                Write-Log "Table deleted: $table" "Success"
                $script:Deleted += "DynamoDB: $table"
            }
        }
        catch {
            Write-Log "Error with table $table : $_" "Warn"
        }
    }
}

#############################################################################
# SNS Topics
#############################################################################

function Remove-SNSTopics {
    if ($KeepSNS) {
        Write-Log "Keeping SNS topics (--KeepSNS flag set)" "Info"
        $script:Kept += "SNS: FormBridge-Budget-Alerts (user kept)"
        return
    }
    
    Write-Log "Checking for SNS topics..." "Info"
    
    try {
        $topic = aws sns list-topics `
            --region $Region `
            --profile $Profile `
            --query "Topics[?contains(TopicArn, 'FormBridge-Budget-Alerts')].TopicArn" `
            --output text 2>$null
        
        if ([string]::IsNullOrEmpty($topic)) {
            Write-Log "Topic not found (skipping): FormBridge-Budget-Alerts" "Info"
            $script:Skipped += "SNS: FormBridge-Budget-Alerts"
            return
        }
        
        if ($DryRun) {
            Write-Log "[DRY] Would delete SNS topic: FormBridge-Budget-Alerts" "Delete"
            $script:Deleted += "SNS: FormBridge-Budget-Alerts"
        }
        else {
            Write-Log "Deleting SNS topic: $topic" "Delete"
            aws sns delete-topic `
                --topic-arn $topic `
                --region $Region `
                --profile $Profile
            
            Write-Log "Topic deleted" "Success"
            $script:Deleted += "SNS: FormBridge-Budget-Alerts"
        }
    }
    catch {
        Write-Log "Error deleting SNS topic: $_" "Warn"
    }
}

#############################################################################
# AWS Budget
#############################################################################

function Remove-Budget {
    if ($KeepBudget) {
        Write-Log "Keeping AWS Budget (--KeepBudget flag set)" "Info"
        $script:Kept += "Budget: FormBridge-Monthly-Budget (user kept)"
        return
    }
    
    Write-Log "Checking for AWS Budget..." "Info"
    
    try {
        $accountId = aws sts get-caller-identity `
            --query Account `
            --output text `
            --profile $Profile
        
        $budget = aws budgets describe-budgets `
            --account-id $accountId `
            --query "Budgets[?BudgetName=='FormBridge-Monthly-Budget'].BudgetName" `
            --output text 2>$null
        
        if ([string]::IsNullOrEmpty($budget)) {
            Write-Log "Budget not found" "Info"
            $script:Skipped += "Budget: FormBridge-Monthly-Budget"
            return
        }
        
        if ($DryRun) {
            Write-Log "[DRY] Would delete budget: FormBridge-Monthly-Budget" "Delete"
            $script:Deleted += "Budget: FormBridge-Monthly-Budget"
        }
        else {
            Write-Log "Deleting budget: FormBridge-Monthly-Budget" "Delete"
            aws budgets delete-budget `
                --account-id $accountId `
                --budget-name "FormBridge-Monthly-Budget" `
                --profile $Profile
            
            Write-Log "Budget deleted" "Success"
            $script:Deleted += "Budget: FormBridge-Monthly-Budget"
        }
    }
    catch {
        Write-Log "Error deleting budget: $_" "Warn"
    }
}

#############################################################################
# Secrets & Parameters
#############################################################################

function Remove-Secrets {
    if (-not $PurgeSecrets) {
        Write-Log "Keeping SSM Parameters and Secrets Manager (use -PurgeSecrets to remove)" "Info"
        return
    }
    
    Write-Log "Purging SSM Parameters and Secrets..." "Info"
    
    try {
        # SSM Parameters
        $params = aws ssm describe-parameters `
            --filters "Key=Name,Values=/formbridge/" `
            --region $Region `
            --profile $Profile `
            --query "Parameters[].Name" `
            --output text 2>$null
        
        if (-not [string]::IsNullOrEmpty($params)) {
            foreach ($param in $params.Split()) {
                if ($DryRun) {
                    Write-Log "[DRY] Would delete SSM parameter: $param" "Delete"
                }
                else {
                    Write-Log "Deleting SSM parameter: $param" "Delete"
                    aws ssm delete-parameter `
                        --name $param `
                        --region $Region `
                        --profile $Profile 2>$null
                }
            }
        }
        
        # Secrets Manager
        $secrets = aws secretsmanager list-secrets `
            --region $Region `
            --profile $Profile `
            --query "SecretList[?contains(Name, 'formbridge')].Name" `
            --output text 2>$null
        
        if (-not [string]::IsNullOrEmpty($secrets)) {
            foreach ($secret in $secrets.Split()) {
                if ($DryRun) {
                    Write-Log "[DRY] Would delete secret: $secret" "Delete"
                }
                else {
                    Write-Log "Deleting secret: $secret" "Delete"
                    aws secretsmanager delete-secret `
                        --secret-id $secret `
                        --force-delete-without-recovery `
                        --region $Region `
                        --profile $Profile 2>$null
                }
            }
        }
    }
    catch {
        Write-Log "Error deleting secrets: $_" "Warn"
    }
}

#############################################################################
# Summary
#############################################################################

function Print-Summary {
    Write-Host ""
    Write-Log "==========================================" "Info"
    if ($DryRun) {
        Write-Log "DRY RUN SUMMARY" "Info"
    }
    else {
        Write-Log "TEARDOWN COMPLETE" "Info"
    }
    Write-Log "==========================================" "Info"
    Write-Host ""
    
    if ($Deleted.Count -gt 0) {
        Write-Host "🗑️  Deleted/Would Delete ($($Deleted.Count)):" -ForegroundColor Cyan
        foreach ($item in $Deleted) {
            Write-Host "  ✓ $item" -ForegroundColor Green
        }
        Write-Host ""
    }
    
    if ($Kept.Count -gt 0) {
        Write-Host "📌 Kept ($($Kept.Count)):" -ForegroundColor Cyan
        foreach ($item in $Kept) {
            Write-Host "  → $item" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    if ($Skipped.Count -gt 0) {
        Write-Host "⏭️  Skipped/Not Found ($($Skipped.Count)):" -ForegroundColor Cyan
        foreach ($item in $Skipped) {
            Write-Host "  − $item" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "📝 What Remains:" -ForegroundColor Cyan
    Write-Host "  • Git repositories (.git/ folders)" -ForegroundColor Gray
    Write-Host "  • CloudWatch Logs (if not in stack)" -ForegroundColor Gray
    Write-Host "  • IAM Roles (if custom)" -ForegroundColor Gray
    if (-not $PurgeSecrets) {
        Write-Host "  • SSM Parameters (use -PurgeSecrets)" -ForegroundColor Gray
        Write-Host "  • Secrets Manager secrets (use -PurgeSecrets)" -ForegroundColor Gray
    }
    if ($KeepData) {
        Write-Host "  • DynamoDB data (kept by request)" -ForegroundColor Gray
    }
    if ($KeepSNS) {
        Write-Host "  • SNS topics (kept by request)" -ForegroundColor Gray
    }
    if ($KeepBudget) {
        Write-Host "  • AWS Budget (kept by request)" -ForegroundColor Gray
    }
    Write-Host ""
    
    if ($DryRun) {
        Write-Host "🔄 To actually delete, run:" -ForegroundColor Yellow
        Write-Host "   & .\scripts\teardown-formbridge.ps1 -ReallyDestroy" -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        Write-Log "Teardown complete!" "Success"
    }
}

#############################################################################
# Main
#############################################################################

try {
    if (-not ($DryRun -or $ReallyDestroy)) {
        Write-Host "Usage: & .\scripts\teardown-formbridge.ps1 [-DryRun | -ReallyDestroy] [options]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Cyan
        Write-Host "  -DryRun              Show what would be deleted (safe)" -ForegroundColor Gray
        Write-Host "  -ReallyDestroy       Actually delete resources (DESTRUCTIVE)" -ForegroundColor Gray
        Write-Host "  -PurgeSecrets        Also delete SSM/Secrets Manager" -ForegroundColor Gray
        Write-Host "  -KeepData            Don't delete DynamoDB tables" -ForegroundColor Gray
        Write-Host "  -KeepSNS             Don't delete SNS topics" -ForegroundColor Gray
        Write-Host "  -KeepBudget          Don't delete budget" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
    
    Write-Log "FormBridge Infrastructure Teardown" "Info"
    Write-Host ""
    
    Confirm-Destruction
    Write-Host ""
    
    Remove-CloudFormationStacks
    Remove-EventSourceMappings
    Remove-ConsumerLambda
    Remove-SQSQueues
    Remove-APIGateway
    Remove-MainLambda
    Remove-DynamoDBTables
    Remove-SNSTopics
    Remove-Budget
    Remove-Secrets
    
    Write-Host ""
    Print-Summary
}
catch {
    Write-Log "Fatal error: $_" "Error"
    exit 1
}
