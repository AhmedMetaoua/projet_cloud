# 🚀 Deploy Angular App to AWS EC2 (Amazon Linux)

This guide explains how to deploy this Angular application on an AWS EC2 instance. The app will be built locally and deployed using EC2 **User Data**.

---

## 🧰 Step 1: Set Up and Test the App Locally

1. **Install Node.js and npm**  
   Download and install from [https://nodejs.org/](https://nodejs.org/)

2. **Install Angular CLI**  
   ```bash
   npm install -g @angular/cli
   ```

3. **Clone your Angular project**  
   ```bash
   git clone https://github.com/alaabenhmida/client.git
   cd client
   npm install
   ```

4. **Update the API URL for local testing**  
   Edit `src/app/services/user.service.ts`:

   ```ts
   private apiUrl = 'http://localhost:3000';
   ```

5. **Run and test the app locally**  
   ```bash
   ng serve
   ```

   Open [http://localhost:4200](http://localhost:4200) and verify everything works properly.

---

## ✍️ Step 2: Personalize the App

Before building for production:

- **Change the page title to your name**  
  Edit `src/app/app.component.html`:

  ```html
  <h1>YOUR NAME</h1>
  ```

---

## 🔧 Step 3: Prepare for Production

1. **Update the API URL for production**  
   Edit `src/app/services/user.service.ts`:

   ```ts
   private apiUrl = 'https://your-production-backend.com';
   ```

2. **Build the app**  
   ```bash
   ng build --configuration production
   ```

   > 📂 After running the build command, the production-ready code will be generated inside the `dist/` folder.

---

## 🔄 Step 4: Push the `dist/` Folder to Your GitHub Repo

> 💡 If you don't have a GitHub repository yet, create one first at [github.com](https://github.com)

1. **Move into the production build folder**  
   ```bash
   cd dist/client
   ```

2. **Initialize Git and push**  
   ```bash
   git init
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
   git add .
   git commit -m "Push production build"
   git branch -M main
   git push -u origin main
   ```

👉 Now your GitHub repository contains **only the production-ready code**.

---

## ☁️ Step 5: Launch an EC2 Instance (Amazon Linux 2)

1. Go to the [AWS EC2 Console](https://console.aws.amazon.com/ec2/)
2. Click **Launch Instance**
3. Configure:
   - **AMI**: Amazon Linux 2 (64-bit)
   - **Instance Type**: `t2.micro`
   - **Key Pair**: Select or create one
   - **Security Group**: Allow:
     - **Port 22** (SSH)
     - **Port 80** (HTTP)
4. Expand **Advanced details** → **User Data** section
5. Paste the script below into **User Data**

---

## ⚙️ Step 6: EC2 User Data Script (for Amazon Linux 2)

```bash
#!/bin/bash
# Update system
sudo yum update -y

# Install Nginx and Git
sudo yum install -y nginx git

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Remove default nginx files
sudo rm -rf /usr/share/nginx/html/*

# Clone your GitHub repo
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Move built Angular files to nginx directory
sudo mv YOUR_REPO/browser/* /usr/share/nginx/html/

# Reload Nginx
sudo systemctl restart nginx

```

> 🔁 Replace `YOUR_USERNAME` and `YOUR_REPO` with your actual GitHub username and repository name.

---

## 🌐 Step 7: Access the Deployed App

Once your EC2 instance is running, open your browser and visit:

```
http://<your-ec2-public-ip>
```

🎉 Your personalized Angular app is now live and accessible!

---

## ⚡ Quick Recap

- Test the app locally
- Personalize the title
- Build for production
- Push only the `dist/` folder to GitHub
- Deploy on Amazon Linux EC2 instance

---

