# What is Kai

Kai is a CLI that makes using determinate systems easy, friendly, and fun.

What if any computer device could be rebuilt _exactly_ from a file that you could easily backup, upload to a fresh device, or send to friends? What if the non-determinism introduced by modifying your computer with AI agents could be deterministically restrained, version-controlled? What if your whole setup was just code? What if, once you painstakingly figured out your setup, you never had to figure it out again?

[Nix](https://determinate.systems/) opened the door for the former, Kai aims to bring us home to the latter.

Spend very little time thinking about installing software, dependencies, developer environments, etc., and once you figure it out once, you _shouldn't have to figure it out again_. The problem is Nix is so hard to learn and use that people often give up (even agents get confused!). This is a complete paradigm shift in how we interact with software! But if no one uses it, what's the point?

To attempt a solution, `kai` wraps `nix` in a friendly frontend so that you can actually use it with confidence.

`kai` can already enter shells with the other determinate system, [Guix](https://guix.gnu.org/), and plans to support more of it. If we're lucky, maybe it will even get a custom implementation which learns from the mistakes of the others :eyes:

The goal is to make using determinate systems so easy and powerful that they become the de-facto choice for computer use in all its forms: from desktops to servers and beyond. Practically, this means adopting Nix under the hood and creating useful abstractions on top in the short term, like [jujutsu](https://github.com/jj-vcs/jj) does with `git`.

## Use Cases

- Completely reproducible machine setups for spinning up VMs/VPS/Self-hosted services
- Easy to understand, low-token cost dotfile setups for your desktop
- Easily customizable and shareable Linux "distros" from a single fileset

