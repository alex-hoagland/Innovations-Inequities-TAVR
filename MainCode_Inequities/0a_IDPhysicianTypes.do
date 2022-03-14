/*******************************************************************************
* Title: ID Interventional Cardiologists
* Created by: Alex Hoagland
* Created on: 1/10/2022
* Last modified on: 
* Last modified by: 
* Purpose: Identifies NPIs of all interventional cardiologists
	- note: this includes all "cardiologists" who perform TAVR at least once

* Notes: 

* Key edits: - TODO: add in all those who perform TAVR at least once to IVC group
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202105"
global geodata "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/Geography"
********************************************************************************


***** 1. Using MD-PPAS to make data sets for: 
* 	1 - all interventional cardiologists
* 	2 - all cardiothoracic surgeons
* 	3 - all other cardiologists
* Notes: requires cardiology as first specialty. Any indication of IVC or CTS moves 
* surgeon into groups 1 or 2; when there is overlap between these, primary specialty is chosen.
* 	- for now, groups 1 and 2 are "sticky" in that if surgeon is in group 1 or 2 in prior years, 
* 	- they cannot be in group 3 in later years. 

clear
gen npi = ""
gen year = . 
gen group = . 
save "$datadir/all_IVcardiologists.dta", replace
save "$datadir/all_CTsurgeons.dta", replace
save "$datadir/all_othercardiologists.dta", replace

forvalues y = 2010/2016 { 
	use /disk/aging/mdppas/data/harm/`y'/mdppas`y'.dta, clear
	gen year = `y'
	
	keep if inlist(spec_prim_1_name, "Advanced Heart Failure and Transplant", /// 
	"Cardiac Surgery", ///
	"Cardiovascular Disease (Cardiology)", ///
	"Interventional Cardiology", ///
	"Thoracic Surgery", ///
	"Vascular Surgery")
	
	gen group = 3
	replace group = 1 if spec_prim_1_name == "Interventional Cardiology" | ///
		spec_prim_2_name == "Interventional Cardiology"
	replace group = 2 if group == 3 & ///
		(spec_prim_1_name == "Cardiac Surgery" | ///
		spec_prim_2_name == "Cardiac Surgery" | ///
		spec_prim_1_name == "Thoracic Surgery" | ///
		spec_prim_2_name == "Thoracic Surgery")
	replace group = 2 if group == 1 & /// take primary specialty if both are listed
		(spec_prim_1_name == "Cardiac Surgery" | ///
		spec_prim_1_name == "Thoracic Surgery")
		
	// update groups based on previous years' assignments: 
	// specifically, if physician is in group 1 or 2 in past, they cannot now be in 3. 
	// If physician appears in both groups 1 and 2 in past, use most recent assignment --
	// note that since this is looping through years, can use iterative nature to only look at 
	// last year's assignment
	if (`y' > 2010) { 
		preserve
		use "$datadir/all_CTsurgeons.dta", clear
		append using "$datadir/all_IVcardiologists.dta"
		local y1 = `y' - 1
		di "y1 = `y1'"
		keep if year == `y1'
		keep npi group
		duplicates drop
		rename group group2
		save "$datadir/tomerge.dta", replace
		restore
		
		merge 1:1 npi using "$datadir/tomerge.dta", keep(1 3) 
		replace group = group2 if _merge == 3 & group == 3 
		drop group2 _merge
	}
	
	preserve
	keep if group == 1
	append using "$datadir/all_IVcardiologists"
	save "$datadir/all_IVcardiologists", replace
	restore
	preserve
	keep if group == 2
	append using "$datadir/all_CTsurgeons"
	save "$datadir/all_CTsurgeons", replace
	restore
	
	keep if group == 3
	append using "$datadir/all_othercardiologists"
	save "$datadir/all_othercardiologists", replace
}

rm "$datadir/tomerge.dta"
********************************************************************************


***** 2. Identify TAVR adoption
use "$datadir/all_as_ip", clear

*** First, go from SSA state/county to FIPS
gen ssacd = state_cd + cnty_cd
merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate

*** Now go from FIPS to CZ
rename fipsc FIPS
merge m:1 FIPS using "$geodata/CZs_Crosswalk", keep(1 3) keepusing(CommutingZoneID2000) nogenerate
rename Commuting CZID

*** Keep only TAVR
	* Identify TAVR-procedures (only in first 10 procs)
	gen tavr = 0
	forvalues i = 1/10 { 
		replace tavr = 1 if inlist(icd_prcdr_cd`i', "3505", "3506")
		replace tavr = 1 if substr(icd_prcdr_cd`i',1,5) == "02RF3" // ICD-10
		replace tavr = 1 if icd_prcdr_cd`i' == "X2A5312" // extra ICD-10
	}
keep if tavr == 1 

*** Identify unique number of individuals (attending or operating) in each CZ/year
expand 2, gen(new)
gen surgeon = op_npi
replace surgeon = at_npi if new == 1
gen surgery = 1
drop if missing(surgeon)

*** Collapse to year of adoption
rename surgeon npi
collapse (min) fyear_tavr=year, by(npi) fast

*** Merge in with each data set 
preserve
merge 1:m npi using "$datadir/all_IVcardiologists.dta", keep(2 3) nogenerate
save "$datadir/all_IVcardiologists.dta", replace
restore

preserve
merge 1:m npi using "$datadir/all_CTsurgeons.dta", keep(2 3) nogenerate
save "$datadir/all_CTsurgeons.dta", replace
restore

// move TAVR adopters out of group 3 
merge 1:m npi using "$datadir/all_othercardiologists.dta", keep(2 3)
bysort npi: ereplace _merge = max(_merge)
preserve
keep if _merge == 2
drop _merge
save "$datadir/all_othercardiologists.dta", replace
restore
drop if _merge == 2
drop _merge 

// try merging these in with group 2 if there is past info there; otherwise, group 1
preserve
collapse (min) fyear_tavr, by(npi) fast
merge 1:m npi using "$datadir/all_CTsurgeons", keep(3) nogenerate
keep npi
duplicates drop
save "$datadir/tomerge.dta", replace
restore

preserve
merge m:1 npi using "$datadir/tomerge.dta", keep(3) nogenerate
append using "$datadir/all_CTsurgeons.dta"
save "$datadir/all_CTsurgeons.dta", replace
restore

preserve
merge m:1 npi using "$datadir/tomerge.dta", keep(1) nogenerate
append using "$datadir/all_IVcardiologists.dta"
save "$datadir/all_IVcardiologists.dta", replace
restore

rm "$datadir/tomerge.dta"
********************************************************************************
