# 🔧 S3 Storage & Website Hosting Scripts

This directory contains PowerShell scripts for automating AWS S3 storage and website hosting tasks for the XYZ Corporation case study.

## 📂 Directory Structure

```
scripts/
├── 🪣 bucket-management/           # S3 bucket creation & configuration
│   ├── create-bucket.ps1          # Create S3 bucket with website hosting
│   └── configure-bucket.ps1       # Advanced bucket configuration (CORS, logging)
│
├── 🔄 lifecycle-automation/       # Lifecycle policy management
│   ├── setup-lifecycle-policy.ps1 # Configure lifecycle policies for cost optimization
│   └── manage-lifecycle.ps1       # Manage and monitor lifecycle policies
│
├── 📚 versioning-setup/           # S3 versioning configuration
│   ├── enable-versioning.ps1      # Enable/configure S3 versioning
│   └── manage-versions.ps1        # Manage object versions (list, restore, cleanup)
│
├── 🌐 website-deployment/         # Static website hosting
│   ├── deploy-website.ps1         # Deploy website files to S3
│   └── configure-hosting.ps1      # Configure advanced hosting settings
│
├── validate-implementation.ps1    # Comprehensive validation script
├── cleanup-resources.ps1         # Resource cleanup utility
└── README.md                     # This documentation
```

## 🚀 Quick Start Guide

### Prerequisites
- AWS CLI installed and configured
- PowerShell 5.1 or higher
- Appropriate AWS IAM permissions for S3 operations

### Basic Usage Flow

1. **Create S3 Bucket**
   ```powershell
   .\bucket-management\create-bucket.ps1 -BucketName "my-website-bucket" -WebsiteHosting
   ```

2. **Enable Versioning**
   ```powershell
   .\versioning-setup\enable-versioning.ps1 -BucketName "my-website-bucket"
   ```

3. **Setup Lifecycle Policy**
   ```powershell
   .\lifecycle-automation\setup-lifecycle-policy.ps1 -BucketName "my-website-bucket" -IncludeVersioning
   ```

4. **Deploy Website**
   ```powershell
   .\website-deployment\deploy-website.ps1 -BucketName "my-website-bucket" -SourcePath "website-files"
   ```

5. **Validate Implementation**
   ```powershell
   .\validate-implementation.ps1 -BucketName "my-website-bucket" -DetailedReport
   ```

## 📋 Script Categories

### 🪣 Bucket Management Scripts

#### `create-bucket.ps1`
Creates S3 bucket with optional website hosting configuration.

**Parameters:**
- `-BucketName` (Required): Name of the S3 bucket
- `-Region` (Optional): AWS region (default: us-east-1)
- `-WebsiteHosting` (Switch): Enable static website hosting

**Example:**
```powershell
.\bucket-management\create-bucket.ps1 -BucketName "xyz-corp-website" -Region "us-east-1" -WebsiteHosting
```

#### `configure-bucket.ps1`
Advanced bucket configuration for CORS, logging, and notifications.

**Parameters:**
- `-BucketName` (Required): Name of the S3 bucket
- `-EnableCORS` (Switch): Configure CORS settings
- `-EnableLogging` (Switch): Setup server access logging
- `-EnableNotifications` (Switch): Configure event notifications

### 🔄 Lifecycle Automation Scripts

#### `setup-lifecycle-policy.ps1`
Configures lifecycle policies for cost optimization with storage class transitions.

**Parameters:**
- `-BucketName` (Required): Name of the S3 bucket
- `-StandardToIA` (Optional): Days to transition to Standard-IA (default: 30)
- `-IAToGlacier` (Optional): Days to transition to Glacier (default: 60)
- `-DeleteAfterDays` (Optional): Days before deletion (default: 75)
- `-IncludeVersioning` (Switch): Include version management rules

**Example:**
```powershell
.\lifecycle-automation\setup-lifecycle-policy.ps1 -BucketName "xyz-corp-storage" -StandardToIA 30 -IAToGlacier 60 -DeleteAfterDays 75 -IncludeVersioning
```

#### `manage-lifecycle.ps1`
Utility for managing existing lifecycle policies.

**Parameters:**
- `-Action` (Required): Action to perform (view, remove, update, status)
- `-BucketName` (Required): Name of the S3 bucket

