# UCS531 Project Submission

The QoS-Aware Hybrid Cloud Task Scheduler accepts a one-column vibration CSV, forecasts finish time on two local workers and on one EC2 worker, and records why it placed the job. The default policy stays on a local worker when that forecast meets the deadline, and starts the stopped EC2 worker when the cloud forecast is the one that still lands on time inside the job budget and the run budget. The control plane is hosted in `us-east-1` and stays available when the laptop workers disconnect.

## Open the running system

- [Hosted dashboard](https://4k3efjo42g.execute-api.us-east-1.amazonaws.com/)
- [Health check](https://4k3efjo42g.execute-api.us-east-1.amazonaws.com/api/health). A healthy API returns `{ "status": "ok" }` after it reads the jobs table.
- Sign in with the steps in [aws/HOSTED.md](../../aws/HOSTED.md#sign-in). `Operator` includes Operations, runs, and metrics. `Student` submits, tracks, and downloads that account's jobs.
- [sample-vibration.csv](sample-vibration.csv) is an 8-sample square wave. Submitted at 1,000 Hz with lags 2 through 4, the published result is 250 Hz and best lag 4. The [demo runbook](demo.md) uses that file for a local result, an EC2 deadline rescue while both laptop slots are busy, and a run after the laptop workers stop.

## Deliverables

| Deliverable | Where to find it |
|---|---|
| Project proposal | [proposal.md](proposal.md): the queue problem, the `vibration-v1` workload, five objectives, and the success checks |
| System architecture | [architecture.md](architecture.md): the private AWS path, the web and scheduler split, job states, placement, and the trust boundary |
| Working implementation | [Local setup](../../README.md#getting-started) in the project README, and the [hosted dashboard](https://4k3efjo42g.execute-api.us-east-1.amazonaws.com/) for the running control plane |
| Cloud deployment and demonstration | [aws/HOSTED.md](../../aws/HOSTED.md) for the hosted stacks, and [demo.md](demo.md) for the three classroom scenarios |
| Source code and README | [TANICE-GAWD/qos-aware-scheduler](https://github.com/TANICE-GAWD/qos-aware-scheduler), with the file map in [Repository structure](../../README.md#repository-structure) |
| Project report | Four-page PDF in the submission package, beside this repository |
| Final presentation and live demonstration | Editable presentation in the handoff, presented with [demo.md](demo.md) |

## Measured results

[docs/evaluation.md](../evaluation.md) replays the same arrivals under FCFS, priority, and QoS. On the live hybrid burst, QoS and priority each met 15 of 21 deadlines. QoS published six EC2 results and priority published eleven. The [hosted acceptance record](../../aws/HOSTED.md#live-acceptance-on-november-25-2026) keeps the browser download, the deadline rescue, the laptop-offline run, and the restart check, with links to the completed jobs.
