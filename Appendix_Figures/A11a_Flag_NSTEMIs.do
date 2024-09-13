/*******************************************************************************
* Title: Flag all inpatient NSTEMIs
* Created by: Alex Hoagland
* Created on: 6/28/2023
* Last modified on: 
* Last modified by: 
* Purpose: Identifies all inpatient NSTEMIs in the population (will eventually link to angiography and TAVR adoption at CZ level)

* Notes: 

* Key edits: 
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202101"
********************************************************************************


***** 0. Identify AS Patients 
// cap rm "$datadir/all_nstemi.dta"
cap confirm file "$datadir/all_nstemi.dta"
if (_rc == 0) {
	use "$datadir/all_nstemi.dta", clear
}
else { 
	clear
	gen bene_id = ""
	save "$mydir/all_nstemi.dta", replace

	forvalues yr = 2010/2017 { 
	di "YEAR: `yr'"
	use /disk/aging/medicare/data/harm/100pct/ip/`yr'/ipc`yr'.dta, clear


	* Keep only patients with NSTEMI diagnoses (in first 3 diagnoses)
	gen tokeep = 0 
	forvalues i = 1/3 {
		replace tokeep = 1 if inlist(icd_dgns_cd`i', "I214", "41071") 
	}
	keep if tokeep == 1
	
	* Keep only certain variables (patient id, treatments/diagnoses, providers, locations)
	keep bene_id clm_id from_dt thru_dt provider fi_num prstate orgnpinm at_npi op_npi ot_npi ///
	    stus_cd admtg_dgns_cd prncpal_dgns_cd icd_dgns_cd*  ///
	   icd_prcdr_cd* prcdr_dt* ime_* dob_dt gndr_cd bene_* ///
	   zip_cd state_cd cnty_cd
	gen year = `yr'
	
	* Combine and save
	append using "$mydir/all_nstemi.dta"
	compress
	save "$mydir/all_nstemi.dta", replace
	}
}
********************************************************************************