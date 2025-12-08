function SmartRuler_TwoOptions

    f = figure('Name','Smart Ruler - Manual & AI Reference', ...
               'NumberTitle','off', ...
               'Color',[0.2 0.2 0.2], ...
               'Position',[150 100 1000 560]);

    axRef = axes('Parent',f, 'Units','normalized', ...
                 'Position',[0.05 0.30 0.40 0.63]);
    title(axRef,'Reference Image','Color','w');
    axis(axRef,'off');

    axMeas = axes('Parent',f, 'Units','normalized', ...
                  'Position',[0.55 0.30 0.40 0.63]);
    title(axMeas,'Measurement Image','Color','w');
    axis(axMeas,'off');

    uistack(axRef,'bottom');
    uistack(axMeas,'bottom');

    statusText = uicontrol('Parent',f,'Style','text', ...
        'Units','normalized', 'Position',[0.05 0.05 0.60 0.10], ...
        'String','Step 1/4: Load a reference image.', ...
        'ForegroundColor','w', 'BackgroundColor',[0.2 0.2 0.2], ...
        'HorizontalAlignment','left', 'FontSize',10);

    uicontrol('Parent',f,'Style','pushbutton','String','Load Reference Image', ...
        'Units','normalized','Position',[0.05 0.17 0.19 0.06], ...
        'Callback',@loadRefCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Set Reference Manually', ...
        'Units','normalized','Position',[0.26 0.17 0.19 0.06], ...
        'Callback',@setManualRefCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Known Object Reference', ...
        'Units','normalized','Position',[0.05 0.10 0.19 0.05], ...
        'Callback',@knownObjectRefCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Auto Detect A4 (AI)', ...
        'Units','normalized','Position',[0.26 0.10 0.19 0.05], ...
        'Callback',@autoA4RefCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Load Measurement Image', ...
        'Units','normalized','Position',[0.55 0.17 0.19 0.06], ...
        'Callback',@loadMeasCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Measure Object', ...
        'Units','normalized','Position',[0.76 0.17 0.19 0.06], ...
        'Callback',@measureObjectCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Undo Last', ...
        'Units','normalized','Position',[0.55 0.10 0.19 0.05], ...
        'Callback',@undoLastCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Clear Measurements', ...
        'Units','normalized','Position',[0.76 0.10 0.19 0.05], ...
        'Callback',@clearMeasurementsCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Clear All', ...
        'Units','normalized','Position',[0.45 0.08 0.10 0.05], ...
        'Callback',@clearAllCallback);

    resultTable = uitable('Parent',f,'Units','normalized', ...
        'Position',[0.55 0.02 0.40 0.07], ...
        'Data',{}, 'ColumnName',{'#','Length'}, ...
        'ColumnEditable',[false false]);

    % --------- ???????? ?????? ---------
    refImg        = [];
    measImg       = [];
    pixelsPerUnit = NaN;
    unitName      = 'cm';
    scaleSet      = false;
    measCount     = 0;

    measLines = gobjects(0);
    measTexts = gobjects(0);

    % ???????? ???? ?????? ???????
    zoomFig  = [];
    zoomAx   = [];
    clickXs  = [];
    clickYs  = [];
    isMeasuring = false;

    % ================== Reference Callbacks ==================

    function loadRefCallback(~,~)
        [file,path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp','Image Files'}, ...
                                 'Select reference image');
        if isequal(file,0)
            set(statusText,'String','Status: Reference image not selected.');
            return;
        end
        refImg = imread(fullfile(path,file));
        axes(axRef); imshow(refImg);
        title(axRef,['Reference: ',file],'Color','w','Interpreter','none');
        set(statusText,'String','Step 2/4: Set reference (manual / known object / A4).');
        scaleSet      = false;
        pixelsPerUnit = NaN;
        unitName      = 'cm';
    end

    function setManualRefCallback(~,~)
        if isempty(refImg)
            set(statusText,'String','Status: Load reference image first.');
            return;
        end

        axes(axRef);
        title(axRef,'Click two points on the known-length object','Color','y');
        [x,y] = ginput(2);

        dx = x(2)-x(1);
        dy = y(2)-y(1);
        refPixelDist = sqrt(dx^2 + dy^2);

        if refPixelDist < 1e-3
            set(statusText,'String','Status: Reference points too close.');
            title(axRef,'Reference Image','Color','w');
            return;
        end

        hold(axRef,'on');
        plot(axRef,x,y,'y-','LineWidth',2);
        plot(axRef,x,y,'yo','MarkerSize',6,'MarkerFaceColor','y');
        hold(axRef,'off');

        answer = inputdlg({'Real length of reference:','Unit (e.g. cm, mm, inch):'}, ...
                          'Manual Reference',1,{'10','cm'});
        if isempty(answer)
            set(statusText,'String','Status: Manual reference cancelled.');
            title(axRef,'Reference Image','Color','w');
            return;
        end

        realLength = str2double(answer{1});
        if isnan(realLength) || realLength <= 0
            set(statusText,'String','Status: Invalid reference length.');
            title(axRef,'Reference Image','Color','w');
            return;
        end

        unitName = strtrim(answer{2});
        if isempty(unitName)
            unitName = 'cm';
        end

        pixelsPerUnit = refPixelDist / realLength;
        scaleSet      = true;

        set(statusText,'String',sprintf( ...
            'Step 3/4: Reference set (%.2f pixels = 1 %s). Now load measurement image.', ...
            pixelsPerUnit, unitName));
        title(axRef,'Reference Image','Color','w');
    end

    function knownObjectRefCallback(~,~)
        if isempty(refImg)
            set(statusText,'String','Status: Load reference image first.');
            return;
        end

        objs  = getKnownObjectsDb();
        names = {objs.name};
        lens  = [objs.length_cm];

        [idx,ok] = listdlg('PromptString','Select the known object:', ...
                           'ListString',names, ...
                           'SelectionMode','single');
        if ~ok
            set(statusText,'String','Status: Known object selection cancelled.');
            return;
        end

        chosenName   = names{idx};
        chosenLength = lens(idx);

        axes(axRef);
        title(axRef,['Click two points along: ', chosenName], ...
              'Color','y','Interpreter','none');
        [x,y] = ginput(2);

        dx = x(2)-x(1);
        dy = y(2)-y(1);
        refPixelDist = sqrt(dx^2 + dy^2);

        if refPixelDist < 1e-3
            set(statusText,'String','Status: Reference points too close.');
            title(axRef,'Reference Image','Color','w');
            return;
        end

        hold(axRef,'on');
        plot(axRef,x,y,'y-','LineWidth',2);
        plot(axRef,x,y,'yo','MarkerSize',6,'MarkerFaceColor','y');
        hold(axRef,'off');

        realLength = chosenLength;
        unitName   = 'cm';

        pixelsPerUnit = refPixelDist / realLength;
        scaleSet      = true;

        set(statusText,'String',sprintf( ...
            'Step 3/4: %s chosen (%.2f pixels = 1 %s). Now load measurement image.', ...
            chosenName, pixelsPerUnit, unitName));
        title(axRef,'Reference Image','Color','w');
    end

    function autoA4RefCallback(~,~)
        if isempty(refImg)
            set(statusText,'String','Status: Load reference image first.');
            return;
        end

        bbox = detectA4BoundingBox(refImg);
        if isempty(bbox)
            set(statusText,'String','Status: Could NOT detect an A4-like rectangle.');
            return;
        end

        axes(axRef);
        imshow(refImg);
        hold(axRef,'on');
        rectangle('Position',bbox,'EdgeColor','g','LineWidth',2);
        hold(axRef,'off');
        title(axRef,'Reference Image (A4 detected)','Color','g');

        w = bbox(3);
        h = bbox(4);

        shortSidePixels = min(w,h);
        realShort_cm    = 21.0;
        pixelsPerUnit   = shortSidePixels / realShort_cm;
        unitName        = 'cm';

        scaleSet = true;
        set(statusText,'String',sprintf( ...
            'Step 3/4: A4 detected (~%.2f pixels = 1 cm). Now load measurement image.', ...
            pixelsPerUnit));
    end

    % ================== Measurement Side ==================

    function loadMeasCallback(~,~)
        [file,path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp','Image Files'}, ...
                                 'Select measurement image');
        if isequal(file,0)
            set(statusText,'String','Status: Measurement image not selected.');
            return;
        end
        measImg = imread(fullfile(path,file));
        axes(axMeas); imshow(measImg);
        title(axMeas,['Measurement: ',file],'Color','w','Interpreter','none');

        measCount        = 0;
        resultTable.Data = {};
        deleteValid(measLines);
        deleteValid(measTexts);
        measLines = gobjects(0);
        measTexts = gobjects(0);

        set(statusText,'String', ...
            'Step 4/4: Measurement image loaded. Click "Measure Object" to measure multiple objects.');
    end

    function measureObjectCallback(~,~)
        if isempty(measImg)
            set(statusText,'String','Status: Load measurement image first.');
            return;
        end
        if ~scaleSet || isnan(pixelsPerUnit)
            set(statusText,'String','Status: Set reference first (manual / known object / A4).');
            return;
        end
        if isMeasuring
            set(statusText,'String','Status: Already measuring. Finish current measurement first.');
            return;
        end

        axes(axMeas);
        title(axMeas,'Click two points on the object to measure','Color','c');

        % ???? ?????
        if ~isempty(zoomFig) && isvalid(zoomFig)
            delete(zoomFig);
        end
        zoomFig = figure('Name','Zoom','NumberTitle','off', ...
                         'MenuBar','none','ToolBar','none', ...
                         'Color','k','Position',[50 50 220 220]);
        zoomAx = axes('Parent',zoomFig,'Position',[0 0 1 1]);

        clickXs = [];
        clickYs = [];
        isMeasuring = true;

        set(f,'WindowButtonMotionFcn',@updateZoom);
        set(f,'WindowButtonDownFcn',@onFigureClick);
        set(f,'Pointer','crosshair');

        set(statusText,'String','Status: Move over measurement image and left-click two points.');
    end

    function onFigureClick(~,~)
        if ~isMeasuring
            return;
        end

        % ????? ?? ?????? ??? ????? ??? ???? ??????
        hObj = hittest(f);
        axParent = ancestor(hObj,'axes');
        if isempty(axParent) || axParent ~= axMeas
            return;
        end

        C = get(axMeas,'CurrentPoint');
        cx = C(1,1);
        cy = C(1,2);

        xl = xlim(axMeas);
        yl = ylim(axMeas);
        if cx < xl(1) || cx > xl(2) || cy < yl(1) || cy > yl(2)
            return;
        end

        clickXs(end+1) = cx;
        clickYs(end+1) = cy;

        if numel(clickXs) == 2
            finishMeasurement();
        end
    end

    function updateZoom(~,~)
        if ~isMeasuring
            return;
        end
        if isempty(measImg) || ~ishandle(axMeas) || isempty(zoomFig) || ~ishandle(zoomAx)
            return;
        end

        C = get(axMeas,'CurrentPoint');
        cx = round(C(1,1));
        cy = round(C(1,2));

        if cx<=0 || cy<=0 || cx>size(measImg,2) || cy>size(measImg,1)
            return;
        end

        r = 25;
        x1 = max(1,cx-r);  x2 = min(size(measImg,2),cx+r);
        y1 = max(1,cy-r);  y2 = min(size(measImg,1),cy+r);

        zoomCrop = measImg(y1:y2, x1:x2, :);
        zoomCrop = imresize(zoomCrop,5);

        axes(zoomAx);
        imshow(zoomCrop);
        hold(zoomAx,'on');

        [hgt,wdt,~] = size(zoomCrop);
        cxz = wdt/2;
        cyz = hgt/2;
        plot(zoomAx,[cxz-8 cxz+8],[cyz cyz],'r-','LineWidth',1.5);
        plot(zoomAx,[cxz cxz],[cyz-8 cyz+8],'r-','LineWidth',1.5);

        hold(zoomAx,'off');
    end

    function finishMeasurement()
        % ????? ??? ?????? ??????
        isMeasuring = false;
        set(f,'WindowButtonMotionFcn','');
        set(f,'WindowButtonDownFcn','');
        set(f,'Pointer','arrow');
        if ~isempty(zoomFig) && isvalid(zoomFig)
            delete(zoomFig);
        end

        if numel(clickXs) < 2
            set(statusText,'String','Status: Measurement cancelled.');
            title(axMeas,'Measurement Image','Color','w');
            return;
        end

        x = clickXs(1:2);
        y = clickYs(1:2);

        dx = x(2)-x(1);
        dy = y(2)-y(1);
        distPixels = sqrt(dx^2 + dy^2);
        if distPixels < 1e-3
            set(statusText,'String','Status: Measurement points too close.');
            title(axMeas,'Measurement Image','Color','w');
            return;
        end

        axes(axMeas);
        hold(axMeas,'on');
        hLine = plot(axMeas,x,y,'c-','LineWidth',2);
        plot(axMeas,x,y,'co','MarkerSize',6,'MarkerFaceColor','c');
        mx = mean(x);
        my = mean(y);
        hTxt  = text(axMeas,mx,my,'','Color','c', ...
                     'FontSize',9,'FontWeight','bold', ...
                     'HorizontalAlignment','center', ...
                     'VerticalAlignment','bottom');
        hold(axMeas,'off');

        distUnits = distPixels / pixelsPerUnit;

        measCount = measCount + 1;
        labelStr  = sprintf('%d (%.2f %s)',measCount,distUnits,unitName);
        set(hTxt,'String',labelStr);

        measLines(end+1) = hLine;
        measTexts(end+1) = hTxt;

        resultTable.Data = [resultTable.Data; ...
            {measCount, sprintf('%.2f %s',distUnits,unitName)}];

        set(statusText,'String',sprintf( ...
            'Status: Measurement %d = %.2f %s (you can measure another object).', ...
             measCount, distUnits, unitName));
        title(axMeas,'Measurement Image','Color','w');
    end

    % ================== Misc Buttons ==================

    function undoLastCallback(~,~)
        if isMeasuring
            return; % ?? ???? ?????? ??????
        end
        if measCount <= 0
            set(statusText,'String','Status: No measurements to undo.');
            return;
        end

        deleteValid(measLines(end));
        deleteValid(measTexts(end));
        measLines(end) = [];
        measTexts(end) = [];

        data = resultTable.Data;
        if ~isempty(data)
            data(end,:) = [];
            resultTable.Data = data;
        end

        measCount = measCount - 1;

        if measCount == 0
            set(statusText,'String', ...
                'Status: All measurements removed. You can start measuring again.');
        else
            set(statusText,'String', ...
                sprintf('Status: Undid last measurement. %d remaining.',measCount));
        end
    end

    function clearMeasurementsCallback(~,~)
        if isMeasuring
            return;
        end
        measCount        = 0;
        resultTable.Data = {};
        deleteValid(measLines);
        deleteValid(measTexts);
        measLines = gobjects(0);
        measTexts = gobjects(0);

        if ~isempty(measImg)
            axes(axMeas); imshow(measImg);
            title(axMeas,'Measurement Image','Color','w');
        end

        set(statusText,'String', ...
            'Status: All measurements cleared. You can start measuring again.');
    end

    function clearAllCallback(~,~)
        if isMeasuring
            return;
        end
        refImg        = [];
        measImg       = [];
        pixelsPerUnit = NaN;
        unitName      = 'cm';
        scaleSet      = false;

        measCount        = 0;
        resultTable.Data = {};
        deleteValid(measLines);
        deleteValid(measTexts);
        measLines = gobjects(0);
        measTexts = gobjects(0);

        axes(axRef); cla(axRef); axis(axRef,'off');
        title(axRef,'Reference Image','Color','w');

        axes(axMeas); cla(axMeas); axis(axMeas,'off');
        title(axMeas,'Measurement Image','Color','w');

        set(statusText,'String','Step 1/4: Cleared. Load a new reference image.');
    end

    function deleteValid(h)
        if isempty(h), return; end
        for k = 1:numel(h)
            if isgraphics(h(k))
                delete(h(k));
            end
        end
    end

