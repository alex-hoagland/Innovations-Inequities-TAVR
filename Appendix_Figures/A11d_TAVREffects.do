/*******************************************************************************
* Title: Flag all inpatient NSTEMIs
* Created by: Alex Hoagland
* Created on: 6/28/2023
* Last modified on: 
* Last modified by: 
* Purpose: Identifies all inpatient NSTEMIs in the population (will eventually link to angioplasties and TAVR adoption at CZ level)

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. 
use "$mydir/nstemi_angiograms_outcomes.dta", clear
rename quarter yq
merge 1:m CZID yq using "$datadir/IVCEventStudy_Base.dta", keep(2 3) nogenerate

local treatment = "ang" // % of angiograms received in time is the main outcome here
local figname = "LPDID-Angiograms"

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

gcollapse (mean) ang* nstemi t_adopt, by(CZID yq) fast // unit of analysis  
fre t_adopt

fillin CZID yq
replace nstemi = 0 if missing(nstemi)
bysort CZID: egen todrop = mean(nstemi) 
drop if todrop < 5
drop todrop _fillin

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
qui gen period_yq = yq -  t_adopt if treated == 1

// Store mean before treatment 
sum ang if period_yq < 0 | missing(period_yq), d
local pretreat: di %4.2fc `r(mean)'

// Run regression 
// Run regression 
gen treatdummy = (treated == 1 & period_yq >= 0)
set scheme cblind1
cap graph drop * 
lpdid ang, unit(CZID) time(yq) treat(treatdummy) pre_window(12) post_window(12)
// results are robust to including: rw nocomp (or nevertraet, but there aren't sufficient nevertreat for this to be done except noisily)
addplot: , yline(0, lcolor(black))
local pooledfx: di %4.2fc e(pooled_results)[2,1]
addplot: , yline(`pooledfx', lpattern(dash))
addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") xsc(r(-12(4)12)) xlab(-12(4)12) ///
	text(5 1 "Pre-treatment mean: `pretreat'", place(e)) ///
	text(3.5 -9 "Pooled Effect: `pooledfx'", place(n))
	
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
