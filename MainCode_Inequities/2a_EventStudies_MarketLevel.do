/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes: Market Level 
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: // remember to clean out directory of figures each time BEFORE RUNNING 
	 - look at comparable procs performed by IVCs
	 - look at overall surgeon volume
	 - eventually, see if race/income affected this (both surgeon and patient)
	 - regression approach: event study (initial adoption) and treatment intensity (# of surgeries?)

* Key edits: - todo: decide on timing (more granular than a year?)
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202105"
global geodata "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/Geography"
global output "$mydir/ToExport/MainFigures"
********************************************************************************


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
	keep group bene_id* clm_id from_dt provider prstate orgnpi*  at_* op_* stus_cd drg_cd admtg_dgns_cd prncpal_dgns* icd_dgns_cd* icd_prcdr_cd* prcdr_dt* ///
		dob_dt gndr_cd race_cd cnty_cd state_cd zip_cd file_year as_flag tavr savr icd9_* order
	
	cap drop icd9
	bysort bene_id-savr: replace order = _n
	drop if order > 5 // keeping only first 5 procs
	gen icd9 = icd_prcdr_cd1 if length(icd_prcdr_cd1) <= 4 & order == 1
	forvalues i = 1/5 { 
		replace icd9 = icd9_`i' if !missing(icd9_`i') & order == `i'
	}
	drop if missing(icd9)

	// drop some useless procs that proliferate too much in ICD-10-PCS
	// drop if inlist(icd9, "0040", "0041", "0042", "0043", "0044") // these just indicate "a proc on a vessel"

	// merge in risk information 
	gen riskvar_year = file_year
	rename file_year year 
	merge m:1 bene_id riskvar_year using "$datadir/PatientRisk", keep(3) nogenerate ///
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
	merge m:1 fips_string year using "$mydir/2_Data/Income/fips_income.dta", keep(1 3) 
		// note that almost 1/4 of counties are missing here, need to check
	drop if _merge == 1  // for now
	drop _merge

	destring race_cd, replace 
	xtile incq = medinc_65plus, nq(5)

	save "$datadir/IVCEventStudy_Base.dta", replace
}
********************************************************************************


***** 2. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear

// drop if year >= 2016 // 2016 makes things weird -- why?
local treatment = "high" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents) 
local margin = "intensive" // extensive = use of technique, intensive = average patient risk conditional on treatment 

