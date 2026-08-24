---
name: verify
description: >-
  Checks that a result means what it appears to mean. Use at BOTH ends of an experiment. At setup:
  before launching or pointing an eval, benchmark, training run, or robot run at a server, endpoint,
  checkpoint, dataset, or config — anything with a host, port, --ckpt, --config, or a mode flag like
  replay, sim, mock, dry-run, or stub. At report: before quoting any number, metric, correlation, or
  comparison, and before claiming a change helped, hurt, or did nothing. Also when deciding a sign
  or frame convention, comparing two runs, tuning against a metric, concluding from a sample, or
  declaring something missing, broken, or done. Also when explaining why a signal, controller,
  estimate, or metric behaves the way it does — why something saturates, drifts, oscillates, flips
  sign, or disagrees between two runs. Covers stub and replay setups mistaken for real results,
  reference frames, units, non-determinism, saturation, timing, and sample size.
---

# Verify

Everything here is cheap to check and expensive to assert.

Start with the Checklist. "Claims about state" applies to any claim at all. The sections between
them are for experiments in robotics, control, and ML.

## At setup, before the run starts

The expensive errors are made here, not at report time. After the run you hold a number and a belief about
it, and you will end up checking your wording rather than your setup.

Before launching anything, write down — in the run's own output, not just the chat:

| | |
|---|---|
| Endpoint | host, port, and what is actually serving it |
| Mode | real, sim, replay, stub, dry-run, mock |
| Artifact | checkpoint, config, commit |
| Data | episode, split, dataset |

Then confirm the mode by evidence, not by the flag you passed. Hit the endpoint and check the
response is a prediction rather than a copy of the input. A server that replays ground truth is
indistinguishable from a perfect policy until you look.

If you cannot say what is on the other end of the socket, you do not have a result yet.

## Checklist

1. State the setup before the number: real or sim, what produced the actions, which artifact, which data.
2. Is the thing under test actually in the loop, or am I measuring my own input?
3. Measured or reasoned? Say which.
4. With and without the change — did I run both, on the quantity I actually care about?
5. Is the system deterministic? If not, one run proves nothing.
6. What would this metric say if I did nothing?
7. Did anything saturate, drop, or get interpolated?
8. Does the sample cover the tail, or just the middle?

## Setup and provenance

State in the first sentence: real hardware or simulation, what generated the actions (trained
policy, stub, replayed log, human), which artifact (checkpoint, config, commit), which data
(episode, run, split).

- **Confirm the thing under test is in the loop.** Replay and stub modes return ground truth and
  look perfect. Suspiciously good agreement, such as a correlation near 1 or an error near 0,
  usually means you are measuring your own input rather than a result.
- **If a caveat invalidates the number, it is not a caveat.** Do not report the number.
- **Record provenance inside the artifact**, not in the chat: commit, config, seed, checkpoint id.
  A result you cannot trace is a result you cannot invalidate later.

## Claiming a change helped

Run the pipeline with and without the change and compare the quantity you actually care about.

- Not a proxy for it. Row alignment improving does not mean depth improved, if the transform also
  rescaled the thing depth is computed from.
- Not by reading the code. How bad something is, and how far its effects reach, are measured rather
  than inferred. "This only affects the display" and "this mismatch is critical" both need a run.

## Frames, units, conventions

- **Units first.** Print the unit and numeric range of every quantity before using it: rad or deg,
  m or mm, and any scale factor. A value off by ~57x or ~1000x is a unit, not physics.
- **Carry the frame in the name**, as in `v_body` or `p_world`. An expression mixing two suffixes
  is a bug.
- **Write transforms as `T_target_source`** and state which way they map. An inverted transform
  produces plausible, wrong output.
- **State rotation conventions** before composing: quaternion order (wxyz or xyzw), Euler sequence,
  active or passive. Wrong conventions look fine near identity and break at large angles.
- **A sign convention is fixed by physical geometry:** which side the sensor sits on, which way the
  axis points. Not by whichever value makes a simulation converge. If the simulation is built on
  your assumption about the sign, it cannot confirm that sign. Find a large deliberate movement in
  recorded data and read the sign off that.
- **Decide whether a quantity is body- or world-defined** before reasoning about how it behaves when
  the direction of motion reverses. Do not transfer a property of one frame to a question in the other.
- A signal too small or too coarse to move cannot confirm a convention. Say it is unvalidated.

## Timing

- Align streams on their own timestamps, never on array index. Report the measured offset and jitter
  between streams before correlating across them.
- State the control rate and each sensor rate. A controller running faster than its measurement acts
  on stale data, so the effective gain is not the configured gain.
- Measure end-to-end sensing-to-actuation latency and report it. A policy served over a network adds
  delay that changes closed-loop behavior even when its outputs are identical.

## Comparing runs

- Establish whether the system is deterministic **before** attributing any difference to your change.
  Sampling policies, dropout, async timing and unseeded RNG all differ per call. Test it: same input
  twice, diff the outputs.
- If non-deterministic, repeat each condition and compare the spread of results, not one run
  against one run.
- Report episode count, seed count, and per-episode spread or a confidence interval. A comparison
  over a handful of episodes with one seed cannot separate a change from noise.
- Split train and eval by episode, session, or location, never by frame. Adjacent frames are near
  duplicates, so a frame-level split makes any policy look better than it is.

## Metrics

- Ask what the metric reads under two null baselines: output zero, and replay the input. Quote your
  number against those. If "do nothing" wins, it is not an objective. Stop and say so.
- Check the signal has the range and variance to carry the claim. A correlation over a near-constant
  or few-valued signal carries no information, whatever the number says.

## Data integrity

- Count clamped, saturated, and rate-limited steps and report them. A run with saturated output is
  measuring the limiter, not the controller.
- Count dropped, duplicated and interpolated samples. Interpolation hides a gap while destroying the
  transients you are trying to measure.
- A median over a small or hand-picked sample says nothing about the tail. Before recommending that
  something be removed or skipped, check the full distribution and the maximum. Failures live in the
  tail. A component that changes nothing on average and everything in one contiguous stretch is
  doing its job.

## Claims about state

- Check the path before declaring a file, checkpoint, or dataset missing, and before declaring one
  deleted.
- Verify existence before declaring work done. A restructuring is not complete while the directory
  it introduces does not exist.
- Confirm a process is alive by PID, or by reading the matched command line. A name-based process
  search matches your own query.
- Findings from reviews or other agents are leads. Reproduce each before acting; expect them to
  contradict each other and to be confidently wrong.
