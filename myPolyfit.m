function [fit_expr, gof] = myPolyfit(X, Y, X_intercept, degree, options)
%CREATEFIT(X,Y)
%  Create a fit.
%
%  Data for 'untitled fit 1' fit:
%      X Input : X
%      Y Output: Y
%  Output:
%      fitresult : a fit object representing the fit.
%      gof : structure with goodness-of fit info.
%

%% Fit
arguments
    X
    Y
    X_intercept
    degree
    options.show_plot (1, 1) logical = false
    options.give_intercept (1, 1) logical = true
end

[xData, yData] = prepareCurveData( X, Y );

% Normalize
f_normalize_x = @(x) (x - mean(xData)) / std(xData);
f_normalize_y = @(y) (y - mean(yData)) / std(yData);
xData_norm = f_normalize_x(xData);
yData_norm = f_normalize_y(yData);

% Set up fittype and options.
fit_type = 'poly' + string(degree);
ft = fittype( fit_type);
opts = fitoptions( 'Method', 'LinearLeastSquares' );
opts.Normalize = 'off'; % Do not normalize here in order to reconstruct the lambda funtion.
opts.Robust = 'Bisquare';

% Fit model to data.
[fitresult, gof] = fit(xData_norm, yData_norm, ft, opts );

% % Make the zero cross of x-axis at X0
if(options.give_intercept == true)
    yData_norm = yData_norm - (fitresult(f_normalize_x(X_intercept)) + mean(yData)/std(yData));
    [fitresult, gof] = fit(xData_norm, yData_norm, ft, opts );
end

% Conver cfit to lambda function
form = regexprep(formula(fitresult), '\n|\s|\t', ' ');
form = strrep(form, 'x', 'v');
coeffs = coeffvalues(fitresult);
coeff_names = coeffnames(fitresult);

syms v;
% Construct symbolic expression from fit
f = symfun(vpa(subs(str2sym(form), num2cell(str2sym(coeff_names)), coeffs')), v);
% Unnormalize
fit_expr = simplify(subs(f, v, (v-mean(xData))/std(xData)) * std(yData) + mean(yData));
clear v;

if(options.show_plot == true)
    figure('Name', 'Fit result')
    scatter(xData, yData);
    hold on;
    plot(xData, fit_expr(xData))

%     % Create a figure for the plots.
%     figure( 'Name', 'Fit result' );
% 
%     % Plot fit with data.
%     subplot( 2, 1, 1 );
%     h = plot( fitresult, xData, yData );
%     legend( h, 'Value vs. Position', 'Fit result', 'Location', 'NorthEast', 'Interpreter', 'none' );
%     % Label axes
%     xlabel( 'Position', 'Interpreter', 'none' );
%     ylabel( 'Value', 'Interpreter', 'none' );
%     grid on
% 
%     % Plot residuals.
%     subplot( 2, 1, 2 );
%     h = plot( fitresult, xData, yData, 'residuals' );
%     legend( h, 'Fit residuals', 'Zero Line', 'Location', 'NorthEast', 'Interpreter', 'none' );
%     % Label axes
%     xlabel( 'Position', 'Interpreter', 'none' );
%     ylabel( 'Error', 'Interpreter', 'none' );
%     grid on
end


