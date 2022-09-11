# What is NixOS for?

Some NixOS users might try to "convert" others to NixOS using a pitch that goes
something like this:

> NixOS is a Linux distribution built on top of the Nix package manager.  It
> uses declarative configuration and allows reliable system upgrades.
>
> - [Wikipedia - NixOS](https://en.wikipedia.org/wiki/NixOS)

This sort of feature-oriented description explains what NixOS *does*, but does
not quite explain what NixOS *is for*.  What sort of useful things can you do
with NixOS?  When is NixOS the best solution?  What types of projects, teams, or
organizations should prefer using NixOS over other the alternatives?

Come to think of it, what *are* the alternatives?  Is NixOS supposed to replace
Debian?  Or Docker?  Or Ansible?  Or Vagrant?  Where does NixOS fit in within
the modern software landscape?

In this chapter I'll help you better understand where you can warmly recommend
NixOS to others and (just as important!) where you should gently nudge people
away from NixOS.  Hopefully this chapter will improve your overall understanding
of NixOS's "niche".

We can begin to narrow down the use cases for NixOS by comparing two broad
operating system categories: desktop versus server.

## Desktop vs. Server

The title of this book might have tipped you off that I will endorse NixOS for
use as a server operating system rather than a desktop operating system.

In my view, NixOS does not cut it as a desktop operating system because:

- NixOS expects users to be developers who are more hands-on with their system

  NixOS does not come preinstalled on most computers and the installation guide
  assumes quite a bit of technical proficiency (such as comfort partitioning
  one's drive).  Also, NixOS can only be configured via text files and upgrades
  are issued from the command line.

- Nixpkgs doesn't enjoy mainstream support for desktop-oriented applications

  … such as games or productivity tools.  Nixpkgs is a fairly large software
  distribution, especially compared to other Linux software distributions, but
  most desktop applications will not support the Nix ecosystem out-of-the-box
  and non-technical users rely on experts to package things on their behalf.

- The NixOS user experience differs from what most desktop users expect

  Most desktop users (especially non-technical users) expect to install packages
  by either downloading the package from the publisher's web page or by visiting
  an App Store of some sort.  They don't expect to modify a text configuration
  file in order to install package.

However, the above limitations don't apply when using NixOS as a server
operating system:

- Servers are managed by technical users comfortable with the command-line

  Server operating systems are often
  [headless](https://en.wikipedia.org/wiki/Headless_computer) machines that only
  support a command-line interface.  In fact, a typical Ops team would likely
  frown upon managing a server any other way.

- Nixpkgs provides amazing support for server-oriented software and services

  `nginx`, `postgres`, `redis`, … you name it, Nixpkgs most likely has the
  service you need and it's a dream to set up. 😍

- End users can more easily self-serve if they stray from the beaten path

  Nixpkgs does a great job of packaging server-oriented software and services;
  the coverage and quality are both great.

Furthermore, NixOS possesses several unique advantages compared to other
server-oriented operating systems:

- NixOS can be managed entirely declaratively

  You can manage every single aspect of a NixOS server using a single, uniform,
  declarative option system.  This works incredibly well with
  [GitOps](https://www.redhat.com/en/topics/devops/what-is-gitops) for managing
  a fleet of machines (which I'll cover in a future chapter).

- NixOS upgrades are fast, safe and reliable

  Upgrades are atomic, meaning that you can't leave a system in an unrecoverable
  state by canceling the upgrade midway (e.g. `Ctrl-C`, loss of power).  You can
  also build the desired system ahead of time if you want to ensure that the
  upgrade is quick and smooth.

- NixOS systems are lean, lean, lean

  If you like Alpine Linux then you'll *love* NixOS.  NixOS systems tend to be
  very light on disk, memory, and CPU resources because you only pay for what
  you use.  You can achieve astonishingly small system footprints whether you
  run services natively on the host or inside of containers.

- NixOS systems are more secure by default

  You get several security improvements for free or almost free by virtue of
  using NixOS.  For example, your system's footprint is immutable and internal
  references to filepaths or executables are almost always fully qualified.

## On-premises vs. Software as a service

"Server operating systems" is still a fairly broad category and we can narrow
things down further to where we deploy the server:

- On-premises ("on-prem" for short)

  "On-premises" software runs within the within the end user's environment.  For
  example, if the software product is a server then an on-premises deployment
  runs within the customer's data center, either as a virtual machine or a rack
  server.

- Software as a service ("SaaS" for short)

  The opposite of on-premises is "off-premises" (more commonly known as
  "software as a service").  This means that you centrally host your software,
  either in your data center or in the cloud, and customers interact with the
  software via a web interface or API.

NixOS is better suited for SaaS than on-prem deployments, because NixOS fares
worse when deployed on-premises in restricted network environments, meaning that
network access is limited or unavailable.

You can deploy NixOS in restricted network environments and I will cover that in
a later chapter, but you will have a much better time using NixOS to host
software as a service.

## Virtualization

You might be interested in how NixOS fares with respect to virtualization or
containers, so I'll break things down into these four potential use cases:

- NixOS without virtualization

  You can run NixOS on a bare metal machine (e.g. a desktop or rack server)
  without any virtual machines or containers.  This implies that services run
  directly on the bare metal machine.

- NixOS as a host operating system

  You can also run NixOS on a bare metal machine (i.e the "host") but then on
  that machine you run containers or virtual machines (i.e. the "guests").
  Typically, you do this if you want services to run inside the guest machines.

- NixOS as a guest operating system

  Virtual machines or "OS containers" can run a full-fledged operating system
  inside of them, which can itself be a NixOS operating system.  I consider this
  morally the same as the "no virtualization" use case because in both cases the
  services run directly on NixOS.

- Application containers

  Containers technically do not need to run an entire operating system and can
  instead run a single process (e.g. one service).  You can do this using
  Nixpkgs (not NixOS), which provides support for building application
  containers.

So which use cases are NixOS/Nixpkgs well-suited for?  If I had to rank these
deployment models then my preference (in descending order) would be:

1.  NixOS as a guest operating system

    Specifically, this means that you would run NixOS as a virtual machine on a
    cloud provider (e.g. AWS) and all of your services run within that NixOS
    guest machine with no intervening containers.

    I prefer this because this is the leanest deployment model and the lowest
    maintenance to administer.

1.  NixOS without virtualization

    This typically entails running NixOS on a bare-metal rack server and you
    still use NixOS to manage all of your services without containers.

    This is the most cost-effective deployment model if you're willing to manage
    your own hardware (including RAID and backup/restore) or you operate your
    own data center.

1.  NixOS as a host operating system - Static containers

    NixOS is amazing if you can statically specify the set of containers that
    you want to run.  You can not only run Docker / OCI containers, but you
    get even better vertical integration if you run "NixOS containers" (which
    are `systemd-nspawn` containers under the hood) or application containers
    built by Nixpkgs.

    I rank this lower than "NixOS without virtualization" because NixOS obviates
    some (but not all) of the reasons for using containers, which means that the
    added cost of containerizing things can dwarf the benefit.

1.  NixOS as a host operating system - Dynamic containers

    You can also use NixOS to run containers dynamically, but NixOS is not
    special in this regard.  At best, NixOS might simplify administering a
    container orchestration service (e.g.  `kubernetes`), but that alone might
    not justify the switching costs of using NixOS.

1.  Application containers sans NixOS

    This is technically a use case for Nixpkgs and not NixOS, but I mention it
    for completeness.  Application containers built by Nixpkgs work best if you
    are trying to introduce the Nix ecosystem (but not NixOS) within a legacy
    environment.

    However, you lose out on the benefits of using NixOS because, well, you're
    no longer using NixOS.

## The killer app for NixOS

Based on the above guidelines, we can outline the ideal use case for NixOS:

- NixOS shines as a server operating system for SaaS deployments

- The services should be statically defined via the NixOS configuration

- NixOS can containerize these services, but it's simpler to skip the containers

- NixOS should handle service orchestration

If your deployment model matches that outline then NixOS is not only a safe
choice, but likely the best choice!  You will be in good company if you use
NixOS this way.

You can still use NixOS in other capacities, but the further you depart from the
above "killer app" the more you will need to roll up your sleeves.

## What does NixOS replace?

If NixOS is a server operating system, does that mean that NixOS competes with
Ubuntu Server, Debian or Fedora?

Actually, NixOS competes more with the Docker ecosystem, meaning that a lot of
the value that NixOS adds overlaps with Docker:

- NixOS supports declarative system specification

  … analogous to `docker compose`.

- NixOS provides better service isolation

  … analogous to containers.

- NixOS uses the Nix package manager to declaratively assemble software

  … analogous to `Dockerfile`s

So NixOS is the Docker killer more than it is the Debian killer.  The killer use
case for NixOS overlaps substantially with the use case for the Docker
ecosystem.

You can use NixOS in conjunction with just Docker containers since NixOS
supports declaratively orchestrating containers (like `docker compose`), but
you probably want to avoid buying further into the broader Docker ecosystem.
You don't want to be in a situation where your engineering organization does
everything in two different ways, the NixOS way and the Docker way, because then
you'll fragment your tooling and developer workflows.

Or to put it another way: **NixOS is like Gentoo, but for Docker**.  Like
Gentoo, NixOS is an operating system that provides unparalleled control over the
machine due to everything being rebuildable from source while targeting use
cases and workflows similar to the Docker ecosystem.
