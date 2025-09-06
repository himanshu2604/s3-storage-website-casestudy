# =============================================================================
# AWS S3 Lifecycle Management Utility Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Manage and monitor S3 lifecycle policies
# Author: Case Study Implementation
# Usage: .\manage-lifecycle.ps1 -Action "view|remove|update" -BucketName "bucket"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("view", "remove", "update", "status")]
    [string]$Action,
    
    [Parameter(Mandatory=$true)]
    [string]$BucketName
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

function Show-LifecyclePolicy {
    param([string]$Bucket)
    
    Write-Info "Retrieving lifecycle policy for bucket: $Bucket"
    
    try {
        $policy = aws s3api get-bucket-lifecycle-configuration --bucket $Bucket 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $policy) {
            Write-Success "Lifecycle policy found!"
            Write-Host "`n📋 Current Lifecycle Configuration:" -ForegroundColor Cyan
            Write-Host "===================================" -ForegroundColor Cyan
            
            # Pretty print the JSON policy
            $policy | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Out-Host
            
            # Parse and display rules in a readable format
            $policyObj = $policy | ConvertFrom-Json
            
            Write-Host "`n📊 Rules Summary:" -ForegroundColor Cyan
            Write-Host "=================" -ForegroundColor Cyan
            
            foreach ($rule in $policyObj.Rules) {
                Write-Host "`n🔹 Rule: $($rule.ID)" -ForegroundColor Yellow
                Write-Host "   Status: $($rule.Status)" -ForegroundColor Gray
                
                if ($rule.Filter.Prefix) {
                    Write-Host "   Prefix: '$($rule.Filter.Prefix)'" -ForegroundColor Gray
                } else {
                    Write-Host "   Prefix: All objects" -ForegroundColor Gray
                }
                
                if ($rule.Transitions) {
                    Write-Host "   Transitions:" -ForegroundColor Gray
                    foreach ($transition in $rule.Transitions) {
                        Write-Host "     - After $($transition.Days) days → $($transition.StorageClass)" -ForegroundColor Gray
                    }
                }
                
                if ($rule.Expiration) {
                    Write-Host "   Expiration: After $($rule.Expiration.Days) days" -ForegroundColor Gray
                }
                
                if ($rule.NoncurrentVersionTransitions) {
                    Write-Host "   Non-current Version Transitions:" -ForegroundColor Gray
                    foreach ($transition in $rule.NoncurrentVersionTransitions) {
                        Write-Host "     - After $($transition.NoncurrentDays) days → $($transition.StorageClass)" -ForegroundColor Gray
                    }
                }
                
                if ($rule.NoncurrentVersionExpiration) {
                    Write-Host "   Non-current Version Expiration: After $($rule.NoncurrentVersionExpiration.NoncurrentDays) days" -ForegroundColor Gray
                }
            }
            
        } else {
            Write-Warning "No lifecycle policy found for bucket: $Bucket"
        }
        
    } catch {
        Write-Error "Failed to retrieve lifecycle policy: $($_.Exception.Message)"
    }
}

function Remove-LifecyclePolicy {
    param([string]$Bucket)
    
    Write-Warning "Removing lifecycle policy from bucket: $Bucket"
    
    $confirm = Read-Host "Are you sure you want to remove the lifecycle policy? (y/N)"
    if ($confirm -ne 'y') {
        Write-Info "Operation cancelled"
        return
    }
    
    try {
        aws s3api delete-bucket-lifecycle --bucket $Bucket
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Lifecycle policy removed successfully!"
        } else {
            Write-Error "Failed to remove lifecycle policy"
        }
        
    } catch {
        Write-Error "Failed to remove lifecycle policy: $($_.Exception.Message)"
    }
}

