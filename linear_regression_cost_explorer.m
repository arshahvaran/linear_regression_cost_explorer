function linear_regression_cost_explorer

    PALETTE = paletteColors();
    TURBO = makeTurbo();
    sup2 = char(178);

    dx = []; dy = [];
    S = struct();
    opt = struct('m',0,'b',0,'J',0,'r2',0);
    items = struct('id',{},'no',{},'type',{},'m',{},'b',{},'J',{},'r2',{}, ...
        'color',{},'label',{},'srcTestId',{},'path',{},'diverged',{}, ...
        'reached',{},'status',{},'alpha',{},'iters',{});
    idc = 0;
    colorIdx = 0;
    showResid = false;
    costDom = [];
    startIds = NaN;
    selStartId = NaN;
    animItemId = [];
    animStep = 0;
    animTimer = [];
    animH = struct('heat',[],'conv',[],'scat',[]);
    cbSurf = [];
    cbHeat = [];
    surfView = [45 32];

    fig = figure('Name','Linear Regression Cost Explorer','NumberTitle','off', ...
        'Units','normalized','Position',[0.05 0.07 0.9 0.86], ...
        'Color',[1 1 1],'MenuBar','none','ToolBar','figure');
    set(fig,'CloseRequestFcn',@onClose);

    axScatter = axes('Parent',fig,'Units','normalized','Position',[0.055 0.819 0.455 0.130]);
    axSurf    = axes('Parent',fig,'Units','normalized','Position',[0.060 0.585 0.385 0.150]);
    axHeat    = axes('Parent',fig,'Units','normalized','Position',[0.060 0.360 0.385 0.130]);
    axConv    = axes('Parent',fig,'Units','normalized','Position',[0.055 0.146 0.455 0.130]);

    for ax = [axScatter axSurf axHeat axConv]
        try, set(ax.Toolbar,'Visible','off'); catch, end
    end

    mkCaption([0.055 0.759 0.50 0.018], ...
        'Grey: data. Black: best fit. Solid colored: your tests. Dashed: gradient descent.');
    mkCaption([0.055 0.537 0.50 0.018], ...
        'Cost as a 3D landscape. The black dot at the bottom of the bowl is the best fit.');
    mkCaption([0.055 0.300 0.50 0.018], ...
        'Top down cost map (log color). Click anywhere to add that line as a test.');
    mkCaption([0.055 0.086 0.50 0.018], ...
        'Cost after each step. Levelling onto the dashed line means it reached the best fit.');

    btnResid = uicontrol(fig,'Style','togglebutton','Units','normalized', ...
        'Position',[0.405 0.963 0.105 0.026],'String','show errors','FontSize',8.5, ...
        'Callback',@onResid);
    uicontrol(fig,'Style','pushbutton','Units','normalized', ...
        'Position',[0.300 0.502 0.090 0.024],'String','reset view','FontSize',8.5, ...
        'Callback',@onCostReset);
    uicontrol(fig,'Style','pushbutton','Units','normalized', ...
        'Position',[0.395 0.502 0.090 0.024],'String','clear tests','FontSize',8.5, ...
        'Callback',@(s,e)onClearTests());

    statusBar = uicontrol(fig,'Style','text','Units','normalized', ...
        'Position',[0.055 0.014 0.45 0.022],'HorizontalAlignment','left', ...
        'BackgroundColor',[1 1 1],'ForegroundColor',[0.41 0.44 0.50],'FontSize',9,'String','');

    XF = 0.545; WF = 0.435;
    XL = 0.545; WL = 0.205;
    XR = 0.775; WR = 0.205;
    colMute = [0.41 0.44 0.50];
    colDark = [0.06 0.07 0.08];
    Yc = 0.986;

    secHeader('Best fit (least squares)');
    txtFitEq = leftText(0.020,12,colMute,'y = ...'); gap(0.002);
    txtFitR2 = leftText(0.024,15,colDark,['R' sup2 ' = ...']); gap(0.002);
    txtFitJ  = leftText(0.018,11.5,colMute,'cost J = ...'); gap(0.011);

    secHeader('Data');
    pairLabels('True slope','True intercept');
    edTrueM = editL('2.5'); edTrueB = editR('1'); gap(0.028+0.007);
    pairLabels(['Noise (' char(963) ')'],'Points (n)');
    edNoise = editL('2'); edN = editR('100'); gap(0.028+0.007);
    fullButton('Regenerate data',@(s,e)regenData()); gap(0.011);

    secHeader('Test a line');
    pairLabels('Slope (m)','Intercept (b)');
    edTestM = editL('1'); edTestB = editR('0'); gap(0.028+0.007);
    yB = takeY(0.030);
    btnHalf(XL,WL,yB,'Add line',@(s,e)addFromFields());
    btnHalf(XR,WR,yB,'Clear tests',@(s,e)onClearTests()); gap(0.011);

    secHeader('Gradient descent');
    leftText(0.015,11,colMute,'Start from'); gap(0.000);
    popStart = uicontrol('Parent',fig,'Style','popupmenu','Units','normalized', ...
        'Position',[XF takeY(0.029) WF 0.029],'String',{'Custom start (use fields)'}, ...
        'Value',1,'FontSize',10,'Callback',@onStartChange,'BackgroundColor',[1 1 1]); gap(0.006);
    pairLabels(['Learning rate (' char(945) ')'],'Iterations');
    edAlpha = editL('0.03'); edIters = editR('1000'); gap(0.028+0.006);
    pairLabels('Start slope','Start intercept');
    edM0 = editL('0'); edB0 = editR('0'); gap(0.028+0.007);
    yB = takeY(0.030);
    btnRect(0.545,0.130,yB,'Animate',@(s,e)runGD(true));
    btnRect(0.690,0.150,yB,'Run instantly',@(s,e)runGD(false));
    btnRect(0.855,0.125,yB,'Clear runs',@(s,e)onClearRuns()); gap(0.010);
    txtWarn = leftText(0.020,10.5,[0.75 0.23 0.18],''); gap(0.012);

    secHeader('Lines and runs');
    lstLines = uicontrol('Parent',fig,'Style','listbox','Units','normalized', ...
        'Position',[XF takeY(0.155) WF 0.155],'String',{''},'FontSize',9, ...
        'Min',0,'Max',1,'BackgroundColor',[1 1 1]); gap(0.009);
    fullButton('Remove selected',@(s,e)removeSelected()); gap(0.014);

    uicontrol('Parent',fig,'Style','text','Units','normalized', ...
        'Position',[0.545 0.005 0.435 0.020],'HorizontalAlignment','left', ...
        'BackgroundColor',[1 1 1],'ForegroundColor',[0.55 0.58 0.63],'FontSize',8.5, ...
        'String','Developed by Ali Reza Shahvaran - github.com/arshahvaran/ - May 2026');

    set(axHeat,'ButtonDownFcn',@onCostClick);

    regenData();

    function regenData()
        tm = numval(edTrueM,2.5);
        tb = numval(edTrueB,1);
        sg = numval(edNoise,2);
        n = round(numval(edN,100));
        if ~isfinite(n), n = 100; end
        n = max(5,min(2000,n));
        set(edN,'String',sprintf('%d',n));
        if ~isfinite(sg), sg = 0; end
        x = (10*(0:n-1)/(n-1))';
        y = tm*x + tb + sg*randn(n,1);
        dx = x; dy = y;
        computeSums();
        computeOpt();
        costDom = [];
        stopAnim();
        items = items([]);
        colorIdx = 0;
        selStartId = NaN;
        set(txtWarn,'String','');
        renumber();
        redrawAll();
    end

    function computeSums()
        n = numel(dx);
        Sx = sum(dx); Sy = sum(dy);
        Sxx = sum(dx.^2); Sxy = sum(dx.*dy); Syy = sum(dy.^2);
        S = struct('n',n,'Sx',Sx,'Sy',Sy,'Sxx',Sxx,'Sxy',Sxy,'Syy',Syy, ...
            'xmin',min(dx),'xmax',max(dx),'ymin',min(dy),'ymax',max(dy), ...
            'SStot',Syy - Sy*Sy/n);
    end

    function v = Jcost(m,b)
        v = (m.^2.*S.Sxx + S.n.*b.^2 + S.Syy + 2.*m.*b.*S.Sx - 2.*m.*S.Sxy - 2.*b.*S.Sy)./(2*S.n);
    end

    function g = grad2(m,b)
        g = [(m*S.Sxx + b*S.Sx - S.Sxy)/S.n, (m*S.Sx + b*S.n - S.Sy)/S.n];
    end

    function v = r2of(m,b)
        den = S.SStot;
        if den <= 0, den = 1e-12; end
        v = max(0, 1 - 2*S.n*Jcost(m,b)/den);
    end

    function computeOpt()
        den = S.n*S.Sxx - S.Sx^2;
        if den ~= 0
            m = (S.n*S.Sxy - S.Sx*S.Sy)/den;
        else
            m = 0;
        end
        b = (S.Sy - m*S.Sx)/S.n;
        opt = struct('m',m,'b',b,'J',Jcost(m,b),'r2',r2of(m,b));
    end

    function d = domainCost()
        if ~isfinite(opt.m) || ~isfinite(opt.b)
            d = [-5 5 -10 10];
            return;
        end
        mMin = opt.m-4; mMax = opt.m+4; bMin = opt.b-10; bMax = opt.b+10;
        capM = 12; capB = 24; capT = 500;
        for k = 1:numel(items)
            L = items(k);
            if strcmp(L.type,'test')
                if isfinite(L.m) && isfinite(L.b) && abs(L.m-opt.m)<capT && abs(L.b-opt.b)<capT
                    mMin=min(mMin,L.m); mMax=max(mMax,L.m); bMin=min(bMin,L.b); bMax=max(bMax,L.b);
                end
            else
                P = L.path;
                for r = 1:size(P,1)
                    pm = P(r,1); pb = P(r,2);
                    if isfinite(pm) && isfinite(pb) && abs(pm-opt.m)<capM && abs(pb-opt.b)<capB
                        mMin=min(mMin,pm); mMax=max(mMax,pm); bMin=min(bMin,pb); bMax=max(bMax,pb);
                    end
                end
            end
        end
        eM = 0.06*(mMax-mMin); if eM==0, eM=1; end
        eB = 0.06*(bMax-bMin); if eB==0, eB=1; end
        d = [mMin-eM mMax+eM bMin-eB bMax+eB];
    end

    function tf = sanePt(pm,pb)
        tf = isfinite(pm) && isfinite(pb) && isfinite(opt.m) && isfinite(opt.b) && ...
            abs(pm-opt.m)<500 && abs(pb-opt.b)<800;
    end

    function c = nextColor()
        c = PALETTE(mod(colorIdx,size(PALETTE,1))+1,:);
        colorIdx = colorIdx + 1;
    end

    function addFromFields()
        addTest(numval(edTestM,1),numval(edTestB,0));
    end

    function addTest(m,b)
        if ~isfinite(m) || ~isfinite(b)
            notify('Please enter valid numbers for slope and intercept.');
            return;
        end
        tol = 0.005;
        for k = 1:numel(items)
            if strcmp(items(k).type,'test') && abs(items(k).m-m)<=tol && abs(items(k).b-b)<=tol
                popMsg(sprintf('That test line is already added (m=%.2f, b=%.2f).',m,b));
                return;
            end
        end
        it = blankItem();
        it.id = idc; idc = idc + 1;
        it.type = 'test';
        it.m = m; it.b = b;
        it.J = Jcost(m,b); it.r2 = r2of(m,b);
        it.color = nextColor();
        items(end+1) = it;
        selStartId = it.id;
        renumber();
        redrawAll();
        set(edM0,'String',sprintf('%.2f',m));
        set(edB0,'String',sprintf('%.2f',b));
    end

    function runGD(animate)
        stopAnim();
        a = numval(edAlpha,0.03);
        it = round(numval(edIters,1000));
        if ~isfinite(it), it = 1000; end
        it = max(1,min(100000,it));
        m0 = numval(edM0,0); b0 = numval(edB0,0);
        if ~isfinite(m0), m0 = 0; end
        if ~isfinite(b0), b0 = 0; end
        for k = 1:numel(items)
            L = items(k);
            if strcmp(L.type,'gd') && ~isempty(L.path)
                if abs(L.path(1,1)-m0)<=0.005 && abs(L.path(1,2)-b0)<=0.005 && ...
                        abs(L.alpha-a)<=1e-6 && L.iters==it
                    popMsg(sprintf(['That gradient descent run is already in the list ' ...
                        '(start m=%.2f, b=%.2f, alpha=%g, %d iterations).'],m0,b0,a,it));
                    return;
                end
            end
        end
        m = m0; b = b0;
        P = zeros(it+1,3);
        P(1,:) = [m b Jcost(m,b)];
        diverged = false;
        used = 1;
        for k = 1:it
            g = grad2(m,b);
            m = m - a*g(1);
            b = b - a*g(2);
            jk = Jcost(m,b);
            P(k+1,:) = [m b jk];
            used = k+1;
            if ~isfinite(jk) || jk > 1e9
                diverged = true;
                break;
            end
        end
        P = P(1:used,:);
        last = P(end,:);
        idx = get(popStart,'Value');
        srcId = NaN;
        if idx >= 1 && idx <= numel(startIds)
            srcId = startIds(idx);
        end
        src = [];
        if ~isnan(srcId)
            src = findItem(srcId);
        end
        if ~isempty(src)
            c = src.color;
        else
            c = nextColor();
        end
        reached = ~diverged && abs(last(1)-opt.m)<0.05 && abs(last(2)-opt.b)<0.1;
        if diverged
            statusShort = 'diverged';
        elseif reached
            statusShort = 'reached optimum';
        else
            statusShort = 'not at optimum';
        end
        item = blankItem();
        item.id = idc; idc = idc + 1;
        item.type = 'gd';
        if ~isempty(src), item.srcTestId = src.id; else, item.srcTestId = NaN; end
        item.m = last(1); item.b = last(2); item.J = last(3);
        item.r2 = r2of(last(1),last(2));
        item.path = P;
        item.color = c;
        item.diverged = diverged;
        item.reached = reached;
        item.status = statusShort;
        item.alpha = a;
        item.iters = it;
        items(end+1) = item;
        renumber();
        if diverged
            set(txtWarn,'String','Diverged. The learning rate is too large for this data.', ...
                'ForegroundColor',[0.75 0.23 0.18]);
            notify('Diverged (alpha too large; try smaller).');
        elseif ~reached
            set(txtWarn,'String','Still on the way. Increase iterations or alpha to arrive.', ...
                'ForegroundColor',[0.41 0.44 0.50]);
            notify('Not at optimum yet (increase iterations or alpha).');
        else
            set(txtWarn,'String','');
            notify('Reached the optimum.');
        end
        if animate && size(P,1) > 2
            startAnim(item.id);
        else
            redrawAll();
        end
    end

    function startAnim(id)
        stopTimerOnly();
        animItemId = id;
        animStep = 0;
        redrawAll();
        L = findItem(id);
        if isempty(L), animItemId = []; return; end
        animH.heat = plot(axHeat,L.path(1,1),L.path(1,2),'-', ...
            'Color',L.color,'LineWidth',2,'HitTest','off','PickableParts','none');
        animH.conv = plot(axConv,0,max(L.path(1,3),1e-6),'-', ...
            'Color',L.color,'LineWidth',2,'HitTest','off');
        xlo = S.xmin; xhi = S.xmax;
        animH.scat = plot(axScatter,[xlo xhi], ...
            [L.path(1,1)*xlo+L.path(1,2) L.path(1,1)*xhi+L.path(1,2)], ...
            '--','Color',L.color,'LineWidth',2,'HitTest','off');
        animTimer = timer('ExecutionMode','fixedSpacing','Period',0.03, ...
            'TimerFcn',@animTick,'ErrorFcn',@(s,e)stopAnim());
        start(animTimer);
    end

    function animTick(~,~)
        if isempty(animItemId) || ~ishandle(fig) || ~allValid()
            finishAnim(); return;
        end
        L = findItem(animItemId);
        if isempty(L), finishAnim(); return; end
        last = size(L.path,1)-1;
        animStep = animStep + max(1, last/130);
        e = floor(animStep);
        if e < 1, e = 1; end
        done = false;
        if e >= last, e = last; done = true; end
        seg = L.path(1:e+1,:);
        mm = seg(:,1); bb = seg(:,2);
        bad = ~arrayfun(@(i)sanePt(mm(i),bb(i)),(1:numel(mm))');
        mm(bad) = NaN; bb(bad) = NaN;
        set(animH.heat,'XData',mm,'YData',bb);
        jj = seg(:,3);
        jj(~isfinite(jj)) = NaN;
        jj = max(jj,1e-6);
        set(animH.conv,'XData',0:e,'YData',jj);
        cm = seg(end,1); cb = seg(end,2);
        if isfinite(cm) && isfinite(cb) && abs(cm)<1e4 && abs(cb)<1e4
            xlo = S.xmin; xhi = S.xmax;
            set(animH.scat,'XData',[xlo xhi],'YData',[cm*xlo+cb cm*xhi+cb]);
        end
        drawnow limitrate;
        if done, finishAnim(); end
    end

    function tf = allValid()
        tf = all(ishandle([animH.heat animH.conv animH.scat]));
    end

    function finishAnim()
        stopAnim();
        redrawAll();
    end

    function stopTimerOnly()
        if ~isempty(animTimer)
            try, stop(animTimer); catch, end
            try, delete(animTimer); catch, end
            animTimer = [];
        end
    end

    function stopAnim()
        stopTimerOnly();
        animItemId = [];
        animStep = 0;
        delAnimH();
    end

    function delAnimH()
        f = fieldnames(animH);
        for k = 1:numel(f)
            h = animH.(f{k});
            if ~isempty(h) && ishandle(h)
                try, delete(h); catch, end
            end
            animH.(f{k}) = [];
        end
    end

    function onClearTests()
        stopAnim();
        keep = true(1,numel(items));
        for k = 1:numel(items)
            L = items(k);
            if strcmp(L.type,'test')
                keep(k) = false;
            elseif strcmp(L.type,'gd') && ~isnan(L.srcTestId)
                keep(k) = false;
            end
        end
        items = items(keep);
        selStartId = NaN;
        renumber();
        redrawAll();
    end

    function onClearRuns()
        stopAnim();
        if ~isempty(items)
            items = items(~strcmp({items.type},'gd'));
        end
        set(txtWarn,'String','');
        renumber();
        redrawAll();
    end

    function removeSelected()
        v = get(lstLines,'Value');
        if v <= 1, return; end
        if v-1 > numel(items), return; end
        target = items(v-1);
        if strcmp(target.type,'test')
            keep = true(1,numel(items));
            for k = 1:numel(items)
                L = items(k);
                if L.id == target.id
                    keep(k) = false;
                elseif strcmp(L.type,'gd') && ~isnan(L.srcTestId) && L.srcTestId == target.id
                    keep(k) = false;
                end
            end
            items = items(keep);
        else
            items = items([items.id] ~= target.id);
        end
        if ~isempty(animItemId) && isempty(findItem(animItemId))
            stopAnim();
        end
        renumber();
        redrawAll();
    end

    function L = findItem(id)
        L = [];
        if isempty(id) || isnan(id), return; end
        for k = 1:numel(items)
            if items(k).id == id
                L = items(k); return;
            end
        end
    end

    function regroup()
        if isempty(items), return; end
        out = items([]);
        isTest = strcmp({items.type},'test');
        testIdx = find(isTest);
        for ti = testIdx
            t = items(ti);
            out(end+1) = t;
            for k = 1:numel(items)
                L = items(k);
                if strcmp(L.type,'gd') && ~isnan(L.srcTestId) && L.srcTestId == t.id
                    out(end+1) = L;
                end
            end
        end
        for k = 1:numel(items)
            L = items(k);
            if strcmp(L.type,'gd') && (isnan(L.srcTestId) || isempty(findTestById(L.srcTestId)))
                out(end+1) = L;
            end
        end
        items = out;
    end

    function t = findTestById(id)
        t = [];
        for k = 1:numel(items)
            if strcmp(items(k).type,'test') && items(k).id == id
                t = items(k); return;
            end
        end
    end

    function renumber()
        regroup();
        tc = 0; gc = 0;
        for k = 1:numel(items)
            if strcmp(items(k).type,'test')
                tc = tc + 1;
                items(k).no = tc;
                items(k).label = sprintf('Test %d: y=%.2fx%s%.2f, R%c=%.3f', ...
                    tc, items(k).m, signOf(items(k).b), abs(items(k).b), sup2, items(k).r2);
            end
        end
        for k = 1:numel(items)
            if strcmp(items(k).type,'gd')
                gc = gc + 1;
                items(k).no = gc;
                src = findTestById(items(k).srcTestId);
                if ~isempty(src)
                    fromStr = sprintf('Test %d',src.no);
                else
                    fromStr = 'Custom';
                end
                items(k).label = sprintf('GD %d (%s): alpha=%g, %d it, %s', ...
                    gc, fromStr, items(k).alpha, items(k).iters, items(k).status);
            end
        end
        updateStartPopup();
    end

    function redrawAll()
        drawScatter();
        drawSurf();
        drawHeat();
        drawConv();
        updateFit();
        updateList();
        hideBars();
    end

    function hideBars()
        for ax = [axScatter axSurf axHeat axConv]
            try, set(ax.Toolbar,'Visible','off'); catch, end
        end
    end

    function tf = isAnim(L)
        tf = ~isempty(animItemId) && L.id == animItemId;
    end

    function drawScatter()
        if ~isfield(S,'n') || S.n == 0, return; end
        cla(axScatter);
        set(axScatter,'NextPlot','add','Color',[1 1 1],'Box','on', ...
            'XColor',[0.41 0.44 0.50],'YColor',[0.41 0.44 0.50],'FontSize',9);
        mx = 0.06*(S.xmax-S.xmin); if mx==0, mx=1; end
        my = 0.08*(S.ymax-S.ymin); if my==0, my=1; end
        xlo = S.xmin-mx; xhi = S.xmax+mx;
        ylo = S.ymin-my; yhi = S.ymax+my;
        if showResid
            for i = 1:numel(dx)
                line(axScatter,[dx(i) dx(i)],[dy(i) opt.m*dx(i)+opt.b], ...
                    'Color',[0.55 0.58 0.63 0.55],'LineWidth',0.8,'HitTest','off');
            end
        end
        scatter(axScatter,dx,dy,16,[0.5 0.5 0.5],'filled', ...
            'MarkerFaceAlpha',0.35,'MarkerEdgeColor','none','HitTest','off');
        legH = []; legS = {};
        for k = 1:numel(items)
            L = items(k);
            if isAnim(L), continue; end
            if strcmp(L.type,'test')
                h = plot(axScatter,[xlo xhi],[L.m*xlo+L.b L.m*xhi+L.b], ...
                    '-','Color',L.color,'LineWidth',2,'HitTest','off');
                legH(end+1) = h;
                legS{end+1} = sprintf('Test %d: y=%.2fx%s%.2f, R%c=%.3f', ...
                    L.no,L.m,signOf(L.b),abs(L.b),sup2,L.r2);
            else
                m = L.m; b = L.b;
                if isfinite(m) && isfinite(b) && abs(m)<1e4 && abs(b)<1e4
                    plot(axScatter,[xlo xhi],[m*xlo+b m*xhi+b], ...
                        '--','Color',L.color,'LineWidth',2,'HitTest','off');
                end
            end
        end
        hOpt = plot(axScatter,[xlo xhi],[opt.m*xlo+opt.b opt.m*xhi+opt.b], ...
            '-','Color',[0 0 0],'LineWidth',2.4,'HitTest','off');
        xlim(axScatter,[xlo xhi]); ylim(axScatter,[ylo yhi]);
        xlabel(axScatter,'x'); ylabel(axScatter,'y');
        title(axScatter,'Data and fitted lines','FontWeight','bold','Color',[0.06 0.07 0.08]);
        allH = [hOpt legH];
        allS = [{sprintf('Best fit: R%c=%.3f',sup2,opt.r2)} legS];
        if numel(allH) > 11
            allH = allH(1:11); allS = allS(1:11);
        end
        lg = legend(axScatter,allH,allS,'Location','northwest','FontSize',7.5, ...
            'AutoUpdate','off','Box','on');
        set(lg,'Color',[1 1 1]);
    end

    function drawSurf()
        if ~isfield(S,'n') || S.n == 0, return; end
        if ~isempty(get(axSurf,'Children'))
            try, surfView = get(axSurf,'View'); catch, end
        end
        cla(axSurf);
        set(axSurf,'NextPlot','add','Color',[1 1 1],'FontSize',9, ...
            'XColor',[0.41 0.44 0.50],'YColor',[0.41 0.44 0.50],'ZColor',[0.41 0.44 0.50]);
        colormap(axSurf,TURBO);
        d = domainCost();
        N = 32;
        mV = linspace(d(1),d(2),N);
        bV = linspace(d(3),d(4),N);
        [Mg,Bg] = meshgrid(mV,bV);
        Jg = Jcost(Mg,Bg);
        jmin = min(Jg(:)); jmax = max(Jg(:));
        surf(axSurf,Mg,Bg,Jg,'EdgeColor',[0.35 0.37 0.40],'LineWidth',0.25, ...
            'FaceColor','interp','FaceAlpha',1,'HitTest','off');
        for k = 1:numel(items)
            L = items(k);
            if isAnim(L), continue; end
            if strcmp(L.type,'gd') && ~isempty(L.path)
                seg = L.path;
                jm = min(max(seg(:,3),jmin),jmax);
                mm = seg(:,1); bb = seg(:,2);
                bad = ~arrayfun(@(i)sanePt(mm(i),bb(i)),(1:numel(mm))');
                mm(bad) = NaN; bb(bad) = NaN; jm(bad) = NaN;
                plot3(axSurf,mm,bb,jm,'-','Color',[0 0 0],'LineWidth',3.5,'HitTest','off');
                plot3(axSurf,mm,bb,jm,'-','Color',L.color,'LineWidth',2,'HitTest','off');
            end
        end
        for k = 1:numel(items)
            L = items(k);
            if strcmp(L.type,'test')
                jt = min(max(Jcost(L.m,L.b),jmin),jmax);
                plot3(axSurf,[L.m L.m],[L.b L.b],[jmin jt], ...
                    '-','Color',L.color,'LineWidth',2,'HitTest','off');
                plot3(axSurf,L.m,L.b,jt,'o','MarkerFaceColor',L.color, ...
                    'MarkerEdgeColor',[1 1 1],'MarkerSize',6,'HitTest','off');
            end
        end
        plot3(axSurf,opt.m,opt.b,opt.J,'o','MarkerFaceColor',[0 0 0], ...
            'MarkerEdgeColor',[1 1 1],'MarkerSize',8,'LineWidth',1,'HitTest','off');
        xlim(axSurf,[d(1) d(2)]); ylim(axSurf,[d(3) d(4)]);
        xlabel(axSurf,'Slope'); ylabel(axSurf,'Intercept'); zlabel(axSurf,'Cost J');
        title(axSurf,'3D cost surface','FontWeight','bold','Color',[0.06 0.07 0.08]);
        grid(axSurf,'on');
        view(axSurf,surfView(1),surfView(2));
        if isempty(cbSurf) || ~ishandle(cbSurf)
            cbSurf = colorbar(axSurf);
            cbSurf.Label.String = 'Cost J';
            cbSurf.Color = [0.41 0.44 0.50];
        end
    end

    function drawHeat()
        if ~isfield(S,'n') || S.n == 0, return; end
        cla(axHeat);
        set(axHeat,'NextPlot','add','Color',[1 1 1],'Box','on','Layer','top', ...
            'YDir','normal','FontSize',9, ...
            'XColor',[0.41 0.44 0.50],'YColor',[0.41 0.44 0.50]);
        colormap(axHeat,TURBO);
        if ~isempty(costDom)
            d = costDom;
        else
            d = domainCost();
        end
        N = 130;
        mV = linspace(d(1),d(2),N);
        bV = linspace(d(3),d(4),N);
        [Mg,Bg] = meshgrid(mV,bV);
        Jg = Jcost(Mg,Bg);
        Jlog = log10(max(Jg,1e-6));
        him = imagesc(axHeat,mV,bV,Jlog);
        set(him,'ButtonDownFcn',@onCostClick);
        lo = min(Jlog(:)); hi = max(Jlog(:));
        if hi <= lo, hi = lo + 1; end
        set(axHeat,'CLim',[lo hi]);
        Nc = 70;
        mC = linspace(d(1),d(2),Nc);
        bC = linspace(d(3),d(4),Nc);
        [Mc,Bc] = meshgrid(mC,bC);
        Jc = Jcost(Mc,Bc);
        levE = log(max(min(Jc(:)),1e-6));
        levH = log(max(max(Jc(:)),min(Jc(:))*1.0001+1e-6));
        levels = exp(levE + (levH-levE)*(1:9)/10);
        levels = unique(levels);
        if numel(levels) >= 2
            contour(axHeat,Mc,Bc,Jc,levels,'LineColor',[0.12 0.12 0.14], ...
                'LineWidth',0.6,'HitTest','off','PickableParts','none');
        end
        for k = 1:numel(items)
            L = items(k);
            if isAnim(L), continue; end
            if strcmp(L.type,'gd') && ~isempty(L.path)
                seg = L.path;
                mm = seg(:,1); bb = seg(:,2);
                bad = ~arrayfun(@(i)sanePt(mm(i),bb(i)),(1:numel(mm))');
                mm(bad) = NaN; bb(bad) = NaN;
                plot(axHeat,mm,bb,'-','Color',[0 0 0],'LineWidth',3.2, ...
                    'HitTest','off','PickableParts','none');
                plot(axHeat,mm,bb,'-','Color',L.color,'LineWidth',1.8, ...
                    'HitTest','off','PickableParts','none');
            end
        end
        for k = 1:numel(items)
            L = items(k);
            if strcmp(L.type,'test')
                line(axHeat,[L.m L.m],[d(3) L.b],'Color',L.color,'LineStyle','--', ...
                    'LineWidth',1,'HitTest','off','PickableParts','none');
                line(axHeat,[d(1) L.m],[L.b L.b],'Color',L.color,'LineStyle','--', ...
                    'LineWidth',1,'HitTest','off','PickableParts','none');
                plot(axHeat,L.m,L.b,'d','MarkerFaceColor',L.color, ...
                    'MarkerEdgeColor',[1 1 1],'MarkerSize',7,'LineWidth',1, ...
                    'HitTest','off','PickableParts','none');
            end
        end
        plot(axHeat,opt.m,opt.b,'o','MarkerFaceColor',[0 0 0], ...
            'MarkerEdgeColor',[1 1 1],'MarkerSize',8,'LineWidth',1.5, ...
            'HitTest','off','PickableParts','none');
        xlim(axHeat,[d(1) d(2)]); ylim(axHeat,[d(3) d(4)]);
        xlabel(axHeat,'Slope (m)'); ylabel(axHeat,'Intercept (b)');
        if isempty(cbHeat) || ~ishandle(cbHeat)
            cbHeat = colorbar(axHeat);
            cbHeat.Label.String = 'Cost J';
            cbHeat.Color = [0.41 0.44 0.50];
        end
        tk = linspace(lo,hi,5);
        set(cbHeat,'Ticks',tk);
        set(cbHeat,'TickLabels',arrayfun(@(t){fmtCost(10^t)},tk));
    end

    function drawConv()
        if ~isfield(S,'n') || S.n == 0, return; end
        cla(axConv);
        set(axConv,'NextPlot','add','Color',[1 1 1],'Box','on','YScale','log', ...
            'FontSize',9,'XColor',[0.41 0.44 0.50],'YColor',[0.41 0.44 0.50]);
        if ~isempty(items)
            runs = items(strcmp({items.type},'gd'));
        else
            runs = items([]);
        end
        maxIt = 1;
        if isfinite(opt.J), maxStart = opt.J; else, maxStart = 0.01; end
        jmn = inf;
        for k = 1:numel(runs)
            L = runs(k);
            maxIt = max(maxIt,size(L.path,1)-1);
            if isfinite(L.path(1,3)), maxStart = max(maxStart,L.path(1,3)); end
            jp = L.path(:,3);
            jp = jp(isfinite(jp) & jp<1e7);
            if ~isempty(jp), jmn = min(jmn,min(jp)); end
        end
        if isfinite(opt.J), jmn = min(jmn,opt.J); end
        if ~isfinite(jmn)
            if isfinite(opt.J), jmn = opt.J; else, jmn = 0.01; end
        end
        jmn = max(jmn*0.8,1e-6);
        jmx = max(maxStart*3, jmn*10);
        yo = opt.J;
        if isfinite(yo)
            line(axConv,[0 maxIt],[yo yo],'Color',[0.41 0.44 0.50], ...
                'LineStyle','--','LineWidth',1,'HitTest','off');
            text(axConv,maxIt,yo,' optimum','Color',[0.41 0.44 0.50], ...
                'FontSize',8,'VerticalAlignment','bottom','HorizontalAlignment','right');
        end
        for k = 1:numel(runs)
            L = runs(k);
            if isAnim(L), continue; end
            e = size(L.path,1)-1;
            yy = L.path(:,3);
            yy(~isfinite(yy)) = jmx;
            yy = min(max(yy,jmn),jmx);
            plot(axConv,0:e,yy,'-','Color',L.color,'LineWidth',2,'HitTest','off');
        end
        xlim(axConv,[0 maxIt]);
        ylim(axConv,[jmn jmx]);
        xlabel(axConv,'Iteration'); ylabel(axConv,'Cost J');
        title(axConv,'Gradient descent convergence','FontWeight','bold','Color',[0.06 0.07 0.08]);
        grid(axConv,'on');
    end

    function updateFit()
        set(txtFitEq,'String',sprintf('y = %.3f x %s %.3f',opt.m,signOf(opt.b),abs(opt.b)));
        set(txtFitR2,'String',sprintf('R%c = %.4f',sup2,opt.r2));
        set(txtFitJ,'String',sprintf('cost J = %.4f',opt.J));
    end

    function updateList()
        strs = {sprintf('Best fit: R%c=%.3f',sup2,opt.r2)};
        for k = 1:numel(items)
            strs{end+1} = items(k).label;
        end
        v = get(lstLines,'Value');
        if v > numel(strs), v = 1; end
        if v < 1, v = 1; end
        set(lstLines,'String',strs,'Value',v);
    end

    function updateStartPopup()
        strs = {'Custom start (use fields)'};
        startIds = NaN;
        for k = 1:numel(items)
            if strcmp(items(k).type,'test')
                strs{end+1} = sprintf('Test %d (m=%.2f, b=%.2f)', ...
                    items(k).no,items(k).m,items(k).b);
                startIds(end+1) = items(k).id;
            end
        end
        target = 1;
        if ~isnan(selStartId)
            pos = find(startIds == selStartId,1);
            if ~isempty(pos), target = pos; end
        end
        set(popStart,'Value',1);
        set(popStart,'String',strs);
        set(popStart,'Value',target);
    end

    function onStartChange(~,~)
        idx = get(popStart,'Value');
        if idx < 1 || idx > numel(startIds), return; end
        id = startIds(idx);
        if isnan(id)
            selStartId = NaN;
            return;
        end
        selStartId = id;
        L = findItem(id);
        if ~isempty(L)
            set(edM0,'String',sprintf('%.2f',L.m));
            set(edB0,'String',sprintf('%.2f',L.b));
        end
    end

    function onResid(src,~)
        showResid = get(src,'Value') == 1;
        drawScatter();
        hideBars();
    end

    function onCostReset(~,~)
        costDom = [];
        drawHeat();
        hideBars();
    end

    function onCostClick(~,~)
        if ~isempty(animItemId), return; end
        cp = get(axHeat,'CurrentPoint');
        m = cp(1,1); b = cp(1,2);
        set(edTestM,'String',sprintf('%.2f',m));
        set(edTestB,'String',sprintf('%.2f',b));
        set(edM0,'String',sprintf('%.2f',m));
        set(edB0,'String',sprintf('%.2f',b));
        addTest(m,b);
    end

    function onClose(~,~)
        stopAnim();
        delete(fig);
    end

    function notify(msg)
        set(statusBar,'String',msg);
    end

    function popMsg(msg)
        set(statusBar,'String',msg);
        try
            warndlg(msg,'Already added','modal');
        catch
        end
    end

    function secHeader(str)
        uicontrol('Parent',fig,'Style','text','Units','normalized', ...
            'Position',[XF takeY(0.024) WF 0.024],'String',str,'FontWeight','bold', ...
            'FontSize',12.5,'HorizontalAlignment','left','BackgroundColor',[1 1 1], ...
            'ForegroundColor',[0.06 0.07 0.08]);
        gap(0.004);
    end

    function h = leftText(hgt,fs,col,str)
        h = uicontrol('Parent',fig,'Style','text','Units','normalized', ...
            'Position',[XF takeY(hgt) WF hgt],'String',str,'FontSize',fs, ...
            'HorizontalAlignment','left','BackgroundColor',[1 1 1],'ForegroundColor',col);
    end

    function pairLabels(a,b)
        y = takeY(0.016);
        uicontrol('Parent',fig,'Style','text','Units','normalized', ...
            'Position',[XL y WL 0.016],'String',a,'FontSize',10, ...
            'HorizontalAlignment','left','BackgroundColor',[1 1 1],'ForegroundColor',[0.41 0.44 0.50]);
        uicontrol('Parent',fig,'Style','text','Units','normalized', ...
            'Position',[XR y WR 0.016],'String',b,'FontSize',10, ...
            'HorizontalAlignment','left','BackgroundColor',[1 1 1],'ForegroundColor',[0.41 0.44 0.50]);
    end

    function h = editL(str)
        h = uicontrol('Parent',fig,'Style','edit','Units','normalized', ...
            'Position',[XL Yc-0.028 WL 0.028],'String',str,'FontSize',10, ...
            'BackgroundColor',[1 1 1],'HorizontalAlignment','left');
    end

    function h = editR(str)
        h = uicontrol('Parent',fig,'Style','edit','Units','normalized', ...
            'Position',[XR Yc-0.028 WR 0.028],'String',str,'FontSize',10, ...
            'BackgroundColor',[1 1 1],'HorizontalAlignment','left');
    end

    function fullButton(str,cb)
        uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
            'Position',[XF takeY(0.034) WF 0.034],'String',str,'FontSize',10.5, ...
            'Callback',cb,'BackgroundColor',[0.42 0.45 0.49],'ForegroundColor',[1 1 1]);
    end

    function btnHalf(x,w,y,str,cb)
        uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
            'Position',[x y w 0.034],'String',str,'FontSize',10.5, ...
            'Callback',cb,'BackgroundColor',[0.42 0.45 0.49],'ForegroundColor',[1 1 1]);
    end

    function btnRect(x,w,y,str,cb)
        uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
            'Position',[x y w 0.034],'String',str,'FontSize',10,'Callback',cb, ...
            'BackgroundColor',[0.42 0.45 0.49],'ForegroundColor',[1 1 1]);
    end

    function mkCaption(pos,str)
        uicontrol('Parent',fig,'Style','text','Units','normalized', ...
            'Position',pos,'HorizontalAlignment','left','BackgroundColor',[1 1 1], ...
            'ForegroundColor',[0.41 0.44 0.50],'FontSize',8.5,'String',str);
    end

    function y = takeY(h)
        y = Yc - h;
        Yc = Yc - h;
    end

    function gap(g)
        Yc = Yc - g;
    end

