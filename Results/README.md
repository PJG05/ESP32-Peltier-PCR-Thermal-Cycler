
# PCR Thermal Cycler — Experimental Results

This document consolidates the measured hold-performance results and their interpretation from the uploaded `PCR_report.xlsx` dataset.

## 1. Actual Measured Hold Performance

The following calculations use samples labelled **Holding**, grouped cycle-by-cycle. A cycle mean is the average of that cycle's recorded hold samples. Cycle-to-cycle error spread is the standard deviation of those cycle means.

| Stage | Target | Recorded Cycles | Mean of Cycle Means | Mean Error | SD of Cycle Error | Average Hold Peak-to-Peak |
|---|---:|---:|---:|---:|---:|
| Denaturation | 95°C | 29 | 94.84°C | −0.16°C | 0.23°C | 2.28°C |
| Annealing | 60°C | 29 | 60.66°C | +0.66°C | 0.44°C | 2.81°C |
| Extension | 72°C | 29 | 72.57°C | +0.57°C | 0.23°C | 3.02°C |

### How to Interpret the Values

- **Mean Error:** Positive means the hold average was above target; negative means it was below target.
- **SD of Cycle Error:** Standard deviation across the 29 cycle-average hold errors. It describes cycle-to-cycle spread, not fluctuation within an individual hold.
- **Average Hold Peak-to-Peak:** For each cycle hold, maximum sampled temperature minus minimum sampled temperature; these ranges are then averaged across cycles. This is a full peak-to-peak range, not a ± value.
- **Cycle Mean:** Average of the temperature samples recorded during one cycle's hold.

### Recorded Temperature Ranges

#### Denaturation — 95°C

- Recorded cycles: 29
- Average cycle mean: 94.836°C
- Mean cycle error: −0.164°C
- SD between cycle errors: 0.235°C
- Recorded temperature range: **93.118°C–96.349°C**

#### Annealing — 60°C

- Recorded cycles: 29
- Average cycle mean: 60.659°C
- Mean cycle error: +0.659°C
- SD between cycle errors: 0.440°C
- Recorded temperature range: **58.559°C–62.824°C**

#### Extension — 72°C

- Recorded cycles: 29
- Average cycle mean: 72.569°C
- Mean cycle error: +0.569°C
- SD between cycle errors: 0.232°C
- Recorded temperature range: **70.761°C–74.740°C**

## 2. Sampling and Measurement Notes

- The recorded sample interval is approximately **5–6 seconds**.
- The values describe temperatures sampled and recorded during the hold phases.
- Recorded maximum/minimum values may not capture true instantaneous thermal extrema between samples.

## 3. Further Thermal Characterization

The following parameters have **not yet been rigorously calculated** and should not be reported as measured results until a defined analysis is completed.

| Parameter | Status | Description |
|---|---|---|
| Peak Overshoot | Future Characterization | Requires a defined target-transition reference and sufficiently time-resolved measurements to identify the peak beyond target. |
| Settling Time | Future Characterization | Requires a defined tolerance band and a criterion for how long temperature must remain within that band. |
| Heating/Cooling Ramp Rate | Future Characterization | Requires analysis of temperature change over time during ramp phases. |

These parameters can be evaluated in future characterization using time-resolved temperature data and explicit measurement criteria.

## 4. Scope and Limitations

- These results characterize recorded temperature behavior during hold phases; they do not establish biological PCR amplification performance.
- The dataset does not include electrical current measurements, ambient-temperature records, or a complete characterization of fan orientation and airflow.
- No power-loss recovery characterization is included here.
- Reported temperature ranges and peak-to-peak values are based on sampled data and may under-represent faster fluctuations.

## 5. Summary

The recorded hold data show mean cycle temperatures close to programmed targets:

- **Denaturation:** −0.16°C mean error
- **Annealing:** +0.66°C mean error
- **Extension:** +0.57°C mean error

Cycle-to-cycle standard deviations of cycle-average errors were **0.23°C, 0.44°C, and 0.23°C**, respectively.

Average sampled hold peak-to-peak ranges were:

- Denaturation: **2.28°C**
- Annealing: **2.81°C**
- Extension: **3.02°C**

These are **recorded hold-performance metrics**, not overshoot, settling-time, or biological-validation results.
