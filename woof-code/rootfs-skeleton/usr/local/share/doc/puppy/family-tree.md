# Family Tree

DISTRO_NAME is a derivative of [Puppy Linux](https://puppylinux.com) built using [a fork of woof-CE](woof-CE.md), Puppy's build system.

```
              B
           10.0.x
           ┌─────┬──────────────────────────────┬──────────────
           │     └┐                   G        ┌┘ I
           │      └┐                11.0.x    ┌┘
   A       │       └┐              ┏━━━━━━━━━━┷━━━━━━━━┯━━━━━━━
testing    │        └┐ D           ┃                   └┐
───────────┴────┬────┴───┬────F────┸────┬─────┬─────────└┐─────
                │       ┌┘ E            └┐    │          └┐ K
                │      ┌┘                └┐   └───────────┴────
                │     ┌┘                  └┐          J
                │    ┌┘                    └┐     TrixiePup64
                │   ┌┘                      └┐ H
                └───┴────────────────────────┴─────────────────
                     C
                BookwormPup64
```

A. Back in the early days Vanilla Dpup, it was built using the [testing branch of upstream woof-CE](https://github.com/puppylinux-woof-CE/woof-CE). Unlike other Puppy variants and derivatives at the time, it was among the few built without manual intervention in the build process and without modification or replacement of various core Puppy components during the build process: `testing` was capable of faithfully reproducing Vanilla Dpup releases.

B. At some point, `testing` was forked into the [vanilladpup-10.0.x branch](https://github.com/vanilla-dpup/woof-CE/tree/vanilladpup-10.0.x) to "freeze" the woof-CE tree used to build Vanilla Dpup releases and prevent untested and risky changes in `testing`, like early development towards Vanilla Dpup 11.0.x, from reaching stable 10.0.x releases. Some fixes that went into 10.0.x releases were first pushed to `testing`, then cherry-picked into `vanilladpup-10.0.x`.

C. [BookwormPup64](https://forum.puppylinux.com/viewtopic.php?t=8690) is based on some Vanilla Dpup 10.0.x release but like most Puppy variants, BookwormPup64 is built from `testing` with various changes.

D. Some fixes were pushed directly into `vanilladpup-10.0.x` but later upstreamed. In other words, `vanilladpup-10.0.x` was a 'soft fork': a 'long-term support' version of woof-CE that gains fixes, doesn't gain new features, and feeds `testing` with fixes.

E. Over time, many of these changes in BookwormPup64 were upstreamed into `testing`, which became capable of reproducing BookwormPup64.

F. Early 11.0.x development, which includes [labwc](https://labwc.github.io/) support and decoupling from [ROX-Filer](https://rox.sourceforge.net/desktop/ROX-Filer), landed in `testing` and coexisted with BookwormPup64 and Vanilla Dpup 10.0.x.

G. Once the scope of changes grew and it became clear that some features (like support for unprivileged users) cannot be merged into upstream as optional features, in a backward compatible way (i.e. without breaking woof-CE's ability to produce a 'traditional' Puppy), `testing` was forked again to form the [vanilladpup-11.0.x branch](https://github.com/vanilla-dpup/woof-CE/tree/vanilladpup-11.0.x). After this point, Vanilla Dpup 11.0.x development continued in this branch and `vanilladpup-11.0.x` became a 'hard fork' of `testing` with extensive changes and no plan to merge in the future.

H. Later releases of BookwormPup64 were built with latest `testing`, pulling fixes upstreamed from `vanilladpup-10.0.x`.

I. Later, some features and fixes that first appeared in `vanilladpup-11.0.x` were backported to 10.0.x, allowing users to benefit from them even before the stable release of 11.0.x.

J. The [TrixiePup64](https://forum.puppylinux.com/viewtopic.php?t=14554) beta, like BookwormPup64, was built using `testing` plus various modifications, but builds on the early 11.0.x development work that went into `testing`, like [labwc](https://labwc.github.io/) support.

K. At the same time, the TrixiePup64 beta cherry-picks some changes that went into `vanilladpup-11.0.x` and continues to omit most features introduced in Vanilla Dpup since the release of BookwormPup64.

To summarize:
* Vanilla Dpup 10.0.x is built from a 'frozen' version of woof-CE, which doesn't change much.
* BookwormPup64 is originally based on Vanilla Dpup 10.0.x, but both contain exclusive features and changes.
* Vanilla Dpup 11.0.x is built from a fork of woof-CE, with big changes.
* TrixiePup64 is based on very early Vanilla Dpup 11.0.x development builds and doesn't incorporate the big changes in this fork.
* Some features and fixes that first appeared in this fork were backported to Vanilla Dpup 10.0.x.
