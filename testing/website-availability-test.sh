#!/bin/bash

# S3 Website Availability and Performance Test Script
# Tests website functionality, response times, and error handling

# Configuration
WEBSITE_URL="https://your-s3-website.s3-website-us-east-1.amazonaws.com"
ERROR_PAGE_URL="https://your-s3-website.s3-website-us-east-1.amazonaws.com/nonexistent-page"
LOG_FILE="test-results-$(date +%Y%m%d-%H%M%S).log"

echo "=== S3 Website Testing Started ===" | tee $LOG_FILE
echo "Timestamp: $(date)" | tee -a $LOG_FILE
echo "Website URL: $WEBSITE_URL" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Test 1: Basic connectivity and response time
echo "Test 1: Basic Connectivity" | tee -a $LOG_FILE
echo "-----------------------------" | tee -a $LOG_FILE
response_time=$(curl -o /dev/null -s -w "%{time_total}" "$WEBSITE_URL")
http_code=$(curl -o /dev/null -s -w "%{http_code}" "$WEBSITE_URL")

if [ "$http_code" -eq 200 ]; then
    echo "✅ Website is accessible (HTTP $http_code)" | tee -a $LOG_FILE
    echo "⏱️  Response time: ${response_time}s" | tee -a $LOG_FILE
else
    echo "❌ Website failed (HTTP $http_code)" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 2: Content validation
echo "Test 2: Content Validation" | tee -a $LOG_FILE
echo "----------------------------" | tee -a $LOG_FILE
content=$(curl -s "$WEBSITE_URL")
if echo "$content" | grep -q "S3 Storage Website"; then
    echo "✅ Website title found" | tee -a $LOG_FILE
else
    echo "❌ Website title missing" | tee -a $LOG_FILE
fi

if echo "$content" | grep -q "Professional Cloud Storage"; then
    echo "✅ Subtitle content found" | tee -a $LOG_FILE
else
    echo "❌ Subtitle content missing" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 3: Error page handling
echo "Test 3: Error Page Handling" | tee -a $LOG_FILE
echo "-----------------------------" | tee -a $LOG_FILE
error_code=$(curl -o /dev/null -s -w "%{http_code}" "$ERROR_PAGE_URL")
if [ "$error_code" -eq 404 ]; then
    echo "✅ 404 error handling works correctly" | tee -a $LOG_FILE
    
    # Check if custom error page is served
    error_content=$(curl -s "$ERROR_PAGE_URL")
    if echo "$error_content" | grep -q "Page Not Found"; then
        echo "✅ Custom error page is served" | tee -a $LOG_FILE
    else
        echo "⚠️  Default error page might be served" | tee -a $LOG_FILE
    fi
else
    echo "❌ Error handling issue (HTTP $error_code)" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Test 4: Performance check
echo "Test 4: Performance Metrics" | tee -a $LOG_FILE
echo "-----------------------------" | tee -a $LOG_FILE
curl -o /dev/null -s -w "DNS lookup: %{time_namelookup}s\nConnect: %{time_connect}s\nSSL handshake: %{time_appconnect}s\nFirst byte: %{time_starttransfer}s\nTotal time: %{time_total}s\nDownload size: %{size_download} bytes\nDownload speed: %{speed_download} bytes/sec\n" "$WEBSITE_URL" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Test 5: Mobile responsiveness check
echo "Test 5: Mobile User Agent Test" | tee -a $LOG_FILE
echo "--------------------------------" | tee -a $LOG_FILE
mobile_code=$(curl -o /dev/null -s -w "%{http_code}" -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)" "$WEBSITE_URL")
if [ "$mobile_code" -eq 200 ]; then
    echo "✅ Mobile user agent response: HTTP $mobile_code" | tee -a $LOG_FILE
else
    echo "❌ Mobile user agent failed: HTTP $mobile_code" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

# Summary
echo "=== Test Summary ===" | tee -a $LOG_FILE
echo "Test completed at: $(date)" | tee -a $LOG_FILE
echo "Results saved to: $LOG_FILE" | tee -a $LOG_FILE

# Performance thresholds
if (( $(echo "$response_time < 2.0" | bc -l) )); then
    echo "🚀 Performance: Good (< 2s)" | tee -a $LOG_FILE
elif (( $(echo "$response_time < 5.0" | bc -l) )); then
    echo "⚠️  Performance: Acceptable (2-5s)" | tee -a $LOG_FILE
else
    echo "🐌 Performance: Needs improvement (> 5s)" | tee -a $LOG_FILE
fi
