<h1> Ubuntu XRDP Full VM Flist Creator </h1>

<h2>Table of Contents</h2>

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [What the Script Does](#what-the-script-does)
- [Notes](#notes)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Introduction

This repository contains a script to create a Full VM flist with Ubuntu and XRDP for the ThreeFold Grid. The flist includes a desktop environment (XFCE) and XRDP, allowing for remote desktop access to your deployed VM.

## Prerequisites

- A Linux system with root access
- Sufficient disk space (at least 10GB free)
- A ThreeFold ZOS Hub account with an API key

## Usage

1. Clone this repository:
   ```
   git clone https://github.com/Mik-TF/ubuntu_xrdp_fullvm_flist.git
   cd ubuntu_xrdp_fullvm_flist
   ```

2. Make the script executable:
   ```
   chmod +x create_fullvm_ubuntu_xrdp_flist.sh
   ```

3. Run the script with sudo privileges, providing your ThreeFold ZOS Hub API key as an argument:
   ```
   sudo ./create_fullvm_ubuntu_xrdp_flist.sh YOUR_API_KEY_HERE
   ```
   Replace `YOUR_API_KEY_HERE` with your actual ThreeFold Hub API key.

4. Wait for the script to complete. This may take some time depending on your internet connection and system performance.

5. Once completed, the script will have created and uploaded an flist named `ubuntu-24.04_fullvm_xrdp.tar.gz` to your ThreeFold Hub account.

## What the Script Does

1. Installs necessary packages
2. Creates a base Ubuntu system using debootstrap
3. Installs XFCE desktop environment and XRDP
4. Configures a non-root user for XRDP access
5. Sets up firewall rules
6. Creates and uploads the flist to the ThreeFold Hub

## Notes

- The default non-root user created is `xrdpuser` with password `xrdppassword`. It's recommended to change this password after first login.
- The script requires an active internet connection throughout its execution.
- Ensure you have the latest version of the script by pulling from this repository before each use.

## Troubleshooting

If you encounter any issues:
1. Check your internet connection
2. Ensure you have sufficient disk space
3. Verify that you're using a valid ThreeFold API key
4. Review the script output for any error messages

For persistent issues, please open an issue in this GitHub repository.

## License

This work is under the [Apache 2.0 license](./LICENSE). 