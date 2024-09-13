/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes :Patient Level
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 3/7/2024
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies -- keep CZs included in market-level analysis 
cap graph drop * 
local group = `1'
local post = 3 // how many quarters to do post for the ATE [0, `post'], so this is actually post + 1 quarters

// run this data merge once, not 12 times 
capture confirm file "$datadir/regdata.dta" // will be removed once you run the combine table .do file 
if (_rc == 0) { 
	use "$datadir/regdata.dta", clear 
}
else {
	// first, correctly identify dates across all observable procedures (and drop the same CZs from before)
	use "$datadir/IVCEventStudy_Base.dta" if tavr == 1, clear
	append using "$datadir/all_OutpatientCardiology.dta"
	keep if tavr ==1 
	gcollapse (min) yq, by(CZID) fast
	rename yq t_adopt_patlevel

	// merge that with all observed procedures in the 20p sample 
	merge 1:m CZID using "$datadir/IVCEventStudy_Base.dta", keep(2 3) nogenerate
	drop t_adopt // only using inpatient data 
	rename t_adopt_patlevel t_adopt // using inpatient and outpatient data 
	gen allprocs = 1
	bysort CZID yq: ereplace allprocs = total(allprocs)
	bysort CZID: ereplace allprocs = mean(allprocs) 
	gen todrop = (allprocs < 5)
	drop allprocs 

	// keep only inpatient procedures for those in 20p
	merge m:1 bene_id using "$datadir/20p_flag", keep(3) nogenerate 

	// add in outpatient procedures
	append using "$datadir/all_OutpatientCardiology.dta" // shouldn't be any duplicates here 
	bys CZID: ereplace todrop = max(todrop) 
	drop if todrop == 1
	
	// pull in most recent ADI data so we know it's working properly 
	replace zip9 = zip if missing(zip9) // we have 5- or 9-digit zip codes for 97.3% of sample
	destring zip9, gen(zip_cd)
	merge m:1 zip_cd using "$mydir/2_Data/ADI/ADI_9digits.dta", keep(1 3) nogenerate keepusing(zip_cd adi_9)
		// a fair chunk of data missing here b/c we only have 5-digit zip codes for some 
	replace adi_9 = "" if strpos(adi_9, "PH") | strpos(adi_9, "Q") | strpos(adi_9, "N")
	destring adi_9, replace 
	merge m:1 zip_cd using "$mydir/2_Data/ADI/ADI_5digits.dta", keep(1 3) nogenerate keepusing(zip_cd adi_5)
	replace adi_9 = adi_5 if missing(adi_9) & !missing(adi_5)
	drop adi_5 // now have ADI for 95% of data 
	
	compress
	save "$datadir/regdata.dta", replace
}

