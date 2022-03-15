/*******************************************************************************
* Title: Make a summary stat table for TAVR patients
* Created by: Alex Hoagland
* Created on: 2/28/2022
* Last modified on: 
* Last modified by: 
* Purpose: 
* Notes: - code fragment, meant to fit into the 1_EstimatePatientRisk.do file

* Key edits: 
*******************************************************************************/


***** 1. Identify patient groups (in markets with/without TAVR adopters in that year)
use "$datadir/all_InpatientCardiology.dta" if tavr == 1, clear
collapse (max) tavr, by(bene_id year) fast 
rename tavr group
rename year riskvar_year
merge 1:1 bene_id riskvar_year using "$datadir/PatientRisk.dta", ///
	keepusing(riskvar* predicted_risk ssacd medinc_*) keep(2 3) nogenerate
bysort ssacd riskvar_year: ereplace group = max(group) 
replace group = 0 if missing(group)
sum group 
********************************************************************************


***** 2. Create table 
drop if riskvar_year >= 2016
cap drop riskvar_year 

* First, demographics; second, health risks; third, predicted risk 
gen riskvar_white = (riskvar_black == 0 & riskvar_othernonwhite == 0)

label var riskvar_age "\hspace{0.25cm} Age"
label var riskvar_fem "\hspace{0.25cm} Female"
label var riskvar_white "\hspace{0.25cm} White"
label var riskvar_black "\hspace{0.25cm} Black"
label var riskvar_hisp "\hspace{0.25cm} Hispanic"
label var riskvar_othernonwhite "\hspace{0.25cm} Other Race"
label var medinc_all "\hspace{0.25cm} Median County Income (all)"
label var medinc_65plus "\hspace{0.25cm} Median County Income (age 65 plus)"
label var riskvar_numccs "\hspace{0.25cm} # of Chronic Conditions"
label var riskvar_chf "\hspace{0.25cm} CC: Congestive Heart Failure"
label var riskvar_diabetes "\hspace{0.25cm} CC: Diabetes"
label var riskvar_hypert "\hspace{0.25cm} CC: Hypertension"
label var riskvar_stroke "\hspace{0.25cm} CC: Stroke"
label var riskvar_ami "\hspace{0.25cm} CC: Acute Myocardial Infarction"
label var riskvar_copd "\hspace{0.25cm} CC: Lung Disease"
label var riskvar_anysurgery "\hspace{0.25cm} Any Previous Cardiac Surgery" 
label var riskvar_previousbypass "\hspace{0.25cm} Any Previous Bypass Surgery"
label var riskvar_previousvalve "\hspace{0.25cm} Any Previous Valve Surgery"
label var riskvar_previouspci "\hspace{0.25cm} Any Previous Revascularization"
label var predicted_risk "\hspace{0.25cm} Predicted STS-PROM"
	
global myvars:  riskvar_age riskvar_fem riskvar_white riskvar_black riskvar_hisp riskvar_othernonwhite ///
	medinc_all medinc_65plus riskvar_numccs riskvar_chf riskvar_diabetes riskvar_hypert ///
	riskvar_stroke riskvar_ami riskvar_copd ///
	riskvar_anysurgery riskvar_previousbypass riskvar_previousvalve riskvar_previouspci ///
	predicted_risk 
	
** Summary by group? 
// estimates clear 
// eststo sum0: qui estpost sum riskvar_* predicted_risk if group == 0
// eststo sum1: qui estpost sum riskvar_* predicted_risk if group == 1
// eststo diff1: qui estpost ttest riskvar_* predicted_risk, by(group) unequal
//
// esttab sum0 sum1 /// diff1 /// 
// 	 using "$output/Tab1_FRAG.tex", se frag replace label substitute(_ \_) /// 
// 	 nomtitle nonumber ///
// 	cells("mean(pattern(1 1 0) fmt(4)) se(pattern(1 1 0) fmt(4)) p(pattern(0 0 1) fmt(4))")
//	
//	
** Pooled summary
estimates clear
estpost tabstat riskvar_age riskvar_fem riskvar_white riskvar_black riskvar_hisp riskvar_othernonwhite ///
	medinc_all medinc_65plus riskvar_numccs riskvar_chf riskvar_diabetes riskvar_hypert ///
	riskvar_stroke riskvar_ami riskvar_copd ///
	riskvar_anysurgery riskvar_previousbypass riskvar_previousvalve riskvar_previouspci ///
	predicted_risk , ///
	c(stat) stat(mean sd min max N )
esttab using "$output/Tab1_FRAG.tex", frag replace ///
 cells("mean(fmt(%13.2fc)) sd(fmt(%13.2fc)) min max count(fmt(0))") ///
 nostar unstack nonumber compress booktabs gap ///
  nomtitle nonote noobs label collabels("Mean" "SE" "Min" "Max" "N") ///
  refcat(riskvar_age "\emph{Patient Demographics}" riskvar_numccs "\emph{Clinical Characteristics}" ///
	riskvar_anysurgery "\emph{Surgical History \& Risk}", nolabel)
********************************************************************************
