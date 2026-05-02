# PERSON 2 — Your Instructions
> The code is already written and deployed. Your job is to clone the repo, test your Lambdas in AWS Console, and be ready for the demo.

---

## Step 1: Install the Tools

### Install Git
Download from https://git-scm.com and install it.

### Install Node.js
Download from https://nodejs.org — get the LTS version.

Verify both work:
```bash
git --version
node --version
```

### Install AWS CLI
- Windows: download installer from https://aws.amazon.com/cli/
- Mac: `brew install awscli`

---

## Step 2: Configure AWS

Person 1 shared AWS keys with you. Run:
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

Verify it works:
```bash
aws sts get-caller-identity
# Should print an Account number — you are connected
```

---

## Step 3: Clone the Repo

```bash
git clone https://github.com/0zyad/reaction-speed-game.git
cd reaction-speed-game
```

---

## Step 4: Install Lambda Dependencies

```bash
cd lambdas/player-service
npm install

cd ../result-service
npm install
```

---

## Step 5: Test Your Lambdas in AWS Console

Go to https://console.aws.amazon.com → search **Lambda** in the top bar.

---

### TEST 1 — joinGame (player-service)

1. Click **player-service**
2. Click the **Test** tab at the top
3. Click **Create new test event**
4. Name it `joinGameTest`
5. Paste this JSON:
```json
{
  "requestContext": { "routeKey": "joinGame", "connectionId": "test-conn-001" },
  "body": "{\"action\":\"joinGame\",\"gameId\":\"TEST\",\"playerName\":\"Ali\"}"
}
```
6. Click **Test**
7. Result should show `"statusCode": 200`

**Verify in DynamoDB:**
- Go to AWS Console → **DynamoDB** → **Tables** → **Players** → **Explore items**
- You should see a row: gameId=TEST, playerName=Ali

---

### TEST 2 — submitReaction (player-service)

First, manually create a game record in DynamoDB so the Lambda can find it:
1. Go to **DynamoDB → Tables → Games → Explore items**
2. Click **Create item** (top right)
3. Switch to JSON view and paste:
```json
{
  "gameId": {"S": "TEST"},
  "signalAt": {"N": "1714600000000"},
  "status": {"S": "SIGNAL_SENT"}
}
```
4. Click **Save changes**

Now go back to **Lambda → player-service → Test tab**:
1. Create new test event named `submitReactionTest`
2. Paste this JSON:
```json
{
  "requestContext": { "routeKey": "submitReaction", "connectionId": "test-conn-001" },
  "body": "{\"action\":\"submitReaction\",\"gameId\":\"TEST\",\"clickedAt\":1714600000243}"
}
```
3. Click **Test** — should return `"statusCode": 200`

**Verify in DynamoDB:**
- Go to **DynamoDB → Players** → the Ali row should now have `reactionMs: 243`

---

### TEST 3 — getResults (result-service)

1. Click **result-service** Lambda → **Test** tab
2. Create new test event named `getResultsTest`
3. Paste this JSON:
```json
{
  "queryStringParameters": { "gameId": "TEST" }
}
```
4. Click **Test**
5. Result should return a rankings array with Ali ranked 1st at 243ms

---

## Step 6: Check CloudWatch Logs

1. AWS Console → search **CloudWatch**
2. Click **Log groups** on the left
3. Click **/aws/lambda/player-service**
4. Click the latest log stream
5. You will see logs from every test you just ran — **screenshot this for the demo**

---

## Step 7: Check GitHub Actions

The CI/CD pipeline runs automatically every time someone pushes code. It installs Lambda dependencies and validates the Terraform infrastructure config.

1. Go to https://github.com/0zyad/reaction-speed-game
2. Click the **Actions** tab
3. You will see green checkmark runs — **screenshot the most recent green one**

What to say about it in the demo:
> "We have a CI/CD pipeline using GitHub Actions. Every push to the repo automatically installs dependencies and validates the infrastructure code. This is the Build/Release/Run factor — build, release, and run are completely separate stages."

---

## Screenshots You Must Take

| Screenshot | Where |
|---|---|
| Lambda test result showing statusCode 200 | Lambda → player-service → Test tab |
| DynamoDB Players table with test data | DynamoDB → Players → Explore items |
| DynamoDB Players row showing reactionMs: 243 | Same table after submitReaction test |
| CloudWatch logs from player-service | CloudWatch → Log groups → /aws/lambda/player-service |
| GitHub Actions green run | https://github.com/0zyad/reaction-speed-game/actions |

---

## Important Info

| Item | Value |
|------|-------|
| WebSocket URL | `wss://a3kfvwmm01.execute-api.us-east-1.amazonaws.com/prod` |
| GitHub Repo | https://github.com/0zyad/reaction-speed-game |
| AWS Region | us-east-1 (N. Virginia) |

---

## Demo Checklist — Check These Before the Demo

- [ ] `aws sts get-caller-identity` prints your account number
- [ ] Lambda test for **joinGame** returns statusCode 200
- [ ] DynamoDB Players table shows the test row
- [ ] Lambda test for **submitReaction** saves reactionMs 243 to DynamoDB
- [ ] Lambda test for **result-service** returns sorted rankings
- [ ] CloudWatch logs show real log entries from your tests
- [ ] You can explain in 30 seconds: "player-service handles joining and clicking, result-service computes the leaderboard"

---

## What to Say in the Demo (30 seconds)

> "I wrote the player-service Lambda which handles everything players do — joining a game, submitting their reaction click, and computing who finished first. I also wrote the result-service which sorts players by reaction time and returns the leaderboard. All state is stored in DynamoDB — the Lambda itself is stateless and disposable."
