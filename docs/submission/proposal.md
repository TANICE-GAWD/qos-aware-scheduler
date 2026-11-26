# Project Proposal

## QoS Aware Hybrid Cloud Task Scheduler

Batch-processing teams have to clear queues on limited local capacity while meeting deadlines and controlling cloud spend. A burst of arrivals can make urgent work wait behind long jobs. Keeping extra cloud capacity running adds cost even during quiet periods. This project proposes a scheduler that estimates whether an independent job can finish locally and starts cloud capacity when that spend can still save the deadline.

The demonstration uses one predefined workload, `vibration-v1`. A user submits a one-column CSV of signed vibration samples, a sample rate, a lag range, a priority, an expected local runtime, a deadline, and a cloud budget. The bytes must match a declared SHA-256 before the job enters the queue. A worker scores candidate lags and publishes the dominant frequency, best lag, and lag scores as JSON. The API publishes that result only after it recomputes the checksum.

Each placement is stored with the job: the chosen target, both predicted finish times, the reason, and the budget comparison. Money is an integer count of microdollars. One USD is 1,000,000 microdollars, so a reservation cannot drift through floating-point rounding.

## Objectives

1. Deliver a web dashboard and REST API for submission, job status, the placement explanation, and result retrieval. Repeating the same idempotency key and the same request returns the existing job.
2. Implement first come first served, priority, and QoS-aware scheduling over the same queue and the same worker pool. QoS stays on a local slot when that forecast meets the deadline, and opens EC2 when the cloud forecast is the one that still lands on time inside the job budget and the run budget.
3. Run jobs on two optional Docker worker slots and one dedicated burst EC2 worker. The EC2 instance stays stopped until a placement needs it. The AWS control plane keeps the queue and the dashboard available when the laptop slots disconnect.
4. Use RDS PostgreSQL for job state, private S3 for artifacts, and CloudWatch for queue, worker-loss, startup, and cost evidence.
5. Replay matched normal and burst workloads under all three policies. Measure queue wait, deadline compliance, completion time, makespan, cloud usage, and estimated EC2 compute cost.

## Scope and success criteria

The semester prototype schedules independent, non-preemptive CSV jobs of one type. It uses one EC2 burst slot and two optional local slots. A lost or timed-out attempt may run once more. A missed deadline is stored as an outcome, and a successful result stays downloadable. The dashboard reads status by polling the REST API.

Success requires:

- A verified local result for the sample recording: 250 Hz and best lag 4.
- A deadline rescued on EC2 within budget while both local slots are busy.
- A clear waiting reason for a zero-budget job while local capacity is offline.
- Job records and result checksums that survive a control-plane restart.
- A policy comparison that reports the observed trade-off in deadline hits and estimated EC2 compute.

The deployed shape of this proposal is [architecture.md](architecture.md). The local build and the running dashboard are in the [project README](../../README.md).
