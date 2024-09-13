global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666"
global datadir "$mydir/2_Data/CMS_Updated202105"
global geodata "$mydir/2_Data/Geography"
global output "$mydir/ToExport/MainFigures"
global output_a "$mydir/ToExport/AppendixFigures"
global allcode "$mydir/3_SourceCode/5_CrowdOut_Decomposition"


clear
	gen bene_id = ""
	save "$datadir/all_OutpatientCardiology.dta", replace

forvalues yr = 2010/2017 { 
	di "YEAR: `yr'"
	use /disk/aging/medicare/data/harm/20pct/car/`yr'/carl`yr'.dta if ///
		inlist(hcpcs_cd, "C2625", "92982", "92984", "92995", "92996", "92980", "92981") | ///
		inlist(hcpcs_cd, "C7531", "C7532", "C7533", "C7534", "C7535","93451", "93452") | ///
		inlist(hcpcs_cd, "93453", "93454", "93455") | ///
		inlist(substr(hcpcs_cd, 1, 4), "C960", "3723" ) | ///
		substr(hcpcs_cd, 1, 2) == "33", clear
	
	gen savr = (inlist(hcpcs_cd, "33405", "33406", "33410", "33411", "33412"))
	gen tavr = (inlist(hcpcs_cd, "33361", "33362", "33363", "33364", "33365", ///
				"33366", "33367", "33368", "33369"))
		
	encode hcpcs_cd, gen(cpt) 
	gen ptca2 = (!missing(cpt) & inrange(cpt, 33361,33440))
	replace ptca2 = 1 if inlist(substr(hcpcs_cd, 1, 4), "C960", "3723" )
	replace ptca2 = 1 if inlist(hcpcs_cd, "C2625", "92982", "92984", "92995", "92996", "92980", "92981") | ///
		inlist(hcpcs_cd, "C7531", "C7532", "C7533", "C7534", "C7535","93451", "93452") | ///
		inlist(hcpcs_cd, "93453", "93454", "93455")
	replace ptca2 = 1 if (!missing(cpt) & inrange(cpt, 33460, 33468))
	replace ptca2 = 1 if (!missing(cpt) & inrange(cpt, 33471, 33478))
	replace ptca2 = 1 if (!missing(cpt) & inrange(cpt, 37700, 37735))
	replace ptca2 = 1 if (!missing(cpt) & inrange(cpt, 33510, 33548))
	replace ptca2 = 1 if (!missing(cpt) & inrange(cpt, 37184, 37218))
// 	stenting: 3723* , C2625
// 	PTCA: 92982, 92984, 92995, 92996, 92980, 92981, C7531, C7532, C7533, C7534, C7535
// 	surgical procedures on aortic valve: 33361-33417, 
// 	surgical procedures on mitral valve: 33418-33440
// 	surgical procedures on tricuspid valve: 33460-33468
// 	surgical procedures on pulmonary valve: 33471-33478
// 	CABG: 37700-37735; 33510-33548, C960*
// 	Transcatheter procedures on arteries and veins: 37184-37218
// 	cardiac catheterization: 93451, 93452, 93453, 93454, 93455


	keep if ptca2 == 1 | tavr == 1 | savr == 1
	
	* Combine and save
	append using "$datadir/all_OutpatientCardiology.dta"
	save "$datadir/all_OutpatientCardiology.dta", replace
	}
********************************************************************************


***** Keep based on NPIs with appropriate specialty
use "$datadir/all_IVcardiologists", clear
append using "$datadir/all_CTsurgeons.dta"
append using "$datadir/all_othercardiologists.dta"
keep npi group
duplicates drop

bysort npi: gen test = _N
drop if group == 3 & test > 1
bysort npi: replace test = _N
drop if test > 1 // drops 5 MDs who are both IVCs and CTs at different points in time
drop test

rename npi prf_npi 
merge 1:m *npi using "$datadir/all_OutpatientCardiology.dta", keep(3) nogenerate // drops ~ 10% of claims 

compress
save "$datadir/all_OutpatientCardiology.dta", replace
********************************************************************************


