# =============================================================================
# AWS S3 Lifecycle Policy Setup Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Automate S3 lifecycle policy configuration for cost optimization
# Author: Case Study Implementation
# Usage: .\setup-lifecycle-policy.ps1 -BucketName "your-bucket-name"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [int]$StandardToIA = 30,
    
    [Parameter(Mandatory=$false)]
    [int]$IAToGlacier = 60,
    
    [Parameter(Mandatory=$false)]
    [int]$DeleteAfterDays = 75,
    
    [Parameter(Mandatory=$false)]
    [string]$RulePrefix = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeVersioning = $false
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Info "Setting up S3 Lifecycle Policy..."
Write-Info "Target Bucket: $BucketName"
Write-Info "Storage Transitions:"
Write-Info "  - Standard to Standard-IA: $StandardToIA days"
Write-Info "  - Standard-IA to Glacier: $IAToGlacier days"
Write-Info "  - Delete after: $DeleteAfterDays days"

try {
    # Verify bucket exists
    Write-Info "Verifying bucket exists..."
    $bucketCheck = aws s3 ls "s3://$BucketName" 2>$null
    if (-not $bucketCheck -and $LASTEXITCODE -ne 0) {
        Write-Error "Bucket '$BucketName' does not exist or is not accessible"
        exit 1
    }
    Write-Success "Bucket verified successfully"

    # Create lifecycle policy JSON
    Write-Info "Creating lifecycle policy configuration..."
    
    $lifecyclePolicy = @"
{
    "Rules": [
        {
            "ID": "XYZ-Corp-Storage-Management-Rule",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "$RulePrefix"
            },
            "Transitions": [
                {
                    "Days": $StandardToIA,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "Days": $IAToGlacier,
                    "StorageClass": "GLACIER"
                }
            ],
            "Expiration": {
                "Days": $DeleteAfterDays
            }
        }
"@

    # Add non-current version rules if versioning is enabled
    if ($IncludeVersioning) {
        Write-Info "Including versioning lifecycle rules..."
        $lifecyclePolicy += @"
,
        {
            "ID": "XYZ-Corp-Version-Management-Rule",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "$RulePrefix"
            },
            "NoncurrentVersionTransitions": [
                {
                    "NoncurrentDays": $StandardToIA,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "NoncurrentDays": $IAToGlacier,
                    "StorageClass": "GLACIER"
                }
            ],
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": $DeleteAfterDays
            }
        }
"@
    }

    $lifecyclePolicy += @"

    ]
}
"@

    # Save policy to temporary file
    $policyFile = "temp_lifecycle_policy_$BucketName.json"
    $lifecyclePolicy | Out-File -FilePath $policyFile -Encoding UTF8
    
    Write-Info "Policy file created: $policyFile"
    Write-Info "Policy content preview:"
    Write-Host "------------------------" -ForegroundColor Gray
    Get-Content $policyFile | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    Write-Host "------------------------" -ForegroundColor Gray

    # Apply lifecycle policy
    Write-Info "Applying lifecycle policy to bucket..."
    aws s3api put-bucket-lifecycle-configuration --bucket $BucketName --lifecycle-configuration "file://$policyFile"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Lifecycle policy applied successfully!"
    } else {
        Write-Error "Failed to apply lifecycle policy"
        Remove-Item $policyFile -ErrorAction SilentlyContinue
        exit 1
    }

    # Verify policy application
    Write-Info "Verifying lifecycle policy..."
    $appliedPolicy = aws s3api get-bucket-lifecycle-configuration --bucket $BucketName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Lifecycle policy verification successful!"
    } else {
        Write-Warning "Could not verify lifecycle policy (might still be applied correctly)"
    }

    # Calculate estimated cost savings
    Write-Host "`n💰 Estimated Cost Savings:" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Info "Standard Storage (0-$StandardToIA days): Full cost"
    Write-Info "Standard-IA Storage ($StandardToIA-$IAToGlacier days): ~40% cost reduction"
    Write-Info "Glacier Storage ($IAToGlacier-$DeleteAfterDays days): ~68% cost reduction"
    Write-Info "Automatic deletion after $DeleteAfterDays days: 100% cost reduction"
    Write-Success "Estimated overall savings: 40-60% reduction in storage costs"

    # Clean up temporary policy file
    Remove-Item $policyFile -ErrorAction SilentlyContinue
    
    Write-Success "Lifecycle policy setup completed successfully!"
    Write-Info "Objects uploaded to this bucket will now follow the configured lifecycle rules"

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    # Clean up on error
    if (Test-Path "temp_lifecycle_policy_$BucketName.json") {
        Remove-Item "temp_lifecycle_policy_$BucketName.json" -ErrorAction SilentlyContinue
    }
    exit 1
}
