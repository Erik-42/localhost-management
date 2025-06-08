// Mise à jour automatique de l'année dans le footer
document.getElementById("current-year").textContent = new Date().getFullYear();

// Fonction pour récupérer la liste des projets
async function fetchProjects() {
    try {
        const response = await fetch('http://localhost:3001/api/projects');
        if (!response.ok) {
            throw new Error('Erreur lors de la récupération des projets');
        }
        return await response.json();
    } catch (error) {
        console.error('Erreur lors de la récupération des projets:', error);
        throw error;
    }
}

// Fonction pour exécuter un script
async function runScript(scriptPath) {
    try {
        const response = await fetch('http://localhost:3000/api/run-script', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ script: scriptPath }),
        });

        const result = await response.json();
        
        if (result.success) {
            alert('Script exécuté avec succès:\n' + result.output);
        } else {
            alert('Erreur lors de l\'exécution du script:\n' + result.error);
        }
    } catch (error) {
        console.error('Erreur lors de l\'exécution du script:', error);
        alert('Erreur lors de l\'exécution du script');
    }
}

// Fonction pour mettre à jour la liste des projets locaux
async function updateProjectsList() {
    try {
        // Récupérer la liste des projets depuis le serveur
        const projects = await fetchProjects();

        // Trouver la section Projets locaux
        const projectsSection = document.querySelector('#projects-list');
        if (!projectsSection) {
            console.error('Section Projets locaux non trouvée');
            return;
        }

        // Trouver l'élément ul existant ou en créer un nouveau
        let ul = projectsSection.querySelector('ul');
        if (!ul) {
            ul = document.createElement('ul');
            projectsSection.appendChild(ul);
        }

        // Nettoyer les éléments existants
        ul.innerHTML = '';

        // Créer les éléments de la liste
        projects.forEach(project => {
            const li = document.createElement('li');
            const fileDiv = document.createElement('div');
            fileDiv.className = 'file';
            
            const a = document.createElement('a');
            a.href = `./${project.name}/index.html`;
            a.textContent = project.title;
            
            fileDiv.appendChild(a);
            li.appendChild(fileDiv);
            ul.appendChild(li);
        });
    } catch (error) {
        console.error('Erreur lors de la mise à jour des projets:', error);
        // Afficher un message d'erreur dans la section Projets locaux
        const projectsSection = document.querySelector('#projects-list');
        if (projectsSection) {
            const errorDiv = document.createElement('div');
            errorDiv.style.color = 'red';
            errorDiv.textContent = 'Erreur lors de la mise à jour des projets';
            projectsSection.appendChild(errorDiv);
        }
    }
}

// Ajouter les gestionnaires d'événements pour les boutons de scripts
document.addEventListener('DOMContentLoaded', () => {
    const scriptButtons = document.querySelectorAll('.run-script');
    scriptButtons.forEach(button => {
        button.addEventListener('click', () => {
            const scriptPath = button.getAttribute('data-script');
            runScript(scriptPath);
        });
    });
});

// Mettre à jour la liste des projets au chargement de la page
window.addEventListener('load', updateProjectsList);
