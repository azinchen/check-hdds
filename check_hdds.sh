#!/bin/bash
#
# MIT License
#
# Copyright (c) 2025 Alexander Zinchenko <alexander@zinchenko.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# ------------------------------------------------------------------------------
# This script checks all detected disks and displays key S.M.A.R.T. parameters
# in a compact table format with fixed column widths. It extracts disk model,
# serial number, size (from "User Capacity:" or "Total NVM Capacity:"), WWN (as
# reported by smartctl), overall health status, SMART attributes (R, P, U, S),
# head parking count (Load_Cycle_Count), work time (from Power_On_Hours) using a space
# delimiter between days and hours, temperature, and an advisory message.
#
# In addition, it adds two extra columns:
# - "Boot": Marks with "*" if any partition on the disk is bootable (parsed via parted).
# - "Conn": Shows the connection type (e.g., USB, SATA, NVMe) parsed from the smartctl output.
# - "Type": Shows the disk type (HDD, SSD, NVME). For non-NVMe devices, it checks the "Rotation Rate:".
#
# For drives connected via USB bridges, the script automatically uses the "-d sat" option.
# The initial disk scan is performed using both "-d sat" and "-d nvme" so that proper
# device types are detected.
#
# Requires smartmontools (smartctl) and parted.
#
# Column Explanations:
# Disk   : Device file for the disk (e.g., /dev/sda)
# Boot   : Bootable indicator ("*" if any partition is bootable)
# Conn   : Connection type (e.g., USB, SATA, NVMe)
# Type   : Disk type (HDD, SSD, NVME)
# Model  : The disk model name
# Serial : The disk serial number
# Size   : Disk capacity (e.g., "1.00 TB")
# WWN    : The disk's WWN as reported by smartctl (e.g., "5 000cca 264d0e0b2")
# Health : Overall SMART health status (e.g., PASSED)
# R      : Reallocated Sector Count
# P      : Current Pending Sector Count
# U      : Offline Uncorrectable Sector Count
# S      : Spin Retry Count
# HP     : Head Parking Count (Load_Cycle_Count)
# Work   : Work time from Power_On_Hours (days and hours)
# Temp   : Temperature in Celsius (from Temperature_Celsius)
# Advice : "FAIL" if any key parameter is non-zero, otherwise "OK"
# ------------------------------------------------------------------------------
 
echo "Scanning for disks..."
 
# Perform two scans: one for SATA (including USB bridges) and one for NVMe devices.
# Merge the unique device paths for processing.
disks=$( { smartctl --scan -d sat; smartctl --scan -d nvme; } | sort -u | awk '{print $1}' )
if [ -z "$disks" ]; then
  echo "No disks found by smartctl."
  exit 0
fi
 
# Define fixed column widths:
# Disk (10), Boot (6), Conn (10), Type (8), Model (22), Serial (20), Size (10),
# WWN (20), Health (8), R (4), P (4), U (4), S (4), HP (8), Work (12), Temp (6), Advice (8)
header_fmt="%-10s %-6s %-10s %-8s %-22s %-20s %-10s %-20s %-8s %-4s %-4s %-4s %-4s %-8s %-12s %-6s %-8s\n"
row_fmt="%-10s %-6s %-10s %-8s %-22s %-20s %-10s %-20s %-8s %-4s %-4s %-4s %-4s %-8s %-12s %-6s %-8s\n"
 
header=$(printf "$header_fmt" "Disk" "Boot" "Conn" "Type" "Model" "Serial" "Size" "WWN" "Health" "R" "P" "U" "S" "HP" "Work" "Temp" "Advice")
header_len=$(echo -n "$header" | wc -c)
dashes=$(printf '%*s' "$header_len" '' | tr ' ' '-')
 
# Print header and dashed line
echo "$header"
echo "$dashes"
 
