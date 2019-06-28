//run("DTP findLocalPuncta v4.8.1.2b callable", "[rfch]=1 [nnch1]=2 [nnch2]=3 [padrefroi]=2 [srchrad]=15 [NNFWHMradius]=5 [mnfitlen]=10 [mxfitlen]=24 [lnwd]=2 [radifnofit]=3 [fwhmlmt]=50 [nnns]=2 [mxdist]=15 [noiselmt]=15 [bgsubrad]=-1 [rptclosest] [gausspk] [saveOutput] [npApnd] [npsfx]=_4.8.1.1 [nprpts]=none");

// NOTE - in order to be able to load NN ROIs from file, I think we will have to combine ref ROIs and NN ROIs into a single .zip file, and signal FLP macro to split the ROI file into 2 temp files.
// This will be a bit of a job. Would also require coding the breakpoint between ROI sets into the .zip file name somehow.

// v6.1.0.0 - moved main macro into the batch script to be able to specify nearest neighbour sets of ROIs from a folder of .zip files
//170129 - getting close - check for unaddress variable with runs then build in ability to specific groups of folders

// v6.0.0.9b - need to sort out why the macro seems to be finding an empty index in the image and ROI arrays after the first lap.
// DTP_findLocalPuncta_v7.0.0.0_2DGauss.ijm was renamed MINER_v1.0 after publishing in AJP 2018
//190403 MINER_v1.0
//looks like NNXctr and NNYctr might be 0.5 off (i.e. on pixel upper left instead of center)
//190405 - have managed to reduce distance between centers by ~0.2 px by updating distance calc with NNcenters 
// Done - 	next step is to update out put to report distances between geo COM and fitted for all reports. and recluster columns
// have analysis parameters save once to the output folder including a brief description of what output headers mean. 
// move FWHM options to top of macro
// done - re-organize columns of output data
// done - in one image 1 px was better than 3 px - should do sensitivity analysis of linewidth for FWHM determination on an image vs self
// sort out how to anlayze multiple ROI sets matching a given image
	// have sorted out making paired list of images with multiple ROIs. Need a way to avoid the system thinking that save a new set of resutls of 
	// a 2nd set of ROIs isn't going to "overright" the first image. Maybe save by Roi file name as output. 
	
// for 	v2.2 - need to fix overlap calculations
// v2.3 - look like NN ROIs from multiple files works smoothly. If no NN ROIs for a given image, 2 small dummy ROIs are created at origin. Likely too far from all but a few ROIs. Also have area == 1
// v2.3 - seems like the system no longer adds a small box to overlay if no NN. Would be nice to restore
//      - fixed how nnMean is calcualted for nnROIs from file. 
//      - overlap of ROIs rebuilt to run >10x faster. Now only adds ~10% to total processing time. 

version = "v2.3d";

//Miner v2.0 - if no images open assume working in batch mode and nSlicesToStart = 3
var nSlicesToStart = 0;
	if (nImages==0) {
		nSlicesToStart = 3;
	} else {
		nSlicesToStart = nSlices();	
	}

	//*****************************************************************
// USER DEFINED PARAMETERS of findLocalPuncta
// set [nnch2]=[none-0] if you do not want to analyze a second set of ROIs

help = "<html>"
+"<b>Description of INPUT Parameters</b><br>"
  + "<b>[rfch]</b>=1 - image channel (base 1) containing reference structure <br>"
 + "<b>[nnch1]=# and [nnch2]=#</b> - image channel(s) (base 1) containing the nearest neighbour structures <br>"
 + "<b>[ch1clr] = 'color' , [ch2clr] = magenta, [ch3clr]=white</b> - colour of the overlays for each channel using standard imagej colours <br>"
 + "<b>[nnsortby]</b>=center or perimeter - determined whether the distance between NN candidates and ref ROis using the centre-centre or perimeter-cenre distance <br>"
 + "<b>[refctrtype]</b>= geometric or COM or fitted - describes method to determine center of ref ROIs and NN ROIs <br>"
 + "<b>[roiwidth]</b>=0 - thickness of outline in output image <br>"
 + "<b>[padrefroi]</b>=2  - additional # pixels beyond major/minro axes of length of line used to start the FWHM in ref ROI <br>"
 + "<b>[srchrad]</b>=20 - search radius for NN <br>"
 + "<b>[NNFWHMradius]</b>=5  - radius of NN ROIs - becomes 'roiRadius'. <br>"
 + "<b>[mnfitlen] & [mxfitlen]</b> - min and max length of line used to fit FWHM <br>"
 + "<b>[lnwd]</b>=1 - thickness of line used to calculate FWHM. <br>" 		 
 + "<b>[radifnofit]</b>=5 <br>"
 + "<b>[fwhmlmt]</b>=15	- upper limit of FWHM to be considered accurate / realistic estimate <br>"
 + "<b>[nnns]</b>=1  - number of nearest neighbours to be analyzed <br>"
 + "<b>[noiselmtref]</b>=2.0 - to find local maxima in ref ROIs, noise limit is image/ROI mean + noiselmtref+SD <br>"
 + "<b>[noiselmtnn]</b>=2.0  - to find local maxima across NN image, noise limit is image/ROI mean + noiselmtref+SD <br>"
 + "<b>[refroisfromfile]</b> Are reference ROIs going to be loaded from a .zip file <br>"
 + "<b>[npsfx]</b>=_findNNv6.1.0.7 - no longer used <br> "
 + "<b>[gausspk]</b> Advanced settings. If included the gauss fitted maxima is used as the ref ROI mean value, otherwise the local maxima is used <br>"
  + "<b>[saveOutput]</b> Advanced settings. Should usually be included to autosave results		<br> "
 + "<b>[npsvtoprnt]</b> Advanced settings. Save results to parent directory - somewhat outdated <br>"
 
 +"... <br>"

+"<b>Description of OUTPUT values</b><br>"
+"<b>ROI</b>:	ROI number from ROI manager<br>"
+"<b>new ROI</b>: 	1 = row is first NN of curr ROI, 0 = row is NOT first NN of curr ROI<br>"
+"<b>proximity</b>: 	-1 = NN is closer to another ROI, 0 = first NN, 1 = 2nd NN....<br>"
+"			note that NN proximity can be sorted by distance or intensity of NN peak<br>"
+"<b>channel</b>:    channel in which NN are being searched for<br>"
+"<b>centroid X / centroid Y</b>: 	centroid of reference ROIv<br>"
+"<b>localMax X / localMax Y</b>: 	brightest pixel within reference ROI<br>"
+"<b>ref major FWHM / ref minor FWHM</b>: 	full-width half-max estimates of reference ROI<br>"
+"<b>ref X Center / ref Y Center</b>: 	centre of ref ROI calculated by 2 x 1D FWHM gaussian fits<br>"
+"<b>dist to peak</b>: 	distance between brightest pixesl in ref ROI and NN <br>"
+"<b>angle</b>:   direction to NN <br>"
+"<b>X Geo / Y Geo</b>:  <br>"
+"<b>major FWHM / minor FWHM</b>: 	full-width half-max estimates of NN ROI <br>"
+"					x.nnnn = failure to fit, beyond max allowed value  <br>"
+"<b>Note - if values below = -1, no NN was found, mean NN values are measured within ref ROI</b> <br>"
+"<b>X Center / Center</b>:	 centre of ref ROI calculated by 2 x 1D FWHM gaussian fits <br>"
+"<b>dist bw Centers</b>: 	distance between fitted centres of ref ROI and NN <br>"
+"<b>NN / ref Mean</b> : 	 mean intensity of NN or ref ROI <br>"
+"<b>NN / ref fitted height</b>:  	average (major & minor axes) height - baseline of gaussian fit of puncta profile <br>"
+"<b>NNr2</b>:   R squared goodness of gaussian fit of profiles through NN puncta <br>"
+"<b>bestCenter2LocalMax</b>: 	dist from ref brightest pixel to fitted centre of NN <br>"
+"	Confirmed 15/04/03 - 0 = means fiited center of NN is immediately above ref ROI max pixel <br>"
+"<b>dFromRefPerimeter</b>: <0 or >0 = NN peak is x pixels inside or outside of the boarder of the ref ROI   <br>"
+"<b>nnAngle</b>:  orientation of major axis of NN <br>"
+"</font>";

var		sliceQuerry2 = "0";	
var		imgType = ".tif";	
var		verbose = false;

	sliceList0 = newArray("1","2","3","4","5");
	sliceList1 = newArray("0","1","2","3","4","5");
	roiColors = newArray("white","red","green","blue","magenta","cyan","orange","yellow","gray","darkGray","black");
	sortByList = newArray("center","perimeter");
	refCtrTypeList = newArray("fitted", "COM","geometric");
	roisFromFileList = newArray("none", "ref_ROIs","ref&NN_ROIs");
	imgTypes = newArray(".tif", ".jpg",".nd2",".stk");
		
	Dialog.create("MINER "+version);
	Dialog.addMessage("CHANNEL SELECTION & CENTER OF REFERENCE CALCULATION METHOD:");
	Dialog.addChoice("[rfCh] channel with reference puncta ", sliceList0,call("ij.Prefs.get", "dialogDefaults.default0", "1"));
	Dialog.addToSameRow() ;
	Dialog.addChoice("[nnCh1] and NN puncta ", sliceList0,call("ij.Prefs.get", "dialogDefaults.default1", "2"));
		if (nSlicesToStart>2) {
			Dialog.addToSameRow() ;
			Dialog.addChoice("[nnCh2] (0=not analyzed)  ", sliceList1,call("ij.Prefs.get", "dialogDefaults.default2", "3"));
		}
	Dialog.addChoice("[nnsortby] NNs ranked by dist from...", sortByList,call("ij.Prefs.get", "dialogDefaults.nnSortBy", "perimiter"));
	Dialog.addToSameRow() ;
	Dialog.addChoice("[refctrtype] ref centre type ", refCtrTypeList,call("ij.Prefs.get", "dialogDefaults.refCtrType", "fitted"));
	Dialog.addChoice("[loadROIs] load ROIs from .Zip file(s)", roisFromFileList, call("ij.Prefs.get", "dialogDefaults.chooseROIset", roisFromFileList[1]));
	Dialog.addToSameRow() ;
	Dialog.addMessage("prompts will follow to specify folders containing .zip files");
	Dialog.addChoice("[imgType] format of images...", imgTypes,call("ij.Prefs.get", "dialogDefaults.imgType", ".tif"));

	Dialog.addMessage("NN SEARCH PARAMETERS (distances are measured in pixels):");
	Dialog.addNumber("[mxDist] NN search radius", parseInt (call("ij.Prefs.get", "dialogDefaults.maxNNdist", 15)));	
	Dialog.addToSameRow() ;
	Dialog.addNumber("[nNNs] # of NNs per ref ROI", parseInt (call("ij.Prefs.get", "dialogDefaults.numNNstats", 1)));
	Dialog.setInsets(0, 200, 0);
	Dialog.addMessage(" ~ Reference ROI centers & NN candidates (if not from file) are 'local maxima' with [mean + n*SD] of image ~");
	Dialog.addNumber("[noiselmtref] ref image", parseFloat (call("ij.Prefs.get", "dialogDefaults.noiselmtref", 10)));
	Dialog.addToSameRow() ;
	Dialog.addNumber("[noiselmtnn] & NN image(s)", parseFloat (call("ij.Prefs.get", "dialogDefaults.noiselmtnn", 10)));
	Dialog.addMessage("Full-Width-Half-Max PARAMETERS (distances are measured in pixels):");
	Dialog.addNumber("[padRefROI] pad axis of Ref ROI for FWHM ",parseInt (call("ij.Prefs.get", "dialogDefaults.refRoiPad", 1)));
	//Dialog.addNumber("[srchRad] radius of search (pixels) for NNs ",parseInt (call("ij.Prefs.get", "dialogDefaults.radius", 13)));
	Dialog.addToSameRow() ;
	Dialog.addNumber("[lnWd] FWHM line width",parseInt (call("ij.Prefs.get", "dialogDefaults.lineWidth", 3)));                                    				 //added V8.0.0.1
	Dialog.addNumber("[mnFitLen] min length of FWHM line profle (>4) ",parseInt (call("ij.Prefs.get", "dialogDefaults.minFWHMLineLength", 5)));  		 // added of v4.8.0.5 
	Dialog.addToSameRow() ;
	Dialog.addNumber("[mxFitLen] max length... ",parseInt (call("ij.Prefs.get", "dialogDefaults.maxFWHMLineLength", 19)));  		 // added of v4.8.0.5 
	Dialog.addNumber("[NNFWHMradius] NN radius for FWHM fit",parseInt (call("ij.Prefs.get", "dialogDefaults.NNFWHMradius", 5)));         //  v4.8.0.5 - description changed but same application
	Dialog.addToSameRow() ;
	Dialog.addMessage("Superceded by fitted ellipse if NN ROIs from file.");
	Dialog.addNumber("[FWHMlmt] Max NN FWHM (-1 = off)", parseInt (call("ij.Prefs.get", "dialogDefaults.NNlimitFWHM", -1)));
	Dialog.addToSameRow() ;
	Dialog.addNumber("[radIfNoFit] NN radius if FWHM fails ", parseInt (call("ij.Prefs.get", "dialogDefaults.radiusNNPuncta", 4)));
	Dialog.addMessage("COLORS OF NN OVERLAYS IN OUTPUT IMAGES");
	Dialog.addChoice("[ch1Clr] Reference channel", roiColors,call("ij.Prefs.get", "dialogDefaults.ch1Clr", "magenta"));
	Dialog.addToSameRow() ;
	Dialog.addChoice("[ch2Clr] NN1... ", roiColors,call("ij.Prefs.get", "dialogDefaults.ch2Clr", "magenta"));
		if (nSlicesToStart>2) {
			Dialog.addToSameRow() ;
			Dialog.addChoice("[ch3Clr] NN2... ", roiColors,call("ij.Prefs.get", "dialogDefaults.ch3Clr", "orange"));
		}
	Dialog.addMessage("OPTIONAL FEATURES:");
	Dialog.setInsets(0, 30, 0);
	Dialog.addCheckbox("[overlap] calculate fractional overlap of ref & NN", call("ij.Prefs.get", "dialogDefaults.calcOverlap", false));
	Dialog.addToSameRow() ;
	Dialog.addString("[npSfx] output text file suffix", call("ij.Prefs.get", "dialogDefaults.savetxtSuffix", "_findNN"+version),20);
	Dialog.setInsets(0, 30, 0);
	Dialog.addCheckbox("[verbose] minimal (uncheck) or complete (check) log", call("ij.Prefs.get", "dialogDefaults.verbose", false));
	msg = " I. If load ROIs from .Zip file(s)!=none, this dialog box will be followed by prompts to select folders containing:\n"
	+"       1. The images to be analyzed.    2. .zip files ROIs in your reference channel.   3. .zip files of ROIs in your NN channel(s).\n "
	+"II. Ref ROIs can be in the image folder. NN ROI files for each channel should be in a separate folder.\n"
	+"III. .zip ROI file names must contain a paired image name less its suffix.\n"
	+"III. Multiple .zip files can be anaylzed for each image if there is some unique string for each .zip file (i.e. image.tif, image_partA.zip, image_partB.zip )";
	Dialog.addMessage(msg);	
	Dialog.addHelp(help); 
	Dialog.show();

	//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	sliceRefString = Dialog.getChoice();		call("ij.Prefs.set", "dialogDefaults.default0", sliceRefString);
	sliceRef = parseInt(sliceRefString);
	sliceQuerry1 = Dialog.getChoice();			call("ij.Prefs.set", "dialogDefaults.default1", sliceQuerry1);
					call("ij.Prefs.set", "dialogDefaults.default2", sliceQuerry2);
	if (nSlicesToStart>2)	{
		sliceQuerry2 = Dialog.getChoice();		call("ij.Prefs.set", "dialogDefaults.default2", sliceQuerry2);
	}
	nnSortBy = Dialog.getChoice();			call("ij.Prefs.set", "dialogDefaults.nnSortBy", nnSortBy);
	refCtrType = Dialog.getChoice();			call("ij.Prefs.set", "dialogDefaults.refCtrType", refCtrType);
	chooseROIset = Dialog.getChoice();		call("ij.Prefs.set", "dialogDefaults.chooseROIset", chooseROIset);

	imgType = Dialog.getChoice();		call("ij.Prefs.set", "dialogDefaults.imgType", imgType);
	
	maxNNdist = Dialog.getNumber();		 	call("ij.Prefs.set", "dialogDefaults.maxNNdist", maxNNdist);
	numNNstats = Dialog.getNumber();		call("ij.Prefs.set", "dialogDefaults.numNNstats", numNNstats);
	noiselmtref = Dialog.getNumber();			call("ij.Prefs.set", "dialogDefaults.noiselmtref", noiselmtref);
	noiselmtnn = Dialog.getNumber();			call("ij.Prefs.set", "dialogDefaults.noiselmtnn", noiselmtnn);

	refRoiPad = Dialog.getNumber();			call("ij.Prefs.set", "dialogDefaults.refRoiPad", refRoiPad);
	//radius = Dialog.getNumber();
		//	call("ij.Prefs.set", "dialogDefaults.radius", radius);
	lineWidth = Dialog.getNumber();			call("ij.Prefs.set", "dialogDefaults.lineWidth", lineWidth);
	minFWHMLineLength = Dialog.getNumber();		call("ij.Prefs.set", "dialogDefaults.minFWHMLineLength", minFWHMLineLength);
	maxFWHMLineLength = Dialog.getNumber();		call("ij.Prefs.set", "dialogDefaults.maxFWHMLineLength", maxFWHMLineLength);
	NNFWHMradius = Dialog.getNumber();			call("ij.Prefs.set", "dialogDefaults.NNFWHMradius", NNFWHMradius);
	NNlimitFWHM = Dialog.getNumber();		call("ij.Prefs.set", "dialogDefaults.NNlimitFWHM", NNlimitFWHM);
	radiusNNPuncta = Dialog.getNumber();	call("ij.Prefs.set", "dialogDefaults.radiusNNPuncta", radiusNNPuncta);

	ch1Clr = Dialog.getChoice();			call("ij.Prefs.set", "dialogDefaults.ch1Clr", ch1Clr);
	ch2Clr = Dialog.getChoice();			call("ij.Prefs.set", "dialogDefaults.ch2Clr", ch2Clr);
	if (nSlicesToStart>2)	{
		ch3Clr = Dialog.getChoice();		call("ij.Prefs.set", "dialogDefaults.ch3Clr", ch3Clr);
	} else {	
		ch3Clr = "white";					call("ij.Prefs.set", "dialogDefaults.ch3Clr", "white");
	}
	calcOverlap = Dialog.getCheckbox();		call("ij.Prefs.set", "dialogDefaults.calcOverlap", calcOverlap);
	txtSuffix = Dialog.getString();				call("ij.Prefs.set", "dialogDefaults.savetxtSuffix", txtSuffix);

	if (calcOverlap==true) {
		 calOverlapString = " [calcoverlap]";
	} else {
		calOverlapString = "";
	}
	verbose = Dialog.getCheckbox();		call("ij.Prefs.set", "dialogDefaults.verbose", verbose);

	// Additional user variables: (also search for FWHM Variables)
	maxPad = maxFWHMLineLength - minFWHMLineLength;
	chooseCloserNN = true; // past option to sort NN by distance vs brightness. Option removed in Miner v2.0
	bkGdSubtrRad = -1;
	gaussPeakReported = false;
	autoSaved = true;
	saveToCurrDir = true;
	appendParameters = false;
	roiLineWidth = 0;

	//Global variables that need to be visible to the findLocalPuncta() function
	var saveSampleImages = true;  // true/false - saves copies of images with NN ROIs overlayed on them
	var overWrite = false; // overwrite previous output
	var doTimeStamp = true; // time stamp the output folder. This subverts the need to overwrite 
	var doBatch = true; // runs in batch mode to be faster
	var do2DGauss = false; // not yet ready. 
	var	imgFolder = "";
	var	roisC1 = "";
	var	roisC2 = "";
	var	roisC3 = "";
	var refROIsUniqueString = "";
	var NN1ROIsUniqueString = "";
	var	NN2ROIsUniqueString = "";
	var usesDummy = false;
			
	var useDummyROI = false; //a trigger for when there is no NN ROI matching a Ref ROI file. 
	 //will trigger creating a "dummy.zip" file in the ImageJ directory with a 3x3 square pixel at the origin
	 //this will be important so that Ref ROIs can still be characterized, even without any NNs
								 	
	var nnROIsFromFile = false;	
	nnROIsFromFileParam = "";
	if (chooseROIset== "ref&NN_ROIs") { 
		nnROIsFromFile = true;
		nnROIsFromFileParam = "[nnroisfromfile] ";
	}

