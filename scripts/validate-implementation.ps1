# =============================================================================
# AWS S3 Implementation Validation Script - XYZ Corporation Case Study
# =============================================================================
# Purpose: Comprehensive validation of S3 storage and website hosting setup
# Author: Case Study Implementation
# Usage: .\validate-implementation.ps1 -BucketName "your-bucket-name"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipWebsiteTest = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$DetailedReport = $false
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Title { param($Message) Write-Host "`n🔍 $Message" -ForegroundColor Cyan; Write-Host ("=" * ($Message.Length + 3)) -ForegroundColor Cyan }

# Test result tracking
$script:TestResults = @{
    Passed = 0
    Failed = 0
    Warnings = 0
    Tests = @()
}

function Add-TestResult {
    param(
        [string]$TestName,
        [string]$Status,  # "PASS", "FAIL", "WARN"
        [string]$Message,
        [string]$Details = ""
    )
    
    $script:TestResults.Tests += @{
        Name = $TestName
        Status = $Status
        Message = $Message
        Details = $Details
        Timestamp = Get-Date
    }
    
    switch ($Status) {
        "PASS" { 
            $script:TestResults.Passed++
            Write-Success "✅ $TestName - $Message"
        }
        "FAIL" { 
            $script:TestResults.Failed++
            Write-Error "❌ $TestName - $Message"
        }
        "WARN" { 
            $script:TestResults.Warnings++
            Write-Warning "⚠️  $TestName - $Message"
        }
    }
    
    if ($Details -and $DetailedReport) {
        Write-Host "   Details: $Details" -ForegroundColor Gray
    }
}

function Test-BucketExists {
    Write-Title "Testing Bucket Existence and Accessibility"
    
    try {
        $bucketList = aws s3 ls "s3://$BucketName" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -TestName "Bucket Existence" -Status "PASS" -Message "Bucket exists and is accessible"
            return $true
        } else {
            Add-TestResult -TestName "Bucket Existence" -Status "FAIL" -Message "Bucket does not exist or is not accessible"
            return $false
        }
    } catch {
        Add-TestResult -TestName "Bucket Existence" -Status "FAIL" -Message "Error checking bucket: $($_.Exception.Message)"
        return $false
    }
}

function Test-BucketConfiguration {
    Write-Title "Testing Bucket Configuration"
    
    try {
        # Test bucket location
        $location = aws s3api get-bucket-location --bucket $BucketName --query "LocationConstraint" --output text 2>$null
        if ($LASTEXITCODE -eq 0) {
            if ($location -eq "None" -or $location -eq "null") { $location = "us-east-1" }
            Add-TestResult -TestName "Bucket Location" -Status "PASS" -Message "Bucket located in region: $location" -Details $location
        } else {
            Add-TestResult -TestName "Bucket Location" -Status "WARN" -Message "Could not determine bucket location"
        }
        
        # Test bucket ACL
        $acl = aws s3api get-bucket-acl --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -TestName "Bucket ACL" -Status "PASS" -Message "Bucket ACL is accessible"
        } else {
            Add-TestResult -TestName "Bucket ACL" -Status "WARN" -Message "Could not retrieve bucket ACL"
        }
        
        # Test public access block
        $publicBlock = aws s3api get-public-access-block --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0) {
            $blockObj = $publicBlock | ConvertFrom-Json
            if ($blockObj.PublicAccessBlockConfiguration.BlockPublicAcls -eq $true) {
                Add-TestResult -TestName "Public Access Block" -Status "PASS" -Message "Public access block is configured (security best practice)"
            } else {
                Add-TestResult -TestName "Public Access Block" -Status "WARN" -Message "Public access block is not fully configured"
            }
        } else {
            Add-TestResult -TestName "Public Access Block" -Status "WARN" -Message "Could not retrieve public access block configuration"
        }
        
    } catch {
        Add-TestResult -TestName "Bucket Configuration" -Status "FAIL" -Message "Error testing configuration: $($_.Exception.Message)"
    }
}

function Test-Versioning {
    Write-Title "Testing S3 Versioning Configuration"
    
    try {
        $versioning = aws s3api get-bucket-versioning --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0) {
            $versionObj = $versioning | ConvertFrom-Json
            
            if ($versionObj.Status -eq "Enabled") {
                Add-TestResult -TestName "Versioning Status" -Status "PASS" -Message "Versioning is enabled (data protection active)"
                
                if ($versionObj.MfaDelete) {
                    Add-TestResult -TestName "MFA Delete" -Status "PASS" -Message "MFA Delete is configured (enhanced security)"
                } else {
                    Add-TestResult -TestName "MFA Delete" -Status "WARN" -Message "MFA Delete is not configured (consider for critical buckets)"
                }
            } elseif ($versionObj.Status -eq "Suspended") {
                Add-TestResult -TestName "Versioning Status" -Status "WARN" -Message "Versioning is suspended (limited data protection)"
            } else {
                Add-TestResult -TestName "Versioning Status" -Status "WARN" -Message "Versioning is not enabled (no version protection)"
            }
        } else {
            Add-TestResult -TestName "Versioning" -Status "FAIL" -Message "Could not retrieve versioning configuration"
        }
    } catch {
        Add-TestResult -TestName "Versioning" -Status "FAIL" -Message "Error testing versioning: $($_.Exception.Message)"
    }
}

