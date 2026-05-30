function cost_function_gui
% cost_function_gui
%   Interactive GUI: 3D mesh cost surface, 2D contours, scatter + fits,
%   add points by typing or double-clicking on the contour. Panels
%   auto-extend with epsilon margin; 40 contour levels; infinite dashed
%   axis crossings; proper legend labels; R² ≥ 0.
%   Prevents duplicate slope-intercept tests, updates surfaces live
%   on pan/zoom/rotate, and includes batch gradient descent controls
%   with duplicate-setting checks. GD runs now also update axis limits.

%% 1) Synthetic data
rng('default');
n = 100;
x = linspace(0,10,n)';
m_true = 2.5;  b_true = 1.0;
y = m_true*x + b_true + 2*randn(n,1);
SS_tot = sum((y-mean(y)).^2);

%% 2) Initial ranges
slopeMinSurf      = -2;   slopeMaxSurf     =  6;
interMinSurf      = -5;   interceptMaxSurf =  5;
initSlopeMinCont     = -1; initSlopeMaxCont     =  5;
initInterceptMinCont = -5; initInterceptMaxCont =  5;
slopeMinCont     = initSlopeMinCont;
slopeMaxCont     = initSlopeMaxCont;
interceptMinCont = initInterceptMinCont;
interceptMaxCont = initInterceptMaxCont;

%% 3) Initial cost surfaces
[slopeGridSurf, interGridSurf, J_surf] = computeCostSurface(...
    slopeMinSurf, slopeMaxSurf, interMinSurf, interceptMaxSurf);
[slopeGridCont, interGridCont, J_cont] = computeCostSurface(...
    slopeMinCont, slopeMaxCont, interceptMinCont, interceptMaxCont);

%% 4) Optimal fit & R²
[J_opt, idx_opt] = min(J_surf(:));
m_opt = slopeGridSurf(idx_opt);
b_opt = interGridSurf(idx_opt);
y_opt = m_opt*x + b_opt;
R2_opt = max(0,1 - sum((y-y_opt).^2)/SS_tot);
optLabel = sprintf('Opt: y=%.2fx+%.2f, R^2=%.3f',m_opt,b_opt,R2_opt);

%% 5) Create GUI
f = figure('Name','Regression GUI','NumberTitle','off', ...
    'Units','normalized','Position',[0.1 0.1 0.8 0.7]);
set(f,'WindowButtonDownFcn',@figureClick);

% pan/zoom/rotate callbacks
hZ = zoom(f);    set(hZ,'ActionPostCallback',@updateSurfaces);
hP = pan(f);     set(hP,'ActionPostCallback',@updateSurfaces);
hR = rotate3d(f);set(hR,'ActionPostCallback',@updateSurfaces);

lm=0.05; bm=0.10; axW=0.7; axH=0.8; sp=0.05;
smallW=(axW-sp)/2; smallH=(axH-sp)/2;

% 5a) 3D mesh
ax1 = axes(f,'Units','normalized',...
    'Position',[lm,bm+smallH+sp,smallW,smallH]);
hSurf = mesh(ax1,slopeGridSurf,interGridSurf,J_surf,'FaceAlpha',0.5);
hSurf.FaceColor = 'flat'; colormap(ax1,'turbo'); colorbar(ax1);
xlabel(ax1,'Slope'); ylabel(ax1,'Intercept'); zlabel(ax1,'Cost J');
title(ax1,'3D Cost Mesh'); view(ax1,45,30);
grid(ax1,'on'); rotate3d(ax1,'on'); hold(ax1,'on');
xlim(ax1,[slopeMinSurf slopeMaxSurf]); ylim(ax1,[interMinSurf interceptMaxSurf]);
plot3(ax1,[m_opt m_opt],[b_opt b_opt],[0 J_opt],'k-','LineWidth',3);
plot3(ax1,m_opt,b_opt,J_opt,'ko','MarkerFaceColor','k','MarkerSize',10);

% 5b) Contour
ax2 = axes(f,'Units','normalized',...
    'Position',[lm+smallW+sp,bm+smallH+sp,smallW,smallH]);
contour(ax2,slopeGridCont,interGridCont,J_cont,40,'LineWidth',2);
colormap(ax2,'turbo'); colorbar(ax2);
xlabel(ax2,'Slope'); ylabel(ax2,'Intercept');
title(ax2,'Cost Contours'); hold(ax2,'on');
plot(ax2,m_opt,b_opt,'ko','MarkerFaceColor','k','MarkerSize',10);
xlim(ax2,[slopeMinCont slopeMaxCont]); ylim(ax2,[interceptMinCont interceptMaxCont]);