quietly {
	cap drop group
	if (`group' == 0) { 
		gen group1 = 1 // all procedures
		local pmd = "pmd(max)" // correct for pre-trends 
	}
	if (`group' == 1) { // Patient sex
		drop if missing(riskvar_fem)
		gen group1 = (riskvar_fem == 0) // ref group: males
		gen group2 = (riskvar_fem == 1) 	
		local pmd = "pmd(max)" // correct for pre-trends 
	}
	else if (`group' == 2) { // Dual status
		drop if missing(riskvar_dual_any)
		gen group2 = (riskvar_dual_any == 1)
		gen group1 = (riskvar_dual_any == 0) // ref group: not dual eligible
		local pmd = "pmd(max)" // correct for pre-trends 
	}
	else if (`group' == 3) { // Race
		drop if missing(riskvar_black) | missing(riskvar_hisp) | missing(riskvar_othernonwhite)
		gen group1 = (riskvar_black == 0 & riskvar_hisp == 0 & riskvar_othernonwhite == 0) // ref group: white
		gen group2 = (riskvar_black == 1) 
		gen group3 = (riskvar_hisp == 1)
		gen group4 = (riskvar_othernonwhite == 1)
		gen group5 = (riskvar_black == 1 | riskvar_hisp == 1 | riskvar_othernonwhite == 1)  // any nonwhite (pooled)
		local pmd = "" // correcting for pre-trends is unecessary and may introduce bias for the very rare outcomes
	}
	else if (`group' == 4) { // ADI
// 		drop if missing(adi_9)
// 		_pctile adi_9, nq(4) 
// 		gen group1 = (adi <= `r(r1)') // reference group: low ADI
// 		gen group2 = (adi >= `r(r3)')

// 		drop if missing(riskvar_adi_9)
// 		replace riskvar_adi_9 = . if riskvar_adi_9 < 20
// 		_pctile riskvar_adi_9, nq(5)
// 		//gen group = (riskvar_adi_9 < `r(p50)')
// 		gen group = (riskvar_adi_9 < `r(r1)')

		// look at top/bottom quartile conditional on CZ mean?
		bys CZID: egen meanadi = mean(adi_9)
		gen diff_adi = adi_9 - meanadi // pretty normally distributed around 0 
		_pctile diff_adi, nq(10)
		gen group1 = (diff_adi <= `r(r1)') // reference group: largest negative differences (adi rank is lower than mean) 
		gen group2 = (diff_adi >= `r(r9)') // comp. group: largest positive differences (adi rank is higher than mean) 
		local pmd = "pmd(max)" // correct for pre-trends 
	}

	gen allprocs = 1 
	gen outcome1 = (group1 ==1 & (tavr == 1 | savr == 1 | ptca2 == 1))
	cap gen outcome2 = (group2 ==1 & (tavr == 1 | savr == 1 | ptca2 == 1))
	cap gen outcome3 = (group3 ==1 & (tavr == 1 | savr == 1 | ptca2 == 1))
	cap gen outcome4 = (group4 ==1 & (tavr == 1 | savr == 1 | ptca2 == 1))
	cap gen outcome5 = (group5 ==1 & (tavr == 1 | savr == 1 | ptca2 == 1))
	gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast

	fillin CZID yq
	foreach v of varlist outcome* all {
		replace `v' = 0 if missing(`v')
	}

	// need to convert allprocs to rate per 1,000; this is the problem with large multipliers in older versions of Fig. A.5.
	merge 1:1 CZID yq using "$datadir/czpop_20", keep(3) nogenerate
	ereplace pop20 = mean(pop20)
	foreach v of var outcome* all {
		replace `v' = `v' / pop20 * 1000
	}
	
	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	sum treated
	qui gen period_yq = yq -  t_adopt if treated == 1

	// Store mean before treatment 
	sum outcome1 if period_yq < 0 | treated == 0, d
	global pretreat1_`group': di %4.2fc `r(mean)'
	global pretreat1_m_`group': di %4.2fc `r(p50)'
	
	forvalues j = 2/5 {
		cap sum outcome`j' if period_yq < 0 | treated == 0, d
		cap global pretreat`j'_`group': di %4.2fc `r(mean)'
		cap global pretreat`j'_m_`group': di %4.2fc `r(p50)'
	}

	// Run regression 
	gen treatdummy = (treated == 1 & period_yq >= 0)
}
********************************************************************************


**** Now run regressions 
// base outcome
lpdid outcome1, unit(CZID) time(yq) treat(treatdummy) post_window(`post') nograph only_pooled `pmd'

global pooledfx1_`group': di %4.2fc e(pooled_results)[2,1]
global se1_`group': di %8.4fc e(pooled_results)[2,2]
global pooledfx1_p_`group': di %4.3fc e(pooled_results)[2,4]
global percchange1_`group': di %4.2fc ${pooledfx1_`group'} / ${pretreat1_`group'} * 100
global pooledfx1_cil_`group': di %4.2fc (${pooledfx1_`group'} - 1.96 * ${se1_`group'}) / ${pretreat1_`group'} * 100
global pooledfx1_cih_`group': di %4.2fc (${pooledfx1_`group'} + 1.96 * ${se1_`group'}) / ${pretreat1_`group'} * 100
// global percchange1_m_`group': di %4.2fc ${pooledfx1_`group'} / ${pretreat1_m_`group'} * 100
// global pooledfx1_cil_m_`group': di %4.2fc (${pooledfx1_`group'} - 1.96 * ${se1_`group'}) / ${pretreat1_m_`group'} * 100
// global pooledfx1_cih_m_`group': di %4.2fc (${pooledfx1_`group'} + 1.96 * ${se1_`group'}) / ${pretreat1_m_`group'} * 100

// comparator outcome 
cap lpdid outcome2, unit(CZID) time(yq) treat(treatdummy) post_window(`post') nograph only_pooled `pmd'

cap global pooledfx2_`group': di %4.2fc e(pooled_results)[2,1]
cap global se2_`group': di %8.4fc e(pooled_results)[2,2]
cap global pooledfx2_p_`group': di %4.3fc e(pooled_results)[2,4]
cap global percchange2_`group': di %4.2fc ${pooledfx2_`group'} / ${pretreat2_`group'} * 100
cap global pooledfx2_cil_`group': di %4.2fc (${pooledfx2_`group'} - 1.96 * ${se2_`group'}) / ${pretreat2_`group'} * 100
cap global pooledfx2_cih_`group': di %4.2fc (${pooledfx2_`group'} + 1.96 * ${se2_`group'}) / ${pretreat2_`group'} * 100
// cap global percchange2_m_`group': di %4.2fc ${pooledfx2_`group'} / ${pretreat2_m_`group'} * 100
// cap global pooledfx2_cil_m_`group': di %4.2fc (${pooledfx2_`group'} - 1.96 * ${se2_`group'}) / ${pretreat2_m_`group'} * 100
// cap global pooledfx2_cih_m_`group': di %4.2fc (${pooledfx2_`group'} + 1.96 * ${se2_`group'}) / ${pretreat2_m_`group'} * 100

// test difference in groups (for percentage changes)
cap local z = (${percchange1_`group'} - ${percchange2_`group'})/sqrt((${se1_`group'}*100)^2+(${se2_`group'}*100)^2) // test stat from: http://psycnet.apa.org/psycinfo/1995-27766-001
cap global group`group'_p: di %4.3fc (1-normal(abs(`z'))) // one-sided p-value from standard normal 

// comparator outcome 
cap lpdid outcome3, unit(CZID) time(yq) treat(treatdummy) post_window(`post') nograph only_pooled `pmd'

cap global pooledfx3_`group': di %4.2fc e(pooled_results)[2,1]
cap global se3_`group': di %8.4fc e(pooled_results)[2,2]
cap global pooledfx3_p_`group': di %4.3fc e(pooled_results)[2,4]
cap global percchange3_`group': di %4.2fc ${pooledfx3_`group'} / ${pretreat3_`group'} * 100
cap global pooledfx3_cil_`group': di %4.2fc (${pooledfx3_`group'} - 1.96 * ${se3_`group'}) / ${pretreat3_`group'} * 100
cap global pooledfx3_cih_`group': di %4.2fc (${pooledfx3_`group'} + 1.96 * ${se3_`group'}) / ${pretreat3_`group'} * 100
// cap global percchange3_m_`group': di %4.2fc ${pooledfx3_`group'} / ${pretreat3_m_`group'} * 100
// cap global pooledfx3_cil_m_`group': di %4.2fc (${pooledfx3_`group'} - 1.96 * ${se3_`group'}) / ${pretreat3_m_`group'} * 100
// cap global pooledfx3_cih_m_`group': di %4.2fc (${pooledfx3_`group'} + 1.96 * ${se3_`group'}) / ${pretreat3_m_`group'} * 100

// test difference in groups (for percentage changes)
cap local z3 = (${percchange1_`group'} - ${percchange3_`group'})/sqrt((${se1_`group'}*100)^2+(${se3_`group'}*100)^2) // test stat from: http://psycnet.apa.org/psycinfo/1995-27766-001
cap global group`group'_p_3: di %4.3fc (1-normal(abs(`z3'))) // one-sided p-value from standard normal 

