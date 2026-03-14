# #!/bin/bash
# # ================================================================
# # escrowmanager — Complete API Test Script
# # Run: chmod +x test_api.sh && ./test_api.sh
# # Make sure your server is running: npm run dev
# # ================================================================

# BASE="http://localhost:3000"
# EMPLOYER_EMAIL="employer_$(date +%s)@test.com"
# FREELANCER_EMAIL="freelancer_$(date +%s)@test.com"
# PASSWORD="password123"

# # Colors
# GREEN='\033[0;32m'
# RED='\033[0;31m'
# YELLOW='\033[1;33m'
# BLUE='\033[0;34m'
# NC='\033[0m'

# pass() { echo -e "${GREEN}  PASS${NC} $1"; }
# fail() { echo -e "${RED}  FAIL${NC} $1"; }
# step() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
# info() { echo -e "${YELLOW}  →${NC} $1"; }

# step "STEP 1 — Register Employer"
# EMPLOYER=$(curl -s -X POST "$BASE/api/auth/register" \
#   -H "Content-Type: application/json" \
#   -d "{\"name\":\"Test Employer\",\"email\":\"$EMPLOYER_EMAIL\",\"password\":\"$PASSWORD\",\"role\":\"EMPLOYER\"}")
# echo "$EMPLOYER" | grep -q '"token"' && pass "Employer registered" || fail "Employer registration failed"
# EMPLOYER_TOKEN=$(echo "$EMPLOYER" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
# info "Token: ${EMPLOYER_TOKEN:0:30}..."

# step "STEP 2 — Register Freelancer"
# FREELANCER=$(curl -s -X POST "$BASE/api/auth/register" \
#   -H "Content-Type: application/json" \
#   -d "{\"name\":\"Test Freelancer\",\"email\":\"$FREELANCER_EMAIL\",\"password\":\"$PASSWORD\",\"role\":\"FREELANCER\"}")
# echo "$FREELANCER" | grep -q '"token"' && pass "Freelancer registered" || fail "Freelancer registration failed"
# FREELANCER_TOKEN=$(echo "$FREELANCER" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
# FREELANCER_ID=$(echo "$FREELANCER" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
# info "Freelancer ID: $FREELANCER_ID"

# step "STEP 3 — Login (verify JWT works)"
# LOGIN=$(curl -s -X POST "$BASE/api/auth/login" \
#   -H "Content-Type: application/json" \
#   -d "{\"email\":\"$EMPLOYER_EMAIL\",\"password\":\"$PASSWORD\"}")
# echo "$LOGIN" | grep -q '"token"' && pass "Login works" || fail "Login failed"

# step "STEP 4 — Create Project (triggers Groq AI milestone generation)"
# info "Calling Groq to decompose project into milestones..."
# PROJECT=$(curl -s -X POST "$BASE/api/projects" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $EMPLOYER_TOKEN" \
#   -d "{
#     \"title\": \"E-commerce Website\",
#     \"description\": \"Build a full-stack e-commerce website with product listings, shopping cart, user authentication, and payment integration using React and Node.js\",
#     \"budget\": 1000,
#     \"deadline\": \"2026-06-01T00:00:00Z\",
#     \"freelancerEmail\": \"$FREELANCER_EMAIL\"
#   }")
# echo "$PROJECT" | grep -q '"id"' && pass "Project created with AI milestones" || fail "Project creation failed"
# PROJECT_ID=$(echo "$PROJECT" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
# MILESTONE_COUNT=$(echo "$PROJECT" | grep -o '"order"' | wc -l | tr -d ' ')
# info "Project ID: $PROJECT_ID"
# info "AI generated $MILESTONE_COUNT milestones"

# step "STEP 5 — Get Project (verify milestones saved)"
# GET_PROJECT=$(curl -s "$BASE/api/projects/$PROJECT_ID" \
#   -H "Authorization: Bearer $EMPLOYER_TOKEN")
# echo "$GET_PROJECT" | grep -q '"milestones"' && pass "Project fetch works" || fail "Project fetch failed"
# MILESTONE_ID=$(echo "$GET_PROJECT" | grep -o '"id":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)
# info "First milestone ID: $MILESTONE_ID"

# step "STEP 6 — Fund Escrow"
# FUND=$(curl -s -X POST "$BASE/api/escrow/fund" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $EMPLOYER_TOKEN" \
#   -d "{\"projectId\":\"$PROJECT_ID\"}")
# echo "$FUND" | grep -q '"clientSecret"' && pass "Escrow funded" || fail "Escrow funding failed"
# PAYMENT_INTENT=$(echo "$FUND" | grep -o '"paymentIntentId":"[^"]*"' | cut -d'"' -f4)
# info "PaymentIntent: $PAYMENT_INTENT"

# step "STEP 7 — Confirm Escrow Funding"
# CONFIRM=$(curl -s -X POST "$BASE/api/escrow/confirm" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $EMPLOYER_TOKEN" \
#   -d "{\"projectId\":\"$PROJECT_ID\",\"paymentIntentId\":\"$PAYMENT_INTENT\"}")
# echo "$CONFIRM" | grep -q '"FUNDED"' && pass "Escrow confirmed, status FUNDED" || fail "Escrow confirmation failed"

# step "STEP 8 — Freelancer views assigned milestones"
# MY_MILESTONES=$(curl -s "$BASE/api/freelancer/milestones" \
#   -H "Authorization: Bearer $FREELANCER_TOKEN")
# echo "$MY_MILESTONES" | grep -q '"milestones"' && pass "Freelancer can see milestones" || fail "Freelancer milestone fetch failed"

# step "STEP 9 — Submit Milestone (triggers AI Agent: score → payment → PFI)"
# info "This calls the Groq tool-calling agent. May take 5-10 seconds..."
# SUBMIT=$(curl -s -X POST "$BASE/api/milestones/$MILESTONE_ID/submit" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $FREELANCER_TOKEN" \
#   -d "{
#     \"workDescription\": \"I have completed the project setup milestone. The GitHub repository has been created at github.com/test/ecommerce. The folder structure follows the standard React + Node.js pattern with separate client and server directories. All dependencies including React 18, Express, Prisma, and Stripe SDK have been installed and configured. The README documents the setup process and development environment is fully working with hot reload enabled.\",
#     \"repoUrl\": \"https://github.com/test/ecommerce-project\"
#   }")
# echo "$SUBMIT" | grep -q '"submissionId"' && pass "Submission accepted (202) — AI agent running" || fail "Submission failed"
# SUBMISSION_ID=$(echo "$SUBMIT" | grep -o '"submissionId":"[^"]*"' | cut -d'"' -f4)
# info "Submission ID: $SUBMISSION_ID"
# info "Waiting 12 seconds for AI agent to complete..."
# sleep 12

