# Helicopter Simulation Development

Currently, I'm working on replicating the helicopter flight mechanics from the game **Nuclear Option**. This project is a blend of GPT-assisted coding and my journey as a novice game developer, focusing on the nuances of helicopter flight simulation.

### Current Challenge:
The main issue I'm facing is that **momentum dies out too quickly** when transitioning from a high altitude to a low altitude. I need to figure out the math to improve the forward vectoring. My suspicion is that it involves creating "dynamic" coefficients for lift, drag, and thrust based on the angle of the helicopter and engine power.

### TODO:
- [ ] **Dynamic Flight Model**: Update the coefficients of lift, drag, and power dynamically based on thrust and the aircraft's angle of attack.
- [ ] **Reduce Magic Numbers**: Clean up the code by minimizing the hard-coded values and making the calculations more flexible and realistic.
- [ ] **Math & Physics Skills**: Improve my understanding of mathematics, physics, and vector calculus to enhance the realism of the flight model.
- [ ] **Wench System**: Implement a wench system to lift objects, which should also update the aircraft's base weight dynamically.
- [ ] **Rotor Blade Animation**: Add rotor blade spin animation (though this is low priority for now).

### Development Notes:
- **Momentum Issue**: The helicopter currently loses momentum too quickly during descent. The solution likely involves more sophisticated modeling of aerodynamic forces.
- **Dynamic Coefficients**: A key focus will be to model flight parameters like lift, drag, and thrust in real-time based on flight conditions (angle, speed, power, etc.).
- **Hard-Coded Values**: Reducing the reliance on arbitrary "magic numbers" will make the flight model easier to tune and more physically accurate.

This is very much a work in progress, and I'm learning as I go.