% 5c) Scatter + optimal line
ax3 = axes(f,'Units','normalized',...
    'Position',[lm,bm,axW,smallH]);
scatter(ax3,x,y,80,'MarkerFaceColor',[.5 .5 .5],...
    'MarkerEdgeColor','none','MarkerFaceAlpha',.3);
hold(ax3,'on');
xlabel(ax3,'x'); ylabel(ax3,'y');
title(ax3,'Data & Fitted Lines'); grid(ax3,'on');
hOptLine = plot(ax3,x,y_opt,'k-','LineWidth',3);
legend(ax3,hOptLine,optLabel,'Location','northwest');

% 5d) Control panel
ctrl = uipanel(f,'Units','normalized',...
    'Position',[0.78 0.1 0.2 0.8],'Title','Controls','FontSize',14);

% Add Test section
uicontrol(ctrl,'Style','text','Units','normalized',...
    'Position',[0.1 0.85 0.8 0.05],'String','Add Test','FontWeight','bold','FontSize',14);
uicontrol(ctrl,'Style','text','Units','normalized',...
    'Position',[0.1 0.80 0.8 0.04],'String','Slope (m):','HorizontalAlignment','left','FontSize',12);
hSlope = uicontrol(ctrl,'Style','edit','Units','normalized',...
    'Position',[0.1 0.76 0.8 0.04],'String','0','FontSize',12);
uicontrol(ctrl,'Style','text','Units','normalized',...
    'Position',[0.1 0.70 0.8 0.04],'String','Intercept (b):','HorizontalAlignment','left','FontSize',12);
hInt = uicontrol(ctrl,'Style','edit','Units','normalized',...
    'Position',[0.1 0.66 0.8 0.04],'String','0','FontSize',12);
uicontrol(ctrl,'Style','pushbutton','Units','normalized',...
    'Position',[0.25 0.60 0.5 0.05],'String','Add Test','FontSize',12,'Callback',@addTest);

% Batch Gradient Descent section
uicontrol(ctrl,'Style','text','Units','normalized',...
    'Position',[0.1 0.52 0.8 0.05],'String','Batch Gradient Descent','FontWeight','bold','FontSize',14);
uicontrol(ctrl,'Style','text','Units','normalized',...
    'Position',[0.1 0.48 0.8 0.04],'String','Learning Rate (α):','HorizontalAlignment','left','FontSize',12);
hAlpha = uicontrol(ctrl,'Style','edit','Units','normalized',...
    'Position',[0.1 0.44 0.8 0.04],'String','0.01','FontSize',12);
uicontrol(ctrl,'Style','text','Units','normalized',...
    'Position',[0.1 0.38 0.8 0.04],'String','Iterations:','HorizontalAlignment','left','FontSize',12);
hIters = uicontrol(ctrl,'Style','edit','Units','normalized',...
    'Position',[0.1 0.34 0.8 0.04],'String','100','FontSize',12);
uicontrol(ctrl,'Style','text','Units','normalized',...
    'Position',[0.1 0.28 0.8 0.04],'String','Init Slope (m₀):','HorizontalAlignment','left','FontSize',12);
hM0 = uicontrol(ctrl,'Style','edit','Units','normalized',...
    'Position',[0.1 0.24 0.8 0.04],'String','0','FontSize',12);
uicontrol(ctrl,'Style','text','Units','normalized',...
    'Position',[0.1 0.18 0.8 0.04],'String','Init Intercept (b₀):','HorizontalAlignment','left','FontSize',12);
hB0 = uicontrol(ctrl,'Style','edit','Units','normalized',...
    'Position',[0.1 0.14 0.8 0.04],'String','0','FontSize',12);
uicontrol(ctrl,'Style','pushbutton','Units','normalized',...
    'Position',[0.25 0.06 0.5 0.06],'String','Run GD','FontSize',12,'Callback',@runGD);

%% 6) Storage
colors         = lines(100);
testCount      = 0;
testSlopes     = [];
testIntercepts = [];
testLines      = gobjects(0);
testLabs       = {};     % legend labels
gdParams       = [];     % [α, iters, m₀, b₀]
gdCount        = 0;
gdSlopes       = [];
gdIntercepts   = [];

