/*******************************************************************************
* Title: Estimate patient risk / appropriateness for TAVR
* Created by: Alex Hoagland
* Created on: 2/21/2022
* Last modified on: 
* Last modified by: 
* Purpose: Identifies risk/appropriateness for TAVR
* Notes: - identifies a risk measure for each patient-year for all AS, OP, and IP patients (can trim later?)
	- single risk index as predicted probability of TAVR, or PCA of covariates?

* Key edits: 
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202105"
global geodata "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/Geography"
********************************************************************************


***** 1. Use all cardiology patients (not just inpatient; can trim this down later)
use "$datadir/TreatmentPanel_AllCardiologist_OutpatientVisits_202110.dta", clear 
	// note: this data set needs to be updated with the new cardiologists? Might be missing some patients
keep bene_id 
duplicates drop
append using "$datadir/all_InpatientCardiology" // add any who got inpatient care without outpatient care
keep bene_id 
duplicates drop
// about 8.8 million patients

sort bene_id 
compress
save "$datadir/AllPatients_BeneIDs.dta", replace
********************************************************************************


***** 2. Match in major beneficiary information (risk scores, chronic conditions, etc.)
clear
gen year = .
save "$datadir/PatientRisk.dta", replace

// Merge in dummies for chronic conditions and utilization in each year
forvalues i = 2010/2017 { 
	di "YEAR: `i'"
	use "$datadir/AllPatients_BeneIDs.dta", clear
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfcc/`i'/bsfcc`i'.dta, keep(3) nogenerate // chronic conditions
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfcu/`i'/bsfcu`i'.dta, keep(3) nogenerate // cost and utilization
	gen year = `i'
	append using "$datadir/PatientRisk.dta"
	compress
	save "$datadir/PatientRisk.dta", replace
}

// Merge in age/sex information
use "$datadir/PatientRisk.dta", clear
forvalues i = 2010/2017 { 
	di "YEAR: `i'"
	merge 1:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfab/`i'/bsfab`i'.dta, ///
		keep(1 3 4 5) nogenerate update ///
		keepusing(age sex state_cd cnty_cd zip* race death_dt) 
}
save "$datadir/PatientRisk.dta", replace
********************************************************************************


***** 3. Variables used in calculating STS-PROM
// sex, age, race (black, hispanic, white, other), # of chronic conditions, AFib, CHF, heart failure (NHYA class IV), severe CLD, 
// cerebrovascular disease, diabetes mellitus, insulin use, dialysis, hypertension, 
// immunosuppressive treatment, peripheral vascular disease, prior surgery (dummy, last year), 
// urgent AVR, mitral stenosis, aortic stenosis, tricuspid stenosis, pulmonic stenosis, 
// aortic valve insufficienty, mitral insufficiency, tricuspid insufficiency, 
// pulmonic insufficiency, previous PCI, liver cirrhosis, 
// pulmonary hypertension, calcified/diseased aorta, recurrent pulmonary embolism, 
// right ventricular failure, cachexia, hypercholesterolemia, past smoker (if coded), chronic lung disease, 
// bmi (if coded sufficiently), stroke, endocarditis, renal failure, previous coronary artery bypass, 
// previous valve surgery, AMI, angina, cardiogenic shock, resuscitation, arryhthmia, 
// time trend (12-month intervals) 
// --> note: use DXI system for these diagnoses (with reverse maps to ICD-9-CM)
// currently, no interactions used (that I have all data for) 
