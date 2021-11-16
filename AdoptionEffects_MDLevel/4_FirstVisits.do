/*******************************************************************************
* Title: Effect of TAVR adoption on cardiologist provision of preventive care: 
	4 -- what does a normal first visit look like? How does that change post adoption? 
* Created by: Alex Hoagland
* Created on: 10/15/2021
* Last modified on: 10/15/2021
* Last modified by: 
* Purpose: Simple event study of TAVR adoption on preventive care visits 
* Notes: 

* Key edits: 
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202105"
global geodata "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/Geography"
********************************************************************************


***** 1. Use panel from 1_EventStudy.do
use "$datadir/TreatmentPanel_AllCardiologist_OutpatientVisits_202110.dta", clear

*** Keep only visits with "new patient" E&M codes
gen tokeep = inlist(hcpcs, "99201", "99202", "99203", "99204", "99205")
bysort bene_id npi from_dt: ereplace tokeep = max(tokeep) 
keep if tokeep == 1

*** Examine popular procedures
// drop established patient visits
gen todrop = inlist(hcpcs, "99211", "99212", "99213", "99214", "99215")
bysort bene_id npi from_dt: ereplace todrop = max(todrop) 
drop if todrop == 1

drop if inlist(hcpcs, "99201", "99202", "99203", "99204", "99205", "G8427","1036F", "G8447", "G8553") // drop E&M codes
bysort hcpcs: gen proccount = _N
drop if proccount < 900 // used in less than 1% of lines
tab hcpcs, sort // show most popular procedures

/* Popular procedures are: 
	93000 (60%): Electrocardiogram
	93306 (16%): Echocardiography 
	93010 (7%): electrocardiogram
	4040F (2.4%): flu shot already received/given
	G8420 (2.3%): BMI evaluated, in normal parameters -- CHECK THIS ONE? 
	36415 (1.5%): blood draw
	93880 (1.4%): Carotid doppler exam -- CHECK THIS ONE? 
	1123F (1.3%): Advance care plan discussed
	G8419 (1.1%): BMI outside normal parameters -- CHECK THIS ONE? 
	4086F (1.1%): Aspirin prescribed -- CHECK THIS ONE? 
	G8754 (1.1%): Low recent diastolic BP 
	1101F (1.1): Fall risk screen (low) -- CHECK THIS ONE? 
	1000F (1.1%): Tobacco use assessed
	93005 (1.1%): Electrocardiogram
	G8598 (1.0%): Aspirin used -- CHECK THIS ONE (also G8599)
*/

// keep only those screened
// gen prev = 0
// replace prev = 1 if inlist(hcpcs_cd, "93303", "93304", "93306", "93307", "93308", "93320", "93325", "93350", "93351")
// replace prev = 1 if substr(hcpcs_cd, 1, 4) == "C892" | hcpcs_cd == "C8930"
// keep if prev == 1
