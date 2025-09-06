# =============================================================================
# AWS S3 Version Management Utility Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Manage S3 object versions (list, restore, cleanup)
# Author: Case Study Implementation
# Usage: .\manage-versions.ps1 -Action "list|restore|cleanup" -BucketName "bucket"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("list", "restore", "cleanup", "info")]
    [string]$Action,
    
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [string]$ObjectKey = "",
    
    [Parameter(Mandatory=$false)]
    [string]$VersionId = "",
    
    [Parameter(Mandatory=$false)]
    [int]$MaxVersions = 100
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

function List-ObjectVersions {
    param(
        [string]$Bucket,
        [string]$Key = "",
        [int]$MaxItems = 100
    )
    
    Write-Info "Listing object versions..."
    
    try {
        if ($Key) {
            Write-Info "Filtering by object key: $Key"
            $versions = aws s3api list-object-versions --bucket $Bucket --prefix $Key --max-items $MaxItems
        } else {
            Write-Info "Listing all object versions in bucket (first $MaxItems items)"
            $versions = aws s3api list-object-versions --bucket $Bucket --max-items $MaxItems
        }
        
        if ($LASTEXITCODE -eq 0 -and $versions) {
            $versionObj = $versions | ConvertFrom-Json
            
            Write-Host "`n📋 Object Versions:" -ForegroundColor Cyan
            Write-Host "===================" -ForegroundColor Cyan
            
            if ($versionObj.Versions -and $versionObj.Versions.Count -gt 0) {
                Write-Success "Found $($versionObj.Versions.Count) object versions"
                
                # Group versions by key for better display
                $groupedVersions = $versionObj.Versions | Group-Object Key
                
                foreach ($group in $groupedVersions) {
                    Write-Host "`n🔹 Object: $($group.Name)" -ForegroundColor Yellow
                    
                    # Sort versions by LastModified (newest first)
                    $sortedVersions = $group.Group | Sort-Object LastModified -Descending
                    
                    for ($i = 0; $i -lt $sortedVersions.Count; $i++) {
                        $version = $sortedVersions[$i]
                        $isLatest = $version.IsLatest
                        $status = if ($isLatest) { "CURRENT" } else { "VERSION" }
                        $statusColor = if ($isLatest) { "Green" } else { "Gray" }
                        
                        Write-Host "   [$($i + 1)] $status - Version ID: $($version.VersionId)" -ForegroundColor $statusColor
                        Write-Host "       Size: $($version.Size) bytes | Modified: $($version.LastModified)" -ForegroundColor Gray
                        Write-Host "       Storage Class: $($version.StorageClass) | ETag: $($version.ETag)" -ForegroundColor Gray
                        
                        if ($version.Owner) {
                            Write-Host "       Owner: $($version.Owner.DisplayName) ($($version.Owner.ID))" -ForegroundColor Gray
                        }
                        Write-Host "" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Warning "No object versions found"
            }
            
            # Show delete markers if any
            if ($versionObj.DeleteMarkers -and $versionObj.DeleteMarkers.Count -gt 0) {
                Write-Host "`n🗑️  Delete Markers:" -ForegroundColor Red
                Write-Host "===================" -ForegroundColor Red
                Write-Warning "Found $($versionObj.DeleteMarkers.Count) delete markers"
                
                foreach ($marker in $versionObj.DeleteMarkers) {
                    Write-Host "   Object: $($marker.Key)" -ForegroundColor Red
                    Write-Host "   Version ID: $($marker.VersionId)" -ForegroundColor Gray
                    Write-Host "   Created: $($marker.LastModified)" -ForegroundColor Gray
                    Write-Host "" -ForegroundColor Gray
                }
            }
            
        } else {
            Write-Warning "No versions found or unable to retrieve version information"
        }
        
    } catch {
        Write-Error "Failed to list object versions: $($_.Exception.Message)"
    }
}

function Restore-ObjectVersion {
    param(
        [string]$Bucket,
        [string]$Key,
        [string]$VersionId
    )
    
    if (-not $Key) {
        Write-Error "Object key is required for restore operation"
        return
    }
    
    if (-not $VersionId) {
        Write-Error "Version ID is required for restore operation"
        return
    }
    
    Write-Info "Restoring object version..."
    Write-Info "Bucket: $Bucket"
    Write-Info "Object: $Key"
    Write-Info "Version ID: $VersionId"
    
    try {
        # First, verify the version exists
        Write-Info "Verifying version exists..."
        $versionCheck = aws s3api head-object --bucket $Bucket --key $Key --version-id $VersionId 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Version not found or not accessible"
            return
        }
        
        Write-Success "Version verified"
        
        # Download the specific version to a temporary file
        $tempFile = "temp_restore_$([System.IO.Path]::GetRandomFileName())"
        Write-Info "Downloading version to temporary file..."
        
        aws s3api get-object --bucket $Bucket --key $Key --version-id $VersionId $tempFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Version downloaded successfully"
            
            # Re-upload to restore as the current version
            Write-Info "Restoring as current version..."
            aws s3 cp $tempFile "s3://$Bucket/$Key"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Object version restored successfully!"
                Write-Info "The specified version is now the current version of the object"
            } else {
                Write-Error "Failed to restore version as current object"
            }
            
            # Clean up temporary file
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            
        } else {
            Write-Error "Failed to download the specified version"
        }
        
    } catch {
        Write-Error "Failed to restore object version: $($_.Exception.Message)"
        # Clean up temporary file if it exists
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }
}

