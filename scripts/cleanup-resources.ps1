# =============================================================================
# AWS S3 Resources Cleanup Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Clean up S3 resources, test files, and temporary configurations
# Author: Case Study Implementation
# Usage: .\cleanup-resources.ps1 -BucketName "your-bucket-name"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("objects", "policies", "configs", "bucket", "all")]
    [string]$CleanupType = "objects",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Title { param($Message) Write-Host "`n🧹 $Message" -ForegroundColor Cyan; Write-Host ("=" * ($Message.Length + 3)) -ForegroundColor Cyan }

# Cleanup statistics
$script:CleanupStats = @{
    ObjectsDeleted = 0
    VersionsDeleted = 0
    PoliciesRemoved = 0
    ConfigsRemoved = 0
    Errors = 0
}

function Confirm-Action {
    param(
        [string]$Message,
        [string]$WarningMessage = ""
    )
    
    if ($Force) {
        return $true
    }
    
    if ($WarningMessage) {
        Write-Warning $WarningMessage
    }
    
    $response = Read-Host "$Message (y/N)"
    return ($response -eq 'y' -or $response -eq 'yes')
}

function Remove-AllObjects {
    Write-Title "Cleaning Up S3 Objects"
    
    try {
        # Get all objects including versions
        Write-Info "Retrieving object list..."
        $objects = aws s3api list-object-versions --bucket $BucketName 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $objects) {
            $objectData = $objects | ConvertFrom-Json
            
            # Count objects and versions
            $totalObjects = 0
            $totalVersions = 0
            
            if ($objectData.Versions) {
                $totalVersions = $objectData.Versions.Count
                $totalObjects = ($objectData.Versions | Where-Object IsLatest).Count
            }
            
            $totalDeleteMarkers = 0
            if ($objectData.DeleteMarkers) {
                $totalDeleteMarkers = $objectData.DeleteMarkers.Count
            }
            
            Write-Info "Found:"
            Write-Info "  - Current objects: $totalObjects"
            Write-Info "  - Total versions: $totalVersions"
            Write-Info "  - Delete markers: $totalDeleteMarkers"
            
            if ($totalVersions -eq 0 -and $totalDeleteMarkers -eq 0) {
                Write-Info "No objects to clean up"
                return
            }
            
            if (-not (Confirm-Action "Do you want to delete all objects and versions?" "This action cannot be undone!")) {
                Write-Info "Object cleanup cancelled"
                return
            }
            
            if ($DryRun) {
                Write-Warning "DRY RUN: Would delete $totalVersions versions and $totalDeleteMarkers delete markers"
                return
            }
            
            # Delete all versions
            if ($objectData.Versions) {
                Write-Info "Deleting object versions..."
                foreach ($version in $objectData.Versions) {
                    Write-Info "Deleting: $($version.Key) (Version: $($version.VersionId))"
                    aws s3api delete-object --bucket $BucketName --key $version.Key --version-id $version.VersionId 2>$null
                    
                    if ($LASTEXITCODE -eq 0) {
                        $script:CleanupStats.VersionsDeleted++
                        if ($version.IsLatest) {
                            $script:CleanupStats.ObjectsDeleted++
                        }
                    } else {
                        Write-Warning "Failed to delete: $($version.Key)"
                        $script:CleanupStats.Errors++
                    }
                }
            }
            
            # Delete all delete markers
            if ($objectData.DeleteMarkers) {
                Write-Info "Removing delete markers..."
                foreach ($marker in $objectData.DeleteMarkers) {
                    Write-Info "Removing delete marker: $($marker.Key)"
                    aws s3api delete-object --bucket $BucketName --key $marker.Key --version-id $marker.VersionId 2>$null
                    
                    if ($LASTEXITCODE -eq 0) {
                        $script:CleanupStats.VersionsDeleted++
                    } else {
                        Write-Warning "Failed to remove delete marker: $($marker.Key)"
                        $script:CleanupStats.Errors++
                    }
                }
            }
            
            Write-Success "Object cleanup completed"
            
        } else {
            Write-Info "No objects found in bucket"
        }
        
    } catch {
        Write-Error "Error during object cleanup: $($_.Exception.Message)"
        $script:CleanupStats.Errors++
    }
}

