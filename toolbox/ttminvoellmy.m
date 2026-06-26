function [H,T] = ttminvoellmy(DEM,H,options)
%TTMINVOELLMY Interface to Stefan Hergarten's rock avalanche model 
%
% Syntax
%
%     [H1,T] = ttminvoellmy(DEM,H0)
%     [H1,T] = ttminvoellmy(DEM,H0,'pn',pv,...)
%
% Description
%
%     This function provides a convenient interface to minvoellmy2d, a
%     software and solver to simulate rock avalanches using Stefan 
%     Hergarten's (2024) modified Voellmy rheology (see also here: 
%     http://hergarten.at/minvoellmy/).
%
% Input arguments
%
%     DEM     Digital elevation model (GRIDobj)
%     H0      Thickness of the mobile layer (GRIDobj). H0 must have the same
%             resolution and extent as DEM. Immobile pixels will have the
%             value zero. The initial surface is thus DEM+H0. 
%
%     Parameter name/value pairs
%
%     Physical parameters
%  
%     mu      Coulomb friction coefficient (default = 0.2)
%     xi      Bed roughness parameter (default = 500 m s^-2)
%     vc      Crossover velocity at h = 1; vc <= 0 switches to the 
%             conventional Voellmy rheology (default = 4 m s^-1) 
%     g       Gravitational acceleration (default 9.81 m s^-2)
%
%     Numerical parameters
%      
%     hmin       Minimum thickness [m] above which the layer can move 
%                (default = 0.001)
%     dmin       Lower limit for the denominator if the original expression 
%                for the pressure shall be used (default = 0 = modified 
%                pressure)
%     cent       Determines whether the effect of centripetal acceleration 
%                on friction is taken into account (default = true)
%     cfl        Courant-Friedrich-Lewis criterion (default = 0.7)
%
%     Simulation parameters
%
%     maxsteps   Maximum number (default = inf)
%     maxtime    Maximum time span (default = 500 s)
%     maxdt      Maximum time step (default = 1 s)
%
%     Visualization
%
%     plot       True or false (default = true). If true, the simulation 
%                will be shown in a 3D surface plot where coloring
%                indicates the thickness of the mobile layer.
%     plotfreq   Frequency at which plots are created. The value should be
%                higher than maxdt.
%     controls   True or false. If true, controls will be shown in a
%                separate window.
%     camorbit   Determines view angle (see function camorbit). 
%                (Default = [0 0])
%     clim       Color range. Default is [0 5].
%     colormap   Default is flipud(ttscm('batlowW',255,[20 100]))
%     video      true or false. If true, the function will write a gif or 
%                mp4, depending on extension provided in filename. The
%                frequency of new frames is given by plotfreq.
%     videofile  name of the gif. Default is 'minvoellmy.mp4'
%     position   four element vector indicating figure position. Note that
%                if a video/gif is created, the figure is nonresizable.
%
%     Output parameters
%
%     output     Create a table with times and intermediate results of the
%                thickness of the mobile layer. The value corresponds to
%                simulation time. output = 60, for example, means that
%                every an output is generated every 60 s simulation time.
%
% Output arguments
%
%     H1         Thickness of the mobile layer at the end of the simulation
%     T
%
% References
%
%     Hergarten, S.: Modeling the formation of toma hills based on fluid
%     dynamics with a modified Voellmy rheology, Earth Surface Dynamics,
%     12, 1193–1203, https://doi.org/10.5194/esurf-12-1193-2024, 2024a.
%     
%     Hergarten, S.: Scaling between volume and runout of rock avalanches
%     explained by a modified Voellmy rheology, Earth Surface Dynamics, 12,
%     219–229, https://doi.org/10.5194/esurf-12-219-2024, 2024b.
%
% See also: STREAMobj/STREAMobj2mapstruct 
%
% Author: Stefan Hergarten and 
%         Wolfgang Schwanghart
% Date: 26. June, 2025

arguments
    DEM   % GRIDobj of DEM: All units must be in [m]
    H     % GRIDobj of thickness of failed mass [m]
    options.mu = 0.2
    options.xi = 500
    options.vc (1,1) {mustBeNumeric,mustBeNonnegative} = 4   % crossover velocity [m s^-1]
    options.hmin (1,1) {mustBeNumeric,mustBeNonnegative} = 0.001
    options.dmin (1,1) {mustBeNumeric,mustBeNonnegative} = 0
    options.cent (1,1) = true
    options.g  (1,1) {mustBeNumeric}  = 9.81
    options.maxsteps (1,1) {mustBeNumeric,mustBeNonnegative} = inf
    options.maxtime (1,1) {mustBeNumeric,mustBeNonnegative} = 1000 % [s]
    options.maxdt (1,1) {mustBeNumeric,mustBeNonnegative} = 1% [s]
    options.cfl  (1,1) {mustBeNumeric,mustBeNonnegative}  = 0.7

    options.plot     (1,1) = true
    options.plotfreq = 2; % 2 seconds
    options.plotfun  = []
    options.plotmask = ~GRIDobj(DEM,'logical')
    options.camorbit (1,2) {mustBeNumeric} = [0,0] 
    options.video      (1,1) = false
    options.videoname  = 'minvoellmy.mp4'
    options.colormap = flipud(ttscm('batlowW',255,[20 100]))
    options.clim     (1,2) {mustBeNumeric} = [0, 5]
    options.controls = true
    options.output (1,1) {mustBeNumeric,mustBeNonnegative} = inf
    options.position (1,4) = [0.20 .1 .70 .80]
    options.camzoom (1,1) {mustBePositive} = 1
    options.backgroundcolor = ttclrr('skyblue')