//========================================================================================
//Collect paths for image folder, and folders containing ref ROIs and NN ROIs if desired. 
//========================================================================================


if (chooseROIset!= "none") {
/*
	msg2 = "";
	if ((chooseROIset== "ref&NN_ROIs")&&(nSlicesToStart==2)) {
		msg2 = "3. .zip files of ROIs in your NN channel."; 
	}
	if ((chooseROIset== "ref&NN_ROIs")&&(nSlicesToStart>2)) {
		msg2 = "3. .zip files of ROIs in your first NN channel.\n"+"4. .zip files of ROIs in your second NN channel." ;
	}

	Dialog.create("Select Folders");
	msg = "The message will be followed by prompts to select folders containing:\n"
	+"1. The images to be analyzed.\n"
	+"2. .zip files ROIs in your reference channel.\n"
	+msg2+"\n \n"
	+" NN ROI files should be in a separate folder from images, refs ROIs and each other\n \n"
	+" .zip files are matched to images by containing the image name.\n \n"
	+" Multiple .zip files can be anaylzed for each image";
	Dialog.addMessage(msg);	
	Dialog.show();
*/
	imgFolder = getDirectory("Choose a Directory");
	roisC1 = getDirectory("Choose a Directory");
	if (chooseROIset== "ref&NN_ROIs") {
		roisC2 = getDirectory("Choose a Directory");
	}
	if ((chooseROIset== "ref&NN_ROIs")&&(sliceQuerry2 != "0")) {
		roisC3 = getDirectory("Choose a Directory");
	}
}

//========================================================================================
// Determine unique string in Ref .zip files & NN .zip files that can be removed to allow matching of .zip files better
//========================================================================================

if (chooseROIset=="ref&NN_ROIs") {
	
	roiGuesses = guessROIString(imgFolder, roisC1,roisC3,roisC3);
	Dialog.create("Identify unique string in Ref & NN .zip file names");
	Dialog.addMessage("example image name... "+roiGuesses[0]);
	Dialog.addString("example Ref channel .zip ROI file name...",roiGuesses[1],lengthOf(roiGuesses[1]));
	Dialog.addString("example NN1 channel .zip ROI file name...",roiGuesses[2],lengthOf(roiGuesses[2]));
	if (sliceQuerry2 != "0") {
		Dialog.addString("example NN1 channel .zip ROI file name...",roiGuesses[3],lengthOf(roiGuesses[3]));
	}
	Dialog.show();
	refROIsUniqueString = Dialog.getString();
	NN1ROIsUniqueString = Dialog.getString();
	if (sliceQuerry2 != "0") {
		NN2ROIsUniqueString = Dialog.getString();
	}
}

//=====================================================================================================================
// MINER parameters are collected from the dialog box when run in pseudo batch mode (only one set of parameters used)
// Power users can run from script editor and can add extra values to the following arrays
dialogParameters = "[rfch]="+sliceRef+" [nnch1]="+sliceQuerry1+" [nnch2]="+sliceQuerry2+" [ch1clr]="+ch1Clr+" [ch2clr]="+ch2Clr+" [ch3clr]="+ch3Clr+
" [nnsortby]="+nnSortBy+" [refctrtype]="+refCtrType+" [roiwidth]="+roiLineWidth+" [padrefroi]="+refRoiPad+" [srchrad]="+maxNNdist+" [NNFWHMradius]="+NNFWHMradius+
" [mnfitlen]="+minFWHMLineLength+" [mxfitlen]="+maxFWHMLineLength+" [lnwd]="+lineWidth+" [radifnofit]="+radiusNNPuncta+" [fwhmlmt]="+NNlimitFWHM+" [nnns]="+numNNstats+" [mxdist]="+maxNNdist+
" [noiselmtref]="+noiselmtref+" [noiselmtnn]="+noiselmtnn+" [bgsubrad]=-1 [refroisfromfile] "+nnROIsFromFileParam+" [saveOutput] "+calOverlapString;

// Create a new flpParameters# variable for each different analysis that you want to run in batch		
//flpParameters2 = "[rfch]=1 [nnch1]=2 [nnch2]=[none-0] [ch1clr]=orange [ch2clr]=magenta [ch3clr]=white [nnsortby]=center [refctrtype]=fitted [roiwidth]=0 [padrefroi]=2 [srchrad]=20 [NNFWHMradius]=5 [mnfitlen]=7 [mxfitlen]=35 [lnwd]=2 [radifnofit]=5 [fwhmlmt]=15 [nnns]=1 [mxdist]=20 [noiselmtref]=2.0 [noiselmtnn]=2.0 [bgsubrad]=20 [gausspk]  [refroisfromfile] [saveOutput] [npsfx]=_findNNv6.1.0.7";
//flpParameters3 = "[rfch]=1 [nnch1]=2 [nnch2]=[none-0] [ch1clr]=orange [ch2clr]=magenta [ch3clr]=white [nnsortby]=center [refctrtype]=fitted [roiwidth]=0 [padrefroi]=2 [srchrad]=20 [NNFWHMradius]=5 [mnfitlen]=7 [mxfitlen]=35 [lnwd]=3 [radifnofit]=5 [fwhmlmt]=15 [nnns]=1 [mxdist]=20 [noiselmtref]=2.0 [noiselmtnn]=2.0 [bgsubrad]=20 [gausspk]  [refroisfromfile] [saveOutput] [npsfx]=_findNNv6.1.0.7";


//Description: This provides a usefull description to the output folder
//Use: if only one parameter string, use "" as second element of array. Otherwise load array with variables descrbing the parameters for each analysis
 // should  start with "_", will be appended to output folder


//Source Folders: 

	//imgFolder = "C:\\Users\\Damon\\sfuvault\\SFU\\Image_Temp_Holding\\testing_MinerV1_2dGauss";  //folder containing image to analyze
	//roisC1 = "C:\\Users\\Damon\\sfuvault\\SFU\\Image_Temp_Holding\\testing_MinerV1_2dGauss";   //where are reference ROIs for NN channel 1 stored
	//roisC2 = "";  //where NN ROIs for ch 1 are stored if being used
	//roisC3 = ""; //where NN ROIs for ch 2 are stored if being used

	flpParamArray = newArray(dialogParameters); //# of elements in this array define how many loops of analysis are performed. The remaining folder arrays and must have the same # of elements. 
	imgFileArray = newArray(imgFolder); ///additional folders can be specified here by pro-user - backslashes must be doubled
	refROIFileArray = newArray(roisC1); //additional folders can be specified here by pro-user - backslashes must be doubled
	nnROIFileCh1Array = newArray(roisC2); //additional folders can be specified here by pro-user - backslashes must be doubled
	nnROIFileCh2Array = newArray(roisC3); //additional folders can be specified here by pro-user - backslashes must be doubled
	suffixArray = newArray(txtSuffix); //additional folders can be specified here by pro-user - backslashes must be doubled

	t0 = getTime();

	if (isOpen("ROI Manager")==false) run("ROI Manager...");

	// ==============================================================================================================================================================
	// ==== Loop through list of various parameters to be analyzed and specified image / ROI folders
	// ==============================================================================================================================================================
	for (b=0; b<flpParamArray.length; b++) {

			if (refROIFileArray[b]!="") dir = imgFileArray[b];
			if (refROIFileArray[b]=="") {
				waitForUser("select directory containing images and refROI");
				dir = getDirectory("Choose a Directory ");
			}

			// get list of images and create required sorting and holding arrays
			mainList = getFileList(imgFileArray[b]);
			mainList = Array.sort(mainList);
			imgList0 = newArray(0); //temp list of images
			imgList = newArray(0); //Array will be expanded with Array.concat as needed
			refROIdir = refROIFileArray[b];
			roiSetList = newArray(0); //Array will be expanded with Array.concat as needed
			refList = getFileList(refROIFileArray[b]);
			refList = Array.sort(refList);
			nImgs = 0;
			nRoisSets = 0;
			nLaps = (flpParamArray.length * imgList.length);

			for ( i =0; i< mainList.length; i++) {
				if ( endsWith(mainList[i], imgType) == true) {
					imgList0 = Array.concat(imgList0,mainList[i]);
					nImgs++;
				}
			}
			imgList0 = Array.trim(imgList0,nImgs);

			//Parse the ref ROI folder for a list of .zip files, and create list of matched images and ROIs
			//To analyze multiple ROIs sets per image, start with ROI.zip list, find matching image, then build (concat) ROI/Image list from there. 
			nPairs = 0;
			for (j = 0; j< refList.length; j++) {
				if ( endsWith(refList[j], ".zip") == true) {
					for (i =0; i< imgList0.length; i++) {
						imgNameForROI = replace(imgList0[i],imgType,"");
						if( (indexOf(refList[j], imgNameForROI) )!=-1 )   {
							imgList = Array.concat(imgList, imgList0[i] );
							roiSetList = Array.concat(roiSetList, refList[j] );
							nPairs++;
						}
					}
				}
			}
			nImgs = nPairs;

			if (nImgs==0) {
				waitForUser("no images with match ROIs found for loop" + b);
			}
			
			userInput = flpParamArray[b];
			extraSuffix = suffixArray[b];
			flpSettings2 = userInput;  //make copy of flpSettings so that it doesn't get deleted by call to Split
	 		flpSettingsArray = split(flpSettings2," "); // split user settings to an array
		
			//code second flpParamArray[b] as "" to skip this lap if only one set of parameters to analyze.
			if (flpParamArray[b]!=""){
			
				if (nnROIsFromFile == true) {				//build list of ROI files if NN ROIs will be pulled from file
					
					if (nnROIFileCh1Array[0]=="") {  								// select folder containing ROIs for nnCh1 
						waitForUser("select directory containing first set of nnROIs");
						dir4nnCh1ROIs = getDirectory("Choose a Directory ");
					} else {														// OR specify in code the folder containing ROIs for nnCh1 
						dir4nnCh1ROIs = nnROIFileCh1Array[0];
					}
					nnCh1ROIList = getFileList(dir4nnCh1ROIs);
					nnCh1RoiSetList = newArray(imgList.length);
					Array.fill(nnCh1RoiSetList,0);
					nNNRoiSets = 0;

					//MINERv2.2: instead of matching NN ROIs (.zip) filess to image, will now match to the names of the ROI files for the ref channel
					//           that are already paired the images. 
					//  step 1. Collect names of NNch1 ROI files
					//  step 2. Compare "roiSetList" with "nnCh1ROIList"
					//	Uniqure ROI file name parts: refROIsUniqueString NN1ROIsUniqueString NN2ROIsUniqueString

					for ( l=0; l< imgList.length; l++) {							// set image list and ref ROI files list = "" if a matching nnCh1 ROI file not found
						foundMatch = 0;
						imgNameForROI = replace(imgList[l],imgType,"");  // imgList and roiSetList already matched.
						searchTerm = replace(roiSetList[l],imgNameForROI,""); // get name of first ROIset and remove match image name
						searchTerm = replace(searchTerm,refROIsUniqueString,""); // further remove unique part of ref ROI file names
						searchTerm = replace(searchTerm,"__","_"); // further remove unique part of ref ROI file names
						isZip = false;
						imgMatch = false;
						roiMatch = false;


						for (m = 0; m<nnCh1ROIList.length; m++) {
							if(endsWith(nnCh1ROIList[m],".zip")==true) isZip = true;
							if(indexOf(nnCh1ROIList[m], imgNameForROI ) !=-1 ) imgMatch = true;
							if(indexOf(nnCh1ROIList[m], searchTerm ) !=-1 ) roiMatch = true;
							if( (endsWith(nnCh1ROIList[m],".zip")==true) && (indexOf(nnCh1ROIList[m], imgNameForROI ) !=-1 ) && (indexOf(nnCh1ROIList[m], searchTerm ) !=-1 )) {
								nnCh1RoiSetList[l] = nnCh1ROIList[m];
								foundMatch=1;
							}
							if (foundMatch==0) {
								useDummyROI = true;
							}
						}

					}

					nnCh2RoiSetList = newArray(imgList.length);
					Array.fill(nnCh2RoiSetList,0);
					
					// find list of ROIs for nnCh2
					if (sliceQuerry2 != "0") {
						// select folder containing ROIs for nnCh1 
						dir4nnCh2ROIs = nnROIFileCh2Array[0];
						nnCh2ROIList = getFileList(dir4nnCh2ROIs);
						nnCh2ROIList = Array.sort(nnCh2ROIList);
						nnCh2RoiSetList = newArray(imgList.length);
						Array.fill(nnCh2RoiSetList,0);
						nNNRoiSets = 0;
		
						// set image list and ref ROI files list = "" if a matching nnCh1 ROI file not found
						for ( l=0; l< imgList.length; l++) {
							foundMatch = 0;
							imgNameForROI = replace(imgList[l],imgType,"");  // imgList and roiSetList already matched.
							searchTerm = replace(roiSetList[l],imgNameForROI,""); // get name of first ROIset and remove match image name
							searchTerm = replace(searchTerm,refROIsUniqueString,""); // further remove unique part of ref ROI file names
							searchTerm = replace(searchTerm,"__","_"); // further remove unique part of ref ROI file names
							for (m = 0; m<nnCh2ROIList.length; m++) {
								if (imgList[l]!="") {						
									if( endsWith(nnCh2ROIList[m],".zip") && (indexOf(nnCh2ROIList[m], imgNameForROI ) !=-1 ) && (indexOf(nnCh2ROIList[m], searchTerm ) !=-1 )) {
										nnCh2RoiSetList[l] = nnCh2ROIList[m];
										foundMatch=1;
									}
								}
							}
							if (foundMatch==0) {
								useDummyROI = true;
							}
						}
					}
					
				} else {	//this is the "if get rois from file" IF statement 
					dir4nnCh1ROIs = refROIdir;
					dir4nnCh2ROIs = refROIdir;
					nnCh1RoiSetList = roiSetList;
					nnCh2RoiSetList = roiSetList;
				}

				//Array.show("round "+b,roiSetList, nnCh1RoiSetList,nnCh2RoiSetList );

				//MINER_v2.2
				if (useDummyROI == true){
					roiManager("reset");
					newImage("Untitled", "8-bit white", 32, 32, 1);
					makeRectangle(0,0,1,1);
					roiManager("Add");
					roiManager("select",0);
					roiManager("rename", "dummy1");
					makeRectangle(1,1,1,1);
					roiManager("Add");
					roiManager("select",0);
					roiManager("rename", "dummy2");
					roiManager("Deselect");
					dummyDir = getDirectory("imagej");
					dummyPath = dummyDir + File.separator + "minerDummy.zip";
					roiManager("save",dummyPath);
					roiManager("reset");
					close;
				}

				roiSArrayName = "matched images and ROIs";
				Array.show(roiSArrayName, imgList, roiSetList, nnCh1RoiSetList,nnCh2RoiSetList);
		 		
				if (dir == "") dir = getDirectory("home");  //save images to "home" directory if no other directory selected

				// TIME STAMP
				getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
				timeStamp = ""+ year +""+IJ.pad(month+1,2)+""+ IJ.pad(dayOfMonth,2)+"-"+IJ.pad(hour,2)+""+IJ.pad(minute,2);
				if (doTimeStamp==false) timeStamp = "";

			    // SET OUTPUT DIRECTORY
				outputDir = "MINER_"+version+ "_" + timeStamp+extraSuffix; 
				outputPathDir = dir + File.separator + outputDir;
				outputPath = dir + File.separator + outputDir + File.separator; 
				if (File.exists(outputPathDir)==false) {
					File.makeDirectory(outputPathDir);
				}
				selectWindow(roiSArrayName);
				saveAs("Results", outputPath  + "0roiSets_MINER_" +version+"_" + timeStamp + ".csv");
				selectWindow("0roiSets_MINER_" +version+"_" + timeStamp + ".csv");
				run("Close");
				
				if (verbose==true) print("\\Update8: outputpath - " + outputPath);
				t1 = getTime();
		
		 		refChannel =  substring(flpSettingsArray[0], indexOf(flpSettingsArray[0],"=")+1,lengthOf(flpSettingsArray[0])); 		
		 		nnChannel1 =  substring(flpSettingsArray[1], indexOf(flpSettingsArray[1],"=")+1,lengthOf(flpSettingsArray[1])); 		
		 		nnChannel2 =  substring(flpSettingsArray[2], indexOf(flpSettingsArray[2],"=")+1,lengthOf(flpSettingsArray[2])); 		



		 		// Loop through images in main folder
		 		for (a=0; a<nImgs; a++) {
if (doBatch == true) setBatchMode(true); //MINER v2.3c		 		
			 		//for (a=0; a<nPairs; a++) {  //MINER_v1.2
					if (nnChannel2=="0"){
						nn2Text = "";
					} else {
						nn2Text = "_nn2-C"+nnChannel2;
					}
		
					//resultsFileName = "Results_" + replace(imgList[a],imgType,"") + "_C" + refChannel + "_nn1Ch_C" + nnChannel1 + "_nn1Ch_C" + nnChannel2 + "_" + version + extraSuffix +  ".txt";
					resultsFileName = "Results_" + replace(roiSetList[a],".zip","") + "_C" + refChannel + "_nn1-C" + nnChannel1 + nn2Text + "_" + version + extraSuffix +  ".txt";
					
					
					path = outputPath + resultsFileName;
					if  ((verbose==true) && (File.exists(path)==true)) print("\\Update6: img exists" +  imgList[a]);
		
					if ( (File.exists(path)==false) && (imgList[a]!="") || ( (File.exists(path)==true) && (overWrite==true))) {
						
							timeA = getTime;
							if  ((verbose==true) && (File.exists(path)==true)) print("\\Update6: img overwrite " +  imgList[a]);
							if  ((verbose==true) && (File.exists(path)==false)) print("\\Update6: img de novo " +  imgList[a]);
		
							//open current image to be analyzed
							print("\\Update2: opening img: " + imgList[a]);
							open(dir + File.separator() + imgList[a]);	
							img0 = getTitle();
					
							//open current reference ROIs to be analyzed
							if (roiManager ("count") >0)  roiManager ("reset");
							if (verbose==true)  print("\\Update7: ROIs        " + roiSetList[a]);
	
							refROIFile = refROIFileArray[0] + File.separator() + roiSetList[a];
							if (verbose==true)  print("\\Update10: opening Ref ROIs: " + refROIFile);
							roiManager("Open",refROIFile);
							
							nnROIsA =  dir4nnCh1ROIs + File.separator() +  nnCh1RoiSetList[a];
							
							if(nnCh1RoiSetList[a]==0) nnROIsA = dummyPath;
							nnROIsB = nnROIsA;
							if( indexOf(flpSettingsArray[2],"[nnch2]=0")==-1) {
								nnROIsB = dir4nnCh2ROIs + File.separator() +  nnCh2RoiSetList[a];
								if(nnCh2RoiSetList[a]==0) nnROIsB = dummyPath;
							}

							// === CALL TO findLocalPuncta FUNCTION =================================================================================================
							// =======================================================================================================================================
							findLocalPuncta(img0, userInput, refROIFile, nnROIsA, nnROIsB, doBatch);
							// =======================================================================================================================================
							// =======================================================================================================================================							
				
							img2 = getTitle();
							//setMetaData		
							metaData = getMetadata("Info") + "\n findLocalPunta "+ version+" Parameters:";
							for (d = 0; d<flpSettingsArray.length; d++) {
								 metaData =  metaData + "\n" + flpSettingsArray[d];
							}
							setMetadata("Info", metaData);
							//saveAs("Tiff", outputPath + img2);
							imgOut = replace(roiSetList[a],".zip","") + "_C" + refChannel  + "_nn1-C" + nnChannel1 + nn2Text;
							saveAs("Tiff", outputPath + imgOut);
							close(imgOut);
							//path = outputPath + "Results_" + replace(img0,imgType,"") + "_C" + "1" + "_analyzedBy_C" + "2" + "_" + version + "_" + extraSuffix +  ".txt";
							saveAs("Results", path);
							if (isOpen(img0)) {
								selectWindow(img0);
								close();
							}
			
					} else {    // close overwrite If		
						print ("\\Update4: no overwrite on img " + a);
					}
							close("*");
							lapTime = (getTime() - t1)/1000;
							t1 = getTime();
							tLeft = (  (  (t1-t0) / (a+1) ) * ( (nImgs-a) + ( (flpParamArray.length-1) - b)  ) )  / 1000 ;
							//selectWindow(pBar);
		
							progress = ( a + 1)/nImgs ;
							nParameterLaps = flpParamArray.length;
							batchProgress = ( b+1)/(nParameterLaps) ;
					
							pctDoneLength = 40;
							pctDone = progress*pctDoneLength;
							pctDoneBatch = batchProgress*pctDoneLength;
							pctDoneString = "";
							pctLeftString = "";
							pctDoneStringBatch = "";
							pctLeftStringBatch = "";
							
							for(bb = 0; bb<pctDoneLength;bb++) {
								pctDoneString = pctDoneString + "|";
								pctLeftString = pctLeftString + ".";
								pctDoneStringBatch = pctDoneStringBatch + "|";
								pctLeftStringBatch = pctLeftStringBatch + ".";
					
							}
							pctDoneString = substring(pctDoneString ,0,pctDone);
							pctLeftString = substring(pctLeftString ,0,pctDoneLength - pctDone);
							pctDoneStringBatch = substring(pctDoneStringBatch ,0,pctDoneBatch);
							pctLeftStringBatch = substring(pctLeftStringBatch ,0,pctDoneLength - pctDoneBatch);
							
							print ("\\Update4: curr Img: " + pctDoneString + pctLeftString + " " +  (a+1) + " of " + nImgs + " loop time: " + d2s(lapTime/60,3) + " min per image "+ d2s( (nImgs-a)*lapTime/60,3) + " min for remaining images");
							print ("\\Update5: param set: " + pctDoneStringBatch + pctLeftStringBatch + " " +  (b+1) + " of " + nParameterLaps + ". Estimating " +d2s(tLeft/60,2)+ " min to completion.");
				} // close "a" loop
					
				
			
			//this is the place to save anlysis parameters to output folder in a table format (.csv). 
				// SAVE PARAMETERS TO A csv FILE
				run("Clear Results");
				for (p=0;p<flpSettingsArray.length;p++) {
					if (indexOf(flpSettingsArray[p],"=")!=-1){
						setResult("Parameter", nResults,""+substring(flpSettingsArray[p], 1,indexOf(flpSettingsArray[p],"=")-1)); 
						setResult("Values", nResults-1,""+substring(flpSettingsArray[p], indexOf(flpSettingsArray[p],"=")+1,lengthOf(flpSettingsArray[p]))); 
					} else {
						setResult("Parameter", nResults,""+flpSettingsArray[p]);
						setResult("Values", nResults-1,"");
					}
				}
				updateResults();
				saveAs("Results", outputPath  + "0parameters_MINER_v" +version+"_" + timeStamp + ".csv");
				//run("Clear Results");

				while(isOpen("sliceQuerry2_refOverlap")) {
					close("sliceQuerry2_refOverlap");
				}

			
			} // close if b == ""
	} // close b loop
	if (doBatch == true) setBatchMode("exit and display");
	print("\\Update0: analysis" + (b) +" complete." );



