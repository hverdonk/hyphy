ExecuteAFile (PATH_TO_CURRENT_BF + "TestTools.ibf");
runATest ();


function getTestName () {
  return "GammaDist";
}		


function runTest () {
	ASSERTION_BEHAVIOR = 1; /* print warning to console and go to the end of the execution list */
	testResult = 0;
  

  //---------------------------------------------------------------------------------------------------------
  // SIMPLE FUNCTIONALITY
  //---------------------------------------------------------------------------------------------------------
  // Computes a point from the Gamma Distribution. GammaDist(x,a,b) a=shape, b=rate
  // grid = it.product( np.linspace(0, 5, 10), [1, 2, 3], [1, 2, 3] ) for x, a, b
  grid = {
    {1.000000, 1.000000, 1.000000}
    {1.000000, 1.000000, 2.000000}
    {1.000000, 1.000000, 3.000000}
    {1.000000, 2.000000, 1.000000}
    {1.000000, 2.000000, 2.000000}
    {1.000000, 2.000000, 3.000000}
    {1.000000, 3.000000, 1.000000}
    {1.000000, 3.000000, 2.000000}
    {1.000000, 3.000000, 3.000000}
    {1.444444, 1.000000, 1.000000}
    {1.444444, 1.000000, 2.000000}
    {1.444444, 1.000000, 3.000000}
    {1.444444, 2.000000, 1.000000}
    {1.444444, 2.000000, 2.000000}
    {1.444444, 2.000000, 3.000000}
    {1.444444, 3.000000, 1.000000}
    {1.444444, 3.000000, 2.000000}
    {1.444444, 3.000000, 3.000000}
    {1.888889, 1.000000, 1.000000}
    {1.888889, 1.000000, 2.000000}
    {1.888889, 1.000000, 3.000000}
    {1.888889, 2.000000, 1.000000}
    {1.888889, 2.000000, 2.000000}
    {1.888889, 2.000000, 3.000000}
    {1.888889, 3.000000, 1.000000}
    {1.888889, 3.000000, 2.000000}
    {1.888889, 3.000000, 3.000000}
    {2.333333, 1.000000, 1.000000}
    {2.333333, 1.000000, 2.000000}
    {2.333333, 1.000000, 3.000000}
    {2.333333, 2.000000, 1.000000}
    {2.333333, 2.000000, 2.000000}
    {2.333333, 2.000000, 3.000000}
    {2.333333, 3.000000, 1.000000}
    {2.333333, 3.000000, 2.000000}
    {2.333333, 3.000000, 3.000000}
    {2.777778, 1.000000, 1.000000}
    {2.777778, 1.000000, 2.000000}
    {2.777778, 1.000000, 3.000000}
    {2.777778, 2.000000, 1.000000}
    {2.777778, 2.000000, 2.000000}
    {2.777778, 2.000000, 3.000000}
    {2.777778, 3.000000, 1.000000}
    {2.777778, 3.000000, 2.000000}
    {2.777778, 3.000000, 3.000000}
    {3.222222, 1.000000, 1.000000}
    {3.222222, 1.000000, 2.000000}
    {3.222222, 1.000000, 3.000000}
    {3.222222, 2.000000, 1.000000}
    {3.222222, 2.000000, 2.000000}
    {3.222222, 2.000000, 3.000000}
    {3.222222, 3.000000, 1.000000}
    {3.222222, 3.000000, 2.000000}
    {3.222222, 3.000000, 3.000000}
    {3.666667, 1.000000, 1.000000}
    {3.666667, 1.000000, 2.000000}
    {3.666667, 1.000000, 3.000000}
    {3.666667, 2.000000, 1.000000}
    {3.666667, 2.000000, 2.000000}
    {3.666667, 2.000000, 3.000000}
    {3.666667, 3.000000, 1.000000}
    {3.666667, 3.000000, 2.000000}
    {3.666667, 3.000000, 3.000000}
    {4.111111, 1.000000, 1.000000}
    {4.111111, 1.000000, 2.000000}
    {4.111111, 1.000000, 3.000000}
    {4.111111, 2.000000, 1.000000}
    {4.111111, 2.000000, 2.000000}
    {4.111111, 2.000000, 3.000000}
    {4.111111, 3.000000, 1.000000}
    {4.111111, 3.000000, 2.000000}
    {4.111111, 3.000000, 3.000000}
    {4.555556, 1.000000, 1.000000}
    {4.555556, 1.000000, 2.000000}
    {4.555556, 1.000000, 3.000000}
    {4.555556, 2.000000, 1.000000}
    {4.555556, 2.000000, 2.000000}
    {4.555556, 2.000000, 3.000000}
    {4.555556, 3.000000, 1.000000}
    {4.555556, 3.000000, 2.000000}
    {4.555556, 3.000000, 3.000000}
    {5.000000, 1.000000, 1.000000}
    {5.000000, 1.000000, 2.000000}
    {5.000000, 1.000000, 3.000000}
    {5.000000, 2.000000, 1.000000}
    {5.000000, 2.000000, 2.000000}
    {5.000000, 2.000000, 3.000000}
    {5.000000, 3.000000, 1.000000}
    {5.000000, 3.000000, 2.000000}
    {5.000000, 3.000000, 3.000000}
  };

  // g = gamma(a, scale=1/b).pdf(x) (HyPhy parametrizes rate, SciPy parametrizes scale)
  g = {{
    0.36787944117144233, 0.2706705664732254, 0.14936120510359185, 0.36787944117144233, 0.5413411329464508 ,
    0.44808361531077556, 0.18393972058572114, 0.5413411329464508, 0.6721254229661633, 0.2358770829857 ,
    0.11127599655568562, 0.03937118621082287, 0.3407113420904556, 0.32146399004975845, 0.17060847358023246 ,
    0.24606930262088458, 0.46433687451631767, 0.36965169275717036, 0.15123975969049577, 0.04574692982247782 ,
    0.010378132009394275, 0.2856751016376031, 0.1728217348849162, 0.05880941471990088, 0.2698042626577363 ,
    0.3264410547826195, 0.1666266750397192, 0.0969719678644051, 0.018807125102990426, 0.0027356458966635512 ,
    0.22626792501694518, 0.08776658381395532, 0.01914952127664486, 0.2639792458531026, 0.2047886955658957 ,
    0.06702332446825698, 0.06217652402211632, 0.007731840278945615, 0.0007211084292585423, 0.17271256672810087 ,
    0.04295466821636452, 0.006009236910487851, 0.23987856490014003, 0.11931852282323478, 0.02503848712703271 ,
    0.039866367823724935, 0.0031786545669130616, 0.00019008211822367862, 0.12845829632089145, 0.02048466276455084 ,
    0.001837460476162227, 0.20696058851699176, 0.06600613557466382, 0.008881058968117432, 0.025561533206507402 ,
    0.0013067839597347612, 5.010510237073698e-05, 0.09372562175719383, 0.009583082371388248, 0.0005511561260781069 ,
    0.17183030655485532, 0.03513796869509024, 0.0030313586934295877, 0.016389553790213604, 0.0005372349468846101 ,
    1.3207561589921799e-05, 0.06737927669310036, 0.004417265118829016, 0.00016289325960903555, 0.1385018465358174 ,
    0.018159867710741507, 0.0010045084342557192, 0.01050866046540279, 0.00022086388955423918, 3.481475436590582e-06 ,
    0.04787278656461271, 0.0020123154381608468, 4.7580164300071285e-05, 0.10904356939717338, 0.009167214773843853 ,
    0.0003251311227171537, 0.006737946999085467, 9.079985952496971e-05, 9.177069615054774e-07, 0.03368973499542734 ,
    0.0009079985952496972, 1.3765604422582168e-05, 0.08422433748856832, 0.004539992976248487, 0.00010324203316936629 
  }};

  for(i=0; i<90; i=i+1) {
    x = grid[i][0];
    a = grid[i][1];
    b = grid[i][2];
    assert(Abs(g[i] - GammaDist(x,a,b)) < 1e-5, "Does not agree with existing numerical computing frameworks");
  }
  //---------------------------------------------------------------------------------------------------------
  // ERROR HANDLING
  //---------------------------------------------------------------------------------------------------------
  list1 = {"key1": "val1"};
  Topology T = ((1,2),(3,4),5);
  Tree TT = ((1,2),(3,4),5);

  
  assert (runCommandWithSoftErrors ('GammaDist(list1, list1, list1)', "GammaDist' is not implemented/defined for a AssociativeList"), "Failed error checking for trying to take GammaDist of associative list");
  assert (runCommandWithSoftErrors ('GammaDist(T, T, T)', "Operation 'GammaDist' is not implemented/defined for a Topology"), "Failed error checking for trying to take GammaDist of Topology");
  assert (runCommandWithSoftErrors ('GammaDist(TT, TT, TT)', "Operation 'GammaDist' is not implemented/defined for a Tree"), "Failed error checking for trying to take GammaDist of Tree");

  testResult = 1;

  return testResult;
}
