 #Create DynamoDB table
 resource "aws_dynamodb_table" "db" {
  name           = "Music"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "Artist"
  range_key      = "Title"

attribute {
    name = "Artist"
    type = "S"
  }

  attribute {
    name = "Title"
    type = "S"
  }
  tags = {
    "Name" = "Music"
  }
 }

#Enable DynamoDB Autoscaling
resource "aws_appautoscaling_target" "dynamodb_table_read_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "table/${aws_dynamodb_table.db.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_read_policy" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_read_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_read_target.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_read_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_read_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value = 70
  }
}

resource "aws_appautoscaling_target" "dynamodb-test-table_write_target" {
    max_capacity       = 10
    min_capacity       = 1
    resource_id        = "table/${aws_dynamodb_table.db.name}"
    scalable_dimension = "dynamodb:table:WriteCapacityUnits"
    service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb-test-table_write_policy" {
    name               = "dynamodb-write-capacity-utilization-${aws_appautoscaling_target.dynamodb-test-table_write_target.resource_id}"
    policy_type        = "TargetTrackingScaling"
    resource_id        = "${aws_appautoscaling_target.dynamodb-test-table_write_target.resource_id}"
    scalable_dimension = "${aws_appautoscaling_target.dynamodb-test-table_write_target.scalable_dimension}"
    service_namespace  = "${aws_appautoscaling_target.dynamodb-test-table_write_target.service_namespace}"

    target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
            predefined_metric_type = "DynamoDBWriteCapacityUtilization"
        }
        target_value = 70
    }
}

#Adding data(items)to the table
resource "aws_dynamodb_table_item" "item-a" {
  table_name = aws_dynamodb_table.db.name
  hash_key   = aws_dynamodb_table.db.hash_key
  range_key = aws_dynamodb_table.db.range_key

item = <<ITEM
{
  "${aws_dynamodb_table.db.hash_key}": {"S": "Weekend"},
  "${aws_dynamodb_table.db.range_key}": {"S": "Starboy"}
}
ITEM
depends_on = [
  aws_dynamodb_table.db
]
}

resource "aws_dynamodb_table_item" "item-b" {
  table_name = aws_dynamodb_table.db.name
  hash_key   = aws_dynamodb_table.db.hash_key
  range_key = aws_dynamodb_table.db.range_key

item = <<ITEM
{
  "${aws_dynamodb_table.db.hash_key}": {"S": "Weekend"},
  "${aws_dynamodb_table.db.range_key}": {"S": "Die For You"}
}
ITEM
depends_on = [
  aws_dynamodb_table.db
]
}

resource "aws_dynamodb_table_item" "item-c" {
  table_name = aws_dynamodb_table.db.name
  hash_key   = aws_dynamodb_table.db.hash_key
  range_key = aws_dynamodb_table.db.range_key

item = <<ITEM
{
  "${aws_dynamodb_table.db.hash_key}": {"S": "Eminem"},
  "${aws_dynamodb_table.db.range_key}": {"S": "Not Afraid"}
}
ITEM
depends_on = [
  aws_dynamodb_table.db
]
}
