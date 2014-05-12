
%data logger used with the gsMotes
%author: Vlad
function DataLogger

    h.fig = figure('position', [700 300 400 500]);
    ComPorts = getAvailableComPort;
    h.NumMotesBox = uicontrol('style', 'edit', 'position', [10 450 100 20]);
    h.ComPorts = uicontrol('style', 'popupmenu', 'string', ComPorts(1:end), 'max', 1, 'min', 1, 'position', [120 450 100 20], 'callback', {@UpdateList, h});
    h.Rescan = uicontrol('style', 'pushbutton', 'position', [120 475 100 20], 'string', 'Connect', 'callback', {@Connect, h});
    h.StartButton = uicontrol('style', 'pushbutton', 'position', [10 400 100 40], 'string', 'Start', 'callback', {@Start, h});
    h.StopButton = uicontrol('style', 'pushbutton', 'position', [10 350 100 40], 'string', 'Stop', 'callback', {@Stop, h});
    h.NumMotesText = uicontrol('style', 'text', 'position', [10 475 100 20], 'string', 'number of motes');
    h.Close = uicontrol('style', 'pushbutton', 'position', [10 300 100 40], 'string', 'Close', 'callback', {@Close, h});
    h.SaveDataButton = uicontrol('style', 'pushbutton', 'position', [120 300 100 40], 'string', 'Save Data', 'callback', {@SaveData, h});
    guidata(h.fig,h);
end

%tell all motes to start sampling
function Start(hObject, eventdata, h)

    %get object handles and other relevant data
    h = guidata(hObject);
    %read number of motes entered in textbox
    h.NumMotes = str2double(get(h.NumMotesBox, 'string'));
    %check if proper value entered
    if (isnan(h.NumMotes) || rem(h.NumMotes,1) ~= 0 || h.NumMotes < 1)
        errordlg('not a valid number of motes');
    %check if connected to serial device
    elseif (~isfield(h,'SerialPort') || ~isa(h.SerialPort,'serial') || ~isvalid(h.SerialPort))
        errordlg('not connected to a serial device');    
    else
        %send the start command
        fwrite(h.SerialPort,3,'uchar');
        fwrite(h.SerialPort,255,'uchar');
        fwrite(h.SerialPort,255,'uchar');
        fwrite(h.SerialPort,'R','uchar');
    end
    %save object handles and other relevant data
    guidata(hObject,h);
end

%tell all the motes to stop sampling
%then collect data from all the motes (determined by number of motes 
%entered into textbox)
%lastly, graph the collected data (normalized and offset based on mote 
%number as well as raw data)
function Stop(hObject, eventdata, h)
    
    %get object handles and other relevant data
    h = guidata(hObject);
    %check if connected to serial device
    if (~isfield(h,'SerialPort') || ~isa(h.SerialPort,'serial') || ~isvalid(h.SerialPort))
        errordlg('not connected to a serial device');
    
    else
        
        %read number of motes entered in textbox
        h.NumMotes = str2double(get(h.NumMotesBox, 'string'));
        %check if proper value entered
        if (isnan(h.NumMotes) || rem(h.NumMotes,1) ~= 0 || h.NumMotes < 1)
            errordlg('not a valid number of motes');
        else
            %send the stop command
            fwrite(h.SerialPort,3,'uchar');
            fwrite(h.SerialPort,255,'uchar');
            fwrite(h.SerialPort,255,'uchar');
            fwrite(h.SerialPort,'S','uchar');
            %collect data from each mote
            for i=1:h.NumMotes
                %issue transmit command
                fwrite(h.SerialPort,3,'uchar');
                fwrite(h.SerialPort,i,'uint16');
                fwrite(h.SerialPort,'T','uchar');
                %wait for data
                start = clock;
                h.data.(sprintf('m%d',i)) = [];
                while true
                    %if data is received, read it into the data structure
                    %with a field name corresponding to the mote number of
                    %the transmitting mote
                    if get(h.SerialPort, 'BytesAvailable') >= 4
                       IntsToRead = idivide(get(h.SerialPort, 'BytesAvailable'),int32(4));
                       h.data.(sprintf('m%d',i)) = cat(1,h.data.(sprintf('m%d',i)),fread(h.SerialPort,double(IntsToRead),'int32')); 
                       start = clock;
                    end
                    %wait 2 seconds to time out waiting on further data
                    %from this mote
                    if etime(clock,start)>2
                        break;
                    end
                end

            end
            %normalize data between 0 and 1 and add an offset to each data
            %set based on the mote number corresponsing to it 
            NormData = [];
            for i=1:size(fieldnames(h.data),1)
                MaxVal = max(h.data.(sprintf('m%d',i)));
                MinVal = min(h.data.(sprintf('m%d',i)));
                for n=1:size(h.data.(sprintf('m%d',i)),1)
                    NormData.(sprintf('m%d',i))(n,1) = (h.data.(sprintf('m%d',i))(n,1)-MinVal)/(MaxVal-MinVal) + ((i-1)*2);
                end    
            end

            %create 2 new figures and add their handles to the array
            %containing handles of plots
            if isfield(h,'plots')
                h.plots(end+1) = figure();
                h.plots(end+1) = figure();
            else
                h.plots(1) = figure();
                h.plots(2) = figure();
            end
            %plot the raw and normalized data (on separate plots)
            for i=1:h.NumMotes
                figure(h.plots(end-1));
                hold on;
                plot(NormData.(sprintf('m%d',i)));
                figure(h.plots(end));
                hold on;
                plot(h.data.(sprintf('m%d',i)));
            end

            %save object handles and other relevant data
            guidata(hObject,h);
        end
    end
