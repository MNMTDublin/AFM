function [fitresult, f_sym, gof] = mySymPolyfit(X, Y, X0, degree, options)
%CREATEFIT(X,Y)
%  Create a fit.
%
%  Data for 'untitled fit 1' fit:
%      X Input : X
%      Y Output: Y
%  Output:
%      fitresult : a fit object representing the fit.
%      gof : structure with goodness-of fit info.
%      f_sym : a symbolic function representing the fit.
%
%% Fit
arguments
    X
    Y
    X0
    degree
    options.show_plot (1, 1) logical = false
end

[xData, yData] = prepareCurveData( X, Y );

% Normalize
xMean = mean(xData);
xStd = std(xData);
xData_norm = (xData - xMean) / xStd;
yMean = mean(yData);
yStd = std(yData);
yData_norm = (yData - yMean) / yStd;

% Fit model to normalized data.
p = polyfit(xData_norm, yData_norm, degree);

% Convert the polynomial coefficients to a symbolic function
syms x_sym
f_sym = poly2sym(p, x_sym);
f_sym = subs(f_sym, x_sym, (x_sym - xMean) / xStd);

% Make the zero cross of x-axis at X0
X0_norm = (X0 - xMean) / xStd;
yData_norm = yData_norm - polyval(p, X0_norm);
p_X0 = polyfit(xData_norm, yData_norm, degree);

fitresult = @(x) polyval(p_X0, (x - xMean) / xStd);

% Convert the polynomial coefficients to a symbolic function
f_sym_X0 = poly2sym(p_X0, x_sym);
f_sym_X0 = subs(f_sym_X0, x_sym, (x_sym - xMean) / xStd);

% Compute goodness of fit
yFit = polyval(p_X0, xData_norm);
yResid = yData_norm - yFit;
SSresid = sum(yResid.^2);
SStotal = (length(yData_norm)-1) * var(yData_norm);
gof.rsquare = 1 - SSresid/SStotal;
gof.sse = SSresid;

fitresult = p_X0;

end
