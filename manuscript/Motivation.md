# What is NixOS for?

Some NixOS users might try to explain NixOS to others using a "pitch" that goes something like this:

> NixOS is a Linux distribution built on top of the Nix package manager.  It uses declarative configuration and allows reliable system upgrades.
>
> - [Wikipedia - NixOS](https://en.wikipedia.org/wiki/NixOS)

This sort of feature-oriented description does a great job of explaining what NixOS *does*, but this still does not quite explain what NixOS *is for*.  What useful things can you do with NixOS?  Where is NixOS the premiere solution?  What types of projects, teams, or organizations should prefer using NixOS over other available alternatives?

Come to think of it, what *are* the alternatives?  Is NixOS supposed to replace Debian?  Or Docker?  Or Ansible?  Or Vagrant?  Where does NixOS fit in within the modern software landscape?

In this chapter I'll help you better understand where you can warmly recommend NixOS to others and (just as important!) where you should gently nudge people away from NixOS.  Hopefully this chapter will improve your overall understanding of NixOS's "niche".

## Desktop vs. Server

The title of this book might have tipped you off that I will endorse NixOS for use a server operating system rather than a desktop operating system.

In my view, NixOS just doesn't cut it as a desktop operating system because:

- NixOS expects users to be developers who are more hands-on with their system

  NixOS does not come preinstalled on most computers and, even worse, the installation guide requires you to partition your hard drive before installation.  Also, NixOS can only be configured via text files and upgrades are issued from the command line.  Yuck!

- Nixpkgs doesn't enjoy mainstream support for desktop-oriented applications

  … such as games or productivity tools.  Nixpkgs is a fairly comprehensive software distribution, especially compared to other Linux software distributions, but most desktop applications will not support the Nix ecosystem out-of-the-box and non-technical users rely on experts to package things on their behalf.

- The NixOS user experience differs from what most desktop users expect

  Most desktop users (especially non-technical users) expect to install packages by either downloading the package from the publisher's web page or by visiting the App Store for their operating system.  They definitely don't expect to add some lines to a text configuration file in order to install package; that will be jarring to them no matter how easy it is.

However, the above limitations don't really matter when using NixOS as a server operating system:

- Servers are managed by technical users comfortable with command-line tools

  Server operating systems are often [headless](https://en.wikipedia.org/wiki/Headless_computer) machines that only support a command-line interface.  In fact, a mature Ops team would typically frown upon managing a server any other way ("a nice UI is bloat!").

- Nixpkgs provides amazing support for server-oriented software and services

  `nginx`, `postgres`, `redis`, … you name it, Nixpkgs most likely has it and
  it's a dream to set up.

- End users can more easily self-serve if they stray from the beaten path

  Nixpkgs excels at packaging open source software and services and for servers there is no shame in falling back to using containers if you're unable to package something yourself.

Moreover, NixOS possesses several unique advantages compared to other server-oriented operating systems:

- NixOS can be managed entirely declaratively

  You can manage every single aspect of a NixOS server using a single, uniform, declarative option system.  This works incredibly well with [GitOps](https://www.redhat.com/en/topics/devops/what-is-gitops) for managing a fleet of machines (which I'll cover in a future chapter).

- NixOS upgrades are fast, safe and reliable

  Upgrades are atomic, meaning that you can't leave a system in an unrecoverable state by cancelling the upgrade midway (e.g. `Ctrl-C`, loss of power).  You can also prebuild the desired system ahead of time if you want to ensure that the upgrade is quick and smooth.

- NixOS systems are lean, lean, lean

  If you like Alpine Linux then you'll *love* NixOS.  NixOS systems tend to be very light on disk, memory, and CPU resources because you only pay for what you use.  You can achieve astonishingly small system footprints whether you run services natively on the host or inside of containers.

- NixOS systems are more secure by default

  You get several security improvements for free or almost free by virtue of using NixOS.  For example, your system's footprint is immutable and internal references to filepaths or executables are almost always fully qualified.

## TODO:

- Explain why not to endorse NixOS for immature use cases.