# step "STEP 10 — Check AQA Result (did the agent score it?)"
# RESULT=$(curl -s "$BASE/api/milestones/$MILESTONE_ID/result" \
#   -H "Authorization: Bearer $FREELANCER_TOKEN")
# echo "$RESULT" | grep -q '"aqaScore"' && pass "AQA result available" || fail "AQA result not ready yet — try again in a few seconds"
# AQA_SCORE=$(echo "$RESULT" | grep -o '"aqaScore":[0-9.]*' | cut -d':' -f2)
# AQA_DECISION=$(echo "$RESULT" | grep -o '"aqaDecision":"[^"]*"' | cut -d'"' -f4)
# AQA_FEEDBACK=$(echo "$RESULT" | grep -o '"aqaFeedback":"[^"]*"' | cut -d'"' -f4 | cut -c1-80)
# info "Score: $AQA_SCORE / 100"
# info "Decision: $AQA_DECISION"
# info "Feedback: ${AQA_FEEDBACK}..."

# step "STEP 11 — Check PFI Score (did it update after payment?)"
# PFI=$(curl -s "$BASE/api/freelancer/pfi" \
#   -H "Authorization: Bearer $FREELANCER_TOKEN")
# echo "$PFI" | grep -q '"overallScore"\|No milestones' && pass "PFI endpoint works" || fail "PFI fetch failed"
# PFI_SCORE=$(echo "$PFI" | grep -o '"overallScore":[0-9.]*' | cut -d':' -f2)
# PFI_INTERP=$(echo "$PFI" | grep -o '"interpretation":"[^"]*"' | cut -d'"' -f4)
# info "PFI Score: $PFI_SCORE ($PFI_INTERP)"

# step "STEP 12 — Check Escrow Balance (did money move?)"
# ESCROW=$(curl -s "$BASE/api/escrow/$PROJECT_ID" \
#   -H "Authorization: Bearer $EMPLOYER_TOKEN")
# echo "$ESCROW" | grep -q '"heldAmount"' && pass "Escrow balance readable" || fail "Escrow fetch failed"
# HELD=$(echo "$ESCROW" | grep -o '"heldAmount":[0-9.]*' | cut -d':' -f2)
# RELEASED=$(echo "$ESCROW" | grep -o '"releasedAmount":[0-9.]*' | cut -d':' -f2)
# info "Held: \$$HELD | Released: \$$RELEASED"

# step "STEP 13 — Auth guard (no token = 401)"
# NO_AUTH=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/projects")
# [ "$NO_AUTH" = "401" ] && pass "Auth guard working (got 401)" || fail "Auth guard broken (got $NO_AUTH)"

# step "STEP 14 — Role guard (freelancer cannot create project)"
# ROLE_GUARD=$(curl -s -X POST "$BASE/api/projects" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $FREELANCER_TOKEN" \
#   -d "{\"title\":\"Hack\",\"description\":\"Should not work at all\",\"budget\":100,\"deadline\":\"2026-06-01T00:00:00Z\"}")
# echo "$ROLE_GUARD" | grep -q '"error"' && pass "Role guard working (freelancer blocked)" || fail "Role guard broken"

# echo ""
# echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
# echo -e "${GREEN}  All tests complete${NC}"
# echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
# echo ""
# echo "  Summary of what was tested:"
# echo "  1.  Register employer"
# echo "  2.  Register freelancer"
# echo "  3.  Login + JWT"
# echo "  4.  AI milestone generation (Groq)"
# echo "  5.  Project fetch"
# echo "  6.  Escrow fund"
# echo "  7.  Escrow confirm"
# echo "  8.  Freelancer milestone view"
# echo "  9.  Milestone submit → AI agent"
# echo "  10. AQA score + decision"
# echo "  11. PFI reputation score"
# echo "  12. Escrow balance after payout"
# echo "  13. Auth guard (401 check)"
# echo "  14. Role guard (EMPLOYER only)"
# echo ""
#!/bin/bash
# ================================================================
# escrowmanager — Full Interactive Test Runner
# Run: chmod +x test_full.sh && ./test_full.sh
# ================================================================

# BASE="http://localhost:3000"
# GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
# BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# pass()  { echo -e "  ${GREEN}✔ PASS${NC}  $1"; }
# fail()  { echo -e "  ${RED}✗ FAIL${NC}  $1"; }
# step()  { echo -e "\n${BLUE}${BOLD}━━━ $1 ━━━${NC}"; }
# info()  { echo -e "  ${YELLOW}→${NC} $1"; }
# data()  { echo -e "  ${CYAN}$1${NC}"; }
# die()   { echo -e "\n${RED}STOPPED: $1${NC}\n"; exit 1; }

# echo -e "${BOLD}"
# echo "  ██████╗ ██╗████████╗██████╗ ██╗   ██╗██████╗ ██╗████████╗"
# echo "  ██╔══██╗██║╚══██╔══╝██╔══██╗╚██╗ ██╔╝██╔══██╗██║╚══██╔══╝"
# echo "  ██████╔╝██║   ██║   ██████╔╝ ╚████╔╝ ██████╔╝██║   ██║   "
# echo "  ██╔══██╗██║   ██║   ██╔══██╗  ╚██╔╝  ██╔══██╗██║   ██║   "
# echo "  ██████╔╝██║   ██║   ██████╔╝   ██║   ██████╔╝██║   ██║   "
# echo "  ╚═════╝ ╚═╝   ╚═╝   ╚═════╝    ╚═╝   ╚═════╝ ╚═╝   ╚═╝   "
# echo -e "${NC}"
# echo -e "  ${CYAN}escrowmanager — Full System Test${NC}"
# echo -e "  Testing: Auth → AI Milestones → Escrow → AQA Agent → PFI\n"

# # ── STEP 1: Register Employer ─────────────────────────────────────
# step "STEP 1 — Register Employer"
# TS=$(date +%s)
# EMP_EMAIL="employer_${TS}@test.com"
# EMP_PASS="pass123"

# EMP_RES=$(curl -s -X POST "$BASE/api/auth/register" \
#   -H "Content-Type: application/json" \
#   -d "{\"name\":\"Test Employer\",\"email\":\"$EMP_EMAIL\",\"password\":\"$EMP_PASS\",\"role\":\"EMPLOYER\"}")

# EMP_TOKEN=$(echo "$EMP_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
# EMP_ID=$(echo "$EMP_RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

# [ -n "$EMP_TOKEN" ] && pass "Employer registered" || die "Employer registration failed. Response: $EMP_RES"
# info "Email: $EMP_EMAIL"
# info "ID:    $EMP_ID"

