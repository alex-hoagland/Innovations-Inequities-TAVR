
***** Pull all AS Diagnoses
forvalues yr = 2010/2017 { 
	di "***** MERGING CLAIMS FROM YEAR `yr' ******************************************************************************"
	
	use /disk/aging/medicare/data/harm/20pct/car/`yr'/carc`yr'.dta, ///
		clear
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
	keep bene_id icd_dgns_cd* 
	duplicates drop 
	gen year = `yr'
	save "$datadir/toappend_`yr'.dta", replace
}



***** Pull some PCI-related Diagnoses
forvalues yr = 2010/2017 { 
	di "***** MERGING CLAIMS FROM YEAR `yr' ******************************************************************************"
	
	use /disk/aging/medicare/data/harm/20pct/car/`yr'/carc`yr'.dta, ///
		clear
	gen tokeep = 0 
	forvalues i = 1/5 { 
		replace tokeep = 1 if inlist(icd_dgns_cd`i', "41001", "41011", "41021", "41031", "41041", "41051", "41071") | ///
		inlist(icd_dgns_cd`i', "41091", "41400", "41401", "41402", "43310", "99672", "I2102") | ///
		inlist(icd_dgns_cd`i',"I2109", "I2111", "I2119", "I213", "I214", "I2510", "I25110") | ///
		inlist(icd_dgns_cd`i', "I25119" , "T82855A") 
	}
	keep if tokeep == 1
	keep bene_id icd_dgns_cd* 
	duplicates drop 
	gen year = `yr'
	save "$datadir/toappend2_`yr'.dta", replace
}

// append, pull out those with surgeries
use "$datadir/toappend_2010", clear
append using "$datadir/toappend2_2010"
forvalues y = 2011/2017 { 
	append using "$datadir/toappend_`y'"
	append using "$datadir/toappend2_`y'"
}
duplicates drop

// add in those from inpatient cardiology
rename year file_year
append using "$datadir/all_InpatientCardiology", keep(bene_id icd_dgns_cd* file_year)
keep bene_id file_year icd_dgns_cd1 icd_dgns_cd2 icd_dgns_cd3 icd_dgns_cd4 icd_dgns_cd5 // just five dxs per claim 
bysort bene_id file_year: gen j = _n
reshape long icd_dgns_cd, i(bene_id file_year j) j(dxnum) 
drop if missing(icd_dgns_cd)
drop j dxnum
duplicates drop

// now create a single observation for each enrolid-year
bysort bene_id file_year: gen j = _n
reshape wide icd_dgns_cd, i(bene_id file_year) j(j)
sort bene_id file_year

// flag those with TAVR/SAVR or PCI surgeries -- not only from IVCs!
preserve
	use "$datadir/all_InpatientCardiology.dta", clear
	merge m:1 icd_prcdr_cd1 using "$datadir/InterventionalCardiacProcedures", keep(3) nogenerate 
		// drop inpatient hospitalizations that aren't cardiology related
		
	// update ICD-10-PCS codes to ICD-9-PCS
	//note: right now, this only covers all ICD-10-PCS codes used by IVCs -- need to expand 
	// this is causing an inflation in late 2015 onwards due to switch to ICD-10. Need to figure out how to deal with this!
	// note: one possibility is (a) check that all procs are covered in ICD-10 and then (b) make sure you're collapsing to proc date in ES. 
	merge m:1 icd_prcdr_cd1 using "$datadir/InterventionalCardiacProcedures_ICDCrosswalk.dta", keep(1 3) nogenerate
	expand 5, generate(order) // this is easier than reshaping in this case
	gen oop = coin_amt + ded_amt
	keep group bene_id* *year* clm_id from_dt provider prstate orgnpi*  at_* op_* stus_cd drg_cd admtg_dgns_cd prncpal_dgns*  /// 
		icd_dgns_cd* icd_prcdr_cd* prcdr_dt* pmt_amt oop /// 
		dob_dt gndr_cd race_cd cnty_cd state_cd zip_cd as_flag tavr savr icd9_* order
	
	cap drop icd9
	bysort bene_id-savr: replace order = _n
	drop if order > 5 // keeping only first 5 procs
	gen icd9 = icd_prcdr_cd1 if length(icd_prcdr_cd1) <= 4 & order == 1
	forvalues i = 1/5 { 
		replace icd9 = icd9_`i' if !missing(icd9_`i') & order == `i'
	}
	drop if missing(icd9)

	gen anyproc = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514") | tavr == 1 | savr == 1) // Valvuloplasty
	gen surgery = (tavr == 1 | savr == 1)
	collapse (max) anyproc surgery, by(bene_id file_year) fast
	keep if anyproc == 1
	gen pci = (surgery == 0)
	duplicates drop 
	compress
	save "$datadir/tomerge.dta", replace
restore

merge 1:1 bene_id file_year using "$datadir/tomerge.dta", nogenerate

// fill in all years before surgeries, flag or take out years after a surgery? 
gen postproc = file_year if anyproc == 1
bysort bene_id: ereplace postproc = min(postproc)
replace postproc = 1 if file_year >= postproc & !missing(postproc)
drop icd* 

preserve
fillin bene_id file_year
bysort bene_id (file_year): carryforward postproc, replace
drop if postproc == 1
keep if _fillin == 1
keep bene_id file_year 
forvalues yr = 2010/2017 { 
	di "********** YEAR: `yr' ***********"
	merge 1:m bene_id file_year using /disk/aging/medicare/data/harm/20pct/car/`yr'/carc`yr'.dta, keep(1 3)
	drop if file_year == `yr' & _merge == 1
	keep bene_id file_year 
	duplicates drop 
}
save "$datadir/tomerge.dta", replace
restore

append using "$datadir/tomerge.dta"
sort bene_id file_year
bysort bene_id (file_year): carryforward postproc, replace
compress
save "$datadir/EnrolleeSample_202203.dta", replace

// Start pulling all DXs for risk scores? 

// Predict patient risks
rename file_year riskvar_year
merge 1:1 bene_id riskvar_year using "$datadir/PatientRisk.dta", keep(1 3) nogenerate 
drop rfrnc_yr-seqnumbsfcc2011
save "$datadir/EnrolleeSample_202203.dta", replace 
