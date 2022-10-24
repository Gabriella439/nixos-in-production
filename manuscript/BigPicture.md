# The big picture

Before diving in further you might want to better understand what a "real" NixOS software enterprise looks like.  Specifically:

- What would a "NixOS team" need to support and maintain?

- How does a NixOS-centric software architecture differ from other architectures?

This chapter answers those questions so that you can get a better idea upfront of what you're signing up for.

## Scope

Here is a checklist of what you would need to understand in order to effectively support NixOS:

- Architectural components
  - Continuous integration
  - Builders
  - Cache
- Development
  - NixOS module system
  - Project organization
  - NixOS best practices
  - Quality controls
- Testing
  - Running virtual machines
  - Automated testing
- Deployment
  - Provisioning a new system
  - Upgrading a system
  - Dealing with estricted networks
- System administration
  - Infrastructure as code
  - Disk management
  - Filesystem
  - Networking
  - Users and authentication
  - Limits and quotas
- Security
  - System hardening
  - Patching dependencies
- Diagnostics and Debugging
  - Nix failures
  - Test failures
  - Production failures
  - Useful references
- Fielding inquiries
  - Licenses
  - System settings
  - Vulnerabilities
- Non-NixOS Integrations
  - Images
  - Containers

This book will cover all of the above topics and more.

There are two notable absences from the above checklist:

- Familiarity with the Nix expression language
- Familiarity with the Nixpkgs software distribution

This book focuses primarily on NixOS and while NixOS does build on top of the Nix language and Nixpkgs I will not focus too much on those.  I assume that you have some passing familiarity with the Nix ecosystem if you're reading this book and I'll also cover you what you need to know that is relevant to NixOS.
