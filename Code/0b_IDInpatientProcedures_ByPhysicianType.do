/*******************************************************************************
* Title: ID Inpatient Procs by Cardiologist Type
* Created by: Alex Hoagland
* Created on: 1/11/2022
* Last modified on: 3/2022
* Last modified by: 
* Purpose: Identifies all Inpatient Procedures involving cardiologists

* Notes: - uses files created in 1_IDPhysicianTypes.do

* Key edits: 
*******************************************************************************/


***** 1. Pull inpatient claims
*** Create a key of groups by NPI, group, year
use "$datadir/all_IVcardiologists", clear
append using "$datadir/all_CTsurgeons.dta"
append using "$datadir/all_othercardiologists.dta"
keep npi group
duplicates drop

bysort npi: gen test = _N
drop if group == 3 & test > 1
bysort npi: replace test = _N
drop if test > 1 // drops 5 MDs who are both IVCs and CTs at different points in time
drop test

save "$datadir/tomerge.dta", replace

*** Now pull claims with those NPIs as either attending or operating physicians
// rm "$datadir/all_InpatientCardiology.dta"
cap confirm file "$datadir/all_InpatientCardiology.dta"
if (_rc == 0) {
	use "$datadir/all_InpatientCardiology.dta", clear
}
else { 
	clear
	gen bene_id = ""
	save "$datadir/all_InpatientCardiology.dta"
	
	forvalues yr = 2010/2017 { 
	di "YEAR: `yr'"
	di "Using ATTENDING NPIs"
	use "$datadir/tomerge", clear
	rename npi at_npi
	merge 1:m at_npi using /disk/aging/medicare/data/harm/100pct/ip/`yr'/ipc`yr'.dta, ///
		keep(3) nogenerate
	
	* Flag patients with aortic stenosis diagnoses (only in first 3 diagnoses)
	gen as_flag = 0 
	forvalues i = 1/3 {
		replace as_flag = 1 if inlist(icd_dgns_cd`i', "3950", "3951", "3952", "3959", ///
		"3960", "3961", "3962", "3963") | ///
		inlist(icd_dgns_cd`i', "3968", "3969", "3979", "4241") // ICD-9
		replace as_flag = 1 if inlist(substr(icd_dgns_cd`i',1,4), "I060", "I061", ///
			"I062", "I068", "I069", "I080", "I088", "I089") | ///
			inlist(icd_dgns_cd`i',"I350", "I351","I352") // ICD-10
	}

	* Identify TAVR-procedures (only in first 10 procs)
	gen tavr = 0
	forvalues i = 1/10 { 
		replace tavr = 1 if inlist(icd_prcdr_cd`i', "3505", "3506")
		replace tavr = 1 if substr(icd_prcdr_cd`i',1,5) == "02RF3" | ///
			substr(icd_prcdr_cd`i',1,5) == "02RF4" // ICD-10
		replace tavr = 1 if icd_prcdr_cd`i' == "X2A5312" // extra ICD-10
	}
		
	* Identify SAVR procedures (only in first 10 procs)
	gen savr = 0
	forvalues i = 1/10 { 
		replace savr = 1 if inlist(icd_prcdr_cd`i', "3521", "3522") // ICD-9
		replace savr = 1 if substr(icd_prcdr_cd`i',1,5) == "02RF0" // ICD-10
	}
	
// 	* Keep only certain variables (patient id, treatments/diagnoses, providers, locations)
// 	keep bene_id clm_id from_dt thru_dt provider fi_num prstate orgnpinm at_npi op_npi ot_npi ///
// 	    stus_cd admtg_dgns_cd prncpal_dgns_cd icd_dgns_cd*  ///
// 	   icd_prcdr_cd* prcdr_dt* ime_* dob_dt gndr_cd bene_* ///
// 	   zip_cd state_cd cnty_cd
// 	gen year = `yr'
	
	* Combine and save
	append using "$datadir/all_InpatientCardiology.dta"
	compress
	save "$datadir/all_InpatientCardiology.dta", replace

	use "$datadir/tomerge", clear
	di "YEAR `yr': Using OPERATING NPIs"
	rename npi op_npi
	merge 1:m op_npi using /disk/aging/medicare/data/harm/100pct/ip/`yr'/ipc`yr'.dta, ///
		keep(3) nogenerate
	
	* Flag patients with aortic stenosis diagnoses (only in first 3 diagnoses)
	gen as_flag = 0 
	forvalues i = 1/3 {
		replace as_flag = 1 if inlist(icd_dgns_cd`i', "3950", "3951", "3952", "3959", ///
		"3960", "3961", "3962", "3963") | ///
		inlist(icd_dgns_cd`i', "3968", "3969", "3979", "4241") // ICD-9
		replace as_flag = 1 if inlist(substr(icd_dgns_cd`i',1,4), "I060", "I061", ///
			"I062", "I068", "I069", "I080", "I088", "I089") | ///
			inlist(icd_dgns_cd`i',"I350", "I351","I352") // ICD-10
	}

	* Identify TAVR-procedures (only in first 10 procs)
	gen tavr = 0
	forvalues i = 1/10 { 
		replace tavr = 1 if inlist(icd_prcdr_cd`i', "3505", "3506")
		replace tavr = 1 if substr(icd_prcdr_cd`i',1,5) == "02RF3" | ///
			substr(icd_prcdr_cd`i',1,5) == "02RF4" // ICD-10
		replace tavr = 1 if icd_prcdr_cd`i' == "X2A5312" // extra ICD-10
	}
		
	* Identify SAVR procedures (only in first 10 procs)
	gen savr = 0
	forvalues i = 1/10 { 
		replace savr = 1 if inlist(icd_prcdr_cd`i', "3521", "3522") // ICD-9
		replace savr = 1 if substr(icd_prcdr_cd`i',1,5) == "02RF0" // ICD-10
	}
	
// 	* Keep only certain variables (patient id, treatments/diagnoses, providers, locations)
// 	keep bene_id clm_id from_dt thru_dt provider fi_num prstate orgnpinm at_npi op_npi ot_npi ///
// 	    stus_cd admtg_dgns_cd prncpal_dgns_cd icd_dgns_cd*  ///
// 	   icd_prcdr_cd* prcdr_dt* ime_* dob_dt gndr_cd bene_* ///
// 	   zip_cd state_cd cnty_cd
// 	gen year = `yr'
	
	* Combine and save
	append using "$datadir/all_InpatientCardiology.dta"
	save "$datadir/all_InpatientCardiology.dta", replace
	}
	
duplicates drop
compress
save "$datadir/all_InpatientCardiology.dta", replace
}

rm "$datadir/tomerge.dta"
********************************************************************************