%% Nested: addTest
    function addTest(~,~)
        m_test = str2double(get(hSlope,'String'));
        b_test = str2double(get(hInt,'String'));
        if isnan(m_test)||isnan(b_test)
            errordlg('Enter numeric values','Input Error'); return;
        end
        if any(abs(testSlopes - m_test)<eps & abs(testIntercepts - b_test)<eps)
            errordlg('This slope-intercept pair has already been added','Duplicate Entry');
            return;
        end
        testCount = testCount + 1;
        testSlopes(end+1)     = m_test;
        testIntercepts(end+1) = b_test;
        c = colors(mod(testCount-1,100)+1,:);

        % 3D surface update (include both test & GD)
        allM = [testSlopes, gdSlopes];
        allB = [testIntercepts, gdIntercepts];
        slopeMinSurf = min([slopeMinSurf, allM]);
        slopeMaxSurf = max([slopeMaxSurf, allM]);
        interMinSurf = min([interMinSurf, allB]);
        interceptMaxSurf = max([interceptMaxSurf, allB]);
        spanS = slopeMaxSurf - slopeMinSurf; spanI = interceptMaxSurf - interMinSurf;
        epsS = 0.05*(spanS+eps); epsI = 0.05*(spanI+eps);
        meshMinS = slopeMinSurf-epsS; meshMaxS = slopeMaxSurf+epsS;
        meshMinI = interMinSurf-epsI; meshMaxI = interceptMaxSurf+epsI;
        [SGS,IGS,J_s] = computeCostSurface(meshMinS,meshMaxS,meshMinI,meshMaxI);
        delete(hSurf);
        hSurf = mesh(ax1,SGS,IGS,J_s,'FaceAlpha',0.5); hSurf.FaceColor='flat';
        colormap(ax1,'turbo'); hold(ax1,'on');
        plot3(ax1,[m_opt m_opt],[b_opt b_opt],[0 J_opt],'k-','LineWidth',3);
        plot3(ax1,m_opt,b_opt,J_opt,'ko','MarkerFaceColor','k','MarkerSize',10);
        xlim(ax1,[meshMinS meshMaxS]); ylim(ax1,[meshMinI meshMaxI]);

        % plot new test point
        y_t = m_test*x + b_test; J_t = sum((y_t-y).^2)/(2*n);
        plot3(ax1,[m_test m_test],[b_test b_test],[0 J_t],'-','Color',c,'LineWidth',2);
        plot3(ax1,m_test,b_test,J_t,'p','MarkerEdgeColor',c,'MarkerFaceColor',c,'MarkerSize',8);
        plot3(ax1,[m_test m_test],[meshMinI meshMaxI],[0 0],'--','Color',c);
        plot3(ax1,[meshMinS meshMaxS],[b_test b_test],[0 0],'--','Color',c);

        R2_t = max(0,1 - sum((y-y_t).^2)/SS_tot);

        % Contour update
        contAllM = [testSlopes, gdSlopes];
        contAllB = [testIntercepts, gdIntercepts];
        newMinS = min([initSlopeMinCont, contAllM]);
        newMaxS = max([initSlopeMaxCont, contAllM]);
        newMinI = min([initInterceptMinCont, contAllB]);
        newMaxI = max([initInterceptMaxCont, contAllB]);
        spanS2=newMaxS-newMinS; spanI2=newMaxI-newMinI;
        epsS2=0.05*(spanS2+eps); epsI2=0.05*(spanI2+eps);
        contMinS=newMinS-epsS2; contMaxS=newMaxS+epsS2;
        contMinI=newMinI-epsI2; contMaxI=newMaxI+epsI2;
        [SGC,IGC,J_c] = computeCostSurface(contMinS,contMaxS,contMinI,contMaxI);
        cla(ax2);
        contour(ax2,SGC,IGC,J_c,40,'LineWidth',2);
        colormap(ax2,'turbo'); hold(ax2,'on');
        plot(ax2,m_opt,b_opt,'ko','MarkerFaceColor','k','MarkerSize',10);
        xlim(ax2,[contMinS contMaxS]); ylim(ax2,[contMinI contMaxI]);
        % plot tests
        for k2=1:testCount
            colk=colors(mod(k2-1,100)+1,:);
            plot(ax2,[testSlopes(k2) testSlopes(k2)],[contMinI contMaxI],'--','Color',colk);
            plot(ax2,[contMinS contMaxS],[testIntercepts(k2) testIntercepts(k2)],'--','Color',colk);
            plot(ax2,testSlopes(k2),testIntercepts(k2),'p','MarkerEdgeColor',colk,...
                 'MarkerFaceColor',colk,'MarkerSize',8);
        end
        % plot GD points too
        for g=1:numel(gdSlopes)
            plot(ax2,gdSlopes(g),gdIntercepts(g),'s','MarkerEdgeColor','r','MarkerFaceColor','none','MarkerSize',8);
        end

        % scatter update
        hL = plot(ax3,x,y_t,'-','Color',c,'LineWidth',2);
        testLines(end+1)=hL;
        testLabs{end+1}=sprintf('T%d: y=%.2fx+%.2f, R^2=%.3f', ...
                                 testCount,m_test,b_test,R2_t);
        legend(ax3,[hOptLine,testLines],[optLabel,testLabs],'Location','northwest');

        fprintf('Test %d: J=%.4f, R^2=%.4f\n',testCount,J_t,R2_t);
    end

