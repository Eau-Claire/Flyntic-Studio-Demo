import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

export class ThreeScene {
    constructor(containerId) {
        this.container = document.getElementById(containerId);

        // Clear anything currently inside.
        this.container.innerHTML = "";

        this.scene = new THREE.Scene();
        this.scene.background = new THREE.Color(0x2a2a35);

        this.camera = new THREE.PerspectiveCamera(45, this.container.clientWidth / this.container.clientHeight, 0.1, 1000);
        this.camera.position.set(10, 10, 10);

        this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
        this.renderer.setSize(this.container.clientWidth, this.container.clientHeight);
        this.renderer.setPixelRatio(window.devicePixelRatio);
        this.renderer.shadowMap.enabled = true;
        this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

        // Style renderer dom to fill exactly
        this.renderer.domElement.style.width = "100%";
        this.renderer.domElement.style.height = "100%";
        this.renderer.domElement.style.position = "absolute";
        this.renderer.domElement.style.top = "0";
        this.renderer.domElement.style.left = "0";
        this.container.appendChild(this.renderer.domElement);

        this.controls = new OrbitControls(this.camera, this.renderer.domElement);
        this.controls.enableDamping = true;
        this.controls.dampingFactor = 0.05;

        this.setupLights();
        this.setupGrid();

        // Handle resize
        window.addEventListener('resize', this.onWindowResize.bind(this));

        // Components group
        this.componentsGroup = new THREE.Group();
        this.scene.add(this.componentsGroup);

        this.meshes = {};
    }

    setupLights() {
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
        this.scene.add(ambientLight);

        const dirLight = new THREE.DirectionalLight(0xffffff, 0.8);
        dirLight.position.set(20, 40, 20);
        dirLight.castShadow = true;
        dirLight.shadow.mapSize.width = 2048;
        dirLight.shadow.mapSize.height = 2048;
        this.scene.add(dirLight);
    }

    setupGrid() {
        // A lighter gray grid
        const gridHelper = new THREE.GridHelper(20, 20, 0x888888, 0x444444);
        gridHelper.position.y = 0.01;
        this.scene.add(gridHelper);

        // Floor plane to receive shadows
        const planeGeometry = new THREE.PlaneGeometry(20, 20);
        const planeMaterial = new THREE.MeshStandardMaterial({
            color: 0x30303e,
            depthWrite: false
        });
        const plane = new THREE.Mesh(planeGeometry, planeMaterial);
        plane.rotation.x = -Math.PI / 2;
        plane.receiveShadow = true;
        this.scene.add(plane);
        this.floor = plane; // Save reference for raycasting

        // XYZ Axes Helper
        const axesHelper = new THREE.AxesHelper(10);
        axesHelper.position.y = 0.02;
        this.scene.add(axesHelper);
    }

    createNeonMesh(geometry, colorHex) {
        const group = new THREE.Group();

        // Inner translucent solid
        const solidMat = new THREE.MeshStandardMaterial({
            color: colorHex,
            transparent: true,
            opacity: 0.15,
            depthWrite: false
        });
        const mesh = new THREE.Mesh(geometry, solidMat);
        group.add(mesh);

        // Glowing wire edges
        const edges = new THREE.EdgesGeometry(geometry);
        const lineMat = new THREE.LineBasicMaterial({ color: colorHex });
        const line = new THREE.LineSegments(edges, lineMat);
        group.add(line);

        return group;
    }

    onWindowResize() {
        if (!this.container) return;
        this.camera.aspect = this.container.clientWidth / this.container.clientHeight;
        this.camera.updateProjectionMatrix();
        this.renderer.setSize(this.container.clientWidth, this.container.clientHeight);
    }

    render() {
        this.controls.update();
        this.renderer.render(this.scene, this.camera);
    }

    createDroneFrame(id) {
        const group = new THREE.Group();
        group.name = id;
        group.userData = { id, type: 'Frame' };

        // Center body
        const centerGeometry = new THREE.BoxGeometry(2, 0.5, 2);
        const center = this.createNeonMesh(centerGeometry, 0x00ffff); // Cyan
        center.position.y = 0.5; // Lift up slightly
        group.add(center);

        // Arms (X shape)
        const armGeometry = new THREE.BoxGeometry(8, 0.2, 0.5);

        const arm1 = this.createNeonMesh(armGeometry, 0x00ffff);
        arm1.rotation.y = Math.PI / 4;
        arm1.position.y = 0.5;
        group.add(arm1);

        const arm2 = this.createNeonMesh(armGeometry, 0x00ffff);
        arm2.rotation.y = -Math.PI / 4;
        arm2.position.y = 0.5;
        group.add(arm2);

        return group;
    }

    createMotor(id) {
        const group = new THREE.Group();
        group.name = id;
        group.userData = { id, type: 'Motor' };

        // Motor base
        const baseGeom = new THREE.CylinderGeometry(0.4, 0.4, 0.6, 16);
        const motor = this.createNeonMesh(baseGeom, 0xff5500); // Orange neon
        motor.position.y = 0.3;
        group.add(motor);

        // Propeller
        const propGeom = new THREE.BoxGeometry(3, 0.05, 0.3);
        const prop = this.createNeonMesh(propGeom, 0xffaa00); // Yellow neon
        prop.position.y = 0.65;
        prop.name = "propeller";
        group.add(prop);

        // Add snapping offsets (motors typically go on the end of the arms)
        // This is handled by user dragging for now
        return group;
    }

    createBattery(id) {
        const group = new THREE.Group();
        group.name = id;
        group.userData = { id, type: 'Battery' };

        const geom = new THREE.BoxGeometry(1.5, 0.8, 3);
        const mesh = this.createNeonMesh(geom, 0x00ff00); // Neon green
        mesh.position.y = 1.15; // Set it on top of the frame
        group.add(mesh);

        return group;
    }

    addComponent(componentData) {
        let mesh;
        switch (componentData.type) {
            case 'Frame':
                mesh = this.createDroneFrame(componentData.instanceId);
                break;
            case 'Motor':
                mesh = this.createMotor(componentData.instanceId);
                break;
            case 'Battery':
                mesh = this.createBattery(componentData.instanceId);
                break;
            default:
                const geom = new THREE.BoxGeometry(1, 1, 1);
                const mat = new THREE.MeshStandardMaterial({ color: 0xffaa00 });
                mesh = new THREE.Mesh(geom, mat);
                mesh.name = componentData.instanceId;
                mesh.userData = { id: componentData.instanceId, type: componentData.type };
                mesh.position.y = 0.5;
                break;
        }

        mesh.position.set(componentData.x || 0, componentData.y || mesh.position.y, componentData.z || 0);
        this.componentsGroup.add(mesh);
        this.meshes[componentData.instanceId] = mesh;
        return mesh;
    }

    removeComponent(instanceId) {
        const mesh = this.meshes[instanceId];
        if (mesh) {
            this.componentsGroup.remove(mesh);
            delete this.meshes[instanceId];
        }
    }
}