# Process each disk
for disk in $disks; do
  # Determine device type option; if "Unknown USB bridge" is found, use "-d sat"
  TYPE=""
  usb_check=$(smartctl -i "$disk" 2>&1)
  if echo "$usb_check" | grep -qi "Unknown USB bridge"; then
    TYPE="-d sat"
  fi
 
  # Get device information
  info=$(smartctl $TYPE -i "$disk")
  model=$(echo "$info" | grep -i "Device Model" | awk -F: '{print $2}' | xargs)
  if [ -z "$model" ]; then
    model=$(echo "$info" | grep -i "Model Family" | awk -F: '{print $2}' | xargs)
  fi
  serial=$(echo "$info" | grep -i "Serial Number" | awk -F: '{print $2}' | xargs)
 
  # Determine connection type:
  connection=$(echo "$info" | grep -i "^Interface:" | awk -F: '{print $2}' | xargs)
  if [ -z "$connection" ]; then
    if echo "$info" | grep -qi "USB"; then
      connection="USB"
    elif echo "$info" | grep -qi "SATA"; then
      connection="SATA"
    elif [[ "$disk" =~ nvme ]]; then
      connection="NVMe"
    else
      connection="N/A"
    fi
  fi
 
  # Determine disk type.
  if [[ "$disk" =~ nvme ]]; then
    diskType="NVME"
  else
    rot_rate=$(echo "$info" | grep -i "Rotation Rate:" | awk -F: '{print $2}' | xargs)
    if [[ "$rot_rate" =~ "Solid State Device" ]]; then
      diskType="SSD"
    elif [[ "$rot_rate" =~ [0-9]+ ]]; then
      diskType="HDD"
    else
      diskType="N/A"
    fi
  fi
 
  # Determine disk size.
  size=$(echo "$info" | grep "User Capacity:" | sed -E 's/.*\[(.*)\].*/\1/' | xargs)
  if [ -z "$size" ]; then
    size=$(echo "$info" | grep "Total NVM Capacity:" | sed -E 's/.*\[(.*)\].*/\1/' | xargs)
  fi
 
  # Extract WWN.
  wwn=$(echo "$info" | grep -i "LU WWN Device Id:" | awk -F: '{print $2}' | xargs)
  if [ -z "$wwn" ]; then
    wwn=$(echo "$info" | grep -i "WWN:" | awk -F: '{print $2}' | xargs)
  fi
 
  model=${model:-"N/A"}
  serial=${serial:-"N/A"}
  size=${size:-"N/A"}
  wwn=${wwn:-"N/A"}
 
  # Determine overall SMART health status.
  health_output=$(smartctl $TYPE -H "$disk")
  health=$(echo "$health_output" | grep -i "SMART overall-health self-assessment test result" | cut -d: -f2 | xargs)
  if [ -z "$health" ]; then
    health="Unknown"
  fi
 
  # Get detailed SMART attributes.
  smart_data=$(smartctl $TYPE -A "$disk")
  r=$(echo "$smart_data" | awk '/Reallocated_Sector_Ct/ {print $10}')
  p=$(echo "$smart_data" | awk '/Current_Pending_Sector/ {print $10}')
  u=$(echo "$smart_data" | awk '/Offline_Uncorrectable/ {print $10}')
  s=$(echo "$smart_data" | awk '/Spin_Retry_Count/ {print $10}')
  r=${r:-0}
  p=${p:-0}
  u=${u:-0}
  s=${s:-0}
 
  # Get head parking count.
  hpc=$(echo "$smart_data" | awk '/Load_Cycle_Count/ {print $10}')
  hpc=${hpc:-"N/A"}
 
  # Calculate work time from power-on hours.
  poh=$(echo "$smart_data" | awk '/Power_On_Hours/ {print $10}')
  if [[ "$poh" =~ ^[0-9]+$ ]]; then
    days=$(( poh / 24 ))
    hours=$(( poh % 24 ))
    work="${days}d ${hours}h"
  else
    work="N/A"
  fi
 
  # Get temperature.
  temp=$(echo "$smart_data" | awk '/Temperature_Celsius/ {print $10}')
  temp=${temp:-"N/A"}
 
  # Determine advisory message.
  if [ "$r" -gt 0 ] || [ "$p" -gt 0 ] || [ "$u" -gt 0 ] || [ "$s" -gt 0 ]; then
    advice="FAIL"
  else
    advice="OK"
  fi
 
  # Determine bootable status using parted.
  boot=$(parted -s "$disk" print 2>/dev/null | awk 'BEGIN {boot=""} /^[[:space:]]*[0-9]+/ { if(tolower($0) ~ /boot/) boot="*" } END {print boot}')
  boot=${boot:-""}
 
  # Print row for the disk
  printf "$row_fmt" "$disk" "$boot" "$connection" "$diskType" "$model" "$serial" "$size" "$wwn" "$health" "$r" "$p" "$u" "$s" "$hpc" "$work" "$temp" "$advice"
done
 
echo "HDD check complete."
 
# Column Explanations:
echo ""
echo "Column Explanations:"
echo "Disk   : Device file for the disk (e.g., /dev/sda)"
echo "Boot   : Bootable indicator ('*' if any partition is bootable)"
echo "Conn   : Connection type (e.g., USB, SATA, NVMe)"
echo "Type   : Disk type (HDD, SSD, NVME)"
echo "Model  : The disk model name"
echo "Serial : The disk serial number"
echo "Size   : Disk capacity (e.g., '1.00 TB')"
echo "WWN    : The disk's WWN as reported by smartctl (e.g., '5 000cca 264d0e0b2')"
echo "Health : Overall SMART health status (e.g., PASSED)"
echo "R      : Reallocated Sector Count"
echo "P      : Current Pending Sector Count"
echo "U      : Offline Uncorrectable Sector Count"
echo "S      : Spin Retry Count"
echo "HP     : Head Parking Count (Load_Cycle_Count)"
echo "Work   : Work time from Power_On_Hours (days and hours)"
echo "Temp   : Temperature in Celsius (from Temperature_Celsius attribute)"
echo "Advice : 'FAIL' if any key parameter is non-zero, otherwise 'OK'"