//===============FUNCTIONS ==================================================================================================================
//===========================================================================================================================================



function findLocalPuncta(img0, flpSettings, refROIFile, nnROIFileCh1, nnROIFileCh2, doBatch) {
		
			doBatch = doBatch;
			//requires("1.44j"); //But it will run much faster if you us ImageJ 1.45n or later due to roiManager improvements

			//===== Section 1.0 Get & Set prefs for slices to be anaylzed =============================================================================
			//----------------------------------------------------set ------------------------------------------------------------------------------------------------------------------------------------------
			selectWindow(img0);
			
			nSlicesToStart = nSlices();
	
			//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
			flpSettingsArray = split(flpSettings," ");


			//set Boolean variable to false by default
			calcOverlap = false;
			gaussPeakReported = false;
			refROIsFromFile = false;
			//nnROIsFromFile = false;
			autoSaved = false;
			saveToParentDir = false;
			appendParameters = false;

			// === parse settings to transfer FLP parameters to macro. ======================================================================================================================================

			for (k=0; k<flpSettingsArray.length; k++) {
				if (indexOf(flpSettingsArray[k],"[rfch]")!=-1) {
						sliceRefString = substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k]));
						sliceRef = parseInt(sliceRefString);			
				}
				if (indexOf(flpSettingsArray[k],"[nnch1]")!=-1) 			sliceQuerry1 = substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])); 
				if (indexOf(flpSettingsArray[k],"[nnch2]")!=-1) 			sliceQuerry2 = substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])); 						
				if (indexOf(flpSettingsArray[k],"[ch1clr]")!=-1) 			ch1Clr = substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])); 			
				if (indexOf(flpSettingsArray[k],"[ch2clr]")!=-1) 			ch2Clr = substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k]));
				if (indexOf(flpSettingsArray[k],"[ch3clr]")!=-1) 			ch3Clr = substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k]));
				if (indexOf(flpSettingsArray[k],"[nnsortby]")!=-1) 			nnSortBy = substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k]));
				if (indexOf(flpSettingsArray[k],"[refctrtype]")!=-1) 		refCtrType = substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k]));
				if (indexOf(flpSettingsArray[k],"[roiwidth]")!=-1) 			roiLineWidth = parseFloat(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[padrefroi]")!=-1) 		refRoiPad = parseInt(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				//Miner v2.0  if (indexOf(flpSettingsArray[k],"[srchrad]")!=-1) radius = parseFloat(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[NNFWHMradius]")!=-1) 		NNFWHMradius = parseInt(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[mnfitlen]")!=-1) 			minFWHMLineLength = parseInt(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[mxfitlen]")!=-1) 			maxFWHMLineLength = parseInt(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[lnwd]")!=-1) 				lineWidth = parseInt(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[radifnofit]")!=-1) 		radiusNNPuncta = parseFloat(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[fwhmlmt]")!=-1) 			NNlimitFWHM = parseFloat(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[nnns]")!=-1) 				numNNstats = parseInt(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[mxdist]")!=-1) 			maxNNdist = parseInt(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));			
				if (indexOf(flpSettingsArray[k],"[noiselmtref]")!=-1) 		noiseLimitRef = parseFloat(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[noiselmtnn]")!=-1)  		noiseLimitNN = parseFloat(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));
				if (indexOf(flpSettingsArray[k],"[bgsubrad]")!=-1) 			bkGdSubtrRad = parseInt(substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"=")+1,lengthOf(flpSettingsArray[k])));			
				if (flpSettingsArray[k]=="[calcoverlap]") 					calcOverlap = true;
				if (flpSettingsArray[k]=="[gausspk]") 						gaussPeakReported = true;
				if (flpSettingsArray[k]=="[refroisfromfile]") 				refROIsFromFile = true;
				//if (flpSettingsArray[k]=="[nnroisfromfile]") 				nnROIsFromFile = true;
				if (flpSettingsArray[k]=="[saveOutput]") 					autoSaved = true;
				//if (flpSettingsArray[k]=="[npsvtoprnt]") saveToParentDir = true;
				if (indexOf(flpSettingsArray[k],"[npsfx]")!=-1) savetxtSuffix = substring(flpSettingsArray[k], indexOf(flpSettingsArray[k],"="),lengthOf(flpSettingsArray[k])-1);			
			}

			maxPad = maxFWHMLineLength - minFWHMLineLength;
			//if (maxNNdist > radius) maxNNdist = radius; //Miner v2.0
			appendParameters = false;
			txtSuffix = "_findNN"+version;
		
			// ==== FWHM variables ======================================================
			var	oneMinusR2Max = 0.3;	var	oneMinusR2Wt = 70;
			var	FWHMdeltaMax = 5;		var	FWHMdeltaWt = 15;
			var	centerOffsetMax = 2.5; 	var	centerOffsetWt = 15;
			var	negBaselinePenalty = 1;
			var	negPeakPenalty = 5;
			var	minSubArrayWidth = minFWHMLineLength;
			var maxPad = maxFWHMLineLength - minFWHMLineLength;
		
			// added v4.7.1 140212
			if (bitDepth() == 8) run("16-bit"); //convert current image to 16-bit to keep Adrian's FWHM from crashing IJ
			foregroundColor = getValue("color.foreground");
			backgroundColor = getValue("color.background");
			makeLine(0, 0, 10, 10);
			origianlSelectionColor = getInfo("selection.color");
			run("Select None");
			run("Set Measurements...", "  mean redirect=None decimal=3");
			run("Colors...", "foreground=white background=black selection=cyan");   // prevents crash if foreground and background colours not right
		
			parametersString = "_refPd-"+refRoiPad+"_rd-"+maxNNdist+"_HMrad-"+NNFWHMradius+"_mnLnLen-"+minFWHMLineLength+"_mxLnLen-"+maxFWHMLineLength
						+"_lnW-"+lineWidth+"_NNrad-"+radiusNNPuncta+"_FWHMlimit-"+NNlimitFWHM+"_nNNs-"+numNNstats+"_mxD-"+maxNNdist+"_RefnsLmt-"+noiseLimitRef+"_NNnsLmt-"+noiseLimitNN+ "_gsPk-"+gaussPeakReported;
		
			if (appendParameters == true) txtSuffix = txtSuffix + parametersString;
		
		//==========================================================================================================================
		
			if (isOpen("ROI Manager")==false) run("ROI Manager...");
			//if (doBatch == true) setBatchMode(true);
		
			dir = getDirectory("image");	
				if (dir == "") dir = getDirectory("home");
			if (refROIsFromFile == true) {
				if (isOpen("ROI Manager")==true) {
					roiManager("reset");
				}  else {
					run("ROI Manager...");
				}
				if (refROIFile=="") {
					waitForUser("Select Reference ROIs");
					roiManager("Open", "");
					roiManager("Save",getDirectory("home")+"tempRoiSet.zip");
					roiManager("reset");
				} else {
					// NOTE: 170130 - this is currently redundant and doubles a call from outside the macro to open a refROI file. 
					// will probably slow down processing a bit.
					roiManager("reset");
					roiManager("Open", refROIFile);
					roiManager("Save",getDirectory("home")+"tempRoiSet.zip");
					roiManager("reset");
				}
				
			} else {
				if (isOpen("ROI Manager")==true) {
					if (roiManager("count") >= 0) roiManager("Save",getDirectory("home")+"tempRoiSet.zip");
					selectWindow("ROI Manager");
					run("Close");
				}
			}
			roiManager("Open",getDirectory("home")+"tempRoiSet.zip");
			
			if (nResults>0) IJ.deleteRows(0, nResults-1);
		
			start = getTime;

			//-----Section 1.1 Determine which slices to analyze & prep storage bins for results -------------------------------------------
			//---------------------------------------------------------------------------------------------------------------------------------------------------
			if (sliceQuerry2 == "0") nSlicesToAnalyze = 1;  //MINER v2.3 - simplified to allow analyses of stacks with >3 channels 
			if (sliceQuerry2 != "0") nSlicesToAnalyze = 2;  //MINER v2.3 - simplified to allow analyses of stacks with >3 channels 
			slicesToAnalyze = newArray(nSlicesToAnalyze);
			slicesToAnalyze[0] = parseInt(sliceQuerry1);    // v4.2 - removed old references to specific colors in channels
			if (sliceQuerry2 != "0") slicesToAnalyze[1] = parseInt(sliceQuerry2); // v4.2 - removed old references to specific colors in channels
			
			img0 = getTitle();
			img0base = substring(img0,0,lastIndexOf(img0,"."));
			imgH = getHeight();
			imgW = getWidth();
			run("Select None");	
			setSlice(sliceRef);    
			selectWindow(img0);
			img1 = img0+ "_copy";
			run("Duplicate...", "title=["+img1+"] duplicate");
		 	if (bkGdSubtrRad!=-1)	run("Subtract Background...", "rolling="+bkGdSubtrRad+"");                 
		
			nnrOutlines = img0+"_nnrOutlines_"+version; 				// v4.7.1:  add an image with outlines of NNRs
			if (appendParameters == true) nnrOutlines = img0+"_nnrOutlines_"+version + parametersString;
			selectWindow(img1);
