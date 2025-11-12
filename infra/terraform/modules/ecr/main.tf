<<<<<<< HEAD
resource "aws_ecr_repository" "backend" {
  name = "${var.project}-backend"

  image_scanning_configuration {
    scan_on_push = true
  }
}
=======
resource "aws_ecr_repository" "backend" { name = "${var.project}-backend" image_scanning_configuration{scan_on_push=true}}
>>>>>>> eca1baaa5cdec3a3cd1a54758194940fdd81d46d
