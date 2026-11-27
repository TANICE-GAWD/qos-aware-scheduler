# What this project is, in plain language

This is a scheduler for a class called UCS531. You give it a tiny vibration recording. It decides where that work should run, does the work, and gives you a result file.

There are two cheap workers on your laptop. There is one paid computer in Amazon's cloud, called EC2. The paid computer stays switched off. The scheduler turns it on only when the laptop would miss the deadline and the job has enough money to pay for it. When the job is done and the cloud computer has been idle, the scheduler turns it off again.

The website that you show your professor is already running in Amazon. Your laptop is only extra muscle. If you close the laptop workers, the website stays up.

## The problem it is trying to solve

Imagine a queue of homework. You have two desks in your room. They are free. You also have a rented desk across town. The rented desk costs money for every minute it is open, and it takes a minute or two to unlock.

A bad plan keeps the rented desk open all day, even when your room is empty. Another bad plan never rents the desk, so urgent work misses its deadline while your two desks are already busy.

This project is the person standing at the door. For each new piece of work they look at three things:

1. Can a free desk in the room finish it before the deadline?
2. If not, can the rented desk finish it before the deadline?
3. Does this piece of work have enough money to pay for unlocking the rented desk and using it?

If the room can do it, the rented desk stays locked. If only the rented desk can save the deadline, and the money is there, they unlock it. If there is no money, the work waits in the room. It is not allowed to spend money it does not have.

## The one job this demo understands

The only kind of work is a vibration recording. The file is a CSV. That is a text file with one number on each line. The numbers are samples of a shaking signal.

The sample file is a tiny square wave: 2, 0, -2, 0, 2, 0, -2, 0. If you tell the system the samples were taken 1000 times a second, and you ask it to look at lags 2, 3, and 4, the repeating pattern is 4 samples long. Frequency is sample rate divided by that lag. 1000 divided by 4 is 250. So the result is **250 Hz**, and the best lag is **4**.

You will see that same answer on every successful demo. The interesting part is not the number 250. The interesting part is which computer produced it, and why.

## The pieces, and where they live

Think of four places.

**The website.** You open it in a browser. It has a sign-in box, a Jobs page, a form to submit a recording, and an Operations page. Operations is the control room: who is free, who is busy, and whether the cloud computer is off.

**The brain, in Amazon, always on.** Two programs run on a private computer that has no public address. One program is the website and the API. An API is the set of doors programs knock on, like "here is a new job" or "I finished." The other program is the scheduler. About once a second it looks at the queue and decides what to do. They do not share a brain inside one process. If one of them crashes, the other can restart. The list of jobs is not stored inside either program.

**The notebook, which is the database.** The database is PostgreSQL, also in Amazon, also private. It remembers every job, every attempt, every decision, and whether the cloud computer was asked to start. The website and the scheduler both read and write this notebook. The workers never open it. Workers only talk to the website.

**The filing cabinet, which is S3.** S3 is Amazon's file storage. The recording goes in. The result JSON comes out. A worker does not get the keys to the whole cabinet. It gets a short-lived link for one input file and one output file. The website checks the result by reading the file back and computing its fingerprint again. That fingerprint is a SHA-256 checksum. If the fingerprint matches, the job is published and you can download it.

**The two laptop workers.** Their names are `local-1` and `local-2`. Each one can do one job at a time. They are Docker containers. A container is a boxed-up program with its own little filesystem, so it runs the same way on your machine as it did in the lab. They ask the website "do you have work for me?" over and over.

**The cloud worker.** Its name is `ec2-1`. It is the same kind of boxed-up program, but it runs on the rented Amazon computer. That computer is off until the scheduler starts it. When it boots, it has to prove it is the real computer the project expects. It shows a signed identity document from Amazon. The website checks the signature, the account, the region, the computer's id, and the exact program version. A random container on the internet cannot pretend to be `ec2-1`.

## Words you will hear

**Job.** One recording, plus the rules for it: sample rate, lag range, priority, how long you expect the laptop to take, the deadline, and the cloud budget.

**Queue.** The line of jobs that have been accepted and are waiting for a worker. The database is the queue. There is no separate queue product.

**Deadline.** The clock time by which the result should exist. A missed deadline is recorded. The result can still be downloadable. Missing a deadline is an outcome, not a crash.

