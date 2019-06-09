#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
WORKING_DIR=/root/ec2-spot-labs/sqs-ec2-spot-fleet-autoscaling

yum -y --security update

yum -y update aws-cli

yum install -y perl-Switch perl-DateTime perl-Sys-Syslog perl-LWP-Protocol-https perl-Digest-SHA.x86_64

yum -y install \
  awslogs jq ImageMagick

aws configure set default.region $REGION

cp -av $WORKING_DIR/awslogs.conf /etc/awslogs/
cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.conf /etc/init/spot-instance-interruption-notice-handler.conf
cp -av $WORKING_DIR/convert-worker.conf /etc/init/convert-worker.conf
cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.sh /usr/local/bin/
cp -av $WORKING_DIR/convert-worker.sh /usr/local/bin

chmod +x /usr/local/bin/spot-instance-interruption-notice-handler.sh
chmod +x /usr/local/bin/convert-worker.sh

sed -i "s|us-east-1|$REGION|g" /etc/awslogs/awscli.conf
sed -i "s|%CLOUDWATCHLOGSGROUP%|$CLOUDWATCHLOGSGROUP|g" /etc/awslogs/awslogs.conf
sed -i "s|%REGION%|$REGION|g" /usr/local/bin/convert-worker.sh
sed -i "s|%S3BUCKET%|$S3BUCKET|g" /usr/local/bin/convert-worker.sh
sed -i "s|%SQSQUEUE%|$SQSQUEUE|g" /usr/local/bin/convert-worker.sh

cd /opt
curl https://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.2.zip -O
unzip -o CloudWatchMonitoringScripts-1.2.2.zip
rm -rf CloudWatchMonitoringScripts-1.2.2.zip
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/aws-scripts-mon/mon-put-instance-data.pl --mem-used-incl-cache-buff --mem-util --disk-space-util --disk-path=/ --from-cron") | crontab -

chkconfig awslogs on && service awslogs restart

start spot-instance-interruption-notice-handler
start convert-worker

/opt/aws/bin/cfn-signal -s true -i $INSTANCE_ID "$WAITCONDITIONHANDLE"