**Examples:**
```powershell
# View current lifecycle policy
.\lifecycle-automation\manage-lifecycle.ps1 -Action view -BucketName "xyz-corp-storage"

# Show bucket status
.\lifecycle-automation\manage-lifecycle.ps1 -Action status -BucketName "xyz-corp-storage"
```

### 📚 Versioning Setup Scripts

#### `enable-versioning.ps1`
Enables and configures S3 bucket versioning for data protection.

**Parameters:**
- `-BucketName` (Required): Name of the S3 bucket
- `-Status` (Optional): Versioning status (Enabled/Suspended, default: Enabled)
- `-EnableMFA` (Switch): Enable MFA delete protection
- `-MFASerial` (Optional): MFA device serial number

#### `manage-versions.ps1`
Comprehensive version management utility.

**Parameters:**
- `-Action` (Required): Action to perform (list, restore, cleanup, info)
- `-BucketName` (Required): Name of the S3 bucket
- `-ObjectKey` (Optional): Specific object key to manage
- `-VersionId` (Optional): Version ID for restore operations
- `-MaxVersions` (Optional): Maximum versions to display (default: 100)

**Examples:**
```powershell
# List all versions
.\versioning-setup\manage-versions.ps1 -Action list -BucketName "xyz-corp-storage"

# Restore specific version
.\versioning-setup\manage-versions.ps1 -Action restore -BucketName "xyz-corp-storage" -ObjectKey "document.pdf" -VersionId "VERSION_ID"

# Cleanup old versions
.\versioning-setup\manage-versions.ps1 -Action cleanup -BucketName "xyz-corp-storage"
```

### 🌐 Website Deployment Scripts

#### `deploy-website.ps1`
Deploys static website files to S3 with proper configuration.

**Parameters:**
- `-BucketName` (Required): Name of the S3 bucket
- `-SourcePath` (Optional): Source directory path (default: "website-files")
- `-EnableWebsiteHosting` (Switch): Enable static website hosting (default: true)
- `-IndexDocument` (Optional): Index document name (default: "index.html")
- `-ErrorDocument` (Optional): Error document name (default: "error.html")
- `-ClearBucket` (Switch): Clear existing bucket contents before deploy

#### `configure-hosting.ps1`
Advanced website hosting configuration and domain integration.

**Parameters:**
- `-BucketName` (Required): Name of the S3 bucket
- `-CustomDomain` (Optional): Custom domain name for the website
- `-SetupRedirection` (Switch): Setup website redirection
- `-RedirectTo` (Optional): Target URL for redirection
- `-EnableCORS` (Switch): Enable CORS for website hosting
- `-TestWebsite` (Switch): Test website accessibility (default: true)

### 🔍 Validation & Cleanup Scripts

#### `validate-implementation.ps1`
Comprehensive validation of S3 storage and website hosting setup.

**Parameters:**
- `-BucketName` (Required): Name of the S3 bucket
- `-SkipWebsiteTest` (Switch): Skip website accessibility testing
- `-DetailedReport` (Switch): Generate detailed test report

**Features:**
- ✅ Bucket existence and accessibility
- ✅ Bucket configuration validation
- ✅ Versioning status check
- ✅ Lifecycle policy validation
- ✅ Website hosting configuration
- ✅ Website accessibility testing
- ✅ Object operations testing
- ✅ Permissions and policy validation

#### `cleanup-resources.ps1`
Resource cleanup utility for removing S3 resources and configurations.

**Parameters:**
- `-BucketName` (Required): Name of the S3 bucket
- `-CleanupType` (Optional): Type of cleanup (objects, policies, configs, bucket, all)
- `-Force` (Switch): Skip confirmation prompts
- `-DryRun` (Switch): Preview changes without executing

**Cleanup Types:**
- `objects`: Remove all objects and versions
- `policies`: Remove bucket policies
- `configs`: Remove bucket configurations (website, CORS, lifecycle)
- `bucket`: Complete bucket deletion
- `all`: Remove everything except bucket

## 💡 Usage Examples

### Complete S3 Website Setup
```powershell
# 1. Create bucket with website hosting
.\bucket-management\create-bucket.ps1 -BucketName "my-company-website" -WebsiteHosting

# 2. Enable versioning for data protection
.\versioning-setup\enable-versioning.ps1 -BucketName "my-company-website"

# 3. Configure lifecycle policy for cost optimization
.\lifecycle-automation\setup-lifecycle-policy.ps1 -BucketName "my-company-website" -IncludeVersioning

# 4. Deploy website files
.\website-deployment\deploy-website.ps1 -BucketName "my-company-website" -SourcePath "..\website-files"

# 5. Configure advanced hosting settings
.\website-deployment\configure-hosting.ps1 -BucketName "my-company-website" -EnableCORS

# 6. Validate the complete setup
.\validate-implementation.ps1 -BucketName "my-company-website" -DetailedReport
```