**Budget.** How many dollars this job is allowed to spend on the cloud computer. `0` means "do not use EC2." `0.03` means "you may spend up to 3 cents."

**Worker and slot.** A worker is a running program. A slot is its one chair. `local-1` has one chair. While it is working, the other waiting jobs cannot sit there.

**Placement.** The decision written on the job: laptop or EC2, the predicted finish time for both, and a short reason. You read this on the job page. "Local can finish before the deadline" means the laptop was good enough. "EC2 can meet the deadline that local would miss" means the cloud was chosen to save the deadline. "EC2 exceeds the remaining job budget" means the cloud was blocked because the job is too poor.

**Policy.** The rule used to order the queue and pick a chair. This project has three, and they share the same workers. The live site is using QoS.

**Token.** A long password. The operator token lets you see Operations and everyone's control-room view. A student token would only see that student's jobs. Worker tokens are different passwords, one for each laptop worker. You do not type the worker tokens. The env file holds them.

**Seed.** One secret stored in Amazon Secrets Manager. The operator token, the student token, and the two laptop-worker tokens are all calculated from that seed. The calculation is HMAC-SHA256. You can think of it as a stamp: same stamp and same label always produce the same password, and you cannot go backwards from the password to the stamp. The cloud worker does not use this stamp. It has its own separate secret.

**Image and digest.** The worker program is packed as a Docker image and stored in a private Amazon registry called ECR. A digest is the fingerprint of that exact build, a long `sha256:...` string. The website only trusts a cloud worker that is running that exact fingerprint.

**Lease.** When a worker takes a job, it has to keep saying "I am still here" every few seconds. If it goes silent for about 20 seconds, the job is no longer theirs. That stops a dead worker from holding a job forever.

**Checksum.** The fingerprint of a file. The browser says "the file I am uploading has this fingerprint." The website hashes the bytes again. The worker later says "the result I uploaded has this fingerprint." The website hashes the stored result again. If either check fails, the job is not trusted.

## What happens when you click Queue job

1. The browser sends the job details and a fingerprint of the CSV.
2. The website writes a row: "I am waiting for the file."
3. The browser uploads the CSV. The website checks the fingerprint, the size, and that the numbers look like the vibration format.
4. The job enters the queue.
5. Within about a second, the scheduler looks at free chairs and writes a decision.
6. A worker asks for work, receives this job, downloads the CSV through a short-lived link, and runs the math in a child program. The child is separate so a bad file does not kill the worker.
7. The worker uploads the JSON result and tells the website the fingerprint.
8. The website reads the file back, hashes it, and marks the job succeeded.
9. You click Download result and see 250 Hz.

If no legal chair exists, the job stays queued and the page tells you why. That is what you saw when the budget was $0 and the laptop workers were off. EC2 was the only computer that could help, and the job was not allowed to pay for it.

## The three policies

All three policies use the same two laptop chairs and the same one cloud chair. The difference is the order of the line, and when they are willing to spend money.

**FCFS** means first come, first served. The oldest job goes first. If the cloud chair will be free sooner than a busy laptop chair, FCFS may use the cloud even when the laptop would also have made the deadline.

**Priority** means high jobs jump ahead of normal jobs, and normal jobs jump ahead of low jobs. Inside one priority level, the oldest goes first. It can also use the cloud just because the cloud chair frees up sooner.

**QoS** is the careful one, and it is the one the live site uses. It still lets a job that has been waiting a long time move forward, so a quiet job is not stuck forever. For the chair, the rule is stricter. If the laptop forecast says "I can finish before the deadline," QoS stays on the laptop. It opens EC2 only when the laptop would be late, the cloud forecast would still be on time, and both the job's own budget and the run's budget can cover the bill. A forecast includes work already sitting on that chair, plus the time to unlock EC2 if it is currently off.

That is why the measured test can say QoS and priority finished the same number of deadlines, while QoS used the cloud fewer times. Priority spends sooner. QoS spends only to rescue a deadline.

## How the money is stored

Dollars and cents are awkward in a computer because decimal fractions wobble. This project stores money as whole numbers of microdollars. One dollar is 1,000,000 microdollars. Three cents is 30,000 microdollars. A reservation is rounded up to the next microdollar, so the scheduler never accidentally spends a fraction it did not record.

The cloud computer is billed by Amazon for the time it is on, including the time it spends booting. The scheduler estimates that cost before it says yes. The number you see on Operations, a fraction of a cent, is the estimated compute for cloud time this project has already used. It is not your whole AWS bill. Storage, the always-on website computer, and the database cost money even while EC2 is stopped.

