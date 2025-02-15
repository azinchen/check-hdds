# HDD Check Script

This repository contains a Bash script that uses **smartctl** (from the [smartmontools](https://www.smartmontools.org/) package) to scan your HDDs and display key S.M.A.R.T. parameters in a compact, fixed-width table format. The script reports information such as the disk model, serial number, WWN, health status, reallocated sector count, pending sector count, offline uncorrectable sector count, spin retry count, head parking count (Load_Cycle_Count), work time (in days and hours), temperature, and an advisory message.

## Prerequisites

- **smartmontools** must be installed on your system.
  - **Debian/Ubuntu:**
    ```bash
    sudo apt-get install smartmontools
    ```
  - **CentOS/RHEL:**
    ```bash
    sudo yum install smartmontools
    ```
- The script needs to be run with **root privileges** so that smartctl can access all disk information.

## Downloading the Script

You can download the script directly using `wget`:

```bash
wget https://raw.githubusercontent.com/azinchen/check_hdds/main/check_hdds.sh
```
## Usage

1. **Make the Script Executable**

   After downloading, ensure the script has execute permissions:
   ```bash
   chmod +x check_hdds.sh
   ```

2. **Run the Script**

   Execute the script with root privileges:
   ```bash
   sudo ./check_hdds.sh
   ```

3. **Review the Output**

   The script prints a table with the following columns:

   - **Disk**: Device file for the HDD (e.g., /dev/sda)
   - **Model**: Disk model name
   - **Serial**: Disk serial number
   - **WWN**: Disk WWN as reported by smartctl (e.g., "5 000cca 264d0e0b2")
   - **Health**: Overall SMART health status (e.g., PASSED)
   - **R**: Reallocated Sector Count
   - **P**: Current Pending Sector Count
   - **U**: Offline Uncorrectable Sector Count
   - **S**: Spin Retry Count
   - **HP**: Head Parking Count (Load_Cycle_Count)
   - **Work**: Calculated work time (days and hours)
   - **Temp**: Temperature in Celsius
   - **Advice**: Advisory message ("FAIL" if any key parameter is non-zero, otherwise "OK")

   After the table, the script prints explanations for each column.

## Contributing

Feel free to open issues or pull requests if you find any bugs or have suggestions for improvements.

## License

This project is licensed under the [MIT License](LICENSE)
.