//MINER v2.3: for multichannel images (>4 channels) maybe need to split channels and rebuilt 2 colour image for analysis to make things easier. 
//   - or easier - just duplicate the whole stack and reference native channel numbers. 
			//if (nSlicesToStart == 2)     run("Duplicate...", "title="+nnrOutlines+" duplicate channels=1-2");
			//if (nSlicesToStart == 3)	run("Duplicate...", "title="+nnrOutlines+" duplicate channels=1-3");  // added v4.8.1.3
			run("Duplicate...", "title="+nnrOutlines+" duplicate"); 

			selectWindow(img1);
			img2 = img0 + "_C"+slicesToAnalyze[0];
			run("Duplicate...", "title="+img2+" duplicate channels="+slicesToAnalyze[0]);
			if (sliceQuerry2 != "0") {
				selectWindow(img1);
				img3 = img0 + "_C"+slicesToAnalyze[1];
				run("Duplicate...", "title="+img3+" duplicate channels="+slicesToAnalyze[1]);
			}
			selectWindow(img1);
		
		
			//-----Section 1.2 the array below defines the heading of the output data.  -------------------------------------------
			//---------------------------------------------------------------------------------------------------------------------------------------------------
		
			/*
				ROI:  ROI number from ROI manager
				new ROI: 1 = row is first NN of curr ROI, 0 = row is NOT first NN of curr ROI
				proximity: -1 = no NN ROI found for this reference puncta, 0 = first NN, 1 = 2nd NN....
							note that NN proximity can be sorted by distance or intensity of NN peak
				channel:    channel in which NN are being searched for
				centroid X / centroid Y: centroid of reference ROI
				localMax X / localMax Y: brightest pixel within reference ROI
				ref major FWHM / ref minor FWHM: full-width half-max estimates of reference ROI
				ref X Center / ref Y Center: centre of ref ROI calculated by 2 x 1D FWHM gaussian fits
				dist to peak: distance between brightest pixesl in ref ROI and NN
				angle:   direction to NN
				X Geo / Y Geo:  
				major FWHM / minor FWHM: full-width half-max estimates of NN ROI
						x.nnnn = failure to fit, beyond max allowed value  
				X Center / Center:  centre of ref ROI calculated by 2 x 1D FWHM gaussian fits
				dist bw Centers:  distance between fitted centres of ref ROI and NN
				NN / ref Mean :    mean intensity of NN or ref ROI
				NN / ref fitted height:  average (major & minor axes) height - baseline of gaussian fit of puncta profile
				NNr2:   R squared goodness of gaussian fit of profiles through NN puncta
				bestCenter2LocalMax: 
				dFromRefPerimeter: <0 or >0 = NN peak is x pixels inside or outside of the boarder of the ref ROI   
				nnAngle:
				fracOverlapNN: fraction of NN ROI that overlaps with ref ROI. Based on initial NN ROIs, which are currently point selections (6.0.0.0, 161002)
				nnRoiIndex: Index in initial list of nnROIs
				qMeanDFromAnyP:
				refArea: area of original ref ROI
			*/
	
			resultsLabels = newArray("ROI","new ROI","proximity","channel","centroid X (ref: " + refCtrType + ")","centroid Y(ref: " + refCtrType + ")","localMax X","localMax Y","ref major FWHM","ref minor FWHM",
		            "ref X Center","ref Y Center","dist bw geo ctrs","dist bw COMs","dist b fitted ctrs","dFromRefPerimeter","angle","nn X Geo","nn Y Geo","nn majorFWHM","nn minorFWHM","nnX Center","nnY Center",
					"ref Mean","NN Mean","ref fitted height","NN fitted height","NNr2","dist localMax2fitdCtr","refArea","nnArea","nnAngle","fracOverlapRef","fracOverlapNN","nnRoiIndex","qMeanDFromAnyP");


			nResultsCols = resultsLabels.length;
			resultsCounter = 0;
		
			//Section 2.0 Walk through ROI list to find centers of puncta & copy ref image ROI parameters to arrays, assign to arrays in base 0, with getResults should also be base 0 =========================================================================================
			//========================================================================================================================================
			//========================================================================================================================================
		
			nROIs = roiManager("count");
			bigResultsArray = newArray(nROIs*numNNstats*nResultsCols*nSlicesToAnalyze);
			totalTime = 0;
		
			//Section 2.1 Get ROI metrics  =========================================================================================
			//============= 130712: updating to analyze FWHM along major and minor axes of fitted ellipse ====================================
			//============== make a binary image of the ROIs in order to get ellipse fit parameters and redirect grayscale metrics to img0
				// moved from being after distance map generation 610205
			xCntrGeo = newArray(nROIs+1); // X geometric center 
			yCntrGeo = newArray(nROIs+1); // Y geometric center 
			xRefCOM = newArray(nROIs+1); // reference X center of mas (xm)
			yRefCOM = newArray(nROIs+1); // reference Y center of mas (xm)
			refROImajorAxis = newArray(nROIs+1); // major axis of fitted elipse
			refROIminorAxis = newArray(nROIs+1); // minor axis of fitted elipse
			refROIAngle = newArray(nROIs+1); // reference Y center of mas (xm)
			refROIMean = newArray(nROIs+1); // reference Y center of mas (xm)   // redirected from binary img to img1
			refROIArea = newArray(nROIs+1); // reference Y center of mas (xm)   // redirected from binary img to img1
			
			run("Set Measurements...", "area mean min centroid center fit shape redirect="+img1);
			
			binaryROIs = "binaryROIs";
			selectWindow(img1);
			setSlice(sliceRef); 
			newImage(binaryROIs, "8-bit Black", imgW, imgH, 1);	
			selections = newArray(nROIs);
			for (b=0; b<nROIs; b++) {
			
				//copy ref ROI metrics to holding arrays		
				roiManager("select", b); // 
				roiManager("measure");
				xCntrGeo[ b ] = getResult( "X" , nResults-1 );
				yCntrGeo[ b ] = getResult("Y", nResults-1 );
				xRefCOM[ b ] = getResult( "XM", nResults-1 );
				yRefCOM[ b ] = getResult( "YM", nResults-1 );
				refROImajorAxis[ b ] = getResult( "Major", nResults-1 );
				refROIminorAxis[ b ] = getResult( "Minor", nResults-1 );
				refROIAngle[ b ] = getResult( "Angle", nResults-1 );
				refROIMean[ b ] = getResult( "Mean", nResults-1 );
				refROIArea[ b ] = getResult( "Area", nResults-1 );
				//generate a multi-ROI array listing ROI indices
				selections[b]=b;
			}
			pad = 2;
			
			// select all ROIs to be converted into a binary image
			roiManager("select", selections);
			roiManager("Fill");	
			run("Invert LUT");
			run("Set Measurements...", "area mean min centroid center fit shape redirect=None decimal=3"); 		// remove redirect

			if (saveSampleImages==true) {
				sampleImageDirectory = dir + File.separator + "sampleImages";
				if (File.isDirectory(sampleImageDirectory)==false) File.makeDirectory(sampleImageDirectory);
				sampleImgPath = sampleImageDirectory + File.separator + img1 + "_binRefROIs";
				save(sampleImgPath + imgType);
				rename(binaryROIs);
			}
		
			//Section 2.1.0 Generate Distance Map from perimeter of ref ROI ==========================================================================
			// ===== added 140613 v5.0.0.0 =================================================================================================
		
			//Generate a mask of all ROIs
			imgRefMask = "refMask";
			selectWindow(binaryROIs);
			run("Invert LUT");
			rename(imgRefMask);
			imgRefPerimeterIn = "imgPin"; 
			imgRefPerimeterOut = "imgPout"; 
			imgRefDfromPerimeter ="imgDfromP";
		
			run("Select None");
			selectWindow(imgRefMask);
			roiManager("Deselect");
			setAutoThreshold("Default dark");
			resetThreshold();
			run("Duplicate...", "title="+imgRefPerimeterIn);
			setOption("BlackBackground", false);
			run("Convert to Mask");
			run("Distance Map");
			selectWindow(imgRefMask);
			run("Duplicate...", "title="+imgRefPerimeterOut);
			setAutoThreshold("Default");
			run("Convert to Mask");
			run("Distance Map");
			imageCalculator("Subtract create 32-bit", imgRefPerimeterOut,imgRefPerimeterIn);
			selectWindow("Result of "+imgRefPerimeterOut);
			rename(imgRefDfromPerimeter);
			run("Enhance Contrast", "saturated=0.35");
			run("Fire");
			selectWindow(imgRefPerimeterIn);  
			close(); 
			selectWindow(imgRefPerimeterOut); 
			close();

			if (saveSampleImages==true) {
				selectWindow(imgRefDfromPerimeter);
				sampleImageDirectory = dir + File.separator + "sampleImages";
				if (File.isDirectory(sampleImageDirectory)==false) File.makeDirectory(sampleImageDirectory);
				sampleImgPath = sampleImageDirectory + File.separator + img1 + "_imgDfromP";
				save(sampleImgPath + imgType);
				rename(imgRefDfromPerimeter);
			}
		
			//Generate image with ROI pixel values = ROIindex+1
			imgRefNumberedROIs = "numberedRefROIs";
			newImage(imgRefNumberedROIs, "16-bit black", imgW, imgH, 1);
			for (b=0; b<nROIs; b++) {
				roiManager("select", b); // 
				changeValues(0, 1, b+1);
			}
			//added in v6.0.0.9c. Convert numbered ROIs to NAN mask, such that when measured, background is not counted. 
			// Then if a NN ROI straddles >1 ref ROI, its Min and Max values will be different
			//v6.0.1.3 - seems to be giving wierd numbers - tunn off for the time being. Get unusually high values for Promximt < 0 being higher abs value than # of ROIs

			if (saveSampleImages==true) {
				sampleImageDirectory = dir + File.separator + "sampleImages";
				if (File.isDirectory(sampleImageDirectory)==false) File.makeDirectory(sampleImageDirectory);
				sampleImgPath = sampleImageDirectory + File.separator + img1 + "_imgRefNumberedROIs";
				save(sampleImgPath + imgType);
				rename(imgRefNumberedROIs);
			}
		
			// Section 2.1.1 new - get NN channel ROIs from local maxima or file of ROIs
			// ===== added 161001 v6.0.0.0 =================================================================================================

			// get nnCH1 ROIs from file passed to this macro, or from prompt to select a file		
			if (nnROIsFromFile==true) {	
					roiManager("reset");
					if (nnROIFileCh1=="") {
						waitForUser("Select NN channel 1 ROIs");
						roiManager("Open", "");
					} else {
						roiManager("Open", nnROIFileCh1);
						if (verbose==true) print("\\Update11: opening NN ch1 ROIs: " + nnROIFileCh1 +", "+ roiManager("count") + " rois.");
						nnROIs1FileTree = split(nnROIFileCh1,"\\");
						nnROIs1FileName = nnROIs1FileTree[nnROIs1FileTree.length-1];
						querryROIsFile1 = nnROIFileCh1;
					}
			// otherwiser use find local maxima	
			} else {
				roiManager("reset");
				// generate ROIs for first querry channel	
				selectWindow(img2);
				getStatistics(area, mean, min, max, std);
				run("Find Maxima...", "noise="+(mean+noiseLimitNN*std)+" output=[Single Points] exclude");  //v6.0.0.2
				
				img2Maxima = img2 +" Maxima";
				selectWindow(img2Maxima);
				//roiManager("Deselect");
			    roiManager("reset");
				run("Analyze Particles...", "exclude add");
				selectWindow(img2Maxima);
				close();

				//check if a folder exists in image directory to hold nnROIs_refX_querryY
				nnROIs1FileName = img0base+"_ch"+sliceQuerry1+"ROIs.zip";
				nnRoiDirectory1 = "nnROIs_ref"+sliceRef+"_querry"+sliceQuerry1;
				nnRoiDirectoryPath1 = dir + File.separator + nnRoiDirectory1;
				if (File.isDirectory(nnRoiDirectoryPath1)==false) File.makeDirectory(nnRoiDirectoryPath1);
				querryROIsFile1 = nnRoiDirectoryPath1 + File.separator +nnROIs1FileName;
				roiManager("save",querryROIsFile1);
				if (verbose==true) print("\\Update12: nnRoiDirectoryPath1: " + nnRoiDirectoryPath1);
			} // close if(nnROIsFromFile==false	)
				
			nROIsQuerry1 = roiManager("count");
			if (verbose==true) print("\\Update16:"+nROIsQuerry1+ " potential nearest neighbours in channel 1");

			run("Clear Results");
			selectWindow(imgRefDfromPerimeter);
			roiManager("measure");
			querry1Area = newArray(nResults);
			querry1Mean = newArray(nResults);
			querry1Distances = newArray(nResults);
			querry1X = newArray(nResults);
			querry1Y = newArray(nResults);
			querry1XM = newArray(nResults);
			querry1YM = newArray(nResults);
			querry1Major = newArray(nResults);
			querry1Minor = newArray(nResults);
			for (t = 0; t<nResults(); t++) {
				querry1Area[t] = getResult("Area",t);
				querry1Mean[t] = getResult("Mean",t);
				querry1Distances[t] = getPixel(getResult("X",t),getResult("Y",t));
				querry1X[t] = getResult("X",t);
				querry1Y[t] = getResult("Y",t);
				querry1XM[t] = getResult("XM",t);
				querry1YM[t] = getResult("YM",t);
				querry1Major[t] = getResult("Major",t);
				querry1Minor[t] = getResult("Minor",t);			
			}
			querry1DistanceTable = "sliceQuerry1_distances"; 
			IJ.renameResults(querry1DistanceTable);
			selectWindow(querry1DistanceTable);
			run("Close");

			//Measure which Ref ROI each NN ROI is overlapping with.
			// As of v6.0.0.9C, this does not handle cases in which NN ROIs overlaps with >1 Ref ROI. Will need to restrict measurement of stored NN ROIs to x&y geometric centre
			selectWindow(imgRefNumberedROIs);
			//roiManager("measure");
			run("Clear Results"); //make sure that we are not drawing from previous table
			roiManager("measure");
			querry1vsRefROINumber = "querry1ROIsOverlapWithRef"; 
			querry1IsInRefRois = newArray(nResults);
			for (t = 0; t<nResults(); t++) {
				//measure ref ROI ID index at geometric center of NN ROI
					//querry1IsInRefRois[t] = getPixel(querry1X[t],querry1Y[t]);  // v6.0.0.9c - changed to measuring 
					querry1IsInRefRois[t] = getResult("Mean",t);   // removed v6.0.0.9c //restored v6.0.1.3 after seeing name ROIs with no NN
			}
			IJ.renameResults(querry1vsRefROINumber);
			selectWindow(querry1vsRefROINumber);
			run("Close");
	
	
			// Section 2.1.2: generate ROIs for second querry channel		
			
			if (sliceQuerry2 != "0") {
				// get nnCH1 ROIs from file passed to this macro, or from prompt to select a file		
				if (nnROIsFromFile==true ) {		
					roiManager("reset");
					if (nnROIFileCh2=="") {
						waitForUser("Select NN channel 2 ROIs");
						roiManager("Open", "");
					} else {
						roiManager("Open", nnROIFileCh2);
						if (verbose==true) print("\\Update11: opening NN ch2 ROIs: " + nnROIFileCh2 + ", "+ roiManager("count") + " rois.");
						nnROIs2FileTree = split(nnROIFileCh2,"\\");
						nnROIs2FileName = nnROIs2FileTree[nnROIs2FileTree.length-1];
						querryROIsFile2 = nnROIFileCh2;
					}
			
				} else {
					// otherwiser use find local maxima	
					selectWindow(img3);
					getStatistics(area, mean, min, max, std);
					run("Find Maxima...", "noise="+(mean+noiseLimitNN*std)+" output=[Single Points] exclude");  //v6.0.0.2
					img3Maxima = img3 +" Maxima";
					selectWindow(img3Maxima);
					roiManager("Deselect");
				    roiManager("Delete");
					run("Analyze Particles...", "exclude add");
					close(img3Maxima);
					//check if a folder exists in image directory to hold nnROIs_refX_querryY
					nnROIs2FileName = img0base+"_ch"+sliceQuerry2+"ROIs.zip";
					nnRoiDirectory2 = "nnROIs_ref"+sliceRef+"_querry"+sliceQuerry2;
					nnRoiDirectoryPath2 = dir + File.separator + nnRoiDirectory2;
					querryROIsFile2 = nnRoiDirectoryPath2 + File.separator +nnROIs2FileName;
					if (File.isDirectory(nnRoiDirectoryPath2)==false) File.makeDirectory(nnRoiDirectoryPath2);
					roiManager("save",querryROIsFile2);	

				} // close if(nnROIsFromFile==false	)	

				
				nROIsQuerry2 = roiManager("count");
				//print("\\Update17:"+ nROIsQuerry2+ " potential nearest neighbours in channel 2");
				// clear results table, and measure ROIs on distance map
				run("Clear Results");
				selectWindow(imgRefDfromPerimeter);
				roiManager("measure");
				querry2DistanceTable = "sliceQuerry2_distances"; 
				querry2Area = newArray(nResults);
				querry2Mean = newArray(nResults);
				querry2Distances = newArray(nResults);
				querry2X = newArray(nResults);
				querry2Y = newArray(nResults);
				querry2XM = newArray(nResults);
				querry2YM = newArray(nResults);
				querry2Major = newArray(nResults);
				querry2Minor = newArray(nResults);
				for (t = 0; t<nResults(); t++) {
					querry2Area[t]  = getResult("Area",t);			
					querry2Mean[t] = getResult("Mean",t);
					querry2Distances[t] = getResult("Mean",t);
					querry2X[t] = getResult("X",t);
					querry2Y[t] = getResult("Y",t);
					querry2XM[t] = getResult("XM",t);
					querry2YM[t] = getResult("YM",t);
					querry2Major[t] = getResult("Major",t);
					querry2Minor[t] = getResult("Minor",t);	
				}

				IJ.renameResults(querry2DistanceTable);
				selectWindow(querry2DistanceTable);
				run("Close");
				selectWindow(imgRefNumberedROIs);  
				roiManager("measure");
				querry2vsRefROINumber = "sliceQuerry2_refOverlap"; 
				querry2IsInRefRois = newArray(nResults);
				
				for (t = 0; t<nResults(); t++) {
					//measure ref ROI ID index at geometric center of NN ROI
					//querry2IsInRefRois[t] = getPixel(querry2X[t],querry2Y[t]);  // v6.0.0.9c - changed to measuring 
					querry2IsInRefRois[t] = getResult("Mean",t);   // removed v6.0.0.9c //restored v6.0.1.3 after seeing name ROIs with no NN

				}
				
				IJ.renameResults(querry2vsRefROINumber);
				selectWindow(querry2vsRefROINumber);  //Miner_v2.3d
				run("Close");
			
			}
				
			// Section 3 Loop through ref ROIs ===========================================================================================================================================================
			//==============================================================================================================================================================================================
			
			// clear querry ROIs and reload ref channel ROIs
			roiManager("reset");
			roiManager("Open",getDirectory("home")+"tempRoiSet.zip");
			nRefROI = roiManager("count");
			nMatches = 0;
			
			for (currROI=0; currROI<nROIs; currROI++) { 
		
				// Section 3.0: calculate FWHM of ref ROIs =========================================================================================================================
				//==============================================================================================================================================================================================
				roiManager("select",currROI);
				Roi.getCoordinates(xpointsRefROI, ypointsRefROI);
				// v6.0.0.9c oroginal coordinates are smoothed by averaging 3 pts
				xPtsSmoothed = Array.copy(xpointsRefROI);
				yPtsSmoothed = Array.copy(ypointsRefROI);
				for (aa=0; aa<xpointsRefROI.length; aa++) {
					bb = aa+1;
					cc = aa +2;
					if (bb == xpointsRefROI.length) bb= 0;
					if (cc >= xpointsRefROI.length) cc= xpointsRefROI.length - aa -1;
					xPtsSmoothed[aa] = (xpointsRefROI[aa] + xpointsRefROI[bb] + xpointsRefROI[cc])/3;
					yPtsSmoothed[aa] = (ypointsRefROI[aa] + ypointsRefROI[bb] + ypointsRefROI[cc])/3;
				}
				xpointsRefROI = xPtsSmoothed;
				ypointsRefROI = yPtsSmoothed;
		
				runReports = false;

		
				timeA = getTime;
				selectWindow(img1);
				setSlice(sliceRef);   
				roiManager("Select", currROI);
		
				//===== 110831 - Run FWHM centered on the local max within the reference ROI to reduce interferance from neighbouring  puncta			
				
				getSelectionBounds(selx, sely, selwidth, selheight);
				getStatistics(currROIArea, mean, min, max, std);
				refRoiX = selx;
				refRoiY = sely;
				refRoiWidth = selwidth;
				refRoiHeight = selheight;
				refRoiMean = mean;
				nRefMaxima = 0; refNoise = noiseLimitRef*std; refItterations = 0;
			
				//110831 - The brightest maxima in the current ROI should be the first local max.
				//while ( (nRefMaxima<1) && (refItterations <= 5) && (refNoise > noiseLimit)) {  //v6.0.0.2 - changed in different ref and NN noiselimits                    
				while ( (nRefMaxima<1) && (refItterations <= 5) && (refNoise > noiseLimitRef)) {                      
					run("Find Maxima...", "noise="+refNoise+" output=List");
					nRefMaxima = nResults();
					refNoise = refNoise/2;
					refItterations ++;
				}
		
				if (nRefMaxima >= 1) {
					if(refCtrType =="geometric") refXcentroid = xCntrGeo[ currROI ];
					if(refCtrType =="COM")       refXcentroid = xRefCOM[ currROI ];
					if(refCtrType =="fitted") refXcentroid = xRefCOM[ currROI ];
					if(refCtrType =="geometric") refYcentroid = yCntrGeo[ currROI ];
					if(refCtrType =="COM")       refYcentroid = yRefCOM[ currROI ];
					if(refCtrType =="fitted") refYcentroid = yRefCOM[ currROI ];

					//%%% 190404 - wondering if these should be centered on the single pixel maxima, so adding 0.5 to each 
					// need to recall where refX and refY get used. 
					refX = getResult("X",0);  //first result (index = 0) is the brightest maxima within the current ref ROI
					refY = getResult("Y",0);  // 
					
					if (verbose==true) print("\\Update13: refX ref Y " + refX + " " + refY);
				}
				
				if (nRefMaxima < 1) {                             //====== 130712: If no local max found, use ROI center of mass from above array
					refXcentroid = xCntrGeo[currROI];
					refYcentroid = yCntrGeo[currROI];
					refX = xRefCOM[currROI] ; 
					refY = yRefCOM[currROI] ;
				}

				// prior to v6.1.0.5, FWHM was centered on refX and refY. These were the locations of the local maxima in the ref channel.
				// These are likely slightly different from the centroid used to calculated distance from local maxima.

				// ====== 130712: Define a line that will be used to calx FWHM, and draw on ref image
				refAR = refROIminorAxis[currROI] / refROImajorAxis[currROI];
		
				// ===== calc FWHM along major axis of curr ROI =======================================================
				// ============================================================================================
				// handles anisotropic puncta (not circular) and arbitrary long axis orientation

				if (do2DGauss == false) {				
		
					refxMajor1 =  refX - cos( refROIAngle[currROI] * PI / 180)*(refROImajorAxis[currROI]/2.0 + pad);
					refxMajor2 =  refX + cos( refROIAngle[currROI] * PI / 180)*(refROImajorAxis[currROI]/2.0 + pad);
					refyMajor1 =  refY + sin( refROIAngle[currROI] * PI / 180)*(refROImajorAxis[currROI]/2.0 + pad);
					refyMajor2 =  refY - sin( refROIAngle[currROI] * PI / 180)*(refROImajorAxis[currROI]/2.0 + pad);
		
					makeLine(refxMajor1, refyMajor1, refxMajor2, refyMajor2, lineWidth);
					FWHMarray1Major = FWHM(img1,minFWHMLineLength,maxPad);  //===== first call to calculate FWHM   
					selectWindow(img1); 
					xCenterMajor = FWHMarray1Major[0];   // FWHM now returns x and y values as on the image, no offsets
			  		yCenterMajor = FWHMarray1Major[1];
					majorFWHM = FWHMarray1Major[2];
					if ( gaussPeakReported == true) majorHeight =  FWHMarray1Major[4];
					if ( gaussPeakReported == false) majorHeight =  FWHMarray1Major[6];
			
					majorR2 = FWHMarray1Major[3];
			
					// changing:  xCenter to xCenterMajor,  yCenter to yCenterMajor, xFWHM to majorFWHM, yFWHM to minorFWHM
			
			    	// ===== calc FWHM along minor axis of curr ROI =======================================================
					// ============================================================================================
					refxMinor1 =  refX - cos( ( refROIAngle[currROI] - 90) * PI / 180)*(refROIminorAxis[currROI]/2.0 + pad);
					refxMinor2 =  refX + cos( ( refROIAngle[currROI] - 90) * PI / 180)*(refROIminorAxis[currROI]/2.0 + pad);
					refyMinor1 =  refY + sin( ( refROIAngle[currROI] - 90) * PI / 180)*(refROIminorAxis[currROI]/2.0 + pad);
					refyMinor2 =  refY - sin( ( refROIAngle[currROI] - 90) * PI / 180)*(refROIminorAxis[currROI]/2.0 + pad);
	
					makeLine(refxMinor1, refyMinor1, refxMinor2, refyMinor2, lineWidth);
					FWHMarray1Minor = FWHM(img1,minFWHMLineLength,maxPad);  //===== first call to calculate FWHM   
					selectWindow(img1); 
					xCenterMinor = FWHMarray1Minor[0];   // FWHM now returns x and y values as on the image, no offsets
			  		yCenterMinor = FWHMarray1Minor[1];
					minorFWHM = FWHMarray1Minor[2];
					if ( gaussPeakReported == true) minorHeight =  FWHMarray1Minor[4];
					if ( gaussPeakReported == false) minorHeight =  FWHMarray1Minor[6];
					minorR2 = FWHMarray1Minor[3];
			
					// v2.3 - override FWHM if fit is poor and value is crazy
					if (  (-1 != NNlimitFWHM) && (FWHMarray1Major[2] > NNlimitFWHM)  ) majorFWHM = 99.999;
					if (  (-1 != NNlimitFWHM) && (FWHMarray1Minor[2] > NNlimitFWHM)  ) minorFWHM = 99.999;
			
					xCenter = (xCenterMajor + xCenterMinor)/2;
					yCenter = (yCenterMajor + yCenterMinor)/2;
				}				

				if (do2DGauss == true) {
					// not well suited to anisotropic data. See linked web page in function.				
					// testing using 2D Gauss 
					// need to get ref ROI Points
					display_output = false; //Set to true to output reconstructed patch and fit plot, for speed set to false.
					wid = getWidth();
					hei = getHeight();
					size_of_patch = maxOf(refRoiWidth+4,refRoiHeight+4); //Size of patch to fit Gaussian in. Should be 3-5x size of Gaussian sigma.
					display_output = false; //Set to true to output reconstructed patch and fit plot, for speed set to false.
					
					makePoint(refX, refY);
					getSelectionCoordinates(xPoints,yPoints);
					out_xPoints = newArray(xPoints.length);
					out_yPoints = newArray(xPoints.length);
					for (v=0;v<xPoints.length;v++){
						selectWindow(img1);
						x = newArray(size_of_patch*size_of_patch);
						o = newArray(size_of_patch*size_of_patch);
						c =0;
						for(j=0;j<size_of_patch;j++){
						  for(i=0;i<size_of_patch;i++){
						   	o[c] = getPixel(i+xPoints[v]-round(size_of_patch/2),j+yPoints[v]-round(size_of_patch/2));
						  	x[c] = c;
						  	c = c+1;
						  }
						}
						
						//Calls the function which fits the distribution within the patch.
						//out = fit_gaussian_diag_cov(size_of_patch,size_of_patch,x,o,display_output);
						out = fit_gaussian_diag_cov(size_of_patch,size_of_patch,x,o,true);
		
						majorFWHM = out[1]; //a, 
						minorFEHM = out[3]; //b
						majorHeight = out[0]-out[f];
						minorHeight = out[0]-out[f];
						if ( gaussPeakReported == true){
							majorHeight = out[0]-out[f];
							minorHeight = out[0]-out[f];
						}
						if ( gaussPeakReported == false){
							Array.getStatistics(o,baseline,majorHeight);
							minorHeight = majorHeight;
						}
						//We want our point to be centered on the pixel not top-left, so we add 0.5.
						xCenter = out[2]+xPoints[v]-round(size_of_patch/2)+0.5;
						yCenter = out[4]+yPoints[v]-round(size_of_patch/2)+0.5;
					}
				}

				x1= round(xCenter); 
				y1= round(yCenter);

				if (verbose==true) print("\\Update14: ref xCenter,yCenter: "+xCenter+";"+yCenter);

				// ===========================================================================================================================================
				// Section 3.2 Loop through each color channel / slice to be analyzed
				// ===========================================================================================================================================
			
				//Section 3.2.0
				for (slice=0; slice<nSlicesToAnalyze;slice++) {               // loop through channels to be analyzed
					selectWindow(img1); 
					currSlice = slicesToAnalyze[slice];
					setSlice(currSlice);
					
					// Set variables to match current querry slice
					if (slice == 0) {
						img4FWHM = img2; 
						nNNROIs = nROIsQuerry1;
						querryArea = querry1Area;
						querryMean = querry1Mean;
						qMeanDFromAnyP = querry1Distances;
						querryXs = querry1X;
						querryYs = querry1Y;
						querryXM = querry1XM;
						querryYM = querry1YM;
						querryMajor = querry1Major;
						querryMinor = querry1Minor;
						querryIsInRefRois = querry1IsInRefRois;  
						querryROIsFile = querryROIsFile1;
					}
					if (slice == 1) {
						img4FWHM = img3; 
						nNNROIs = nROIsQuerry2;
						querryArea = querry2Area;
						querryMean = querry2Mean;
						qMeanDFromAnyP = querry2Distances;
						querryXs = querry2X;
						querryYs = querry2Y;
						querryXM = querry2XM;
						querryYM = querry2YM;
						querryMajor = querry2Major;
						querryMinor = querry2Minor;
						querryIsInRefRois = querry2IsInRefRois;
						querryROIsFile = querryROIsFile2;
					}
					getStatistics(area, mean, min, max, std);
		
		 	  		//----------------------------------------------------------------------------------------------------------------------------------------------------
					// Section 3.2.1 161101 = compare current ROIs against potential NN ROIs identified in part 2.2
		
					//load querry ROIs into ROI manager after ref ROIs on first loop of ref ROIs
					if (slice == 0) nROIsQuerry = nROIsQuerry1;
					if (slice == 1) nROIsQuerry = nROIsQuerry2;
					//add nnChX ROIs to ROI manager on in first lap of analyzing ref ROIs
					if ((currROI==0) &&(slice == 0)) {
						q1ROIIndexFirstnn1 = roiManager("count");
						roiManager("open",querryROIsFile);
						nTotalROIs = roiManager("count");
						q1ROIIndexLastnn1 = roiManager("count");
						
					}
					if ((currROI==0) &&(slice == 1)) {
						q1ROIIndexFirstnn2 = roiManager("count");
						roiManager("open",querryROIsFile);
						nTotalROIs = roiManager("count");
						q1ROIIndexLastnn2 = roiManager("count");
					}
					//depending on which slice is being analyzed, will need to adjust which ROI indices are compared to refROIs
					if (slice == 0) {
						q1ROIIndexFirst = q1ROIIndexFirstnn1;
						q1ROIIndexLast = q1ROIIndexLastnn1;
					}
					if (slice == 1) {
						q1ROIIndexFirst = q1ROIIndexFirstnn2;
						q1ROIIndexLast = q1ROIIndexLastnn2;
					}
					roiManager("deselect");
					if (nROIsQuerry != (q1ROIIndexLast-q1ROIIndexFirst) ) waitForUser("nROIs in querry <> nQuerryROIs loaded");
		
					// Holders for querry related parameters =======================================================================================================================================
					localXs = newArray(nROIsQuerry); localYs = newArray(nROIsQuerry); localDists = newArray(nROIsQuerry); localDistsGeo = newArray(nROIsQuerry); localDistsCOM = newArray(nROIsQuerry); localDistsFitted = newArray(nROIsQuerry);
					localDirection = newArray(nROIsQuerry); dFromParray = newArray(nROIsQuerry); localNNAreas = newArray(nROIsQuerry); localNNmeans = newArray(nROIsQuerry); localNNradius = newArray(nROIsQuerry);
					fracOverlapNN = newArray(nROIsQuerry); nnRoiIndexArray= newArray(nROIsQuerry); fracOverlapRef = newArray(nROIsQuerry);
					Array.fill(localDists,9999); Array.fill(dFromParray,9999);
					
					//Section 3.2.2: compare current ROI to each possible nearest neioghbour. If within search radius, further analyze; 
					// nROIs = # of ref ROIS, so = first index of querry ROIs
					// roiIndex: current querry ROI with list of both sets of ROIS (ref ROIS > querryROIs)
					nMaxima = 0; //count number of querry ROIs within maxNNdist of ref ROI
					nTooFar = 0;
					refAndNNCtrSame = false;
					
					for (roiIndex= q1ROIIndexFirst ; roiIndex<q1ROIIndexLast; roiIndex++) {
						
						currQuerryIndex = roiIndex - q1ROIIndexFirst; // currQuerryROI: index of current querry (potential NN) being tested in the list of querry ROIs identified rather than in the current ROI manager

						// ==== Calculate direction (angle) between peaks ======================================================================================================================================================
						if(refCtrType =="fitted") localDirection[currQuerryIndex] = atan2( (querryYs[currQuerryIndex] - yCenter), ( querryXs[currQuerryIndex] - xCenter)) * (180/PI); 
						if(refCtrType =="geometric") localDirection[currQuerryIndex] = atan2( (querryYs[currQuerryIndex] - yCntrGeo[currROI]), ( querryXs[currQuerryIndex] - xCntrGeo[currROI])) * (180/PI); 
						if(refCtrType =="COM")       localDirection[currQuerryIndex] = atan2( (querryYs[currQuerryIndex] - yRefCOM[currROI]), ( querryXs[currQuerryIndex] - xRefCOM[currROI])) * (180/PI); 

						// ==== Calculate distance between peaks ======================================================================================================================================================
						distGeoCtrs = sqrt( pow( querryXs[currQuerryIndex] - xCntrGeo[currROI] ,2) + pow( querryYs[currQuerryIndex] - yCntrGeo[currROI],2)); 
						distCOMs = sqrt( pow( querryXM[currQuerryIndex] - xRefCOM[currROI] ,2) + pow( querryYM[currQuerryIndex] - yRefCOM[currROI],2)); 
						distFittedCtrs = sqrt( pow( querryXM[currQuerryIndex] - xCenter ,2) + pow( querryYM[currQuerryIndex] - yCenter,2)); 

						if(refCtrType =="geometric") ref2querryDist = distGeoCtrs;  //MINER_batch_v1.1
						if(refCtrType =="COM")       ref2querryDist = distCOMs; 	//MINER_batch_v1.1
						if(refCtrType =="fitted")    ref2querryDist = distFittedCtrs; //MINER_batch_v1.1 //this value would neeed to updated once FWHM used to find NN ctrs
						// MINER_batch_v1.0 190404: Noting that ref2querryDist is calculated using querryX[Y]s, which is the geometric center of the NN roi (or maxima if no ROIs defined)
		
						// ONLY ANALYZE QUERRY ROIS THAT ARE WITHIN SEARCH RADIUS =================================================================================================================
						// ========================================================================================================================================================================
						//if (ref2querryDist > radius) { // Miner v2.0
						if (ref2querryDist > maxNNdist) {
							
							// fill most metrics with -1	
							localXs[currQuerryIndex]=-1; localYs[currQuerryIndex]=-1; localDirection[currQuerryIndex]=-1; dFromParray[currQuerryIndex]=9999;
							localDists[currQuerryIndex]=ref2querryDist; localDistsGeo[currQuerryIndex]=distGeoCtrs; localDistsCOM[currQuerryIndex]=distCOMs; localDistsFitted[currQuerryIndex]=distFittedCtrs;
							nTooFar = nTooFar + 1;
							
						} else {
							
						// ===== Determine distances, directions and overlap between ref and requery ROIs =======================================================================

							//v6.1.0.5 - refX and refY used for FWHM of ref puncta use floor of pixel values, NN channel used center (X.5 & Y.5)
							// 170808 - switching localXs and localYs to be floor(querryXs[currQuerryIndex]) did not quite fix the 0.5 px difference between reference and NN centers
							//v6.1.0.6 -localXs[currQuerryIndex] = floor(querryXs[currQuerryIndex]);
							// This seems to improve median separation from ~0.5 pixels to ~0.3 pixels
							// Note, even when refX/Y match localXs/Ys, there is some spread in distance between peaks. Still not sure why. 
							// MINER_batch_v1.0 190404 - must be a rounding error somewhere!!
							
							localXs[currQuerryIndex] = floor(querryXs[currQuerryIndex]);	//quaerryXs and querryYs are geometric positions with X.5 pixel values
							localYs[currQuerryIndex] = floor(querryYs[currQuerryIndex]);	

							if (( abs(localXs[currQuerryIndex]-refX) == 0) && (abs(localYs[currQuerryIndex]-refY)==0)) {
								refAndNNCtrSame = false;
								nMatches = nMatches + 1;
								if (verbose==true) print("\\Update16: matches " + nMatches + " : " + (q1ROIIndexLast-q1ROIIndexFirst) );
							}

							localDists[currQuerryIndex] =  ref2querryDist;	
							localDistsGeo[currQuerryIndex]=distGeoCtrs; 		//MINER_vatch_v1.1
							localDistsCOM[currQuerryIndex]=distCOMs; 			//MINER_vatch_v1.1
							localDistsFitted[currQuerryIndex]=distFittedCtrs;	//MINER_vatch_v1.1	
							nnRoiIndexArray[currQuerryIndex]= currQuerryIndex;
							localNNAreas[currQuerryIndex] = querryArea[currQuerryIndex];
							localNNmeans[currQuerryIndex] = querryMean[currQuerryIndex];
							localNNradius[currQuerryIndex] = (querryMajor[currQuerryIndex] + querryMinor[currQuerryIndex])/2;

							// MINER_batch_v1.0 190404: This was meant to address this issue where a NN puncta (querry) had a negative dFromP value because 
							// it was located within a ref Puncta other than the current puncta. 
							// I am just realizing that I have not accounted for cases where the dFromP value for the querry is small because it is close to
							// a neighbouring ref puncta (i.e. on the other side of a voronoi distance barrier. 
	
							// MINER_batch_v1.0 190404 - This dFromP = 999 business just seemed to be getting in the way. Not
							// sure why. But results make much more sense when disabled. Perhaps a wierd ROI numbering issue. 
							//if ((querryIsInRefRois[currQuerryIndex]!=currROI)&&(querryIsInRefRois[currQuerryIndex]!=0)) {
							//	dFromP = 999;
							//	dFromParray[currQuerryIndex] = 999;
							//	localDists[currQuerryIndex] = 999;
							//} else {
								
							//otherwise calculate distance from perimeter of currROI
							//v6.0.0.9c resample array coordinates 3x to smooth out perimeter and give closer to continuous values for distance from perimeter 
							dFromP = 999; // if querry is within a different refROI, code dFromP and localDist as 999
							for(r=0; r<xpointsRefROI.length; r++) {
								dNext = sqrt( pow( ( localXs[currQuerryIndex] - xpointsRefROI[r]) ,2) + pow( ( localYs[currQuerryIndex] - ypointsRefROI[r]),2)) ; 
								if (dNext < dFromP) dFromP = dNext;	
							}
							// if querry ROI is within currROI, then dFromP is negative indicating that it is within the bound of currROI
							selectWindow(imgRefNumberedROIs);
							if (getPixel(localXs[currQuerryIndex], localYs[currQuerryIndex]) == (currROI+1)) dFromP = -1 * dFromP;   
							selectWindow(img1);
							dFromParray[currQuerryIndex] = dFromP;
							//}
		
							// calculate fraction of querry ROI within ref ROI. Select ref and querry ROI. Combine with roiManager("and"), Get area
							// ====================================================================================================================
							if (calcOverlap==true) {
								roiManager("select",currROI);
								Roi.getCoordinates(x0, y0);
								//getStatistics(a1);
								roiManager("select",roiIndex);
								Roi.getCoordinates(x1, y1);
								//getStatistics(a2);
								xc = newArray();
								yc = newArray();
								ao = 0; // Overlap area in pixels
								 for (i=0;i<x0.length;i++) {
								    if (Roi.contains(x0[i], y0[i])==1) {
								    	xc = Array.concat(xc,x0[i]);
								    	yc = Array.concat(yc,y0[i]);
								    }
								 }
								 if (xc.length>0) { // if xc.length==0, then first ROI had no overlap with 2nd. Overlap area (ao) = 0 
								 	//else find verticies of 2nd ROI that are within 1st ROI
									roiManager("select",0);
									for (i=0;i<x1.length;i++) {
									    if (Roi.contains(x1[i], y1[i])==1) {
									    	xc= Array.concat(xc,x1[i]);
									    	yc = Array.concat(yc,y1[i]);
									    }
									}
									makeSelection("polygon", xc, yc);; //merge the two sets of verticies
									if (xc.length >60) run("Convex Hull"); // determine the convex hull of the overlapping region
									getStatistics(ao); // get the overlapping area
									run("Select None");
								 }
								 if (ao == imgW*imgH) ao = 0;
								fracOverlapNN[currQuerryIndex] = ao/currROIArea;
								fracOverlapRef[currQuerryIndex] = ao/querryArea[currQuerryIndex];;
							} else {
								fracOverlapNN[currQuerryIndex] = -1;
								fracOverlapRef[currQuerryIndex] = -1;
							}
/*							
							if (calcOverlap==true) {
								// this needs a do over. regino of overlap is combine, xor, xor of combine and xor
								// fails when 
								nrTemp1 = roiManager("count");
								refQuerryIndicies = newArray(currROI,roiIndex);
								roiManager("deselect");
								roiManager("select",currROI);
								getStatistics(a1, m1);
								roiManager("select",roiIndex);
								getStatistics(a2, m2);
								roiManager("select",refQuerryIndicies);
								roiManager("XOR");
								getStatistics(aCombined);
								//if XOR has no selection, then aCombined will be area of entire image. 
								// So test of aCombined > a1 + a2 = sum of area of individual ROIs.
								if (aCombined > (a1+a2)) { // perfect overlap
									fracOverlapNN[currQuerryIndex] = 1;
									fracOverlapRef[currQuerryIndex] = 1;
										
								} else if (aCombined == (a1+a2))  { // no overlap
									fracOverlapNN[currQuerryIndex] = 0;
									fracOverlapRef[currQuerryIndex] = 0;
									
								} else {  // indicates some amount of overlap
									roiManager("add"); // add XOR ROIs
									roiManager("select",refQuerryIndicies);
									roiManager("combine");
									roiManager("add");
									tempArray = newArray(roiManager("count")-1,roiManager("count")-2);
									roiManager("select",tempArray);
									roiManager("XOR");
									getStatistics(aOverlap);
									roiManager("select",tempArray);
									roiManager("delete");
									currFracOverlapNN =  aOverlap/a1;
									currFracOverlapRef = aOverlap/a2;
									fracOverlapNN[currQuerryIndex] = currFracOverlapNN;
									fracOverlapRef[currQuerryIndex] = currFracOverlapRef;
								}
							} else {
								fracOverlapNN[currQuerryIndex] = -1;
								fracOverlapRef[currQuerryIndex] = -1;
							}
*/
							nMaxima = nMaxima + 1;	
						} // close if within maxNNdist check
					} // close roiIndex Loop
		
					print ("\\Update1: nMaxima for ref ROI: " +currROI+ " = "+ nMaxima + " nTooFar: " + nTooFar + " nTot: " + (nMaxima + nTooFar)); 
		
					// Make copies of the local Distances array that will be used to sort local Xs, Ys and direction by local distance
		 			localDistsD = Array.copy(localDists); localDistsE = Array.copy(localDists); localDistsF = Array.copy(localDists);  
		
					/* other parameters to sort with NN in future				
					querryX = querry1X; querryY = querry1Y; querryXM = querry1XM;
					querryYM = querry1YM; querryMajor = querry1Major; querryMinor = querry1Minor querryIsInRefRois = querry1IsInRefRois;
					*/
					if (verbose==true)  print("\\Update13: currROI: "+currROI+" nnSortBy: "+nnSortBy+" localDists.length: " +localDists.length+ " dFromParray.length: "+dFromParray.length);
					if (nnSortBy == "center") sortNNArray = Array.copy(localDists);
					if (nnSortBy == "perimeter") sortNNArray = Array.copy(dFromParray);

					// Section 3.2.3 - sort NN ROIs by distance. Becomes required in v6.0.0.0
					if (nMaxima > 0 ) {
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localXs);
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localYs);
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localDirection);
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,dFromParray);
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,fracOverlapNN);
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,fracOverlapRef);
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,nnRoiIndexArray);
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localDists);
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localDistsGeo);		//MINER_batch_v1.1
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localDistsCOM);		//MINER_batch_v1.1
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localDistsFitted);	//MINER_batch_v1.1
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localNNAreas);	//MINER_batch_v1.1
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localNNmeans);	//MINER_batch_v2.1
						sortNNArrayB = Array.copy(sortNNArray);	sort_B_by_sortedA(sortNNArrayB,localNNradius);	//MINER_batch_v2.3
					} else {
						localXs[0] = -1;
						localYs[0] = -1;
						//localDists[0] = -1;
						localDirection[0] = 9999;
						dFromParray[0] = 9999;
						fracOverlapNN[0] = 0;
					}

					
					// =====================================================================================
					//-----Section 3.3 Load results for a given slice and ROI into the results holder ------- -------------------------------------------
					// =====================================================================================
			
					nToLoad = minOf(numNNstats,nMaxima); xTemp = 0; yTemp = 0;
					print("\\Update3: nToLoad: " + nToLoad);

					if (nMaxima == 0) nToLoad = 1;
		
					for (i=0;i<nToLoad;i++) {

						// this effectively means that we aren't recording anything for ref ROIs that don't have a partner. That's too exclusive
						//if (localDists[i] <= maxNNdist) {
						
							selectWindow(img4FWHM);  // new in V4.8.1.0 - set to match "slice" in slicesToAnalyze[] array

							// v6.0.0.0 161102 - Note that using (localDists[0] != -1) ) as exlusion criteria OK, because localDist is between centers so always >0
							//if ((nMaxima > 0) && (localDists[0] != -1) ) {
							if (localDists[i] <= maxNNdist) { //Miner v2.3 - this should be sufficient criteria to decide whether to do fitting or not on NN, otherwise refROI gets all -1's 
								xGeo = localXs[i];
								yGeo = localYs[i];

								// MINER v2.3 - NN initial radius 
								if (nnROIsFromFile==false) roiRadius = NNFWHMradius; //use user define radius from dialog
								if (nnROIsFromFile==true) roiRadius = localNNradius[i]; //uses mean of major and minor axes of best fit ellipse 
								roiRadius = NNFWHMradius; 
								    
				                if (verbose==true)  print("\\Update14: i="+i+" roiRadius = "+roiRadius+"  NNFWHMradius="+NNFWHMradius);            
							
									// ============= v4.0 Calc FWHM of NN at 0 and 90 degree, with starting length = 2*roiRadius =============================
									// =======================================================================================================
									testAngle = 0;
									testxMajor1 =  xGeo - cos( testAngle * PI / 180)*(roiRadius);
									testxMajor2 =  xGeo + cos(testAngle * PI / 180)*(roiRadius);
									testyMajor1 =  yGeo + sin( testAngle * PI / 180)*(roiRadius);
									testyMajor2 =  yGeo - sin( testAngle * PI / 180)*(roiRadius);
									makeLine(testxMajor1, testyMajor1, testxMajor2, testyMajor2, lineWidth);
									FWHMarray2Major = FWHM(img4FWHM,minFWHMLineLength,maxPad);  //===== first call to calculate FWHM   
									selectWindow(img4FWHM); 
									NNxCenterMajor = FWHMarray2Major[0];   // FWHM now returns x and y values as on the image, no offsets
							  		NNyCenterMajor = FWHMarray2Major[1];
									NNmajorFWHM = FWHMarray2Major[2];
									if ( gaussPeakReported == true) NNmajorHeight =  FWHMarray2Major[4];
									if ( gaussPeakReported == false) NNmajorHeight =  FWHMarray2Major[6];
		
									NNmajorR2 = FWHMarray2Major[3];
		
									// ===  v4.8.1.0 test getting local major axis orientation to fit major and minor axes ===============================
									// ============================================================================================
		
									run("Clear Results");
									halfWidth = FWHMarray2Major[2];
									lowerThresold =  FWHMarray2Major[6] * 0.7;
									maxWidth = NNlimitFWHM;
									while ( ( nResults < 1) && ( halfWidth <= maxWidth) ) {
										makeRectangle(NNxCenterMajor - halfWidth, NNyCenterMajor - halfWidth, 2 * halfWidth, 2 * halfWidth);
										setThreshold(lowerThresold, 65000);
										run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Nothing display exclude clear");
										halfWidth ++;
									}
									resetThreshold();
									
									if (nResults == 0) testAngle = 0;
									if (nResults != 0) { 
										testAngle = getResult("Angle", 0);
										xC2 = getResult("X", 0);
										yC2 = getResult("Y", 0);
										if ( sqrt( pow(xC2-NNxCenterMajor,2) + pow(yC2-NNyCenterMajor,2) ) > NNmajorFWHM+2) testAngle = 0;
									}

									// ===== calc FWHM along major axis of curr ROI =======================================================
									// ============================================================================================
				
									if (testAngle != 0) {
										
										testxMajor1 =  xGeo - cos( testAngle * PI / 180.0)*(roiRadius);
										testxMajor2 =  xGeo + cos(testAngle * PI / 180.0)*(roiRadius);
										testyMajor1 =  yGeo + sin( testAngle * PI / 180.0)*(roiRadius);
										testyMajor2 =  yGeo - sin( testAngle * PI / 180.0)*(roiRadius);
										makeLine(testxMajor1, testyMajor1, testxMajor2, testyMajor2, lineWidth);
										FWHMarray2Major = FWHM(img4FWHM,minFWHMLineLength,maxPad);  //===== first call to calculate FWHM   
										//FWHMarray2Major = FWHM(img1,minFWHMLineLength,maxPad);  //===== first call to calculate FWHM   
		
										selectWindow(img4FWHM); 
										//selectWindow(img1); 
										
										NNxCenterMajor = FWHMarray2Major[0];   // FWHM now returns x and y values as on the image, no offsets
								  		NNyCenterMajor = FWHMarray2Major[1];
										NNmajorFWHM = FWHMarray2Major[2];
										if ( gaussPeakReported == true) NNmajorHeight =  FWHMarray2Major[4];
										if ( gaussPeakReported == false) NNmajorHeight =  FWHMarray2Major[6];
		
										NNmajorR2 = FWHMarray2Major[3];
									}
		
									// ===== calc FWHM along minor axis of curr ROI =======================================================
									// ============================================================================================
						
									testxMinor1 =   xGeo - cos( (testAngle-90) * PI / 180)*(roiRadius);
									testxMinor2 =   xGeo + cos( (testAngle-90) * PI / 180)*(roiRadius);
									testyMinor1 =   yGeo + sin( (testAngle-90) * PI / 180)*(roiRadius);
									testyMinor2 =   yGeo - sin( (testAngle-90) * PI / 180)*(roiRadius);
									makeLine(testxMinor1, testyMinor1, testxMinor2, testyMinor2, lineWidth);
									FWHMarray2Minor = FWHM(img4FWHM,minFWHMLineLength,maxPad);  //===== first call to calculate FWHM   
									selectWindow(img4FWHM); 
		
									NNxCenterMinor = FWHMarray2Minor[0];   // FWHM now returns x and y values as on the image, no offsets
							  		NNyCenterMinor = FWHMarray2Minor[1];
									NNminorFWHM = FWHMarray2Minor[2];
									if ( gaussPeakReported == true) NNminorHeight =  FWHMarray2Minor[4];
									if ( gaussPeakReported == false) NNminorHeight =  FWHMarray2Minor[6];
		
									NNminorR2 = FWHMarray2Minor[3];
		
								if ( minOf(NNmajorHeight,NNminorHeight) == 0) {
									NNHeight = maxOf(NNmajorHeight,NNminorHeight);
								} else {
									 NNHeight =(NNmajorHeight +NNminorHeight)/2;
								}
								if ( minOf(majorHeight,minorHeight) == 0){ 
									fittedHeight = maxOf(majorHeight,minorHeight);
								} else {
									fittedHeight =(majorHeight +minorHeight)/2;
								}
		
								NNxCenter = (NNxCenterMajor + NNxCenterMinor)/2;
								NNyCenter = (NNyCenterMajor + NNyCenterMinor)/2;
		
								if ((NNmajorFWHM > NNlimitFWHM) && (NNlimitFWHM!=-1))  {
									NNmajorFWHM = NNlimitFWHM+0.1234;					
									NNxCenter = xGeo;
								}
								if ((NNminorFWHM > NNlimitFWHM) && (NNlimitFWHM!=-1)) {
									NNminorFWHM = NNlimitFWHM+0.1234;
									NNyCenter = yGeo;					
								}
		
								//use geometric X & Y if fitted X & Y are more than some # px away from local max (i.e. 2)
								bestCenter2LocalMax = sqrt( pow(FWHMarray2Major[5],2) + pow(FWHMarray2Minor[5],2)) ; 
								if (bestCenter2LocalMax > 6 ) {
									NNxCenter = xGeo+0.00123;					
									NNyCenter = yGeo+0.00123;					
								}

								localDistsFitted[i] = sqrt( pow( NNxCenter - xCenter ,2) + pow( NNyCenter - yCenter,2)); 
								
								//define the FWHM elipse of the NN to calculate mean intensity
								// 190405 - need to  accomodate using actual NN ROI area if available. 
								if (nnROIsFromFile == true) nnMean = localNNmeans[i];
								if (nnROIsFromFile == false) {
									ar = NNminorFWHM  / NNmajorFWHM;
									majorForElispse = NNmajorFWHM;
									if (NNlimitFWHM!=-1) {
										if (NNmajorFWHM>NNlimitFWHM) {
											ar = 1;
											majorForEllipse = NNminorFWHM;
										} 
							
										if ( (NNmajorFWHM>NNlimitFWHM) & (NNmajorFWHM>NNlimitFWHM) ) {
											ar = 1;
											majorForEllipse = 2*radiusNNPuncta;
										} 
									}
									if ( (ar==0) || (ar>5) ) ar = 1;
									x1 =  NNxCenter - cos( testAngle * PI / 180.0)*(majorForElispse/2);
									x2 =  NNxCenter + cos( testAngle * PI / 180.0)*(majorForElispse/2);
									y1 =  NNyCenter + sin( testAngle * PI / 180.0)*(majorForElispse/2);
									y2 =  NNyCenter - sin( testAngle * PI / 180.0)*(majorForElispse/2);
									makeEllipse(x1, y1, x2, y2, ar);
									getStatistics(area, nnMean, min, max, std, histogram);
									run("Select None");
								}
								//NNROIArea
								if (nnROIsFromFile == false) NNROIArea = PI*(NNmajorFWHM/2)*(NNminorFWHM/2);
								if (nnROIsFromFile == true) NNROIArea = localNNAreas[i];

								// LOAD results into a big result holder
								bigResultsArray[ (nResultsCols * resultsCounter) + 0] =  currROI;  	 //ROI#
								if (i ==0 ) bigResultsArray[ (nResultsCols * resultsCounter) + 1] =	1.0;	//newROI
								if (i !=0 ) bigResultsArray[ (nResultsCols * resultsCounter) + 1] =	0.0;	            //newROI
								bigResultsArray[ (nResultsCols * resultsCounter) + 2] =   i;	              //rank of neighboring ROI - aka Proximity
								bigResultsArray[ (nResultsCols * resultsCounter) + 3] =   currSlice;	  //channel/slice
								bigResultsArray[ (nResultsCols * resultsCounter) + 4] =   refXcentroid;	 // can be geometric or COM of ref ROI depending on options
								bigResultsArray[ (nResultsCols * resultsCounter) + 5] =   refYcentroid;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 6] =   refX;	          // center of local max found in ref ROI
								bigResultsArray[ (nResultsCols * resultsCounter) + 7] =   refY;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 8] =   majorFWHM;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 9] =   minorFWHM;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 10] =   xCenter;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 11] =   yCenter;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 12] = localDistsGeo[i];	   // distance from refROI geometric center or COM depending on options
								bigResultsArray[ (nResultsCols * resultsCounter) + 13] = localDistsCOM[i];	   // distance from refROI geometric center or COM depending on options
								bigResultsArray[ (nResultsCols * resultsCounter) + 14] = localDistsFitted[i];	   // distance from refROI geometric center or COM depending on options
								bigResultsArray[ (nResultsCols * resultsCounter) + 15] = dFromParray[i]; 	  // mean best fit ref peak height								
								bigResultsArray[ (nResultsCols * resultsCounter) + 16] = localDirection[i]; 	
								bigResultsArray[ (nResultsCols * resultsCounter) + 17] = xGeo;	           	//geometric center of NN ROIS or local maxima
								bigResultsArray[ (nResultsCols * resultsCounter) + 18] = yGeo;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 19] = NNxCenter;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 20] = NNyCenter; 
								bigResultsArray[ (nResultsCols * resultsCounter) + 21] = NNmajorFWHM;
								bigResultsArray[ (nResultsCols * resultsCounter) + 22] = NNminorFWHM;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 23] = refRoiMean; 	//mean gray of reference ROI
								bigResultsArray[ (nResultsCols * resultsCounter) + 24] = nnMean; 	//mean gray of neighbor
								bigResultsArray[ (nResultsCols * resultsCounter) + 25] = fittedHeight; 	// mean best fit ref peak height
								bigResultsArray[ (nResultsCols * resultsCounter) + 26] = NNHeight;  	// mean best fit NN peak height
								bigResultsArray[ (nResultsCols * resultsCounter) + 27] =  (FWHMarray2Major[3] + FWHMarray2Minor[3])/2; 	  // average R2 of FWHM fit
								bigResultsArray[ (nResultsCols * resultsCounter) + 28] = sqrt( pow(FWHMarray2Major[5],2) + pow(FWHMarray2Minor[5],2)) ; 	  // mean best fit ref peak height
								bigResultsArray[ (nResultsCols * resultsCounter) + 29] = refROIArea[currROI];
								bigResultsArray[ (nResultsCols * resultsCounter) + 30] = NNROIArea;
								bigResultsArray[ (nResultsCols * resultsCounter) + 31] = testAngle; 	  // mean best fit ref peak height
								bigResultsArray[ (nResultsCols * resultsCounter) + 32] = fracOverlapNN[i]; 	  // mean best fit ref peak height
								bigResultsArray[ (nResultsCols * resultsCounter) + 33] = fracOverlapRef[i]; 	  // mean best fit ref peak height
								bigResultsArray[ (nResultsCols * resultsCounter) + 34] = nnRoiIndexArray[i];  // index of nnROI in list of ROIs initially found in NN channel
								bigResultsArray[ (nResultsCols * resultsCounter) + 35] = qMeanDFromAnyP[nnRoiIndexArray[i]];  // index of nnROI in list of ROIs initially found in NN channel

								selectWindow(img4FWHM); 
		
							} else {  // Handle cases where no local max is found. Center on the reference ROI to get the local mean intensity in the reference channel
								 // then use -1 as a default to indicate in the output that no nearest neighbor was found

								roiRadius = NNFWHMradius;  
								if (verbose==true)  print("\\Update14: i="+i+" roiRadius = "+roiRadius+"  NNFWHMradius="+NNFWHMradius);                 
								// v4.7.1:  add an image with outlines of NNRs
									selectWindow(nnrOutlines);
									makeRectangle(xCenter-roiRadius,yCenter-roiRadius,2*roiRadius,2*roiRadius);
									run("Add Selection...");
									selectWindow(img4FWHM);
									//selectWindow(img1);
		
								//************************************************************************               
								makeOval(xCenter-roiRadius,yCenter-roiRadius,2*roiRadius,2*roiRadius);
								getStatistics(area, nnFWHMmean, min, max, std, histogram);

								proximity = i;
								if (nMaxima==0) proximity = -1;

								bigResultsArray[ (nResultsCols * resultsCounter) + 0] =  currROI;  	 //ROI#
								if (i ==0 ) bigResultsArray[ (nResultsCols * resultsCounter) + 1] =	1.0;	//newROI
								if (i !=0 ) bigResultsArray[ (nResultsCols * resultsCounter) + 1] =	0.0;	            //newROI
								bigResultsArray[ (nResultsCols * resultsCounter) + 2] =   proximity;	              //rank of neighboring ROI - aka Proximity
								bigResultsArray[ (nResultsCols * resultsCounter) + 3] =   currSlice;	  //channel/slice
								bigResultsArray[ (nResultsCols * resultsCounter) + 4] =   refXcentroid;	 // can be geometric or COM of ref ROI depending on options
								bigResultsArray[ (nResultsCols * resultsCounter) + 5] =   refYcentroid;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 6] =   refX;	          // center of local max found in ref ROI
								bigResultsArray[ (nResultsCols * resultsCounter) + 7] =   refY;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 8] =   majorFWHM;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 9] =   minorFWHM;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 10] =   xCenter;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 11] =   yCenter;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 12] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 13] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 14] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 15] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 16] = -1; 	
								bigResultsArray[ (nResultsCols * resultsCounter) + 17] = -1;	           	//geometric center of NN ROIS
								bigResultsArray[ (nResultsCols * resultsCounter) + 18] = -1;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 19] = -1;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 20] = -1; 
								bigResultsArray[ (nResultsCols * resultsCounter) + 21] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 22] = -1;	
								bigResultsArray[ (nResultsCols * resultsCounter) + 23] = refRoiMean; 	//mean gray of reference ROI
								bigResultsArray[ (nResultsCols * resultsCounter) + 24] = -1; 	//mean gray of neighbor
								bigResultsArray[ (nResultsCols * resultsCounter) + 25] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 26] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 27] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 28] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 29] = refROIArea[i];
								bigResultsArray[ (nResultsCols * resultsCounter) + 30] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 31] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 32] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 33] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 34] = -1;
								bigResultsArray[ (nResultsCols * resultsCounter) + 35] = -1;

							}
						resultsCounter ++;
						//} //end if for distance threshold
					}  // close nResults loop
				} //close channel loop
		
				ROIsLeft = nROIs - currROI - 1;
				loopTime = round(getTime-timeA)/1000;
				totalTime = totalTime + loopTime;
				avgLoopTime = totalTime / (currROI + 1);
				timeLeft = avgLoopTime * ROIsLeft;
				pctDoneLength = 35;
				pctDone = floor(pctDoneLength*(currROI/nROIs));
				pctDoneString = "";
				pctLeftString = "";
				for(bb = 0; bb<pctDoneLength;bb++) {
					pctDoneString = pctDoneString + "|";
					pctLeftString = pctLeftString + ".";
				}
				pctDoneString = substring(pctDoneString ,0,pctDone);
				pctLeftString = substring(pctLeftString ,0,pctDoneLength - pctDone);
				print ("\\Update0: currROI: " + pctDoneString + pctLeftString + " " +  (currROI+1) + " of " + nROIs + " loop time: " + d2s(loopTime,3) + " s, time left " +d2s(timeLeft,1)+ " s");
			}
		
		
			//Section 5.0 Clean-up  =========================================================================================
		
			selectWindow(img1);
			close();
			selectWindow(imgRefMask);
			close();
			if (isOpen(img2) == true) {
				selectWindow(img2);
				close();
			}
			if (slicesToAnalyze.length >1) {
				if (isOpen(img3) == true) {
					selectWindow(img3);
					close();
				}
			}
			selectWindow(imgRefDfromPerimeter);
			close();
			selectWindow(imgRefNumberedROIs);
			close();
		
		
		//==== v4.8.0.1 ====== scan results array for NNR assigned to >1 ref puncta and set results to -1 for all but closest puncta
		// ====== added v4.8.0.1 - holding arrays for XY coordinates, dist, ROI # and prox # for each NN, to test if already assigned to another ref puncta ====
		
		//repopulate the ROI manager from the temporarily saved ROIset
		roiManager("reset");

