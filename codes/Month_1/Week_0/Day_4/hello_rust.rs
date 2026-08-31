// SPDX-License-Identifier: GPL-2.0

//! Hello world, in Rust, running inside the kernel.
//!
//! The first kernel code in this repo that is not copied from `samples/rust/`.
//!
//! The same source builds two different ways, and that is the point of the exercise:
//!
//! - `CONFIG_SAMPLE_RUST_HELLO=m` builds a `hello_rust.ko` you load with `insmod`.
//!   `init` runs when you load it, `drop` when you `rmmod` it.
//! - `CONFIG_SAMPLE_RUST_HELLO=y` compiles this into `vmlinux` itself. `init` then runs
//!   during boot, before you reach a shell, and there is no way to unload it — so `drop`
//!   never runs.
//!
//! `built_in` below reports which one you are looking at, via `cfg!(MODULE)`, a
//! compile-time constant the build system defines only for loadable modules.

use kernel::prelude::*;

module! {
    type: HelloRust,
    name: "hello_rust",
    // Change this to your real name. It ends up in `modinfo hello_rust`.
    authors: ["ksanu"],
    description: "First hand-written Rust kernel module (M1W0D4 activity)",
    license: "GPL",
    params: {
        greetings: i64 {
            default: 3,
            description: "How many times to say hello (clamped to 1..=10)",
        },
    },
}

/// The module's state. Constructing this is initialisation; dropping it is cleanup.
struct HelloRust {
    /// Exists purely to prove that a fallible kernel allocation succeeded, and that
    /// `Drop` releases it without us writing a single `kfree`.
    greeted: KVec<i32>,
}

impl kernel::Module for HelloRust {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        let built_in = !cfg!(MODULE);

        // Never trust a module parameter. This one is an i64 supplied from outside, and
        // an unclamped value would drive the loop below into an allocation storm.
        let times = (*module_parameters::greetings.value()).clamp(1, 10);

        pr_info!("=====================================\n");
        pr_info!("  Hello, World! From Rust, in ring 0.\n");
        pr_info!("=====================================\n");
        pr_info!(
            "running as: {}\n",
            if built_in {
                "compiled into vmlinux (this line printed during boot)"
            } else {
                "a loadable module (.ko)"
            }
        );

        let mut greeted = KVec::new();
        for i in 1..=times {
            pr_info!("  hello {} of {}\n", i, times);
            // Two things no userspace `Vec::push` has: an allocation flag, and a Result.
            // GFP_KERNEL means "this allocation is allowed to sleep", which is true here
            // because module init runs in normal process context. `?` turns an allocation
            // failure into a failed insmod rather than a panic.
            greeted.push(i as i32, GFP_KERNEL)?;
        }

        pr_info!("recorded {} greetings on the kernel heap\n", greeted.len());

        Ok(HelloRust { greeted })
    }
}

impl Drop for HelloRust {
    fn drop(&mut self) {
        // Runs on rmmod. Reading self.greeted here is safe: the body of drop() executes
        // before the struct's fields are dropped.
        pr_info!("goodbye — greetings I recorded: {:?}\n", self.greeted);
        pr_info!("hello_rust unloaded; the allocation above is freed as this struct drops\n");
    }
}
