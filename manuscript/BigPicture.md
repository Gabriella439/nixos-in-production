# The big picture

Before diving in further you might want to get some idea of what a "real" NixOS software enterprise looks like.  Specifically:

- What are the guiding principles for a NixOS-centric software architecture?

- How does a NixOS-centric architecture differ from other architectures?

- What would a "NixOS team" need to be prepared to support and maintain?

Here I'll do my best to answer those questions so that you can get a better idea of what you would be signing up for.

{id: zen}
## The Zen of NixOS

I like to use the term "master cue" to denote an overarching sign that indicates that you're doing things right.  This master cue might not tell you *how* to do things right, but it can still provide a high-level indicator of whether you are on the right track.

The master cue for NixOS is very similar to the master cue for the Nix ecosystem, which is this:

> Every common build/test/deploy-related activity should be possible with at most one command using Nix's command line interface.

I say "*at most* one command" because some activities (like continuous deployment) should ideally require no human intervention at all.  However, activities that do require human intervention should in principle be compressible into a single Nix command.

I can explain this by providing an example of a development workflow that *disregards* this master cue:

Suppose that you want to test your local project's changes within the context of some larger system at work (i.e. an [integration test](https://en.wikipedia.org/wiki/Integration_testing)).  Your organization's process for testing your code might hypothetically look like this:

- Create and publish a branch in version control recording your changes

- Manually trigger some workflow to build a software artifact containing your changes

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

- *Do you maintain a file server for storing intermediate build products?*

  You're likely implementing your own version of the Nix store and caching system


- *Do you generate unique labels for build products to isolate parallel workflows?*

  In the best case scenario, you label build products by a hash of their dependencies and you've reinvented the Nix store's hashing scheme.  In the worst case scenario you're doing something less accurate (e.g. using timestamps in the labels instead of hashes).


- *Do you have a custom script that updates references to these build products?*

  This would be reinventing Nix's language support for automatically updating dependency references.


- *Do you need to isolate your integration tests or run them in parallel?*

  You would likely reimplement the NixOS test framework.


You can save yourself a lot of headaches by taking time to learn and use the Nix ecosystem as idiomatically as possible instead of learning these lessons the hard way.

## GitOps

NixOS exemplifies the [Infrastructure as Code (IaC)](https://en.wikipedia.org/wiki/Infrastructure_as_code) paradigm, meaning that every aspect of your organization (including hardware/systems/software) is stored in code or configuration files that are the source of truth for how everything is built.  In particular, you don't make undocumented changes to your infrastructure that cause it to diverge from what is recorded within those files.

This book will espouse a specific flavor of Infrastructure of Code known as [GitOps](https://about.gitlab.com/topics/gitops/) where:

- *The code and configuration files are (primarily) declarative*

  In other words, they tend to specify the desired state of the system rather than a sequence of steps to get there.


- *These files are stored in version control*

  Proponents of this approach most commonly use `git` as their version control software, which is why it's called "GitOps".


- *Pull requests are the change management system*

  In other words, the pull request review process determines whether you have sufficient privileges, enough vetting, or the correct approvals from relevant maintainers.


## DevOps

NixOS also exemplifies the [DevOps](https://en.wikipedia.org/wiki/DevOps) principle of breaking down boundaries between software developers ("Dev") and operations ("Ops").  Specifically, NixOS goes further in this regard than most other tools by unifying both software configuration and system configuration underneath the NixOS option system.  These NixOS options fall into roughly three categories:

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

  These are options that are mostly interesting to software engineers, such as:

  - Patches
  - Command-line arguments
  - Environment variables


In extreme cases, you can even embed non-Nix code inside of Nix and do "pure software development".  In other words, you can author inline code written within another language inside of a NixOS configuration file.  I'll include one example of this later on in the "Our first web server" chapter.

{id: big-picture-architecture}
## Architecture

A NixOS-centric architecture tends to have the following key pieces of infrastructure:

- *Version control*

  If you're going to use GitOps then you had better use `git`!  More specifically, you'll likely use a `git` hosting provider like [GitHub](https://github.com/) or [GitLab](https://about.gitlab.com/) which supports pull requests and continuous integration.

  Most companies these days use version control, so this is not a surprising requirement.


- *Product servers*

  These are the NixOS servers that actually host your product-related services.


- *A central build server (the "hub")*

  This server initiates builds for continuous integration, which are delegated to builders.


- *Builders for each platform*

  These builders perform the actual Nix builds.  However, remember that integration tests will be Nix builds, too, so these builders also run integration tests.

  These builders will come in two flavors:

  - Builders for the hub (the "spokes")
  - Builders for developers to use


- *A cache*

  In simpler setups the "hub" can double as a cache, but as you grow you will likely want to upload build products to a dedicated cache.


- *One or more "utility" servers*

  A "utility" server is a NixOS server that you can use to host IT infrastructure and miscellaneous utility services to support developers (e.g. web pages, chat bots).

  This server will play a role analogous to a container engine or virtual machine hypervisor in other software architectures, except that we won't necessarily be using virtual machines or containers: many things will run natively on the host as NixOS services.  Of course, you can also use this machine to run a container engine or hypervisor in addition to running things natively on the host.

{blurb, class:warning}
A "utility" server should **not** be part of your continuous integration or continuous deployment pipeline.  You should think of such a server as a "junk drawer" for stuff that does not belong in CI/CD.
{/blurb}

Moreover, you will either need a cloud platform (e.g. [AWS](https://aws.amazon.com/)) or data center for hosting these machines.  In this book we'll primarily focus on hosting infrastructure on AWS.

These are not the only components you will need to build out your product, but these should be the only components necessary to support DevOps workflows, including continuous integration and continuous deployment.

Notably absent from the above list are:

- *Container-specific infrastructure*

  A NixOS-centric architecture already mitigates some of the need for containerizing services, but the architecture doesn't change much even if you do use containers, because containers can be built by Nixpkgs, distributed via the cache, and declaratively deployed to any NixOS machine.


- *Programming-language-specific infrastructure*

  If Nixpkgs supports a given language then we require no additional infrastructure to support building and deploying that language.  However,  we might still host language-specific amenities on our utility server, such as generated documentation.


- *Continuous-deployment services*

  NixOS provides out-of-the-box services that we can use for continuous deployment, which we will cover in a later chapter.


- *Cloud/Virtual development environments*

  Nix's support for development shells (e.g. `nix develop`) will be our weapon of choice here.


## Scope

So far I've explained NixOS in high-level terms, but you might prefer a more down-to-earth picture of the day-to-day requirements and responsibilities for a professional NixOS user.

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

This book will cover all of the above topics and more, although they will not necessarily be grouped or organized in that exact order.
