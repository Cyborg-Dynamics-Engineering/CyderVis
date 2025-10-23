# Getting Started on Windows

This guide walks you through setting up and running **CyderVis** on Windows.

---

## Step 1: Install *win-can-utils*

**win-can-utils** is an open-source Windows port of Linux’s *can-utils*.  
It provides the backend required for interfacing with your CAN adapter on Windows.

Follow the installation and usage instructions in the official [win-can-utils README](https://github.com/cyborg-dynamics-engineering/win-can-utils?tab=readme-ov-file#windows-can-utils).

---

## Step 2: Download and Run CyderVis

1. Visit the [CyderVis Releases](https://github.com/Cyborg-Dynamics-Engineering/cyder-vis/releases) page on GitHub.  
2. Under the latest release, expand the **Assets** dropdown and download the Windows `.zip` package.

   ![Releases](images/releases_windows.png)

3. Extract the downloaded `.zip` file to your preferred location.  
4. Run the executable file:  
   **`CyderVis_vx.x.x_windows.exe`**

   ![Run Program](images/run_program.png)

Once launched, the **CyderVis** window will open:

![CyderVis Open](images/cydervis_opened.png)

---

## Step 3: Start a CAN Server

With your USB CAN adapter connected, start a CAN server using **win-can-utils**:

```bash
# Example: start a server for a gsusb (candleLight) device with a bitrate of 1 Mbps
canserver gsusb -b 1000000
```

This will start the CAN interface (usually named `can0` by default).

![Start canserver](images/start_canserver.png)

> 💡 **Note:**  
> The `canserver` must remain running while CyderVis is active.  
> If you close it, CyderVis will lose connection to the CAN interface.

---

## User Guide
With the CAN interface up, move on to the [CyderVis User Guide](cydervis_user_guide.md)