# **⚡ FPGA Real-Time Accelerometer Streaming**
### **A High-Performance VHDL Hardware Pipeline built "From Scratch" on Artix-7**

---

## **🚀 Project Overview**
This project demonstrates a complete, low-latency hardware pipeline designed to acquire 3-axis acceleration data from an **ADXL345 sensor** and stream it to a host PC via **Ethernet (UDP/IPv4)**.

**The "From Scratch" Philosophy:** This system is built on a custom-logic approach where every clock cycle is precisely managed. By implementing our own state machines for every stage—from sub-microsecond SPI transactions to MII nibble serialization—this project provides a deep dive into the inner workings of communication protocols and direct hardware interaction, without the abstraction of standard software layers.

---

## **🛠 Technology Stack**

### **Hardware & RTL**
* **Target**: Xilinx Artix-7 (Arty A7-35T).
* **System Clock**: **25 MHz** (Generated via the **Clock Wizard IP**, converting the 100 MHz board oscillator into a stable 25 MHz system base).
* **Sensor**: ADXL345 (Digital Accelerometer via SPI (MODE 3)).
* **SPI Protocol**: Currently running at **1 MHz** (Scalable via generics; must remain **< 5 MHz** per ADXL345 datasheet specifications).
* **Internal Interconnect**: **AXI-Stream Interface** (Ensures reliable, back-pressured data flow between the Packet Generator and the MII Driver).
* **Protocol Stack**: Ethernet II, IPv4, UDP (Fully hard-coded logic).
* **Physical Layer**: MII (Medium Independent Interface) @ 25 MHz.



### **Software & Tools (The Ecosystem)**
* **Vivado Design Suite**: The Software IDE used for synthesis, implementation, and bitstream generation.
* **Python 3.10**: For real-time sensor modeling and data visualization.
* **Wireshark**: Network protocol validation and frame inspection.
* **Tera Term**: Serial monitoring via the internal UART telemetry core.

---

## **✨ Key Features**
* **AXI-Stream Architecture**: The design utilizes the industry-standard **AXI-Stream** protocol for internal data movement. This allows the `frame_gen` to pause if the `mii_phy` is busy, preventing data overflow and ensuring high-performance throughput.
* **Strobe-and-Latch Coherency**: Guarantees zero "data tearing"—X, Y, and Z axes are captured at the exact same instant.
* **Educational Hardware Design**: A modular architecture designed to clearly expose the mechanics of SPI registers and network headers.

---

## **🔍 Debug-First Design (Oscilloscope-Free Validation)**
The project is engineered to be fully validated without the need for an external oscilloscope:

* **Sub-system Isolation**: Specific versions like `top_adxl_debug` and `top_eth_debug` allow you to isolate the **SPI acquisition** from the **Ethernet transmission**. This means you can debug the sensor logic or the network stack independently before full integration.
* **UART Telemetry**: The `uart_tx` module allows for real-time data logging directly on a PC serial terminal.
* **ILA Proven**: While not permanently instantiated to save FPGA resources, the design has been fully validated using **Xilinx Integrated Logic Analyzers (ILA)**. The signals are structured to be easily probed by any user wishing to perform in-chip signal visualization.
* **Full Visibility**: Between the UART logs and Wireshark captures on the PC, the entire data path—from SPI transactions to Ethernet nibbles—is transparent and verifiable.


---

## **🚦 Quick Start (Vivado Project Restoration)**

This repository uses a `.tcl` script to rebuild the project structure automatically.

1.  **Open Vivado**
2.  **Open the Tcl Console** (Window > Tcl Console).
3.  **Navigate to the project folder**:
    ```tcl
    cd [path/to/eth_adxl_project]
    ```
4.  **Source the restoration script**:
    ```tcl
    source  eth_adxl_project.tcl
    ```
5.  **Configure Networking**: Open `top_eth.vhd` and update the `mac_dest` and `ip_dest` generics to match your PC.
6.  **Generate Bitstream**: Click "Generate Bitstream" to run Synthesis, Implementation, and Bitstream generation.