function Cleanup-OldVersions {
    param(
        [string]$Bucket,
        [string]$Key = ""
    )
    
    Write-Warning "This operation will delete old versions of objects (keeping only the current version)"
    
    if ($Key) {
        Write-Info "Target object: $Key"
    } else {
        Write-Info "Target: All objects in bucket"
    }
    
    $confirm = Read-Host "Are you sure you want to proceed? (y/N)"
    if ($confirm -ne 'y') {
        Write-Info "Operation cancelled"
        return
    }
    
    try {
        Write-Info "Retrieving object versions for cleanup..."
        
        if ($Key) {
            $versions = aws s3api list-object-versions --bucket $Bucket --prefix $Key
        } else {
            $versions = aws s3api list-object-versions --bucket $Bucket
        }
        
        if ($LASTEXITCODE -eq 0 -and $versions) {
            $versionObj = $versions | ConvertFrom-Json
            
            if ($versionObj.Versions -and $versionObj.Versions.Count -gt 0) {
                # Filter out current versions (IsLatest = true)
                $oldVersions = $versionObj.Versions | Where-Object { -not $_.IsLatest }
                
                if ($oldVersions.Count -gt 0) {
                    Write-Warning "Found $($oldVersions.Count) old versions to delete"
                    
                    foreach ($version in $oldVersions) {
                        Write-Info "Deleting version: $($version.Key) (Version: $($version.VersionId))"
                        aws s3api delete-object --bucket $Bucket --key $version.Key --version-id $version.VersionId
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "✓ Deleted version of $($version.Key)"
                        } else {
                            Write-Warning "✗ Failed to delete version of $($version.Key)"
                        }
                    }
                    
                    Write-Success "Old version cleanup completed!"
                } else {
                    Write-Info "No old versions found to clean up"
                }
            } else {
                Write-Info "No versions found"
            }
            
            # Clean up delete markers as well
            if ($versionObj.DeleteMarkers -and $versionObj.DeleteMarkers.Count -gt 0) {
                Write-Info "Cleaning up delete markers..."
                
                foreach ($marker in $versionObj.DeleteMarkers) {
                    Write-Info "Removing delete marker for: $($marker.Key)"
                    aws s3api delete-object --bucket $Bucket --key $marker.Key --version-id $marker.VersionId
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "✓ Removed delete marker for $($marker.Key)"
                    } else {
                        Write-Warning "✗ Failed to remove delete marker for $($marker.Key)"
                    }
                }
            }
            
        } else {
            Write-Warning "No versions found or unable to retrieve version information"
        }
        
    } catch {
        Write-Error "Failed to cleanup old versions: $($_.Exception.Message)"
    }
}