function Remove-BucketPolicies {
    Write-Title "Cleaning Up Bucket Policies"
    
    try {
        # Check if bucket policy exists
        $policy = aws s3api get-bucket-policy --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0 -and $policy) {
            Write-Info "Bucket policy found"
            
            if (-not (Confirm-Action "Do you want to remove the bucket policy?")) {
                Write-Info "Policy cleanup cancelled"
                return
            }
            
            if ($DryRun) {
                Write-Warning "DRY RUN: Would remove bucket policy"
                return
            }
            
            aws s3api delete-bucket-policy --bucket $BucketName
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Bucket policy removed"
                $script:CleanupStats.PoliciesRemoved++
            } else {
                Write-Warning "Failed to remove bucket policy"
                $script:CleanupStats.Errors++
            }
        } else {
            Write-Info "No bucket policy found"
        }
        
    } catch {
        Write-Error "Error removing bucket policy: $($_.Exception.Message)"
        $script:CleanupStats.Errors++
    }
}

function Remove-BucketConfigurations {
    Write-Title "Cleaning Up Bucket Configurations"
    
    try {
        # Remove website hosting configuration
        Write-Info "Checking website hosting configuration..."
        $website = aws s3api get-bucket-website --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Website hosting configuration found"
            
            if (Confirm-Action "Remove website hosting configuration?") {
                if (-not $DryRun) {
                    aws s3api delete-bucket-website --bucket $BucketName
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Website hosting configuration removed"
                        $script:CleanupStats.ConfigsRemoved++
                    } else {
                        Write-Warning "Failed to remove website hosting configuration"
                        $script:CleanupStats.Errors++
                    }
                } else {
                    Write-Warning "DRY RUN: Would remove website hosting configuration"
                }
            }
        } else {
            Write-Info "No website hosting configuration found"
        }
        
        # Remove CORS configuration
        Write-Info "Checking CORS configuration..."
        $cors = aws s3api get-bucket-cors --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "CORS configuration found"
            
            if (Confirm-Action "Remove CORS configuration?") {
                if (-not $DryRun) {
                    aws s3api delete-bucket-cors --bucket $BucketName
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "CORS configuration removed"
                        $script:CleanupStats.ConfigsRemoved++
                    } else {
                        Write-Warning "Failed to remove CORS configuration"
                        $script:CleanupStats.Errors++
                    }
                } else {
                    Write-Warning "DRY RUN: Would remove CORS configuration"
                }
            }
        } else {
            Write-Info "No CORS configuration found"
        }
        
        # Remove lifecycle configuration
        Write-Info "Checking lifecycle configuration..."
        $lifecycle = aws s3api get-bucket-lifecycle-configuration --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Lifecycle configuration found"
            
            if (Confirm-Action "Remove lifecycle configuration?") {
                if (-not $DryRun) {
                    aws s3api delete-bucket-lifecycle --bucket $BucketName
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Lifecycle configuration removed"
                        $script:CleanupStats.ConfigsRemoved++
                    } else {
                        Write-Warning "Failed to remove lifecycle configuration"
                        $script:CleanupStats.Errors++
                    }
                } else {
                    Write-Warning "DRY RUN: Would remove lifecycle configuration"
                }
            }
        } else {
            Write-Info "No lifecycle configuration found"
        }
        
        # Note: Versioning cannot be disabled, only suspended
        $versioning = aws s3api get-bucket-versioning --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0) {
            $versionObj = $versioning | ConvertFrom-Json
            if ($versionObj.Status -eq "Enabled") {
                Write-Warning "Versioning is enabled - it can be suspended but not fully disabled"
                
                if (Confirm-Action "Suspend versioning?") {
                    if (-not $DryRun) {
                        aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=Suspended
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "Versioning suspended"
                            $script:CleanupStats.ConfigsRemoved++
                        } else {
                            Write-Warning "Failed to suspend versioning"
                            $script:CleanupStats.Errors++
                        }
                    } else {
                        Write-Warning "DRY RUN: Would suspend versioning"
                    }
                }
            }
        }
        
    } catch {
        Write-Error "Error removing bucket configurations: $($_.Exception.Message)"
        $script:CleanupStats.Errors++
    }
}

function Remove-Bucket {
    Write-Title "Removing S3 Bucket"
    
    try {
        if (-not (Confirm-Action "Do you want to DELETE the entire bucket '$BucketName'?" "This will permanently delete the bucket and cannot be undone!")) {
            Write-Info "Bucket deletion cancelled"
            return
        }
        
        if ($DryRun) {
            Write-Warning "DRY RUN: Would delete bucket '$BucketName'"
            return
        }
        
        Write-Info "Attempting to delete bucket..."
        aws s3 rb "s3://$BucketName" --force
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Bucket '$BucketName' deleted successfully"
        } else {
            Write-Error "Failed to delete bucket - ensure it's empty first"
            $script:CleanupStats.Errors++
        }
        
    } catch {
        Write-Error "Error deleting bucket: $($_.Exception.Message)"
        $script:CleanupStats.Errors++
    }
}