function Test-LifecyclePolicy {
    Write-Title "Testing Lifecycle Policy Configuration"
    
    try {
        $lifecycle = aws s3api get-bucket-lifecycle-configuration --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0 -and $lifecycle) {
            $lifecycleObj = $lifecycle | ConvertFrom-Json
            
            if ($lifecycleObj.Rules -and $lifecycleObj.Rules.Count -gt 0) {
                Add-TestResult -TestName "Lifecycle Policy" -Status "PASS" -Message "$($lifecycleObj.Rules.Count) lifecycle rule(s) configured (cost optimization active)"
                
                foreach ($rule in $lifecycleObj.Rules) {
                    if ($rule.Status -eq "Enabled") {
                        $transitions = if ($rule.Transitions) { $rule.Transitions.Count } else { 0 }
                        $details = "Rule '$($rule.ID)' - $transitions transition(s)"
                        
                        if ($rule.Expiration) {
                            $details += ", expires after $($rule.Expiration.Days) days"
                        }
                        
                        Add-TestResult -TestName "Lifecycle Rule" -Status "PASS" -Message "Active rule found" -Details $details
                    } else {
                        Add-TestResult -TestName "Lifecycle Rule" -Status "WARN" -Message "Rule '$($rule.ID)' is disabled"
                    }
                }
            } else {
                Add-TestResult -TestName "Lifecycle Policy" -Status "WARN" -Message "Lifecycle policy exists but no rules configured"
            }
        } else {
            Add-TestResult -TestName "Lifecycle Policy" -Status "WARN" -Message "No lifecycle policy configured (missing cost optimization)"
        }
    } catch {
        Add-TestResult -TestName "Lifecycle Policy" -Status "FAIL" -Message "Error testing lifecycle policy: $($_.Exception.Message)"
    }
}

function Test-WebsiteHosting {
    Write-Title "Testing Website Hosting Configuration"
    
    try {
        $website = aws s3api get-bucket-website --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0 -and $website) {
            $websiteObj = $website | ConvertFrom-Json
            
            Add-TestResult -TestName "Website Hosting" -Status "PASS" -Message "Static website hosting is enabled"
            
            if ($websiteObj.IndexDocument -and $websiteObj.IndexDocument.Suffix) {
                Add-TestResult -TestName "Index Document" -Status "PASS" -Message "Index document configured: $($websiteObj.IndexDocument.Suffix)"
            } else {
                Add-TestResult -TestName "Index Document" -Status "WARN" -Message "Index document not configured"
            }
            
            if ($websiteObj.ErrorDocument -and $websiteObj.ErrorDocument.Key) {
                Add-TestResult -TestName "Error Document" -Status "PASS" -Message "Error document configured: $($websiteObj.ErrorDocument.Key)"
            } else {
                Add-TestResult -TestName "Error Document" -Status "WARN" -Message "Error document not configured"
            }
            
            if ($websiteObj.RedirectAllRequestsTo) {
                Add-TestResult -TestName "Website Redirect" -Status "PASS" -Message "Redirect configured to: $($websiteObj.RedirectAllRequestsTo.HostName)"
            }
            
            return $true
        } else {
            Add-TestResult -TestName "Website Hosting" -Status "WARN" -Message "Static website hosting is not enabled"
            return $false
        }
    } catch {
        Add-TestResult -TestName "Website Hosting" -Status "FAIL" -Message "Error testing website hosting: $($_.Exception.Message)"
        return $false
    }
}

