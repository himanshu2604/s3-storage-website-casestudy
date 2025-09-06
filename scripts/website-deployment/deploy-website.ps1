# =============================================================================
# AWS S3 Website Deployment Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Deploy static website files to S3 bucket with proper configuration
# Author: Case Study Implementation
# Usage: .\deploy-website.ps1 -BucketName "your-bucket-name" -SourcePath "website-files"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "website-files",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableWebsiteHosting = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$IndexDocument = "index.html",
    
    [Parameter(Mandatory=$false)]
    [string]$ErrorDocument = "error.html",
    
    [Parameter(Mandatory=$false)]
    [switch]$ClearBucket = $false
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Info "AWS S3 Website Deployment"
Write-Info "Target Bucket: $BucketName"
Write-Info "Source Path: $SourcePath"

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
        Write-Info "Please create the bucket first using the bucket-management scripts"
        exit 1
    }
    Write-Success "Bucket verified successfully"

    # Verify source files exist
    Write-Info "Checking source files..."
    if (-not (Test-Path $SourcePath)) {
        Write-Error "Source path '$SourcePath' does not exist"
        Write-Info "Please ensure the website files are in the specified directory"
        exit 1
    }
    
    $sourceFiles = Get-ChildItem -Path $SourcePath -Recurse -File
    if ($sourceFiles.Count -eq 0) {
        Write-Error "No files found in source path '$SourcePath'"
        exit 1
    }
    
    Write-Success "Found $($sourceFiles.Count) files to deploy"

    # Check for required files
    $indexPath = Join-Path $SourcePath $IndexDocument
    $errorPath = Join-Path $SourcePath $ErrorDocument
    
    if (-not (Test-Path $indexPath)) {
        Write-Warning "Index document '$IndexDocument' not found at '$indexPath'"
        Write-Info "Website hosting may not work properly without an index document"
    } else {
        Write-Success "Index document found: $IndexDocument"
    }
    
    if (-not (Test-Path $errorPath)) {
        Write-Warning "Error document '$ErrorDocument' not found at '$errorPath'"
        Write-Info "Custom error pages will not be available"
    } else {
        Write-Success "Error document found: $ErrorDocument"
    }

    # Clear bucket if requested
    if ($ClearBucket) {
        Write-Warning "Clearing existing bucket contents..."
        $confirm = Read-Host "Are you sure you want to delete all existing files in the bucket? (y/N)"
        if ($confirm -eq 'y') {
            aws s3 rm "s3://$BucketName" --recursive
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Bucket cleared successfully"
            } else {
                Write-Warning "Failed to clear bucket or bucket was already empty"
            }
        } else {
            Write-Info "Skipping bucket clearing"
        }
    }

    # Upload website files
    Write-Info "Starting file upload to S3..."
    Write-Info "This may take a few moments depending on file size and count..."
    
    # Use AWS S3 sync for efficient uploading
    aws s3 sync $SourcePath "s3://$BucketName" --delete
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Website files uploaded successfully!"
    } else {
        Write-Error "Failed to upload website files"
        exit 1
    }

    # Configure website hosting if enabled
    if ($EnableWebsiteHosting) {
        Write-Info "Configuring static website hosting..."
        
        aws s3 website "s3://$BucketName" --index-document $IndexDocument --error-document $ErrorDocument
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Website hosting configured successfully!"
        } else {
            Write-Error "Failed to configure website hosting"
            exit 1
        }

        # Set bucket policy for public read access
        Write-Info "Setting up public read policy for website hosting..."
        
        $bucketPolicy = @"
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
        
        $policyFile = "temp_website_policy_$BucketName.json"
        $bucketPolicy | Out-File -FilePath $policyFile -Encoding UTF8
        
        aws s3api put-bucket-policy --bucket $BucketName --policy "file://$policyFile"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Public read policy applied successfully!"
        } else {
            Write-Warning "Failed to apply public read policy"
            Write-Warning "Website may not be publicly accessible"
        }
        
        # Clean up temporary policy file
        Remove-Item $policyFile -ErrorAction SilentlyContinue
    }

    # Get bucket location for website URL
    Write-Info "Getting website endpoint information..."
    $bucketLocation = aws s3api get-bucket-location --bucket $BucketName --query "LocationConstraint" --output text
    
    if ($bucketLocation -eq "None" -or $bucketLocation -eq "null") {
        $bucketLocation = "us-east-1"
    }

    # Display deployment results
    Write-Host "`n🎉 Deployment Completed Successfully!" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green
    
    Write-Host "`n📊 Deployment Summary:" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Info "Bucket Name: $BucketName"
    Write-Info "Files Deployed: $($sourceFiles.Count)"
    Write-Info "Source Directory: $SourcePath"
    
    if ($EnableWebsiteHosting) {
        Write-Host "`n🌐 Website Information:" -ForegroundColor Cyan
        Write-Host "=======================" -ForegroundColor Cyan
        Write-Success "Static Website Hosting: Enabled"
        Write-Info "Index Document: $IndexDocument"
        Write-Info "Error Document: $ErrorDocument"
        
        # Construct website URL
        if ($bucketLocation -eq "us-east-1") {
            $websiteUrl = "http://$BucketName.s3-website-us-east-1.amazonaws.com"
        } else {
            $websiteUrl = "http://$BucketName.s3-website-$bucketLocation.amazonaws.com"
        }
        
        Write-Success "Website URL: $websiteUrl"
        Write-Info "Note: It may take a few minutes for the website to be accessible"
    }

    # Display file listing
    Write-Host "`n📁 Deployed Files:" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    $deployedFiles = aws s3 ls "s3://$BucketName" --recursive --human-readable
    if ($LASTEXITCODE -eq 0 -and $deployedFiles) {
        $deployedFiles | ForEach-Object { 
            if ($_.Trim()) {
                Write-Host "  $_" -ForegroundColor Gray
            }
        }
    }

    Write-Host "`n🔧 Next Steps:" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    Write-Info "1. Test the website by visiting the URL above"
    Write-Info "2. Configure custom domain using Route 53 (if needed)"
    Write-Info "3. Set up CloudFront for CDN (optional)"
    Write-Info "4. Monitor website performance and access logs"
    Write-Info "5. Update website content by re-running this script"

    Write-Host "`n💡 Tips:" -ForegroundColor Yellow
    Write-Host "========" -ForegroundColor Yellow
    Write-Info "• Use 'aws s3 sync' for incremental updates"
    Write-Info "• Enable CloudFront for better performance and HTTPS"
    Write-Info "• Monitor S3 request metrics in CloudWatch"
    Write-Info "• Consider setting up CI/CD for automatic deployments"

    Write-Success "Website deployment completed successfully!"

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    
    # Clean up temporary files on error
    if (Test-Path "temp_website_policy_$BucketName.json") {
        Remove-Item "temp_website_policy_$BucketName.json" -ErrorAction SilentlyContinue
    }
    
    exit 1
}
