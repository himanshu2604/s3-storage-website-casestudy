#!/bin/bash

# S3 Bucket Functionality Test Script
# Tests bucket permissions, policies, and configurations

# Configuration
BUCKET_NAME="your-s3-bucket-name"
TEST_FILE="test-file-$(date +%s).txt"
LOG_FILE="bucket-test-results-$(date +%Y%m%d-%H%M%S).log"

echo "=== S3 Bucket Testing Started ===" | tee $LOG_FILE
echo "Timestamp: $(date)" | tee -a $LOG_FILE
echo "Bucket: $BUCKET_NAME" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Test 1: Bucket accessibility
echo "Test 1: Bucket Accessibility" | tee -a $LOG_FILE
echo "------------------------------" | tee -a $LOG_FILE
if aws s3 ls s3://$BUCKET_NAME &>/dev/null; then
    echo "✅ Bucket is accessible" | tee -a $LOG_FILE
else
    echo "❌ Cannot access bucket" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 2: Upload functionality
echo "Test 2: Upload Test" | tee -a $LOG_FILE
echo "--------------------" | tee -a $LOG_FILE
echo "Test content for S3 upload" > $TEST_FILE
if aws s3 cp $TEST_FILE s3://$BUCKET_NAME/$TEST_FILE &>/dev/null; then
    echo "✅ File upload successful" | tee -a $LOG_FILE
else
    echo "❌ File upload failed" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 3: Download/Read functionality
echo "Test 3: Download Test" | tee -a $LOG_FILE
echo "---------------------" | tee -a $LOG_FILE
if aws s3 cp s3://$BUCKET_NAME/$TEST_FILE downloaded-$TEST_FILE &>/dev/null; then
    echo "✅ File download successful" | tee -a $LOG_FILE
    
    # Verify content integrity
    if diff $TEST_FILE downloaded-$TEST_FILE &>/dev/null; then
        echo "✅ File integrity verified" | tee -a $LOG_FILE
    else
        echo "❌ File integrity check failed" | tee -a $LOG_FILE
    fi
else
    echo "❌ File download failed" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 4: Bucket policy validation
echo "Test 4: Bucket Policy Check" | tee -a $LOG_FILE
echo "----------------------------" | tee -a $LOG_FILE
if aws s3api get-bucket-policy --bucket $BUCKET_NAME &>/dev/null; then
    echo "✅ Bucket policy is configured" | tee -a $LOG_FILE
else
    echo "⚠️  No bucket policy found (might be intentional)" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 5: Website configuration check
echo "Test 5: Website Configuration" | tee -a $LOG_FILE
echo "------------------------------" | tee -a $LOG_FILE
if aws s3api get-bucket-website --bucket $BUCKET_NAME &>/dev/null; then
    echo "✅ Website hosting is configured" | tee -a $LOG_FILE
else
    echo "❌ Website hosting not configured" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 6: Lifecycle configuration check
echo "Test 6: Lifecycle Rules" | tee -a $LOG_FILE
echo "------------------------" | tee -a $LOG_FILE
if aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET_NAME &>/dev/null; then
    echo "✅ Lifecycle rules are configured" | tee -a $LOG_FILE
else
    echo "⚠️  No lifecycle rules found" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 7: Versioning check
echo "Test 7: Versioning Status" | tee -a $LOG_FILE
echo "--------------------------" | tee -a $LOG_FILE
versioning_status=$(aws s3api get-bucket-versioning --bucket $BUCKET_NAME --query 'Status' --output text 2>/dev/null)
if [ "$versioning_status" = "Enabled" ]; then
    echo "✅ Versioning is enabled" | tee -a $LOG_FILE
else
    echo "ℹ️  Versioning status: ${versioning_status:-Suspended}" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 8: Encryption check
echo "Test 8: Encryption Status" | tee -a $LOG_FILE
echo "--------------------------" | tee -a $LOG_FILE
if aws s3api get-bucket-encryption --bucket $BUCKET_NAME &>/dev/null; then
    echo "✅ Bucket encryption is configured" | tee -a $LOG_FILE
else
    echo "⚠️  Bucket encryption not configured" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Cleanup
echo "Cleaning up test files..." | tee -a $LOG_FILE
aws s3 rm s3://$BUCKET_NAME/$TEST_FILE &>/dev/null
rm -f $TEST_FILE downloaded-$TEST_FILE

# Summary
echo "=== Test Summary ===" | tee -a $LOG_FILE
echo "Test completed at: $(date)" | tee -a $LOG_FILE
echo "Results saved to: $LOG_FILE" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "Note: Update BUCKET_NAME variable before running tests" | tee -a $LOG_FILE
