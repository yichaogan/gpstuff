%DEMO_MULTICLASS_NESTED_EP Demonstrate the fully-coupled nested EP for
%                          multi-class classification
%
%  Description
%    This is a short demo of the fully-coupled nested EP
%    implementation for Gaussian process classification with a
%    multinomial probit likelihood described in
%
%  Reference
%    Jaakko Riihimäki, Pasi Jylänki and Aki Vehtari (2013). Nested
%    Expectation Propagation for Gaussian Process Classification with
%    a Multinomial Probit Likelihood. Journal of Machine Learning
%    Research 14:75-109, 2013.
%
%  Data description
%    The data used in this demo is the same used by Radford M. Neal in
%    his three-way classification example in Software for Flexible
%    Bayesian Modeling (http://www.cs.toronto.edu/~radford/fbm.software.html).
%    The data consists of 1000 4-D vectors which are classified into
%    three classes. The data is generated by drawing the components of
%    vector, x1, x2, x3 and x4, uniformly form (0,1). The class of
%    each vector is selected according to the first two components of
%    the vector, x_1 and x_2. After this a Gaussian noise with
%    standard deviation of 0.1 has been added to every component of
%    the vector. Because there are two irrelevant components in the
%    input vector a prior with ARD should be of help.
%
% Copyright (c) 2011-2013 Jaakko Riihimäki, Pasi Jylänki, Aki Vehtari

%- load the data
S = which('demo_multiclass_nested_ep');
L = strrep(S,'demo_multiclass_nested_ep.m','demodata/cdata.txt');
x=load(L);
y=zeros(size(x,1),3);
y(x(:,5)==0,1) = 1;
y(x(:,5)==1,2) = 1;
y(x(:,5)==2,3) = 1;
x(:,end)=[];

%- Divide the data set into test and training parts
%
% x  = training inputs
% y  = training class labels
% xt = test inputs
% yt = test class labels
%
% test data (800 cases)
xt = x(201:end,:);
yt=y(201:end,:);
% training data (200 cases)
x=x(1:200,:);
y=y(1:200,:);

[n, nin] = size(x); % n = number of observations, nin = number of inputs

%- Create the covariance function
% without ARD (common lengthscale for all inputs):
%gpcf1 = gpcf_sexp('lengthScale', 1, 'magnSigma2', 1);
% with ARD (individual lengthscale for all inputs):
gpcf1 = gpcf_sexp('lengthScale', ones(1,nin), 'magnSigma2', 1);

%- Create priors for the parameters of covariance functions
pl = prior_t('s2',10,'nu',10); % the lengthscale
pm = prior_sqrtt('s2',10,'nu',10); % the magnitude

%- Set the priors for the parameters of covariance functions
gpcf1 = gpcf_sexp(gpcf1, 'lengthScale_prior', pl,'magnSigma2_prior', pm);

%- Create the GP structure
latent_opt.maxiter=30;
latent_opt.tol=1e-3;
latent_opt.incremental='on';
gpep = gp_set('lik', lik_multinomprobit, 'cf', {gpcf1}, 'jitterSigma2', 1e-6, 'latent_method', 'EP', 'latent_opt', latent_opt);

% Optimization options
opt=optimset('TolX',1e-2,'TolFun',1e-2,'Display','iter','derivativecheck','off');

disp('Optimize the hyperparameters')
gpep=gp_optim(gpep,x,y,'opt',opt, 'optimf', @fminlbfgs);

%- print optimized hyperparameter values
fprintf('\n');
disp(['Optimized magnitude sigma^2: ' num2str(gpep.cf{1}.magnSigma2)])
disp(['Optimized lengthscales: ' num2str(gpep.cf{1}.lengthScale)])

%- compute the predictions for the test data
[Eftep, Covftep, lpytep] = gp_pred(gpep, x, y, xt,'yt', ones(size(xt,1),size(y,2)));

% calculate the percentage of misclassified points
ttep = (exp(lpytep)==repmat(max(exp(lpytep),[],2),1,size(lpytep,2)));
disp(['The percentage of misclassified points: ' num2str((sum(sum(abs(ttep-yt)))/2)/size(yt,1))])

%- Create a 2D grid (inputs 1 and 2) for visualizing predictions
xtg1 = meshgrid(linspace(min(x(:,1))-.1, max(x(:,1))+.1, 30)); 
xtg2 = meshgrid(linspace(min(x(:,2))-.1, max(x(:,2))+.1, 30))';
% inputs 3 and 4 are irrelevant
xtg=[xtg1(:) xtg2(:) repmat(mean(x(:,3:4)), size(xtg1(:),1),1)];

%- compute the predictions in a 2D grid
[Eft, Covft, lpg] = gp_pred(gpep, x, y, xtg,'yt', ones(size(xtg,1),size(y,2)));

%- plot the training data
figure, hold on
plot(x(y(:,1)==1,1),x(y(:,1)==1,2),'ro', 'linewidth', 2);
plot(x(y(:,2)==1,1),x(y(:,2)==1,2),'x', 'linewidth', 2);
plot(x(y(:,3)==1,1),x(y(:,3)==1,2),'k+', 'linewidth', 2);
%- plot the contours of class probabilities
contour(xtg1, xtg2, reshape(exp(lpg(:,1)),30,30), [0.1 0.25 0.5 0.75 0.9] ,'r', 'linewidth', 2)
contour(xtg1, xtg2, reshape(exp(lpg(:,2)),30,30), [0.1 0.25 0.5 0.75 0.9], 'b', 'linewidth', 2)
contour(xtg1, xtg2, reshape(exp(lpg(:,3)),30,30), [0.1 0.25 0.5 0.75 0.9], 'k', 'linewidth', 2)
xlabel('Input 1'), ylabel('Input 2')
title('Training data points and predicted contours of class probabilities')
