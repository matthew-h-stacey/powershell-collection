# Introduction 
The objective of this project is to develop a user offboarding script that defines a standardized, repeatable offboarding process. This will both save time and make the work more consistent.

# Getting Started
1.	Installation process

    Git the repository or download it manually 

2.  Usage

    Offboard-AADUserGUI.ps1 is the primary script, the other files are complementary.

3.	Software dependencies (required modules)

    ExchangeOnlineManagement

    AzureAD

    MSOnline
    
    SPOService

# Issues
License removal checkbox removing licenses even when unchecked

# To-Do Items / Script Enhancements
- Cleaner reporting (single file?) *WIP - using _Summary.txt
- Report on any/all licenses removed
- Change ownership on any owned distis
- Implement application (certificate/secret) based authentication to minimize efforts during execution