end

%open a connection to a serial device
function Connect(hObject, eventdata, h)

    %get object handles and other relevant data
    h = guidata(hObject);
    %if not connected to a serial port
    if strcmp(get(hObject,'string'),'Connect')
        %get selected serial port from popupmenu
        values = get(h.ComPorts,'string');
        PortName = values(get(h.ComPorts, 'value'));
        %connect to this serial port
        h.SerialPort = serial(PortName, 'BaudRate', 57600);
        fopen(h.SerialPort);
        %change the button text to 'Disconnect' and disable the serial 
        %port popupmenu
        set(hObject,'string','Disconnect');
        set(h.ComPorts,'enable','off');
    %otherwise already connected to a serial port so do the following 
    %instead    
    else
        %if connected to serial port then close the connection and delete 
        %the serial port object
        if (isfield(h,'SerialPort') && isa(h.SerialPort,'serial') && isvalid(h.SerialPort))
            fclose(h.SerialPort);
            delete(h.SerialPort);
        end
        %change the button text to 'Connect' and enable the serial port 
        %popupmenu
        set(hObject,'string','Connect');
        set(h.ComPorts,'enable','on');
    end
    %save object handles and other relevant data
    guidata(hObject,h);
end

%close the GUI and all associated figures and serial connections
function Close(hObject, eventdata, h)

    %get object handles and other relevant data
    h = guidata(hObject);
    %check if serial port exists and close it
    if (isfield(h,'SerialPort') && isa(h.SerialPort,'serial') && isvalid(h.SerialPort))
        fclose(h.SerialPort);
    	delete(h.SerialPort);
    end
    %close any open graphs
    if (isfield(h,'plots'))
        for i=1:size((h.plots),2)
            if ishandle(h.plots(i))
               close(h.plots(i)); 
            end
        end
    end
    %close the gui
    close(h.fig);
end

%save the most recently collected data set
function SaveData(hObject, eventdata, h)

    %get object handles and other relevant data
    h = guidata(hObject);
    if (h.NumMotes > 0)
        %get current system time
        time = clock;
        %save the most recently collected data to files (one file per mote)
        %with file name consisting of date, time and mote number
        for i=1:size(fieldnames(h.data),1)
            fp = fopen(strcat(date,'-',num2str(time(4)),'_',num2str(time(5)),'_',num2str(round(time(6))),'-','mote_',int2str(i),'.txt'),'w');
            fwrite(fp,h.data.(sprintf('m%d',i)),'int32');
            fclose(fp);
        end
        %save the data as matlab file also (all mote data in one file)
        save(strcat(date,'-',num2str(time(4)),'_',num2str(time(5)),'_',num2str(round(time(6))),'-','data.mat'),'-struct','h','data');
    end
end

%update the serial port selection popupmenu
function UpdateList(hObject, eventdata, h)

    %update available com ports displayed in popupmenu
    ComPorts = getAvailableComPort;
    set(hObject,'string',ComPorts(1:end));
end
