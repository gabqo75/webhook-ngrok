#!/usr/bin/env bas
set -euo pipefail

: "${REPO_URL:?Missing REPO_URL}"
: "${DEPLOY_DIR:?Missing DEPLOY_DIR}"
: "${TARGET_BRANCH:=main}"

echo "== Deploy started =="
echo "Repo: $REPO_URL"
echo "Dir:  $DEPLOY_DIR"
echo "Branch: $TARGET_BRANCH"

# 1. Clonage ou mise à jour du dépôt
if [ ! -d "$DEPLOY_DIR/.git" ]; then
    echo "Cloning..."
    git clone --branch "$TARGET_BRANCH" "$REPO_URL" "$DEPLOY_DIR"
else
    echo "Pulling latest..."
    git -C "$DEPLOY_DIR" fetch --all
    git -C "$DEPLOY_DIR" checkout "$TARGET_BRANCH"
    git -C "$DEPLOY_DIR" pull --ff-only
fi

# 2. Installation des dépendances
echo "Installing dependencies..."
cd "$DEPLOY_DIR"
npm install

# 3. Arrêt de l'ancienne version (pour libérer le port)
echo "Stopping previous app (best-effort)..."
# Tue les processus sur les ports standards de React/Vite
lsof -ti :5173 | xargs kill -9 2>/dev/null || true
lsof -ti :3000 | xargs kill -9 2>/dev/null || true
sleep 2

# 4. Lancement de l'application en arrière-plan
echo "Starting app..."
# On vérifie quel script est disponible dans le package.json
if npm run | grep -qE ' start'; then
    # nohup et & permettent de garder l'app allumée après la fermeture du script
    nohup npm run start -- --host 0.0.0.0 > app.log 2>&1 &
    echo "Started with: npm run start"
elif npm run | grep -qE ' dev'; then
    nohup npm run dev -- --host 0.0.0.0 > app.log 2>&1 &
    echo "Started with: npm run dev"
else
    echo "No start/dev script found in package.json"
    exit 1
fi

echo "== Deploy done =="
