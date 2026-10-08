# Multi-Bit-Comparator

> ### 🐞 eUVM Bug Hunt activity
> This fork turns the eUVM testbench for the **Serialized Comparator** into a hands-on learning activity.
> The testbench passes with 0 errors, but it has bugs. Find them using the logs and the waveform.
> **Start here: [ACTIVITY.md](ACTIVITY.md)**. Solutions are on the `solution` branch.
>
> Original design and testbench by **Soham Kapur**. The activity was added by **Thilagan KM**.

**Author:** Soham Kapur
</br> </br>
**Description:** Variations of a generalized multi-bit/magnitude comparator with trade-offs among timing and area.
</br></br>
**Tools Used:** Verilog HDL, Xilinx Vivado, Altera Quartus
</br> </br>
**Concepts Used:** Clock gating, Power gating, Area-Power-Timing trade-off, Comparator
</br> </br>
**Device Simulated:** Cyclone IV E: EP4CE115F29C7
</br> </br>
**Multi Bit Comparator with Power Gating:** 4-bit Comparator
</br>
![image](https://github.com/user-attachments/assets/83017971-f21f-4b3d-ba02-daf77f90432b)
</br> </br>
**Single Bit Comparator with Power Gating:** Fmax = 103.69 MHz
</br>
![image](https://github.com/user-attachments/assets/ba54a9f9-df3f-4b8d-9bd7-729253db7038)
</br> </br>
**Serialized Multi Bit Comparator:** Fmax = 118.88 MHz
</br>
![image](https://github.com/user-attachments/assets/fffdd3b8-c5a5-40d7-b859-9f90e69871de)

</br> </br>

## Credits and licence

- **Original design and eUVM testbench:** Soham Kapur. Original repository: [SKpro-glitch/Multi-Bit-Comparator](https://github.com/SKpro-glitch/Multi-Bit-Comparator).
- **eUVM Bug Hunt activity, testbench fixes and documentation:** Thilagan KM.

This project is licensed under the [Apache License 2.0](LICENSE). The original work is published here with Soham Kapur's permission.
See [NOTICE](NOTICE) for copyright and a summary of the changes made to the original files.
