/*
 * QEMU pdp64 CPU QOM header (target agnostic)
 * SPDX-License-Identifier: BSD-2-Clause
 */
#ifndef PDP64_CPU_QOM_H
#define PDP64_CPU_QOM_H

#include "hw/core/cpu.h"

#define TYPE_PDP64_CPU "pdp64-cpu"

OBJECT_DECLARE_CPU_TYPE(PDP64CPU, PDP64CPUClass, PDP64_CPU)

#define PDP64_CPU_TYPE_SUFFIX "-" TYPE_PDP64_CPU
#define PDP64_CPU_TYPE_NAME(model) model PDP64_CPU_TYPE_SUFFIX
#define TYPE_PDP64_BASE_CPU PDP64_CPU_TYPE_NAME("pdp64")

#endif
