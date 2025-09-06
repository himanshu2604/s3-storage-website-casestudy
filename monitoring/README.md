# S3 Monitoring and Observability

This directory contains monitoring configurations and best practices for the S3 storage case study.

## 📊 Monitoring Components

### 1. CloudWatch Alarms (`cloudwatch-alarms.json`)
- **Storage Usage Alert**: Monitors bucket size and alerts when storage exceeds 5GB
- **Request Rate Alert**: Detects unusual traffic spikes
- **Error Rate Alert**: Monitors 4xx/5xx errors for website availability

### 2. Access Logging (`access-logging-config.json`)
- Configures S3 access logs for detailed request tracking
- Separate logging bucket with lifecycle policies
- Comprehensive request metadata capture

### 3. Performance Dashboard (`performance-dashboard.json`)
- CloudWatch dashboard for real-time monitoring
- Key metrics: storage usage, request rates, error rates, data transfer
- Custom widgets for visual performance tracking

## 🚀 Quick Setup

### Prerequisites
- AWS CLI configured with appropriate permissions
- SNS topic for alerts (optional but recommended)

### Step 1: Create SNS Topic for Alerts
```bash
aws sns create-topic --name s3-alerts
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:ACCOUNT:s3-alerts --protocol email --notification-endpoint your-email@domain.com
```

### Step 2: Deploy CloudWatch Alarms
```bash
# Update bucket names in cloudwatch-alarms.json first
aws cloudwatch put-metric-alarm --cli-input-json file://cloudwatch-alarms.json
```

### Step 3: Enable Access Logging
```bash
# Create logging bucket first
aws s3 mb s3://s3-access-logs-bucket

# Enable logging on your main bucket
aws s3api put-bucket-logging --bucket your-main-bucket --bucket-logging-status file://access-logging-config.json
```

### Step 4: Create Dashboard
```bash
aws cloudwatch put-dashboard --dashboard-name S3-Performance-Monitoring --dashboard-body file://performance-dashboard.json
```

## 📈 Key Metrics to Monitor

| Metric | Purpose | Threshold | Action |
|--------|---------|-----------|---------|
| BucketSizeBytes | Storage usage | 5GB | Review storage optimization |
| AllRequests | Traffic patterns | 10,000/5min | Scale or investigate |
| 4xxErrors | Client errors | 50/5min | Check website issues |
| 5xxErrors | Server errors | 10/5min | AWS service issues |
| BytesDownloaded | Data transfer | Custom | Cost monitoring |

## 🔍 Log Analysis

### Common Log Patterns
```bash
# Top IP addresses
awk '{print $3}' access_log | sort | uniq -c | sort -nr | head -10

# Most requested files
awk '{print $8}' access_log | sort | uniq -c | sort -nr | head -10

# Error analysis
grep "HTTP/1.1\" [45]" access_log | awk '{print $9}' | sort | uniq -c
```

## 🚨 Alert Configuration

### Critical Alerts
- Storage usage > 80% of planned capacity
- Error rate > 5% for 10 minutes
- Unusual traffic spikes (>200% of baseline)

### Warning Alerts  
- Storage growth rate exceeding budget projections
- Increasing response times
- Regional access pattern changes

## 💰 Cost Monitoring

### Monitoring Costs
- CloudWatch metrics: ~$0.30/metric/month
- CloudWatch alarms: $0.10/alarm/month
- Access logging: Storage costs for log files
- Dashboard: Free (up to 3 dashboards)

### Cost Optimization
- Set up billing alerts for monitoring costs
- Use lifecycle policies for log retention
- Monitor only essential metrics initially

## 📋 Maintenance Checklist

### Weekly
- [ ] Review alarm status and any triggered alerts
- [ ] Check dashboard for performance trends
- [ ] Verify log delivery and storage usage

### Monthly
- [ ] Analyze access patterns from logs
- [ ] Review and adjust alarm thresholds
- [ ] Clean up old log files per retention policy
- [ ] Generate cost and usage reports

### Quarterly
- [ ] Review monitoring strategy effectiveness
- [ ] Update alert recipients and escalation procedures
- [ ] Optimize dashboard layout based on usage
- [ ] Assess need for additional metrics or alarms

## 🛠️ Troubleshooting

### Common Issues
1. **Alarms not triggering**: Check metric dimensions and thresholds
2. **Missing logs**: Verify logging bucket permissions and region
3. **Dashboard not loading**: Check metric names and dimensions
4. **High monitoring costs**: Review metric retention and frequency

### Best Practices
- Start with essential metrics, expand gradually
- Use composite alarms for complex scenarios
- Implement proper tagging for cost allocation
- Regular review and optimization of monitoring setup

## 📚 Additional Resources

- [AWS S3 Monitoring Guide](https://docs.aws.amazon.com/s3/latest/userguide/monitoring.html)
- [CloudWatch Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_best_practices.html)
- [S3 Access Logs Format](https://docs.aws.amazon.com/AmazonS3/latest/userguide/LogFormat.html)
