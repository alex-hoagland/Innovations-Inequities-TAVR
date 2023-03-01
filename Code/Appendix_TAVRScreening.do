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
// clear
// tempfile screenings
// gen prf_npi = "" 
// save `screenings', replace
//
// forvalues y = 2010/2017 { 
// 	di in green "********** OUTPATIENT YEAR `y' ************" 
// 	use thru_dt prf_npi hcpcs_cd using ///
// 		/disk/aging/medicare/data/harm/20pct/car/`y'/carl`y'.dta if hcpcs_cd == "71275", clear
// 	gen yq = qofd(thru_dt)
// 	gen count = 1 
// 	gcollapse (sum) count, by(prf_npi yq) fast
// 	append using `screenings'
// 	save `screenings', replace
//	
// // 	di error "********** INPATIENT YEAR `y' ************" 
// // 	use *_npi icd_prcdr_cd* prcdr_dt* /disk/aging/medicare/data/harm/20pct/car/`yr'/carl`yr'.dta if hcpcs_cd == "71275", clear
// // 	gen yq = qofd(thru_dt)
// // 	gen count = 1 
// // 	gcollapse (sum) count, by(prf_npi yq) fast
// // 	append using `screenings'
// // 	save `screenings', replace
// }
//
// use `screenings', clear
// save "$datadir/tomerge.dta", replace
********************************************************************************


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear
local figname = "Appendix_TAVRScreening_FracScreening"

// merge in 
gen prf_npi = op_npi 
merge m:1 prf_npi yq using "$datadir/tomerge.dta", keep(1 3) nogenerate
gen outcome = count
replace outcome = 0 if missing(outcome) 
replace prf_npi = at_npi
drop count
merge m:1 prf_npi yq using "$datadir/tomerge.dta", keep(1 3) nogenerate
replace outcome = outcome + count if !missing(count) 

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)
	
// if you nwant any screening
gen allprocs = 1 
replace outcome = (outcome > 0)  * 100
gcollapse (max) outcome (sum) allprocs (mean) t_adopt, by(CZID yq *npi) fast
gcollapse (sum) allprocs (mean) outcome t_adopt, by(CZID yq) fast
// replace outcome = (outcome > 0) * 100

	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	replace todrop = 1 if allprocs < 10
	bysort CZID: ereplace todrop = max(todrop) 
	drop if todrop == 1 
	drop todrop
	
sum outcome, d
replace outcome = 250 if outcome > 250 

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
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
local pretreat = round(r(mean), .1)

// Run regression 
binscatter outcome period_yq, nq(100) linetype(qfit) rd(0) 
qui reghdfe outcome dummy* [aw=allprocs], absorb(CZID yq) vce(cluster CZID) 

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

// keep only 4 yqs pre-/post-adoption
drop if abs(y) > 12

// combine the risk figures (intensive margin) 
if ("`margin'" == "intensive") { 
	save "$datadir/figuredata_intensivemargin_`treatment'_`3'.dta", replace
}

	// local for where to put the text label
	qui sum y 
	local mymin = r(min) 
	local mymax = r(max) 
	local myx = `mymax' * 0.05
	qui sum ub
	local myy = r(max) * 0.85

sort y 
twoway (scatter coef y, color(maroon)) /// (line coef y, lcolor(ebblue)) /// 
	(rcap lb ub y, color(ebblue%60)), ///
	graphregion(color(white)) legend(off) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
