RequireVersion("2.3");

/*------------------------------------------------------------------------------
    Load library files
*/

LoadFunctionLibrary("libv3/UtilityFunctions.bf");
LoadFunctionLibrary("libv3/IOFunctions.bf");
LoadFunctionLibrary("libv3/stats.bf");
LoadFunctionLibrary("libv3/terms-json.bf");

LoadFunctionLibrary("libv3/tasks/ancestral.bf");
LoadFunctionLibrary("libv3/tasks/alignments.bf");
LoadFunctionLibrary("libv3/tasks/estimators.bf");
LoadFunctionLibrary("libv3/tasks/trees.bf");
LoadFunctionLibrary("libv3/tasks/mpi.bf");

LoadFunctionLibrary("libv3/models/codon/BS_REL.bf");

LoadFunctionLibrary("libv3/convenience/math.bf");

LoadFunctionLibrary("modules/io_functions.ibf");


/*------------------------------------------------------------------------------ Display analysis information
*/

io.DisplayAnalysisBanner({
    "info": "MEME (Mixed Effects Model of Evolution)
    estimates a site-wise synonymous (&alpha;) and a two-category mixture of non-synonymous
    (&beta;-, with proportion p-, and &beta;+ with proportion [1-p-]) rates, and
    uses a likelihood ratio test to determine if &beta;+ > &alpha; at a site.
    The estimates aggregate information over a proportion of branches at a site,
    so the signal is derived from
    episodic diversification, which is a combination of strength of selection [effect size] and
    the proportion of the tree affected. A subset of branches can be selected
    for testing as well, in which case an additional (nuisance) parameter will be
    inferred -- the non-synonymous rate on branches NOT selected for testing. Multiple partitions within a NEXUS file are also supported
    for recombination - aware analysis.
    ",
    "version": "2.00",
    "reference": "Detecting Individual Sites Subject to Episodic Diversifying Selection. _PLoS Genet_ 8(7): e1002764.",
    "authors": "Sergei L. Kosakovsky Pond, Steven Weaver",
    "contact": "spond@temple.edu",
    "requirements": "in-frame codon alignment and a phylogenetic tree"
});



/*------------------------------------------------------------------------------
    Environment setup
*/

utility.SetEnvVariable ("NORMALIZE_SEQUENCE_NAMES", TRUE);

/*------------------------------------------------------------------------------
    Globals
*/



meme.terms.site_alpha = "Site relative synonymous rate";
meme.terms.site_omega_minus = "Omega ratio on (tested branches); negative selection or neutral evolution (&omega;- <= 1;)";
meme.terms.site_beta_minus = "Site relative non-synonymous rate (tested branches); negative selection or neutral evolution (&beta;- <= &alpha;)";
meme.terms.site_beta_plus = "Site relative non-synonymous rate (tested branches); unconstrained";
meme.terms.site_mixture_weight = "Beta- category weight";
meme.terms.site_beta_nuisance = "Site relative non-synonymous rate (untested branches)";

meme.pvalue = 0.1;
    /**
        default cutoff for printing to screen
    */

meme.json = {
    terms.json.fits: {},
    terms.json.timers: {},
};
    /**
        The dictionary of results to be written to JSON at the end of the run
    */

selection.io.startTimer (meme.json [terms.json.timers], "Total time", 0);
meme.scaler_prefix = "MEME.scaler";

meme.table_headers = {{"&alpha;", "Synonymous substitution rate at a site"}
                     {"&beta;<sup>-</sup>", "Non-synonymous substitution rate at a site for the negative/neutral evolution component"}
                     {"p<sup>-</sup>", "Mixture distribution weight allocated to &beta;<sup>-</sup>; loosely -- the proportion of the tree evolving neutrally or under negative selection"}
                     {"&beta;<sup>+</sup>", "Non-synonymous substitution rate at a site for the positive/neutral evolution component"}
                     {"p<sup>+</sup>", "Mixture distribution weight allocated to &beta;<sup>+</sup>; loosely -- the proportion of the tree evolving neutrally or under positive selection"}
                     {"LRT", "Likelihood ratio test statistic for episodic diversification, i.e., p<sup>+</sup> &gt; 0 <emph>and<emph> &beta;<sup>+</sup> &gt; &alpha;"}
                     {"p-value", "Asymptotic p-value for for episodic diversification, i.e., p<sup>+</sup> &gt; 0 <emph>and<emph> &beta;<sup>+</sup> &gt; &alpha;"}
                     {"Total branch length", "The total length of branches contributing to inference at this site, and used to scale dN-dS"}};