function Show-BucketStatus {
    param([string]$Bucket)
    
    Write-Info "Getting comprehensive bucket status for: $Bucket"
    
    try {
        Write-Host "`n🔍 Bucket Analysis:" -ForegroundColor Cyan
        Write-Host "===================" -ForegroundColor Cyan
        
        # Check if bucket exists
        $bucketCheck = aws s3 ls "s3://$Bucket" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Bucket exists and is accessible"
        } else {
            Write-Error "Bucket does not exist or is not accessible"
            return
        }
        
        # Get bucket location
        $location = aws s3api get-bucket-location --bucket $Bucket --query "LocationConstraint" --output text
        if ($location -eq "None" -or $location -eq "null") { $location = "us-east-1" }
        Write-Info "Region: $location"
        
        # Check versioning
        $versioning = aws s3api get-bucket-versioning --bucket $Bucket --query "Status" --output text 2>$null
        if ($versioning) {
            Write-Info "Versioning: $versioning"
        } else {
            Write-Info "Versioning: Not configured"
        }
        
        # Check website hosting
        $website = aws s3api get-bucket-website --bucket $Bucket 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Website hosting: Enabled"
            $websiteObj = $website | ConvertFrom-Json
            Write-Info "  Index document: $($websiteObj.IndexDocument.Suffix)"
            if ($websiteObj.ErrorDocument) {
                Write-Info "  Error document: $($websiteObj.ErrorDocument.Key)"
            }
        } else {
            Write-Info "Website hosting: Disabled"
        }
        
        # Check lifecycle policy
        $lifecycle = aws s3api get-bucket-lifecycle-configuration --bucket $Bucket 2>$null
        if ($LASTEXITCODE -eq 0 -and $lifecycle) {
            Write-Success "Lifecycle policy: Configured"
            $lifecycleObj = $lifecycle | ConvertFrom-Json
            Write-Info "  Number of rules: $($lifecycleObj.Rules.Count)"
        } else {
            Write-Warning "Lifecycle policy: Not configured"
        }
        
        # Get object count and size (sample)
        Write-Info "Getting object statistics (this may take a moment)..."
        $objects = aws s3 ls "s3://$Bucket" --recursive --summarize 2>$null
        if ($LASTEXITCODE -eq 0 -and $objects) {
            $summary = $objects | Select-String -Pattern "Total (Objects|Size):"
            foreach ($line in $summary) {
                Write-Info "  $line"
            }
        } else {
            Write-Info "  No objects found or unable to retrieve statistics"
        }
        
    } catch {
        Write-Error "Failed to get bucket status: $($_.Exception.Message)"
    }
}

function Update-LifecyclePolicy {
    param([string]$Bucket)
    
    Write-Info "Updating lifecycle policy for bucket: $Bucket"
    Write-Warning "This will launch the setup script to update the policy"
    
    $scriptPath = Join-Path (Split-Path $MyInvocation.PSCommandPath -Parent) "setup-lifecycle-policy.ps1"
    
    if (Test-Path $scriptPath) {
        Write-Info "Launching setup script: $scriptPath"
        & $scriptPath -BucketName $Bucket
    } else {
        Write-Error "Setup script not found at: $scriptPath"
        Write-Info "Please run the setup-lifecycle-policy.ps1 script manually"
    }
}

# Main execution
Write-Info "AWS S3 Lifecycle Management Utility"
Write-Info "Action: $Action"
Write-Info "Target Bucket: $BucketName"

# Verify AWS CLI is available
$awsCheck = aws --version 2>$null
if (-not $awsCheck) {
    Write-Error "AWS CLI is not installed or not in PATH"
    exit 1
}

try {
    switch ($Action) {
        "view" {
            Show-LifecyclePolicy -Bucket $BucketName
        }
        "remove" {
            Remove-LifecyclePolicy -Bucket $BucketName
        }
        "update" {
            Update-LifecyclePolicy -Bucket $BucketName
        }
        "status" {
            Show-BucketStatus -Bucket $BucketName
        }
    }
    
    Write-Success "Operation completed successfully!"
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