// could this be supressed in batch mode to speed things up!?		
		roiManager("Open",getDirectory("home")+"tempRoiSet.zip");			
		
		
			for (a = 1; a < resultsCounter; a++) {
				for (b = 0; b < a; b++) {
				
					// check that two NN are on same channel  - added v4.8.1.3
					if (  bigResultsArray[ (nResultsCols * a) + 3] == bigResultsArray[ (nResultsCols * b) + 3]  ) {
					
						// check if two NN X & Y local maxima are same
						if ( ( bigResultsArray[ (nResultsCols * a) + 17] == bigResultsArray[ (nResultsCols * b) + 17]  ) && ( bigResultsArray[ (nResultsCols * a) + 18] == bigResultsArray[ (nResultsCols * b) + 18])) {
		
							//check that ROIs have not already been excluded for being closer to another ref ROI based on distance from perimeter
							if ( ( bigResultsArray[ (nResultsCols * a) + 17] != -1  ) && ( bigResultsArray[ (nResultsCols * b) + 17] != -1  ) ) {
								
								minAdist = bigResultsArray[ (nResultsCols * a) + 15];  //distances compared as distance from perimeter
								minBdist = bigResultsArray[ (nResultsCols * b) + 15];  //distances compared as distance from perimeter
								//tie results in both kept, otherwise label as negative of ROI that took precedence
								if ( minAdist < minBdist)  { 
								 	bigResultsArray[ (nResultsCols * b) + 2] = -1*a; 
								} 
								if ( minAdist > minBdist)  { 
									 bigResultsArray[ (nResultsCols *a) + 2] = -1*b; 
								}
							}	
						}
					}
				} //b
			}  //a
		
			//=================== Transfer the data from its holding array to a results table ================================================
			//===============================================================================================================
			run("Clear Results");
			numResults = resultsCounter;
			
			for (m=0; m<numResults;m++) {
				for (n=0; n<=nResultsCols-1;n++) {
					setResult("Label", m, img0 );  //load results into the 
					setResult(resultsLabels[n], m, bigResultsArray[ (m*nResultsCols) + n] );  //load results into the 
				}
			}
			print("\\Update2: numResults = "+numResults);
			setResult("Label", m, "Analysis_parameters_"+parametersString);
			updateResults();
		
			//==== Option: save the results table to image directory =================================
			chnlsAnalyzed = "_Analyzed_C"+slicesToAnalyze[0];
			if (sliceQuerry2 != "0") chnlsAnalyzed = chnlsAnalyzed + "_C"+slicesToAnalyze[1];
			if (autoSaved == true) {
				tree = split(dir,"\\");
				if (saveToParentDir == true) 	currDir = tree[tree.length-2];    // 130522 v2.5: updated to accomadate more diverse file names
				if (saveToParentDir == false) 	currDir = tree[tree.length-1];
				path = dir + "Results_" + replace(img0,imgType,"") + "_C" + sliceRef + chnlsAnalyzed + txtSuffix + ".txt";
				saveAs("Results", path);
			}
			selectWindow(nnrOutlines);
			
			selColors = newArray(ch1Clr,ch2Clr,ch3Clr);
			makeLine(0, 0, 10, 10);
			originalLineWidth = getValue("selection.width");
		
		if (doBatch == true) setBatchMode("exit and display");	
			
			selectWindow(img0);
			print("\\Update2: creating overlays");
			for (a = 0; a < resultsCounter; a++) {
				if ( (bigResultsArray[ (nResultsCols * a) + 2] >= 0 ) && (bigResultsArray[ (nResultsCols * a) + 12] >= 0) && (bigResultsArray[ (nResultsCols * a) + 12] <= maxNNdist) ) {
			
					if ( 0 == bigResultsArray[ (nResultsCols * a) + 2] ) selColors = newArray(ch1Clr,ch2Clr,ch3Clr);
					if ( 0 >  bigResultsArray[ (nResultsCols * a) + 2] ) selColors = newArray("red","yellow","blue");
					xNNctr = bigResultsArray[ (nResultsCols * a) + 19];
					yNNctr = bigResultsArray[ (nResultsCols * a) + 20];
					if ( (xNNctr !=-1) && (yNNctr !=-1)) {
						wNN =bigResultsArray[ (nResultsCols * a) + 21];  //nnFWHMMajor 
						hNN = bigResultsArray[ (nResultsCols * a) + 22]; //nnFWHMMinor
						if (wNN < 2.5) wNN = 2.5;
						if (hNN < 2.5) hNN = 2.5;
						x =bigResultsArray[ (nResultsCols * a) + 10];  //ref fitted centre X
						y =bigResultsArray[ (nResultsCols * a) + 11]; //ref fitted centre y
						currROI = bigResultsArray[ (nResultsCols * a) + 0]; //ref fitted centre y
						angle = bigResultsArray[ (nResultsCols * a) + 31];
						nnMajorFWHM = bigResultsArray[ (nResultsCols * a) + 21];
						nnMinorFWHM = bigResultsArray[ (nResultsCols * a) + 22]; 
						if (nnMajorFWHM<nnMinorFWHM) {
							nnMajorFWHM = bigResultsArray[ (nResultsCols * a) + 22];
							nnMinorFWHM = bigResultsArray[ (nResultsCols * a) + 21]; 
							angle = angle - 90;
						}
						ar = nnMinorFWHM  / nnMajorFWHM;
						if ( (ar==0) || (ar>3) ) ar = 1;
						x1 =  xNNctr+0.5 - cos( angle * PI / 180.0)*(nnMajorFWHM/2);
						x2 =  xNNctr+0.5 + cos(angle * PI / 180.0)*(nnMajorFWHM/2);
						y1 =  yNNctr+0.5 + sin( angle * PI / 180.0)*(nnMajorFWHM/2);
						y2 =  yNNctr+0.5 - sin( angle * PI / 180.0)*(nnMajorFWHM/2);
						if (nnMajorFWHM>=3) {
							makeEllipse(x1, y1, x2, y2, ar);
						} else {
							makeEllipse(xNNctr-1, yNNctr-1, xNNctr+2, yNNctr+2, 1);
							
						}
						
						//Miner2.3 - allows analysis of images with >3 channels
						//Overlay.addSelection(selColors[bigResultsArray[ (nResultsCols * a) + 3]-1],roiLineWidth);
						if (verbose == true) print("\\Update13: ROI "+currROI+" Overlay ellipse size"+ Overlay.size +" x1 "+ x1 +" x2 "+ x2 +" y1 "+ y1 +" y2 "+ y2);
						if (Overlay.size>0) {
							if (slice==1) Overlay.addSelection(ch2Clr,roiLineWidth);
							if (slice==2) Overlay.addSelection(ch3Clr,roiLineWidth);
						}
						lineLength = sqrt( pow(xNNctr -x,2) + pow(yNNctr -y,2));
						if (verbose == true) print("\\Update13: Overlay line size"+ Overlay.size +" xNNctr+0.5 " +xNNctr+0.5 +" yNNctr+0.5 "+yNNctr+0.5 +" x "+ x +" y "+ y);
						if ( (lineLength <= maxNNdist) && (lineLength >= 1.5) ) {
							makeLine(xNNctr+0.5, yNNctr+0.5, x, y);
							//Overlay.addSelection(selColors[bigResultsArray[ (nResultsCols * a) + 3]-1],roiLineWidth);
							//Miner2.3 - allows analysis of images with >3 channels
							olsz = Overlay.size;
							if (Overlay.size>0) {
								if (slice==1) Overlay.addSelection(ch2Clr,roiLineWidth);
								if (slice==2) Overlay.addSelection(ch3Clr,roiLineWidth);
								
							}
						} 
						if ( (lineLength <= maxNNdist) && (lineLength < 1.5) ) {
							makeEllipse(xNNctr, yNNctr, xNNctr+1, yNNctr+1, 1);
							if (slice==1) Overlay.addSelection(ch2Clr,roiLineWidth);
							if (slice==2) Overlay.addSelection(ch3Clr,roiLineWidth);
							
						}

						
					}
				}
				//MINER v2.3 - add rectangle if no NN
				if ( (bigResultsArray[ (nResultsCols * a) + 2] < 0 ) && (numNNstats==1) ) {
						x =bigResultsArray[ (nResultsCols * a) + 10];  //ref fitted centre X
						y =bigResultsArray[ (nResultsCols * a) + 11]; //ref fitted centre y
						makeRectangle(x-radiusNNPuncta/2,y-radiusNNPuncta/2,radiusNNPuncta,radiusNNPuncta);
							if (slice==1) Overlay.addSelection("lightgray",roiLineWidth);
							if (slice==2) Overlay.addSelection("gray",roiLineWidth);
				}
			}  //a
		
			run("Colors...", "foreground="+foregroundColor+" background="+backgroundColor+" selection="+origianlSelectionColor);
			run("Line Width...", "line="+originalLineWidth);
			//setColor(origianlSelectionColor);
			
			//===============================================================================================================

			// this could be supressed in batch mode to speed things up!?!?		
			roiManager("Open",getDirectory("home")+"tempRoiSet.zip");
			//File.delete(getDirectory("home")+"tempRoiSet.zip");
		 	//repopulate the ROI manager from the temporarily saved ROIset
			roiManager("Set Color", "cyan");
			roiManager("Show All with labels");
			end = getTime;
			print ("\\Update3: " + currROI + " ROIs processed in " +(end-start)/1000+ " sec");
		} // close findLocalPuncta function	

