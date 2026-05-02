# PERSON 3 — Your Instructions
> The code is already written and deployed. Your job is to open the frontend, test the game in 3 browser tabs, and prepare the demo script.

---

## Step 1: Install the Tools

### Install Git
Download from https://git-scm.com and install it.

### Install Node.js
Download from https://nodejs.org — get the LTS version.

Verify:
```bash
git --version
node --version
```

---

## Step 2: Clone the Repo

```bash
git clone https://github.com/0zyad/reaction-speed-game.git
cd reaction-speed-game
```

---

## Step 3: Configure AWS (needed for CloudWatch logs in demo)

Person 1 shared AWS keys with you. 

Download AWS CLI from https://aws.amazon.com/cli/ then run:
```bash
aws configure
```
Answer like this:
```
AWS Access Key ID: [paste key from Person 1]
AWS Secret Access Key: [paste secret from Person 1]
Default region name: us-east-1
Default output format: json
```

Verify:
```bash
aws sts get-caller-identity
# Should print an Account number
```

---

## Step 4: Open the Frontend

The WebSocket URL is already patched into the frontend automatically.

Just open this file in your browser:
```
reaction-speed-game/frontend/index.html
```

Double-click the file, or drag it into Chrome/Firefox.

You should see the game home screen. The status bar at the top should say **Connected ✅** within a few seconds.

If it says **Connection error** — check that the URL in `frontend/index.html` line 125 is:
```
wss://a3kfvwmm01.execute-api.us-east-1.amazonaws.com/prod
```

---

## Step 5: Test the Full Game (do this alone with 3 tabs)

1. Open `frontend/index.html` in **3 separate browser tabs**
2. All 3 tabs should show **Connected ✅**

**Tab 1 (you are the host):**
- Enter name: `Ali`
- Click **Create New Game**
- You will see a 4-letter game code (e.g. `ABCD`) — copy it

**Tab 2:**
- Enter name: `Sara`
- Paste the game code in the join field
- Click **Join Game**
- Tab 1 and Tab 2 should both show Sara joined

**Tab 3:**
- Enter name: `Omar`
- Paste the same game code
- Click **Join Game**
- All 3 tabs should show 3 players in the lobby

**Tab 1 (host):**
- Click **Start Game**
- All 3 tabs go dark with "Wait for green signal..."
- After 2-6 seconds, all 3 tabs flash GREEN — click as fast as you can on each tab
- After all 3 click, results appear showing rankings with millisecond times

If this works — the full system is working end to end.

---

## Step 6: Check CloudWatch Logs (for demo)

1. Go to https://console.aws.amazon.com
2. Search **CloudWatch** in the top bar
3. Click **Log groups** on the left
4. Click **/aws/lambda/player-service**
5. Click the latest log stream
6. You will see real log lines from the game you just played — **screenshot this**

---

## Step 7: Check GitHub Actions (for demo)

1. Go to https://github.com/0zyad/reaction-speed-game
2. Click the **Actions** tab
3. You should see green checkmark runs — **screenshot this**

---

## Important Info

| Item | Value |
|------|-------|
| WebSocket URL | `wss://a3kfvwmm01.execute-api.us-east-1.amazonaws.com/prod` |
| GitHub Repo | https://github.com/0zyad/reaction-speed-game |
| AWS Region | us-east-1 (N. Virginia) |

---

## Demo Checklist — Check These Before the Demo

- [ ] Frontend opens without errors in browser (F12 console shows no red errors)
- [ ] Status bar shows **Connected ✅**
- [ ] 3 tabs can join the same game and see each other in the lobby
- [ ] Start game triggers green flash on all 3 tabs at the same time
- [ ] Results show correct rankings with millisecond times
- [ ] CloudWatch logs show real log entries from your game
- [ ] GitHub Actions tab shows green pipeline run
- [ ] Demo script practiced once end to end

---

## Demo Script (7 minutes total)

### Act 1 — Infrastructure (2 minutes)
Show the AWS Console while saying:

> "All of this infrastructure was created automatically by Terraform — we wrote one configuration file and it created the DynamoDB tables, Lambda functions, API Gateway WebSocket, and IAM roles with zero manual clicking."

Show:
- Lambda → 3 functions
- DynamoDB → 3 tables (Games, Players, Results)
- API Gateway → reaction-game-ws

### Act 2 — Live Game (3 minutes)
- Open 3 browser tabs side by side (full screen record your screen)
- Tab 1: create game, get code
- Tab 2 + 3: join with that code
- All see the lobby together
- Start the game — all tabs go dark
- Screen flashes green — click fast on all 3
- Show the leaderboard with real millisecond times

### Act 3 — Cloud Proof (2 minutes)
Go to CloudWatch logs and show the real log lines while saying:

> "These are the real logs from AWS CloudWatch — every player join, every click, every result computation — all logged automatically. This proves the system ran on AWS, not locally."

Then show DynamoDB → Players table with the real game data.

---

## 15-Factor Points to Mention in Demo

| Factor | What to Say |
|--------|-------------|
| **Stateless Processes** | "Lambda functions have zero memory between calls — all state lives in DynamoDB" |
| **Config via Environment** | "No hardcoded values — table names and endpoints are all environment variables set in Terraform" |
| **Disposability** | "Lambda starts in milliseconds, can be killed any time. DynamoDB TTL auto-deletes old sessions" |
| **Logs as Streams** | "Every Lambda writes structured logs to CloudWatch in real time — shown here" |
| **Build/Release/Run** | "GitHub Actions separates build, release, and deploy into distinct pipeline stages" |
| **Scalability** | "1000 players joining at once — API Gateway and Lambda scale automatically, no capacity planning" |
