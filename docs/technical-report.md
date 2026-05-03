# Reaction Speed Game - Technical Report
**Course:** SWE 455: Cloud Applications Engineering - Term 252
**Group Members:** Ziyad Abdul Atif, Ali Alumran, Abdullah Alumran
**GitHub:** https://github.com/0zyad/reaction-speed-game
**Frontend:** http://reaction-speed-game-frontend.s3-website-us-east-1.amazonaws.com
**WebSocket:** wss://a3kfvwmm01.execute-api.us-east-1.amazonaws.com/prod

---

## 1. What is the Application?

We built a real-time multiplayer reaction speed game. Players join a game using a code, wait for a green flash to appear on their screen, and click as fast as possible. The fastest player wins. Everything runs on AWS with no traditional servers.

---

## 2. System Architecture

```
Browser (S3 Frontend)
        |
        | WebSocket
        |
   API Gateway
   /     |       /      |      game   player  result
service service service
(Lambda)(Lambda)(Lambda)
  |       |       |
Games  Players  Results
(DynamoDB tables)
```

| Component | Technology | Purpose |
|---|---|---|
| Frontend | S3 Static Website | Browser UI anyone can open |
| API Gateway | WebSocket API | Receives real-time messages from players |
| game-service | Lambda + Docker | Creates games, sends green flash signal |
| player-service | Lambda + Docker | Handles connect, join, reaction submission |
| result-service | Lambda + Docker | Returns final rankings |
| Games / Players / Results | DynamoDB | Stores all game state |
| ECR | Amazon ECR | Stores Docker images for all 3 Lambdas |
| CI/CD | GitHub Actions | Builds and deploys automatically on every push |

---

## 3. The 15 Factors

### Factor 1 - One Codebase
We have one GitHub repository that contains everything: Lambda code, Terraform, CI/CD pipeline, and frontend. One repo, one application, one production environment.

### Factor 2 - API First
We designed the WebSocket messages (createGame, joinGame, startGame, submitReaction) and their response formats before writing any code. This let us build the frontend and backend independently.

### Factor 3 - Dependency Management
Each Lambda has a package.json that lists exact package versions. During the Docker image build, npm install runs automatically and all dependencies are locked inside the container image. Nothing depends on what is already installed on the machine.

### Factor 4 - Design, Build, Release, Run
Strictly separated:
- Design: write code and commit to GitHub
- Build: GitHub Actions builds a Docker image for each Lambda
- Release: image pushed to ECR, Terraform deploys it to Lambda
- Run: Lambda runs the container when a player sends a message

### Factor 5 - Configuration
Nothing is hardcoded. All config is stored as:
- Lambda environment variables (set by Terraform): table names, WebSocket endpoint
- GitHub Secrets: AWS credentials for CI/CD

### Factor 6 - Logs
All Lambda functions use console.log(). AWS automatically streams these to CloudWatch Logs. Logs are event streams, not disk files. We used CloudWatch during testing to verify correct behavior.

### Factor 7 - Disposability
Lambda starts in milliseconds and shuts down after each request. There is nothing to crash or hang. Old game data auto-deletes after 1 hour using DynamoDB TTL.

### Factor 8 - Backing Services
DynamoDB is an attached backing service. Lambda connects to it via table names in environment variables. If we changed the table name, only the environment variable changes, not the code.

### Factor 9 - Environment Parity
The same Docker image built in GitHub Actions runs on AWS Lambda in production. No "works on my machine" problem because the environment is always identical.

### Factor 10 - Administrative Processes
All infrastructure is managed by Terraform as one-off commands. We never click in the AWS console. The deploy.ps1 script rebuilds the entire environment from scratch with one command.

### Factor 11 - Port Binding
Lambda functions do not listen on ports. API Gateway handles all WebSocket connections and routes messages to the correct Lambda. The frontend connects to the API Gateway URL.

### Factor 12 - Stateless Processes
Lambda functions store nothing between invocations. All state (game status, player connections, reaction times) lives in DynamoDB. Any Lambda instance can handle any request.

### Factor 13 - Concurrency
Lambda automatically runs multiple instances in parallel when many players send messages at once. DynamoDB scales automatically with PAY_PER_REQUEST mode.

### Factor 14 - Telemetry
Monitoring via Amazon CloudWatch:
- Logs: every Lambda invocation produces a log entry
- Metrics: Lambda tracks invocation count, duration, errors automatically
- Alarms: can be set up to alert on error spikes

### Factor 15 - Authentication and Authorization
- Lambda uses an IAM execution role with least-privilege policies
- CI/CD pipeline uses IAM credentials stored as encrypted GitHub Secrets
- ECR repositories allow image pulls only from the Lambda service

---

## 4. REST API Documentation

### WebSocket Endpoint
wss://a3kfvwmm01.execute-api.us-east-1.amazonaws.com/prod

All messages are JSON. The "action" field determines which Lambda handles the request.

**Create a Game**
```
Send:    { "action": "createGame", "playerName": "Ziyad" }
Receive: { "action": "gameCreated", "gameId": "AB3F" }
```

**Join a Game**
```
Send:    { "action": "joinGame", "gameId": "AB3F", "playerName": "Ali" }
Receive (all): { "action": "playerJoined", "playerName": "Ali", "players": ["Ziyad","Ali"] }
```

**Start Game (host only)**
```
Send:     { "action": "startGame", "gameId": "AB3F" }
Receive:  { "action": "gameStarting" }
Then after 2-6 seconds:
Receive:  { "action": "SIGNAL", "signalAt": 1746123456789 }
```

**Submit Reaction**
```
Send:    { "action": "submitReaction", "gameId": "AB3F", "clickedAt": 1746123457032 }
Receive: { "action": "reactionRecorded", "reactionMs": 243 }
When all players submit:
Receive: { "action": "RESULTS", "rankings": [
  { "rank": 1, "name": "Ali", "ms": 243, "medal": "1st" },
  { "rank": 2, "name": "Ziyad", "ms": 381, "medal": "2nd" }
]}
```

### REST API
GET /results?gameId=AB3F
Returns the rankings for a completed game.

---

## 5. Appendix - AI Prompts Used

**Prompt 1 - Build the full project**
Build a complete AWS multiplayer reaction speed game. Requirements: 3 Lambda functions (game-service, player-service, result-service), 3 DynamoDB tables (Games, Players, Results), API Gateway WebSocket, all infrastructure in Terraform, GitHub Actions CI/CD, frontend HTML/CSS/JS, deploy.ps1 script, and instructions for 3 team members. Stack: Node.js 20, AWS, Terraform.

**Prompt 2 - Create IAM user for teammate**
Create an IAM user called ali in AWS account 438825592512 with AdministratorAccess and console login enabled for a course project teammate.

**Prompt 3 - Host frontend on S3**
Host the game frontend on AWS S3 with static website hosting so anyone can open it from any browser. The backend WebSocket is already deployed on API Gateway.

**Prompt 4 - Fix CI/CD and complete 15-factor compliance**
The course requires CI/CD that builds Docker container images and deploys to production, all infrastructure in Terraform (no manual configs), and a technical document for all 15 factors. Add Dockerfiles to each Lambda, ECR repos and S3 bucket to Terraform, fix GitHub Actions to build and push Docker images and run terraform apply, write the full technical report.
