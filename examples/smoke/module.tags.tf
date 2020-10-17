module "tags" {
  source = "github.com/example/clz-tfmodule-base-tags?ref=1.0.13"

  tags = "${var.tags}"
}
