# Security policy

Production's maintained PHP/Alpine variants and end-of-support rules are defined
in [SUPPORT.md](SUPPORT.md). Only newly built, validated and published releases
receive package corrections. Historical version tags and running containers do
not update automatically.

## Report a vulnerability

Email **geral@joaopinto.pt** with the affected version or image digest, variant,
architecture, impact and minimal reproduction steps. Include scanner/database
versions for package findings. Do not include credentials, private application
code or sensitive logs. Please use this private channel for source exposure,
privilege escalation, release-integrity defects or other exploitable findings.

Reports are reviewed by the maintainer. This project does not promise a response
or remediation SLA. Fixes are published as new versions with release notes and
migration guidance when required. Package versions alone do not establish that a
vulnerability is fixed; the relevant advisories and the exact image matter.

## Deployment responsibilities

The image runs as a non-root user and supports a read-only root filesystem,
dropped capabilities and no-new-privileges. Follow the documented writable-mount
ownership and stop-grace requirements. Terminate TLS at a trusted ingress/proxy,
configure trusted proxies in the application and keep secrets out of image
layers and URLs. The runtime health check does not validate application database
or queue progress.

See the [release verification procedure](docs/RELEASING.md#verify-and-consume-a-release)
for digest, signature, SBOM and provenance checks. A passed scan is evidence for
that image and database snapshot, not a guarantee of no vulnerabilities.
