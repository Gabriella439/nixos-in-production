# Continuous Integration

### Alternatives for continuous integration

In my opinion, there are three leading approaches for managing a central build server for a Nix-centric architecture:

- Hydra

  [Hydra](https://nixos.org/hydra/manual/) is a Nix-aware continuous integration service that is self-hosted[^1].  However, Hydra is (in my experience) difficult to support, maintain, and debug.

- garnix

  [garnix](https://garnix.io/) is a also a Nix-aware continuous integration service that is installed as a [GitHub application](https://github.com/apps/garnix-ci).  Garnix is more opinionated than Hydra, providing a simpler and more polished user experience but at the expense of less customizability and visibility into builds.

- A Nix agnostic CI solution

  e.g. [GitHub actions](https://github.com/features/actions), [Jenkins](https://www.jenkins.io/), or [CircleCI](https://circleci.com/)

  The idea is that you have a build agent run a `nix build` and otherwise not have any sort of special integration with Nix.

The solution I'd recommend depends on the context, but my usual heuristic is:

- Use garnix for open source projects

  Mainly because it's extremely lightweight to set up and "just works".  The reason I don't endorse garnix for proprietary projects is for caching reasons: garnix provides a cache for you, but the cache products eventually expire and you can't easily mirror build products to another cache (especially if the build fails).

- Use GitHub actions for simpler 

- Use Hydra if you need to scale out continuous integration

  In other words, if you have a large number of expensive builds or you frequently need to rebuild deep dependency trees then you should put in the work to set up and manage Hydra since it does the best job of utilizing available build capacity and giving visibility into the build process.