function Show-VersioningInfo {
    param([string]$Bucket)
    
    Write-Info "Getting versioning information for bucket: $Bucket"
    
    try {
        # Get versioning configuration
        $versioningConfig = aws s3api get-bucket-versioning --bucket $Bucket
        
        Write-Host "`n📊 Versioning Configuration:" -ForegroundColor Cyan
        Write-Host "=============================" -ForegroundColor Cyan
        
        if ($LASTEXITCODE -eq 0 -and $versioningConfig) {
            $configObj = $versioningConfig | ConvertFrom-Json
            
            if ($configObj.Status) {
                Write-Success "Versioning Status: $($configObj.Status)"
            } else {
                Write-Warning "Versioning Status: Never Enabled"
            }
            
            if ($configObj.MfaDelete) {
                Write-Info "MFA Delete: $($configObj.MfaDelete)"
            }
        }
        
        # Get summary statistics
        Write-Info "Getting version statistics (this may take a moment)..."
        $allVersions = aws s3api list-object-versions --bucket $Bucket
        
        if ($LASTEXITCODE -eq 0 -and $allVersions) {
            $versionObj = $allVersions | ConvertFrom-Json
            
            Write-Host "`n📈 Version Statistics:" -ForegroundColor Cyan
            Write-Host "======================" -ForegroundColor Cyan
            
            $totalVersions = if ($versionObj.Versions) { $versionObj.Versions.Count } else { 0 }
            $currentVersions = if ($versionObj.Versions) { ($versionObj.Versions | Where-Object IsLatest).Count } else { 0 }
            $oldVersions = $totalVersions - $currentVersions
            $deleteMarkers = if ($versionObj.DeleteMarkers) { $versionObj.DeleteMarkers.Count } else { 0 }
            
            Write-Info "Total Versions: $totalVersions"
            Write-Info "Current Versions: $currentVersions"
            Write-Info "Old Versions: $oldVersions"
            Write-Info "Delete Markers: $deleteMarkers"
            
            if ($totalVersions -gt 0) {
                # Calculate storage usage by version type
                $totalSize = ($versionObj.Versions | Measure-Object -Property Size -Sum).Sum
                $currentSize = ($versionObj.Versions | Where-Object IsLatest | Measure-Object -Property Size -Sum).Sum
                $oldSize = $totalSize - $currentSize
                
                Write-Host "`n💾 Storage Usage:" -ForegroundColor Cyan
                Write-Host "=================" -ForegroundColor Cyan
                Write-Info "Total Storage: $([Math]::Round($totalSize / 1MB, 2)) MB"
                Write-Info "Current Versions: $([Math]::Round($currentSize / 1MB, 2)) MB"
                Write-Info "Old Versions: $([Math]::Round($oldSize / 1MB, 2)) MB"
                
                if ($oldSize -gt 0) {
                    $oldPercentage = [Math]::Round(($oldSize / $totalSize) * 100, 1)
                    Write-Warning "Old versions represent $oldPercentage% of total storage"
                }
            }
        }
        
    } catch {
        Write-Error "Failed to get versioning information: $($_.Exception.Message)"
    }
}

# Main execution
Write-Info "AWS S3 Version Management Utility"
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
        "list" {
            List-ObjectVersions -Bucket $BucketName -Key $ObjectKey -MaxItems $MaxVersions
        }
        "restore" {
            Restore-ObjectVersion -Bucket $BucketName -Key $ObjectKey -VersionId $VersionId
        }
        "cleanup" {
            Cleanup-OldVersions -Bucket $BucketName -Key $ObjectKey
        }
        "info" {
            Show-VersioningInfo -Bucket $BucketName
        }
    }
    
    Write-Success "Operation completed successfully!"
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
