variable "VERSION" {
  default = "2.0.0-dev.7"
}

variable "IMAGE_NAME" {
  default = "production"
}

variable "VCS_REF" {
  default = "unknown"
}

variable "PLATFORMS" {
  default = ["linux/amd64", "linux/arm64"]
}

group "default" {
  targets = [
    "php83", "php84", "php85",
    "laravel-php83", "laravel-php84", "laravel-php85"
  ]
}

group "generic" {
  targets = ["php83", "php84", "php85"]
}

group "laravel" {
  targets = ["laravel-php83", "laravel-php84", "laravel-php85"]
}

group "multiarch" {
  targets = [
    "php83-multiarch", "php84-multiarch", "php85-multiarch",
    "laravel-php83-multiarch", "laravel-php84-multiarch", "laravel-php85-multiarch"
  ]
}

target "common" {
  context    = "."
  dockerfile = "Dockerfile"
  args = {
    VERSION = "${VERSION}"
    VCS_REF = "${VCS_REF}"
  }
}

target "php83" {
  inherits = ["common"]
  args = {
    PHP_VERSION = "8.3"
    VARIANT     = "generic"
  }
  tags = ["${IMAGE_NAME}:${VERSION}-php8.3"]
}

target "php84" {
  inherits = ["common"]
  args = {
    PHP_VERSION = "8.4"
    VARIANT     = "generic"
  }
  tags = ["${IMAGE_NAME}:${VERSION}-php8.4"]
}

target "php85" {
  inherits = ["common"]
  args = {
    PHP_VERSION = "8.5"
    VARIANT     = "generic"
  }
  tags = ["${IMAGE_NAME}:${VERSION}-php8.5"]
}

target "laravel-php83" {
  inherits = ["common"]
  args = {
    PHP_VERSION = "8.3"
    VARIANT     = "laravel"
  }
  tags = ["${IMAGE_NAME}:${VERSION}-laravel-php8.3"]
}

target "laravel-php84" {
  inherits = ["common"]
  args = {
    PHP_VERSION = "8.4"
    VARIANT     = "laravel"
  }
  tags = ["${IMAGE_NAME}:${VERSION}-laravel-php8.4"]
}

target "laravel-php85" {
  inherits = ["common"]
  args = {
    PHP_VERSION = "8.5"
    VARIANT     = "laravel"
  }
  tags = ["${IMAGE_NAME}:${VERSION}-laravel-php8.5"]
}

target "php83-multiarch" {
  inherits  = ["php83"]
  platforms = PLATFORMS
}

target "php84-multiarch" {
  inherits  = ["php84"]
  platforms = PLATFORMS
}

target "php85-multiarch" {
  inherits  = ["php85"]
  platforms = PLATFORMS
}

target "laravel-php83-multiarch" {
  inherits  = ["laravel-php83"]
  platforms = PLATFORMS
}

target "laravel-php84-multiarch" {
  inherits  = ["laravel-php84"]
  platforms = PLATFORMS
}

target "laravel-php85-multiarch" {
  inherits  = ["laravel-php85"]
  platforms = PLATFORMS
}
