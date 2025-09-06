# S3 Testing Suite

This directory contains testing scripts and configurations for validating the S3 storage case study implementation.

## 🧪 Testing Components

### 1. Website Availability Tests (`website-availability-test.sh`)
- **Connectivity**: Tests basic website accessibility and response times
- **Content Validation**: Verifies website content and structure
- **Error Handling**: Tests 404 error page functionality
- **Performance Metrics**: Measures response times and download speeds
- **Mobile Compatibility**: Tests mobile user agent responses

### 2. S3 Bucket Tests (`s3-bucket-tests.sh`)
- **Bucket Access**: Verifies AWS credentials and bucket permissions
- **Upload/Download**: Tests file operations and data integrity
- **Configuration Checks**: Validates bucket policies, website config, lifecycle rules
- **Security Features**: Checks encryption and versioning status

### 3. Load Testing (`load-test-config.yaml`)
- **Performance Testing**: Artillery.js and K6 configurations
- **Load Patterns**: Warm-up, ramp-up, sustained, and peak load scenarios
- **Apache Bench**: Simple command-line load testing alternatives
- **Thresholds**: Performance expectations and success criteria

## 🚀 Quick Start

### Prerequisites
```bash
# Install required tools
curl -L https://github.com/loadimpact/k6/releases/download/v0.35.0/k6-v0.35.0-linux-amd64.tar.gz | tar xvz
npm install -g artillery@latest

# Ensure AWS CLI is configured
aws configure list
```

### Running Tests

#### 1. Website Availability Test
```bash
chmod +x website-availability-test.sh
./website-availability-test.sh
```

#### 2. S3 Bucket Functionality Test
```bash
chmod +x s3-bucket-tests.sh
# Edit BUCKET_NAME variable first
./s3-bucket-tests.sh
```

#### 3. Load Testing
```bash
# Using Artillery
artillery run load-test-config.yaml

# Using K6 (extract k6_config section to separate file first)
k6 run load-test.js

# Using Apache Bench
ab -n 1000 -c 10 https://your-s3-website.s3-website-us-east-1.amazonaws.com/
```

## 📊 Test Results Interpretation

### Website Availability Results
| Status | Meaning | Action |
|--------|---------|---------|
| ✅ | Test passed | Continue monitoring |
| ⚠️  | Warning condition | Review and investigate |
| ❌ | Test failed | Immediate attention required |

### Performance Benchmarks
- **Response Time**: < 2s (Good), 2-5s (Acceptable), > 5s (Poor)
- **Availability**: > 99.9% uptime expected
- **Error Rate**: < 1% for 4xx/5xx errors

### Load Testing Thresholds
- **P95 Response Time**: < 2000ms
- **Success Rate**: > 99%
- **Concurrent Users**: Should handle 50+ without degradation

## 🔧 Configuration

### Before Running Tests

1. **Update URLs and Bucket Names**:
   ```bash
   # In website-availability-test.sh
   WEBSITE_URL="https://your-actual-domain.com"
   
   # In s3-bucket-tests.sh
   BUCKET_NAME="your-actual-bucket-name"
   
   # In load-test-config.yaml
   target: 'https://your-actual-domain.com'
   ```

2. **AWS Credentials**:
   ```bash
   aws configure set aws_access_key_id YOUR_ACCESS_KEY
   aws configure set aws_secret_access_key YOUR_SECRET_KEY
   aws configure set default.region us-east-1
   ```

## 📋 Testing Checklist

### Pre-Production Testing
- [ ] Website loads successfully (HTTP 200)
- [ ] All content renders correctly
- [ ] Custom error page works (HTTP 404)
- [ ] Mobile responsiveness verified
- [ ] SSL certificate valid (if using HTTPS)

### S3 Configuration Testing
- [ ] Bucket accessible with correct permissions
- [ ] File upload/download operations work
- [ ] Website hosting configuration active
- [ ] Bucket policies applied correctly
- [ ] Lifecycle rules configured (if applicable)

### Performance Testing
- [ ] Load testing completed successfully
- [ ] Response times meet requirements
- [ ] No errors under normal load
- [ ] CloudWatch metrics captured during tests
- [ ] Cost impact of testing documented

### Security Testing
- [ ] Bucket policies restrict unauthorized access
- [ ] Encryption enabled (if required)
- [ ] Access logging configured
- [ ] No sensitive data exposed in public buckets

## 🚨 Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   ```bash
   # Check AWS credentials
   aws sts get-caller-identity
   
   # Verify bucket policy allows required actions
   aws s3api get-bucket-policy --bucket your-bucket-name
   ```

2. **Website Not Loading**
   ```bash
   # Check website configuration
   aws s3api get-bucket-website --bucket your-bucket-name
   
   # Verify index document exists
   aws s3 ls s3://your-bucket-name/index.html
   ```

3. **High Response Times**
   - Check CloudFront configuration if using CDN
   - Verify bucket region matches testing location
   - Monitor S3 metrics for throttling

### Load Testing Considerations
- **S3 Request Limits**: Be aware of request rate limits
- **Cost Impact**: Load testing generates requests and data transfer charges
- **Regional Testing**: Test from multiple geographic locations
- **Baseline Establishment**: Run tests during low-traffic periods first

## 📈 Continuous Testing

### Automated Testing Schedule
- **Availability Tests**: Every 5 minutes (using monitoring tools)
- **Functionality Tests**: Daily
- **Load Tests**: Weekly or before major releases
- **Security Audits**: Monthly

### Integration with CI/CD
```yaml
# Example GitHub Actions workflow
name: S3 Website Tests
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run availability tests
        run: ./testing/website-availability-test.sh
```

## 📚 Additional Resources

- [AWS S3 Testing Best Practices](https://docs.aws.amazon.com/s3/latest/userguide/testing.html)
- [Artillery.js Documentation](https://artillery.io/docs/)
- [K6 Load Testing Guide](https://k6.io/docs/)
- [Apache Bench Tutorial](https://httpd.apache.org/docs/2.4/programs/ab.html)
