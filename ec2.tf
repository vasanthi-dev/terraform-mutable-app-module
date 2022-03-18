resource "aws_spot_instance_request" "ec2-spot" {
  count = var.INSTANCE_COUNT
  ami           = data.aws_ami.ami.id
  instance_type = var.INSTANCE_TYPE

  tags = {
    Name = "${var.COMPONENT}-${var.ENV}-${count.index+1}"
  }
  subnet_id = data.terraform_remote_state.vpc.outputs.PRIVATE_SUBNETS[count.index]
  wait_for_fulfillment = true
  vpc_security_group_ids = [aws_security_group.sg.id]
}

resource "aws_ec2_tag" "spot-instances" {
  count = length(aws_spot_instance_request.ec2-spot)
  resource_id = aws_spot_instance_request.ec2-spot.*.spot_instance_id[count.index]
  key         = "Name"
  value       = "${var.COMPONENT}-${var.ENV}-${count.index+1}"
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.COMPONENT}-${var.ENV}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.vpc.outputs.VPC_ID
}

resource "aws_lb_target_group_attachment" "tg-attach" {
  count            = length(aws_spot_instance_request.ec2-spot)
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_spot_instance_request.ec2-spot.*.spot_instance_id[count.index]
  port             = 80
}

resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = data.terraform_remote_state.alb.outputs.ALB_PUBLIC_ARN
  port              = "80"
  protocol          = "HTTP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}