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
	use "$datadir/all_InpatientCardiology.dta", clear
	keep if group == 1 // only want IVC responses at this point
	merge m:1 icd_prcdr_cd1 using "$datadir/InterventionalCardiacProcedures", keep(3) nogenerate 
		// drop inpatient hospitalizations that aren't cardiology related
		
	// update ICD-10-PCS codes to ICD-9-PCS
	//note: right now, this only covers all ICD-10-PCS codes used by IVCs -- need to expand 
	// this is causing an inflation in late 2015 onwards due to switch to ICD-10. Need to figure out how to deal with this!
	// note: one possibility is (a) check that all procs are covered in ICD-10 and then (b) make sure you're collapsing to proc date in ES. 
	merge m:1 icd_prcdr_cd1 using "$datadir/InterventionalCardiacProcedures_ICDCrosswalk.dta", keep(1 3) nogenerate
	expand 5, generate(order) // this is easier than reshaping in this case
	gen oop = coin_amt + ded_amt
	keep group bene_id* clm_id from_dt provider prstate orgnpi*  at_* op_* stus_cd drg_cd admtg_dgns_cd prncpal_dgns*  /// 
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
	
	// Convert oop / paid amounts to 2021 USD
	gen year = year(from_dt) 
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
	drop year 

	// drop some useless procs that proliferate too much in ICD-10-PCS
	// drop if inlist(icd9, "0040", "0041", "0042", "0043", "0044") // these just indicate "a proc on a vessel"

	// merge in risk information 
	gen riskvar_yq = file_yq
	rename file_yq yq 
	merge m:1 bene_id riskvar_yq using "$datadir/PatientRisk", keep(3) nogenerate ///
		keepusing(predicted*)

	// overall, 1,094,451 procedures (1,066,942 are non-TAVR/non-SAVR)

	// Create quarter variable from from_dt
	gen yq = qofd(from_dt)
	format yq %tq
	
	// Create local-market information (for clustering) 
	// Current choice: CZ (need cite to justify this?)
	*** First, go from SSA state/county to FIPS
	gen ssacd = state_cd + cnty_cd
	merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate

	*** Now go from FIPS to CZ
	rename fipsc FIPS
	merge m:1 FIPS using "$geodata/CZs_Crosswalk", keep(1 3) keepusing(CommutingZoneID2000) nogenerate
	rename Commuting CZID // 0.19% of observations (979) missing CZID
	
	*** Finally, add in income information 
	rename FIPS fips_string
	drop if missing(fips_string) // drops 1,705 procedures
	merge m:1 fips_string yq using "$mydir/2_Data/Income/fips_income_ACS_5Year.dta", keep(3) nogenerate 
	destring medinc_hh, replace
	destring race_cd, replace 
	xtile incq = medinc_65plus, nq(5)
	
	// Income data based on qualifying subsidies/eligibility
	gen file_year = year
	merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfd/2010/bsfd2010.dta, ///
		keep(1 3) nogenerate keepusing(cstshr* rdsind* dual*) 
	forvalues y = 2011/2016 { 
		merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfd/`y'/bsfd`y'.dta, ///
			keep(1 3 4 5) nogenerate keepusing(cstshr* rdsind* dual*) update replace
	}
	destring dual_mo, replace // need to update data types
	merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfd/2017/bsfd0217.dta, ///
		keep(1 3 4 5) nogenerate keepusing(cstshr* rdsind* dual*) update replace
		
	*** Generate low-income variables
	// Use based on LIS at time of surgery 
	gen surgmonth = month(from_dt)
	tostring surgmonth, replace format("%02.0f")

	gen lis_eligible = 0 
	gen lis_enrol = 0 
	gen lis_premsub = 0 
	gen lis_copaysub = 0 

	forvalues m = 1/12 { 
		local mi = string(`m', "%02.0f")
		
		replace lis_eligible = 1 if inlist(cstshr`mi', "01", "02", "03") & surgmonth == "`mi'"
		replace lis_enrol = 1 if inlist(cstshr`mi', "04", "05", "06", "07", "08") & surgmonth == "`mi'"
		replace lis_premsub = 100 if inlist(cstshr`mi', "01", "02", "03", "04", "05") & surgmonth == "`mi'"
		replace lis_premsub = 75 if cstshr`mi' == "06" & surgmonth == "`mi'"
		replace lis_premsub = 50 if cstshr`mi' == "07" & surgmonth == "`mi'"
		replace lis_premsub = 25 if cstshr`mi' == "08" & surgmonth == "`mi'"
		replace lis_copaysub = 85 if inlist(cstshr`mi', "02", "05", "06", "07", "08") & surgmonth == "`mi'"
		replace lis_copaysub = 15 if inlist(cstshr`mi', "04", "03") & surgmonth == "`mi'"
		replace lis_copaysub = 100 if cstshr`mi' == "01" & surgmonth == "`mi'"
	}

	gen dual_mdcd = 0 
	gen dual_lowinc_mdcr = 0
	gen dual_other = 0 

	forvalues m = 1/12 { 
		local mi = string(`m', "%02.0f")
		
		replace dual_mdcd = 1 if inlist(dual_`mi', "02", "04") & surgmonth == "`mi'"
		replace dual_lowinc = 1 if inlist(dual_`mi', "01", "03") & surgmonth == "`mi'"
		replace dual_other = 1 if inlist(dual_`mi', "05", "06", "08") & surgmonth == "`mi'"
	}

	gen rds_ind = 0
	forvalues m = 1/12 { 
		local mi = string(`m', "%02.0f")
		
		replace rds_ind = 1 if rdsind`mi' == "Y" & surgmonth == "`mi'"
	}

	rename lis_* lowinc_lis_*
	rename dual_mdcd lowinc_dual_mdcd
	rename dual_lowinc lowinc_dual_mdcr
	rename dual_other lowinc_dual_other
	rename rds_ind lowinc_rds_ind

	drop cstshr* rdsind* dual* 

	compress
	save "$datadir/IVCEventStudy_Base.dta", replace
}
********************************************************************************


***** 2. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local margin = "`2'" // extensive = use of technique, intensive = average patient risk conditional on treatment 
local figname = "EventStudy_MDLevel_`1'Treatments_`2'Margin"

*** Identify treatment (first adoption of tavr) 
gen t_adopt = yq if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)

if ("`treatment'" == "high" & "`margin'" == "extensive") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1)
	collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (sum) num_procs allprocs (mean) t_adopt nCZID, by(at_npi yq) fast
	gen outcome = num_procs / allprocs * 100
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop if MD only does few procedures
}
else if ("`treatment'" == "high" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 
	
	keep if (tavr == 1 | savr == 1) // intensive margin only
	collapse (mean) predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) predicted_risk t_adopt nCZID, by(at_npi yq) fast
	rename predicted_risk outcome 
	replace outcome = outcome * 100
}
else if ("`treatment'" == "low" & "`margin'" == "extensive") {
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (sum) num_procs allprocs (mean) t_adopt nCZID, by(at_npi yq) fast
	gen outcome = num_procs / allprocs * 100
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop if MD only does 10 procedures
}
else if ("`treatment'" == "low" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 
	
	keep if (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty// intensive margin only
	collapse (mean) predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) predicted_risk t_adopt nCZID, by(at_npi yq) fast
	rename predicted_risk outcome 
	replace outcome = outcome * 100
}
else if ("`treatment'" == "all" & "`margin'" == "extensive") {
	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
			inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	// gen num_procs = (inlist(icd9, "3721", "3722", "3723", "3726", "8855", "8856")) // Cardiac Catheterization
	// gen num_procs = (inlist(icd9, "3794", "3795", "3796", "3797", "3798", "0050", "0051") | ///
	// 		inlist(icd9, "0052", "0053", "0054", "8945", "8946", "8947", "8948", "8949") | ///
	// 		inlist(icd9, "3770", "3771", "3772", "3773", "3774", "3775","3776") | ///
	// 		inlist(icd9,"3777","3778","3779") | ///
	// 		inlist(icd9, "3780", "3778", "3782", "3783", "3784", "3785") | ///
	// 		inlist(icd9,"3786","3787","3788","3789")) // Defibrillators/pacemakers
	replace num_procs = 1 if savr == 1 | tavr == 1
	collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (sum) num_procs allprocs (mean) t_adopt nCZID, by(at_npi yq) fast
	gen outcome = num_procs / allprocs * 100
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop if MD only does 10 procedures
}
else if ("`treatment'" == "all" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 
	
	keep if tavr == 1 | savr == 1 | /// All surgeries
		(inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty // intensive margin only
	collapse (mean) predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) predicted_risk t_adopt nCZID, by(at_npi yq) fast
	rename predicted_risk outcome 
	replace outcome = outcome * 100
}

do "$allcode/EventStudyFrag.do"

	// local for where to put the text label
	qui sum y 
	local mymin = r(min) 
	local mymax = r(max) 
	local myx = `mymax' * 0.05
	qui sum ub
	local myy = r(max) * 0.85

twoway (scatter coef y, color(maroon)) (line coef y, lcolor(ebblue)) /// 
	(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
	graphregion(color(white)) legend(off) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: $pretreat %", place(e))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace

// Save data for decomposition 
if ("`treatment'" == "low" & "`margin'" == "extensive") {
	save "$datadir/Low-Intensity-Intervention_Decomposition.dta", replace
}
********************************************************************************