*** Merge in riskvar information 
use bene_id using "$datadir/all_OutpatientCardiology.dta", clear
duplicates drop // 389,194 beneficiaries captured 
bene, keep(3) keepusing(riskvar* bene_id) nogenerate
duplicates drop
	// note: this grabs demographic information for all but 4,609 individuals (1.2%)
gcollapse (max) riskvar_fem riskvar_black riskvar_hisp riskvar_othernonwhite riskvar_dual* (mean) riskvar_adi_*, by(bene_id) fast 
	// merge back into main data
merge 1:m bene_id using "$datadir/all_OutpatientCardiology.dta", keep(2 3) nogenerate
compress
save "$datadir/all_OutpatientCardiology.dta", replace
********************************************************************************


***** Look at trends over the year for treatment/control CZIDs
use "$datadir/all_OutpatientCardiology.dta", clear
// keep bene_id *dt file_year  savr tavr ptca2
gen ssacd = ""
gen zip = ""
forvalues yr = 2010/2016 { 
	di "***** YEAR: `yr' *****"
	merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsf/`yr'/bsfab`yr'.dta, ///
		keepusing(bene_id file_year cnty_cd state_cd bene_zip) ///
		keep(1 3) nogenerate
	replace ssacd = state_cd + cnty_cd if missing(ssacd)
	replace zip = bene_zip if missing(zip)
	drop cnty_cd state_cd bene_zip
}
gen g_fileyear = file_year
merge m:1 bene_id g_fileyear using /disk/aging/medicare/data/harm/100pct/bsf/2017/bsfab2017.dta, ///
		keepusing(bene_id g_fileyear cnty_cd state_cd bene_zip) ///
		keep(1 3) nogenerate
replace ssacd = state_cd + cnty_cd if missing(ssacd)
replace zip = bene_zip if missing(zip)
drop cnty_cd state_cd bene_zip g_fileyear

// construct CZID and adoption date
// First, go from SSA state/county to FIPS
merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate
rename fipsc FIPS // Now go from FIPS to CZ
merge m:1 FIPS using "$geodata/CZs_Crosswalk", keep(1 3) keepusing(CommutingZoneID2000) nogenerate
rename Commuting CZID
drop ssacd FIPS 
drop if missing(CZID)
gen yq = qofd(thru_dt)

// drop some unneeded variables
drop prf_upin prgrpnpi mdfr* lpr* line_* thrpy* clm_next* hpsasccd carrxnum hcth* lnnd* carr_*

compress
save "$datadir/all_OutpatientCardiology.dta", replace
********************************************************************************


/***** Optional figure (sense check) ****
// merge in adoption dates (just by year)
preserve
use "$datadir/IVCEventStudy_Base.dta" if tavr == 1, clear
append using "$datadir/all_OutpatientCardiology"
keep if tavr == 1
cap drop t_adopt
gen t_adopt = year if tavr == 1
gcollapse (min) t_adopt, by(CZID) 
drop if missing(t_adopt)
save "$datadir/tomerge.dta", replace
restore

use "$datadir/all_OutpatientCardiology.dta", clear
merge m:1 CZID using "$datadir/tomerge.dta", keep(1 3) nogenerate
rm "$datadir/tomerge.dta"

// graphs (mostly PTCA)
gcollapse (sum) tavr savr ptca2 , by(CZID t_adopt yq) fast
gcollapse (p50) tavr savr ptca2, by(t_adopt yq) fast 
replace ptca2 = ptca2 + tavr 
twoway (line ptca2 yq if t_adopt == 2011) ///
	(line ptca2 yq if t_adopt == 2012) ///
	(line ptca2 yq if t_adopt == 2013) ///
	(line ptca2 yq if t_adopt == 2014) ///
	(line ptca2 yq if t_adopt == 2015) ///
	(line ptca2 yq if t_adopt == 2016) ///
	(line ptca2 yq if t_adopt == 2017) ///
	(line ptca2 yq if t_adopt == .), ///
	xtitle("Calendar Time (Quarters)") ytitle("") ///
	legend(order(1 "Adopted in 2011" 2 "Adopted in 2012" 3 "Adopted in 2013" 4 "Adopted in 2014" 5 "Adopted in 2015" 6 "Adopted in 2016" 7 "Adopted in 2017" 8 "Did not adopt by 2017")) // similar trends 
********************************************************************************/
