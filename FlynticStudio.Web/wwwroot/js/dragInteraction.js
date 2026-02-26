import * as THREE from 'three';
import { TransformControls } from 'three/addons/controls/TransformControls.js';

export class DragInteraction {
    constructor(threeScene, onComponentAdded, onComponentMoved, onComponentSelected) {
        this.threeScene = threeScene;
        this.camera = threeScene.camera;
        this.renderer = threeScene.renderer;
        this.scene = threeScene.scene;

        this.onComponentAdded = onComponentAdded;
        this.onComponentMoved = onComponentMoved;
        this.onComponentSelected = onComponentSelected;

        this.raycaster = new THREE.Raycaster();
        this.mouse = new THREE.Vector2();

        this.plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
        this.intersection = new THREE.Vector3();

        // Highlight material
        this.highlightBox = new THREE.BoxHelper();
        this.highlightBox.material.color.setHex(0x00ffcc);
        this.highlightBox.visible = false;
        this.scene.add(this.highlightBox);

        // Transform Controls for XYZ movement
        this.transformControls = new TransformControls(this.camera, this.renderer.domElement);
        this.transformControls.addEventListener('dragging-changed', (event) => {
            this.threeScene.controls.enabled = !event.value;
            // When user releases the drag handle, broadcast the new position!
            if (!event.value && this.transformControls.object) {
                const obj = this.transformControls.object;
                if (this.onComponentMoved) {
                    this.onComponentMoved(obj.userData.id, obj.position.x, obj.position.y, obj.position.z);
                }
            }
        });

        // Listen to object change to update highlight box smoothly during dragging
        this.transformControls.addEventListener('change', () => {
            if (this.transformControls.object) {
                this.highlightBox.update();
            }
        });

        this.scene.add(this.transformControls);

        this.initEvents();
    }

    initEvents() {
        const dom = this.renderer.domElement;

        // Click to select/deselect
        dom.addEventListener('pointerdown', this.onPointerDown.bind(this));

        // HTML drag and drop into 3D scene
        dom.addEventListener('dragover', this.onDragOver.bind(this));
        dom.addEventListener('drop', this.onDrop.bind(this));
    }

    onPointerDown(event) {
        // If it's a right click or we are clicking exactly on the TransformControls gizmo, do nothing
        if (event.button !== 0 || this.transformControls.dragging) return;

        event.preventDefault();
        this.updateMouse(event);
        this.raycaster.setFromCamera(this.mouse, this.camera);

        const intersects = this.raycaster.intersectObjects(this.threeScene.componentsGroup.children, true);

        if (intersects.length > 0) {
            // Find root group element
            let object = intersects[0].object;
            while (object.parent && object.parent !== this.threeScene.componentsGroup) {
                object = object.parent;
            }

            this.transformControls.attach(object);

            // Selection Highlight
            this.highlightBox.setFromObject(object);
            this.highlightBox.visible = true;

            if (this.onComponentSelected) {
                this.onComponentSelected(object.userData.id);
            }
        } else {
            this.transformControls.detach();
            this.highlightBox.visible = false;
            if (this.onComponentSelected) {
                this.onComponentSelected(null);
            }
        }
    }

    updateMouse(event) {
        const rect = this.renderer.domElement.getBoundingClientRect();
        this.mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
        this.mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
    }

    planeRaycast() {
        this.raycaster.setFromCamera(this.mouse, this.camera);
        if (this.raycaster.ray.intersectPlane(this.plane, this.intersection)) {
            return true;
        }
        return false;
    }

    onDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
    }

    onDrop(event) {
        event.preventDefault();
        this.updateMouse(event);

        let dataStr = event.dataTransfer.getData('application/json');
        if (!dataStr) {
            dataStr = event.dataTransfer.getData('text/plain');
        }

        if (!dataStr) return;

        try {
            const data = JSON.parse(dataStr);
            if (this.planeRaycast()) {
                data.x = Math.round(this.intersection.x);
                data.z = Math.round(this.intersection.z);

                if (this.onComponentAdded) {
                    this.onComponentAdded(data);
                }
            }
        } catch (e) {
            console.error("Drop Parse error", e);
        }
    }
}