### Storage Management Operations
```powershell
# View lifecycle policy status
.\lifecycle-automation\manage-lifecycle.ps1 -Action status -BucketName "my-storage-bucket"

# List object versions
.\versioning-setup\manage-versions.ps1 -Action list -BucketName "my-storage-bucket"

# Cleanup old versions to save costs
.\versioning-setup\manage-versions.ps1 -Action cleanup -BucketName "my-storage-bucket"

# Test resource cleanup (dry run)
.\cleanup-resources.ps1 -BucketName "my-storage-bucket" -CleanupType objects -DryRun
```

### Validation and Monitoring
```powershell
# Quick validation check
.\validate-implementation.ps1 -BucketName "my-bucket"

# Detailed validation report
.\validate-implementation.ps1 -BucketName "my-bucket" -DetailedReport

# Skip website testing (for storage-only buckets)
.\validate-implementation.ps1 -BucketName "my-bucket" -SkipWebsiteTest
```

## 🔧 Configuration Tips

### AWS CLI Configuration
Ensure AWS CLI is configured with appropriate credentials:
```bash
aws configure
# OR
aws configure --profile myprofile
```

### Required IAM Permissions
Your AWS user/role needs these S3 permissions:
- `s3:CreateBucket`
- `s3:DeleteBucket`
- `s3:ListBucket`
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`
- `s3:GetBucketVersioning`
- `s3:PutBucketVersioning`
- `s3:GetBucketLifecycle`
- `s3:PutBucketLifecycle`
- `s3:GetBucketWebsite`
- `s3:PutBucketWebsite`
- `s3:GetBucketPolicy`
- `s3:PutBucketPolicy`
- `s3:DeleteBucketPolicy`

### PowerShell Execution Policy
If you encounter execution policy issues:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 📊 Features & Benefits

### ✅ Cost Optimization
- **Automated Lifecycle Policies**: Transition objects through storage classes
- **Version Management**: Control old version retention
- **Resource Cleanup**: Remove unnecessary resources

### ✅ Data Protection
- **S3 Versioning**: Protect against accidental deletion/modification
- **Backup and Recovery**: Easy version restoration
- **Configuration Validation**: Ensure proper setup

### ✅ Website Hosting
- **Static Website Deployment**: Automated file uploads
- **Custom Domain Support**: Route 53 integration guidance
- **Error Handling**: Custom error pages and CORS configuration

### ✅ Monitoring & Validation
- **Comprehensive Testing**: Validate all aspects of implementation
- **Performance Monitoring**: Website accessibility testing
- **Configuration Auditing**: Verify security and compliance

## 🆘 Troubleshooting

### Common Issues

1. **AWS CLI Not Found**
   - Install AWS CLI from https://aws.amazon.com/cli/
   - Ensure it's in your system PATH

2. **Permission Denied**
   - Check IAM permissions
   - Verify AWS credentials with `aws sts get-caller-identity`

3. **Bucket Already Exists**
   - S3 bucket names are globally unique
   - Choose a different bucket name

4. **Website Not Accessible**
   - Check bucket policy for public read access
   - Verify website hosting is enabled
   - Ensure index.html exists

5. **PowerShell Execution Policy**
   - Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Getting Help

For script-specific help, use the `-?` parameter:
```powershell
.\bucket-management\create-bucket.ps1 -?
```

## 📝 Best Practices

1. **Always Use Validation**: Run validation script after setup
2. **Test Before Production**: Use dry-run options for cleanup
3. **Monitor Costs**: Regularly review lifecycle policies
4. **Backup Configurations**: Save script parameters for reuse
5. **Security First**: Use least privilege IAM policies

## 🔄 Updates & Maintenance

These scripts are designed for the XYZ Corporation case study but can be adapted for other use cases. Key areas for customization:

- Bucket naming conventions
- Lifecycle policy timings
- Website hosting configurations
- Custom domain setups

---

**🎓 Academic Context**: These scripts support the Executive Post Graduate Certification in Cloud Computing at iHub Divyasampark, IIT Roorkee, demonstrating practical AWS S3 implementation skills.
