% RUN_NESTAPP  Launch the nestapp TMS-EEG processing application.
%
%   Usage: run_nestapp
%
%   Run this script from the project root in the MATLAB command window.
%   nestapp.m is the authoritative source — do not open nestapp_designer.mlapp.

addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
nestapp;
