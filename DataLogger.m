function DataLogger
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

h.fig = figure('position', [700 300 400 500]);
ComPorts = getAvailableComPort;
h.NumMotes = uicontrol('style', 'edit', 'position', [10 450 100 20]);
h.ComPorts = uicontrol('style', 'popupmenu', 'string', ComPorts(1:end), 'max', 1, 'min', 1, 'position', [120 450 100 20]);
h.Rescan = uicontrol('style', 'pushbutton', 'position', [120 475 100 20], 'string', 'Connect', 'callback', {@Connect, h});
h.StartButton = uicontrol('style', 'pushbutton', 'position', [10 400 100 40], 'string', 'Start', 'callback', {@Start, h});
h.StopButton = uicontrol('style', 'pushbutton', 'position', [10 350 100 40], 'string', 'Stop', 'callback', {@Stop, h});
h.NumMotesText = uicontrol('style', 'text', 'position', [10 475 100 20], 'string', 'number of motes');
h.Close = uicontrol('style', 'pushbutton', 'position', [10 300 100 40], 'string', 'Close', 'callback', {@Close, h});
h.SaveDataButton = uicontrol('style', 'pushbutton', 'position', [120 300 100 40], 'string', 'Save Data', 'callback', {@SaveData, h});

end

function Start(hObject, eventdata, h)

global SerialPort;
global NumMotes;
NumMotes = str2double(get(h.NumMotes, 'string'));
if (isnan(NumMotes) || rem(NumMotes,1) ~= 0 || NumMotes < 1)
    errordlg('not a valid number of motes');
else
    %disp(sprintf(num2str(NumMotes)));
    %errordlg(NumMotes);
    %send the start command
    fwrite(SerialPort,3,'uchar');
    fwrite(SerialPort,255,'uchar');
    fwrite(SerialPort,255,'uchar');
    fwrite(SerialPort,'R','uchar');
end

end

function Stop(hObject, eventdata, h)
    
    global SerialPort;
    global NumMotes;
    global data;
    %data.name = 'test';
    %send the stop command
    fwrite(SerialPort,3,'uchar');
    fwrite(SerialPort,255,'uchar');
    fwrite(SerialPort,255,'uchar');
    fwrite(SerialPort,'S','uchar');
    
    for i=1:NumMotes
        
        %issue transmit command
        fwrite(SerialPort,3,'uchar');
        %fwrite(SerialPort,bitand(i,255,'uint16'),'uchar');
        %fwrite(SerialPort,bitand(bitsra(i,4),255,'uint16'),'uchar');
        fwrite(SerialPort,i,'uint16');
        fwrite(SerialPort,'T','uchar');
        %wait for data
        start = clock;
        data.(sprintf('m%d',i)) = [];
        while true
            if get(SerialPort, 'BytesAvailable') >= 4
               IntsToRead = idivide(get(SerialPort, 'BytesAvailable'),int32(4));
               data.(sprintf('m%d',i)) = cat(1,data.(sprintf('m%d',i)),fread(SerialPort,double(IntsToRead),'int32')); 
               start = clock;
            end
            %wait 2 seconds to timeout
            if etime(clock,start)>2
                break;
            end
        end
        
    end
    %normalize data
    NormData = [];
    for i=1:size(fieldnames(data),1)
        MaxVal = max(data.(sprintf('m%d',i)));
        MinVal = min(data.(sprintf('m%d',i)));
        for n=1:size(data.(sprintf('m%d',i)),1)
            NormData.(sprintf('m%d',i))(n,1) = (data.(sprintf('m%d',i))(n,1)-MinVal)/(MaxVal-MinVal) + ((i-1)*2);
        end    
    end
    
    %plot data
    h.plots = figure();
    for i=1:NumMotes
        plot(NormData.(sprintf('m%d',i)));
        hold on;
    end
    %save the data to files
    %save(strcat(date,'-',int2str(round(cputime)),'-','m',int2str(9),'.txt'),x,'-ascii','-double')
end

function Connect(hObject, eventdata, h)

    global SerialPort; 
    %set(h.ComPorts,'string',getAvailableComPort);
    values = get(h.ComPorts,'string');
    PortName = values(get(h.ComPorts, 'value'));
    disp(PortName);
    SerialPort = serial(PortName, 'BaudRate', 57600);
    fopen(SerialPort);
    
end

function Close(hObject, eventdata, h)

    global SerialPort;
    %check if serial port exists and close it
    if (isa(SerialPort,'serial') && isvalid(SerialPort))
        fclose(SerialPort);
    	delete(SerialPort);
    end
    close(h.fig);
    
end

function SaveData(hObject, eventdata, h)

    global data
    global NumMotes
    if (NumMotes > 0)
        time = clock;
        for i=1:size(fieldnames(data),1)
            fp = fopen(strcat(date,'-',num2str(time(4)),'_',num2str(time(5)),'_',num2str(round(time(6))),'-','mote_',int2str(i),'.txt'),'w');
            fwrite(fp,data.(sprintf('m%d',i)),'int32');
            fclose(fp);
        end
        %save data as matlab file also
        save(strcat(date,'-',num2str(time(4)),'_',num2str(time(5)),'_',num2str(round(time(6))),'-','data.mat'),'data');
    end

end