/**
    This table is meant for HTML rendering in the results web-app; can use HTML characters, the second column
    is 'pop-over' explanation of terms. This is ONLY saved to the JSON file. For Markdown screen output see
    the next set of variables.
*/



meme.table_screen_output  = {{"Codon", "Partition", "alpha", "beta+", "p+", "LRT", "Selection detected?"}};
meme.table_output_options = {"header" : TRUE, "min-column-width" : 16, "align" : "center"};

namespace meme {
    LoadFunctionLibrary ("modules/shared-load-file.bf");
    load_file ("meme");
}

/**
    TODO: Need to document what variables are available after call to load_file
*/


meme.partition_count = Abs (meme.filter_specification);
meme.pvalue  = io.PromptUser ("\n>Select the p-value used to for perform the test at",meme.pvalue,0,1,FALSE);
io.ReportProgressMessageMD('MEME',  'selector', 'Branches to include in the MEME analysis');

utility.ForEachPair (meme.selected_branches, "_partition_", "_selection_",
    "_selection_ = utility.Filter (_selection_, '_value_', '_value_ == terms.json.attribute.test');
     io.ReportProgressMessageMD('MEME',  'selector', 'Selected ' + Abs(_selection_) + ' branches to include in the MEME analysis: \\\`' + Join (', ',utility.Keys(_selection_)) + '\\\`')");


selection.io.startTimer (meme.json [terms.json.timers], "Model fitting",1);

namespace meme {
    doGTR ("meme");
}


estimators.fixSubsetOfEstimates(meme.gtr_results, meme.gtr_results["global"]);

namespace meme {
    doPartitionedMG ("meme", FALSE);
}


io.ReportProgressMessageMD ("MEME", "codon-refit", "Improving branch lengths, nucleotide substitution biases, and global dN/dS ratios under a full codon model");

meme.final_partitioned_mg_results = estimators.FitMGREV (meme.filter_names, meme.trees, meme.codon_data_info ["code"], {
    "model-type": terms.global,
    "partitioned-omega": meme.selected_branches,
    "retain-lf-object": TRUE
}, meme.partitioned_mg_results);

io.ReportProgressMessageMD("MEME", "codon-refit", "* Log(L) = " + Format(meme.final_partitioned_mg_results["LogL"],8,2));
meme.global_dnds = selection.io.extract_global_MLE_re (meme.final_partitioned_mg_results, "^" + terms.omega_ratio);
utility.ForEach (meme.global_dnds, "_value_", 'io.ReportProgressMessageMD ("MEME", "codon-refit", "* " + _value_["description"] + " = " + Format (_value_["MLE"],8,4));');

estimators.fixSubsetOfEstimates(meme.final_partitioned_mg_results, meme.final_partitioned_mg_results["global"]);

selection.io.json_store_lf(
    meme.json,
    "Global MG94xREV",
    meme.final_partitioned_mg_results["LogL"],
    meme.final_partitioned_mg_results["parameters"],
    meme.sample_size,
    utility.ArrayToDict (utility.Map (meme.global_dnds, "_value_", "{'key': _value_['description'], 'value' : Eval({{_value_ ['MLE'],1}})}"))
);

utility.ForEachPair (meme.filter_specification, "_key_", "_value_",
    'selection.io.json_store_branch_attribute(meme.json, "Global MG94xREV model", terms.json.attribute.branch_length, 0,
                                             _key_,
                                             selection.io.extract_branch_info((meme.final_partitioned_mg_results[terms.json.attribute.branch_length])[_key_], "selection.io.branch.length"));');

selection.io.stopTimer (meme.json [terms.json.timers], "Model fitting");

// define the site-level likelihood function

meme.site.background_fel = model.generic.DefineModel("models.codon.MG_REV.ModelDescription",
        "meme.background_fel", {
            "0": parameters.Quote(terms.local),
            "1": meme.codon_data_info["code"]
        },
        meme.filter_names,
        None);

meme.alpha = model.generic.GetLocalParameter (meme.site.background_fel, terms.synonymous_rate);
meme.beta  = model.generic.GetLocalParameter (meme.site.background_fel, terms.nonsynonymous_rate);

io.CheckAssertion ("None!=meme.alpha && None!=meme.beta", "Could not find expected local synonymous and non-synonymous rate parameters in \`estimators.FitMGREV\`");

meme.site.bsrel =  model.generic.DefineMixtureModel("models.codon.BS_REL_Per_Branch_Mixing.ModelDescription",
        "meme.bsrel", {
            "0": parameters.Quote(terms.local),
            "1": meme.codon_data_info["code"],
            "2": parameters.Quote (2) // the number of rate classes
        },
        meme.filter_names,
        None);
        


meme.beta1  = model.generic.GetLocalParameter (meme.site.bsrel , terms.AddCategory (terms.nonsynonymous_rate,1));
meme.beta2  = model.generic.GetLocalParameter (meme.site.bsrel , terms.AddCategory (terms.nonsynonymous_rate,2));
meme.branch_mixture = model.generic.GetLocalParameter (meme.site.bsrel , terms.AddCategory (terms.mixture_aux_weight,1));

io.CheckAssertion ("None!=meme.beta2&&None!=meme.beta1&&None!=meme.branch_mixture", "Could not find expected local rate and mixture parameters for the BS-REL model");

meme.site_model_mapping = {
                           "meme.background_fel" : meme.site.background_fel,
                           "meme.bsrel" : meme.site.bsrel,
                          };


selection.io.startTimer (meme.json [terms.json.timers], "MEME analysis", 2);


model.generic.AddGlobal (meme.site.background_fel, "meme.site_alpha", meme.terms.site_alpha);
parameters.DeclareGlobal ("meme.site_alpha", {});

model.generic.AddGlobal (meme.site.background_fel, "meme.site_beta_nuisance", meme.terms.site_beta_nuisance);
parameters.DeclareGlobal ("meme.site_beta_nuisance", {});

model.generic.AddGlobal (meme.site.bsrel, "meme.site_alpha", meme.terms.site_alpha);
model.generic.AddGlobal (meme.site.bsrel, "meme.site_omega_minus", meme.terms.site_omega_minus);
parameters.DeclareGlobal ("meme.site_omega_minus", {});
parameters.SetRange ("meme.site_omega_minus", terms.range01);

model.generic.AddGlobal (meme.site.bsrel, "meme.site_beta_minus", meme.terms.site_beta_minus);
parameters.DeclareGlobal ("meme.site_beta_minus", {});
parameters.SetConstraint ("meme.site_beta_minus", "meme.site_alpha * meme.site_omega_minus", "");

model.generic.AddGlobal (meme.site.bsrel, "meme.site_beta_plus", meme.terms.site_beta_plus);
parameters.DeclareGlobal ("meme.site_beta_plus", {});

model.generic.AddGlobal  (meme.site.bsrel, "meme.site_mixture_weight", meme.terms.site_mixture_weight);
parameters.DeclareGlobal ("meme.site_mixture_weight", {});
parameters.SetRange ("meme.site_mixture_weight", terms.range01);


meme.report.count       = {{0}};

meme.table_screen_output  = {{"Codon", "Partition", "alpha", "beta+", "p+", "LRT", "Selection detected?"}};

meme.report.positive_site = {{"" + (1+((meme.filter_specification[meme.report.partition])["coverage"])[meme.report.site]),
                                    meme.report.partition + 1,
                                    Format(meme.report.row[0],10,3),
                                    Format(meme.report.row[3],10,3),
                                    Format(meme.report.row[4],10,3),
                                    Format(meme.report.row[5],10,3),
                                    "Yes, p = " + Format(meme.report.row[6],7,4)}};



meme.site_results = {};

for (meme.partition_index = 0; meme.partition_index < meme.partition_count; meme.partition_index += 1) {
    meme.report.header_done = FALSE;
    meme.table_output_options["header"] = TRUE;
    
    meme.model_to_branch_bsrel = { "meme.bsrel" : utility.Filter (meme.selected_branches[meme.partition_index], '_value_', '_value_ == terms.json.attribute.test'),
					         "meme.background_fel" : utility.Filter (meme.selected_branches[meme.partition_index], '_value_', '_value_ != terms.json.attribute.test')};

 			
    model.ApplyModelToTree( "meme.site_tree_fel", meme.trees[meme.partition_index], {"default" : meme.site.background_fel}, None);
    model.ApplyModelToTree( "meme.site_tree_bsrel", meme.trees[meme.partition_index], None, meme.model_to_branch_bsrel);

    meme.site_patterns = alignments.Extract_site_patterns ((meme.filter_specification[meme.partition_index])["name"]);

    utility.ForEach (meme.site_tree_fel, "_node_",
            '_node_class_ = (meme.selected_branches[meme.partition_index])[_node_];
             if (_node_class_ != "test") {
                _beta_scaler = "meme.site_beta_nuisance";
				meme.apply_proportional_site_constraint.fel ("meme.site_tree_bsrel", _node_, 
					meme.alpha, meme.beta, "meme.site_alpha", _beta_scaler, (( meme.final_partitioned_mg_results[terms.json.attribute.branch_length])[meme.partition_index])[_node_]);
            } else {
                _beta_scaler = "meme.site_beta_plus";
				meme.apply_proportional_site_constraint.bsrel ("meme.site_tree_bsrel", _node_, 
					meme.alpha,  meme.beta1, meme.beta2, meme.branch_mixture, "meme.site_alpha", "meme.site_omega_minus", 
					_beta_scaler, "meme.site_mixture_weight", (( meme.final_partitioned_mg_results[terms.json.attribute.branch_length])[meme.partition_index])[_node_]);
             }
             meme.apply_proportional_site_constraint.fel ("meme.site_tree_fel", _node_, 
             	meme.alpha, meme.beta, "meme.site_alpha", _beta_scaler, (( meme.final_partitioned_mg_results[terms.json.attribute.branch_length])[meme.partition_index])[_node_]);
        ');



	
    // create the likelihood function for this site

    ExecuteCommands (alignments.serialize_site_filter
                                       ((meme.filter_specification[meme.partition_index])["name"],
                                       ((meme.site_patterns[0])["sites"])[0],
                     ));

    __make_filter ("meme.site_filter");
    
    LikelihoodFunction meme.site_likelihood = (meme.site_filter, meme.site_tree_fel);

    __make_filter ("meme.site_filter_bsrel");


    estimators.ApplyExistingEstimates ("meme.site_likelihood", meme.site_model_mapping, meme.final_partitioned_mg_results,
                                        "globals only");


    LikelihoodFunction meme.site_likelihood_bsrel = (meme.site_filter_bsrel, meme.site_tree_bsrel);
    

    estimators.ApplyExistingEstimates ("meme.site_likelihood_bsrel", meme.site_model_mapping, meme.final_partitioned_mg_results,
                                        "globals only");

    meme.queue = mpi.CreateQueue ({"LikelihoodFunctions": {{"meme.site_likelihood","meme.site_likelihood_bsrel"}},
                                   "Models" : {{"meme.site.background_fel","meme.site.bsrel"}},
                                   "Headers" : {{"libv3/terms-json.bf"}},
                                   "Variables" : {{"meme.selected_branches"}}
                                 });

    /* run the main loop over all unique site pattern combinations */
    utility.ForEachPair (meme.site_patterns, "_pattern_", "_pattern_info_",
        '
            if (_pattern_info_["is_constant"]) {
                meme.store_results (-1,None,{"0" : "meme.site_likelihood",
                							 "1" : "meme.site_likelihood_bsrel",
											 "2" : None,
											 "3" : meme.partition_index,
											 "4" : _pattern_info_,
											 "5" : meme.site_model_mapping
                                     });
            } else {
                mpi.QueueJob (meme.queue, "meme.handle_a_site", {"0" : "meme.site_likelihood",
                												 "1" : "meme.site_likelihood_bsrel",
                                                                 "2" : alignments.serialize_site_filter
                                                                   ((meme.filter_specification[meme.partition_index])["name"],
                                                                   (_pattern_info_["sites"])[0]),
																 "3" : meme.partition_index,
																 "4" : _pattern_info_,
																 "5" : meme.site_model_mapping
																	},
																	"meme.store_results");
            }
        '
    );

    mpi.QueueComplete (meme.queue);
    meme.partition_matrix = {Abs (meme.site_results[meme.partition_index]), Rows (meme.table_headers)};

    utility.ForEachPair (meme.site_results[meme.partition_index], "_key_", "_value_",
    '
        for (meme.index = 0; meme.index < Rows (meme.table_headers); meme.index += 1) {
            meme.partition_matrix [0+_key_][meme.index] = _value_[meme.index];
        }
    '
    );

    meme.site_results[meme.partition_index] = meme.partition_matrix;


}

meme.json [terms.json.MLE ] = {terms.json.headers   : meme.table_headers,
                               terms.json.content : meme.site_results };


io.ReportProgressMessageMD ("MEME", "results", "** Found _" + meme.report.count[0] + "_ sites under positive at p <= " + meme.pvalue + "**");

selection.io.stopTimer (meme.json [terms.json.timers], "Total time");
selection.io.stopTimer (meme.json [terms.json.timers], "MEME analysis");

io.SpoolJSON (meme.json, meme.codon_data_info["json"]);

//----------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------

function meme.apply_proportional_site_constraint.fel (tree_name, node_name, alpha_parameter, beta_parameter, alpha_factor, beta_factor, branch_length) {

    meme.branch_length = (branch_length[terms.synonymous_rate])[terms.MLE];

    node_name = tree_name + "." + node_name;

    ExecuteCommands ("
        `node_name`.`alpha_parameter` := (`alpha_factor`) * meme.branch_length__;
        `node_name`.`beta_parameter`  := (`beta_factor`)  * meme.branch_length__;
    ");
}
//----------------------------------------------------------------------------------------

function meme.apply_proportional_site_constraint.bsrel (tree_name, node_name, alpha_parameter, beta_parameter, beta_parameter2, mixture_parameter, alpha_factor, omega_factor, beta_factor, mixture_global, branch_length) {

    meme.branch_length = (branch_length[terms.synonymous_rate])[terms.MLE];

    node_name = tree_name + "." + node_name;

    ExecuteCommands ("
        `node_name`.`alpha_parameter` := (`alpha_factor`) * meme.branch_length__;
        `node_name`.`beta_parameter`  := (`omega_factor`)  * `node_name`.`alpha_parameter`;
        `node_name`.`beta_parameter2`  := (`beta_factor`)  * meme.branch_length__;
        `node_name`.`mixture_parameter`  := `mixture_global`;
    ");
}

//----------------------------------------------------------------------------------------
lfunction meme.compute_branch_EBF (lf_id, tree_name, branch_name, baseline) {
// TODO: figure out why LFCompute fails if this is run as an `lfunction`

	parameter_name = "`tree_name`.`branch_name`." + ^"meme.branch_mixture";
	^parameter_name = 1;
	LFCompute (^lf_id,LOGL0);
				
	ExecuteCommands (parameter_name + ":= meme.site_mixture_weight", enclosing_namespace);

	if (^"meme.site_mixture_weight" != 1 && ^"meme.site_mixture_weight" != 0) {
		_priorOdds = (1-^"meme.site_mixture_weight")/^"meme.site_mixture_weight";
	} else {
		_priorOdds = 0;
	}
        
	MaxL     = -Max (LOGL0,baseline);
	
	baseline += MaxL;
	LOGL0 = Exp(MaxL+LOGL0);
	LOGL1 = (Exp(baseline) - ^"meme.site_mixture_weight" * LOGL0) / (1-^"meme.site_mixture_weight");
	
	_posteriorProb = {{LOGL0 * ^"meme.site_mixture_weight", LOGL1 * (1-^"meme.site_mixture_weight")}};
	
	_posteriorProb = _posteriorProb * (1/(+_posteriorProb));
	if ( _priorOdds != 0) {
		eBF = _posteriorProb[1] / (1 - _posteriorProb[1]) / _priorOdds;
	} else {
		eBF = 1;
	}

	return {"BF" : eBF__, "posterior" : _posteriorProb__[1]};
}

//----------------------------------------------------------------------------------------
 lfunction meme.handle_a_site (lf_fel, lf_bsrel, filter_data, partition_index, pattern_info, model_mapping) {

    GetString   (lfInfo, ^lf_fel,-1);
    
    ExecuteCommands (filter_data);
    __make_filter ((lfInfo["Datafilters"])[0]);

    GetString (lfInfo, ^lf_bsrel,-1);
    __make_filter ((lfInfo["Datafilters"])[0]);
    
	bsrel_tree_id = (lfInfo["Trees"])[0];
	
    utility.SetEnvVariable ("USE_LAST_RESULTS", TRUE);

    ^"meme.site_alpha" = 1;
    ^"meme.site_beta_plus"  = 1;
    ^"meme.site_beta_nuisance"  = 1;

    Optimize (results, ^lf_fel);

    fel = estimators.ExtractMLEs (lf_fel, model_mapping);
    fel[utility.getGlobalValue("terms.json.log_likelihood")] = results[1][0];

 	^"meme.site_mixture_weight" = 0.75;
 	if (^"meme.site_alpha" > 0) {
 		^"meme.site_omega_minus" = 1;
 	} else {
 		^"meme.site_omega_minus" = ^"meme.site_beta_plus" / ^"meme.site_alpha";
 	}
    
	Optimize (results, ^lf_bsrel);
    alternative = estimators.ExtractMLEs (lf_bsrel, model_mapping);
    alternative [utility.getGlobalValue("terms.json.log_likelihood")] = results[1][0];

	
	branch_ebf       = {};
	branch_posterior = {};

	if (^"meme.site_beta_plus" > ^"meme.terms.site_alpha" && ^"meme.site_mixture_weight" > 0) {
		LFCompute (^lf_bsrel,LF_START_COMPUTE);

		utility.ForEach (^bsrel_tree_id, "_node_name_",
		'
			if ((meme.selected_branches [^"`&partition_index`"])[_node_name_]  == "test") {
				_node_name_res_ = meme.compute_branch_EBF (^"`&lf_bsrel`", ^"`&bsrel_tree_id`", _node_name_, (^"`&alternative`") [utility.getGlobalValue("terms.json.log_likelihood")]);
				(^"`&branch_ebf`")[_node_name_] = _node_name_res_["BF"];
				(^"`&branch_posterior`")[_node_name_] = _node_name_res_["posterior"];
			} else {
				(^"`&branch_ebf`")[_node_name_] = None;			
				(^"`&branch_posterior`")[_node_name_] = None;			
			}
		'
		);

		LFCompute (^lf_bsrel,LF_DONE_COMPUTE);

		^"meme.site_beta_plus" := ^"meme.site_alpha";
		Optimize (results, ^lf_bsrel);

		null = estimators.ExtractMLEs (lf_bsrel, model_mapping);
		null [utility.getGlobalValue("terms.json.log_likelihood")] = results[1][0];
		

		
	} else {
		null = alternative;
		utility.ForEach (^bsrel_tree_id, "_node_name_",
		'
			if ((meme.selected_branches [^"`&partition_index`"])[_node_name_]  == "test") {
				(^"`&branch_ebf`")[_node_name_] = 1.0;
				(^"`&branch_posterior`")[_node_name_] = 0.0;
			} else {
				(^"`&branch_ebf`")[_node_name_] = None;
				(^"`&branch_posterior`")[_node_name_] = None;
			}
		'
		);
	}
    
    console.log (branch_ebf);
    console.log (branch_posterior);
        

    return {"fel" : fel,
    		"alternative" : alternative, 
    		"null": null};
}

/* echo to screen calls */

//----------------------------------------------------------------------------------------
function meme.report.echo (meme.report.site, meme.report.partition, meme.report.row) {
    meme.print_row = None;
    if (meme.report.row [6] <= meme.pvalue) {
		meme.print_row = meme.report.positive_site;
		meme.report.count[0] += 1;
	}

     if (None != meme.print_row) {
            if (!meme.report.header_done) {
                io.ReportProgressMessageMD("MEME", "" + meme.report.partition, "For partition " + (meme.report.partition+1) + " these sites are significant at p <=" + meme.pvalue + "\n");
                fprintf (stdout,
                    io.FormatTableRow (meme.table_screen_output,meme.table_output_options));
                meme.report.header_done = TRUE;
                meme.table_output_options["header"] = FALSE;
            }

            fprintf (stdout,
                io.FormatTableRow (meme.print_row,meme.table_output_options));
        }

}

//----------------------------------------------------------------------------------------

lfunction meme.store_results (node, result, arguments) {

    partition_index = arguments [3];
    pattern_info    = arguments [4];

    result_row          = { { 0, // alpha
                          0, // beta-
                          1, // weight-
                          0, // beta +
                          0, // weight +
                          0, // LRT
                          1, // p-value,
                          0  // total branch length of tested branches
                      } };

    if (None != result) { // not a constant site
    
    	lrt = {"LRT" : 2*((result["alternative"])[utility.getGlobalValue("terms.json.log_likelihood")]-(result["null"])[utility.getGlobalValue("terms.json.log_likelihood")])};
    	lrt ["p-value"] = 2/3-2/3*(0.45*CChi2(lrt["LRT"],1)+0.55*CChi2(lrt["LRT"],2));
    	
        result_row [0] = estimators.GetGlobalMLE (result["alternative"], ^"meme.terms.site_alpha");
        result_row [1] = estimators.GetGlobalMLE (result["alternative"], ^"meme.terms.site_omega_minus") * result_row[0];
        result_row [2] = estimators.GetGlobalMLE (result["alternative"], ^"meme.terms.site_mixture_weight");
        result_row [3] = estimators.GetGlobalMLE (result["alternative"], ^"meme.terms.site_beta_plus");
        result_row [4] = 1-result_row [2];
        result_row [5] = lrt ["LRT"];
        result_row [6] = lrt ["p-value"];
        
        //console.log ((result["alternative"])[utility.getGlobalValue("terms.json.log_likelihood")]);

        sum = 0;
        alternative_lengths = ((result["alternative"])[^"terms.json.attribute.branch_length"])[0];

        utility.ForEach (^"meme.site_tree_fel", "_node_",
                '_node_class_ = ((^"meme.selected_branches")[`&partition_index`])[_node_];
                 if (_node_class_ == "test") {
                    `&sum` += ((`&alternative_lengths`)[_node_])[^"terms.json.MLE"];
                 }
            ');

        result_row [7] = sum;
	}

    utility.EnsureKey (^"meme.site_results", partition_index);

    utility.ForEach (pattern_info["sites"], "_value_",
        '
            (meme.site_results[`&partition_index`])[_value_] = `&result_row`;
            meme.report.echo (_value_, `&partition_index`, `&result_row`);
        '
    );


    //assert (0);
}