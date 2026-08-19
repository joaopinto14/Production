variable "VERSION" {
  default = "2.0.0-dev.4"
}

group "default" {
  targets = ["php83", "php84", "php85"]
}

target "common" {
  context    = "."
  dockerfile = "Dockerfile"
}

target "php83" {
  inherits = ["common"]
  args = {
    VERSION     = "${VERSION}"
    PHP_VERSION = "8.3"
  }
  tags = ["production:${VERSION}-php8.3"]
}

target "php84" {
  inherits = ["common"]
  args = {
    VERSION     = "${VERSION}"
    PHP_VERSION = "8.4"
  }
  tags = ["production:${VERSION}-php8.4"]
}

target "php85" {
  inherits = ["common"]
  args = {
    VERSION     = "${VERSION}"
    PHP_VERSION = "8.5"
  }
  tags = ["production:${VERSION}-php8.5"]
}