%% Nested: runGD
    function runGD(~,~)
        alpha = str2double(get(hAlpha,'String'));
        iters = round(str2double(get(hIters,'String')));
        m0    = str2double(get(hM0,'String'));
        b0    = str2double(get(hB0,'String'));
        if isnan(alpha)||alpha<=0||alpha>=1
            errordlg('α between 0 and 1','Input Error'); return; end
        if isnan(iters)||iters<1
            errordlg('Iterations ≥ 1','Input Error'); return; end
        if isnan(m0)||isnan(b0)
            errordlg('Init m₀ and b₀ numeric','Input Error'); return; end
        newParam = [alpha,iters,m0,b0];
        if ~isempty(gdParams) && any(all(abs(gdParams-newParam)<eps,2))
            errordlg('These GD settings already run','Duplicate GD Entry');
            return;
        end
        gdParams(end+1,:) = newParam;
        % run GD
        m_gd = m0; b_gd = b0;
        for k=1:iters
            yhat = m_gd*x + b_gd;
            dJdm = (1/n)*sum((yhat-y).*x);
            dJdb = (1/n)*sum(yhat-y);
            m_gd = m_gd - alpha*dJdm;
            b_gd = b_gd - alpha*dJdb;
        end
        y_gd = m_gd*x + b_gd;
        J_gd = sum((y_gd-y).^2)/(2*n);
        R2_gd = max(0,1 - sum((y-y_gd).^2)/SS_tot);
        gdCount = gdCount + 1;
        gdSlopes(end+1)     = m_gd;
        gdIntercepts(end+1) = b_gd;

        % 3D surface update including GD
        allM = [testSlopes, gdSlopes];
        allB = [testIntercepts, gdIntercepts];
        slopeMinSurf = min([slopeMinSurf, allM]);
        slopeMaxSurf = max([slopeMaxSurf, allM]);
        interMinSurf = min([interMinSurf, allB]);
        interceptMaxSurf = max([interceptMaxSurf, allB]);
        spanS = slopeMaxSurf - slopeMinSurf; spanI = interceptMaxSurf - interMinSurf;
        epsS = 0.05*(spanS+eps); epsI = 0.05*(spanI+eps);
        meshMinS = slopeMinSurf-epsS; meshMaxS = slopeMaxSurf+epsS;
        meshMinI = interMinSurf-epsI; meshMaxI = interceptMaxSurf+epsI;
        [SGS,IGS,J_s] = computeCostSurface(meshMinS,meshMaxS,meshMinI,meshMaxI);
        delete(hSurf);
        hSurf = mesh(ax1,SGS,IGS,J_s,'FaceAlpha',0.5); hSurf.FaceColor='flat';
        hold(ax1,'on');
        plot3(ax1,[m_opt m_opt],[b_opt b_opt],[0 J_opt],'k-','LineWidth',3);
        plot3(ax1,m_opt,b_opt,J_opt,'ko','MarkerFaceColor','k','MarkerSize',10);
        xlim(ax1,[meshMinS meshMaxS]); ylim(ax1,[meshMinI meshMaxI]);
        % plot GD on 3D
        plot3(ax1,[m_gd m_gd],[b_gd b_gd],[0 J_gd],'r-','LineWidth',2);
        plot3(ax1,m_gd,b_gd,J_gd,'s','MarkerEdgeColor','r','MarkerFaceColor','none','MarkerSize',10);

        % contour update including GD
        contAllM = [testSlopes, gdSlopes];
        contAllB = [testIntercepts, gdIntercepts];
        newMinS = min([initSlopeMinCont, contAllM]);
        newMaxS = max([initSlopeMaxCont, contAllM]);
        newMinI = min([initInterceptMinCont, contAllB]);
        newMaxI = max([initInterceptMaxCont, contAllB]);
        spanS2=newMaxS-newMinS; spanI2=newMaxI-newMinI;
        epsS2=0.05*(spanS2+eps); epsI2=0.05*(spanI2+eps);
        contMinS=newMinS-epsS2; contMaxS=newMaxS+epsS2;
        contMinI=newMinI-epsI2; contMaxI=newMaxI+epsI2;
        [SGC,IGC,J_c] = computeCostSurface(contMinS,contMaxS,contMinI,contMaxI);
        cla(ax2);
        contour(ax2,SGC,IGC,J_c,40,'LineWidth',2); hold(ax2,'on');
        plot(ax2,m_opt,b_opt,'ko','MarkerFaceColor','k','MarkerSize',10);
        xlim(ax2,[contMinS contMaxS]); ylim(ax2,[contMinI contMaxI]);
        % replot test and GD points
        for k2=1:testCount
            colk=colors(mod(k2-1,100)+1,:);
            plot(ax2,testSlopes(k2),testIntercepts(k2),'p','MarkerEdgeColor',colk,...
                 'MarkerFaceColor',colk,'MarkerSize',8);
        end
        for g=1:numel(gdSlopes)
            plot(ax2,gdSlopes(g),gdIntercepts(g),'s','MarkerEdgeColor','r',...
                 'MarkerFaceColor','none','MarkerSize',8);
        end

        % scatter plot GD
        hGD = plot(ax3,x,y_gd,'-.','Color','r','LineWidth',2);
        testLines(end+1)=hGD;
        runLabel = sprintf('GD%d: y=%.2fx+%.2f, R^2=%.3f',gdCount,m_gd,b_gd,R2_gd);
        testLabs{end+1} = runLabel;
        legend(ax3,[hOptLine,testLines],[optLabel,testLabs],'Location','northwest');
        fprintf('%s → J=%.4f, R^2=%.4f\n',runLabel,J_gd,R2_gd);
    end