//===========================================================================================================================================
//===========================================================================================================================================
	
	// **** 1. Modified QuickSort *********************************************************************************************************************************
	function sort_B_by_sortedA(a,b) {quickSort(a, 0, lengthOf(a)-1,b);}
	
	function quickSort(a, from, to,b) {
	      i = from; j = to;
	      center = a[(from+to)/2];
	      do {
	          while (i<to && center>a[i]) i++;
	          while (j>from && center<a[j]) j--;
	          if (i<j) {
			temp=a[i]; 
			a[i]=a[j]; 
			a[j]=temp;
			tempc=b[i]; 
			b[i]=b[j]; 
			b[j]=tempc;
		}
	          if (i<=j) {i++; j--;}
	      } while(i<=j);
	      if (from<j) quickSort(a, from, j, b);
	      if (i<to) quickSort(a, i, to, b);
	}

// ***** 3. FWHM *********************************************************************************************************************************

		function FWHM(img4FWHM, minSubArrayWidth, maxPad) {  // FWHMofLine_v2.1
		// FWHMofLine_v2.3.0
		
		/*
		This function assumes that a line selection has been made on the image to be analyzed. 
		It will attempt to fit this line profile to a gaussian fit starting from the local max and growing out until the fit becomes poor
		
		v2.2.1 140224-5
			1. Restored using line width of whatever current line width is used when macro is called
			2. Added option to use a linear fit of line profile to help correct for differences in the shoulder of the profile. 
				This seems to improve robustness for fitting assymetrical peaks
			3. changed method of selecting best fitted line:
				added crtieria to weight the contributions of :
				(i) (1-R^2) for fit
				(ii) absolute change in FWHM to avoid itterations with unstable calculation of FWHM, while being agnostic to actual FWHM
				(iii) offset between fitted center and local peak is penalized slightly
				(iv) fits that calculate a negative baseline are severaly penalized
		
			to do: work on localizing fitted max wrt local max wrt trigonometry
				- still have to flush out whether differential number of plots makes sense for even vs odd # of pixels. 
				- would make more sense to center on fitted peak???
		
		v2.3.0 switched method so that only 1 line profile is taken, and is subsampled to fit smaller lines. Gets around issue of floating 0 (center) pixel
			not really any faster. Local max still calculated from initial line fed to FWHM
		v2.3.1 - added minSubArrayWidth and maxPad to dialog
		
		*/
		
			tAA = getTime();
			img4FWHM = getTitle();
		
			//==== User defined options ====================================================================================
			plotResults = false;
			levelLine = true;
			//======================================================================================================
			// added 140225 v2.2.1 parameters for changing weights and thresholds of R2 for fit, change in FWHM, and dist of fitted center vs local peak
			//======================================================================================================
			/*
			oneMinusR2Max = 0.3;
			FWHMdeltaMax = 3;
			centerOffsetMax = 2.5;
			oneMinusR2Wt = 50;
			FWHMdeltaWt = 20;
			centerOffsetWt = 30;
			negBaselinePenalty = 1;
			negPeakPenalty = 5;
			minSubArrayWidth = 5;   // need to get from function call
			maxPad = 19;                   // need to get from function call
		
			*/
			//======================================================================================================
		
			// ==== get line parameters ============================== 
			getLine(x1, y1, x2, y2, lineWidth);
			
			//print("\\Update20: FWHM line XYs " + x1 + " " + y1 + " " + x2 + " " + y2);
			
			x1=x1; x2=x2; y1=y1; y2=y2; lineWidth = lineWidth;
			theta = (180/PI) * atan2( (y1-y2),(x2-x1) ); // returns angle in range of -180 to 180
			run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
		
			resultsArray = newArray(7);    // bestFitx, bestFity, bestFWHM, bestR2, bestHeight, bestBaseline, localMaxValue	
		
			// find position on line of local max
			lineWidthForFWHM = lineWidth;					//v4.7.1.2
			makeLine(x1, y1, x2, y2, lineWidthForFWHM); // set to 2px to average a bit         //v4.7.1.2   test wider line
			Ys =getProfile();
			Array.getStatistics(Ys, min, max, mean, stdDev);
			localMaxValue = max;      // referring to amplitude on initial line
			maxLinePosition = 0;     // referring to index on initial line
			for (i=0; i<Ys.length; i++) {
				if (Ys[i] == localMaxValue) maxLinePosition =  i;
				if (i>0) {
					if( (Ys[i-1]== localMaxValue) && (Ys[i] == localMaxValue)) maxLinePosition = i-0.5;
				}
			}
			
			//===== make new line from theta, local max and 2x length of distance from local max to edge of original trace ==================
			//initlineLength = sqrt( pow((x1 - x2),2) + pow((y1-y2),2));
			localMaxX = x1+ cos( theta * PI / 180)*maxLinePosition;
			localMaxY = y1 - sin( theta * PI / 180)*maxLinePosition;
			lineLength = maxOf( 2*maxLinePosition, 2*(Ys.length - maxLinePosition) );   
			pad = 0;
		
			//===== calc Gaussian fit of peak with increasing line lengths and hold parameters in arrays
			r2Array = newArray(50);
			FWHMArray = Array.copy(r2Array);
			fittedCenters = Array.copy(r2Array);
			fittedHeights = Array.copy(r2Array);
			fittedBaselines = Array.copy(r2Array);
			fitIndex = Array.copy(r2Array);  // product of r2 and FWHM
			FWHMpctChange = Array.copy(r2Array);
		
			runs = 0;
		
			// v2.3.0 only grab line profile once, at max line length, then just fit subSamples of that profile
			jj = minSubArrayWidth + maxPad -1;
			FWHMLineX1 = localMaxX - cos( theta * PI / 180)*(  jj / 2);
			FWHMLineX2 = localMaxX + cos( theta * PI / 180)*(  jj / 2);
			FWHMLineY1 =  localMaxY + sin( theta * PI / 180)*(  jj / 2);
			FWHMLineY2 =  localMaxY  - sin( theta * PI / 180)*(  jj / 2);
			makeLine(FWHMLineX1, FWHMLineY1, FWHMLineX2, FWHMLineY2, lineWidth);
			FWHMYs =getProfile();
			FWHMleveledYs = newArray(FWHMYs.length);
			FWHMXs = newArray(FWHMYs.length);

			// v6.1.0.5: 170808: because the line is always the center +/- an integer, the length should alwys by odd (seems so in testing) 
			if(FWHMXs.length%2==0) {
				for ( i=0; i<FWHMXs.length; i++) {
					FWHMXs[i] =  i - ( (FWHMXs.length / 2) + (FWHMXs.length%2) )  ;             //%%%%% check this as a source of error
				}
			}
			// added in v2.2
			// ===== FIT straight line to removal uneven shoulders ================================
			Fit.doFit("Straight Line", FWHMXs, FWHMYs);
				for ( i=0; i<FWHMXs.length; i++) {
					FWHMleveledYs[i] = FWHMYs[i] - (Fit.p(1)*i);
					FWHMXs[i] =  i - (jj-1) / 2;
				}
		
			for (j = minSubArrayWidth; j < (minSubArrayWidth + maxPad) ;j++) {
				// changed in v2.2 to simply be half of dist from local center,centered on peak pixel
				// ===== store results of fit and complementary metrics in arrays indexed by itteration =================
		
				start = ( (FWHMXs.length / 2) + (FWHMXs.length%2) )  - floor(j/2);
				end = start + j;
				XsToFit = Array.slice(FWHMXs,start,end);
				if (levelLine == false ) YsToFit = Array.slice(FWHMYs,start,end);
				if (levelLine == true ) YsToFitLeveled = Array.slice(FWHMleveledYs,start,end);
		
				// ===== FIT line profile to gaussian ================================
				if (levelLine == false ) Fit.doFit("Gaussian", XsToFit, YsToFit);   
				if (levelLine == true ) Fit.doFit("Gaussian", XsToFit, YsToFitLeveled);   // new in v2.2   
		
				r2Array[ runs ] = Fit.rSquared;
				FWHMArray[ runs ] = 2.35482 * Fit.p(3);
				fittedBaselines[ runs ] = Fit.p(0);
				fittedHeights[ runs ] = Fit.p(1);
				fittedCenters[ runs ] = Fit.p(2);
		
				if (runs ==0) FWHMpctChange[runs] = 0;
				if (runs >0) FWHMpctChange[runs] = abs( 100 * ( FWHMArray[ runs ] - FWHMArray[ runs -1] ) / FWHMArray[ runs ] );
		
				selectWindow(img4FWHM);
				runs = runs +1;  		// ===== "runs" is a shorthand for itteration, j increases by 2 each round. This minimizes setting line lengths as half pixels
				j=j+1;
			}	
		
				// ======== added 140225 v2.2.1 changed best fit criteria to include offset and weight optimized =============================
				for (k = 0; k < runs; k++) {
					k2 = k+1;
					if (k == runs-1) k2= k-1;
					negBaseline = 1;
					negPeak = 1;
					if( fittedBaselines[ k ] < 0) negBaseline = negBaselinePenalty;
					if( (fittedHeights[ k ] - fittedBaselines[ k ]) < 0) negPeak = negPeakPenalty;
		
		 			fitIndex[ k ] = negBaseline * negPeak * 
						       ( oneMinusR2Wt / oneMinusR2Max) * (1-Fit.rSquared) +
					                      ( FWHMdeltaWt / FWHMdeltaMax) * abs(FWHMArray[ k ] - FWHMArray[ k2 ] ) +
					                      ( centerOffsetWt / centerOffsetMax)  * pow(abs( Fit.p(2)),2) ;                   //v2.2 incorporate a bonus for minimizing diff bw local peak and fitted peak1
				}
		
		
			// trim large inititial holder arrays to number of itterations
			r2Array = Array.trim(r2Array, runs);
			FWHMArray = Array.trim(FWHMArray, runs);
			fittedCenters = Array.trim(fittedCenters, runs);	
			fittedHeights = Array.trim(fittedHeights, runs);
			fittedBaselines = Array.trim(fittedBaselines, runs);
			fitIndex = Array.trim(fitIndex, runs);
			FWHMpctChange = Array.trim(FWHMpctChange, runs);
		
		
			if (plotResults == true) {
			
				// plot results of fits over # of itterations to see how things went
		
				Array.getStatistics(r2Array, min, max, mean, stdDev);
				minR2 = min;
				maxR2 = max;
				Array.getStatistics(FWHMArray, min, max, mean, stdDev);
				minFWHM = min;
				maxFWHM = max;
		
				Array.getStatistics(fitIndex, min, max, mean, stdDev);
				maxFitIndex = max;
				Plot.create("fit Index by itteration", "itteration", "10*(1-r^2) * FWHM");
				Plot.setFrameSize(256, 256);
				//plotH = minOf(maxFitIndex+1, 100);
				plotH = 50;
				Plot.setLimits(0, r2Array.length, 0, plotH);
				Plot.setColor("magenta");
		        		Plot.add("line", fitIndex);
				Plot.setColor("magenta");
		        		Plot.add("circles", fitIndex);
				Plot.show();
		
				Plot.create("FWHM fits", "R2", "FWHM", r2Array,FWHMArray);
				Plot.setFrameSize(256, 256);
				plotH = minOf(maxFWHM+2, 60);
				Plot.setLimits(minR2-0.005, 1, 0, plotH+1);
				Plot.setColor("white");
			        	Plot.add("line", r2Array,FWHMArray);
				Plot.setColor("green");
			        	Plot.add("circles", r2Array,FWHMArray);
				Plot.show();
		
			} //close if (plotResults == true)
		
			// OLD APPROACH AS OF v2.2.1 ======= determine best fit itteration by minimizing %difference between fits, also check that FWHM < 2X line length =======
			//   previous approach simply looked for minimal change in FWHM, did not optimize for fit or any other factor. Probably error prone
			// ==== v2.2.1 ==== optimize for balance of good fit, small change in FWHM, small diff bw peak and fitted center, and avoid negative baseline
		
			bestRun = 0;
			bestFWHM = 0;	 bestR2 = 0;   bestHeigh = 0;   bestBaseline = 0; bestFitX = 0;   bestFitY = 0;
			//rankPosArr = Array.rankPositions(FWHMpctChange);
			rankPosArr = Array.rankPositions(fitIndex);
			ranks = Array.rankPositions(rankPosArr);
			bestFound = false;
			bestRun = -1;
		
			// ===== many changes bw v2.2.1 and v2.1 ===================================
			for (i=0; i<FWHMpctChange.length; i++) {
				for (j=0; j<FWHMpctChange.length; j++) {
					if (ranks[j] == i) {
		
						// verify that any metrics pass criteria. Only assess starting on 
						if ( (FWHMArray[j] < 2*(minSubArrayWidth + maxPad) ) && (FWHMArray[j] > 0)   ) {     // additional criteria could be added here
							bestRun = j;
							bestR2 = r2Array[bestRun];

							bestHeight = fittedHeights[bestRun];
							bestBaseline = fittedCenters[bestRun];
				
							// v2.2.1 - need to verify this calculation is optimal. Might make more sense to ref start of line used for that run. less potential error
							bestFWHM = FWHMArray[bestRun];		
							bestFitX = localMaxX + cos( theta * PI / 180)*( fittedCenters[bestRun]) ;
							bestFitY = localMaxY - sin( theta * PI / 180)*( fittedCenters[bestRun]) ;
							


							bestCenter2LocalMax = fittedCenters[bestRun];
							i = FWHMpctChange.length -1;   //skip other itterations of i-loop
							j = FWHMpctChange.length -1;
							bestFound = true;
						
						}
					}
				}
			}
		
			if (bestFound == false) {
					bestRun = j;
					bestR2 = 0;
					bestFWHM = 0;
					bestHeight = 0;
					bestBaseline = 0;
					bestFitX = localMaxX;
					bestFitY = localMaxY;
					bestCenter2LocalMax = 0;
			}
		
			// Fill results Array with: bestFitx, bestFity, bestFWHM, bestR2, bestHeight, bestBaseline
			resultsArray[0]= bestFitX; 	
			resultsArray[1]= bestFitY; 	
			resultsArray[2] = bestFWHM;
			resultsArray[3]= bestR2;
		 	resultsArray[4]= bestHeight;
			resultsArray[5]= bestCenter2LocalMax;
			resultsArray[6]= localMaxValue;
	
			return resultsArray;
		
		} // close fxn FWHM
		

