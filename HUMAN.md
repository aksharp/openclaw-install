# Actually what I am doing to get this thing installed...

### Step 1: Install all the software on host and got Signal account from README.md
### Step 2: prerequisites.yaml - copy file, not much changes there, might add it to git repo as an example
### Step 3: kind create cluster stuff
### Step 4: helm dependency update ./helm/openclaw && helm upgrade --install openclaw ./helm/openclaw -f ./helm/openclaw/prerequisites.yaml -n openclaw --create-namespace




