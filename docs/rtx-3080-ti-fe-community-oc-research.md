# RTX 3080 Ti Founders Edition community overclock research

Date: 2026-09-06

## Short answer

Our result was not an improvement: five-run 3440x1440 off-screen `glmark2` median changed from **12,788 stock** to **12,659 with the full profile** (**-1.01%**). That is plausible for this card. The RTX 3080 Ti FE already boosts well at stock, and its compact cooler plus hot GDDR6X memory make a higher power limit useful only when the card can actually dissipate the extra heat.

The public results suggest three broad tiers:

| Tier | Reported settings/results | Confidence |
| --- | --- | --- |
| Sensible daily starting point | 114% power, dynamic voltage, about `+100` to `+130` core, `+400` to `+600` memory | Review data; still card- and workload-dependent |
| Strong air-cooled sample | Around 2.0–2.085 GHz sustained, roughly `+1,000` to `+1,700` memory, high fan speed | Firsthand reports; not guaranteed and often not game-stable |
| Exceptional / benchmark-oriented | 2.1–2.16 GHz and above 21 Gbps memory, around 400 W, aggressive cooling | Review samples or heavily cooled cards; not a safe expectation for this FE |

## What the sources actually show

### Controlled reviews

- [The FPS Review's FE overclock test](https://www.thefpsreview.com/2021/06/24/overclocking-nvidia-geforce-rtx-3080-ti-founders-edition/) used a 114% power target, `+130` GPU clock, and `+500` memory. The reviewer deliberately kept memory below its apparent maximum because GDDR6X can error-correct and throttle performance instead of crashing. Their card reached about 399 W and required 100% fan for roughly 66°C GPU / 80.5°C hotspot.
- [TechSpot's FE review](https://www.techspot.com/review/2264-geforce-rtx-3080-ti/) measured about **4%** more performance from an FE sample at roughly 1885 MHz and 21 Gbps memory. This is a controlled review result, not a promise for every card.
- [TweakTown's FE review](https://www.tweaktown.com/reviews/9827/nvidia-geforce-rtx-3080-ti-founders-edition/index.html) reports a particularly good sample exceeding 2100 MHz, over 21 Gbps memory, and a stable 2160 MHz boost with 114% power. The same review measured approximately 92–94°C GDDR6X at stock under its test conditions, and about 70°C with the fans at 100% during its overclock test.
- [Overclockers Club's FE review](https://www.overclockersclub.com/reviews/nvidia_geforce_rtx3080ti_founders_edition/12.htm) found that simply raising the power limit did not improve its result because the FE cooler was already thermally saturated; it also warns that memory overclocks can reduce performance without an obvious crash.

### Firsthand owner reports

These are useful for ranges, but they are not controlled comparisons and may involve different ambient temperatures, BIOSes, games, or cooling modifications.

- In [this r/overclocking FE report](https://www.reddit.com/r/overclocking/comments/195t9x1/rtx_3080_ti_owners_what_kind_overclocks_did_you/), an owner reported `+150` core, 2085 MHz core, and `+1710` memory at 75°C with a 17°C ambient. The same thread says the 60-pass Time Spy Stress Test peaked around 2085 MHz / 11,211 MHz memory and 402 W.
- In [this report from an owner of the same FE model](https://www.reddit.com/r/overclocking/comments/sfd7x6/finally_complete_water_cooling/), `+1180` memory worked in Fire Strike Ultra but `+1000` caused artifacts or crashes in most games. The owner also reported that replacing thermal pads reduced VRAM temperature by more than 10°C and core temperature by more than 15°C, and that a lower power limit could produce a higher sustained clock in a real game.
- The same thread reports a game-oriented profile around 2000 MHz at 987 mV failing at maximum power but a lower-power profile reaching about 2130 MHz at 993 mV after cooling changes. Treat this as a cooling- and silicon-specific anecdote, not a target for our untouched card.

## Why our profile lost

Our live profile was:

- 399 W power cap (`350 W × 114%`)
- `+800` memory offset
- MSI-derived curve targeting 1935 MHz at 900 mV
- automatic fan control

The profile applied correctly: memory moved from about 9501 to 9901 MHz and LACT reported the requested curve, memory offset, and power cap. However, stock reached about 1965 MHz in the workload while the custom curve held around 1935 MHz. The extra power budget therefore did not buy a higher core clock, while the memory offset increased heat and power demand. That matches the review evidence that FE performance is often cooler-limited before it is slider-limited.

There is also a measurement distinction: `glmark2` is a repeatable synthetic comparison, but its four scenes do not necessarily reward the same balance of core clock and memory bandwidth as a game or 3DMark. The result proves that this profile did not improve this workload; it does not prove that every game would be exactly -1%.

## Local replication attempt

On 2026-09-06 I applied the review-style offset profile live through LACT, without changing the Nix-selected default:

- `gpu_clock_offsets`: `+130` on all five NVIDIA pstates
- `mem_clock_offsets`: `+400` on all five NVIDIA pstates
- `power_cap`: `399 W`
- automatic fan control
- no custom `nvidia_gpu_vf_curve`

The first two complete 3440x1440 off-screen `glmark2` passes scored **13,521** and **13,608**, versus the stock five-run median of **12,788**. That is an observed **+5.7%** and **+6.4%** respectively, but it is not yet a five-run acceptance result. During the third pass, several VRAM-chip sensors reached **100°C**; the run was aborted before thermal slowdown, and the temporary profile was removed. The raw files are under `$HOME/.local/state/lact-benchmarks/rtx-3080-ti/typical-community-3440x1440-20260906-oc`.

After the thermal-limited trial, the user explicitly selected this community-style profile as the active setup. It is now Nix-managed as `community-typical` and reapplied by the Home Manager user service with automatic fan control. The MSI-derived V/F profile remains in the source asset as a rollback reference, but is not emitted into the daemon YAML because Nix quotes its numeric curve keys and LACT rejects them. The applier replaces the GPU config instead of merging it, so stale `gpu_clock_offsets` fields cannot survive alongside a V/F curve.

## What I would test next

Do not raise the power cap or memory offset further. The useful next sweep is smaller and cooler:

1. Keep automatic fan control and test the core curve at 1905, 1935, and 1950 MHz at 900 mV, with memory offset `0`.
2. On the best core point, test memory offsets `+400`, `+600`, and `+800`. Keep a value only if the score improves and the memory-chip sensors stay well below the observed 96–100°C thermal behavior.
3. Compare five-run medians in the same 3440x1440 suite and retain at least one real game or 3DMark-style workload. A memory setting that does not crash can still be slower due to GDDR6X correction/throttling.
4. Treat a repeatable **2–4%** gain as a good FE result. The 4% controlled review result is a realistic upper reference; 5%+ community claims generally require unusually good silicon, high fan speed, thermal-pad work, water cooling, or benchmark-only settings.

The current automatic-fan profile should remain the safe default until that sweep is performed. Fixed 35% fan is not a sensible daily setting on this card: our run reached 98°C VRAM-chip readings and `SW_THERMAL_SLOWDOWN`.

## Hardware baseline

[NVIDIA's official RTX 3080 Ti page](https://www.nvidia.com/en-us/geforce/graphics-cards/30-series/rtx-3080-3080ti/) lists the Founders Edition at 350 W graphics-card power, a 93°C maximum GPU temperature, and a 750 W recommended system power. The 399–400 W results above are the card's 114% power-target behavior, not its stock rating.