function fit_gaussian_diag_cov(wid,hei,x,o,out){

// described here - http://www.biii.eu/2d-gaussian-fitting-macro-fijiimagej-multiple-signals


//Get the statistics from the array.
Array.getStatistics(o, min, max, mean, stdDev);

//2D Gaussian equation.
g =   "y =(a-f)*exp(-(b*(pow(((x-(floor(x/"+wid+")*"+wid+"))-c),2))+d*pow(((floor(x/"+wid+"))-e),2)))+f";

Fit.doFit(g, x, o,newArray(max-min,0.1,wid/2,0.1,hei/2,min));
Fit.plot();

a = Fit.p(0); //A
b = 2.35482 * wid*Fit.p(1);  //a
c = Fit.p(2); //x0
d = 2.35482 * hei*Fit.p(3);//b
e = Fit.p(4); //y0
f = Fit.p(5); //baseline

//Whether to plot data or not.
if (out == true){
//Fit.plot();
newImage("out", "32-bit black", wid,hei,1);
x = 0;
for(j=0;j<hei;j++){
	for(i=0;i<wid;i++){
	in = Fit.f(x);   
	setPixel(i,j,in);
	x = x+1;
  	}}
resetMinAndMax();
}
return newArray(a,b,c,d,e,f)
}


//The MIT License (MIT)

