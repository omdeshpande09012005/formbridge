#############################################################################
# setup-cost-guardrails.ps1
# Idempotent AWS CLI tool (PowerShell) for FormBridge cost controls
# Creates budgets, SNS alerts, applies mandatory tagging, verifies DynamoDB/SQS
#
# Usage:
#   $env:REGION = "ap-south-1"
#   $env:ALERT_EMAIL = "ops@example.com"
#   $env:BUDGET_LIMIT = "3.00"
#   & .\scripts\setup-cost-guardrails.ps1
#
# Env vars:
#   REGION        - AWS region (default: ap-south-1)
#   ALERT_EMAIL   - Email for budget alerts (required)
#   BUDGET_LIMIT  - Monthly budget in USD (default: 3.00)
#############################################################################

param(
    [string]$Region = $env:REGION ?? "ap-south-1",
    [string]$AlertEmail = $env:ALERT_EMAIL,
    [string]$BudgetLimit = $env:BUDGET_LIMIT ?? "3.00",
    [string]$Profile = $env:AWS_PROFILE ?? "default"
)

$ErrorActionPreference = "Stop"

# Colors
$Colors = @{
    Red    = "Red"
    Green  = "Green"
    Yellow = "Yellow"
    Blue   = "Cyan"
}

# Configuration
$BudgetName = "FormBridge-Monthly-Budget"
$SnsTopicName = "FormBridge-Budget-Alerts"
$AccountId = aws sts get-caller-identity --query Account --output text --profile $Profile

#############################################################################
# Utility Functions
#############################################################################

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warn", "Error")]
        [string]$Level = "Info"
    )
    
    $prefix = switch ($Level) {
        "Info" { "[INFO] " }
        "Success" { "[✓] " }
        "Warn" { "[WARN] " }
        "Error" { "[ERROR] " }
    }
    
    $color = switch ($Level) {
        "Info" { $Colors.Blue }
        "Success" { $Colors.Green }
        "Warn" { $Colors.Yellow }
        "Error" { $Colors.Red }
    }
    
    Write-Host "$prefix$Message" -ForegroundColor $color
}

function Exit-Error {
    param([string]$Message)
    Write-Log $Message "Error"
    exit 1
}

function Validate-Inputs {
    if ([string]::IsNullOrEmpty($AlertEmail)) {
        Exit-Error "ALERT_EMAIL environment variable is required. Set it and retry."
    }
    
    if ($BudgetLimit -notmatch '^\d+\.\d{2}$') {
        Exit-Error "BUDGET_LIMIT must be in format: X.XX (e.g., 3.00)"
    }
    
    Write-Log "Configuration:" "Info"
    Write-Host "  Region:       $Region" -ForegroundColor Gray
    Write-Host "  Alert Email:  $AlertEmail" -ForegroundColor Gray
    Write-Host "  Budget Limit: USD $BudgetLimit" -ForegroundColor Gray
    Write-Host "  Account ID:   $AccountId" -ForegroundColor Gray
}

#############################################################################
# SNS Topic Setup
#############################################################################

