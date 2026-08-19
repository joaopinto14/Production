variable "VERSION" {
  default = "2.0.0-dev.5"
}

group "default" {
  targets = [
    "php83", "php84", "php85",
    "laravel-php83", "laravel-php84", "laravel-php85"
  ]
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
    VARIANT     = "generic"
  }
  tags = ["production:${VERSION}-php8.3"]
}

target "php84" {
  inherits = ["common"]
  args = {
    VERSION     = "${VERSION}"
    PHP_VERSION = "8.4"
    VARIANT     = "generic"
  }
  tags = ["production:${VERSION}-php8.4"]
}

target "php85" {
  inherits = ["common"]
  args = {
    VERSION     = "${VERSION}"
    PHP_VERSION = "8.5"
    VARIANT     = "generic"
  }
  tags = ["production:${VERSION}-php8.5"]
}

target "laravel-php83" {
  inherits = ["common"]
  args = {
    VERSION     = "${VERSION}"
    PHP_VERSION = "8.3"
    VARIANT     = "laravel"
  }
  tags = ["production:${VERSION}-laravel-php8.3"]
}

target "laravel-php84" {
  inherits = ["common"]
  args = {
    VERSION     = "${VERSION}"
    PHP_VERSION = "8.4"
    VARIANT     = "laravel"
  }
  tags = ["production:${VERSION}-laravel-php8.4"]
}

target "laravel-php85" {
  inherits = ["common"]
  args = {
    VERSION     = "${VERSION}"
    PHP_VERSION = "8.5"
    VARIANT     = "laravel"
  }
  tags = ["production:${VERSION}-laravel-php8.5"]
}