## How the cloud was built before you touched this laptop

Someone already built the Amazon side. You do not rebuild it for the presentation. The instruction manual for that build is `aws/HOSTED.md`. In simple terms they made five piles of resources, all in Amazon's Virginia region, `us-east-1`.

**The data pile** is a private network, a private PostgreSQL database, and three secrets: the database's master password, the 64-character seed, and the cloud worker's own token. The database accepts connections only from the website computer.

**The app pile** is the private computer that runs the website and the scheduler. It has no public internet address. It pulls an exact version of the program from the private registry.

**The gateway pile** is the public front door. The browser talks to an Amazon API Gateway address. That door forwards the request through a private tunnel to the website computer. That is why the website can be private and you can still open it.

**The worker pile** is the permission and the recipe that teach `ec2-1` the public website address and how to read its own token when it boots.

**The older shared pile** is the cloud computer itself, the file bucket, and the image registry. Those existed before the hosted website. The hosted stacks reuse them.

There is also a log book in CloudWatch. The scheduler writes health numbers there: how long the queue is, whether a worker disappeared, whether EC2 took too long to boot.

The first time the website computer boots, a prepare step checks that the database certificate is really Amazon's, creates the application database user, and applies the table definitions. After that, the website and the scheduler start, and Amazon restarts them if they die.

## What we did on this computer

The website was already up. This laptop had none of the local pieces.

**The AWS profile.** The name `ucs531-qos` is just a label for a key stored in `~/.aws/credentials`. The website login does not create that label. You created an access key on the root account and saved it under that label with `aws configure --profile ucs531-qos`. After that, commands can say "use the ucs531-qos key" by setting `AWS_PROFILE=ucs531-qos`.

**`npm ci`.** This downloads the JavaScript libraries the scripts need, including the small runner called `tsx`. Without it, `node --import tsx` cannot start the project scripts.

**`prepare-demo.sh`.** This is the setup that failed when it was pasted as many broken lines. The script does five quiet jobs:

1. It asks CloudFormation for the seed's address, the dashboard address, the image name, and the image fingerprint.
2. It reads the seed from Secrets Manager.
3. It logs Docker into the private registry so this laptop is allowed to download the worker image.
4. It writes `.env.aws-workers`. That file holds the website address, the exact image fingerprint, and the two laptop-worker tokens. Git ignores it.
5. It copies the operator token to the clipboard.

**The GPG box.** Docker on this machine wanted to save the registry password inside a locked keyring. You do not know that key's passphrase. The workaround was a separate Docker config folder, `/tmp/qos-docker`, that stores the registry login in a normal file for this demo only. Commands that start with `DOCKER_CONFIG=/tmp/qos-docker` use that folder and do not open the GPG box. If the box appears anyway, Cancel is the right button.

**Starting the workers.** `docker compose ... up -d` reads `.env.aws-workers` and starts `local-1` and `local-2` in the background. `-d` means "do not hold the terminal open." The warning "No services to build" only means the image was already built and stored in Amazon. Compose did not need to compile anything. `stop` pauses those containers. `up -d` starts the same containers again, which is why the Created time stays old and the Up time becomes a few seconds.

## The commands in the presentation notes

### `aws configure --profile ucs531-qos`

Saves the access key under the name the scripts expect. You only do this once per computer.

### `aws sts get-caller-identity --profile ucs531-qos`

Asks Amazon "who is this key?" If it prints an account number, the key works. It does not print the secret key.

### `cd ~/Desktop/qos-aware-scheduler`

Moves the terminal into the project folder. Later commands look for files here. `~` means your home folder.

### `npm ci`

Installs the exact library versions from the lockfile into `node_modules`.

### `bash prepare-demo.sh`

Runs the setup script described above. Run the file. Do not copy its insides into the terminal. A pasted line that wraps becomes two commands, and the second half is nonsense. That was the `command not found` storm.

### The health URL

The website asks the database "can I read the jobs table?" If the answer is yes, you see `{"status":"ok"}`. If you do not see that, the demo cannot work, and the problem is the cloud site, not your laptop.

### Sign in

The token is a password calculated from the seed. The box on the site is labeled **Project access token**. After a correct operator token, the corner says **Operator**. Do this before you share the screen, because the token is a secret.

