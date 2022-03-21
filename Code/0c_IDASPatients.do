/*******************************************************************************
* Title: Update flag for all patients with AS 
* Created by: Alex Hoagland
* Created on: 1/11/2022
* Last modified on: 3/2022
* Last modified by: 
* Purpose: 

* Notes: - uses files created in earlier code + outpatient files

* Key edits: 
*******************************************************************************/


***** 1. Start with universe of patients 
use "$datadir/all_InpatientCardiology.dta", clear
keep bene_id from_dt 
duplicates drop

// Pull AS claims from outpatient files 
forvalues yr = 2010/2017 { 
	di "***** MERGING CLAIMS FROM YEAR `yr' ******************************************************************************"
	
	preserve
	keep if year(from_dt) >= `yr' // keep all surgeries for which this year of OP data will be informative
	keep bene_id
	duplicates drop 
	merge 1:m bene_id using /disk/aging/medicare/data/harm/20pct/car/`yr'/carc`yr'.dta, ///
		keep(3) nogenerate
	gen tokeep = 0 
	forvalues i = 1/5 { 
		replace tokeep = 1 if inlist(icd_dgns_cd`i', "3950", "3951", "3952", "3959", ///
		"3960", "3961", "3962", "3963") | ///
		inlist(icd_dgns_cd`i', "3968", "3969", "3979", "4241") // ICD-9
		replace tokeep = 1 if inlist(substr(icd_dgns_cd`i',1,4), "I060", "I061", ///
			"I062", "I068", "I069", "I080", "I088", "I089") | ///
			inlist(icd_dgns_cd`i',"I350", "I351","I352") // ICD-10
	}
	keep if tokeep == 1
	keep bene_id 
	duplicates drop 
	gen as_flag = 1 
	gen year = `yr'
	save "$datadir/toappend_`yr'.dta", replace
	restore
}

********************************************************************************
