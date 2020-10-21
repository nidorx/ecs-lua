<div align="center">
    <a href="https://www.npmjs.com/package/ecs-lib">
        <img src="https://badge.fury.io/js/ecs-lib.svg" alt="npm package" title="npm package" />
    </a>    
    <a href="https://travis-ci.org/nidorx/ecs-lib">
        <img src="https://travis-ci.org/nidorx/ecs-lib.svg?branch=master" alt="Build Status" title="Build Status" />
    </a>    
    <a href="https://coveralls.io/github/nidorx/ecs-lib?branch=master">
        <img src="https://coveralls.io/repos/github/nidorx/ecs-lib/badge.svg?branch=master" alt="Coverage Status" />
    </a>
    <br/>    
    <img src="https://github.com/nidorx/ecs-lib/raw/master/logo.jpg" width="882" />
</div>

**ecs-lib** is a tiny and easy to use [ECS _(Entity Component System)_](https://en.wikipedia.org/wiki/Entity_component_system) library for game programming. It's written in Typescript but you can use on node.js an web browser too. 


**TLDR;** Take a look at the [example](https://nidorx.github.io/ecs-lib/) and its [source code](https://github.com/nidorx/ecs-lib/tree/master/example)


```bash
npm install --save ecs-lib
```


## Table of contents
   * [Documentation](#documentation)
      * [World](#world)
      * [Component](#component)
         * [Raw data access](#raw-data-access)
         * [Secondary attributes](#secondary-attributes)
      * [Entity](#entity)
         * [Adding and removing from the world](#adding-and-removing-from-the-world)
         * [Adding and removing components](#adding-and-removing-components)
         * [Subscribing to changes](#subscribing-to-changes)
         * [Accessing components](#accessing-components)
      * [System](#system)
         * [Adding and removing from the world](#adding-and-removing-from-the-world-1)
         * [Limiting frequency (FPS)](#limiting-frequency-fps)
         * [Time Scaling - Slow motion effect](#time-scaling---slow-motion-effect)
             * [Pausing](#pausing)
         * [Global systems - all entities](#global-systems---all-entities)
         * [Before and After update](#before-and-after-update)
         * [Enter - When adding new entities](#enter---when-adding-new-entities)
         * [Change - When you add or remove components](#change---when-you-add-or-remove-components)
         * [Exit - When removing entities](#exit---when-removing-entities)
   * [API](#api)
      * [ECS](#ecs)
      * [Component](#component-1)
         * [Component&lt;T&gt;](#componentt)
      * [Entity](#entity-1)
      * [System](#system-1)
   * [Feedback, Requests and Roadmap](#feedback-requests-and-roadmap)
   * [Contributing](#contributing)
      * [Translating and documenting](#translating-and-documenting)
      * [Reporting Issues](#reporting-issues)
      * [Fixing defects and adding improvements](#fixing-defects-and-adding-improvements)
   * [License](#license)


## Documentation

Entity-Component-System (ECS) is a distributed and compositional architectural design pattern that is mostly used in game development. It enables flexible decoupling of domain-specific behaviour, which overcomes many of the drawbacks of traditional object-oriented inheritance.

For further details:

- [Entity Systems Wiki](http://entity-systems.wikidot.com/)
- [Evolve Your Hierarchy](http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
- [ECS on Wikipedia](https://en.wikipedia.org/wiki/Entity_component_system)
- [Entity Component Systems in Elixir](https://yos.io/2016/09/17/entity-component-systems/)

### World

A ECS instance is used to describe you game world or **Entity System** if you will. The World is a container for Entities, Components, and Systems.

```typescript
import ECS from "ecs-lib";

const world = new ECS();
```


### Component

Represents the different facets of an entity, such as position, velocity, geometry, physics, and hit points for example. Components store only raw data for one aspect of the object, and how it interacts with the world.

In other words, the component labels the entity as having this particular aspect.


```typescript
import {Component} from "ecs-lib";

export type Box = {
    width: number;
    height: number;
    depth: number;
}

export const BoxComponent = Component.register<Box>();
```

The register method generates a new class that represents this type of component, which has a unique identifier. You also have access to the type id from the created instances.

```typescript
const boxCmp = new BoxComponent({ width:10, height:10, depth:10 });

// prints true, in this case type = 1
console.log(BoxComponent.type === boxCmp.type);
```

> You can also have access to the `Component` class from ECS (`ECS.Component.register`)


#### Raw data access

Component instance displays raw data by property `data`

```typescript
boxCmp.data.width = 33;
console.log(boxCmp.data.width);
```

#### Secondary attributes
A component can have attributes. Attributes are secondary values used to save miscellaneous data required by some specialized systems.

```typescript
boxCmp.attr.specializedSystemMetadata = 33;
console.log(boxCmp.attr.specializedSystemMetadata);
```

### Entity

The entity is a general purpose object. An entity is what you use to describe an object in your game. e.g. a player, a gun, etc. It consists only of a unique ID and the list of components that make up this entity.

```typescript
import {Entity} from "ecs-lib";
import {ColorComponent} from "../component/ColorComponent";
import {Box, BoxComponent} from "../component/BoxComponent";

export default class CubeEntity extends Entity {

    constructor(cube: Box, color: string) {
        super();

        this.add(new BoxComponent(cube));
        this.add(new ColorComponent(color));
    }
}
```

> You can also have access to the `Entity` class from ECS (`ECS.Entity`)


#### Adding and removing from the world

You can add multiple instances of the same entity in the world. Each entity is given a **unique identifier** at creation time.

```typescript
const cubeEnt = new CubeEntity({
    width: 10,
    height: 10,
    depth: 10
}, '#FF0000');

console.log(cubeEnt, cubeEnt.id);

world.addEntity(cubeEnt);

world.removeEntity(cubeEnt);
world.removeEntity(cubeEnt.id);
```

#### Adding and removing components 

At any point in the entity's life cycle, you can add or remove components, using `add` and `remove` methods.

```typescript
cubeEnt.add(boxCmp);
cubeEnt.remove(boxCmp);
```

**ecs-lib** entities can have more than one component per type, it is up to the programmer to control the addition and removal of entity components.

```typescript
cubeEnt.add(new BoxComponent({ width:10, height:10, depth:10 }));
cubeEnt.add(new BoxComponent({ width:20, height:20, depth:20 }));
```

#### Subscribing to changes

In **ecs-lib** you can be informed when a component is added or removed from an entity by simply subscribing to the entity.

To unsubscribe, simply invoke the function you received at the time of subscription.

```typescript
const cancel = cubeEnt.subscribe((entity)=>{
    console.log(entity === cubeEnt);
});

cancel();
```

#### Accessing components

To gain access to the components of an entity, simply use the `allFrom` and `oneFrom` methods of the `Component` class to get all or the first instance of this component respectively.

```typescript
BoxComponent.allFrom(cubeEnt)
    .forEach((boxCmp)=>{
        console.log(boxCmp.data.height);
    });

const boxCmp = BoxComponent.oneFrom(cubeEnt);
console.log(boxCmp.data.height);
```


### System

Represents the logic that transforms component data of an entity from its current state to its next state. A system runs on entities that have a specific set of component types.

Each system runs continuously (as if each system had its own thread).

In **ecs-lib**, a system has a strong connection with component types. You must define which components this system works on in the `System` abstract class constructor.

If the `update` method is implemented, it will be invoked for every update in the world. Whenever an entity with the characteristics expected by this system is added or removed on world, or it components is changed, the system is informed via the `enter`, `change` and `exit` methods.

```typescript
import {Entity, System} from "ecs-lib";
import KeyboardState from "../utils/KeyboardState";
import {BoxComponent} from "../component/BoxComponent";
import {Object3DComponent} from "../component/Object3DComponent";

export default class KeyboardSystem extends System {

    constructor() {
        super([
            Object3DComponent.type,
            BoxComponent.type
        ]);
    }

    update(time: number, delta: number, entity: Entity): void {
        let object3D = Object3DComponent.oneFrom(entity).data;
        if (KeyboardState.pressed("right")) {
            object3D.translateX(0.3);
        } else if (KeyboardState.pressed("left")) {
            object3D.translateX(-0.3);
        } else if (KeyboardState.pressed("up")) {
            object3D.translateZ(-0.3);
        } else if (KeyboardState.pressed("down")) {
            object3D.translateZ(0.3);
        }
    }
}
```

#### Adding and removing from the world

To add or remove a system to the world, simply use the `addSystem` and `removeSystem` methods.

```typescript
const keyboardSys = new KeyboardSystem();
world.addSystem(keyboardSys);
world.removeSystem(keyboardSys);
```

#### Limiting frequency (FPS)

It is possible to limit the maximum number of invocations that the `update` method can perform per second (FPS) by simply entering the `frequency` parameter in the class constructor. This control is useful for example to limit the processing of physics systems to a specific frequency in order to decrease the processing cost.

```typescript
export default class PhysicsSystem extends System {

    constructor() {
        super([
            Object3DComponent.type,
            VelocityComponent.type,
            PositionComponent.type,
            DirectionComponent.type
        ], 25);  // <- LIMIT FPS
    }

    // Will run at 25 FPS
    update(time: number, delta: number, entity: Entity): void {
       //... physics stuff
    }
}
```

#### Time Scaling - Slow motion effect

A very interesting feature in **ecs-lib** is the TIMESCALE. This allows you to change the rate that time passes in the game, also known as the timescale. You can set the timescale by changing the `timeScale` property of the world.

A time scale of 1 means normal speed. 0.5 means half the speed and 2.0 means twice the speed. If you set the game's timescale to 0.1, it will be ten times slower but still smooth - a good slow motion effect!

The timescale works by changing the value returned in the `time` and `delta` properties of the system update method. This means that the behaviors are affected and any movement using delta. If you do not use delta in your motion calculations, motion will not be affected by the timescale! Therefore, to use the timescale, simply use the delta correctly in all movements.

> **ATTENTION!** The systems continue to be invoked obeying their normal frequencies, what changes is only the values received in the time and delta parameters.

```typescript
export default class PhysicsSystem extends System {

    constructor() {
        super([
            Object3DComponent.type,
            VelocityComponent.type
        ], 25);
    }

    update(time: number, delta: number, entity: Entity): void {
        let object = Object3DComponent.oneFrom(entity).data;
        let velocity = VelocityComponent.oneFrom(entity).data;
        object.position.y += velocity.y * delta;   
    }
}

world.timeScale = 1; // Normal speed
world.timeScale = 0.5; // Slow motion
```

##### Pausing

You can set the timescale to 0. This stops all movement. It is an easy way to pause the game. Go back to 1 and the game will resume.

You may find that you can still do things like shoot using the game controls. You can get around this by placing your main game events in a group and activating / deactivating that group while pausing and not pausing.

It's also a good way to test if you used delta correctly. If you used it correctly, setting the timescale to 0 will stop everything in the game. If you have not used it correctly, some objects may keep moving even if the game should be paused! In this case, you can check how these objects are moved and make sure you are using delta correctly.

#### Global systems - all entities

You can also create systems that receive updates from all entities, regardless of existing components. To do this, simply enter `[-1]` in the system builder. This functionality may be useful for debugging and other rating mechanisms for your game.

```typescript
import {Entity, System} from "ecs-lib";

export default class LogSystem extends System {

    constructor() {
        super([-1], 0.5); // Logs all entities every 2 seconds (0.5 FPS)
    }

    update(time: number, delta: number, entity: Entity): void {
        console.log(entity);
    }
}
```

#### Before and After update

If necessary, the system can be informed before and after executing the update of its entities in this interaction (respecting the execution frequency defined for that system).

```typescript
import {Entity, System} from "ecs-lib";

export default class LogSystem extends System {

    constructor() {
        super([-1], 0.5); // Logs all entities every 2 seconds (0.5 FPS)
    }

    beforeUpdateAll(time: number): void {
        console.log('Before update');
    }
    
    update(time: number, delta: number, entity: Entity): void {
        console.log(entity);
    }
    
    afterUpdateAll(time: number, entities: Entity[]): void {
        console.log('After update');
    }
}
```


#### Enter - When adding new entities

Invoked when:

 1. An entity with the characteristics (components) expected by this system is added in the world;
 2. This system is added in the world and this world has one or more entities with the characteristics expected by this system; 
 3. An existing entity in the same world receives a new component at runtime and all of its new components match the standard expected by this system.
 
 It can be used for initialization of new components in this entity, or even registration of this entity in a more complex management system.
 
 ```typescript
 import {Entity, System} from "ecs-lib";
 import {BoxGeometry, Mesh, MeshBasicMaterial} from "three";
 import {BoxComponent} from "../component/BoxComponent";
 import {ColorComponent} from "../component/ColorComponent";
 import {Object3DComponent} from "../component/Object3DComponent";
 
 export default class CubeFactorySystem extends System {
 
     constructor() {
         super([
             ColorComponent.type,
             BoxComponent.type
         ]);
     }
     
     enter(entity: Entity): void {
         let object = Object3DComponent.oneFrom(entity);
         if (!object) {
             const box = BoxComponent.oneFrom(entity).data;
             const color = ColorComponent.oneFrom(entity).data;
 
             const geometry = new BoxGeometry(box.width, box.height, box.depth);
             const material = new MeshBasicMaterial({color: color});
             const cube = new Mesh(geometry, material);
 
             // Append new component to entity
             entity.add(new Object3DComponent(cube));
         }
     }
 }
 ```
 
 #### Change - When you add or remove components
 
 A system can also be informed when adding or removing components of an entity by simply implementing the "change" method.
 
 ```typescript
 import {Entity, System, Component} from "ecs-lib";
 
 export default class LogSystem extends System {
 
     constructor() {
         super([-1], 0.5); // Logs all entities every 2 seconds (0.5 FPS)
     }
 
     change(entity: Entity, added?: Component<any>, removed?: Component<any>): void {
         console.log(entity, added, removed);
     }
 }
 ```


#### Exit - When removing entities

Invoked when:
 
 1. An entity with the characteristics (components) expected by this system is removed from the world;
 2. This system is removed from the world and this world has one or more entities with the characteristics expected by this system;
 3. An existing entity in the same world loses a component at runtime and its new component set no longer matches the standard expected by this system;
 
 Can be used to clean memory and references.
 
 ```typescript
import {Scene} from "three";
import {Entity, System} from "ecs-lib";
import {Object3DComponent} from "../component/Object3DComponent";

export default class SceneObjectSystem extends System {

    private scene: Scene;

    constructor(scene: Scene) {
        super([
            Object3DComponent.type
        ]);

        this.scene = scene;
    }

    exit(entity: Entity): void {
        let model = Object3DComponent.oneFrom(entity);
        this.scene.remove(model.data);
    }
}
```

## API

| name | type | description |
|---|---- |:---- | 
| <h3>ECS</h2>   |
| `System` | `System`  | _`static`_ reference to `System` class. _(`ECS.System`)_ |
| `Entity` | `Entity`  | _`static`_ reference to `Entity` class. _(`ECS.Entity`)_ |
| `Component` | `Component`  | _`static`_ reference to `Component` class. _(`ECS.Component`)_ |
| `constructor` | `(systems?: System[])` |  |
| `getEntity(id: number)` | <code>Entity &#124; undefined</code>  | Get an entity by id |
| `addEntity(entity: Entity)` |  | Add an entity to this world |
| <code>removeEntity(entity: number &#124; Entity)</code> |  | Remove an entity from this world |
| `addSystem(system: System)` |  | Add a system in this world |
| `removeSystem(system: System)` |  | Remove a system from this world |
| `update()` |  | Invokes the `update` method of the systems in this world. |
| <h3>Component</h2> |
| `register<T>()` | `Class<Component<T>>`  | _`static`_ Register a new component class |
| <h3>Component&lt;T&gt;</h2> |
| `type` | `number`  | _`static`_ reference to type id |
| `allFrom(entity: Entity)` | `Component<T>[]`  | _`static`_ Get all instances of this component from entity |
| `oneFrom(entity: Entity)` | `Component<T>`  | _`static`_ Get one instance of this component from entity |
| `constructor` | `(data: T)` | Create a new instance of this custom component |
| `type` | `number`  | reference to type id from instance |
| `data` | `T`  | reference to raw data from instance |
| <h3>Entity</h2> |
| `id` | `number`  | Instance unique id |
| `active` | `boolean`  | Informs if the entity is active |
| `add(component: Component)` |  | Add a component to this entity |
| `remove(component: Component)` |  | Removes a component's reference from this entity |
| `subscribe(handler: Susbcription)` | `cancel = () => Entity`  | Allows interested parties to receive information when this entity's component list is updated <br> `Susbcription = (entity: Entity, added: Component[], removed: Component[]) => void` |
| <h3>System</h2> |
| `constructor` | `(components: number[], frequence: number = 0)`  |  |
| `id` | `number` | Unique identifier of an instance of this system |
| `frequence` | `number` | The maximum times per second this system should be updated |
| `beforeUpdateAll(time: number)` | | Invoked before updating entities available for this system. It is only invoked when there are entities with the characteristics expected by this system. |
| `update(time: number, delta: number, entity: Entity)` | | Invoked in updates, limited to the value set in the "frequency" attribute |
| `afterUpdateAll(time: number, entities: Entity[])` | | Invoked after performing update of entities available for this system. It is only invoked when there are entities with the characteristics expected by this system. |
| `change(entity: Entity, added?: Component<any>, removed?: Component<any>)` | | Invoked when an expected feature of this system is added or removed from the entity |
| `enter(entity: Entity)` | | Invoked when: <br>**A)** An entity with the characteristics (components) expected by this system is added in the world; <br>**B)** This system is added in the world and this world has one or more entities with the characteristics expected by this system; <br>**C)** An existing entity in the same world receives a new component at runtime and all of its new components match the standard expected by this system. |
| `exit(entity: Entity)` | | Invoked when: <br>**A)** An entity with the characteristics (components) expected by this system is removed from the world; <br>**B)** This system is removed from the world and this world has one or more entities with the characteristics expected by this system; <br>**C)** An existing entity in the same world loses a component at runtime and its new component set no longer matches the standard expected by this system |


## Feedback, Requests and Roadmap

Please use [GitHub issues] for feedback, questions or comments.

If you have specific feature requests or would like to vote on what others are recommending, please go to the [GitHub issues] section as well. I would love to see what you are thinking.

## Contributing

You can contribute in many ways to this project.

### Translating and documenting

I'm not a native speaker of the English language, so you may have noticed a lot of grammar errors in this documentation.

You can FORK this project and suggest improvements to this document (https://github.com/nidorx/ecs-lib/edit/master/README.md).

If you find it more convenient, report a issue with the details on [GitHub issues].

### Reporting Issues

If you have encountered a problem with this component please file a defect on [GitHub issues].

Describe as much detail as possible to get the problem reproduced and eventually corrected.

### Fixing defects and adding improvements

1. Fork it (<https://github.com/nidorx/ecs-lib/fork>)
2. Commit your changes (`git commit -am 'Add some fooBar'`)
3. Push to your master branch (`git push`)
4. Create a new Pull Request

## License

This code is distributed under the terms and conditions of the [MIT license](LICENSE).


[GitHub issues]: https://github.com/nidorx/ecs-lib/issues
