# AWS Sandbox Deployment Checklist

## Pre-Deployment

- [ ] AWS Sandbox credentials configured (`aws configure` or `AWS_ACCESS_KEY_ID` env vars)
- [ ] Terraform installed (v1.0+)
- [ ] SSH key pair created: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/projet-cloud-key`
- [ ] Public key added to terraform.tfvars: `cat ~/.ssh/projet-cloud-key.pub`
- [ ] Your public IP set in terraform.tfvars: `curl ifconfig.me` → add `/32` suffix
- [ ] GitHub repo URL is correct and has HTTPS access (no auth needed for public repo)
- [ ] All changes committed to GitHub and pushed (terraform scripts clone from GitHub)

## Terraform Deployment

### Step 1: Initialize
```bash
cd terraform/
terraform init
```
**Check**: No errors about missing AWS credentials

### Step 2: Validate & Plan
```bash
terraform validate
terraform plan -out=tfplan
```
**Check**: 
- Shows ~20 resources to be created
- No validation errors
- Correct variables (region, db password, etc.)

### Step 3: Apply
```bash
terraform apply tfplan
```
**Check**:
- Waits ~15-20 minutes for RDS to be ready
- Output shows: `alb_dns_name`, `frontend_url`, `rds_endpoint`, `ssh_frontend`
- No error messages about security groups or IAM

## Post-Deployment Verification

### Step 1: Test Frontend
```bash
# Get frontend URL from terraform output
FRONTEND_IP=<from terraform output>
curl http://$FRONTEND_IP
```
**Expect**: HTML page loads (check browser too)

### Step 2: Test Backend API
```bash
# Get ALB DNS from terraform output
ALB_DNS=<from terraform output>

# Test health check
curl http://$ALB_DNS/health

# Test list users
curl http://$ALB_DNS/api/users

# Test create user
curl -X POST http://$ALB_DNS/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'
```
**Expect**: 200 OK responses, JSON payloads

### Step 3: Check Backend Instance Logs
```bash
# SSH into frontend
ssh -i ~/.ssh/projet-cloud-key ubuntu@$FRONTEND_IP

# From frontend, SSH into backend (private)
ssh -i /path/to/key ubuntu@<backend-private-ip>

# View backend logs
tail -f /home/ubuntu/.pm2/logs/backend-out.log
tail -f /home/ubuntu/.pm2/logs/backend-error.log

# Check PM2 status
pm2 status
```

### Step 4: Test Database Connection
```bash
# From backend instance, verify MySQL is reachable
mysql -h $DB_HOST -u admin -p'123456789' appdb -e "SELECT * FROM users;"
```

### Step 5: Browser Test (Full Integration)
1. Open frontend URL in browser
2. Verify Angular app loads
3. Click "List Users" → should see 3 users
4. Try adding a new user
5. Verify it appears in the list
6. Try editing/deleting

## Troubleshooting

### Frontend shows blank page / API calls fail
- [ ] Check browser console for CORS errors
- [ ] Verify frontend was built correctly: check /var/www/html/ contains index.html
- [ ] Verify config.js exists with correct ALB DNS
- [ ] Check nginx status: `sudo systemctl status nginx`

### Backend health check failing (ALB shows unhealthy)
- [ ] Check backend logs for database connection errors
- [ ] Verify database RDS endpoint in EC2 .env: `curl http://backend-ip:3000/health`
- [ ] Check security group: does RDS SG allow backend SG?

### Cannot access backend via ALB DNS
- [ ] Verify ALB listener is active: `aws elbv2 describe-listeners`
- [ ] Check target group: are backend instances registered?
- [ ] Try accessing backend directly: `curl http://backend-private-ip:3000/health`

### Database won't initialize
- [ ] Check RDS status in AWS console (should be "available")
- [ ] Verify RDS is in private subnets (check VPC configuration)
- [ ] Check RDS security group allows inbound on 3306 from backend SG
- [ ] Test connection from backend manually with mysql-client

### PM2 not starting backend
- [ ] SSH into instance and check Node.js: `node --version`
- [ ] Check npm install succeeded: `ls -la /home/ubuntu/app/backend/node_modules`
- [ ] Check .env file exists: `cat /home/ubuntu/app/backend/.env`
- [ ] Try starting manually: `cd /home/ubuntu/app/backend && npm start`

### Cost concerns
- [ ] Check AWS Free Tier status (t2.micro, 20GB storage, 750hrs/month free)
- [ ] Use `terraform destroy` to stop all resources when not in use
- [ ] Monitor RDS daily active connections (should be 2-4)

## Security Notes for Sandbox

⚠️ **These are NOT production-safe but OK for sandbox:**
- [ ] SSH key stored in .ssh/ (should be in secret manager)
- [ ] RDS password in terraform.tfvars (should be AWS Secrets Manager)
- [ ] CORS allows '*' (should restrict to frontend domain)
- [ ] No HTTPS (should use ACM certificate in production)
- [ ] Backend SSH rule removed ✓

## Cleanup

When done, destroy all resources to avoid costs:
```bash
terraform destroy
```

**Verify**: All EC2, RDS, ALB, VPC resources are gone
