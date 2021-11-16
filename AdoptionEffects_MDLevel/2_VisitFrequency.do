/*******************************************************************************
* Title: Effect of TAVR adoption on cardiologist provision of preventive care: 
	2 -- effect on visit frequency 
* Created by: Alex Hoagland
* Created on: 10/15/2021
* Last modified on: 10/15/2021
* Last modified by: 
* Purpose: Simple event study of TAVR adoption on preventive care visits 
* Notes: 

* Key edits: 
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202105"
global geodata "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/Geography"

ssc install reghdfe
ssc install regsave
********************************************************************************


***** 1. Use panel from 1_EventStudy.do
use "$datadir/TreatmentPanel_AllCardiologist_OutpatientVisits_202110.dta", clear

// at enrollee-provider level, calculate number of visits and avg time between them 
bysort npi bene_id: gen numvisits = _N
bysort npi bene_id (from_dt): gen spacetime = from_dt[_n] - from_dt[_n-1] if _n > 1 & numvisits > 1
replace spacetime = . if spacetime == 0 // consider all claims on the same day as part of same visit

// merge in TAVR adoption dates
merge m:1 npi using "$datadir/EventStudy_20211020.dta", keep(1 3) nogenerate

// quick test: 
gen group = (year >= fyear & !missing(fyear))
ttest spacetime, by(group) unequal // suggests a reduction in 28 days between visits
********************************************************************************
