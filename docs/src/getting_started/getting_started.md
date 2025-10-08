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

   ![Releases](./getting_started/releases.png)

3. Extract the downloaded `.zip` file to your preferred location.  
4. Run the executable file:  
   **`CyderVis_vx.x.x_windows.exe`**

   ![Run Program](./getting_started/run_program.png)

Once launched, the **CyderVis** window will open:

![CyderVis Open](./getting_started/cydervis_opened.png)

---

## Step 3: Start a CAN Server

With your USB CAN adapter connected, start a CAN server using **win-can-utils**:

```bash
# Example: start a server for a gsusb (candleLight) device with a bitrate of 1 Mbps
canserver gsusb -b 1000000
```

This will start the CAN interface (usually named `can0` by default).

![Start canserver](./getting_started/start_canserver.png)

> 💡 **Note:**  
> The `canserver` must remain running while CyderVis is active.  
> If you close it, CyderVis will lose connection to the CAN interface.

---

## Step 4: Connect and Receive Data in CyderVis

1. In **CyderVis**, locate the **CAN Interface** input field.  
2. Verify that the interface name matches the one started by `canserver` (default is `can0`).  
3. Click **Start** to begin receiving data from the CAN adapter.

If other devices are active on the bus, incoming CAN frames will begin streaming into CyderVis and appear in the viewing table.

![CyderVis Streaming](./getting_started/cydervis_streaming.png)

---

## Step 5: Adjust Display Options

Use the display option toggles to customize how CAN data is displayed.  
These toggles control message formatting and visualization preferences.

![CyderVis Display Options](./getting_started/cydervis_display_options.png)

---

## Step 6: Load a `.dbc` File to Decode Frames

A **DBC file** defines how to decode CAN frames into human-readable signals.  
You can learn more about the DBC format here:  
<https://docs.openvehicles.com/en/latest/components/vehicle_dbc/docs/dbc-primer.html>

We provide example `.dbc` files for Cyder products at:  
<https://github.com/cyborg-dynamics-engineering/cyder-vis/tree/main/gdextension_can_io/examples>

To load a `.dbc` file:
1. Click **Open** next to the **DBC File** dialog.
2. Select your `.dbc` file.
3. Once loaded, decoded frames will automatically appear in the viewing table.

![CyderVis Decoded Frames](./getting_started/cydervis_decoded_frames.png)

---

## Step 7: Plot the Data

1. Open the **Plot** tab.  
2. Click on any decoded variable name in the viewing table to toggle it on or off in the plot view.

![CyderVis Plotting](./getting_started/cydervis_plotting.png)

> 💡 **Note:**  
> Data must be decoded using a .dbc file to enable plotting.

---

## Troubleshooting

- **CyderVis doesn’t connect:**  
  Ensure the `canserver` is running and the interface name matches (e.g., `can0`).

- **Permission issues:**  
  Try running both `canserver` and CyderVis as **Administrator**.

---