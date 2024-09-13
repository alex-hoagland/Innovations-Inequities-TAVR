/*******************************************************************************
* Title: ID eligible angiography within 72 hours of all inpatient NSTEMIs
* Created by: Alex Hoagland
* Created on: 6/28/2023
* Last modified on: 
* Last modified by: 
* Purpose: Identifies links all inpatient NSTEMIs in the population to angiography performed within 72 hours

* Notes: Angiogram CPT codes are 75625, 75630, 75635, 75658, 75705, 75710, 75716, 75726, 75731, 75733, 75736, 75741, 75743, 75746

* Key edits: 
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202101"
********************************************************************************


***** 0. Identify all NSTEMI patients, keep all of their angioplasties
cap confirm file "$mydir/all_nstemi_pats.dta"
if (_rc != 0) {
	use "$mydir/all_nstemi.dta", clear
	keep bene_id 
	duplicates drop
	compress
	save "$mydir/all_nstemi_pats.dta", replace
}

// cap rm "$mydir/all_angiogram.dta"
cap confirm file "$mydir/all_angiogram.dta"
if (_rc == 0) {
	use "$mydir/all_angiogram.dta", clear
}
else { 
	clear
	gen bene_id = ""
	save "$mydir/all_angiogram.dta", replace

forvalues yr = 2010/2017 { 
	di "YEAR: `yr'"
	use "$mydir/all_nstemi_pats.dta", clear
	merge 1:m bene_id using "/disk/aging/medicare/data/harm/100pct/ip/`yr'/ipc`yr'.dta", keep(3) nogenerate

	* Keep only patients with angiogram procedure codes (in first 5 codes)
	gen tokeep = 0 
	forvalues i = 1/5 {
		replace tokeep = 1 if inlist(icd_prcdr_cd`i', "8852", "8853", "8854", "8855", "8856", "8857") // ICD-9-PCS
		replace tokeep = 1 if inlist(substr(icd_prcdr_cd`i', 1, 3), "B21", "B31", "B41", "B51") // ICD-10-PCS
	}
	keep if tokeep == 1
	
	* Keep only certain variables (patient id, treatments/diagnoses, providers, locations)
	keep bene_id clm_id from_dt thru_dt provider fi_num prstate orgnpinm at_npi op_npi ot_npi ///
	    stus_cd admtg_dgns_cd prncpal_dgns_cd icd_dgns_cd*  ///
	   icd_prcdr_cd* prcdr_dt* ime_* dob_dt gndr_cd bene_* ///
	   zip_cd state_cd cnty_cd
	gen year = `yr'
	
	* Combine and save
	append using "$mydir/all_angiogram.dta"
	compress
	save "$mydir/all_angiogram.dta", replace
	}
}
********************************************************************************


***** 1. Now link angiograms to NSTEMIs within 72 hours *****
// angiogram procedure dates are well documented
//keep bene_id icd_prcdr_cd* prcdr_dt* 
//bysort bene_id (prcdr_dt1): gen n = _n
//reshape long icd_prcdr_cd prcdr_dt, i(bene_id n) j(procnum) 
//drop if missing(icd_prcdr_cd) 
//drop n 
//keep if inlist(icd_prcdr_cd, "8852", "8853", "8854", "8855", "8856", "8857") | /// ICD-9-PCS
//	inlist(substr(icd_prcdr_cd, 1, 3), "B21", "B31", "B41", "B51") // ICD-10-PCS

//keep bene_id prcdr_dt
//duplicates drop
//save "$mydir/tomerge.dta" 

// now merge this in to the sample of NSTEMIs
//use "$mydir/all_nstemi.dta", clear
//keep bene_id clm_id from_dt thru_dt // merge the others back later
//bysort bene_id (from_dt): gen n = _n 
//reshape wide clm_id from_dt thru_dt, i(bene_id) j(n) 
//merge 1:m bene_id using "$mydir/tomerge.dta", keep(1 3) nogenerate

//reshape long clm_id from_dt thru_dt, i(bene_id prcdr_dt) j(nstemi_num) 

use "$mydir/tomerge2.dta", clear // done in pieces
drop if missing(clm_id) 
replace prcdr_dt = . if prcdr_dt < from_dt // don't count any angiograms before the NSTEMI
gen ang_intime = 0
replace ang_intime = 1 if inrange(prcdr_dt, from_dt, thru_dt + 3) // count any that occur within 72 hours of discharge for NSTEMI
gen year = year(from_dt)

// now collapse to level of each NSTEMI
gcollapse (max) ang_intime, by(bene_id clm_id from_dt thru_dt) fast

merge 1:1 bene_id clm_id from_dt thru_dt using "$mydir/all_nstemi.dta", keep(2 3) nogenerate
replace ang_intime = 0 if missing(ang_intime)

compress
save "$mydir/linked_nstemi_angiograms.dta", replace

rm "$mydir/tomerge.dta" 
rm "$mydir/tomerge2.dta" 
********************************************************************************