end

% ================== Helper: A4 Detection ==================
function bbox = detectA4BoundingBox(img)

    if size(img,3)==3
        g = rgb2gray(img);
    else
        g = img;
    end

    g = im2double(g);

    T_otsu = graythresh(g);
    T      = max(T_otsu, 0.7);
    mask   = g > T;

    mask = imfill(mask,'holes');
    mask = imopen(mask, strel('rectangle',[7 7]));

    imgArea = numel(g);
    minArea = imgArea * 0.05;
    mask    = bwareaopen(mask, round(minArea));

    stats = regionprops(mask,'BoundingBox','Area');
    if isempty(stats)
        bbox = [];
        return;
    end

    targetRatio = 29.7 / 21.0;
    bestScore   = 0;
    bestBox     = [];

    for k = 1:numel(stats)
        bb = stats(k).BoundingBox;
        w = bb(3);
        h = bb(4);

        ratio      = max(w,h) / min(w,h);
        ratioScore = 1 / (1 + abs(ratio - targetRatio));
        score      = ratioScore * stats(k).Area;

        if score > bestScore
            bestScore = score;
            bestBox   = bb;
        end
    end

    if bestScore == 0
        bbox = [];
    else
        bbox = bestBox;
    end
end

% ================== Known Objects DB ==================
function objs = getKnownObjectsDb()
    objs(1).name      = 'Credit / Bank Card (long side)';
    objs(1).length_cm = 8.56;

    objs(2).name      = 'ID Card (long side)';
    objs(2).length_cm = 8.56;

    objs(3).name      = 'AA Battery (length)';
    objs(3).length_cm = 5.0;

    objs(4).name      = 'Standard A4 Short Side';
    objs(4).length_cm = 21.0;

    objs(5).name      = 'Coin ~2.4 cm diameter';
    objs(5).length_cm = 2.4;

    objs(6).name      = 'Generic Pen (body length)';
    objs(6).length_cm = 14.0;

    objs(7).name      = 'Phone (approx. 15 cm height)';
    objs(7).length_cm = 15.0;
end


