# =============================================
# REACTION GAME - ONE CLICK DEPLOY SCRIPT
# Run this in PowerShell from the project folder
# =============================================

Write-Host "⚡ Reaction Speed Game - Auto Deploy" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Step 1: Check AWS is configured
Write-Host "`n[1/4] Checking AWS connection..." -ForegroundColor Yellow
$identity = aws sts get-caller-identity 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ AWS not configured! Run: aws configure" -ForegroundColor Red
    exit 1
}
Write-Host "✅ AWS connected" -ForegroundColor Green

# Step 2: Install Lambda dependencies
Write-Host "`n[2/4] Installing Lambda dependencies..." -ForegroundColor Yellow
Set-Location lambdas/game-service; npm install --silent; Set-Location ../..
Set-Location lambdas/player-service; npm install --silent; Set-Location ../..
Set-Location lambdas/result-service; npm install --silent; Set-Location ../..
Write-Host "✅ Dependencies installed" -ForegroundColor Green

# Step 3: Terraform init and apply
Write-Host "`n[3/4] Running Terraform..." -ForegroundColor Yellow
Set-Location terraform
terraform init
terraform apply -auto-approve
$ws_url = terraform output -raw websocket_url
Set-Location ..

Write-Host "✅ Infrastructure deployed!" -ForegroundColor Green

# Step 4: Update frontend with real URL
Write-Host "`n[4/4] Updating frontend with WebSocket URL..." -ForegroundColor Yellow
$html = Get-Content frontend/index.html -Raw
$html = $html -replace 'wss://REPLACE_WITH_PERSON_1_URL/prod', $ws_url
Set-Content frontend/index.html $html
Write-Host "✅ Frontend updated!" -ForegroundColor Green

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "🚀 DEPLOY COMPLETE!" -ForegroundColor Green
Write-Host "WebSocket URL: $ws_url" -ForegroundColor Yellow
Write-Host "Send this URL to Person 2 and Person 3!" -ForegroundColor Yellow
Write-Host "`nOpen frontend/index.html in your browser to play!" -ForegroundColor Cyan