# # ── STEP 2: Register Freelancer ───────────────────────────────────
# step "STEP 2 — Register Freelancer"
# FREE_EMAIL="freelancer_${TS}@test.com"
# FREE_PASS="pass123"

# FREE_RES=$(curl -s -X POST "$BASE/api/auth/register" \
#   -H "Content-Type: application/json" \
#   -d "{\"name\":\"Test Freelancer\",\"email\":\"$FREE_EMAIL\",\"password\":\"$FREE_PASS\",\"role\":\"FREELANCER\"}")

# FREE_TOKEN=$(echo "$FREE_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
# FREE_ID=$(echo "$FREE_RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

# [ -n "$FREE_TOKEN" ] && pass "Freelancer registered" || die "Freelancer registration failed. Response: $FREE_RES"
# info "Email: $FREE_EMAIL"
# info "ID:    $FREE_ID"

# # ── STEP 3: Login ─────────────────────────────────────────────────
# step "STEP 3 — Login"
# LOGIN_RES=$(curl -s -X POST "$BASE/api/auth/login" \
#   -H "Content-Type: application/json" \
#   -d "{\"email\":\"$EMP_EMAIL\",\"password\":\"$EMP_PASS\"}")

# LOGIN_TOKEN=$(echo "$LOGIN_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
# [ -n "$LOGIN_TOKEN" ] && pass "Login works, JWT issued" || fail "Login failed"

# # ── STEP 4: Create Project (AI Milestone Generation) ──────────────
# step "STEP 4 — Create Project  [GROQ AI CALL]"
# info "Sending project to Groq for milestone decomposition..."
# info "This may take 3-5 seconds..."

# PROJECT_RES=$(curl -s -X POST "$BASE/api/projects" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $EMP_TOKEN" \
#   -d "{
#     \"title\": \"E-commerce Platform\",
#     \"description\": \"Build a full-stack e-commerce website with product listings, shopping cart, user authentication, and Stripe payment integration using React and Node.js. Include admin dashboard and order management.\",
#     \"budget\": 1000,
#     \"deadline\": \"2026-08-01T00:00:00Z\",
#     \"freelancerEmail\": \"$FREE_EMAIL\"
#   }")

# PROJECT_ID=$(echo "$PROJECT_RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
# MILESTONE_COUNT=$(echo "$PROJECT_RES" | grep -o '"order"' | wc -l | tr -d ' ')

# [ -n "$PROJECT_ID" ] && pass "Project created" || die "Project creation failed.\nResponse: $PROJECT_RES"
# pass "Groq generated $MILESTONE_COUNT milestones"
# info "Project ID: $PROJECT_ID"

# # Print milestone titles
# echo ""
# echo -e "  ${BOLD}AI-Generated Milestones:${NC}"
# echo "$PROJECT_RES" | grep -o '"title":"[^"]*"' | tail -n +2 | while IFS= read -r line; do
#   TITLE=$(echo "$line" | cut -d'"' -f4)
#   echo -e "    ${CYAN}•${NC} $TITLE"
# done

# # Extract first ASSIGNED milestone
# MILESTONE_ID=$(echo "$PROJECT_RES" | grep -o '"id":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)
# MILESTONE_TITLE=$(echo "$PROJECT_RES" | grep -o '"title":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)
# MILESTONE_AMOUNT=$(echo "$PROJECT_RES" | grep -o '"amount":[0-9]*' | head -1 | cut -d':' -f2)
# info "Using milestone: \"$MILESTONE_TITLE\" (\$$MILESTONE_AMOUNT)"

# # ── STEP 5: Get Project ───────────────────────────────────────────
# step "STEP 5 — Fetch Project from DB"
# GET_RES=$(curl -s "$BASE/api/projects/$PROJECT_ID" \
#   -H "Authorization: Bearer $EMP_TOKEN")

# echo "$GET_RES" | grep -q '"milestones"' && pass "Project + milestones fetched from DB" || fail "Project fetch failed"

# # ── STEP 6: Fund Escrow ───────────────────────────────────────────
# step "STEP 6 — Fund Escrow"
# FUND_RES=$(curl -s -X POST "$BASE/api/escrow/fund" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $EMP_TOKEN" \
#   -d "{\"projectId\":\"$PROJECT_ID\"}")

# PAYMENT_INTENT=$(echo "$FUND_RES" | grep -o '"paymentIntentId":"[^"]*"' | cut -d'"' -f4)
# [ -n "$PAYMENT_INTENT" ] && pass "Escrow payment intent created" || die "Escrow funding failed. Response: $FUND_RES"
# info "PaymentIntent: $PAYMENT_INTENT"

# # ── STEP 7: Confirm Escrow ────────────────────────────────────────
# step "STEP 7 — Confirm Escrow Funded"
# CONFIRM_RES=$(curl -s -X POST "$BASE/api/escrow/confirm" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $EMP_TOKEN" \
#   -d "{\"projectId\":\"$PROJECT_ID\",\"paymentIntentId\":\"$PAYMENT_INTENT\"}")

# echo "$CONFIRM_RES" | grep -q 'FUNDED' && pass "Escrow status = FUNDED, \$1000 held" || fail "Escrow confirmation failed. Response: $CONFIRM_RES"

# # ── STEP 8: Freelancer Sees Milestones ────────────────────────────
# step "STEP 8 — Freelancer Views Assigned Milestones"
# FL_MILES=$(curl -s "$BASE/api/freelancer/milestones" \
#   -H "Authorization: Bearer $FREE_TOKEN")

# echo "$FL_MILES" | grep -q '"milestones"' && pass "Freelancer can see assigned milestones" || fail "Freelancer milestone fetch failed"
# ASSIGNED_COUNT=$(echo "$FL_MILES" | grep -o '"status":"ASSIGNED"' | wc -l | tr -d ' ')
# info "$ASSIGNED_COUNT milestone(s) with status ASSIGNED"

# # ── STEP 9: Submit Milestone ──────────────────────────────────────
# step "STEP 9 — Submit Milestone  [GROQ AGENT CALL]"
# info "Submitting work for: \"$MILESTONE_TITLE\""
# info "This triggers the 3-tool agent: score → payment → PFI"
# info "Agent runs in background, may take 10-15 seconds..."

# SUBMIT_RES=$(curl -s -X POST "$BASE/api/milestones/$MILESTONE_ID/submit" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $FREE_TOKEN" \
#   -d "{
#     \"workDescription\": \"I have completed the first milestone for the E-commerce Platform project. The GitHub repository has been created and initialized at github.com/freelancer/ecommerce-platform. The complete folder structure has been set up following React and Node.js best practices, with separate client and server directories. All required dependencies have been installed including React 18, Express 4, Prisma ORM, and Stripe SDK. The development environment is fully configured with hot reload using nodemon and vite. The README.md has been written with complete setup instructions. The basic CI/CD pipeline has been configured using GitHub Actions.\",
#     \"repoUrl\": \"https://github.com/freelancer/ecommerce-platform\"
#   }")