function Test-WebsiteAccessibility {
    if ($SkipWebsiteTest) {
        Write-Info "Skipping website accessibility test as requested"
        return
    }
    
    Write-Title "Testing Website Accessibility"
    
    try {
        # Get bucket location for URL construction
        $location = aws s3api get-bucket-location --bucket $BucketName --query "LocationConstraint" --output text 2>$null
        if ($location -eq "None" -or $location -eq "null") { $location = "us-east-1" }
        
        # Construct website URL
        if ($location -eq "us-east-1") {
            $websiteUrl = "http://$BucketName.s3-website-us-east-1.amazonaws.com"
        } else {
            $websiteUrl = "http://$BucketName.s3-website-$location.amazonaws.com"
        }
        
        Write-Info "Testing URL: $websiteUrl"
        
        # Test website accessibility
        try {
            $response = Invoke-WebRequest -Uri $websiteUrl -Method Head -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
            Add-TestResult -TestName "Website Accessibility" -Status "PASS" -Message "Website is accessible (HTTP $($response.StatusCode))" -Details $websiteUrl
            
            # Test for common security headers (informational)
            if ($response.Headers.ContainsKey("X-Content-Type-Options")) {
                Add-TestResult -TestName "Security Headers" -Status "PASS" -Message "Security headers detected"
            } else {
                Add-TestResult -TestName "Security Headers" -Status "WARN" -Message "Consider adding security headers via CloudFront"
            }
            
        } catch [System.Net.WebException] {
            $statusCode = $_.Exception.Response.StatusCode
            if ($statusCode -eq "NotFound") {
                Add-TestResult -TestName "Website Accessibility" -Status "WARN" -Message "Website returns 404 - check if index.html exists"
            } elseif ($statusCode -eq "Forbidden") {
                Add-TestResult -TestName "Website Accessibility" -Status "WARN" -Message "Access forbidden - check bucket policy and public access settings"
            } else {
                Add-TestResult -TestName "Website Accessibility" -Status "WARN" -Message "Website returned error: $statusCode"
            }
        } catch {
            Add-TestResult -TestName "Website Accessibility" -Status "WARN" -Message "Could not connect to website: $($_.Exception.Message)"
        }
        
    } catch {
        Add-TestResult -TestName "Website Accessibility" -Status "FAIL" -Message "Error testing website accessibility: $($_.Exception.Message)"
    }
}

function Test-ObjectOperations {
    Write-Title "Testing Object Operations"
    
    try {
        # Test listing objects
        $objects = aws s3 ls "s3://$BucketName" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $objectCount = ($objects | Where-Object { $_.Trim() }).Count
            Add-TestResult -TestName "Object Listing" -Status "PASS" -Message "Can list objects ($objectCount objects found)"
        } else {
            Add-TestResult -TestName "Object Listing" -Status "FAIL" -Message "Cannot list objects in bucket"
        }
        
        # Test uploading a small test file
        $testFileName = "validation-test-$(Get-Date -Format 'yyyyMMddHHmmss').txt"
        $testContent = "S3 validation test file created on $(Get-Date)"
        
        Write-Info "Testing file upload with test file: $testFileName"
        
        # Create temporary test file
        $testFilePath = Join-Path $env:TEMP $testFileName
        $testContent | Out-File -FilePath $testFilePath -Encoding UTF8
        
        # Upload test file
        aws s3 cp $testFilePath "s3://$BucketName/$testFileName" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -TestName "File Upload" -Status "PASS" -Message "Can upload objects to bucket"
            
            # Test downloading the file
            $downloadPath = Join-Path $env:TEMP "downloaded_$testFileName"
            aws s3 cp "s3://$BucketName/$testFileName" $downloadPath 2>$null
            
            if ($LASTEXITCODE -eq 0 -and (Test-Path $downloadPath)) {
                Add-TestResult -TestName "File Download" -Status "PASS" -Message "Can download objects from bucket"
                
                # Verify content integrity
                $downloadedContent = Get-Content $downloadPath -Raw
                if ($downloadedContent.Trim() -eq $testContent.Trim()) {
                    Add-TestResult -TestName "Data Integrity" -Status "PASS" -Message "File content verified successfully"
                } else {
                    Add-TestResult -TestName "Data Integrity" -Status "WARN" -Message "File content mismatch detected"
                }
                
                # Clean up downloaded file
                Remove-Item $downloadPath -ErrorAction SilentlyContinue
            } else {
                Add-TestResult -TestName "File Download" -Status "FAIL" -Message "Cannot download objects from bucket"
            }
            
            # Clean up test file from S3
            aws s3 rm "s3://$BucketName/$testFileName" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Info "Test file cleaned up successfully"
            } else {
                Write-Warning "Could not clean up test file: $testFileName"
            }
            
        } else {
            Add-TestResult -TestName "File Upload" -Status "FAIL" -Message "Cannot upload objects to bucket"
        }
        
        # Clean up local test file
        Remove-Item $testFilePath -ErrorAction SilentlyContinue
        
    } catch {
        Add-TestResult -TestName "Object Operations" -Status "FAIL" -Message "Error testing object operations: $($_.Exception.Message)"
    }
}