function Setup-SnsTopic {
    Write-Log "Setting up SNS topic for budget alerts..." "Info"
    
    try {
        $topics = aws sns list-topics `
            --region $Region `
            --profile $Profile `
            --query "Topics[?contains(TopicArn, '$SnsTopicName')].TopicArn" `
            --output text
        
        $SnsTopicArn = if ($topics) { $topics } else { "" }
        
        if ([string]::IsNullOrEmpty($SnsTopicArn)) {
            Write-Log "Creating SNS topic: $SnsTopicName" "Info"
            $SnsTopicArn = aws sns create-topic `
                --name $SnsTopicName `
                --region $Region `
                --profile $Profile `
                --query TopicArn `
                --output text
            
            # Apply cost tags
            aws sns tag-resource `
                --topic-arn $SnsTopicArn `
                --tags Key=Project,Value=FormBridge Key=Env,Value=Prod Key=Owner,Value=OmDeshpande `
                --region $Region `
                --profile $Profile
            
            Write-Log "SNS topic created: $SnsTopicArn" "Success"
        }
        else {
            Write-Log "SNS topic exists: $SnsTopicArn" "Success"
        }
        
        # Check if email is subscribed
        $subscription = aws sns list-subscriptions-by-topic `
            --topic-arn $SnsTopicArn `
            --region $Region `
            --profile $Profile `
            --query "Subscriptions[?Endpoint=='$AlertEmail'].SubscriptionArn" `
            --output text
        
        if ([string]::IsNullOrEmpty($subscription)) {
            Write-Log "Subscribing email to SNS topic: $AlertEmail" "Info"
            aws sns subscribe `
                --topic-arn $SnsTopicArn `
                --protocol email `
                --notification-endpoint $AlertEmail `
                --region $Region `
                --profile $Profile | Out-Null
            
            Write-Log "Email subscription pending. Please check your inbox and confirm." "Warn"
        }
        else {
            Write-Log "Email already subscribed to SNS topic" "Success"
        }
    }
    catch {
        Write-Log "Error setting up SNS topic: $_" "Error"
        throw
    }
}

#############################################################################
# AWS Budget Setup
#############################################################################

function Setup-Budget {
    Write-Log "Setting up AWS Budget: $BudgetName..." "Info"
    
    try {
        $budgets = aws budgets describe-budgets `
            --account-id $AccountId `
            --query "Budgets[?BudgetName=='$BudgetName'].BudgetName" `
            --output text
        
        if ([string]::IsNullOrEmpty($budgets)) {
            Write-Log "Creating new budget: $BudgetName" "Info"
            
            $budgetJson = @{
                BudgetName = $BudgetName
                BudgetLimit = @{
                    Amount = $BudgetLimit
                    Unit = "USD"
                }
                TimeUnit = "MONTHLY"
                BudgetType = "COST"
                CostFilters = @{
                    TagKeyValue = @("Project`$FormBridge")
                }
            } | ConvertTo-Json
            
            aws budgets create-budget `
                --account-id $AccountId `
                --budget $budgetJson `
                --profile $Profile 2>$null
        }
        else {
            Write-Log "Budget already exists. Updating notifications..." "Info"
        }
        
        # Set up notifications for 50%, 80%, 100%
        foreach ($threshold in @(50, 80, 100)) {
            try {
                $notifications = aws budgets describe-notifications-for-budget `
                    --account-id $AccountId `
                    --budget-name $BudgetName `
                    --query "Notifications[?NotificationThreshold==$threshold && NotificationType=='ACTUAL'].NotificationArn" `
                    --output text 2>$null
                
                if ([string]::IsNullOrEmpty($notifications)) {
                    Write-Log "Creating notification for $threshold% threshold..." "Info"
                    
                    $notificationJson = @{
                        NotificationType = "ACTUAL"
                        ComparisonOperator = "GREATER_THAN"
                        NotificationThreshold = $threshold
                        ThresholdType = "PERCENTAGE"
                    } | ConvertTo-Json
                    
                    $subscriberJson = @{
                        SubscriptionType = "SNS"
                        Address = $SnsTopicArn
                    } | ConvertTo-Json
                    
                    aws budgets create-notification `
                        --account-id $AccountId `
                        --budget-name $BudgetName `
                        --notification $notificationJson `
                        --subscriber $subscriberJson `
                        --profile $Profile 2>$null
                }
            }
            catch {
                Write-Log "Could not create notification for $threshold%: $_" "Warn"
            }
        }
        
        Write-Log "Budget '$BudgetName' configured with alerts at 50%, 80%, and 100%" "Success"
    }
    catch {
        Write-Log "Error setting up budget: $_" "Error"
        throw
    }
}

#############################################################################
# Tag Core Resources
#############################################################################

