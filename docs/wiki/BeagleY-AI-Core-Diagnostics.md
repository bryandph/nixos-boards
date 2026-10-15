# Core runtime diagnostics

> Hardware results described here are historical observations, not fresh
> current-candidate acceptance. See [historical scope](BeagleY-AI-Hardware-Notes#historical-observation-scope);
> the generated hardware matrix retains conservative current status.

The fleet board exposes OP-TEE 4.6 with dynamic shared memory. Read-only
`TEE_IOC_VERSION` identified OP-TEE (implementation 1, implementation caps 1,
generic caps 0xd); `/dev/tee0` and `/dev/teepriv0` were root-only, mode 0600.
No trusted application session, secure storage operation, fuse or key operation
was performed. Those require an explicit trusted-application integration.

The hardware RNG provider was `optee-rng`. A bounded read succeeded without
printing or retaining entropy:

```sh
cat /sys/class/misc/hw_random/rng_current
timeout 5 dd if=/dev/hwrng of=/dev/null bs=32 count=1 status=none
```

This confirms the kernel interface, not an entropy quality certification.
See [CPU cooling](BeagleY-AI-CPU-Cooling) for PSCI, watchdog, LED, power-button and fan
interfaces and the distinction between baseline WFI and unsupported deep idle.