// comparator outcome 
cap lpdid outcome4, unit(CZID) time(yq) treat(treatdummy) post_window(`post') nograph only_pooled `pmd'

cap global pooledfx4_`group': di %4.2fc e(pooled_results)[2,1]
cap global se4_`group': di %8.4fc e(pooled_results)[2,2]
cap global pooledfx4_p_`group': di %4.3fc e(pooled_results)[2,4]
cap global percchange4_`group': di %4.2fc ${pooledfx4_`group'} / ${pretreat4_`group'} * 100
cap global pooledfx4_cil_`group': di %4.2fc (${pooledfx4_`group'} - 1.96 * ${se4_`group'}) / ${pretreat4_`group'} * 100
cap global pooledfx4_cih_`group': di %4.2fc (${pooledfx4_`group'} + 1.96 * ${se4_`group'}) / ${pretreat4_`group'} * 100
// cap global percchange4_m_`group': di %4.2fc ${pooledfx4_`group'} / ${pretreat4_m_`group'} * 100
// cap global pooledfx4_cil_m_`group': di %4.2fc (${pooledfx4_`group'} - 1.96 * ${se4_`group'}) / ${pretreat4_m_`group'} * 100
// cap global pooledfx4_cih_m_`group': di %4.2fc (${pooledfx4_`group'} + 1.96 * ${se4_`group'}) / ${pretreat4_m_`group'} * 100

// test difference in groups (for percentage changes)
cap local z4 = (${percchange1_`group'} - ${percchange4_`group'})/sqrt((${se1_`group'}*100)^2+(${se4_`group'}*100)^2) // test stat from: http://psycnet.apa.org/psycinfo/1995-27766-001
cap global group`group'_p_4: di %4.3fc (1-normal(abs(`z4'))) // one-sided p-value from standard normal 

