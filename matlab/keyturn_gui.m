function varargout = keyturn_gui(varargin)
% KEYTURN_GUI MATLAB code for keyturn_gui.fig
%      KEYTURN_GUI, by itself, creates a new KEYTURN_GUI or raises the existing
%      singleton*.
%
%      H = KEYTURN_GUI returns the handle to a new KEYTURN_GUI or the handle to
%      the existing singleton*.
%
%      KEYTURN_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in KEYTURN_GUI.M with the given input arguments.
%
%      KEYTURN_GUI('Property','Value',...) creates a new KEYTURN_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before keyturn_gui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to keyturn_gui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help keyturn_gui

% Last Modified by GUIDE v2.5 18-Jun-2022 16:00:42

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @keyturn_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @keyturn_gui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before keyturn_gui is made visible.
function keyturn_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to keyturn_gui (see VARARGIN)

% Choose default command line output for keyturn_gui
handles.output = hObject;
handles.audio.started   = -1;
handles.audio.fs        = 16000;
handles.audio.nbits     = 16;

global scan
scan.state     = 0;
scan.time      = 0;
scan.dt        = 0.1;
scan.pwm       = 0;
scan.freq      = 0;
scan.pump      = 0;
scan.pump_idx  = 1;
scan.freq_valid  = 0;
scan.pwm_array   = 0 : 5 : 1000;
scan.servo_pwm_array = [];
scan.servo_pih_array = [];
scan.servo_ref_freq_array = [];
scan.servo_range_freq_array = [];
scan.servo_array_idx   = 1;
scan.freq_array   = zeros(length(scan.pwm_array), 10);
scan.pump_scan    = 1;
scan.freq_list    = [];
scan.pitch_list    = [];
scan.vel_cent_err = zeros(100, 128);
scan.pwm_idx     = 1;
scan.pwm_idx_dt  = 1;
scan.pwm_idx_max = length(scan.pwm_array);
scan.lasttime    = 0;

%% serial port
delete(instrfindall);
serial_handle = serial('COM27','BaudRate', 921600);
serial_handle.Timeout = 10;
fopen(serial_handle);
handles.pserial = serial_handle;

% Update handles structure
xlabel(handles.axes_time_domain,'Time');
ylabel(handles.axes_time_domain, 'Amplitude');
xlabel(handles.axes_freq_domain,'Frequency(Hz)');
ylabel(handles.axes_freq_domain,'|Y(f)|')
% UIWAIT makes keyturn_gui wait for user response (see UIRESUME)
% uiwait(handles.figure1);
guidata(hObject,handles);


% --- Outputs from this function are returned to the command line.
function varargout = keyturn_gui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

function servo_set(hObject, handles, pwm, id)
global scan
serial_handle = handles.pserial;
scan.pwm = uint32(pwm);
strout = strcat('set_slider', string(1), '_duty#' , string(scan.pwm) , '#');
fprintf(serial_handle, strout);
set(handles.edit_servo,'String',pwm);

function pump_set(hObject, handles, perc, id)
global scan
if (perc > 100) 
    perc = 100 
end
if (perc < 0) 
    perc = 0 
end
serial_handle = handles.pserial;
scan.pump = uint32(perc);
strout = strcat('set_pumb', string(1), '_perc#' , string(scan.pump) , '#');
fprintf(serial_handle, strout);
set(handles.edit_pumb,'String',perc);

function generate_pwm_table(hObject, handles)
global scan
% save(strcat('scan', string(scan.pump), '.mat'), 'scan');
save('scan');

% --- Executes on slider movement.
function slider_servo_Callback(hObject, eventdata, handles)
% hObject    handle to slider_servo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
value = get(hObject,'Value');
servo_set(hObject, handles, value, 0);
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider_servo_CreateFcn(hObject, ~, handles)
% hObject    handle to slider_servo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'Min', 0);
set(hObject,'Max', 1000);
% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in btn_start.
function btn_start_Callback(hObject, eventdata, handles)
% hObject    handle to btn_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global scan
if (handles.audio.started == -1)    
    handles.recObj = audiorecorder(handles.audio.fs, handles.audio.nbits, 1);
    set(handles.recObj, 'TimerPeriod', scan.dt, 'TimerFcn',{@audioTimerCallback, handles});
    record(handles.recObj);    
    handles.audio.started = 1;
elseif (handles.audio.started == 0)    
    record(handles.recObj);
    handles.audio.started = 1;
