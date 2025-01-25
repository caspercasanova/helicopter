# Helicopter Simulation Development

Currently, I'm working on replicating the helicopter flight mechanics from the game **Nuclear Option**. This project is a blend of GPT-assisted coding and my journey as a novice game developer, focusing on the nuances of helicopter flight simulation.

This is very much a work in progress, and I'm learning as I go.

### Current Challenge:

#### Flight Model
Making flight fun, gliding with a bit less input required from the pilot. Currently everything is very loose. 

#### Destructible Aircraft Modules
I am currently testing out how to make different sections of the aircraft 'destructible'. My intuition is guiding me towards making each section of Helicopter a `RigidBody` and using `Jolt Joints` to tie everything together would be the best approach.
I want to avoid needing to have to make different Area3D's to register different damages. 
Current implementation works as far as I know, **however**, the tail section gets springy with more than a couple joints applied. 
I worked around this solution by changing the mass on the individual rigid bodies, but I feel like that is a work around, from what seems like an obvious fix with better Joint Params. 

One thing to explore would be some kind of Skeletal Bone System. Might be worth it, but who knows.  

---

Check out the `helicopter.gd` file for a list of TODOs and notes
You can learn a lot about building something from scratch. 
I have learned about game dev, helicopters and physics. 
Shits cool. 

- [ ] **Dynamic Flight Model**: Update the coefficients of lift, drag, and power dynamically based on thrust and the aircraft's angle of attack.
- [ ] **Reduce Magic Numbers**: Clean up the code by minimizing the hard-coded values and making the calculations more flexible and realistic.
- [ ] **Math & Physics Skill Issues**: Improve my understanding of mathematics, physics, and vector calculus to enhance the realism of the flight model.
- [ ] **Debugging Visuals**: I'd ideally like some debugging things to visualize different transforms and positions
- [ ] **Add Sound**: I have no sounds currently, which is a technical challenge that will need to be addressed. Need to add sounds for Spool Up/Spool Down and different Rotor scenarios ("High G turns") etc
- [ ] **UI**: I would like to make some better working UI (never worked on making UIs in games)

 

### Development Notes:
- **GAME NOT FUN IN CURRENT STATE**: There is something fun about the wench system, but Need to find a better balance of flight control and physics sim and I haven't found it yet. 
- Godot 4.4 Changes the physics engine to have Jolt support; which may fix some of the issues I have been facing with joint bounciness. This is a TBD perspective. 
- **Translation Issue**: I feel as though this helicopter doesn't translate like it *ought* to. 
- **Dynamic Coefficients**: A key focus will be to model flight parameters like lift, drag, and thrust in real-time based on flight conditions (angle, speed, power, etc.).
- **Hard-Coded Values**: Reducing the reliance on arbitrary "magic numbers" will make the flight model easier to tune and more physically accurate.



### Cool Discovery
Helicopter + Wench is a super fun game loop in itself.  