%%  Nested: updateSurfaces
    function updateSurfaces(~,~)
        % update 3D
        xl = xlim(ax1); yl = ylim(ax1);
        [Mnew,Bnew,Jnew] = computeCostSurface(xl(1),xl(2),yl(1),yl(2));
        set(hSurf,'XData',Mnew,'YData',Bnew,'ZData',Jnew);
        % update contour
        xl2 = xlim(ax2); yl2 = ylim(ax2);
        [M2,B2,J2] = computeCostSurface(xl2(1),xl2(2),yl2(1),yl2(2));
        cla(ax2);
        contour(ax2,M2,B2,J2,40,'LineWidth',2); hold(ax2,'on');
        plot(ax2,m_opt,b_opt,'ko','MarkerFaceColor','k','MarkerSize',10);
        for k2=1:testCount
            colk=colors(mod(k2-1,100)+1,:);
            plot(ax2,testSlopes(k2),testIntercepts(k2),'p','MarkerEdgeColor',colk,...
                 'MarkerFaceColor',colk,'MarkerSize',8);
        end
        for g=1:numel(gdSlopes)
            plot(ax2,gdSlopes(g),gdIntercepts(g),'s','MarkerEdgeColor','r',...
                 'MarkerFaceColor','none','MarkerSize',8);
        end
    end

%% Nested: figureClick
    function figureClick(~,~)
        if ~strcmp(get(f,'SelectionType'),'open'), return; end
        if ~isequal(gca,ax2), return; end
        cp = get(ax2,'CurrentPoint');
        set(hSlope,'String',num2str(cp(1,1)));
        set(hInt,  'String',num2str(cp(1,2)));
        addTest();
    end
end

%% Helper: computeCostSurface
function [Mgrid,Bgrid,Jgrid] = computeCostSurface(mMin,mMax,bMin,bMax)
    nPts = 100;
    mVals = linspace(mMin,mMax,nPts);
    bVals = linspace(bMin,bMax,nPts);
    [Mgrid,Bgrid] = meshgrid(mVals,bVals);
    x = evalin('caller','x'); y = evalin('caller','y'); n = evalin('caller','n');
    Jgrid = zeros(size(Mgrid));
    for idx = 1:numel(Mgrid)
        yHat = Mgrid(idx)*x + Bgrid(idx);
        Jgrid(idx) = sum((yHat - y).^2)/(2*n);
    end
end
