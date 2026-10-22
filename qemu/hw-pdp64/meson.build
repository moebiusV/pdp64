pdp64_ss = ss.source_set()
pdp64_ss.add(when: 'CONFIG_PDP64_VIRT', if_true: files('virt.c', 'timer.c', 'console.c'))

hw_arch += {'pdp64': pdp64_ss}
