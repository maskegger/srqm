*! SRQM data preparation script
*! last upgrades: QOG 2013, GSS 2012
cap pr drop srqm_data
pr srqm_data
  syntax anything [using/] [, data(string)]

tokenize `anything'

if "`1'" == "" {
    di as err "Error: provide a dataset handle (", "$srqm_datasets", ") or 'all'"
    exit 198
}

if "`using'" != "" {
  cap log close srqm_data
  log using "$srqm_wd/setup/srqm_data.log", name(srqm_data) replace
}

if "`data'" == "" {
  local src = "~/Documents/Data"
  di as txt "Using personal default for local raw files:", "`src'"
}

di as inp _n "Updating `1' teaching dataset(s)..." _n

// --------------------------------------------------------- ESS 2008-2010 -----

* URL: http://www.europeansocialsurvey.org/

if inlist("`1'", "all", "ess0810") {
  // Get the data (downloaded from the website).
  use "`src'/ESS/ESS4e04_3.stata/ESS4e04_3.dta", clear

  // Zero-match merge (non-longitudinal survey).
  merge 1:1 idno cntry edition using "`src'/ESS/ESS5e03_2.stata/ESS5e03_2.dta", nogen

  // Encode missing values (same code for both ESS rounds).
  run "`src'/ESS/ESS4e04_3.stata/ESS_miss.do"

  // Trim (this threshold drops nation-specific questions).
  srqm_datatrim, k(9)

  // Get codebook.
  copy "`src'/ESS/ESS4_data_documentation_report_e05_3.pdf" data/ess0810r4_codebook.pdf, replace
  copy "`src'/ESS/ESS5_data_documentation_report_e03_2.pdf" data/ess0810r5_codebook.pdf, replace

  srqm_datamake, label(European Social Survey 2008-2010) filename(ess0810)
}

// --------------------------------------------------------- GSS 2000-2012 -----

* URL: http://www3.norc.org/GSS+Website/

