const express = require("express");
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const app = express();

// Servir les fichiers statiques
app.use(express.static(__dirname));

// Fonction pour récupérer la liste des projets
function getProjects() {
  const projects = [];
  const dir = path.join(__dirname);

  try {
    const files = fs.readdirSync(dir);
    for (const file of files) {
      const filePath = path.join(dir, file);
      const stats = fs.statSync(filePath);

      // Vérifier si c'est un dossier et qu'il contient un fichier index.html
      if (stats.isDirectory() && file !== "admin" && file !== "node_modules") {
        const indexFile = path.join(filePath, "index.html");
        if (fs.existsSync(indexFile)) {
          projects.push({
            name: file,
            title: file.replace(".local", ""),
          });
        }
      }
    }
  } catch (error) {
    console.error("Erreur lors de la lecture des dossiers:", error);
  }

  return projects;
}

// Fonction pour exécuter un script
function executeScript(scriptPath) {
  return new Promise((resolve, reject) => {
    try {
      // Normaliser le chemin du script
      const fullPath = path.join(__dirname, scriptPath);
      
      // Vérifier si le fichier existe
      if (!fs.existsSync(fullPath)) {
        return reject(new Error(`Script non trouvé: ${scriptPath}`));
      }

      // Déterminer le type de script
      const ext = path.extname(fullPath).toLowerCase();
      let command;
      
      switch (ext) {
        case '.js':
          command = spawn('node', [fullPath]);
          break;
        case '.sh':
          command = spawn('bash', [fullPath]);
          break;
        case '.bat':
          command = spawn('cmd', ['/c', fullPath]);
          break;
        default:
          return reject(new Error(`Type de script non supporté: ${ext}`));
      }

      // Gérer les sorties
      const output = [];
      command.stdout.on('data', (data) => {
        output.push(data.toString());
      });

      command.stderr.on('data', (data) => {
        output.push(data.toString());
      });

      command.on('close', (code) => {
        if (code === 0) {
          resolve({ success: true, output: output.join('') });
        } else {
          reject(new Error(`Erreur lors de l'exécution du script: ${output.join('')}`));
        }
      });

    } catch (error) {
      reject(error);
    }
  });
}

// Route pour exécuter un script
app.post('/api/run-script', express.json(), async (req, res) => {
  try {
    const { script } = req.body;
    if (!script) {
      return res.status(400).json({ error: 'Chemin du script requis' });
    }

    const result = await executeScript(script);
    res.json(result);
  } catch (error) {
    console.error('Erreur lors de l\'exécution du script:', error);
    res.status(500).json({ error: error.message });
  }
});

// Route pour récupérer la liste des projets
app.get("/api/projects", (req, res) => {
  res.json(getProjects());
});

const PORT = 3001;
app.listen(PORT, () => {
  console.log(`Serveur démarré sur le port ${PORT}`);
});
