// raii_probe.rs — M1W1D1. The C `goto err_unlock` ladder, deleted by the compiler.
//
//   rustc raii_probe.rs -o probe && ./probe
//
// A pretend driver "probe" that acquires three resources, and any step can fail.
// There is NO cleanup code anywhere in probe(), yet every failure path releases
// exactly what was acquired, in reverse order. Predict each run before looking.

/// Stands in for memory, an IRQ, or a lock: something that must be given back.
struct Resource(&'static str);

impl Resource {
    /// `fail` simulates the allocator or the hardware saying no.
    fn acquire(name: &'static str, fail: bool) -> Result<Resource, String> {
        if fail {
            println!("      FAILED to acquire {}", name);
            return Err(format!("could not get {}", name));
        }
        println!("      acquired {}", name);
        Ok(Resource(name))
    }
}

impl Drop for Resource {
    fn drop(&mut self) {
        println!("      released {}", self.0);
    }
}

/// Fields are listed in REVERSE acquisition order on purpose. A struct drops its
/// fields top to bottom, so this order makes teardown release the lock first and
/// the memory last — the same reverse order the error paths use.
struct Device {
    _lock: Resource,
    _irq: Resource,
    _memory: Resource,
}

/// Acquire memory, then an IRQ, then a lock. `fail_at` picks the failing step; 0 = none.
fn probe(fail_at: u32) -> Result<Device, String> {
    let memory = Resource::acquire("memory", fail_at == 1)?;
    let irq = Resource::acquire("irq", fail_at == 2)?;
    let lock = Resource::acquire("lock", fail_at == 3)?;
    Ok(Device { _lock: lock, _irq: irq, _memory: memory })
}

fn main() {
    for fail_at in [1, 2, 3, 0] {
        println!("\n--- probe, failing at step {} ---", fail_at);
        match probe(fail_at) {
            Ok(_device) => println!("      probe succeeded; device in use..."),
            Err(e) => println!("      probe returned error: {}", e),
        }
    }
}