function Test-Permissions {
    Write-Title "Testing Bucket Permissions and Policies"
    
    try {
        # Test bucket policy
        $policy = aws s3api get-bucket-policy --bucket $BucketName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -TestName "Bucket Policy" -Status "PASS" -Message "Bucket policy is configured"
            
            # Try to parse and analyze policy
            try {
                $policyObj = ($policy | ConvertFrom-Json).Policy | ConvertFrom-Json
                $statements = $policyObj.Statement
                
                $publicReadFound = $false
                foreach ($statement in $statements) {
                    if ($statement.Effect -eq "Allow" -and $statement.Principal -eq "*" -and $statement.Action -contains "s3:GetObject") {
                        $publicReadFound = $true
                        break
                    }
                }
                
                if ($publicReadFound) {
                    Add-TestResult -TestName "Public Read Policy" -Status "PASS" -Message "Public read access configured (required for website hosting)"
                } else {
                    Add-TestResult -TestName "Public Read Policy" -Status "WARN" -Message "Public read access not detected (may affect website accessibility)"
                }
                
            } catch {
                Add-TestResult -TestName "Policy Analysis" -Status "WARN" -Message "Could not analyze bucket policy structure"
            }
            
        } else {
            Add-TestResult -TestName "Bucket Policy" -Status "WARN" -Message "No bucket policy configured"
        }
        
    } catch {
        Add-TestResult -TestName "Permissions" -Status "FAIL" -Message "Error testing permissions: $($_.Exception.Message)"
    }
}

# Main execution
Write-Host "🔍 AWS S3 Implementation Validation" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Info "Target Bucket: $BucketName"
Write-Info "Validation Started: $(Get-Date)"

# Verify AWS CLI is available
$awsCheck = aws --version 2>$null
if (-not $awsCheck) {
    Write-Error "AWS CLI is not installed or not in PATH"
    exit 1
}

try {
    # Run all tests
    $bucketExists = Test-BucketExists
    
    if ($bucketExists) {
        Test-BucketConfiguration
        Test-Versioning
        Test-LifecyclePolicy
        $websiteEnabled = Test-WebsiteHosting
        
        if ($websiteEnabled) {
            Test-WebsiteAccessibility
        }
        
        Test-ObjectOperations
        Test-Permissions
    }
    
    # Generate summary report
    Write-Host "`n📊 Validation Summary Report" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    
    Write-Success "✅ Tests Passed: $($script:TestResults.Passed)"
    if ($script:TestResults.Warnings -gt 0) {
        Write-Warning "⚠️  Warnings: $($script:TestResults.Warnings)"
    }
    if ($script:TestResults.Failed -gt 0) {
        Write-Error "❌ Tests Failed: $($script:TestResults.Failed)"
    }
    
    $totalTests = $script:TestResults.Passed + $script:TestResults.Failed + $script:TestResults.Warnings
    $successRate = if ($totalTests -gt 0) { [Math]::Round(($script:TestResults.Passed / $totalTests) * 100, 1) } else { 0 }
    
    Write-Host "`nOverall Success Rate: $successRate% ($($script:TestResults.Passed)/$totalTests tests passed)" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })
    
    # Recommendations based on test results
    Write-Host "`n💡 Recommendations:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    
    $failedTests = $script:TestResults.Tests | Where-Object { $_.Status -eq "FAIL" }
    $warnTests = $script:TestResults.Tests | Where-Object { $_.Status -eq "WARN" }
    
    if ($failedTests.Count -eq 0 -and $warnTests.Count -eq 0) {
        Write-Success "🎉 Excellent! Your S3 implementation is properly configured."
        Write-Info "Consider implementing CloudFront for enhanced performance and security."
    } elseif ($failedTests.Count -eq 0) {
        Write-Success "✅ Good! Your S3 implementation is working correctly."
        Write-Info "Address the warnings above to optimize your configuration."
    } else {
        Write-Warning "❗ Issues detected that need attention:"
        foreach ($test in $failedTests) {
            Write-Error "• $($test.Name): $($test.Message)"
        }
    }
    
    # Detailed report if requested
    if ($DetailedReport) {
        Write-Host "`n📋 Detailed Test Report:" -ForegroundColor Cyan
        Write-Host "=========================" -ForegroundColor Cyan
        
        foreach ($test in $script:TestResults.Tests) {
            $statusSymbol = switch ($test.Status) {
                "PASS" { "✅" }
                "FAIL" { "❌" }
                "WARN" { "⚠️ " }
            }
            
            Write-Host "$statusSymbol $($test.Name)" -ForegroundColor $(switch ($test.Status) { "PASS" { "Green" } "FAIL" { "Red" } "WARN" { "Yellow" } })
            Write-Host "   Message: $($test.Message)" -ForegroundColor Gray
            if ($test.Details) {
                Write-Host "   Details: $($test.Details)" -ForegroundColor DarkGray
            }
            Write-Host "   Time: $($test.Timestamp)" -ForegroundColor DarkGray
            Write-Host ""
        }
    }
    
    Write-Info "Validation completed at: $(Get-Date)"
    
    # Exit with appropriate code
    if ($script:TestResults.Failed -gt 0) {
        exit 1
    } else {
        exit 0
    }
    
} catch {
    Write-Error "Validation failed with error: $($_.Exception.Message)"
    exit 1
}
