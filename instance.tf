resource "aws_key_pair" "auth"{
	key_name 		= "newKeyPair"
	public_key 		= "${file("newKeyPair.pub")}"
}

resource "aws_launch_template" "alb-template"{
  name_prefix = "alb-template"
  image_id = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.alb-sec-group.id}"]
  key_name = "${aws_key_pair.auth.key_name}"
  block_device_mappings{
    device_name = "/dev/sda1"
    ebs {
      volume_size = "40"
      volume_type = "gp2"
      delete_on_termination = "true"
    }
  }
  placement {
    availability_zone = "us-east-1a"
  }

}



resource "aws_autoscaling_group" "autoscale_group" {
  // availability_zones = ["us-east-1a"]
  vpc_zone_identifier = ["${aws_subnet.PrivateSubnetA.id}","${aws_subnet.PrivateSubnetB.id}","${aws_subnet.PrivateSubnetC.id}"]
  // load_balancers = ["${aws_lb.alb.name}"]
  target_group_arns    = ["${aws_alb_target_group.alb.arn}"]
  min_size = 3
  max_size = 3

  launch_template {
    id =  "${aws_launch_template.alb-template.id}"
    version = "$Latest"
  }
  tag {
    key = "Name"
    value = "autoscale"
    propagate_at_launch = true
  }
}


resource "aws_security_group" "alb-sec-group" {
    name            = "alb-sec-group"
	vpc_id          = "${aws_vpc.alb-vpc.id}"
	description     = "security group that allows all egress traffic"
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		from_port   = 22
		to_port     = 22
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
		Name = "alb-sec-group"
	}
}

resource "aws_lb" "alb" {
  name            = "alb"
  subnets         = ["${aws_subnet.PublicSubnetA.id}","${aws_subnet.PublicSubnetB.id}","${aws_subnet.PublicSubnetC.id}"]
  security_groups = ["${aws_security_group.alb-sec-group.id}"]
  internal        = false
  idle_timeout    = 60
  tags {
    Name    = "alb"
  }
}


resource "aws_lb" "alb-scaling"{
    name                = "alb-scaling-tf"
    load_balancer_type   = "application"
    subnets         = ["${aws_subnet.PublicSubnetA.id}","${aws_subnet.PublicSubnetB.id}","${aws_subnet.PublicSubnetC.id}"]
  	security_groups = ["${aws_security_group.alb-sec-group.id}"]
  	internal        = false
  	idle_timeout    = 60
  	tags {
    	Name    = "alb"
  	}

}

resource "aws_lb_target_group" "alb_target_group" {
  name     = "alb-target-group"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.alb-vpc.id}"
  tags {
    name = "alb_target_group"
  }
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = true
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/"
    port                = 80
  }
}


resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = "${aws_lb.alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.alb_target_group.arn}"
    type             = "forward"
  }
}
