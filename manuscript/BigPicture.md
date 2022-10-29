# The big picture

Before diving in further you might want to get some idea of what a "real" NixOS software enterprise looks like.  Specifically:

- What are the guiding principles for a NixOS-centric software architecture?

- What would a "NixOS team" need to be prepared to support and maintain?

- How does a NixOS-centric architecture differ from other architectures?

- What does "success" look like?

Here I'll answer those questions so that you can get a better idea of what you would be signing up for.

## The Zen of NixOS

I like to use the term "master cue" to denote an overarching sign that indicates that you're doing things right.  The "master cue" for NixOS is very similar to the "master cue" for the Nix ecosystem, which is this:

> Every common build/test/deploy-related activity should be possible with at most a single command using Nix's command line interface.

I say "at most" because some activities (like continuous deployment) should ideally require no human intervention at all.  However, activities that do require human intervention should in principle be compressible into a single Nix command.

I can explain this by providing an example of an architectural pattern that violates this master cue:

Suppose that you want to test your local project's changes within the context of some larger system at work (i.e. an [integration test](https://en.wikipedia.org/wiki/Integration_testing).  The process for testing your code might hypothetically look like this:

- Create and publish a branch recording your changes so far in version control

- Manually trigger some job to build a software artifact containing your changes

  Perhaps the artifact is a container, executable binary, or JAR.

- Update some repository to reference the newly-built software artifact

- Run the appropriate integration test

  Your organization scores "bonus" points (for terrible workflows) if the integration test is not automated and you have to manually exercise the code paths that you modified.

Now what if I told you that the entire integration testing process from start to finish could be:

- Run `nix flake check`

In other words:

- There would be no need to create or publish your branch

  You could test uncommitted changes straight from your local project checkout.

- There would be no multi-step publish and reference process

  All of the intermediate build products and internal references would be handled transparently by the Nix build tool.

- The test itself would be managed by the Nix build tool

  In other words, Nix would treat your test no differently than any other build product.  Tests and their outputs *are* build products.

- There would be no need to select the appropriate tests to rerun

  Nix would automatically infer which tests depended on your project and rerun those.  Other test runs and their results would be cached if their dependency tree did not include your changes.

Some of these potential improvements are not specific to the Nix ecosystem.  After all, you could attempt to create a script that automates the more painstaking multi-step process.  However, you would likely run into several issues with respect to robustness and efficiency and inevitably reimplement what the Nix ecosystem gives you for free.  For example:

- Do you maintain an artifact repository or file server that you use for hosting
  intermediate build products?

  Congratulations, you're implementing your own version of the `/nix/store`.

- Do you generate unique labels for intermediate software artifact to isolate them?

  In the best case scenario, the label is a hash of the artifact's transitive build-time dependencies and you've reinvented the hash component of `/nix/store` paths.  In the worst case scenario you're doing something different and worse (e.g. using timestamps instead of hashes).

- Do you have some automation that updates references to these uniquely labeled build products?

  This would be reinventing Nix's language support for updating dependency references.

You can save yourself a lot of trouble by taking the time to use the Nix ecosystem as idiomatically as possible and in doing so you will greatly reduce your team's maintenance footprint.

## GitOps

NixOS exemplifies the [Infrastructure as Code (IaC)](https://en.wikipedia.org/wiki/Infrastructure_as_code) paradigm, meaning that everything about your systems (including hardware/system/software configuration) is recorded in configuration files that are the source of truth for how to assemble your infrastructure.

This book will go even further and espouse a specific flavor of Infrastructure of Code known as [GitOps](https://about.gitlab.com/topics/gitops/) where:

- The configuration files are (primarily) *declarative*

  In other words, they tend to specify the desired state of the system rather than the specific sequence of events to get there.

- These configuration files are stored in version control

  Proponents of this approach most commonly use `git` as their version control software, which is why it's called "GitOps".

- Pull requests are the change management system

  In other words, the pull request review process determines whether you have sufficient privileges, enough vetting, or the correct approvals from relevant maintainers.

## DevOps

NixOS also exemplifies the [DevOps](https://en.wikipedia.org/wiki/DevOps) principle of breaking down boundaries between software developers ("Dev") and operations ("Ops").  Specifically, the NixOS option system goes further in this regard than most other tools in the same space by unifying both software configuration and system configuration.

You can group NixOS options into three categories:

- Systems configuration

  These are options that are mostly interesting to operations engineers, such as:

  - log rotation policies
  - kernel boot parameters
  - disk encryption settings

- Hybrid systems/software options

  These are options that live in the grey area between Dev and Ops, such as

  - Service restart policies
  - Networking
  - Credentials/secrets management

- Software configuration

  In other words, options that are mostly interesting to software engineers, such as:

  - Patches
  - Command-line arguments
  - Environment variables

In extreme cases, you can even embed non-Nix code and do "pure software development" entirely within NixOS.  In other words, you can author inline code written within another language but inside of a NixOS configuration file.

An extreme example of this is my [`simple-twitter` project](https://github.com/Gabriella439/simple-twitter) which implements a bare-bones Twitter clone in a single Nix file.  There the server code is implemented in Haskell (a compiled language!) embedded inside of a NixOS option as a large multi-line string with some wrapping logic within the same file to build and run the Haskell code as a backend service.

Embedding non-Nix code side-by-side with systems configuration within the same file is not advisable in general, but it's neat that it's possible *and* ergonomic.  This is one of many reasons why I view NixOS as the "king of DevOps" because no other tool comes close in terms of allowing software engineers and operations engineers to work side-by-side (literally within the same file).

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
