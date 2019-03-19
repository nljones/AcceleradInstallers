@echo off
rem This batch script tests that AcceleradRT runs.
set CUDA_VISIBLE_DEVICES=0
AcceleradRT -version
if errorlevel 1 goto FAILURE
AcceleradRT -g 8192 -vf test.vf -ab 3 -aa 0 -ad 1 -x 768 -y 768 -s 10000 -log 3 test.oct
if errorlevel 1 goto FAILURE
echo AcceleradRT succeeded!
goto END
:FAILURE
echo AcceleradRT failed
:END
pause
