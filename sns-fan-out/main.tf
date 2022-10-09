#Create SNS topic
resource "aws_sns_topic" "sns-a" {
  name = "Insurance-Quote-Requests"
  kms_master_key_id = "alias/aws/sns"
}

#Create SQS queue
resource "aws_sqs_queue" "sqs-a" {
  name = "Vehicle-Insurance-Quotes"
  tags = {
    name = "Vehicle-Insurance-Quotes"
}
}
resource "aws_sqs_queue" "sqs-b" {
  name = "Life-Insurance-Quotes"
  tags = {
    name = "Life-Insurance-Quotes"
}
}
resource "aws_sqs_queue" "sqs-c" {
  name = "All-Quotes"
  tags = {
    name = "All-Quotes"
}
}

#Access policy for the queues
resource "aws_sqs_queue_policy" "sqs-pol-a" {
  queue_url = aws_sqs_queue.sqs-a.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.sqs-a.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.sns-a.arn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_sqs_queue_policy" "sqs-pol-b" {
  queue_url = aws_sqs_queue.sqs-b.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.sqs-b.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.sns-a.arn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_sqs_queue_policy" "sqs-pol-c" {
  queue_url = aws_sqs_queue.sqs-c.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.sqs-c.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.sns-a.arn}"
        }
      }
    }
  ]
}
POLICY
}
#Subscribe the queues to the topic
resource "aws_sns_topic_subscription" "sqs-sub-a" {
  topic_arn = aws_sns_topic.sns-a.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sqs-a.arn
  filter_policy = <<EOF
  {
    "insurance-type": ["car", "boat"]
    }
  EOF
  depends_on =[aws_sns_topic.sns-a,aws_sqs_queue.sqs-a]
}
resource "aws_sns_topic_subscription" "sqs-sub-b" {
  topic_arn = aws_sns_topic.sns-a.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sqs-b.arn
  filter_policy = <<EOF
  {
    "insurance-type": ["life"]
    }
  EOF
  depends_on =[aws_sns_topic.sns-a,aws_sqs_queue.sqs-b]
}
resource "aws_sns_topic_subscription" "sqs-sub-c" {
  topic_arn = aws_sns_topic.sns-a.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sqs-c.arn
  depends_on =[aws_sns_topic.sns-a,aws_sqs_queue.sqs-c]
}


#Publishing the message to the created SNS topic should be done manually
#Publish and poll the messages of the created queues and notice the messages getting filtered
#Refer the link, from step-5 to do so --->https://aws.amazon.com/getting-started/hands-on/filter-messages-published-to-topics/?trk=gs_card