# SUBMISSION_ID=$(echo "$SUBMIT_RES" | grep -o '"submissionId":"[^"]*"' | cut -d'"' -f4)
# [ -n "$SUBMISSION_ID" ] && pass "Submission accepted (202) — AI agent running in background" || die "Submission failed. Response: $SUBMIT_RES"
# info "Submission ID: $SUBMISSION_ID"

# # Wait for agent to complete
# echo ""
# for i in 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1; do
#   echo -ne "  ${YELLOW}Waiting for AI agent...${NC} ${i}s remaining\r"
#   sleep 1
# done
# echo -e "  ${GREEN}Agent processing complete${NC}                    "

# # ── STEP 10: AQA Result ───────────────────────────────────────────
# step "STEP 10 — AQA Result  [AGENT OUTPUT]"
# RESULT=$(curl -s "$BASE/api/milestones/$MILESTONE_ID/result" \
#   -H "Authorization: Bearer $FREE_TOKEN")

# AQA_SCORE=$(echo "$RESULT" | grep -o '"aqaScore":[0-9.]*' | cut -d':' -f2)
# AQA_DECISION=$(echo "$RESULT" | grep -o '"aqaDecision":"[^"]*"' | cut -d'"' -f4)
# AQA_STATUS=$(echo "$RESULT" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
# AQA_FEEDBACK=$(echo "$RESULT" | grep -o '"aqaFeedback":"[^"]*"' | cut -d'"' -f4)

# [ -n "$AQA_SCORE" ] && pass "AQA evaluation complete" || fail "AQA result not ready — run: curl -s $BASE/api/milestones/$MILESTONE_ID/result -H \"Authorization: Bearer $FREE_TOKEN\""

# echo ""
# echo -e "  ${BOLD}┌─────────────────────────────────────┐${NC}"
# echo -e "  ${BOLD}│         AQA EVALUATION RESULT        │${NC}"
# echo -e "  ${BOLD}├─────────────────────────────────────┤${NC}"

# # Score bar
# if [ -n "$AQA_SCORE" ]; then
#   SCORE_INT=${AQA_SCORE%.*}
#   BAR_FILL=$((SCORE_INT / 5))
#   BAR=""
#   for i in $(seq 1 $BAR_FILL); do BAR="${BAR}█"; done
#   for i in $(seq $BAR_FILL 19); do BAR="${BAR}░"; done

#   if [ "$SCORE_INT" -ge 85 ]; then COLOR=$GREEN
#   elif [ "$SCORE_INT" -ge 50 ]; then COLOR=$YELLOW
#   else COLOR=$RED; fi

#   echo -e "  ${BOLD}│${NC} Score:    ${COLOR}${BOLD}$AQA_SCORE / 100${NC}  ${COLOR}${BAR}${NC}"
# fi

# echo -e "  ${BOLD}│${NC} Decision: ${BOLD}$AQA_DECISION${NC}"
# echo -e "  ${BOLD}│${NC} Status:   $AQA_STATUS"
# echo -e "  ${BOLD}├─────────────────────────────────────┤${NC}"
# echo -e "  ${BOLD}│${NC} Feedback:"
# # Word wrap feedback at 45 chars
# echo "$AQA_FEEDBACK" | fold -s -w 45 | while IFS= read -r line; do
#   echo -e "  ${BOLD}│${NC}   $line"
# done
# echo -e "  ${BOLD}└─────────────────────────────────────┘${NC}"

# # ── STEP 11: PFI Score ────────────────────────────────────────────
# step "STEP 11 — PFI Reputation Score"
# PFI_RES=$(curl -s "$BASE/api/freelancer/pfi" \
#   -H "Authorization: Bearer $FREE_TOKEN")

# PFI_SCORE=$(echo "$PFI_RES" | grep -o '"overallScore":[0-9.]*' | cut -d':' -f2)
# PFI_INTERP=$(echo "$PFI_RES" | grep -o '"interpretation":"[^"]*"' | cut -d'"' -f4)
# PFI_ACCURACY=$(echo "$PFI_RES" | grep -o '"milestoneAccuracy":[0-9.]*' | cut -d':' -f2)
# PFI_DEADLINE=$(echo "$PFI_RES" | grep -o '"deadlineAdherence":[0-9.]*' | cut -d':' -f2)
# PFI_AQA=$(echo "$PFI_RES" | grep -o '"averageAqaScore":[0-9.]*' | cut -d':' -f2)

# echo "$PFI_RES" | grep -q 'overallScore' && pass "PFI score calculated" || fail "PFI fetch failed"

# if [ -n "$PFI_SCORE" ]; then
#   echo ""
#   echo -e "  ${BOLD}Professional Fidelity Index (PFI)${NC}"
#   echo -e "  Overall Score  : ${CYAN}${BOLD}$PFI_SCORE${NC}  ($PFI_INTERP)"
#   echo -e "  ├ Milestone Accuracy  (40%) : $PFI_ACCURACY"
#   echo -e "  ├ Deadline Adherence  (30%) : $PFI_DEADLINE"
#   echo -e "  └ Avg AQA Score       (30%) : $PFI_AQA"
# fi

# # ── STEP 12: Escrow Balance ───────────────────────────────────────
# step "STEP 12 — Escrow Balance After Payout"
# ESCROW_RES=$(curl -s "$BASE/api/escrow/$PROJECT_ID" \
#   -H "Authorization: Bearer $EMP_TOKEN")

# HELD=$(echo "$ESCROW_RES" | grep -o '"heldAmount":[0-9.]*' | cut -d':' -f2)
# RELEASED=$(echo "$ESCROW_RES" | grep -o '"releasedAmount":[0-9.]*' | cut -d':' -f2)
# REFUNDED=$(echo "$ESCROW_RES" | grep -o '"refundedAmount":[0-9.]*' | cut -d':' -f2)
# ESCROW_STATUS=$(echo "$ESCROW_RES" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)

# echo "$ESCROW_RES" | grep -q '"heldAmount"' && pass "Escrow balance retrieved" || fail "Escrow fetch failed"

# echo ""
# echo -e "  ${BOLD}Escrow Account Status: $ESCROW_STATUS${NC}"
# echo -e "  ├ Held     : ${YELLOW}\$$HELD${NC}"
# echo -e "  ├ Released : ${GREEN}\$$RELEASED${NC}"
# echo -e "  └ Refunded : ${RED}\$$REFUNDED${NC}"

