#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
WORKING_DIR=/root/aws-spot-asg-custom-metrics
echo "INSTANCE_ID=$INSTANCE_ID" >>/var/log/initial-setup.log
echo "STACKID=$STACKID" >>/var/log/initial-setup.log

echo "AUTOSCALINGGROUPNAME=$AUTOSCALINGGROUPNAME" >>/var/log/initial-setup.log
echo "IMAGEID=$IMAGEID" >>/var/log/initial-setup.log
echo "INSTANCETYPE=$INSTANCETYPE" >>/var/log/initial-setup.log

echo "REGION=$REGION" >>/var/log/initial-setup.log
echo "S3BUCKET=$S3BUCKET" >>/var/log/initial-setup.log
echo "SQSQUEUE=$SQSQUEUE" >>/var/log/initial-setup.log
echo "CLOUDWATCHLOGSGROUP=$CLOUDWATCHLOGSGROUP" >>/var/log/initial-setup.log
echo "WAITCONDITIONHANDLE=\"$WAITCONDITIONHANDLE\"" >>/var/log/initial-setup.log



yum -y --security update

yum -y update aws-cli

yum -y install \
  awslogs jq ImageMagick

rpm -Uvh https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm

aws configure set default.region $REGION
mkdir /etc/cfn
mkdir /etc/cfn/hooks.d
mkdir /lib/systemd
mkdir /lib/systemd/system



cp -av $WORKING_DIR/awslogs.conf /etc/awslogs/
cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.conf /etc/init/spot-instance-interruption-notice-handler.conf
cp -av $WORKING_DIR/convert-worker.conf /etc/init/convert-worker.conf
cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.sh /usr/local/bin/
cp -av $WORKING_DIR/convert-worker.sh /usr/local/bin

sed -i "s|%CLOUDWATCHLOGSGROUP%|$CLOUDWATCHLOGSGROUP|g" $WORKING_DIR/amazon-cloudwatch-agent.json
cp -av $WORKING_DIR/amazon-cloudwatch-agent.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
cp -av $WORKING_DIR/cfn-hup.conf /etc/cfn/cfn-hup.conf
cp -av $WORKING_DIR/amazon-cloudwatch-agent-auto-reloader.conf /etc/cfn/hooks.d/amazon-cloudwatch-agent-auto-reloader.conf
cp -av $WORKING_DIR/cfn-hup.service /lib/systemd/system/cfn-hup.service



chmod +x /usr/local/bin/spot-instance-interruption-notice-handler.sh
chmod +x /usr/local/bin/convert-worker.sh

chmod 400 /etc/cfn/hooks.d/amazon-cloudwatch-agent-auto-reloader.conf
chmod 400 /etc/cfn/cfn-hup.conf

sed -i "s|us-east-1|$REGION|g" /etc/awslogs/awscli.conf
sed -i "s|%CLOUDWATCHLOGSGROUP%|$CLOUDWATCHLOGSGROUP|g" /etc/awslogs/awslogs.conf
sed -i "s|%REGION%|$REGION|g" /usr/local/bin/convert-worker.sh
sed -i "s|%S3BUCKET%|$S3BUCKET|g" /usr/local/bin/convert-worker.sh
sed -i "s|%SQSQUEUE%|$SQSQUEUE|g" /usr/local/bin/convert-worker.sh


sed -i "s|%STACKID%|$STACKID|g" /etc/cfn/cfn-hup.conf
sed -i "s|%REGION%|$REGION|g" /etc/cfn/cfn-hup.conf

sed -i "s|%STACKID%|$STACKID|g" /etc/cfn/hooks.d/amazon-cloudwatch-agent-auto-reloader.conf
sed -i "s|%REGION%|$REGION|g" /etc/cfn/hooks.d/amazon-cloudwatch-agent-auto-reloader.conf

chkconfig awslogs on && service awslogs restart

start spot-instance-interruption-notice-handler
start convert-worker

chkconfig cfn-hup on
service cfn-hup start

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a stop
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m auto -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s


/opt/aws/bin/cfn-signal -s true -i $INSTANCE_ID "$WAITCONDITIONHANDLE"




