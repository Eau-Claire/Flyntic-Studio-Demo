import { ThreeScene } from './threeScene.js';
import { DragInteraction } from './dragInteraction.js';

// Global state
let threeScene;
let dragInteraction;
let placedComponents = {};

document.addEventListener('DOMContentLoaded', () => {
    // Hide standard 2D canvas overlay
    const gridOverlay = document.getElementById('gridOverlay');
    if (gridOverlay) gridOverlay.style.display = 'none';

    // Initialize Three.js scene
    threeScene = new ThreeScene('assemblyCanvas');

    // Animation loop
    function animate() {
        requestAnimationFrame(animate);
        threeScene.render();
    }
    animate();

    // Setup 3D drag interactions
    dragInteraction = new DragInteraction(
        threeScene,
        handleComponentAdded,
        handleComponentMoved,
        handleComponentSelected
    );

    // Initial load of existing components from server
    if (window.placedComponents) {
        window.placedComponents.forEach(comp => {
            const mesh = threeScene.addComponent(comp);
            placedComponents[comp.instanceId] = comp;
        });
        if (window.updateMonitors) window.updateMonitors();
    }

    // Initialize Left Panel Drag and Drop (HTML -> 3D)
    initLeftPanelDraggables();
});

function initLeftPanelDraggables() {
    const items = document.querySelectorAll('.component-item');

    items.forEach(item => {
        item.addEventListener('dragstart', (e) => {
            const compData = {
                id: item.dataset.componentId,
                name: item.dataset.componentName,
                type: item.dataset.componentType,
                width: parseInt(item.dataset.componentWidth),
                height: parseInt(item.dataset.componentHeight)
            };

            // Generate a temporary instance ID for drag visualization
            compData.instanceId = 'temp_' + Date.now();

            e.dataTransfer.setData('application/json', JSON.stringify(compData));
            e.dataTransfer.effectAllowed = 'copy';
        });
    });
}

async function handleComponentAdded(data) {
    try {
        // Remove temp ID if any, Backend expects PlaceComponentRequest
        const requestPayload = {
            componentId: data.id,
            x: data.x,
            y: 0,
            z: data.z
        };

        const response = await axios.post('/api/drone/place', requestPayload);
        const newComp = response.data;

        // Add component to 3D scene
        const componentData = {
            instanceId: newComp.instanceId,
            type: newComp.type,
            x: newComp.x,
            y: newComp.y,
            z: newComp.z
        };

        // If it's a battery or motor, adjust vertical position based on frame
        if (componentData.type === 'Battery') {
            componentData.y = 1.15;
        } else if (componentData.type === 'Motor') {
            componentData.y = 0.3;
        } else {
            componentData.y = 0.5; // Frame
        }

        threeScene.addComponent(componentData);
        placedComponents[newComp.instanceId] = newComp;

        // Hook into existing Application Logic
        if (window.addToHierarchy) {
            window.addToHierarchy(newComp.instanceId, newComp.name, newComp.type);
        }
        if (window.updateMonitors) {
            window.updateMonitors();
        }
        if (window.updateComponentCount) {
            window.updateComponentCount();
        }

    } catch (error) {
        console.error('Error placing component:', error);
        alert('Failed to place component.');
    }
}

async function handleComponentMoved(instanceId, x, y, z) {
    if (!instanceId || instanceId.startsWith('temp_')) return;

    try {
        const payload = {
            instanceId: instanceId,
            x: Math.round(x),
            y: Math.round(y), // Optional: clamp based on type
            z: Math.round(z),
            rotation: 0,
            isSelected: true
        };

        await axios.put('/api/drone/update', payload);
        placedComponents[instanceId].x = payload.x;
        placedComponents[instanceId].z = payload.z;
    } catch (error) {
        console.error('Error moving component', error);
    }
}

function handleComponentSelected(instanceId) {
    if (window.Studio) {
        window.Studio.selectedComponent = instanceId;
        window.Studio.selectedComponents = instanceId ? [instanceId] : [];
    }
}

// Override deleteSelected globally so it deletes from ThreeJS as well
const originalDeleteSelected = window.deleteSelected;
window.deleteSelected = async function () {
    const toDelete = window.Studio?.selectedComponents.length > 0
        ? [...window.Studio.selectedComponents]
        : (window.Studio?.selectedComponent ? [window.Studio.selectedComponent] : []);

    if (originalDeleteSelected) {
        await originalDeleteSelected();
    }

    // Also remove from ThreeJS
    if (toDelete && toDelete.length > 0) {
        toDelete.forEach(id => {
            if (window.threeScene) window.threeScene.removeComponent(id);
            if (placedComponents[id]) delete placedComponents[id];

            if (dragInteraction && dragInteraction.transformControls.object?.userData?.id === id) {
                dragInteraction.transformControls.detach();
                dragInteraction.highlightBox.visible = false;
            }
        });
    }
}