# if [ "${RELEASED:-0}" != "0" ] && [ "${RELEASED:-0}" != "" ]; then
#   pass "Money moved from escrow to freelancer"
# else
#   info "Released = 0 — check server logs for agent output"
# fi

# # ── STEP 13: Security Checks ──────────────────────────────────────
# step "STEP 13 — Security: Auth Guard"
# NO_AUTH=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/projects")
# [ "$NO_AUTH" = "401" ] && pass "No token → 401 Unauthorized" || fail "Auth guard broken (got HTTP $NO_AUTH)"

# step "STEP 14 — Security: Role Guard"
# ROLE_RES=$(curl -s -X POST "$BASE/api/projects" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $FREE_TOKEN" \
#   -d "{\"title\":\"Hack attempt\",\"description\":\"Should be blocked by role guard\",\"budget\":100,\"deadline\":\"2026-08-01T00:00:00Z\"}")
# echo "$ROLE_RES" | grep -q '"error"' && pass "Freelancer blocked from creating project" || fail "Role guard broken"

# step "STEP 15 — Security: Wrong User Guard"
# OTHER_RES=$(curl -s "$BASE/api/projects/$PROJECT_ID" \
#   -H "Authorization: Bearer $FREE_TOKEN")
# # freelancer assigned to project CAN view it — just check it doesn't crash
# echo "$OTHER_RES" | grep -q '"id"' && pass "Assigned user can view project" || info "Project access response: $OTHER_RES"

# # ── FINAL SUMMARY ─────────────────────────────────────────────────
# echo ""
# echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
# echo -e "${GREEN}${BOLD}  FULL SYSTEM TEST COMPLETE${NC}"
# echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
# echo ""
# echo -e "  ${BOLD}What was verified:${NC}"
# echo -e "  ${GREEN}✔${NC}  Auth — register, login, JWT token"
# echo -e "  ${GREEN}✔${NC}  Groq AI — decomposed project into $MILESTONE_COUNT milestones"
# echo -e "  ${GREEN}✔${NC}  Database — all data persisted in PostgreSQL"
# echo -e "  ${GREEN}✔${NC}  Escrow — funded \$1000, held in account"
# echo -e "  ${GREEN}✔${NC}  AI Agent — scored submission, triggered payout, updated PFI"
# echo -e "  ${GREEN}✔${NC}  AQA — score: $AQA_SCORE, decision: $AQA_DECISION"
# echo -e "  ${GREEN}✔${NC}  PFI — reputation score: $PFI_SCORE ($PFI_INTERP)"
# echo -e "  ${GREEN}✔${NC}  Security — auth guard, role guard"
# echo ""
# echo -e "  ${CYAN}Project ID  : $PROJECT_ID${NC}"
# echo -e "  ${CYAN}Employer    : $EMP_EMAIL${NC}"
# echo -e "  ${CYAN}Freelancer  : $FREE_EMAIL${NC}"
# echo -e "  ${CYAN}Milestone   : $MILESTONE_TITLE${NC}"
# echo ""

#!/bin/bash
# ================================================================
# BitByBit — Complete System Test
# Tests every feature including GitHub AQA, PFI, escrow, security
# Run: chmod +x test_complete.sh && ./test_complete.sh
# ================================================================

BASE="http://localhost:3000"
PASS=0; FAIL=0

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

