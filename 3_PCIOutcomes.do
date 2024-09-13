/*******************************************************************************
* Title: ID Effect of TAVR Adoption on PCI Outcomes
* Created by: Alex Hoagland
* Created on: 7/30/2024
* Last modified on: 8/1/2024
* Last modified by: 
* Purpose: 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Pull surgical complications + mortality (at time of admission + 30 days) of PCI
clear
gen bene_id = ""
save "$datadir/PCI_complications.dta", replace 

forvalues i = 2010/2017 {
	di  "***** WORKING ON YEAR `i' *******"
	use bene_id using "$datadir/IVCEventStudy_Base.dta", clear
	duplicates drop 
	merge 1:m bene_id using ///
		/disk/aging/medicare/data/harm/100pct/ip/`i'/ipc`i'.dta, ///
		keep(3) nogenerate keepusing(bene_id *dt* icd_dgns_cd* icd_prcdr_cd*)

	gen comp_tamponade = 0 // this can happen at the time of PCI or within 30 days
	forvalues i = 1/25 { // look at all diagnosis codes
		replace comp_tamponade = 1 if inlist(icd_dgns_cd`i', "4233", "I3131", "I3139", "I314") // tamponade
	}
	gen comp_thrombosis = 0 // should look at follow-up admissions within 30 days *or* at time of PCI
	forvalues i = 1/25 { // look at all diagnosis codes
		replace comp_thrombosis = 1 if inlist(substr(icd_dgns_cd`i',1,3), "451", "I80", "452", "I81", "453", "I82") // deep-vein thrombosis
	}
	gen comp_restonsis = 0 // need to look at this between 31 and 365 days 
	forvalues i = 1/25 { // look at all diagnosis codes
		replace comp_restonsis = 1 if inlist(substr(icd_prcdr_cd`i',1,2), "36") // PCA, ICD-9
		replace comp_restonsis = 1 if ///
			inlist(icd_prcdr_cd`i', "02100ZZ", "021009Z", "021008Z", "02100YZ", "02100WZ") | ///
			inlist(icd_prcdr_cd`i', "02110ZZ", "021109Z", "021108Z", "02110YZ", "02110WZ") | ///
			inlist(icd_prcdr_cd`i', "02120ZZ", "021209Z", "021208Z", "02120YZ", "02120WZ") | ///
			inlist(icd_prcdr_cd`i', "02130ZZ", "021309Z", "021308Z", "02130YZ", "02130WZ") | ///
			inlist(icd_prcdr_cd`i', "02703ZZ", "027034Z", "027035Z", "02703DZ", "02703EZ") | ///
			inlist(icd_prcdr_cd`i', "02713ZZ", "027134Z", "027135Z", "02713DZ", "02713EZ") | ///
			inlist(icd_prcdr_cd`i', "02723ZZ", "027234Z", "027235Z", "02723DZ", "02723EZ") | ///
			inlist(icd_prcdr_cd`i', "02733ZZ", "027334Z", "027335Z", "02733DZ", "02733EZ") | ///
			inlist(icd_prcdr_cd`i', "02300ZZ", "02303ZZ", "02304ZZ", "02310ZZ", "02313ZZ") | ///
			inlist(icd_prcdr_cd`i', "02314ZZ", "02320ZZ", "02323ZZ", "02324ZZ", "02330ZZ") | ///
			inlist(icd_prcdr_cd`i', "02333ZZ", "02334ZZ", "02V00ZZ", "02V03ZZ", "02V04ZZ") | ///
			inlist(icd_prcdr_cd`i', "02V10ZZ", "02V13ZZ", "02V14ZZ", "02V20ZZ", "02V23ZZ") | ///
			inlist(icd_prcdr_cd`i', "02V24ZZ", "02V30ZZ", "02V33ZZ", "02V34ZZ", "02U00JZ") | /// 
			inlist(icd_prcdr_cd`i', "02U03JZ", "02U04JZ", "02U10JZ", "02U13JZ", "02U14JZ") | ///
			inlist(icd_prcdr_cd`i', "02U20JZ", "02U23JZ", "02U24JZ", "02U30JZ", "02U33JZ") | ///
			inlist(icd_prcdr_cd`i', "02U34JZ", "02Q00ZZ", "02Q03ZZ", "02Q04ZZ", "02Q10ZZ") | ///
			inlist(icd_prcdr_cd`i', "02Q13ZZ", "02Q14ZZ", "02Q20ZZ", "02Q23ZZ", "02Q24ZZ") | ///
			inlist(icd_prcdr_cd`i', "02Q30ZZ", "02Q33ZZ", "02Q34ZZ", "02Y00Z0") // icd-10	
	}
	gen comp_embolization = 0 // should look at follow-up admissions within 30 days
	forvalues i = 1/25 { // look at all diagnosis codes
		replace comp_embolization = 1 if inlist(substr(icd_dgns_cd`i',1,3),"444", "445", "I74", "I75") // arterial embolism
	}
	gen comp_heartfailure = 0 // look within 30 days
	forvalues i = 1/25 { // look at all diagnosis codes
		replace comp_heartfailure = 1 if inlist(substr(icd_dgns_cd`i',1,3), "428", "I50") // heart failure
	}
	gen comp_intracranialhem = 0 // look within 30 days
	forvalues i = 1/25 { 
		replace comp_intracranialhem = 1 if (inlist(substr(icd_dgns_cd`i',1,3), "433","434") & substr(icd_dgns_cd`i',5,1) == "1")
		replace comp_intracranialhem = 1 if inlist(substr(icd_dgns_cd`i', 1, 3), "430", "431", "432", "I60", "I61", "I62", "I63") // intra-cranial hemorrhage
	}
	gen comp_shock = 0 // look at time of PCI or within 30 days
	forvalues i = 1/25 { 
		replace comp_shock = 1 if inlist(icd_dgns_cd`i', "R570", "78551") // cardiogenic shock 
	}
	gen comp_mi = 0 // look within 30 days only
	forvalues i = 1/25 { 
		replace comp_mi = 1 if inlist(substr(icd_dgns_cd`i',1,3), "410", "I21", "I22") // AMI + NSTEMI
	}
	egen comp_any = rowmax(comp*)
	keep if comp_any == 1 
	
	sum comp* 
	append using "$datadir/PCI_complications.dta"
	save "$datadir/PCI_complications.dta", replace
}

// add in transfusion using the ipr files (to use hcpcs_cd)
forvalues i = 2010/2017 {
	di  "***** WORKING ON YEAR `i' *******"
	use bene_id using "$datadir/IVCEventStudy_Base.dta", clear
	duplicates drop 
	merge 1:m bene_id using ///
		/disk/aging/medicare/data/harm/100pct/ip/`i'/ipr`i'.dta, ///
		keep(3) nogenerate keepusing(bene_id *dt* hcpcs_cd rev_cntr)

	gen comp_transfusion = 0 // look at time of PCI or within 30 days
	replace comp_transfusion = 1 if hcpcs_cd == "36430" // blood transfusion
	replace comp_transfusion = 1 if substr(rev_cntr, 1, 3) == "039"
		
	keep if comp_trans == 1 
	append using "$datadir/PCI_complications.dta"
	save "$datadir/PCI_complications.dta", replace
}

use "$datadir/PCI_complications.dta", clear
replace comp_any = 1 

keep bene_id *dt* comp_*
duplicates drop 
gen comp_date = thru_dt if comp_transfusion == 1 // for the ipr files 
replace comp_date = rev_dt if comp_transfusion == 1 & missing(comp_date) // for the ipr files 
replace comp_date = prcdr_dt1 if comp_transfusion == 0 | missing(comp_transfusion)
replace comp_date = from_dt if missing(comp_date)
rename comp_date date
gcollapse (max) comp_*, by(bene_id date) fast
rename date comp_date
compress
save "$datadir/tomerge.dta", replace

// merge into initial surgeries, calculate rate of complications 
use bene_id surg_dt using "$datadir/IVCEventStudy_Base.dta", clear
bys bene_id (surg_dt): gen j = _n 
reshape wide surg_dt, i(bene_id) j(j)
drop surg_dt11-surg_dt25 // can add these back in later if needed
merge 1:m bene_id using "$datadir/tomerge.dta", keep(3) nogenerate
reshape long surg_dt, i(bene_id comp_date) j(j)
drop if missing(surg_dt)
drop j 
keep if inrange(comp_date - surg_dt, 0, 365)
// rm "$datadir/tomerge.dta"

// now go through and for each bene-surg pair, generate a binary complication measure
gen elapse = comp_date - surg_dt
drop comp_any comp_date
foreach v of var comp_transf comp_tamp comp_thromb comp_emb comp_heartf ///
	comp_intrac comp_shock comp_mi { 
	replace `v' = (`v' == 1 & inrange(elapse , 0, 30))
}
replace comp_rest = (comp_rest == 1 & inrange(elapse, 31, 365))
egen comp_any = rowmax(comp_*)
replace comp_heartf = (comp_heartf == 1 & inrange(elapse , 1, 30))
replace comp_mi = (comp_mi == 1 & inrange(elapse , 1, 30))
egen comp_any2 = rowmax(comp_transf comp_tamp comp_thromb comp_emb ///
	comp_intrac comp_shock comp_mi comp_rest comp_heartf)
	// just in case having heart failure and AMI on the procedure date is too much of a complication here
keep if comp_any == 1 
gcollapse (max) comp_*, by(bene_id surg_dt) fast
merge 1:m bene_id surg_dt using "$datadir/IVCEventStudy_Base.dta", keep(2 3) nogenerate
foreach v of var comp* { 
	replace `v' = 0 if missing(`v')
}

compress
save "$datadir/PCIOutcomes.dta", replace

// need to also merge in mortality data 
use bene_id using "$datadir/IVCEventStudy_Base.dta", clear
duplicates drop
merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsf/2017/bsfab2017.dta, ///
	keep(1 3) nogenerate keepusing(bene_id death*)
gen died = death_dt
drop death_dt 
forvalues i = 0/6 { 
	local year = 2016 - `i'
	di "***** YEAR: `year' *****"
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsf/`year'/bsfab`year'.dta, ///
		keep(1 3) nogenerate keepusing(bene_id death*)
	replace died = death_dt if !missing(death_dt) & missing(died) 
	drop death_dt 
}
drop if missing(died) 
merge 1:m bene_id using "$datadir/PCIOutcomes.dta", keep(2 3) nogenerate
gen comp_mortality = (!missing(died) & inrange(died-surg_dt, 0, 30))
drop died
replace comp_any = 1 if comp_mortality == 1 
replace comp_any2 = 1 if comp_mortality == 1 
compress
save "$datadir/PCIOutcomes.dta", replace 
********************************************************************************


***** 2. event study at the level of the individual operator
use "$datadir/PCIOutcomes.dta", clear
egen comp_any3 = rowmax(comp_transf comp_tamp comp_thromb comp_emb ///
	comp_intrac comp_shock comp_rest comp_mortality)

cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort op_npi: ereplace t_adopt = min(t_adopt) // individual adoption decisions as opposed to market-level

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
qui gen period_yq = yq -  t_adopt if treated == 1
gen treatdummy = (treated == 1 & period_yq >= 0)

// sort providers based on adoption: TAVR as a fraction of PCIs
gen provmean = 1 if tavr == 1 & treatdummy == 1
replace provmean = 0 if ptca2 == 1 & treatdummy == 1 
bys op_npi: ereplace provmean = mean(provmean)

keep if ptca2 == 1 // now keep only the pcis
drop if tavr == 1 | savr == 1
gen numprocs = 1 

foreach v of varlist comp_any3* {
	preserve
	local outcome = "`v'" // any of the individual complications can be run here
	local figname = "PCIComplications_`outcome'"

	gcollapse (sum) numprocs (mean) outcome=`outcome' t_adopt provmean (max) treat*, by(op_npi yq period_yq) fast
	replace numprocs = . if yq >= 206 
	bys op_npi: ereplace numprocs = mean(numprocs)
	drop if numprocs == 0.1 // require a CZ to do at least .1 per quarter pre-adoption (as before)
	xtile provq = provmean, nq(5) // sort providers into quantiles 
	
	replace outcome = outcome * 1000 // to get outcome/1,000; this cancels out in regression since we are rescaling by baseline means
		// note: these are by construction conditional outcomes, so we automatically only keep the op_npi-yq pairs where there is at least one PCI

	// Store mean before treatment 
	sum outcome if period_yq < 0 | missing(period_yq), d
	// local pretreat = round(r(mean), .1)
	local pretreat: di %4.0fc `r(p50)'
	local premean = `r(mean)'
	di in red "BASELINE MEAN: `premean'"

	// Run regression 
	cap graph drop * 
	egen id = group(op_npi)
	replace outcome = outcome / `premean' // measure relative to baseline mean
	
	di in red "FULL REGRESSION: `v'"
	lpdid outcome, unit(id) time(yq) treat(treatdummy) only_pooled nograph pre_window(12) post_window(12) post_pooled(12) pmd(12) // results are robust to including: rw nocomp (or nevertraet, but there aren't sufficient nevertreat for this to be done except noisily)
// 	addplot: , yline(0, lcolor(black))
// 	local pooledfx: di %4.2fc e(pooled_results)[2,1]
// 	addplot: , yline(`pooledfx', lpattern(dash))
// 	addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") ///
// 		xsc(r(-12(4)12)) xlab(-12(4)12) ///
// 		text(0.6 -10 "Pre-treatment median: `pretreat'", place(e)) ///
// 		text(`pooledfx' -8 "Pooled Effect: `pooledfx'", place(s)) 
//		
// 	// Save graphs
// 	graph save "$output/`figname'_recentered.gph", replace
// 	graph export "$output/`figname'_recentered.pdf", as(pdf) replace 
	
	// now loop through each of the quantiles 
	forvalues q = 1/5 { 
		di in red "QUANTILE `q' REGRESSION: `v'"
		lpdid outcome if provq == `q' | missing(provq), ///
			unit(id) time(yq) treat(treatdummy) ///
			pre_window(12) post_window(12) post_pooled(12) pmd(12) only_pooled nograph // results are robust to including: rw nocomp (or nevertraet, but there aren't sufficient nevertreat for this to be done except noisily)
// 		addplot: , yline(0, lcolor(black))
// 		local pooledfx: di %4.2fc e(pooled_results)[2,1]
// 		addplot: , yline(`pooledfx', lpattern(dash))
// 		addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") ///
// 			xsc(r(-12(4)12)) xlab(-12(4)12) ///
// 			text(0.6 -10 "Pre-treatment median: `pretreat'", place(e)) ///
// 			text(`pooledfx' -8 "Pooled Effect: `pooledfx'", place(s)) 
//			
// 		// Save graphs
// 		graph save "$output/`figname'_recentered.gph", replace
// 		graph export "$output/`figname'_recentered.pdf", as(pdf) replace
	}
	restore
}
********************************************************************************