function Clean-LocalTempFiles {
    Write-Title "Cleaning Up Local Temporary Files"
    
    try {
        $tempPatterns = @(
            "temp_policy_*.json",
            "temp_cors_*.json",
            "temp_lifecycle_policy_*.json",
            "temp_logging_*.json",
            "temp_website_policy_*.json",
            "validation-test-*.txt",
            "downloaded_validation-test-*.txt"
        )
        
        $deletedFiles = 0
        
        foreach ($pattern in $tempPatterns) {
            $files = Get-ChildItem -Path "." -Name $pattern -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                if ($DryRun) {
                    Write-Warning "DRY RUN: Would delete local file: $file"
                } else {
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                    if (-not (Test-Path $file)) {
                        Write-Success "Deleted local temp file: $file"
                        $deletedFiles++
                    }
                }
            }
        }
        
        if ($deletedFiles -eq 0 -and -not $DryRun) {
            Write-Info "No temporary files found to clean up"
        } elseif (-not $DryRun) {
            Write-Success "Cleaned up $deletedFiles local temporary files"
        }
        
    } catch {
        Write-Error "Error cleaning local temp files: $($_.Exception.Message)"
    }
}

# Main execution
Write-Host "🧹 AWS S3 Resources Cleanup Utility" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Info "Target Bucket: $BucketName"
Write-Info "Cleanup Type: $CleanupType"
Write-Info "Dry Run: $(if ($DryRun) { 'Yes' } else { 'No' })"
Write-Info "Force Mode: $(if ($Force) { 'Yes' } else { 'No' })"

# Verify AWS CLI is available
$awsCheck = aws --version 2>$null
if (-not $awsCheck) {
    Write-Error "AWS CLI is not installed or not in PATH"
    exit 1
}

# Verify bucket exists (unless we're cleaning up everything)
if ($CleanupType -ne "bucket") {
    $bucketCheck = aws s3 ls "s3://$BucketName" 2>$null
    if (-not $bucketCheck -and $LASTEXITCODE -ne 0) {
        Write-Error "Bucket '$BucketName' does not exist or is not accessible"
        exit 1
    }
    Write-Success "Bucket verified successfully"
}

try {
    # Execute cleanup based on type
    switch ($CleanupType) {
        "objects" {
            Remove-AllObjects
        }
        "policies" {
            Remove-BucketPolicies
        }
        "configs" {
            Remove-BucketConfigurations
        }
        "bucket" {
            Remove-AllObjects
            Remove-BucketPolicies
            Remove-BucketConfigurations
            Remove-Bucket
        }
        "all" {
            Remove-AllObjects
            Remove-BucketPolicies
            Remove-BucketConfigurations
            Clean-LocalTempFiles
            # Note: Not deleting bucket in 'all' mode for safety
            Write-Info "Use 'bucket' cleanup type to delete the bucket itself"
        }
    }
    
    # Always clean up local temp files
    if ($CleanupType -ne "objects" -and $CleanupType -ne "policies") {
        Clean-LocalTempFiles
    }
    
    # Display cleanup summary
    Write-Host "`n📊 Cleanup Summary" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    if ($DryRun) {
        Write-Warning "This was a DRY RUN - no actual changes were made"
    } else {
        Write-Success "Objects Deleted: $($script:CleanupStats.ObjectsDeleted)"
        Write-Success "Versions Deleted: $($script:CleanupStats.VersionsDeleted)"
        Write-Success "Policies Removed: $($script:CleanupStats.PoliciesRemoved)"
        Write-Success "Configurations Removed: $($script:CleanupStats.ConfigsRemoved)"
        
        if ($script:CleanupStats.Errors -gt 0) {
            Write-Error "Errors Encountered: $($script:CleanupStats.Errors)"
        }
    }
    
    if ($DryRun) {
        Write-Info "Run without -DryRun to perform actual cleanup"
    } else {
        Write-Success "Cleanup completed successfully!"
    }
    
} catch {
    Write-Error "Cleanup failed with error: $($_.Exception.Message)"
    exit 1
}