function Tag-CoreResources {
    Write-Log "Applying cost tags to FormBridge resources..." "Info"
    
    $tags = @("Key=Project,Value=FormBridge", "Key=Env,Value=Prod", "Key=Owner,Value=OmDeshpande")
    
    # Lambda functions
    Write-Log "Tagging Lambda functions..." "Info"
    foreach ($func in @("contactFormProcessor", "formbridgeWebhookDispatcher")) {
        try {
            $funcArn = aws lambda list-functions `
                --region $Region `
                --profile $Profile `
                --query "Functions[?FunctionName=='$func'].FunctionArn" `
                --output text
            
            if ($funcArn) {
                aws lambda tag-resource `
                    --resource $funcArn `
                    --tags $tags `
                    --region $Region `
                    --profile $Profile 2>$null
                
                Write-Log "Tagged Lambda: $func" "Success"
            }
        }
        catch {
            Write-Log "Could not tag Lambda $func" "Warn"
        }
    }
    
    # API Gateway
    Write-Log "Tagging API Gateway..." "Info"
    try {
        $apiId = aws apigateway get-rest-apis `
            --region $Region `
            --profile $Profile `
            --query "items[0].id" `
            --output text 2>$null
        
        if ($apiId -and $apiId -ne "None") {
            $apiArn = "arn:aws:apigateway:$Region`::/restapis/$apiId"
            aws apigateway tag-resource `
                --resource-arn $apiArn `
                --tags $tags `
                --region $Region `
                --profile $Profile 2>$null
            
            Write-Log "Tagged API Gateway: $apiId" "Success"
        }
    }
    catch {
        Write-Log "Could not tag API Gateway" "Warn"
    }
    
    # DynamoDB tables
    Write-Log "Tagging DynamoDB tables..." "Info"
    foreach ($table in @("contact-form-submissions", "formbridge-config")) {
        try {
            $tableArn = aws dynamodb describe-table `
                --table-name $table `
                --region $Region `
                --profile $Profile `
                --query "Table.TableArn" `
                --output text 2>$null
            
            if ($tableArn -and $tableArn -ne "None") {
                aws dynamodb tag-resource `
                    --resource-arn $tableArn `
                    --tags $tags `
                    --region $Region `
                    --profile $Profile 2>$null
                
                Write-Log "Tagged DynamoDB: $table" "Success"
            }
        }
        catch {
            Write-Log "Could not tag DynamoDB $table" "Warn"
        }
    }
    
    # SQS queues
    Write-Log "Tagging SQS queues..." "Info"
    foreach ($queue in @("formbridge-webhook-queue", "formbridge-webhook-dlq")) {
        try {
            $queueUrl = aws sqs get-queue-url `
                --queue-name $queue `
                --region $Region `
                --profile $Profile `
                --query QueueUrl `
                --output text 2>$null
            
            if ($queueUrl) {
                aws sqs tag-queue-url `
                    --queue-url $queueUrl `
                    --tags $tags `
                    --region $Region `
                    --profile $Profile 2>$null
                
                Write-Log "Tagged SQS: $queue" "Success"
            }
        }
        catch {
            Write-Log "Could not tag SQS $queue" "Warn"
        }
    }
}

#############################################################################
# Verify DynamoDB
#############################################################################

function Verify-DynamoDB {
    Write-Log "Verifying DynamoDB settings..." "Info"
    
    foreach ($table in @("contact-form-submissions", "formbridge-config")) {
        try {
            $tableDesc = aws dynamodb describe-table `
                --table-name $table `
                --region $Region `
                --profile $Profile `
                --output json 2>$null | ConvertFrom-Json
            
            # BillingMode
            $billingMode = $tableDesc.Table.BillingModeSummary.BillingMode ?? "PAY_PER_REQUEST"
            if ($billingMode -eq "PAY_PER_REQUEST") {
                Write-Log "✓ $table : BillingMode = $billingMode (good for variable load)" "Success"
            }
            else {
                Write-Log "✗ $table : BillingMode = $billingMode (consider ON_DEMAND)" "Warn"
            }
            
            # TTL
            $ttlStatus = $tableDesc.Table.TimeToLiveDescription.TimeToLiveStatus ?? "DISABLED"
            if ($ttlStatus -eq "ENABLED") {
                Write-Log "✓ $table : TTL = ENABLED (auto-cleanup enabled)" "Success"
            }
            else {
                Write-Log "✗ $table : TTL = $ttlStatus (consider enabling for cost opt)" "Warn"
            }
            
            # PITR
            $pitrStatus = $tableDesc.Table.ContinuousBackupsDescription.ContinuousBackupsStatus ?? "DISABLED"
            if ($pitrStatus -eq "DISABLED") {
                Write-Log "✓ $table : PITR = DISABLED (lower cost)" "Success"
            }
            else {
                Write-Log "  $table : PITR = $pitrStatus (adds cost)" "Info"
            }
        }
        catch {
            Write-Log "Table not found or error: $table" "Warn"
        }
    }
}

#############################################################################
# Verify SQS
#############################################################################

function Verify-SQS {
    Write-Log "Verifying SQS queue settings..." "Info"
    
    foreach ($queue in @("formbridge-webhook-queue", "formbridge-webhook-dlq")) {
        try {
            $queueUrl = aws sqs get-queue-url `
                --queue-name $queue `
                --region $Region `
                --profile $Profile `
                --query QueueUrl `
                --output text 2>$null
            
            if ($queueUrl) {
                $attrs = aws sqs get-queue-attributes `
                    --queue-url $queueUrl `
                    --attribute-names All `
                    --region $Region `
                    --profile $Profile `
                    --output json 2>$null | ConvertFrom-Json
                
                $retention = [int]($attrs.Attributes.MessageRetentionPeriod ?? 345600)
                $retentionDays = [math]::Floor($retention / 86400)
                Write-Log "  $queue : Retention = $retentionDays days" "Info"
                
                if ($queue -eq "formbridge-webhook-queue") {
                    $redrivePolicy = $attrs.Attributes.RedrivePolicy | ConvertFrom-Json
                    $maxReceives = $redrivePolicy.maxReceiveCount ?? 0
                    if ($maxReceives -eq 5) {
                        Write-Log "✓ $queue : maxReceiveCount = $maxReceives (good DLQ setup)" "Success"
                    }
                    else {
                        Write-Log "✗ $queue : maxReceiveCount = $maxReceives (consider 5)" "Warn"
                    }
                }
                
                $depth = $attrs.Attributes.ApproximateNumberOfMessages ?? "0"
                Write-Log "  $queue : Approximate depth = $depth messages" "Info"
            }
        }
        catch {
            Write-Log "Queue not found or error: $queue" "Warn"
        }
    }
}

