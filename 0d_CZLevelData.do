/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Start with set of all procedures
capture confirm file "$datadir/IVCEventStudy_Base.dta"
if (_rc != 0) { // Create file if need be
	use "$datadir/all_InpatientCardiology.dta" if group == 1, clear
	merge m:1 icd_prcdr_cd1 using "$datadir/InterventionalCardiacProcedures", keep(3) nogenerate 
		// drop inpatient hospitalizations that aren't cardiology related
		
	// update ICD-10-PCS codes to ICD-9-PCS 
	merge m:1 icd_prcdr_cd1 using "$datadir/InterventionalCardiacProcedures_ICDCrosswalk.dta", keep(1 3) nogenerate
	expand 5, generate(order) // this is easier than reshaping in this case
	gen oop = coin_amt + ded_amt
	// a bunch of variables to identify the "same" claim 
	keep group bene_id* clm_id surg_dt provider prstate orgnpi*  at_* op_* stus_cd drg_cd admtg_dgns_cd prncpal_dgns*  /// 
		icd_dgns_cd* icd_prcdr_cd* prcdr_dt* pmt_amt oop /// 
		dob_dt gndr_cd race_cd cnty_cd state_cd zip_cd as_flag tavr savr ptca* isivc* icd9_* order
	
	cap drop icd9
	order savr, last
	bysort bene_id-savr: replace order = _n
	drop if order > 5 // keeping only first 5 procs
	gen icd9 = icd_prcdr_cd1 if length(icd_prcdr_cd1) <= 4 & order == 1
	forvalues i = 1/5 { 
		replace icd9 = icd9_`i' if !missing(icd9_`i') & order == `i'
	}
	drop if missing(icd9)
	
	// collapse back to single procedure (using clm_id) 
	gen year = year(surg_dt) 
	gen yq = qofd(surg_dt)
	keep bene_id yq year surg_dt oop pmt_amt tavr savr icd9 *npi*  clm_id ptca* isivc* 
	bysort bene_id yq year surg_dt oop pmt_amt tavr savr *npi*  clm_id ptca* isivc*  (icd9) : gen i = _n 
	reshape wide icd9, i(bene_id surg_dt tavr savr clm_id  ptca* *npi*) j(i) 
	
	// Convert oop / paid amounts to 2021 USD
	drop if year < 2010
	foreach v of varlist oop pmt_amt { 
		replace `v' = `v' * 1.3011 if year == 2010
		replace `v' = `v' * 1.2613 if year == 2011
		replace `v' = `v' * 1.2357 if year == 2012
		replace `v' = `v' * 1.2179 if year == 2013
		replace `v' = `v' * 1.1984 if year == 2014
		replace `v' = `v' * 1.1970 if year == 2015
		replace `v' = `v' * 1.1821 if year == 2016
		replace `v' = `v' * 1.1575 if year == 2017
	}
	replace oop = 25000 if oop > 25000
	replace pmt_amt = 250000 if pmt_amt > 250000 // topcode both variables 
	
	// merge in information from all_SurgicalCandidates 
	merge m:1 bene_id yq using "$datadir/all_SurgicalCandidates.dta", keep(3 ) nogenerate
	
	compress
	save "$datadir/IVCEventStudy_Base.dta", replace
}
********************************************************************************