### `DOCKER_CONFIG=/tmp/qos-docker docker compose --env-file .env.aws-workers -f compose.workers.yaml up -d`

`DOCKER_CONFIG=...` applies only to this one command. It points Docker at the login that skips GPG.

`docker compose` reads `compose.workers.yaml`. That file describes two services, `local-1` and `local-2`. It does not start the website or the database. Those are already in Amazon.

`--env-file .env.aws-workers` fills in the website address, the image fingerprint, and the worker passwords.

`up` creates or starts the containers. `-d` returns you to the prompt.

### Operations

This page is the truth for the demo. Before example 1 you want:

- Queued 0, so an old job is not sitting in a chair.
- Both local workers Available. The clock next to them should be a few seconds ago. That means they just phoned home.
- EC2 capacity Stopped. `ec2-1` will say Offline. That is correct. Offline here means "the cloud computer is switched off," not "the project is broken."

### Example 1, on the website

Budget `0` and a deadline a couple of minutes away. A free laptop worker takes it. The reason says the laptop can finish on time. The result is 250 Hz and lag 4. You say the cloud stayed off because the job had no money and the laptop was free.

### `bash run-connected.sh`

This is example 2, the busy-laptop case. It is one file so the clipboard cannot be used as the password. The earlier failure happened because `wl-paste` read the commands you had copied, and the script tried to send that paragraph as the token.

The script:

1. Sets the laptop workers to 3.5 percent of one CPU. They become slow on purpose, so two big jobs stay in the chairs long enough for a third job to arrive.
2. Recreates the two containers with that limit. `--force-recreate` throws away the running boxes and starts fresh ones with the new setting. The image does not have to download again.
3. Reads the seed and calculates the operator token inside the script. The token is not printed.
4. Runs `scripts/verify-hosted.ts connected`.

That check waits until both laptop workers are healthy and EC2 is stopped. It submits one small free job and expects a laptop to finish it. Then it starts a named run called **Hosted burst acceptance**. It submits two large free recordings, waits until `local-1` and `local-2` are both busy, and then submits one small high-priority job with an 85-second deadline and a budget of 3 cents. It expects the reason "EC2 can meet the deadline that local would miss," expects the result before the deadline, and waits until EC2 has been switched off again. Then it prints `Hosted connected verification passed.` and a link to the cloud job.

Open that link. Show both predicted finish times, the EC2 assignment, and the checksum. In Operations, the run name is **Hosted burst acceptance**. Wait until EC2 says Stopped before you move on. This whole script can take several minutes because the cloud computer has to boot.

### Example 3

`docker compose ... stop` tells the two laptop containers to exit. The website does not stop.

`unset LOCAL_WORKER_CPUS` removes the "be slow" setting from the terminal, so a later start is full speed again. It does not matter for example 3, because the workers are off.

The first new job has budget `0.03` and a deadline at least 3 minutes away. No laptop is free, the job can pay, so EC2 boots and the result comes back as 250 Hz.

The second new job has budget `0`. EC2 is blocked. The page should say the cloud exceeds the job budget, and the worker stays unassigned. The job waits. You say the website lives in Amazon, so turning off the laptop does not turn off the site. Money decides whether the cloud computer is allowed to wake up.

### The last sentence

On a recorded busy test, with the same arrivals for every policy, QoS and priority each made 15 of 21 deadlines. Priority used the cloud for 11 results. QoS used it for 6. QoS was slower on average and spent less, because it refused to turn the cloud on when the laptop could still win.

## What "good" looks like before you start talking

Operations shows an empty queue, both local workers Available with a fresh timestamp, and EC2 Stopped. Health says ok. You are signed in as Operator. Then example 1 is just a form.

## Files that matter on this laptop

| File | What it is |
|---|---|
| `how-to-present.txt` | The short checklist. Git ignores it. |
| `prepare-demo.sh` | One-time setup. Git ignores it. |
| `run-connected.sh` | Example 2. Git ignores it. |
| `.env.aws-workers` | Website address, image fingerprint, and the two worker tokens. Git ignores it. |
| `/tmp/qos-docker` | Docker's Amazon login for this demo, without the GPG key. It disappears on reboot. |
| `docs/submission/demo.md` | The same three examples, written as a lab handout. |
| `aws/HOSTED.md` | How the Amazon side was built. You do not run that in the room. |
