# =============================================================================
# AWS S3 Website Hosting Configuration Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Configure advanced website hosting settings and domain integration
# Author: Case Study Implementation
# Usage: .\configure-hosting.ps1 -BucketName "your-bucket-name"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [string]$CustomDomain = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$SetupRedirection = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$RedirectTo = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableCORS = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$TestWebsite = $true
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Info "AWS S3 Website Hosting Advanced Configuration"
Write-Info "Target Bucket: $BucketName"

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

    # Check current website configuration
    Write-Info "Checking current website configuration..."
    $currentConfig = aws s3api get-bucket-website --bucket $BucketName 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $currentConfig) {
        Write-Success "Website hosting is currently enabled"
        $configObj = $currentConfig | ConvertFrom-Json
        
        Write-Host "`n📋 Current Configuration:" -ForegroundColor Cyan
        Write-Host "=========================" -ForegroundColor Cyan
        
        if ($configObj.IndexDocument) {
            Write-Info "Index Document: $($configObj.IndexDocument.Suffix)"
        }
        
        if ($configObj.ErrorDocument) {
            Write-Info "Error Document: $($configObj.ErrorDocument.Key)"
        }
        
        if ($configObj.RedirectAllRequestsTo) {
            Write-Info "Redirect Target: $($configObj.RedirectAllRequestsTo.HostName)"
        }
        
    } else {
        Write-Warning "Website hosting is not currently enabled"
        Write-Info "Please run the deploy-website.ps1 script first to enable basic hosting"
    }

    # Setup website redirection if requested
    if ($SetupRedirection -and $RedirectTo) {
        Write-Info "Configuring website redirection..."
        Write-Info "Redirecting all requests to: $RedirectTo"
        
        aws s3 website "s3://$BucketName" --redirect-all-requests-to $RedirectTo
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Website redirection configured successfully!"
            Write-Warning "All requests to this bucket will now redirect to $RedirectTo"
        } else {
            Write-Error "Failed to configure website redirection"
        }
    }

    # Configure CORS if requested
    if ($EnableCORS) {
        Write-Info "Configuring CORS for website hosting..."
        
        $corsConfig = @"
{
    "CORSRules": [
        {
            "AllowedHeaders": ["*"],
            "AllowedMethods": ["GET", "HEAD"],
            "AllowedOrigins": ["*"],
            "ExposeHeaders": ["ETag"],
            "MaxAgeSeconds": 3000
        },
        {
            "AllowedHeaders": ["Content-*"],
            "AllowedMethods": ["PUT", "POST", "DELETE"],
            "AllowedOrigins": ["https://$BucketName.s3-website-*.amazonaws.com"],
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

    # Get bucket location and construct website URL
    Write-Info "Getting website endpoint information..."
    $bucketLocation = aws s3api get-bucket-location --bucket $BucketName --query "LocationConstraint" --output text
    
    if ($bucketLocation -eq "None" -or $bucketLocation -eq "null") {
        $bucketLocation = "us-east-1"
    }

    # Construct website URL
    if ($bucketLocation -eq "us-east-1") {
        $websiteUrl = "http://$BucketName.s3-website-us-east-1.amazonaws.com"
    } else {
        $websiteUrl = "http://$BucketName.s3-website-$bucketLocation.amazonaws.com"
    }

    # Custom domain configuration guidance
    if ($CustomDomain) {
        Write-Host "`n🌐 Custom Domain Configuration:" -ForegroundColor Cyan
        Write-Host "===============================" -ForegroundColor Cyan
        
        Write-Info "Custom Domain: $CustomDomain"
        Write-Warning "Note: For custom domains, the bucket name must match the domain name"
        
        if ($BucketName -ne $CustomDomain) {
            Write-Warning "Current bucket name '$BucketName' does not match domain '$CustomDomain'"
            Write-Info "For custom domain support, create a bucket named '$CustomDomain'"
        } else {
            Write-Success "Bucket name matches custom domain - configuration is valid"
        }
        
        Write-Host "`n📝 DNS Configuration Steps:" -ForegroundColor Yellow
        Write-Host "===========================" -ForegroundColor Yellow
        Write-Info "1. Create a Route 53 hosted zone for '$CustomDomain'"
        Write-Info "2. Create a CNAME record pointing to: $websiteUrl"
        Write-Info "3. Or create an A record as an alias to the S3 endpoint"
        Write-Info "4. Update your domain's nameservers to Route 53"
        
        Write-Host "`n💡 Route 53 Commands:" -ForegroundColor Yellow
        Write-Host "=====================" -ForegroundColor Yellow
        Write-Host "# Create hosted zone" -ForegroundColor Gray
        Write-Host "aws route53 create-hosted-zone --name $CustomDomain --caller-reference $(Get-Date -Format 'yyyyMMddHHmmss')" -ForegroundColor Gray
        Write-Host "" -ForegroundColor Gray
        Write-Host "# Create CNAME record (replace ZONE_ID with actual value)" -ForegroundColor Gray
        Write-Host "aws route53 change-resource-record-sets --hosted-zone-id ZONE_ID --change-batch file://dns-record.json" -ForegroundColor Gray
    }

    # Test website if requested
    if ($TestWebsite -and -not $SetupRedirection) {
        Write-Info "Testing website accessibility..."
        
        try {
            $testResult = Invoke-WebRequest -Uri $websiteUrl -Method Head -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            Write-Success "Website is accessible! Status: $($testResult.StatusCode)"
        } catch {
            Write-Warning "Website test failed: $($_.Exception.Message)"
            Write-Info "This might be normal if the website was just configured"
            Write-Info "Please wait a few minutes and try accessing the URL manually"
        }
    }

    # Display comprehensive configuration summary
    Write-Host "`n📊 Website Hosting Summary:" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    
    Write-Info "Bucket Name: $BucketName"
    Write-Info "Region: $bucketLocation"
    Write-Success "Website URL: $websiteUrl"
    
    if ($CustomDomain) {
        Write-Info "Custom Domain: $CustomDomain"
    }
    
    if ($SetupRedirection -and $RedirectTo) {
        Write-Success "Redirection Target: $RedirectTo"
    }
    
    Write-Info "CORS Enabled: $(if ($EnableCORS) { 'Yes' } else { 'No' })"

    # Display security and performance recommendations
    Write-Host "`n🔒 Security & Performance Recommendations:" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Warning "⚠️  S3 website endpoints do not support HTTPS natively"
    Write-Info "💡 For HTTPS support, consider using CloudFront"
    Write-Info "💡 Enable access logging for monitoring"
    Write-Info "💡 Set up CloudWatch alarms for monitoring"
    Write-Info "💡 Use CloudFront for better global performance"
    Write-Info "💡 Implement proper error handling pages"

    # CloudFront setup guidance
    Write-Host "`n☁️  CloudFront Integration:" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Info "Benefits of using CloudFront with S3 website:"
    Write-Info "• HTTPS/SSL support"
    Write-Info "• Global edge locations for better performance"
    Write-Info "• Custom error pages"
    Write-Info "• Advanced caching controls"
    Write-Info "• Custom domain with SSL certificates"
    
    Write-Host "`n📝 CloudFront Setup Command:" -ForegroundColor Gray
    Write-Host "aws cloudfront create-distribution --distribution-config file://cloudfront-config.json" -ForegroundColor Gray

    # Monitoring setup guidance
    Write-Host "`n📈 Monitoring Setup:" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    Write-Info "Enable request metrics in S3 console or use:"
    Write-Host "aws s3api put-bucket-metrics-configuration --bucket $BucketName --id EntireBucket --metrics-configuration Id=EntireBucket,Filter={}" -ForegroundColor Gray

    Write-Success "Website hosting configuration completed successfully!"
    Write-Info "Your website should be accessible at: $websiteUrl"

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    
    # Clean up temporary files on error
    if (Test-Path "temp_cors_$BucketName.json") {
        Remove-Item "temp_cors_$BucketName.json" -ErrorAction SilentlyContinue
    }
    
    exit 1
}