preserve
if ("`treatment'" == "high" & "`margin'" == "extensive") { 
	// Construct outcome: aggregate count of procedure at surgeon-year level
	*** Identify treatment (first adoption of tavr) 
	gen t_adopt = yq if tavr == 1
	bysort at_npi: ereplace t_adopt = min(t_adopt)

	gen num_procs = (tavr == 1 | savr == 1)
	collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1
	collapse (sum) num_procs allprocs (mean) t_adopt CZID, by(at_npi yq) fast
	gen outcome = num_procs / allprocs * 100
	gen todrop = (allprocs < 10) // drop those with fewest procs
	bysort at_npi yq: ereplace todrop = max(todrop)
	drop if todrop == 1

	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	qui gen period_yq = yq -  t_adopt if treated == 1

	*** Gen dummy variables
	qui sum period_yq
	local mymin = `r(min)'*-1
	local mymax = `r(max)'

	forvalues  i = 0/`mymax' { 
		qui gen dummy_`i' = (period_yq == `i' & treated == 1)
	}
	forvalues i = 2/`mymin' { 
		local j = `i' * -1
		qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
	}
	rename dummy_neg_`mymin' dropdummy 

	// Store mean before treatment 
	sum outcome if period_yq < 0 | missing(period_yq), d
	local pretreat = r(mean)

	// Run regression 
	reghdfe outcome dummy*, absorb(at_npi yq) vce(cluster CZID) 

	// Graph results
	regsave
	drop if strpos(var,"o.")
	keep if strpos(var, "dummy")
	gen y = substr(var, 11, .)
	destring y, replace
	replace y = y * -1
	replace y = real(substr(var, 7, .)) if missing(y)
	local obs = _N+1
	set obs `obs'
	replace y = -1 in `obs'
	replace coef = 0 in `obs'
	replace stderr = 0 in `obs'
	gen lb = coef - 1.96*stderr
	gen ub = coef + 1.96*stderr
	
	// keep only 4 years pre-/post-adoption
	drop if abs(y) > 16

		// local for where to put the text label
		qui sum y 
		local mymin = r(min) 
		local mymax = r(max) 
		local myx = `mymax' * 0.05
		qui sum ub
		local myy = r(max) * 0.85

	sort y 
	twoway (scatter coef y, color(maroon)) (line coef y, lcolor(ebblue)) /// 
		(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
		graphregion(color(white)) legend(off) ///
		xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
		xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
		ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))

	// Save graphs
	graph save "$output/EventStudyQ_High-Intensity-Intervention_ExtensiveMargin.gph", replace
	graph export "$output/EventStudyQ_High-Intensity-Intervention_ExtensiveMargin.gph", as(png) replace

}
else if ("`treatment'" == "high" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	*** Identify treatment (first adoption of tavr) 
	gen t_adopt = yq if tavr == 1
	bysort at_npi: ereplace t_adopt = min(t_adopt)

	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi yq: ereplace allprocs = total(allprocs)
	gen todrop = (allprocs < 10)
	bysort at_npi yq: ereplace todrop = max(todrop)
	drop if todrop == 1
	keep if (tavr == 1 | savr == 1) // intensive margin only
	collapse (mean) predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	collapse (mean) predicted_risk t_adopt CZID, by(at_npi yq) fast
	rename predicted_risk outcome 
	replace outcome = outcome * 100

	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	qui gen period_yq = yq -  t_adopt if treated == 1

	*** Gen dummy variables
	qui sum period_yq
	local mymin = `r(min)'*-1
	local mymax = `r(max)'

	forvalues  i = 0/`mymax' { 
		qui gen dummy_`i' = (period_yq == `i' & treated == 1)
	}
	forvalues i = 2/`mymin' { 
		local j = `i' * -1
		qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
	}
	rename dummy_neg_`mymin' dropdummy 

	// Store mean before treatment 
	sum outcome if period_yq < 0 | missing(period_yq), d
	local pretreat = r(mean)

	// Run regression 
	reghdfe outcome dummy*, absorb(at_npi yq) vce(cluster CZID) 

	// Graph results
	regsave
	drop if strpos(var,"o.")
	keep if strpos(var, "dummy")
	gen y = substr(var, 11, .)
	destring y, replace
	replace y = y * -1
	replace y = real(substr(var, 7, .)) if missing(y)
	local obs = _N+1
	set obs `obs'
	replace y = -1 in `obs'
	replace coef = 0 in `obs'
	replace stderr = 0 in `obs'
	gen lb = coef - 1.96*stderr
	gen ub = coef + 1.96*stderr
	
	// keep only 4 years pre-/post-adoption
	drop if abs(y) > 16

		// local for where to put the text label
		qui sum y 
		local mymin = r(min) 
		local mymax = r(max) 
		local myx = `mymax' * 0.05
		qui sum ub
		local myy = r(max) * 0.85

	sort y 
	twoway (scatter coef y, color(maroon)) (line coef y, lcolor(ebblue)) /// 
		(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
		graphregion(color(white)) legend(off) ///
		xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
		xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
		ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))

	// Save graphs
	graph save "$output/EventStudyQ_High-Intensity-Intervention_IntensiveMargin.gph", replace
	graph export "$output/EventStudyQ_High-Intensity-Intervention_IntensiveMargin.gph", as(png) replace
}
else if ("`treatment'" == "low" & "`margin'" == "extensive") {
		// Construct outcome: aggregate count of procedure at surgeon-year level
	*** Identify treatment (first adoption of tavr) 
	gen t_adopt = yq if tavr == 1
	bysort at_npi: ereplace t_adopt = min(t_adopt)

	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1
	collapse (sum) num_procs allprocs (mean) t_adopt CZID, by(at_npi yq) fast
	gen outcome = num_procs / allprocs * 100
		gen todrop = (allprocs < 10) // drop those with fewest procs
	bysort at_npi yq: ereplace todrop = max(todrop)
	drop if todrop == 1

	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	qui gen period_yq = yq -  t_adopt if treated == 1

	*** Gen dummy variables
	qui sum period_yq
	local mymin = `r(min)'*-1
	local mymax = `r(max)'

	forvalues  i = 0/`mymax' { 
		qui gen dummy_`i' = (period_yq == `i' & treated == 1)
	}
	forvalues i = 2/`mymin' { 
		local j = `i' * -1
		qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
	}
	rename dummy_neg_`mymin' dropdummy 

	// Store mean before treatment 
	sum outcome if period_yq < 0 | missing(period_yq), d
	local pretreat = r(mean)

	// Run regression 
	reghdfe outcome dummy*, absorb(at_npi yq) vce(cluster CZID) 

	// Graph results
	regsave
	drop if strpos(var,"o.")
	keep if strpos(var, "dummy")
	gen y = substr(var, 11, .)
	destring y, replace
	replace y = y * -1
	replace y = real(substr(var, 7, .)) if missing(y)
	local obs = _N+1
	set obs `obs'
	replace y = -1 in `obs'
	replace coef = 0 in `obs'
	replace stderr = 0 in `obs'
	gen lb = coef - 1.96*stderr
	gen ub = coef + 1.96*stderr
	
	// keep only 4 years pre-/post-adoption
	drop if abs(y) > 16

		// local for where to put the text label
		qui sum y 
		local mymin = r(min) 
		local mymax = r(max) 
		local myx = `mymax' * 0.05
		qui sum ub
		local myy = r(max) * 0.85

	sort y 
	twoway (scatter coef y, color(maroon)) (line coef y, lcolor(ebblue)) /// 
		(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
		graphregion(color(white)) legend(off) ///
		xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
		xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
		ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))

	// Save graphs
	graph save "$output/EventStudyQ_Low-Intensity-Intervention_ExtensiveMargin.gph", replace
	graph export "$output/EventStudyQ_Low-Intensity-Intervention_ExtensiveMargin.gph", as(png) replace
	
	// save data to make decomposition graph 
	save "$datadir/Low-Intensity-Intervention_Decomposition.dta", replace
}
else if ("`treatment'" == "low" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	*** Identify treatment (first adoption of tavr) 
	gen t_adopt = yq if tavr == 1
	bysort at_npi: ereplace t_adopt = min(t_adopt)

	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi yq: ereplace allprocs = total(allprocs)
	gen todrop = (allprocs < 10)
	bysort at_npi yq: ereplace todrop = max(todrop)
	drop if todrop == 1
	keep if (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty// intensive margin only
	collapse (mean) predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	collapse (mean) predicted_risk t_adopt CZID, by(at_npi yq) fast
	rename predicted_risk outcome 
	replace outcome = outcome * 100

	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	qui gen period_yq = yq -  t_adopt if treated == 1

	*** Gen dummy variables
	qui sum period_yq
	local mymin = `r(min)'*-1
	local mymax = `r(max)'

	forvalues  i = 0/`mymax' { 
		qui gen dummy_`i' = (period_yq == `i' & treated == 1)
	}
	forvalues i = 2/`mymin' { 
		local j = `i' * -1
		qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
	}
	rename dummy_neg_`mymin' dropdummy 

	// Store mean before treatment 
	sum outcome if period_yq < 0 | missing(period_yq), d
	local pretreat = r(mean)

	// Run regression 
	reghdfe outcome dummy*, absorb(at_npi yq) vce(cluster CZID) 

	// Graph results
	regsave
	drop if strpos(var,"o.")
	keep if strpos(var, "dummy")
	gen y = substr(var, 11, .)
	destring y, replace
	replace y = y * -1
	replace y = real(substr(var, 7, .)) if missing(y)
	local obs = _N+1
	set obs `obs'
	replace y = -1 in `obs'
	replace coef = 0 in `obs'
	replace stderr = 0 in `obs'
	gen lb = coef - 1.96*stderr
	gen ub = coef + 1.96*stderr
	
	// keep only 4 years pre-/post-adoption
	drop if abs(y) > 16

		// local for where to put the text label
		qui sum y 
		local mymin = r(min) 
		local mymax = r(max) 
		local myx = `mymax' * 0.05
		qui sum ub
		local myy = r(max) * 0.85

	sort y 
	twoway (scatter coef y, color(maroon)) (line coef y, lcolor(ebblue)) /// 
		(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
		graphregion(color(white)) legend(off) ///
		xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
		xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
		ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))

	// Save graphs
	graph save "$output/EventStudyQ_Low-Intensity-Intervention_IntensiveMargin.gph", replace
	graph export "$output/EventStudyQ_Low-Intensity-Intervention_IntensiveMargin.gph", as(png) replace
}
restore
********************************************************************************


