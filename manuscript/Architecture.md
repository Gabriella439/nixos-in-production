# A real-world NixOS architecture

In the previous chapter we deployed a standalone web server and that would likely be good enough for a small business or organization.  However, if you're planning to use NixOS within a larger organization you're probably going to need more supporting infrastructure to scale out development.

The following diagram shows a more complete NixOS architecture that we will cover in this chapter:

![](resources/architecture.png)

… and this chapter will include a sample Terraform template you can use for deploying this architecture diagram.

The ["big picture"](#big-picture-architecture) chapter briefly introduced these architectural components, but we'll cover them in more detail here.

## Product servers

These servers are the "business end" of your organization so we obviously can't omit them from our architecture diagram!
