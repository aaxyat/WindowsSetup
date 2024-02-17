# Windows 11 Setup Script Testing Environment

This repository contains scripts for setting up a Windows 11 environment. The setup is tested in an ephemeral environment using VirtualBox.

## Requirements

- [VirtualBox](https://www.virtualbox.org/)
- [Windows 11 ISO](https://www.microsoft.com/software-download/windows11)

## Development

### VirtualBox Setup

1. Install VirtualBox on your machine.
2. Download the Windows 11 ISO from the official Microsoft website.
3. Create a new virtual machine in VirtualBox and install Windows 11 using the downloaded ISO.

### Creating a Snapshot

1. Once Windows 11 is installed and set up to your liking, power off the VM.
2. Go to the "Snapshots" section in the VirtualBox Manager.
3. Click on the "Take" button to create a new snapshot. You can name it something like "Fresh Install".

### Testing the Setup Script

1. Start the VM and run your setup script.
2. Test the environment as needed.

### Reverting to the Snapshot

1. Once testing is complete, power off the VM.
2. In the "Snapshots" section, select the "Fresh Install" snapshot and click on the "Restore" button. This will discard all changes made after the snapshot and revert the VM back to the state it was in when you took the snapshot.

Remember, snapshots do take up disk space, as they need to store the differences from the base disk. Make sure you have enough space on your hard drive.

## License

This project is licensed under the terms of the MIT license.
