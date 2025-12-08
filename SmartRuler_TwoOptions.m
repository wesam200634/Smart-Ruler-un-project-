function SmartRuler_TwoOptions

    f = figure('Name','Smart Ruler - Manual & AI Reference', ...
               'NumberTitle','off', ...
               'Color',[0.2 0.2 0.2], ...
               'Position',[150 100 1000 560]);

    axRef = axes('Parent',f, 'Units','normalized', ...
                 'Position',[0.05 0.25 0.40 0.7]);
    title(axRef,'Reference Image','Color','w');
    axis(axRef,'off');

    axMeas = axes('Parent',f, 'Units','normalized', ...
                  'Position',[0.55 0.25 0.40 0.7]);
    title(axMeas,'Measurement Image','Color','w');
    axis(axMeas,'off');

    statusText = uicontrol('Parent',f,'Style','text', ...
        'Units','normalized', 'Position',[0.05 0.05 0.60 0.10], ...
        'String','Status: Load a reference image.', ...
        'ForegroundColor','w', 'BackgroundColor',[0.2 0.2 0.2], ...
        'HorizontalAlignment','left', 'FontSize',10);

    uicontrol('Parent',f,'Style','pushbutton','String','Load Reference Image', ...
        'Units','normalized','Position',[0.05 0.17 0.19 0.06], ...
        'Callback',@loadRefCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Set Reference Manually', ...
        'Units','normalized','Position',[0.26 0.17 0.19 0.06], ...
        'Callback',@setManualRefCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Auto Detect A4 (AI)', ...
        'Units','normalized','Position',[0.05 0.10 0.40 0.05], ...
        'Callback',@autoA4RefCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Load Measurement Image', ...
        'Units','normalized','Position',[0.55 0.17 0.19 0.06], ...
        'Callback',@loadMeasCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Measure Object', ...
        'Units','normalized','Position',[0.76 0.17 0.19 0.06], ...
        'Callback',@measureObjectCallback);

    uicontrol('Parent',f,'Style','pushbutton','String','Clear All', ...
        'Units','normalized','Position',[0.45 0.08 0.10 0.05], ...
        'Callback',@clearAllCallback);

    resultTable = uitable('Parent',f,'Units','normalized', ...
        'Position',[0.55 0.05 0.39 0.08], ...
        'Data',{}, 'ColumnName',{'#','Length'}, ...
        'ColumnEditable',[false false]);

    refImg        = [];
    measImg       = [];
    pixelsPerUnit = NaN;
    unitName      = 'cm';
    scaleSet      = false;
    measCount     = 0;

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
        set(statusText,'String','Status: Reference image loaded. Choose manual or AI reference.');
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

        set(statusText,'String',sprintf('Status: Manual reference set. %.2f pixels = 1 %s.', ...
                                         pixelsPerUnit, unitName));
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
            'Status: A4 detected. ~%.2f pixels = 1 cm (short side = 21 cm).', ...
            pixelsPerUnit));
    end

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
        measCount = 0;
        resultTable.Data = {};
        set(statusText,'String','Status: Measurement image loaded. Click "Measure Object".');
    end

    function measureObjectCallback(~,~)
        if isempty(measImg)
            set(statusText,'String','Status: Load measurement image first.');
            return;
        end
        if ~scaleSet || isnan(pixelsPerUnit)
            set(statusText,'String','Status: Set reference first (manual or AI).');
            return;
        end

        axes(axMeas);
        title(axMeas,'Click two points on the object to measure','Color','c');
        [x,y] = ginput(2);

        dx = x(2)-x(1);
        dy = y(2)-y(1);
        distPixels = sqrt(dx^2 + dy^2);
        if distPixels < 1e-3
            set(statusText,'String','Status: Measurement points too close.');
            title(axMeas,'Measurement Image','Color','w');
            return;
        end

        hold(axMeas,'on');
        plot(axMeas,x,y,'c-','LineWidth',2);
        plot(axMeas,x,y,'co','MarkerSize',6,'MarkerFaceColor','c');
        hold(axMeas,'off');

        distUnits = distPixels / pixelsPerUnit;

        measCount = measCount + 1;
        resultTable.Data = [resultTable.Data; ...
            {measCount, sprintf('%.2f %s',distUnits,unitName)}];

        set(statusText,'String',sprintf('Status: Measurement %d = %.2f %s', ...
                                         measCount, distUnits, unitName));
        title(axMeas,'Measurement Image','Color','w');
    end

    function clearAllCallback(~,~)
        refImg        = [];
        measImg       = [];
        pixelsPerUnit = NaN;
        unitName      = 'cm';
        scaleSet      = false;
        measCount     = 0;
        resultTable.Data = {};

        axes(axRef); cla(axRef); axis(axRef,'off');
        title(axRef,'Reference Image','Color','w');

        axes(axMeas); cla(axMeas); axis(axMeas,'off');
        title(axMeas,'Measurement Image','Color','w');

        set(statusText,'String','Status: Cleared. Load a new reference image.');
    end

end

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

        score = ratioScore * stats(k).Area;

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