//Copyright (c) 2016 Dominic Waithe

//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:

//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.

//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.	
		
	
function guessROIString(imgFolder, roisC1,roisC3,roisC3) {

	imgName = "";
	imgListA = getFileList(imgFolder);
	imgListA = Array.sort(imgListA);
	rc1List = getFileList(roisC1);
	rc1List = Array.sort(rc1List);
	rc2List = getFileList(roisC2);
	rc2List = Array.sort(rc2List);
	if (sliceQuerry2=="0")  matchArray = newArray(0,0);
	if (sliceQuerry2!="0") {
		rc3List = getFileList(roisC3);
		rc3List = Array.sort(rc3List);
		matchArray = newArray(0,0,0);
	}

	for ( i =0; i< imgListA.length; i++) {
		if ( endsWith(imgListA[i], imgType) == true) {
			imgName = imgListA[i];
			imgName1 = substring(imgName,0,lastIndexOf(imgName,"."));

			for (j = 0; j<rc1List.length;j++) {
				if ( ( endsWith(rc1List[j], ".zip") == true) && (indexOf(rc1List[j], imgName1)!=-1 )) {
					refROIsUniqueString = substring(rc1List[j], indexOf(rc1List[j],imgName1)+lengthOf(imgName1),lengthOf(rc1List[j])-4);
					//refROIsUniqueString = replace(rc1List[j],imgName1,"");
					//refROIsUniqueString = replace(refROIsUniqueString,".zip","");
					matchArray[0] = 1;
				}	
			}
			for (k = 0; k<rc2List.length;k++) {
				if ( ( endsWith(rc2List[k], ".zip") == true) && (indexOf(rc2List[k], imgName1)!=-1 )) {
					NN1ROIsUniqueString = substring(rc2List[k], indexOf(rc2List[k],imgName1)+lengthOf(imgName1),lengthOf(rc2List[k])-4);
					//NN1ROIsUniqueString = replace(rc2List[k],imgName1,"");
					//NN1ROIsUniqueString = replace(NN1ROIsUniqueString,".zip","");
					matchArray[1] = 1;
				}	
			}
			if (sliceQuerry2!="0") {
				for (l = 0; l<rc3List.length;l++) {
					if ( ( endsWith(rc3List[l], ".zip") == true) && (indexOf(rc3List[l], imgName1)!=-1 )) {
						NN2ROIsUniqueString = substring(rc3List[l], indexOf(rc3List[l],imgName1)+lengthOf(imgName1),lengthOf(rc3List[l])-4);
						//NN2ROIsUniqueString = replace(rc3List[l],imgName1,"");
						//NN2ROIsUniqueString = replace(NN2ROIsUniqueString,".zip","");
						matchArray[2] = 1;
					}	
				}
			}
			Array.getStatistics(matchArray,min, max, mean, stdDev);
			if (min==1) i = imgListA.length;
	
		}
	}
	returnedGuesses = newArray(imgName1,refROIsUniqueString,NN1ROIsUniqueString,NN2ROIsUniqueString);

	
	return returnedGuesses;
			
}
		