#############################################################################
# Verify CloudWatch Alarms
#############################################################################

function Verify-CloudWatchAlarms {
    Write-Log "Verifying CloudWatch alarms..." "Info"
    
    try {
        $alarms = aws cloudwatch describe-alarms `
            --region $Region `
            --profile $Profile `
            --query "MetricAlarms[?contains(AlarmName, 'FormBridge') || contains(AlarmName, 'formbridge')]" `
            --output json 2>$null | ConvertFrom-Json
        
        if ($alarms -and $alarms.Count -gt 0) {
            Write-Log "Found $($alarms.Count) FormBridge CloudWatch alarms" "Success"
            
            foreach ($alarm in $alarms) {
                $tags = @("Key=Project,Value=FormBridge", "Key=Env,Value=Prod", "Key=Owner,Value=OmDeshpande")
                aws cloudwatch tag-resource `
                    --resource-arn $alarm.AlarmArn `
                    --tags $tags `
                    --region $Region `
                    --profile $Profile 2>$null
            }
        }
        else {
            Write-Log "No FormBridge CloudWatch alarms found" "Warn"
        }
    }
    catch {
        Write-Log "Error checking CloudWatch alarms: $_" "Warn"
    }
}

#############################################################################
# Print Summary
#############################################################################

function Print-Summary {
    Write-Host ""
    Write-Log "========================================" "Info"
    Write-Log "Cost Guardrails Setup Complete" "Info"
    Write-Log "========================================" "Info"
    Write-Host ""
    
    Write-Host "📊 Budget & Alerts:" -ForegroundColor Cyan
    Write-Host "  • Budget Name:        $BudgetName" -ForegroundColor Gray
    Write-Host "  • Monthly Limit:      USD $BudgetLimit" -ForegroundColor Gray
    Write-Host "  • Alert Thresholds:   50%, 80%, 100%" -ForegroundColor Gray
    Write-Host "  • SNS Topic:          $SnsTopicArn" -ForegroundColor Gray
    Write-Host "  • Alert Email:        $AlertEmail" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "🏷️  Tagging:" -ForegroundColor Cyan
    Write-Host "  • Project:            FormBridge" -ForegroundColor Gray
    Write-Host "  • Environment:        Prod" -ForegroundColor Gray
    Write-Host "  • Owner:              OmDeshpande" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "🔗 Useful Links:" -ForegroundColor Cyan
    Write-Host "  • AWS Budgets Console:" -ForegroundColor Gray
    Write-Host "    https://console.aws.amazon.com/budgets/home#/budgets" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  • Cost Explorer:" -ForegroundColor Gray
    Write-Host "    https://console.aws.amazon.com/cost-management/home#/custom" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  • CloudWatch Alarms:" -ForegroundColor Gray
    Write-Host "    https://console.aws.amazon.com/cloudwatch/home?region=$Region#alarmsV2:" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "✅ Next Steps:" -ForegroundColor Green
    Write-Host "  1. Confirm SNS email subscription (check your inbox)" -ForegroundColor Gray
    Write-Host "  2. Run verify-cost-posture.sh to audit current settings" -ForegroundColor Gray
    Write-Host "  3. Set up alerts on CloudWatch dashboard" -ForegroundColor Gray
    Write-Host ""
}

#############################################################################
# Main
#############################################################################

try {
    Write-Log "FormBridge Cost Guardrails Setup" "Info"
    Write-Host ""
    
    Validate-Inputs
    Write-Host ""
    
    Setup-SnsTopic
    Write-Host ""
    
    Setup-Budget
    Write-Host ""
    
    Tag-CoreResources
    Write-Host ""
    
    Verify-DynamoDB
    Write-Host ""
    
    Verify-SQS
    Write-Host ""
    
    Verify-CloudWatchAlarms
    Write-Host ""
    
    Print-Summary
}
catch {
    Write-Log "Fatal error: $_" "Error"
    exit 1
}
