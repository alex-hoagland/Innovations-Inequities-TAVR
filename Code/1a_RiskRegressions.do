/*******************************************************************************
* Title: Estimate patient risk / appropriateness for TAVR
* Created by: Alex Hoagland
* Created on: 2/21/2022
* Last modified on: 2/7/2023
* Last modified by: 
* Purpose: Identifies risk/appropriateness for TAVR
* Notes: -runs STS-PROM model predicting risk of surgical mortality following TAVR/SAVR
	 - uses 1_EstimatePatientRisk.do to create dvariables first 

* Key edits: 
*******************************************************************************/

***** 1. Keep data used in main regressions (those with cardiac surgeries) 
use "$datadir/all_SurgicalCandidates.dta" if tavr == 1 | savr == 1, clear

xtset CZID
********************************************************************************

***** 2. Estimate regression coefficients, check for validity, and use to generate predicted risk
gen mort_30 = (!missing(days_mortality) & days_mortality <= 30)
gen mort_60 = (!missing(days_mortality) & days_mortality <= 60)
gen mort_90 = (!missing(days_mortality) & days_mortality <= 90)

mdesc riskvar_* mort_* CZID 

estimates clear
foreach v of varlist mort_* { 
	// NOTE: not using CZID fixed effects, as these won't be helpful for prediction
	// since not consistently estimated
	di "***** REGRSESION FOR `v' *******"
	local d = substr("`v'", 6, 2)
	//xtlogit `v' riskvar_* i.yq, fe
	logit `v' riskvar_* i.yq
	estimates store predrisk_`v'
	
	// predict risk out of sample 
	di "***** PREDICTION FOR `v' *******"
	preserve
	use "$datadir/all_SurgicalCandidates.dta", clear
	cap drop predrisk_`d'
	predict predrisk_`d', pr
	save "$datadir/all_SurgicalCandidates.dta", replace
	restore
	
	eststo margin_`v': margins, dydx(*) post
	estimates store m_`v', title(`v')
}
********************************************************************************


***** 3. Appendix table for regression coefficients
// reports marginal effects + CIs
esttab margin_mort_30 margin_mort_60 margin_mort_90 ///
	using "$output/Appendix_PredictedRisk_TableFrag.tex", label frag  nonumber collab(none) ///
	cells(b(fmt(3)) ci(fmt(3) par) wide) mtitles("30-Day" "60-Day", "90-Day") 
********************************************************************************


***** 4. Examine distribution of predicted risk
// generally, low risk is <= 3%, medium risk is 3-8%, and high risk is >= 8%
use "$datadir/all_SurgicalCandidates.dta", clear
foreach v of varlist predrisk* { 
	hist `v', percent graphregion(color(white)) fcolor(ebblue%30) lcolor(ebblue) ///
		xtitle("Predicted Pr(Surgical Mortality)") ytitle("%",angle(horizontal)) ///
		ylab(,angle(horizontal)) xsc(r(0(.2)1)) xlab(0(.2)1) ///
		xline(.03, lpattern(dash) lcolor(red)) xline(.08, lpattern(dash) lcolor(red))
	graph save "$mydir/ToExport/`v'_Histogram.gph", replace
	graph export "$mydir/ToExport/`v'_Histogram.pdf", as(pdf) replace
}
********************************************************************************
estimates clear
foreach v of varlist mort_* { 
	// NOTE: not using CZID fixed effects, as these won't be helpful for prediction
	// since not consistently estimated
	di "***** REGRSESION FOR `v' *******"
	local d = substr("`v'", 6, 2)
	//xtlogit `v' riskvar_* i.yq, fe
	logit `v' riskvar_* i.yq
	estimates store predrisk_`v'
	
	// predict risk out of sample 
	di "***** PREDICTION FOR `v' *******"
	preserve
	use "$datadir/all_SurgicalCandidates.dta", clear
	cap drop predrisk_`d'
	predict predrisk_`d', pr
	save "$datadir/all_SurgicalCandidates.dta", replace
	restore
	
	eststo margin_`v': margins, dydx(*) post
	estimates store m_`v', title(`v')
}
********************************************************************************


***** 3. Appendix table for regression coefficients
// reports marginal effects + CIs
esttab margin_mort_30 margin_mort_60 margin_mort_90 ///
	using "$output/Appendix_PredictedRisk_TableFrag.tex", label frag  nonumber collab(none) ///
	cells(b(fmt(3)) ci(fmt(3) par) wide) mtitles("30-Day" "60-Day" "90-Day") 
********************************************************************************


***** 4. Examine distribution of predicted risk
// generally, low risk is <= 3%, medium risk is 3-8%, and high risk is >= 8%
use "$datadir/all_SurgicalCandidates.dta", clear
foreach v of varlist predrisk* { 
	hist `v', percent graphregion(color(white)) fcolor(ebblue%30) lcolor(ebblue) ///
		xtitle("Predicted Pr(Surgical Mortality)") ytitle("%",angle(horizontal)) ///
		ylab(,angle(horizontal)) xsc(r(0(.2)1)) xlab(0(.2)1) ///
		xline(.03, lpattern(dash) lcolor(red)) xline(.08, lpattern(dash) lcolor(red))
	graph save "$mydir/ToExport/`v'_Histogram.gph", replace
	graph export "$mydir/ToExport/`v'_Histogram.pdf", as(pdf) replace
}
********************************************************************************