end

function s = signOf(v)
    if v < 0, s = '-'; else, s = '+'; end
end

function it = blankItem()
    it = struct('id',0,'no',0,'type','test','m',0,'b',0,'J',0,'r2',0, ...
        'color',[0 0 0],'label','','srcTestId',NaN,'path',[], ...
        'diverged',false,'reached',false,'status','','alpha',0,'iters',0);
end

function v = numval(h,def)
    s = get(h,'String');
    if iscell(s), s = s{1}; end
    v = str2double(s);
    if isnan(v), v = def; end
end

function str = fmtCost(v)
    if v >= 1000
        str = sprintf('%.0f',v);
    elseif v >= 10
        str = sprintf('%.1f',v);
    elseif v >= 1
        str = sprintf('%.2f',v);
    else
        str = sprintf('%.3f',v);
    end
end

function P = paletteColors()
    P = [59 125 216; 214 69 65; 31 163 122; 155 89 182; 224 138 30; ...
         17 160 181; 214 73 154; 91 140 42; 124 92 255; 14 159 110] / 255;
end

function M = makeTurbo()
    A = [48 18 59; 50 80 196; 12 150 222; 20 205 170; 120 225 80; ...
         220 220 40; 250 150 40; 230 70 20; 122 4 3] / 255;
    nA = size(A,1);
    xq = linspace(0,1,256)';
    xp = linspace(0,1,nA)';
    M = [interp1(xp,A(:,1),xq), interp1(xp,A(:,2),xq), interp1(xp,A(:,3),xq)];
    M = min(1,max(0,M));
end