elseif (handles.audio.started == 1)    
    stop(handles.recObj);
    handles.audio.started = 0;
end
guidata(hObject, handles);

function audioTimerCallback(hObject,~,handles)
if(isempty(hObject))
    return;
end

global scan
scan.time = scan.time + scan.dt;

%%
signal = getaudiodata(hObject);
signal = signal(end -  (4096 - 1): end);
plot(handles.axes_time_domain, signal,  'LineWidth', 2);
ylim(handles.axes_time_domain, [-1.0 1.0]);
title(handles.axes_time_domain, '时域波形');
xlabel(handles.axes_time_domain,'Time');
ylabel(handles.axes_time_domain, 'Amplitude');

%fft
nfft = 2^nextpow2(length(signal));
fftRecord = fft(signal,nfft);
f = handles.audio.fs/2*linspace(0,1,nfft/2+1);

x = f(80:300);
y = abs(fftRecord(80:300));
[value, index] = max(y);
new_freq = f(80 - 1 + index);
if (value > 100)
    scan.freq_valid = 1;
    scan.freq = new_freq;
    display(new_freq);
    set(handles.edit_freq,'String',new_freq);
else
    scan.freq_valid = 0;
    scan.freq = 0;
    set(handles.edit_freq,'String','NaN');
end
plot(handles.axes_freq_domain, x, y, 'LineWidth', 2);
ylim(handles.axes_freq_domain, [0 500]);
title(handles.axes_freq_domain, 'FFT波形');
xlabel(handles.axes_freq_domain,'Frequency(Hz)');
ylabel(handles.axes_freq_domain,'|Y(f)|')

%%  auto scan freq
dtime = scan.time - scan.lasttime;
if (scan.state == 1)
    scan.freq_array(scan.pwm_idx, 1) = scan.freq;    
    scan.pwm_idx = scan.pwm_idx + 1;
    if (scan.pwm_idx > scan.pwm_idx_max)        
        scan.state = 0;
        pump_set(hObject, handles, 0, 0);
        figure(1);
        plot(scan.pwm_array, scan.freq_array(:, scan.pump_idx), 'lineWidth', 3);             
        xlabel('PWM');
        ylabel('Frequency(HZ)');
        title('位置 - 频率关系图');
        save('scan');
    else
        next_pwm = scan.pwm_array(scan.pwm_idx);
        servo_set(hObject, handles, next_pwm, 0);
    end         
end
scan.lasttime = scan.time;
% display(scan.time)
%%  auto scan freq


% --- Executes on slider movement.
function slider_pump_Callback(hObject, eventdata, handles)
% hObject    handle to slider_pump (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
value = get(hObject,'Value');
pump_set(hObject, handles, value, 0);
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider_pump_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_pump (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'Min', 0);
set(hObject,'Max', 100);
% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function edit_servo_Callback(hObject, eventdata, handles)
% hObject    handle to edit_servo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_servo as text
%        str2double(get(hObject,'String')) returns contents of edit_servo as a double


% --- Executes during object creation, after setting all properties.
function edit_servo_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_servo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_pumb_Callback(hObject, eventdata, handles)
% hObject    handle to edit_pumb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_pumb as text
%        str2double(get(hObject,'String')) returns contents of edit_pumb as a double


% --- Executes during object creation, after setting all properties.
function edit_pumb_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_pumb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btn_generate_table.
function btn_generate_table_Callback(hObject, eventdata, handles)
% hObject    handle to btn_generate_table (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
generate_pwm_table(hObject, handles);


% --- Executes on button press in btn_scan_pitch.
function btn_scan_pitch_Callback(hObject, eventdata, handles)
global scan
if (scan.state == 0)
    scan.state = 1;
else
    scan.state = 0;
end
scan.pwm_idx = 1; 
scan.time = 0;
scan.lasttime = scan.time;
servo_set(hObject,handles, scan.pwm_array(1), 0);
guidata(hObject,handles);

% --- Executes on button press in btn_scan_velocity.
function btn_scan_velocity_Callback(hObject, eventdata, handles)
 



function edit_freq_Callback(hObject, eventdata, handles)
% hObject    handle to edit_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_freq as text
%        str2double(get(hObject,'String')) returns contents of edit_freq as a double


% --- Executes during object creation, after setting all properties.
function edit_freq_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit4_Callback(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit4 as text
%        str2double(get(hObject,'String')) returns contents of edit4 as a double


% --- Executes during object creation, after setting all properties.
function edit4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