// comparator outcome 
cap lpdid outcome5, unit(CZID) time(yq) treat(treatdummy) post_window(`post') nograph only_pooled `pmd'

cap global pooledfx5_`group': di %4.2fc e(pooled_results)[2,1]
cap global se5_`group': di %8.4fc e(pooled_results)[2,2]
cap global pooledfx5_p_`group': di %4.3fc e(pooled_results)[2,4]
cap global percchange5_`group': di %4.2fc ${pooledfx5_`group'} / ${pretreat5_`group'} * 100
cap global pooledfx5_cil_`group': di %4.2fc (${pooledfx5_`group'} - 1.96 * ${se5_`group'}) / ${pretreat5_`group'} * 100
cap global pooledfx5_cih_`group': di %4.2fc (${pooledfx5_`group'} + 1.96 * ${se5_`group'}) / ${pretreat5_`group'} * 100
// cap global percchange5_m_`group': di %4.2fc ${pooledfx5_`group'} / ${pretreat5_m_`group'} * 100
// cap global pooledfx5_cil_m_`group': di %4.2fc (${pooledfx5_`group'} - 1.96 * ${se5_`group'}) / ${pretreat5_m_`group'} * 100
// cap global pooledfx5_cih_m_`group': di %4.2fc (${pooledfx5_`group'} + 1.96 * ${se5_`group'}) / ${pretreat5_m_`group'} * 100

// test difference in groups (for percentage changes)
cap local z5 = (${percchange1_`group'} - ${percchange5_`group'})/sqrt((${se1_`group'}*100)^2+(${se5_`group'}*100)^2) // test stat from: http://psycnet.apa.org/psycinfo/1995-27766-001
cap global group`group'_p_5: di %4.3fc (1-normal(abs(`z5'))) // one-sided p-value from standard normal 

********************************************************************************
