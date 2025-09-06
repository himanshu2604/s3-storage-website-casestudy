# =============================================================================
# AWS S3 Bucket Creation Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Automate S3 bucket creation for storage and website hosting
# Author: Case Study Implementation
# Usage: .\create-bucket.ps1 -BucketName "your-bucket-name" -Region "us-east-1"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [switch]$WebsiteHosting = $false
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Info "Starting S3 bucket creation process..."
Write-Info "Bucket Name: $BucketName"
Write-Info "Region: $Region"

try {
    # Check if AWS CLI is installed and configured
    $awsCheck = aws --version 2>$null
    if (-not $awsCheck) {
        Write-Error "AWS CLI is not installed or not in PATH"
        exit 1
    }
    Write-Success "AWS CLI is available"

    # Check if bucket already exists
    Write-Info "Checking if bucket already exists..."
    $bucketExists = aws s3 ls "s3://$BucketName" 2>$null
    if ($bucketExists) {
        Write-Warning "Bucket '$BucketName' already exists!"
        $continue = Read-Host "Do you want to continue with configuration? (y/N)"
        if ($continue -ne 'y') {
            exit 0
        }
    } else {
        # Create the bucket
        Write-Info "Creating S3 bucket: $BucketName"
        
        if ($Region -eq "us-east-1") {
            aws s3 mb "s3://$BucketName"
        } else {
            aws s3 mb "s3://$BucketName" --region $Region
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Bucket '$BucketName' created successfully!"
        } else {
            Write-Error "Failed to create bucket '$BucketName'"
            exit 1
        }
    }

    # Configure bucket for website hosting if requested
    if ($WebsiteHosting) {
        Write-Info "Configuring bucket for static website hosting..."
        
        # Enable static website hosting
        aws s3 website "s3://$BucketName" --index-document index.html --error-document error.html
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Static website hosting enabled!"
            Write-Info "Website endpoint: http://$BucketName.s3-website-$Region.amazonaws.com"
        } else {
            Write-Warning "Failed to enable static website hosting"
        }
    }

    # Set up basic bucket policy for public read access (if website hosting)
    if ($WebsiteHosting) {
        Write-Info "Setting up public read policy for website hosting..."
        
        $policyJson = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BucketName/*"
        }
    ]
}
"@
        
        $policyFile = "temp_policy_$BucketName.json"
        $policyJson | Out-File -FilePath $policyFile -Encoding UTF8
        
        aws s3api put-bucket-policy --bucket $BucketName --policy "file://$policyFile"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Public read policy applied successfully!"
        } else {
            Write-Warning "Failed to apply public read policy"
        }
        
        # Clean up temporary policy file
        Remove-Item $policyFile -ErrorAction SilentlyContinue
    }

    Write-Success "Bucket setup completed successfully!"
    Write-Info "Next steps:"
    Write-Info "1. Configure lifecycle policies using lifecycle-automation scripts"
    Write-Info "2. Enable versioning using versioning-setup scripts"
    Write-Info "3. Upload website files using website-deployment scripts"

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
