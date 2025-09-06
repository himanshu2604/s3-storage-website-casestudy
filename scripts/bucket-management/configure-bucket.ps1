# =============================================================================
# AWS S3 Bucket Configuration Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Configure advanced S3 bucket settings (CORS, notifications, etc.)
# Author: Case Study Implementation
# Usage: .\configure-bucket.ps1 -BucketName "your-bucket-name"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableCORS = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableLogging = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableNotifications = $false
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Info "Starting S3 bucket advanced configuration..."
Write-Info "Target Bucket: $BucketName"

try {
    # Verify bucket exists
    Write-Info "Verifying bucket exists..."
    $bucketCheck = aws s3 ls "s3://$BucketName" 2>$null
    if (-not $bucketCheck -and $LASTEXITCODE -ne 0) {
        Write-Error "Bucket '$BucketName' does not exist or is not accessible"
        exit 1
    }
    Write-Success "Bucket verified successfully"

    # Configure CORS if requested
    if ($EnableCORS) {
        Write-Info "Configuring CORS settings..."
        
        $corsConfig = @"
{
    "CORSRules": [
        {
            "AllowedHeaders": ["*"],
            "AllowedMethods": ["GET", "HEAD"],
            "AllowedOrigins": ["*"],
            "ExposeHeaders": ["ETag"],
            "MaxAgeSeconds": 3000
        }
    ]
}
"@
        
        $corsFile = "temp_cors_$BucketName.json"
        $corsConfig | Out-File -FilePath $corsFile -Encoding UTF8
        
        aws s3api put-bucket-cors --bucket $BucketName --cors-configuration "file://$corsFile"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "CORS configuration applied successfully!"
        } else {
            Write-Warning "Failed to apply CORS configuration"
        }
        
        Remove-Item $corsFile -ErrorAction SilentlyContinue
    }

    # Configure server access logging if requested
    if ($EnableLogging) {
        Write-Info "Configuring server access logging..."
        
        $loggingBucket = "$BucketName-logs"
        Write-Info "Creating logging bucket: $loggingBucket"
        
        # Create logging bucket if it doesn't exist
        aws s3 mb "s3://$loggingBucket" 2>$null
        
        $loggingConfig = @"
{
    "LoggingEnabled": {
        "TargetBucket": "$loggingBucket",
        "TargetPrefix": "access-logs/"
    }
}
"@
        
        $loggingFile = "temp_logging_$BucketName.json"
        $loggingConfig | Out-File -FilePath $loggingFile -Encoding UTF8
        
        aws s3api put-bucket-logging --bucket $BucketName --bucket-logging-status "file://$loggingFile"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Server access logging configured successfully!"
            Write-Info "Logs will be stored in: s3://$loggingBucket/access-logs/"
        } else {
            Write-Warning "Failed to configure server access logging"
        }
        
        Remove-Item $loggingFile -ErrorAction SilentlyContinue
    }

    # Configure event notifications if requested
    if ($EnableNotifications) {
        Write-Info "Event notifications require additional setup (SNS/SQS topics)"
        Write-Info "Please configure manually or use dedicated notification scripts"
        Write-Warning "Skipping automatic notification configuration"
    }

    # Display bucket configuration summary
    Write-Info "Getting bucket configuration summary..."
    
    Write-Host "`n📋 Bucket Configuration Summary:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    # Check website hosting status
    $websiteConfig = aws s3api get-bucket-website --bucket $BucketName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Website Hosting: Enabled"
    } else {
        Write-Info "Website Hosting: Disabled"
    }
    
    # Check versioning status
    $versioningStatus = aws s3api get-bucket-versioning --bucket $BucketName --query "Status" --output text
    Write-Info "Versioning: $versioningStatus"
    
    # Check public access block
    $publicAccess = aws s3api get-public-access-block --bucket $BucketName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Public Access Block: Configured"
    } else {
        Write-Info "Public Access Block: Not configured"
    }

    Write-Success "Bucket configuration completed successfully!"

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
