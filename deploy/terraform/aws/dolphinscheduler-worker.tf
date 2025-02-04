# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

locals {
  alert_server_ip = var.ds_component_replicas.alert > 0 ? aws_instance.alert[0].private_ip : aws_instance.standalone_server[0].private_ip
}

resource "aws_security_group" "worker" {
  name        = "worker_server_sg"
  description = "Allow incoming connections"
  vpc_id      = aws_vpc._.id
  ingress {
    from_port       = 1234
    to_port         = 1234
    protocol        = "tcp"
    security_groups = [aws_security_group.master.id, aws_security_group.api.id]
    description     = "Allow incoming HTTP connections"
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow incoming SSH connections (Linux)"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, {
    "Name" = "${var.name_prefix}-worker-sg"
  })
}

data "template_file" "worker_user_data" {
  template = file("templates/cloud-init.yaml")
  vars = {
    "ssh_public_key"             = aws_key_pair.key_pair.public_key
    "dolphinscheduler_version"   = var.ds_version
    "dolphinscheduler_component" = "worker-server"
    "database_address"           = aws_db_instance.database.address
    "database_port"              = aws_db_instance.database.port
    "database_name"              = aws_db_instance.database.db_name
    "database_username"          = aws_db_instance.database.username
    "database_password"          = aws_db_instance.database.password
    "zookeeper_connect_string"   = var.zookeeper_connect_string != "" ? var.zookeeper_connect_string : aws_instance.zookeeper[0].private_ip
    "alert_server_host"          = local.alert_server_ip
    "s3_access_key_id"           = aws_iam_access_key.s3.id
    "s3_secret_access_key"       = aws_iam_access_key.s3.secret
    "s3_region"                  = var.aws_region
    "s3_bucket_name"             = module.s3_bucket.s3_bucket_id
    "s3_endpoint"                = ""
  }
}

resource "aws_instance" "worker" {
  count = var.ds_component_replicas.worker

  ami                         = data.aws_ami.dolphinscheduler.id
  instance_type               = var.vm_instance_type.worker
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.worker.id]
  source_dest_check           = false
  associate_public_ip_address = var.vm_associate_public_ip_address.worker

  user_data = data.template_file.worker_user_data.rendered

  root_block_device {
    volume_size           = var.vm_root_volume_size.worker
    volume_type           = var.vm_root_volume_type.worker
    delete_on_termination = true
    encrypted             = true
    tags = merge(var.tags, {
      "Name" = "${var.name_prefix}-rbd"
    })
  }

  ebs_block_device {
    device_name           = "/dev/xvda"
    volume_size           = var.vm_data_volume_size.worker
    volume_type           = var.vm_data_volume_type.worker
    encrypted             = true
    delete_on_termination = true
    tags = merge(var.tags, {
      "Name" = "${var.name_prefix}-ebd"
    })
  }

  tags = merge(var.tags, {
    "Name" = "${var.name_prefix}-worker-${count.index}"
  })
}
