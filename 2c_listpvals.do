local allfiles: dir "$datadir/" files "binned_`1'_*"

clear
gen var = ""
foreach f of local allfiles { 
	append using "$datadir/`f'"
}
cap drop if missing(wt)

cap gen se = (coef - lb)/1.96
cap gen t = coef/se
gen p = (1-normal(abs(t))) // one-sided p-values
gsort r_lb
keep p r_lb
di "***** COPY THESE TO PASTE INTO DATA EDITOR BELOW *****"
list p r_lb