---

## **📂 Repository Structure**

The repository follows a strict modular organization. **Each directory contains its own README.md** detailing local FSMs, port maps, and timing specifications.

```text
eth_adxl_project/
├── eth_adxl_project.tcl        # Project restoration script
├──   mod3d.py                  # Real-time 3D visualization and UDP packet listener
├── README.md                   # Main documentation (Landing page)
│
├── hdl/                        # Hardware Description Language source files
│   ├── adxl_top/               # Sensor integration and strobe logic
│   │   ├── README.md           # Sensor integration documentation
│   │   ├── adxl_top.vhd        # Production sensor top-level module
│   │   └── top_adxl_debug.vhd  # Debug variant with UART/LED diagnostics
│   │
│   ├── adxl_controller/        # ADXL345 FSM & Register management
│   │   ├── README.md           # Controller logic documentation
│   │   └── adxl345_controller.vhd # Main FSM for sensor configuration
│   │
│   ├── spi_master/             # Low-level SPI Protocol engine
│   │   ├── README.md           # SPI driver documentation
│   │   └── spi_master.vhd      # Generic SPI Master (Mode 3) implementation
│   │
│   ├── top_eth/                # Network stack integration
│   │   ├── README.md           # Ethernet integration documentation
│   │   ├── top_eth.vhd         # Main Ethernet sub-system
│   │   └── top_eth_debug.vhd   # Debug variant with fixed network payload
│   │
│   ├── frame_gen/              # UDP/IP Packet encapsulation logic
│   │   ├── README.md           # Frame generation documentation
│   │   ├── frame_gen.vhd       # Production UDP/IP packet builder
│   │   └── frame_gen_debug.vhd # Test pattern generator for network validation
│   │
│   ├── mii_phy/                # MII Interface & PHY Nibble serialization
│   │   ├── README.md           # Physical layer interface documentation
│   │   └── mii_phy.vhd         # Driver for the DP83848J Ethernet PHY
│   │   └── crc.vhd             # Parallel CRC32 calculation for FCS field
│   │   
│   │
│   ├── uart/                   # Debug monitoring utility
│   │   ├── README.md           # UART documentation
│   │   └── uart_tx.vhd         # UART Transmitter for telemetry data
│   │
│   └── top_system/             # Global system hierarchy
│       ├── README.md           # Top-level integration documentation
│       └── TOP_system.vhd      # Final system-level wrapper
│
├── ip/                         # Xilinx IP Core files
│   └── clk_wiz_0/              # Clock Wizard PLL (100MHz to 25MHz)
│
├── constraints/                # Xilinx Design Constraints (.xdc)
│   ├── arty_a7_TOP.xdc         # Full system physical pin mapping
│   ├── arty_a7_adxl_debug.xdc  # Pin mapping for sensor-only debugging
│   └── arty_eth_only.xdc       # Pin mapping for network-only debugging
│
└── sim/                        # VHDL Testbenches
    ├── tb_top_adxl.vhd         # Simulation for sensor acquisition path
    ├── tb_mii_phy.vhd          # Simulation for MII interface timing
    ├── tb_frame_gen.vhd        # Simulation for UDP/IP encapsulation
    ├── tb_frame_gen_debug.vhd  # Simulation for network debug logic
    └── tb_spi_master.vhd       # Simulation for low-level SPI protocol
```


## **📚 References**
* **Sensor**: [ADXL345 Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/ADXL345.pdf)
* **Ethernet PHY**: [DP83848J Datasheet](https://www.ti.com/lit/ds/symlink/dp83848j.pdf)
* **Protocol**: [UDP/IPv4 Specification (RFC 768 / 791)](https://datatracker.ietf.org/doc/html/rfc768)

## **👤 Author**
* **Johan EL HAJJ DIB** [LinkedIn](https://www.linkedin.com/in/johan-el-hajj-dib/)