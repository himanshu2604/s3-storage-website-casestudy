# =============================================================================
# AWS S3 Versioning Setup Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Enable and configure S3 bucket versioning for data protection
# Author: Case Study Implementation
# Usage: .\enable-versioning.ps1 -BucketName "your-bucket-name"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Enabled", "Suspended")]
    [string]$Status = "Enabled",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableMFA = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$MFASerial = ""
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Info "AWS S3 Versioning Configuration"
Write-Info "Target Bucket: $BucketName"
Write-Info "Versioning Status: $Status"

try {
    # Verify AWS CLI is available
    $awsCheck = aws --version 2>$null
    if (-not $awsCheck) {
        Write-Error "AWS CLI is not installed or not in PATH"
        exit 1
    }
    Write-Success "AWS CLI is available"

    # Verify bucket exists
    Write-Info "Verifying bucket exists..."
    $bucketCheck = aws s3 ls "s3://$BucketName" 2>$null
    if (-not $bucketCheck -and $LASTEXITCODE -ne 0) {
        Write-Error "Bucket '$BucketName' does not exist or is not accessible"
        exit 1
    }
    Write-Success "Bucket verified successfully"

    # Get current versioning status
    Write-Info "Checking current versioning status..."
    $currentStatus = aws s3api get-bucket-versioning --bucket $BucketName --query "Status" --output text 2>$null
    
    if (-not $currentStatus -or $currentStatus -eq "null") {
        $currentStatus = "Never Enabled"
    }
    
    Write-Info "Current versioning status: $currentStatus"

    # Enable or configure versioning
    Write-Info "Configuring versioning status to: $Status"
    
    if ($EnableMFA -and $MFASerial) {
        Write-Warning "MFA delete protection requested"
        Write-Info "MFA Serial: $MFASerial"
        
        # For MFA, user needs to provide token interactively
        $mfaToken = Read-Host "Enter MFA token code"
        
        aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=$Status,MfaDelete=Enabled --mfa "$MFASerial $mfaToken"
    } else {
        aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=$Status
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Versioning configuration applied successfully!"
    } else {
        Write-Error "Failed to configure versioning"
        exit 1
    }

    # Verify the configuration
    Write-Info "Verifying versioning configuration..."
    $newStatus = aws s3api get-bucket-versioning --bucket $BucketName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Versioning verification successful!"
        Write-Host "`n📋 Current Versioning Configuration:" -ForegroundColor Cyan
        Write-Host "====================================" -ForegroundColor Cyan
        
        $versioningObj = $newStatus | ConvertFrom-Json
        Write-Info "Status: $($versioningObj.Status)"
        
        if ($versioningObj.MfaDelete) {
            Write-Info "MFA Delete: $($versioningObj.MfaDelete)"
        }
    } else {
        Write-Warning "Could not verify versioning configuration"
    }

    # Display versioning benefits and information
    Write-Host "`n💡 Versioning Benefits:" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Success "✅ Protection against accidental deletion"
    Write-Success "✅ Protection against accidental overwrites"
    Write-Success "✅ Ability to restore previous versions"
    Write-Success "✅ Maintain object history for compliance"
    Write-Success "✅ Enhanced data durability"

    Write-Host "`n⚠️  Important Notes:" -ForegroundColor Yellow
    Write-Host "===================" -ForegroundColor Yellow
    Write-Warning "⚠️  Versioning cannot be fully disabled, only suspended"
    Write-Warning "⚠️  Each version is stored and billed separately"
    Write-Warning "⚠️  Use lifecycle policies to manage version costs"
    Write-Warning "⚠️  Consider MFA delete for critical buckets"

    if ($Status -eq "Enabled") {
        Write-Host "`n🔧 Next Steps:" -ForegroundColor Cyan
        Write-Host "==============" -ForegroundColor Cyan
        Write-Info "1. Upload test files to verify versioning works"
        Write-Info "2. Configure lifecycle policies for version management"
        Write-Info "3. Set up monitoring for version metrics"
        Write-Info "4. Test version recovery procedures"
        Write-Info "5. Document versioning procedures for your team"

        # Provide example commands
        Write-Host "`n📝 Example Usage:" -ForegroundColor Cyan
        Write-Host "=================" -ForegroundColor Cyan
        Write-Host "# List all versions of an object:" -ForegroundColor Gray
        Write-Host "aws s3api list-object-versions --bucket $BucketName --prefix filename.ext" -ForegroundColor Gray
        Write-Host "" -ForegroundColor Gray
        Write-Host "# Get a specific version of an object:" -ForegroundColor Gray
        Write-Host "aws s3api get-object --bucket $BucketName --key filename.ext --version-id VERSION_ID local_filename.ext" -ForegroundColor Gray
        Write-Host "" -ForegroundColor Gray
        Write-Host "# Delete a specific version:" -ForegroundColor Gray
        Write-Host "aws s3api delete-object --bucket $BucketName --key filename.ext --version-id VERSION_ID" -ForegroundColor Gray
    }

    Write-Success "Versioning configuration completed successfully!"

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
