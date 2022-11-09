# The big picture

Before diving in further you might want to get some idea of what a "real" NixOS software enterprise looks like.  Specifically:

- What are the guiding principles for a NixOS-centric software architecture?

- How does a NixOS-centric architecture differ from other architectures?

- What would a "NixOS team" need to be prepared to support and maintain?

Here I'll do my best to answer those questions so that you can get a better idea of what you would be signing up for.

## The Zen of NixOS

I like to use the term "master cue" to denote an overarching sign that indicates that you're doing things right.  This "master" cue" might not tell you *how* to do things right, but it can still provide a high-level indicator of whether you are on the right track.

The "master cue" for NixOS is very similar to the "master cue" for the Nix ecosystem, which is this:

> Every common build/test/deploy-related activity should be possible with at most one command using Nix's command line interface.

I say "*at most* one command" because some activities (like continuous deployment) should ideally require no human intervention at all.  However, activities that do require human intervention should in principle be compressible into a single Nix command.

I can explain this by providing an example of a development workflow that disregards this master cue:

Suppose that you want to test your local project's changes within the context of some larger system at work (i.e. an [integration test](https://en.wikipedia.org/wiki/Integration_testing).  Your organization's process for testing your code might hypothetically look like this:

- Create and publish a branch in version control recording your changes

- Manually trigger some job to build a software artifact containing your changes

- Update some configuration file to reference the newly-built software artifact

- Run the appropriate integration test

Now what if I told you that the entire integration testing process from start to finish could be:

- Run `nix flake check`

In other words:

- *There would be no need to create or publish your branch*

  You could test uncommitted changes straight from your local project checkout.


- *There would be no multi-step publication process*

  All of the intermediate build products and internal references would be handled transparently by the Nix build tool.


- *The test itself would be managed by the Nix build tool*

  In other words, Nix would treat your integration test no differently than any other build product.  Tests and their outputs *are* build products.


- *There would be no need to select the appropriate tests to rerun*

  The Nix build tool would automatically infer which tests depended on your project and rerun those.  Other test runs and their results would be cached if their dependency tree did not include your changes.


Some of these potential improvements are not specific to the Nix ecosystem.  After all, you could attempt to create a script that automates the more painstaking multi-step process.  However, you would likely need to reinvent large portions of the Nix ecosystem for this automation to be sufficiently robust and efficient.  For example:

- *Do you maintain an artifact repository or file server that you use for publishing and sharing intermediate build products?*

  Congratulations, you're implementing your own version of the Nix store and caching system


- *Do you generate unique labels for intermediate software artifact to isolate them?*

  In the best case scenario, the label is a hash of the artifact's transitive build-time dependencies and you've reinvented the hash component of `/nix/store` paths.  In the worst case scenario you're doing something different and worse (e.g. using timestamps instead of hashes).


- *Do you have some automation that updates references to these uniquely labeled build products?*

  This would be reinventing Nix's language support for updating dependency references.


- *Do you need to isolate your integration tests or run them in parallel?*

  You would likely reimplement the NixOS test framework.


You can save yourself a lot of headaches and professional embarrassment by taking time to learn and use the Nix ecosystem as idiomatically as possible instead of learning these lessons the hard way.

## GitOps

NixOS exemplifies the [Infrastructure as Code (IaC)](https://en.wikipedia.org/wiki/Infrastructure_as_code) paradigm, meaning that every aspect of your organization (including hardware/systems/software) is stored in code or configuration files that are the source of truth for how everything is built.  In particular, you don't make undocumented changes to your infrastructure that cause it to diverge from what is recorded within those files.

This book will go further and espouse a specific flavor of Infrastructure of Code known as [GitOps](https://about.gitlab.com/topics/gitops/) where:

- *The code and configuration files are (primarily) declarative*

  In other words, they tend to specify the desired state of the system rather than a sequence of steps to get there.


- *These files are stored in version control*

  Proponents of this approach most commonly use `git` as their version control software, which is why it's called "GitOps".


- *Pull requests are the change management system*

  In other words, the pull request review process determines whether you have sufficient privileges, enough vetting, or the correct approvals from relevant maintainers.


## DevOps

NixOS also exemplifies the [DevOps](https://en.wikipedia.org/wiki/DevOps) principle of breaking down boundaries between software developers ("Dev") and operations ("Ops").  Specifically, NixOS goes further in this regard than most other tools by unifying both software configuration and system configuration underneath the NixOS option system.

You can group NixOS options into three categories:

- *Systems configuration*

  These are options that are mostly interesting to operations engineers, such as:

  - log rotation policies
  - kernel boot parameters
  - disk encryption settings


- *Hybrid systems/software options*

  These are options that live in the grey area between Dev and Ops, such as:

  - Service restart policies
  - Networking
  - Credentials/secrets management


- *Software configuration*

  In other words, options that are mostly interesting to software engineers, such as:

  - Patches
  - Command-line arguments
  - Environment variables


In extreme cases, you can even embed non-Nix code and do "pure software development" entirely within NixOS.  In other words, you can author inline code written within another language inside of a NixOS configuration file.

An extreme example of this is my [`simple-twitter` project](https://github.com/Gabriella439/simple-twitter) which implements a bare-bones Twitter clone in a single Nix file.  There the server code is implemented in Haskell (a compiled language!) embedded inside of a NixOS option as a large multi-line string with some wrapping logic within the same file to build and run the Haskell code as a backend service.

Typically you don't want to embed non-Nix source code side-by-side with systems configuration options, but it's neat that NixOS makes this both possible *and* ergonomic.  This is one of many reasons why I view NixOS as the "king of DevOps" because no other tool encourages software engineers and operations engineers to work so closely side-by-side (literally within the same files).

## Scope

So far we've covered NixOS from a high-level standpoint, but you might more interested in a more down-to-earth picture of the day-to-day requirements and responsibilities for a professional NixOS user.

To that end, here is a checklist that will summarize what you would need to understand in order to effectively introduce and support NixOS within an organization:

- Infrastructure setup
  - Continuous integration
  - Builders
  - Caching
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
  - Dealing with restricted networks
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
  - System settings
  - Licenses
  - Vulnerabilities
- Non-NixOS Integrations
  - Images
  - Containers

This book will cover all of the above topics and more, although they will not necessarily be grouped or organize in that exact order.
