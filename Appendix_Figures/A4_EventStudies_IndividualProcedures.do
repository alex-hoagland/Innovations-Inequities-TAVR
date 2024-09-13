/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Surgical Volume: Specific to One Proc 
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/2024
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: This file is specific to CABG and PCI procedures

* Key edits: 
*******************************************************************************/


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear
local treatment `1'

// define procs of interest
gen cabg = inlist(icd91, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd92, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd93, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd94, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd95, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd96, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd97, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
gen cath = inlist(icd91, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd92, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd93, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd94, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd95, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd96, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd97, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
gen ptcaonly = inlist("0066", icd91, icd92, icd93, icd94, icd95, icd96, icd97)

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local margin = "`2'" // extensive = use of technique, intensive = average patient risk conditional on treatment 
local figname = "LPDID-EventStudy_CZLevel_`1'Treatments"

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

if ("`treatment'" == "cabg") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (cabg == 1)
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs
}
else if ("`treatment'" == "cath") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (cath == 1)
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs
}
else if ("`treatment'" == "ptcaonly") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (ptcaonly == 1)
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs
}
else if ("`treatment'" == "allother") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = 1 
	replace num_procs = 0 if cabg == 1 | ptcaonly == 1 | tavr == 1 | savr == 1
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs
}
else if ("`treatment'" == "allsupport") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = 1 
	replace num_procs = 0 if cabg == 1 | cath == 1 | ptcaonly == 1 //  | tavr == 1 | savr == 1
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs
}

// Require that a CZID have >10 procs in each quarter (deals with 0s as well)
if ("`treatment'" != "high" | "`margin'" != "intensive") { 
	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	replace num_procs = 0 if missing(num_procs)
	replace outcome = 0 if missing(outcome)
	replace todrop = 1 if allprocs < 10
	bysort CZID: ereplace todrop = mean(allprocs) 
	drop if todrop < 0
	drop todrop
}

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
qui gen period_yq = yq -  t_adopt if treated == 1

// DD regression -- pooled effects in lpdid	

// Store mean before treatment 
sum outcome if period_yq < 0 | missing(period_yq), d
local pretreat: di %4.0fc `r(p50)'

// Run regression 
gen treatdummy = (treated == 1 & period_yq >= 0)
set scheme cblind1
cap graph drop * 
lpdid outcome, unit(CZID) time(yq) treat(treatdummy) pre_window(12) post_window(12)
// results are robust to including: rw nocomp (or nevertraet, but there aren't sufficient nevertreat for this to be done except noisily)
addplot: , yline(0, lcolor(black))
local pooledfx: di %4.2fc e(pooled_results)[2,1]
addplot: , yline(`pooledfx', lpattern(dash))
addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") xsc(r(-12(4)12)) xlab(-12(4)12) ///
	text(1.5 1 "Pre-treatment median: `pretreat'", place(e))  ///
	text(`pooledfx' -9 "Pooled Effect: `pooledfx'", place(s))
	
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
