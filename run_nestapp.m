% RUN_NESTAPP  Launch the nestapp TMS-EEG processing application.
%
%   Usage: run_nestapp
%
%   Run this script from the project root in the MATLAB command window.
%   nestapp.m is the authoritative source — do not open nestapp_designer.mlapp.

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'eeglab2026.0.0'));
nestapp;
