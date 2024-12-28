# Bloop's gun system V2

## A free, open source, made from scratch gun system developed with the Flux Framework.

## 🚨 Notice
I am no longer uploading `.rbxl` files to the github since my fatass is too lazy. The release is now on an uncopylocked place on my roblox profile.  
🔗 **[Click here for releases](https://www.roblox.com/games/95481417748754/new-gun-system-test)**  

---

## ✨ What is this?
This is a complete and total rewrite of the original gun system i made back in V3.

## ✨ So what's new?
The gun system comes with BIG significant improvements and additional features, including **actual mobile support**. (also fixes input delay also known as "fire" delay) (those who were in v3 know.....) (this shit drove me insane in v3 😭)

---

## 🛠️ System-Features

- Fully functional gun system as you'd expect.
- Smooth firing.
- Matained often and new features to come in the future.
- Also has support for Mobile Devices.  
- Customizable Settings found in the module ("GunConfig").  
- Team-based kill restrictions via a "Priority" System.
- Also has a custom drop system which is cool i think.
- Powered by Flux V3

---
In ``ReplicatedStorage.Shared.Data` there is a module called "GunConfig" this defines all the customizable options you can configure in the gun system

## ⚙️ So what are all the Options?

### 1. **ShowMuzzleEffects**  
- **Default**: `True`
  
- **Description**: Enables or disables muzzle effects.  

### 2. **ShowBlood**  
- **Default**: `True`
  
- **Description**: Enables or disables blood effects.  

### 3. **AlwaysDamage**  
- **Default**: `False`
  
- **Description**: Ignores all team-based kill restrictions, allowing unrestricted combat.  

### 4. **NotifyPlayer**  
- **Default**: `True`
  
- **Description**: Enables or disables the notification system.  

### 5. **EnableGuiltySystem**  
- **Default**: `True`

- **Description**: Controls the Class-D Guilty check.
  
  - If `True`, Class D will only be damaged if they are guilty.  
  - If `False`, Class D can always be damaged.  

### 6. **EnableS19ReloadSounds**  
- **Default**: `True`
  
- **Description**: turns on \ off the Site-19 reload system, including:
  - Mag-in and mag-out sounds.  
  - Magazine transparency.  
  - If `False`, falls back to the default reload sound in the muzzle (if it even exists).  

### 7. **EnableDropWeapons**  
 `NOTE!: IN THE GUN SETTINGS OF THE ACTUAL GUN YOU CAN CONFIGURE IF YOU WANT THE GUN TO BE DROPABLE OR NOT! `
 
- **Default**: `True`
  
- **Description**: Enables or disables the weapon drop system.
  - If true, and  WeaponDropable is true in the gun settings, by pressing Q you may trigger the custom drop system.
  - **Warning**: impending doom..

### 8. AltSpread
- **Default**: `False`
- **Description**: Enables or disables Site-19 Style Spread system (spread gets worse untill you stop firing)


![image](https://github.com/user-attachments/assets/851defcd-5e55-4584-a14b-48a790e0d774)

---

## 🧩 Other Features

### Class D Guilty System
To make a specific tool "guilty" (When a class d equips the tool it will make them guilty) :  
1. Scroll down untill you reach the tags.  
2. Click the + and add a new tag called `Hostile` OR `Guilty`.  

![image](https://github.com/user-attachments/assets/7540d4df-3237-4059-ab8d-8713d02546cb)


---

### Anti TeamKill System
The `TeamPriority` inside **ReplicatedStorage.Shared.Data** defines all team kill restrictions.  
You can add or modify your teams and their restrictions directly in this module.  

## 1. Priority1
- These will be your basic Hostiel teams (Example: Chaos Insurgency, Class D)

## 2. Priority2
- These will be your Non-TK Teams (Example: Security Department and MTF Beta-7)

## 3. Priority3
- These will be you team kill teams (Example: Adminstrative, MTF Alpha-1)
  
![image](https://github.com/user-attachments/assets/63795e72-1a39-4765-a339-1abf6e1195fe)


Contributions \ edits are welcome! feel free to fork at your own need.
---
