## GitHub (or GitLab) setup

### Create remote repository
- Create a new repo named `VaultGuard` (Private recommended).
- Do **not** add README/.gitignore on the remote (we already have local files).

### Connect local repo to remote
Run from `C:\Users\pc\AndroidStudioProjects\VaultGuard`:

```bash
git remote add origin https://github.com/YOUR_USERNAME/VaultGuard.git
git branch -M main
git push -u origin main
```

### Recommended branch model
- `main`: protected, release-ready
- `develop`: integration
- `feature/*`: feature branches

