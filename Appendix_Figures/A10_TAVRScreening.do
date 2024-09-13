/*******************************************************************************
* Title: Effect of TAVR adoption on cardiologist provision of preventive care: 
	3 -- rate of screening at the IVC level. 
* Created by: Alex Hoagland
* Created on: 10/15/2021
* Last modified on: 2/27/2023
* Last modified by: 
* Purpose: Simple event study of TAVR adoption on CTA screening (CPT 71275)
* Notes: 

* Key edits: 
*******************************************************************************/


***** 0. Temp merge file with all procedures
clear
tempfile screenings
gen prf_npi = "" 
save `screenings', replace

forvalues y = 2010/2016 { 
	di "********** CARRIER YEAR `y' ************" 
	use thru_dt prf_npi hcpcs_cd using ///
		/disk/aging/medicare/data/harm/20pct/car/`y'/carl`y'.dta if inlist(hcpcs_cd, "75573", "75574", "71275"), clear
	gen yq = qofd(thru_dt)
	gen count = 1 
	gcollapse (sum) count, by(prf_npi yq) fast
	append using `screenings'
	save `screenings', replace
	
	di "********** INPATIENT YEAR `y' ************" 
	use *npi hcpcs_cd *dt* using /disk/aging/medicare/data/harm/20pct/ip/`y'/ipr`y'.dta if inlist(hcpcs_cd, "75573", "75574", "71275"), clear
	rename *npi prf_npi
	rename rev_dt thru_dt
	gen yq = qofd(thru_dt)
	gen count = 1 
	gcollapse (sum) count, by(prf_npi yq) fast
	append using `screenings'
	save `screenings', replace
}

di "********** CARRIER YEAR 2017 ************" 
	use thru_dt prf_npi hcpcs_cd using ///
		/disk/aging/medicare/data/harm/20pct/car/2017/carl2017.dta if inlist(hcpcs_cd, "75573", "75574", "71275"), clear
	gen yq = qofd(thru_dt)
	gen count = 1 
	gcollapse (sum) count, by(prf_npi yq) fast
	append using `screenings'
	save `screenings', replace
	
	di "********** INPATIENT YEAR 2017 ************" 
	use *npi hcpcs_cd *dt* using /disk/aging/medicare/data/harm/20pct/ip/2017/ipr2017.dta if inlist(hcpcs_cd, "75573", "75574", "71275"), clear
	rename *npi prf_npi
	// rename rev_dt thru_dt
	gen yq = qofd(thru_dt)
	gen count = 1 
	gcollapse (sum) count, by(prf_npi yq) fast
	append using `screenings'
	save `screenings', replace

use `screenings', clear
save "$datadir/screenings.dta", replace
********************************************************************************


***** 1. Event Studies (20% file only)
local figname = "NPILevel_FracTAVRScreening"

use bene_id using "$datadir/ASpatients2024_20p.dta", clear
duplicates drop 
tempfile my20
save `my20', replace

use "$datadir/IVCEventStudy_Base.dta", clear
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort op_npi: ereplace t_adopt = min(t_adopt) 
merge m:1 bene_id using `my20', keep(3) nogenerate

// merge in 
gen prf_npi = op_npi 
merge m:1 prf_npi yq using "$datadir/screenings.dta", keep(1 3) nogenerate
gen outcome = count
replace outcome = 0 if missing(outcome) 

// drop operators without any PCI prior to TAVR
cap drop todrop 
gen todrop = ptca2 if yq < 206
bys op_npi: ereplace todrop = max(todrop) 
drop if todrop == 0
drop todrop 

// if you nwant any screening
gen allprocs = 1 
replace outcome = (outcome > 0)  * 100
gcollapse (max) outcome (sum) allprocs (mean) t_adopt, by(prf_npi yq) fast
// gcollapse (sum) allprocs (mean) outcome t_adopt, by(CZID yq) fast
// replace outcome = (outcome > 0) * 100

fillin prf_npi yq
replace allprocs = 0 if missing(allprocs)
replace outcome = 0 if missing(outcome)

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
qui gen period_yq = yq -  t_adopt if treated == 1

// binscatter outcome period_yq, nq(100) linetype(qfit) rd(0) 

// Store mean before treatment 
gen test = outcome if period_yq < 0 | missing(period_yq)
bys prf_npi: ereplace test = mean(test) 
sum test, d // this is measured as % of all operators 
// sum outcome if period_yq < 0 | missing(period_yq), d
// local pretreat = round(r(mean), .1)
local pretreat: di %4.2fc `r(mean)'

// Run regression 
cap gen treatdummy = (treated == 1 & period_yq >= 0)
set scheme cblind1
cap graph drop * 
cap egen id = group(prf_npi)
lpdid outcome, unit(id) time(yq) treat(treatdummy) pre_window(12) post_window(12) pmd(max)
// results are robust to including: rw nocomp (or nevertraet, but there aren't sufficient nevertreat for this to be done except noisily)
addplot: , yline(0, lcolor(black))
local pooledfx: di %4.2fc e(pooled_results)[2,1]
local postp: di %6.4fc e(pooled_results)[2,4]
addplot: , yline(`pooledfx', lpattern(dash))
addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") xsc(r(-12(4)12)) xlab(-12(4)12) ///
	text(2 1 "Pre-treatment mean: `pretreat'", place(e)) ///
	text(0.75 -7 "Pooled Effect: `pooledfx' (p = `postp')", place(n))
	
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