if inlist("`1'", "all", "gss0012") {
	// Get the data.
  	loc gss GSS7212_R6
	cap use "`src'/GSS/`gss'.dta", clear

	// Download the 1972-2012 cumulative file if needed (large, > 350 MB).
	if _rc==601 {
		local link "http://publicdata.norc.org/GSS/DOCUMENTS/OTHR/GSS_stata.zip"
		copy `link' gss.zip, replace
		unzipfile gss.zip
		use `gss'.dta, clear
		rm gss.zip // comment out to keep the cumulative data zip
		rm `gss'.dta // comment out to keep the cumulative data file
	}

	// Subset years.
	drop if year < 2000

	// Trim (low threshold to accommodate single-year questions)
	// Note: be carefult to maintain a threshold that is sufficiently high to
	// keep less than 2047 veriables in order for the course to run under old
	// or limited of versions of Stata (at Sciences Po, Stata 11 IC). The value
	// below leaves 2,045 variables.
	srqm_datatrim, k(5.75)

	// Get the codebook.
	local file data/gss0012_codebook.pdf
	local link "http://publicdata.norc.org/GSS/DOCUMENTS/BOOK/GSS_Codebook.pdf"
	cap conf f `file'
	if _rc==601 copy `link' `file', replace

	srqm_datamake, label(U.S. General Social Survey 2000-2012) filename(gss0012)
}

// -------------------------------------------------------- NHIS 1997-2011 -----

* URL: http://www.cdc.gov/nchs/nhis.htm

if inlist("`1'", "all", "nhis9711") {
	// Get the data (downloaded from the website).
  loc data "ihis_00001"
	copy "`src'/NHIS/9711/`data'.zip" "`data'.zip"
  unzipfile "`data'.zip"
  do "`src'/NHIS/9711/`data'.do"
  erase "`data'.dat"
  erase "`data'.zip"

  // keep sample children and adults for year 1997-2011
  qui keep if year > 1997 & astatflg == 1
  drop cstatflg astatflg

  // simplify race variable
  qui gen raceb = racea
  qui replace raceb = 1 if raceb == 100
  qui replace raceb = 2 if raceb == 200
  qui replace raceb = 3 if hispeth != 10
  qui replace raceb = 4 if raceb > 310 & raceb < 570
  // 310 American Indian, 570 other, 580 unreleasable, 600 multiple
  qui replace raceb = . if raceb > 4
  la de raceb_lbl 1 "White" 2 "Black" 3 "Hispanic" 4 "Asian"
  la val raceb raceb_lbl
  la var raceb "Racial-ethnic profile"
  notes raceb: ///
  	Assembled from hispeth and racea, excluding American Indians and unclassifiable cases.

  // correlate class estimates and official figures of Body Mass Index
  qui gen bmi2 = weight * 703 / height^2 if weight < 996 & height < 96
  fre bmi if abs(bmi - bmi2) > 1, r(5)
  mean bmi bmi2 if bmi < 99.8 [pw = sampweight]
  kdensity bmi, addplot(kdensity bmi2) ti("") ///
    legend(order(1 "Official measure" 2 "Public file"))
  drop bmi bmi2

  // drop 10-pt health status (available only for year 1988)
  drop health10pt
  // drop household weights (unused)
  drop hhweight
  // drop supp. weights flags (unavailable after 1997)
  drop supp2wt

	// Trim.
	srqm_datatrim

	srqm_datamake, label(U.S. National Health Interview Survey 1997-2011) filename(nhis9711)
}

// -------------------------------------------------------------- QOG 2013 -----

* URL: http://qog.pol.gu.se/

if inlist("`1'", "all", "qog2013") {
	// Get the data.
	cap use "`src'/QOG/QOG Standard 2013 (December)/qog_std_cs.dta", clear

	// Download if needed. This version was uploaded to the server in 2014,
	// but is still QOG Standard December 2013. This might change later, so
	// the code will need a small update to avoid downloading more recent
	// QOG data, which is much heavier.
	if _rc==601 use "http://www.qogdata.pol.gu.se/data/qog_std_cs.dta", clear

	// Trim (lower threshold).
	srqm_datatrim, k(12.5)
	
	// Get the codebook.
	local file data/qog2013_codebook.pdf
	local link "`src'/QOG/QOG Standard 2013 (December)/qog2013_codebook.pdf"
	cap conf f `file'
	if _rc==601 copy "`link'" "`file'", replace

	srqm_datamake, label(Quality of Government 2013) filename(qog2013)
}

* Note: the -qog- and -qogbook- packages available from SSC have been outdated
* for over a year. They can still be installed by using the -srqm_pkgs- command
* with the -extra- option, but are not likely to work properly.

// -------------------------------------------------------------- WVS 2000 -----

* URL: http://www.worldvaluessurvey.org/

if inlist("`1'", "all", "wvs2000") {
	// Get the data.
	cap use "`src'/WVS/wvs2000/wvs2000_v20090914.dta", clear

	// Download if needed.
	if _rc==601 {
		local link "http://www.asep-sa.org/wvs/wvs2000/wvs2000_v20090914_stata.zip"
		copy `link' temp.zip, replace
		unzipfile temp.zip
		use wvs2000_v20090914.dta, clear
		rm temp.zip
		rm wvs2000_v20090914.dta
	}

	// No trim: missing values are not properly encoded.
	// Also, some items are asked only in a few countries (e.g. Islam, neighbours).

	// Capitalize country names
  	// Thanks to William A. Huber: http://stackoverflow.com/q/12591056/635806
	local sLabelName: value l v2
	di "`sLabelName'"
	qui levelsof v2, local(xValues)
	foreach x of local xValues {
	    local sLabel: label (v2) `x', strict
	    local sLabelNew = proper("`sLabel'")
	    di as txt "`x': `sLabel' ==> `sLabelNew'"
	    label define `sLabelName' `x' "`sLabelNew'", modify
	}

	// Get the codebook.
	local file data/wvs2000_codebook.pdf
	local link "`src'/WVS/wvs2000/wvs2000_codebook.pdf"
	cap conf f `file'
	if _rc==601 copy `link' `file', replace

	srqm_datamake, label(World Values Survey 2000) filename(wvs2000)
}

cap log close srqm_data

end

// ttyl