end

% Do some input checking
validatealignment(DEM,H)
b = DEM.Z;
h = H.Z;

% Extract cell sizes
dx = DEM.cellsize;
dy = DEM.cellsize;

% Initiate the simulation class
o = minvoellmy2d(b,h,dx,dy,...
    options.mu,options.xi,options.vc,...
    options.hmin,options.dmin,options.cent,options.g);

% Preallocate array for flow depth
H  = DEM;

% counter
counter = 1;
% track time
t = 0;

% DEMp for plotting
DEMp = crop(DEM,options.plotmask);

% Set up figure and controls
if options.plot
    if options.controls
        fhcontrol = uifigure('Units','Normalized',...
            'Position',[0 .60 .20 .30],...
            'Name','Controls',...
            'NumberTitle','off','WindowStyle','alwaysontop');

        g = uigridlayout(fhcontrol,[4 1]);
        g.RowHeight = {'fit','1x','1x','1x'};
        g.ColumnWidth = {'1x'};
        htimetext   = uitextarea(g,"Value",num2str(0));
        hpausebutton = uibutton(g,"Text","Pause simulation",...
            "ButtonPushedFcn",@(btn,event) pauseOrContinueLoop());
        hstopbutton = uibutton(g,"Text","Stop simulation",...
            "ButtonPushedFcn",@(btn,event) stopLoop());
    end        

        % Create a variable to control the loop
        running = true;
        ispaused = false;
        drawnow

        % Create another axis with the figure
        fh  = figure('Units','Normalized','Position',options.position);
        if options.video
            % If a gif will be produced, then the figure should not be
            % resizable.
            fh.Resize = false;
            
            [folder,file,ext] = fileparts(options.videoname);
            switch lower(ext)
                case '.gif'
                    writegif = true;
                otherwise
                    writegif = false;
            end

        end
        ax  = axes("Parent",fh);
        ax.Position = [0 0 1 1];
        H.Z = o.h;
        Hp   = crop(H, options.plotmask);
        h    = surf(DEMp + Hp,Hp,'block',true,'parent',ax);
        camorbit(ax,options.camorbit(1),options.camorbit(2))
        colormap(ax,options.colormap)
        camlight
        camzoom(options.camzoom)

        % colorbar
        clim(options.clim)
        lastcamorbit = options.camorbit;

        axis off
        fh.Color = options.backgroundcolor;
        material dull

        subplotlabel(gca,['t = ' num2str(0,'%6.2f') ' s'],'Location','southwest');
        drawnow;

        % Gif
        if options.video
            if writegif
                gif(options.videoname, 'frame', fh,'overwrite',true)
            else
                v = VideoWriter(options.videoname,"MPEG-4");
                open(v)
            end
        end

        if options.controls
            hslider = uislider(g,'Value',options.camorbit(1),'Limits',[0 360],...
            'ValueChangingFcn',@(src,event,xr) setCamorbit());
        end
    
else
    running = true;
    ispaused = false;
end

if nargout == 2
    T = table(0,H,'VariableNames',{'Time','H'});
end

% Run loop    
while counter <= options.maxsteps && t <= options.maxtime && running

    dt = step(o,options.maxdt,options.cfl);
    t  = t+dt;
    
    if options.controls
    htimetext.Value = num2str(round(t,1));
    end
    % V.Z = sqrt(o.uh.^2 + o.vh.^2);

    while ispaused
        pause(0.2)
    end

    % Did we cross the time stepping for plotting?
    doplot = mod(t,options.plotfreq) < mod(t-dt,options.plotfreq);
        
    if counter == 1 || doplot
        H.Z = o.h;
        Hp   = crop(H, options.plotmask);

        h.ZData = DEMp.Z + Hp.Z;
        h.CData = Hp.Z;

        subplotlabel(gca,['t = ' num2str(t,'%6.2f') ' s'],'Location','southwest');
        drawnow; 
    end

    if options.video && (counter == 1 || doplot)
        if writegif
            gif
        else
            frame = getframe(gcf);
            writeVideo(v,frame)
        end
    end
    
    if nargout == 2
        if ~isinf(options.output) && ...
                mod(t,options.output) < mod(t-dt,options.output)
            H.Z = o.h;
            T   = [T;table(t,H,'VariableNames',{'Time','H'})];
        end
    end

    % u = max(o.uh(:));
    counter = counter +1 ;
end

H.Z = o.h;

if options.controls
    close(fhcontrol)
end
if options.video
    if writegif
        gif('clear')
    else
        close(v)
    end
end


% Nested functions 
    function stopLoop()
        running = false;
    end
    function pauseOrContinueLoop()
        if ~ispaused 
            ispaused = true;
            hpausebutton.Text = 'Resume simulation';
        else
            ispaused = false;
            hpausebutton.Text = 'Pause simulation';
        end
    end
    function setCamorbit()
        co = lastcamorbit;
        val = hslider.Value;
        newvalue = val-co(1);
        camorbit(ax,newvalue,0)
        lastcamorbit(1) = newvalue;
    end

end