***** 3. Overall volume: SAVR/TAVR + PCI
use "$datadir/IVCEventStudy_Base.dta", clear
gen t_adopt = yq if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)

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
collapse (sum) num_procs allprocs (mean) t_adopt CZID, by(at_npi yq) fast
gen outcome = num_procs / allprocs * 100
gen todrop = (allprocs < 10) // drop those with fewest procs
bysort at_npi yq: ereplace todrop = max(todrop)
drop if todrop == 1

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
qui gen period_yq = yq -  t_adopt if treated == 1

*** Gen dummy variables
qui sum period_yq
local mymin = `r(min)'*-1
local mymax = `r(max)'

forvalues  i = 0/`mymax' { 
	qui gen dummy_`i' = (period_yq == `i' & treated == 1)
}
forvalues i = 2/`mymin' { 
	local j = `i' * -1
	qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
}
rename dummy_neg_`mymin' dropdummy 

// Store mean before treatment 
sum outcome if period_yq < 0 | missing(period_yq), d
local pretreat = r(mean)

// Run regression 
reghdfe outcome dummy*, absorb(at_npi yq) vce(cluster CZID) 

// Graph results
regsave
keep if strpos(var, "dummy")
gen y = substr(var, 11, .)
destring y, replace
replace y = y * -1
replace y = real(substr(var, 7, .)) if missing(y)
local obs = _N+1
set obs `obs'
replace y = -1 in `obs'
replace coef = 0 in `obs'
replace stderr = 0 in `obs'
gen lb = coef - 1.96*stderr
gen ub = coef + 1.96*stderr

	// local for where to put the text label
	qui sum y 
	local mymin = r(min) 
	local mymax = r(max) 
	local myx = `mymax' * 0.05
	qui sum ub
	local myy = r(max) * 0.85

sort y 
twoway (scatter coef y, color(maroon)) (line coef y, lcolor(ebblue)) /// 
	(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
	graphregion(color(white)) legend(off) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))

// Save graphs
graph save "$output/EventStudyQ_AllProcs.gph", replace
graph export "$output/EventStudyQ_AllProcs", as(pdf) replace
********************************************************************************
