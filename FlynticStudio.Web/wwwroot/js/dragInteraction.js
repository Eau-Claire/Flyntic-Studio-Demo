import * as THREE from 'three';

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

        this.draggedMesh = null;
        this.plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
        this.intersection = new THREE.Vector3();
        this.offset = new THREE.Vector3();

        // Highlight material
        this.highlightBox = new THREE.BoxHelper();
        this.highlightBox.material.color.setHex(0x4fc3f7);
        this.highlightBox.visible = false;
        this.scene.add(this.highlightBox);

        this.initEvents();
    }

    initEvents() {
        const dom = this.renderer.domElement;

        // 3D dragging
        dom.addEventListener('pointerdown', this.onPointerDown.bind(this));
        dom.addEventListener('pointermove', this.onPointerMove.bind(this));
        dom.addEventListener('pointerup', this.onPointerUp.bind(this));

        // HTML drag and drop into 3D scene
        dom.addEventListener('dragover', this.onDragOver.bind(this));
        dom.addEventListener('drop', this.onDrop.bind(this));
    }

    onPointerDown(event) {
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

            this.threeScene.controls.enabled = false;
            this.draggedMesh = object;

            if (this.planeRaycast()) {
                this.offset.copy(this.intersection).sub(object.position);
            }

            // Selection Highlight
            this.highlightBox.setFromObject(this.draggedMesh);
            this.highlightBox.visible = true;

            if (this.onComponentSelected) {
                this.onComponentSelected(object.userData.id);
            }
        } else {
            this.highlightBox.visible = false;
            if (this.onComponentSelected) {
                this.onComponentSelected(null);
            }
        }
    }

    onPointerMove(event) {
        event.preventDefault();
        this.updateMouse(event);

        if (this.draggedMesh) {
            if (this.planeRaycast()) {
                const targetX = Math.round(this.intersection.x - this.offset.x);
                const targetZ = Math.round(this.intersection.z - this.offset.z);

                this.draggedMesh.position.x = targetX;
                this.draggedMesh.position.z = targetZ;

                this.highlightBox.setFromObject(this.draggedMesh);
            }
        }
    }

    onPointerUp(event) {
        event.preventDefault();
        this.threeScene.controls.enabled = true;

        if (this.draggedMesh) {
            if (this.onComponentMoved) {
                this.onComponentMoved(
                    this.draggedMesh.userData.id,
                    this.draggedMesh.position.x,
                    this.draggedMesh.position.y,
                    this.draggedMesh.position.z
                );
            }
            this.draggedMesh = null;
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
