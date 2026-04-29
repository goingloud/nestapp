% This file has been moved to tests/integration/test_batchTEPExtract.m
%
% batchTEPExtract requires TESA (tesa_peakanalysis) for all meaningful tests
% because it calls tepPeakFinder internally.  Tests that depend on an external
% toolbox belong in the integration suite, not the fast unit suite.
%
% Run:  runtests('tests/integration/test_batchTEPExtract')