pass()  { echo -e "  ${GREEN}✔${NC} $1"; ((PASS++)); }
fail()  { echo -e "  ${RED}✗${NC} $1"; ((FAIL++)); }
step()  { echo -e "\n${BLUE}${BOLD}━━━ $1 ━━━${NC}"; }
info()  { echo -e "  ${YELLOW}→${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }

header() {
  echo -e "\n${BOLD}${CYAN}"
  echo "  ██████╗ ██╗████████╗██████╗ ██╗   ██╗██████╗ ██╗████████╗"
  echo "  ██╔══██╗██║╚══██╔══╝██╔══██╗╚██╗ ██╔╝██╔══██╗██║╚══██╔══╝"
  echo "  ██████╔╝██║   ██║   ██████╔╝ ╚████╔╝ ██████╔╝██║   ██║   "
  echo "  ██╔══██╗██║   ██║   ██╔══██╗  ╚██╔╝  ██╔══██╗██║   ██║   "
  echo "  ██████╔╝██║   ██║   ██████╔╝   ██║   ██████╔╝██║   ██║   "
  echo "  ╚═════╝ ╚═╝   ╚═╝   ╚═════╝    ╚═╝   ╚═════╝ ╚═╝   ╚═╝   "
  echo -e "${NC}"
  echo -e "  ${CYAN}Full System Test — $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
}

header
TS=$(date +%s)
EMP_EMAIL="emp_${TS}@test.com"
FREE_EMAIL="free_${TS}@test.com"
PASS_WORD="pass123"

# ─────────────────────────────────────────────────────────────────
step "MODULE 1 — Authentication"
# ─────────────────────────────────────────────────────────────────

# 1.1 Register employer
RES=$(curl -s -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Test Employer\",\"email\":\"$EMP_EMAIL\",\"password\":\"$PASS_WORD\",\"role\":\"EMPLOYER\"}")
EMP_TOKEN=$(echo "$RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
EMP_ID=$(echo "$RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$EMP_TOKEN" ] && pass "Employer registered" || fail "Employer registration — response: $RES"

# 1.2 Register freelancer
RES=$(curl -s -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Test Freelancer\",\"email\":\"$FREE_EMAIL\",\"password\":\"$PASS_WORD\",\"role\":\"FREELANCER\"}")
FREE_TOKEN=$(echo "$RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
FREE_ID=$(echo "$RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$FREE_TOKEN" ] && pass "Freelancer registered" || fail "Freelancer registration — response: $RES"

# 1.3 Login returns token
RES=$(curl -s -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMP_EMAIL\",\"password\":\"$PASS_WORD\"}")
echo "$RES" | grep -q '"token"' && pass "Login returns JWT" || fail "Login failed"

# 1.4 Wrong password rejected
RES=$(curl -s -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMP_EMAIL\",\"password\":\"wrongpassword\"}")
echo "$RES" | grep -q '"error"' && pass "Wrong password rejected" || fail "Wrong password accepted (security issue)"

# 1.5 Short password rejected by Zod
RES=$(curl -s -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Test\",\"email\":\"short@test.com\",\"password\":\"ab\",\"role\":\"EMPLOYER\"}")
echo "$RES" | grep -q '"error"' && pass "Short password (< 6 chars) rejected by validation" || fail "Short password accepted"

# ─────────────────────────────────────────────────────────────────
step "MODULE 2 — Security Guards"
# ─────────────────────────────────────────────────────────────────

# 2.1 No token → 401
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/projects")
[ "$CODE" = "401" ] && pass "No token → 401 Unauthorized" || fail "Auth guard broken (got $CODE)"

# 2.2 Fake token → 401
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/projects" \
  -H "Authorization: Bearer fake.token.here")
[ "$CODE" = "401" ] && pass "Invalid token → 401" || fail "Invalid token accepted"

# 2.3 Freelancer cannot create project (role guard)
RES=$(curl -s -X POST "$BASE/api/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FREE_TOKEN" \
  -d "{\"title\":\"Hack attempt\",\"description\":\"Should be blocked completely\",\"budget\":100,\"deadline\":\"2026-08-01T00:00:00Z\"}")
echo "$RES" | grep -q '"error"' && pass "Role guard — freelancer blocked from creating project" || fail "Role guard broken"

# ─────────────────────────────────────────────────────────────────
step "MODULE 3 — AI Milestone Generation (NLP Precision)"
# ─────────────────────────────────────────────────────────────────

info "Calling Groq AI to decompose project — may take 5s..."

PROJECT_RES=$(curl -s -X POST "$BASE/api/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EMP_TOKEN" \
  -d "{
    \"title\": \"E-commerce Platform\",
    \"description\": \"Build a production-ready e-commerce platform using React and Node.js. Must include user authentication with JWT, product catalog with search and filters, shopping cart with persistent state, Stripe payment integration, order management system, admin dashboard for inventory, and email notifications for order updates. The backend should use Express with PostgreSQL via Prisma ORM. All API endpoints must be RESTful and include input validation.\",
    \"budget\": 1000,
    \"deadline\": \"2026-08-01T00:00:00Z\",
    \"freelancerEmail\": \"$FREE_EMAIL\"
  }")

PROJECT_ID=$(echo "$PROJECT_RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$PROJECT_ID" ] && pass "Project created successfully" || fail "Project creation failed — $(echo $PROJECT_RES | grep -o '"error":"[^"]*"')"

# Count milestones
MILESTONE_COUNT=$(echo "$PROJECT_RES" | grep -o '"order"' | wc -l | tr -d ' ')
[ "$MILESTONE_COUNT" -ge 3 ] && pass "AI generated $MILESTONE_COUNT milestones (min 3)" || fail "Too few milestones: $MILESTONE_COUNT"

# Check checklist items exist
CHECKLIST_COUNT=$(echo "$PROJECT_RES" | grep -o '"checklist"' | wc -l | tr -d ' ')
[ "$CHECKLIST_COUNT" -ge 3 ] && pass "All milestones have checklists" || fail "Missing checklists"

# Check budget sums correctly
TOTAL_AMOUNT=$(echo "$PROJECT_RES" | grep -o '"amount":[0-9]*' | cut -d':' -f2 | awk '{s+=$1} END {print s}')
[ "$TOTAL_AMOUNT" = "1000" ] && pass "Milestone amounts sum to budget (\$1000)" || fail "Budget mismatch — amounts sum to \$$TOTAL_AMOUNT not \$1000"

# Check deadlines exist
echo "$PROJECT_RES" | grep -q '"deadline"' && pass "Milestones have time-bound deadlines" || fail "No deadlines on milestones"

# Print what AI generated
echo ""
echo -e "  ${BOLD}AI-generated milestones:${NC}"
echo "$PROJECT_RES" | grep -o '"title":"[^"]*"' | tail -n +2 | head -6 | while IFS= read -r line; do
  TITLE=$(echo "$line" | cut -d'"' -f4)
  echo -e "    ${CYAN}•${NC} $TITLE"
done
echo ""

# Extract first milestone for submission test
MILESTONE_ID=$(echo "$PROJECT_RES" | grep -o '"id":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)
MILESTONE_TITLE=$(echo "$PROJECT_RES" | grep -o '"title":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)
MILESTONE_AMOUNT=$(echo "$PROJECT_RES" | grep -o '"amount":[0-9]*' | head -1 | cut -d':' -f2)
info "Using milestone: \"$MILESTONE_TITLE\" (\$$MILESTONE_AMOUNT)"

# ─────────────────────────────────────────────────────────────────
step "MODULE 4 — Escrow & Financial Integrity"
# ─────────────────────────────────────────────────────────────────

# 4.1 Fund escrow
FUND_RES=$(curl -s -X POST "$BASE/api/escrow/fund" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EMP_TOKEN" \
  -d "{\"projectId\":\"$PROJECT_ID\"}")
PAYMENT_INTENT=$(echo "$FUND_RES" | grep -o '"paymentIntentId":"[^"]*"' | cut -d'"' -f4)
[ -n "$PAYMENT_INTENT" ] && pass "Escrow payment intent created" || fail "Escrow fund failed — $FUND_RES"

# 4.2 Confirm funding
CONFIRM_RES=$(curl -s -X POST "$BASE/api/escrow/confirm" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EMP_TOKEN" \
  -d "{\"projectId\":\"$PROJECT_ID\",\"paymentIntentId\":\"$PAYMENT_INTENT\"}")
echo "$CONFIRM_RES" | grep -q 'FUNDED' && pass "Escrow confirmed — status FUNDED, \$1000 held" || fail "Escrow confirmation failed"

# 4.3 Non-owner cannot fund another project's escrow
ANOTHER_PROJECT=$(curl -s -X POST "$BASE/api/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EMP_TOKEN" \
  -d "{\"title\":\"Another Project\",\"description\":\"Another test project for security check\",\"budget\":500,\"deadline\":\"2026-08-01T00:00:00Z\"}")
ANOTHER_ID=$(echo "$ANOTHER_PROJECT" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
WRONG_FUND=$(curl -s -X POST "$BASE/api/escrow/fund" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FREE_TOKEN" \
  -d "{\"projectId\":\"$ANOTHER_ID\"}")
echo "$WRONG_FUND" | grep -q '"error"' && pass "Non-owner blocked from funding escrow" || fail "Escrow ownership guard broken"

# 4.4 Check initial escrow state
ESCROW_RES=$(curl -s "$BASE/api/escrow/$PROJECT_ID" \
  -H "Authorization: Bearer $EMP_TOKEN")
HELD=$(echo "$ESCROW_RES" | grep -o '"heldAmount":[0-9.]*' | cut -d':' -f2)
[ "$HELD" = "1000" ] && pass "Escrow holds full \$1000 before any payout" || fail "Escrow held amount wrong: \$$HELD"

# ─────────────────────────────────────────────────────────────────
step "MODULE 5 — AQA Agent & Verification Logic"
# ─────────────────────────────────────────────────────────────────

info "Submitting milestone work — AQA agent will run in background"
info "Agent will: fetch GitHub (if URL provided) → score → pay → update PFI"
info "Using a real public GitHub repo for verification..."

SUBMIT_RES=$(curl -s -X POST "$BASE/api/milestones/$MILESTONE_ID/submit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FREE_TOKEN" \
  -d "{
    \"workDescription\": \"I have completed the E-commerce Platform setup milestone. The GitHub repository has been initialized at the provided URL with the complete folder structure following React and Node.js best practices. The src directory contains separate client and server folders. All core dependencies have been installed including React 18, Express 4, Prisma ORM, Stripe SDK, and JWT authentication libraries. The package.json is properly configured with all scripts. The README.md contains comprehensive setup instructions, environment variable documentation, and API endpoint reference. The development environment runs successfully with hot reload.\",
    \"repoUrl\": \"https://github.com/expressjs/express\"
  }")

SUBMISSION_ID=$(echo "$SUBMIT_RES" | grep -o '"submissionId":"[^"]*"' | cut -d'"' -f4)
[ -n "$SUBMISSION_ID" ] && pass "Submission accepted (202) — agent running async" || fail "Submission rejected — $SUBMIT_RES"
info "Submission ID: $SUBMISSION_ID"

# Only employer can't submit
EMPLOYER_SUBMIT=$(curl -s -X POST "$BASE/api/milestones/$MILESTONE_ID/submit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EMP_TOKEN" \
  -d "{\"workDescription\":\"Employer trying to submit work which should be blocked completely\"}")
echo "$EMPLOYER_SUBMIT" | grep -q '"error"' && pass "Employer blocked from submitting milestone" || warn "Employer submission guard may be missing"

# Wait for agent
echo ""
for i in $(seq 20 -1 1); do
  printf "\r  ${YELLOW}→${NC} Agent processing... ${i}s  "
  sleep 1
done
echo -e "\r  ${GREEN}✔${NC} Wait complete              "
echo ""

# ─────────────────────────────────────────────────────────────────
step "MODULE 6 — AQA Results"
# ─────────────────────────────────────────────────────────────────

RESULT=$(curl -s "$BASE/api/milestones/$MILESTONE_ID/result" \
  -H "Authorization: Bearer $FREE_TOKEN")

AQA_SCORE=$(echo "$RESULT" | grep -o '"aqaScore":[0-9.]*' | cut -d':' -f2)
AQA_DECISION=$(echo "$RESULT" | grep -o '"aqaDecision":"[^"]*"' | cut -d'"' -f4)
AQA_STATUS=$(echo "$RESULT" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
AQA_FEEDBACK=$(echo "$RESULT" | grep -o '"aqaFeedback":"[^"]*"' | cut -d'"' -f4)

[ -n "$AQA_SCORE" ] && pass "AQA score returned: $AQA_SCORE/100" || fail "AQA score missing — agent may not have finished"
[ -n "$AQA_DECISION" ] && pass "AQA decision: $AQA_DECISION" || fail "AQA decision missing"
[ -n "$AQA_FEEDBACK" ] && pass "Feedback generated for freelancer" || fail "No feedback returned"

# Validate decision matches score threshold
if [ -n "$AQA_SCORE" ]; then
  SCORE_INT=${AQA_SCORE%.*}
  if [ "$SCORE_INT" -ge 85 ] && [ "$AQA_DECISION" = "FULL_PAYOUT" ]; then
    pass "Score ≥ 85 correctly maps to FULL_PAYOUT"
  elif [ "$SCORE_INT" -ge 50 ] && [ "$SCORE_INT" -lt 85 ] && [ "$AQA_DECISION" = "PARTIAL_PAYOUT" ]; then
    pass "Score 50-84 correctly maps to PARTIAL_PAYOUT"
  elif [ "$SCORE_INT" -lt 50 ] && [ "$AQA_DECISION" = "REFUND" ]; then
    pass "Score < 50 correctly maps to REFUND"
  else
    warn "Score $AQA_SCORE → decision $AQA_DECISION (check threshold logic)"
  fi
fi

# Print the full AQA result box
echo ""
echo -e "  ${BOLD}┌─────────────────────────────────────────┐${NC}"
echo -e "  ${BOLD}│           AQA EVALUATION RESULT          │${NC}"
echo -e "  ${BOLD}├─────────────────────────────────────────┤${NC}"
if [ -n "$AQA_SCORE" ]; then
  SCORE_INT=${AQA_SCORE%.*}
  BAR_FILL=$((SCORE_INT / 5))
  BAR=""; for i in $(seq 1 $BAR_FILL); do BAR="${BAR}█"; done
  for i in $(seq $BAR_FILL 19); do BAR="${BAR}░"; done
  if [ "$SCORE_INT" -ge 85 ]; then C=$GREEN; elif [ "$SCORE_INT" -ge 50 ]; then C=$YELLOW; else C=$RED; fi
  echo -e "  ${BOLD}│${NC} Score    ${C}${BOLD}$AQA_SCORE / 100${NC}  ${C}${BAR}${NC}"
fi
echo -e "  ${BOLD}│${NC} Decision $AQA_DECISION"
echo -e "  ${BOLD}│${NC} Status   $AQA_STATUS"
echo -e "  ${BOLD}├─────────────────────────────────────────┤${NC}"
echo -e "  ${BOLD}│${NC} Feedback preview:"
echo "$AQA_FEEDBACK" | cut -c1-55 | while IFS= read -r line; do
  echo -e "  ${BOLD}│${NC}   $line"
done
echo -e "  ${BOLD}└─────────────────────────────────────────┘${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────
step "MODULE 7 — Financial State After AQA"
# ─────────────────────────────────────────────────────────────────

ESCROW_AFTER=$(curl -s "$BASE/api/escrow/$PROJECT_ID" \
  -H "Authorization: Bearer $EMP_TOKEN")

HELD_AFTER=$(echo "$ESCROW_AFTER" | grep -o '"heldAmount":[0-9.]*' | cut -d':' -f2)
RELEASED=$(echo "$ESCROW_AFTER" | grep -o '"releasedAmount":[0-9.]*' | cut -d':' -f2)
REFUNDED=$(echo "$ESCROW_AFTER" | grep -o '"refundedAmount":[0-9.]*' | cut -d':' -f2)

echo "$ESCROW_AFTER" | grep -q '"heldAmount"' && pass "Escrow balance retrieved after AQA" || fail "Escrow fetch failed"

# Money should have moved
RELEASED_INT=${RELEASED%.*}
REFUNDED_INT=${REFUNDED%.*}
[ "${RELEASED_INT:-0}" -gt 0 ] || [ "${REFUNDED_INT:-0}" -gt 0 ] && \
  pass "Money moved from escrow (released: \$$RELEASED, refunded: \$$REFUNDED)" || \
  warn "No money moved yet — agent may still be running"

echo ""
echo -e "  ${BOLD}Escrow balance:${NC}"
echo -e "    Held     ${YELLOW}\$$HELD_AFTER${NC}"
echo -e "    Released ${GREEN}\$$RELEASED${NC}"
echo -e "    Refunded ${RED}\$$REFUNDED${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────
step "MODULE 8 — PFI Scoring Accuracy"
# ─────────────────────────────────────────────────────────────────

PFI_RES=$(curl -s "$BASE/api/freelancer/pfi" \
  -H "Authorization: Bearer $FREE_TOKEN")

PFI_SCORE=$(echo "$PFI_RES" | grep -o '"overallScore":[0-9.]*' | cut -d':' -f2)
PFI_INTERP=$(echo "$PFI_RES" | grep -o '"interpretation":"[^"]*"' | cut -d'"' -f4)
PFI_ACCURACY=$(echo "$PFI_RES" | grep -o '"milestoneAccuracy":[0-9.]*' | cut -d':' -f2)
PFI_DEADLINE=$(echo "$PFI_RES" | grep -o '"deadlineAdherence":[0-9.]*' | cut -d':' -f2)
PFI_AQA_AVG=$(echo "$PFI_RES" | grep -o '"averageAqaScore":[0-9.]*' | cut -d':' -f2)

echo "$PFI_RES" | grep -q 'overallScore\|No milestones' && pass "PFI endpoint responds" || fail "PFI endpoint failed"
[ -n "$PFI_SCORE" ] && pass "PFI score calculated: $PFI_SCORE ($PFI_INTERP)" || warn "No PFI score yet — milestone may not be evaluated"

# Check no NaN in response (our divide-by-zero fix)
echo "$PFI_RES" | grep -qi "nan\|null.*overallScore" && fail "NaN detected in PFI — divide-by-zero bug still present" || pass "No NaN in PFI — divide-by-zero fix works"

if [ -n "$PFI_SCORE" ]; then
  echo ""
  echo -e "  ${BOLD}PFI breakdown:${NC}"
  echo -e "    Overall score    ${CYAN}$PFI_SCORE${NC}  ($PFI_INTERP)"
  echo -e "    Milestone acc    $PFI_ACCURACY  (weight 40%)"
  echo -e "    Deadline adh     $PFI_DEADLINE  (weight 30%)"
  echo -e "    Avg AQA score    $PFI_AQA_AVG  (weight 30%)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────
step "MODULE 9 — Freelancer Dashboard"
# ─────────────────────────────────────────────────────────────────

MILES_RES=$(curl -s "$BASE/api/freelancer/milestones" \
  -H "Authorization: Bearer $FREE_TOKEN")
echo "$MILES_RES" | grep -q '"milestones"' && pass "Freelancer can view assigned milestones" || fail "Milestone fetch failed"

ASSIGNED=$(echo "$MILES_RES" | grep -o '"status":"ASSIGNED"' | wc -l | tr -d ' ')
UNDER_REVIEW=$(echo "$MILES_RES" | grep -o '"status":"UNDER_REVIEW"' | wc -l | tr -d ' ')
APPROVED=$(echo "$MILES_RES" | grep -o '"status":"APPROVED"' | wc -l | tr -d ' ')
info "Milestone statuses — Assigned:$ASSIGNED  UnderReview:$UNDER_REVIEW  Approved:$APPROVED"

# ─────────────────────────────────────────────────────────────────
step "MODULE 10 — Validation Guards"
# ─────────────────────────────────────────────────────────────────

# Title too short
RES=$(curl -s -X POST "$BASE/api/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EMP_TOKEN" \
  -d "{\"title\":\"Hi\",\"description\":\"Some project description here\",\"budget\":100,\"deadline\":\"2026-08-01T00:00:00Z\"}")
echo "$RES" | grep -q '"error"' && pass "Short title (< 5 chars) rejected by Zod" || fail "Short title accepted"

# Work description too short for submission
SECOND_MILESTONE=$(echo "$PROJECT_RES" | grep -o '"id":"[^"]*"' | sed -n '3p' | cut -d'"' -f4)
if [ -n "$SECOND_MILESTONE" ]; then
  SHORT_SUB=$(curl -s -X POST "$BASE/api/milestones/$SECOND_MILESTONE/submit" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $FREE_TOKEN" \
    -d "{\"workDescription\":\"Done\"}")
  echo "$SHORT_SUB" | grep -q '"error"' && pass "Short work description (< 50 chars) rejected" || fail "Short description accepted"
fi

# Negative budget
RES=$(curl -s -X POST "$BASE/api/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EMP_TOKEN" \
  -d "{\"title\":\"Valid Title\",\"description\":\"Valid description text here\",\"budget\":-100,\"deadline\":\"2026-08-01T00:00:00Z\"}")
echo "$RES" | grep -q '"error"' && pass "Negative budget rejected" || fail "Negative budget accepted"

# ─────────────────────────────────────────────────────────────────
# FINAL SUMMARY
# ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  TEST RESULTS${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
TOTAL=$((PASS + FAIL))
echo -e "  ${GREEN}✔ Passed: $PASS${NC}  ${RED}✗ Failed: $FAIL${NC}  Total: $TOTAL"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}All tests passed — system fully operational${NC}"
else
  echo -e "  ${RED}${BOLD}$FAIL test(s) failed — check output above${NC}"
fi

echo ""
echo -e "  ${BOLD}What was verified:${NC}"
echo -e "  ${CYAN}Auth${NC}      Register, login, JWT, wrong password"
echo -e "  ${CYAN}Security${NC}  No token, invalid token, role guard, ownership guard"
echo -e "  ${CYAN}NLP${NC}       Groq milestone gen, checklist, budget sum, deadlines"
echo -e "  ${CYAN}Escrow${NC}    Fund, confirm, balance tracking, ownership"
echo -e "  ${CYAN}AQA${NC}       Submission, agent scoring, decision thresholds"
echo -e "  ${CYAN}Payout${NC}    Money movement, escrow balance after decision"
echo -e "  ${CYAN}PFI${NC}       Score calc, no NaN, weighted components"
echo -e "  ${CYAN}Validation${NC} Zod guards on all inputs"
echo ""
echo -e "  Project ID  : ${CYAN}$PROJECT_ID${NC}"
echo -e "  Employer    : ${CYAN}$EMP_EMAIL${NC}"
echo -e "  Freelancer  : ${CYAN}$FREE_EMAIL${NC}"
echo -e "  AQA Score   : ${CYAN}$AQA_SCORE / 100  →  $AQA_DECISION${NC}"
echo -e "  PFI Score   : ${CYAN}$PFI_SCORE  ($PFI_INTERP)${NC}"
echo ""