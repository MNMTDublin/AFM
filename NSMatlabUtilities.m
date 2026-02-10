classdef NSMatlabUtilities < handle
   % A class that implements NanoScope file I/O utilities
    properties (SetAccess = 'private')
        FileName = '';
        IsOpen = 0;
        METRIC = 1;
        VOLTS = 2;
        FORCE = 3;
        RAW = 4;
        %NOTE: MAX_STRING_SIZE must match MAX_STRING_SIZE in DataSourceDLL.h!!
        MAX_STRING_SIZE = 100;
    end
    
    methods
        function this = NSMatlabUtilities()
        end
        
        function LoadDLL(this)
            if ~libisloaded('DataSourceDLL')
                try
                    if (isdeployed)
                        loadlibrary('DataSourceDLL.dll', @mdatasourcehdr);
                    else
                        hdrFile = 'DataSourceDLL.h';
                        dllFile =  'DataSourceDLL.dll';
                        if exist(hdrFile, 'file') && exist(dllFile, 'file')
                            loadlibrary(dllFile, hdrFile);
                        else
                            error('Unable to locate %s and/or %s', hdrFile, dllFile);
                        end
                    end
                catch exc
                    %trap the case of mis-matched win32/win64 versions of Matlab and Toolbox
                    strFound = strfind(exc.message, 'DataSourceDLL.dll is not a valid Win32 application');
                    if (~isempty(strFound))
                        error('Could not load %s \n\nNote: Your NanoScope Matlab Toolbox version MUST correspond to the Matlab version you are runnning (win32 or win64).', ...
                              dllFile);
                    else
                        error(exc.message);
                    end
                end
            end
        end
        
        function [versionInfo] = GetVersionInfo(this)
            this.LoadDLL()
            pStr = GetStringPtr(this.MAX_STRING_SIZE);
            [ret, versionInfo] = calllib('DataSourceDLL', 'DataSourceDllGetVersionInfo', pStr);
            clear pStr;
        end
        
        function Open(this, FileName)
            this.LoadDLL()
            this.FileName = FileName;
            this.IsOpen = calllib('DataSourceDLL', 'DataSourceDllOpen', FileName);
            if this.IsOpen ~= 1;
                error('Could not open %s.\n\nVerify that it is a valid Nanoscope File.', FileName);
            end
        end
        
        function Close(this)
            if libisloaded('DataSourceDLL')
                calllib('DataSourceDLL', 'DataSourceDllClose');
                unloadlibrary DataSourceDLL;
            end
        end
        
        function [trace, retrace, scaleUnit, dataTypeDesc] = GetForceCurveData(this, ChannelNumber, UnitType)
            %Returns force curve data
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file.
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            trace = [];
            retrace = [];
            dataTypeDesc = '';
            scaleUnit = '';
            
            if this.IsOpen
                
                dataTypeDesc = this.GetDataTypeDesc(ChannelNumber); % do before decrement
                NumRetrace = this.GetNumberOfRetracePoints(ChannelNumber);
                NumTrace = this.GetNumberOfTracePoints(ChannelNumber);
                
                if ChannelNumber ~= 0
                    ChannelNumber = ChannelNumber - 1;
                end
                
                pTrace = GetDoubleBufferPtr(NumTrace);
                pRetrace = GetDoubleBufferPtr(NumRetrace);
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                
                switch UnitType
                    case this.RAW
                        calllib('DataSourceDLL', 'DataSourceDllGetForceCurveData', ChannelNumber, pTrace, pRetrace);
                        scaleUnit = 'LSB';
                    case this.METRIC
                        calllib('DataSourceDLL', 'DataSourceDllGetForceCurveMetricData', ChannelNumber, pTrace, pRetrace);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetMetricDataScaleUnits', ChannelNumber, pUnit);
                    case this.FORCE
                        calllib('DataSourceDLL', 'DataSourceDllGetForceCurveForceData', ChannelNumber, pTrace, pRetrace);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetForceDataScaleUnits', ChannelNumber, pUnit);
                        dataTypeDesc = 'Force';
                    case this.VOLTS
                        calllib('DataSourceDLL', 'DataSourceDllGetForceCurveVoltsData', ChannelNumber, pTrace, pRetrace);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetVoltsDataScaleUnits', ChannelNumber, pUnit);
                    otherwise
                        error('Wrong UnitType parameter.');
                end
                
                trace = GetAllValuesFromPtr(pTrace);
                retrace = GetAllValuesFromPtr(pRetrace);
                clear pUnit;
            end
        end
        
        function [data, scaleUnit, dataTypeDesc] = GetHSDCData(this, ChannelNumber, UnitType)
            %Returns HSDC data
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file.
            %UnitType: this.METRIC, this.VOLTS, this.RAW
            data = [];
            dataTypeDesc = '';
            scaleUnit = '';
            if this.IsOpen
                
                dataTypeDesc = this.GetDataTypeDesc(ChannelNumber); % do before decrement
                
                if ChannelNumber ~= 0
                    ChannelNumber = ChannelNumber - 1;
                end
                
                MaxDataSize = 0;
                [ret, MaxDataSize] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfPointsPerCurve', ChannelNumber, MaxDataSize);
                ActualDataSize = 0;
                
                pBuffer = GetDoubleBufferPtr(MaxDataSize);
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                
                switch UnitType
                    case this.RAW
                        [ret, ~, ActualDataSize] = calllib('DataSourceDLL', 'DataSourceDllGetHSDCForceCurveData', ChannelNumber, pBuffer, MaxDataSize, ActualDataSize);
                        scaleUnit = 'LSB';
                    case this.METRIC
                        [ret, ~, ActualDataSize] = calllib('DataSourceDLL', 'DataSourceDllGetHSDCMetricForceCurveData', ChannelNumber, pBuffer, MaxDataSize, ActualDataSize);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetMetricDataScaleUnits', ChannelNumber, pUnit);
                    case this.VOLTS
                        [ret, ~, ActualDataSize] = calllib('DataSourceDLL', 'DataSourceDllGetHSDCVoltsForceCurveData', ChannelNumber, pBuffer, MaxDataSize, ActualDataSize);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetVoltsDataScaleUnits', ChannelNumber, punit);
                    otherwise
                        error('Wrong UnitType parameter.')
                end
                
                data = GetValuesFrom1DPtr(pBuffer, ActualDataSize);
                clear pUnit;
            end
        end
        
        function [data, scaleUnit, dataTypeDesc] = GetForceVolumeImageData(this, UnitType)
            %Returns force volume image
            %Input:
            %UnitType: this.METRIC, this.VOLTS, this.RAW
            data = [];
            dataTypeDesc = '';
            scaleUnit = '';
            if this.IsOpen
                
                dataTypeDesc = this.GetDataTypeDesc(0);
                
                %FV image ChannelNumber is always 0
                SamplesPerLine = 0;
                [ret, SamplesPerLine] = calllib('DataSourceDLL', 'DataSourceDllGetSamplesPerLine', 0, SamplesPerLine);
                NumberOfLines = 0;
                [ret, NumberOfLines] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfLines', 0, NumberOfLines);
                MaxDataSize = SamplesPerLine * NumberOfLines;
                ActualDataSize = 0;
                
                pBuffer = GetDouble2DPtr(NumberOfLines, SamplesPerLine);
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                
                switch UnitType
                    case this.RAW
                        calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeImageData', pBuffer, MaxDataSize, ActualDataSize);
                        scaleUnit = 'LSB';
                    case this.METRIC
                        calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeMetricImageData', pBuffer, MaxDataSize, ActualDataSize);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetMetricDataScaleUnits', 0, pUnit);
                    case this.VOLTS
                        calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeVoltsImageData', pBuffer, MaxDataSize, ActualDataSize);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetVoltsDataScaleUnits', 0, pUnit);
                    otherwise
                        error('Wrong UnitType parameter.')
                end
                
                data = GetAllValuesFromPtr(pBuffer);
                data = rot90(data);
                clear pUnit;
            end
        end
        
        function [data, scaleUnit, dataTypeDesc] = GetPeakForceCaptureImageData(this, UnitType)
            [data, scaleUnit, dataTypeDesc] = this.GetForceVolumeImageData(UnitType);
        end
        
        function [imagePixel, forVolPixel] = GetForceVolumeScanLinePixels(this)
            %Return image pixels and number of force curves
            %in each scan line of the specific force volume/peak force
            %capture file.
            imagePixel = 0;
            forVolPixel = 0;
            if this.IsOpen
                [ret, forVolPixel] = calllib('DataSourceDLL', 'DataSourceDllGetForcesPerLine', forVolPixel);
                %FV image ChannelNumber is always 0
                [ret, imagePixel] = calllib('DataSourceDLL', 'DataSourceDllGetSamplesPerLine', 0, imagePixel);
            end
        end
        
        function [trace, retrace, scaleUnit, dataTypeDesc] = GetForceVolumeForceCurveData(this, ChannelNumber, CurveNumber, UnitType)
            %Returns force volume force curve data
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file.
            %CurveNumber ranges from 1 to Number of Curves in the file.
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            trace = [];
            retrace = [];
            scaleUnit = '';
            dataTypeDesc = '';
            
            if this.IsOpen && ChannelNumber >= 0 && ChannelNumber <= this.GetNumberOfChannels()
                
                dataTypeDesc = this.GetDataTypeDesc(ChannelNumber); % do before decrement
                
                if ChannelNumber ~= 0
                    ChannelNumber = ChannelNumber - 1; %matlab is 1 based, DataSource is 0 based (but forgive if 0 was passed in)
                end
                if CurveNumber ~= 0
                    CurveNumber = CurveNumber - 1; %ditto
                end
                
                MaxDataSize = 0;
                [ret, MaxDataSize] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfPointsPerCurve', 1, MaxDataSize);
                tracePts = 0;
                retracePts = 0;
                
                pTrace = GetDoubleBufferPtr(MaxDataSize);
                pRetrace = GetDoubleBufferPtr(MaxDataSize);
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                
                switch UnitType
                    case this.RAW
                        [~, ~, ~, tracePts, retracePts] = calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeForceCurveData', ChannelNumber, CurveNumber, pTrace, pRetrace, tracePts, retracePts, MaxDataSize);
                        scaleUnit = 'LSB';
                    case this.METRIC
                        [~, ~, ~, tracePts, retracePts] = calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeMetricForceCurveData', ChannelNumber, CurveNumber, pTrace, pRetrace, tracePts, retracePts, MaxDataSize);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetMetricDataScaleUnits', ChannelNumber, pUnit);
                    case this.VOLTS
                        [~, ~, ~, tracePts, retracePts] = calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeVoltsForceCurveData', ChannelNumber, CurveNumber, pTrace, pRetrace, tracePts, retracePts , MaxDataSize);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetVoltsDataScaleUnits', ChannelNumber, pUnit);
                    case this.FORCE
                        [~, ~, ~, tracePts, retracePts] = calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeForceForceCurveData', ChannelNumber, CurveNumber, pTrace, pRetrace, tracePts, retracePts, MaxDataSize);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetForceDataScaleUnits', ChannelNumber, pUnit);
                    otherwise
                        error('Wrong UnitType parameter.')
                end
                
                trace = GetValuesFrom1DPtr(pTrace, tracePts);
                retrace = GetValuesFrom1DPtr(pRetrace, retracePts);
                clear pUnit;
            end
        end
        
        function [hold, scaleUnit, dataTypeDesc] = GetForceVolumeHoldData(this, ChannelNumber, CurveNumber, UnitType)
            %Returns force volume hold curve data
            %Input:
            %Channel is force image channel
            %CurveNumber ranges from 1 to Number of Curves in the file.
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            hold = [];
            dataTypeDesc = '';
            scaleUnit = '';
            if this.IsOpen
                
                dataTypeDesc = this.GetDataTypeDesc(ChannelNumber); % do before decrement
                nHoldPts = this.GetNumberOfHoldPoints(ChannelNumber); % ditto
                
                if ChannelNumber ~= 0
                    ChannelNumber = ChannelNumber - 1;
                end
                if CurveNumber ~= 0
                    CurveNumber = CurveNumber - 1;
                end
                
                pHold = GetDoubleBufferPtr(nHoldPts);
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                
                switch UnitType
                    case this.RAW
                        calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeHoldData', ChannelNumber, CurveNumber, pHold);
                        scaleUnit = 'LSB';
                    case this.METRIC
                        calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeMetricHoldData', ChannelNumber, CurveNumber, pHold);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetMetricDataScaleUnits', ChannelNumber, pUnit);
                    case this.VOLTS
                        calllib('DataSourceDLL', 'DataSourceDllGetForceVolumeVoltsHoldData', ChannelNumber, CurveNumber, pHold);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetVoltsDataScaleUnits', ChannelNumber, pUnit);
                    otherwise
                        error('Wrong UnitType parameter.')
                end
                hold = GetAllValuesFromPtr(pHold);
                clear pUnit;
            end
        end
        
        function [hold, scaleUnit, dataTypeDesc] = GetForceHoldData(this, ChannelNumber, UnitType)
            %Returns force hold curve data
            %Input:
            %Channel is force image channel
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            hold = [];
            dataTypeDesc = '';
            scaleUnit = '';
            if this.IsOpen
                
                dataTypeDesc = this.GetDataTypeDesc(ChannelNumber); % do before decrement
                nHoldPts = this.GetNumberOfHoldPoints(ChannelNumber); % do before decrement
                
                if ChannelNumber ~= 0
                    ChannelNumber = ChannelNumber - 1;
                end
                
                pHold = GetDoubleBufferPtr(nHoldPts);
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                
                switch UnitType
                    case this.RAW
                        calllib('DataSourceDLL', 'DataSourceDllGetForceHoldData', ChannelNumber, pHold);
                        scaleUnit = 'LSB';
                    case this.METRIC
                        calllib('DataSourceDLL', 'DataSourceDllGetForceMetricHoldData', ChannelNumber, pHold);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetMetricDataScaleUnits', ChannelNumber, pUnit);
                    case this.VOLTS
                        calllib('DataSourceDLL', 'DataSourceDllGetForceVoltsHoldData', ChannelNumber, pHold);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetVoltsDataScaleUnits', ChannelNumber, pUnit);
                    otherwise
                        error('Wrong UnitType parameter.')
                end
                
                hold = GetAllValuesFromPtr(pHold);
                clear pUnit;
            end
        end
        
        function [xData, yData, scaleUnit, dataTypeDesc] = GetScriptSegmentData(this, ChannelNumber, SegmentNumber, UnitType)
            %Returns ScriptSegmentData
            %Input:
            %Channel is data channel
            %SegmentNumber ranges from 1 to Number of Segments in the file.
            %Note: Segment Number <=0  => get all segments
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            %Output:
            %xData, yData contain segment data
            xData = [];
            yData = [];
            dataTypeDesc = '';
            scaleUnit = '';
            if this.IsOpen
                [nSegments, sizeSegs, ~, ~, ~, ~] = GetScriptSegmentInfo(this);
                if nSegments > 0
                    
                    dataTypeDesc = this.GetDataTypeDesc(ChannelNumber); % do before decrement
                    
                    if ChannelNumber ~= 0
                        ChannelNumber = ChannelNumber - 1;
                    end
                    
                    firstSeg = 1;
                    lastSeg = nSegments;
                    if SegmentNumber > 0 && SegmentNumber <= nSegments
                        firstSeg = SegmentNumber;
                        lastSeg = SegmentNumber;
                        SegmentNumber = SegmentNumber -1; %Dll uses 0 base, so offset Segment #
                    else
                        SegmentNumber = -1; %force to all segments if segment # wasn't valid
                    end
                    
                    nPts = sum(sizeSegs(firstSeg:lastSeg));  %total number of points we'll be getting
                    
                    pXData= GetDoubleBufferPtr(nPts);
                    pYData= GetDoubleBufferPtr(nPts);
                    pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                    
                    switch UnitType
                        case this.RAW
                            calllib('DataSourceDLL', 'DataSourceDllGetScriptSegmentData', ChannelNumber, SegmentNumber, nPts, pXData, pYData);
                            scaleUnit = 'LSB';
                        case this.METRIC
                            calllib('DataSourceDLL', 'DataSourceDllGetScriptMetricSegmentData', ChannelNumber, SegmentNumber, nPts, pXData, pYData);
                            [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetMetricDataScaleUnits', ChannelNumber, pUnit);
                        case this.VOLTS
                            calllib('DataSourceDLL', 'DataSourceDllGetScriptVoltsSegmentData', ChannelNumber, SegmentNumber, nPts, pXData, pYData);
                            [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetVoltsDataScaleUnits', ChannelNumber, pUnit);
                        otherwise
                            error('Wrong UnitType parameter.')
                    end
                    
                    xData = GetAllValuesFromPtr(pXData);
                    yData = GetAllValuesFromPtr(pYData);
                    clear pUnit;
                end;
            end
        end
        
        function [xTrace, xRetrace, scaleUnit] = GetPeakForceCaptureZData(this, TracePts, RetracePts)
            %Returns peak force z data
            %Input: TracePts & RetracePts
            
            xTrace = [];
            xRetrace = [];
            scaleUnit = '';
            if this.IsOpen
                doublexTrace = double(zeros(TracePts, 1));
                doublexRetrace = double(zeros(RetracePts, 1));
                pxTrace = libpointer('doublePtr', doublexTrace);
                pxRetrace = libpointer('doublePtr', doublexRetrace);
                
                calllib('DataSourceDLL', 'DataSourceDllGetPeakForceCaptureZData', pxTrace, pxRetrace, TracePts, RetracePts);
                scaleUnit = 'nm';
                xTrace = pxTrace.Value;
                xRetrace = pxRetrace.Value;
                clear TracePts; clear RetracePts;
                clear pxTrace; clear pxRetrace;
            end
        end
        
        function [data, scaleUnit, dataTypeDesc] = GetImageData(this, ChannelNumber, UnitType)
            %Returns image channel data
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file.
            %UnitType: this.METRIC, this.VOLTS, this.RAW
            data = [];
            dataTypeDesc = '';
            scaleUnit = '';
            if this.IsOpen
                
                dataTypeDesc = this.GetDataTypeDesc(ChannelNumber); % do before decrement
                
                if ChannelNumber ~= 0
                    ChannelNumber = ChannelNumber - 1;
                end
                
                SamplesPerLine = 0; NumberOfLines = 0;
                [ret, SamplesPerLine] = calllib('DataSourceDLL', 'DataSourceDllGetSamplesPerLine', 0, SamplesPerLine);
                [ret, NumberOfLines] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfLines', 0, NumberOfLines);
                MaxDataSize = SamplesPerLine * NumberOfLines;
                ActualDataSize = 0;
                
                pBuffer = GetDouble2DPtr(NumberOfLines, SamplesPerLine);
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                switch UnitType
                    case this.RAW
                        calllib('DataSourceDLL', 'DataSourceDllGetImageData', ChannelNumber, pBuffer, MaxDataSize, ActualDataSize);
                        scaleUnit = 'LSB';
                    case this.METRIC
                        calllib('DataSourceDLL', 'DataSourceDllGetImageMetricData', ChannelNumber, pBuffer, MaxDataSize, ActualDataSize);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetMetricDataScaleUnits', ChannelNumber, pUnit);
                    case this.VOLTS
                        calllib('DataSourceDLL', 'DataSourceDllGetImageVoltsData', ChannelNumber, pBuffer, MaxDataSize, ActualDataSize);
                        [ret, scaleUnit] = calllib('DataSourceDLL', 'DataSourceDllGetVoltsDataScaleUnits', ChannelNumber, pUnit);
                    otherwise
                        error('Wrong UnitType parameter.')
                end
                
                data = GetAllValuesFromPtr(pBuffer);
                data = rot90(data);
                clear pUnit;
            end
        end
        
        function [deflSens] = GetDeflSensitivity(this)
            deflSens = 1;
            if this.IsOpen
                [ret, deflSens] = calllib('DataSourceDLL', 'DataSourceDllGetDeflSens', deflSens);
            end
        end
        
        function [sensUnits] = GetDeflSensitivityUnits(this)
            sensUnits = '';
            if this.IsOpen
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                [ret, sensUnits] = calllib('DataSourceDLL', 'DataSourceDllGetDeflSensUnits', pUnit);
                clear pUnit;
            end
        end
        
        function [deflLimit, deflLimitLockIn3LSADC1] = GetDeflLimits(this)
            deflLimit = 1;
            deflLimitLockIn3LSADC1 = 1;
            if this.IsOpen
                [ret, deflLimit, deflLimitLockIn3LSADC1] = calllib('DataSourceDLL', 'DataSourceDllGetDeflLimits', deflLimit, deflLimitLockIn3LSADC1);
            end
        end
        
        function [deflLimitsUnit, deflLimitLockIn3LSADC1Units] = GetDeflLimitsUnits(this)
            deflLimitsUnit = '';
            deflLimitLockIn3LSADC1Units = '';
            if this.IsOpen
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                pUnit2 = GetStringPtr(this.MAX_STRING_SIZE);
                [ret, deflLimitsUnit, deflLimitLockIn3LSADC1Units] = calllib('DataSourceDLL', 'DataSourceDllGetDeflLimitsUnits', pUnit, pUnit2);
                clear pUnit; clear pUnit2;
            end
        end
        
        function [modulateType, modulateAmp, modulateFreq] = GetRampModulationInfo(this)
            modulateAmp = 0;
            modulateFreq = 0;
            modulateType = '';
            if this.IsOpen
                pType = GetStringPtr(this.MAX_STRING_SIZE);
                [ret, modulateType, modulateAmp, modulateFreq] = calllib('DataSourceDLL', 'DataSourceDllGetRampModulationInfo', pType, modulateAmp, modulateFreq);
                clear pType;
            end
        end
        
        function [modulateAmpUnit, modulateFreqUnit] = GetRampModulationUnits(this)
            modulateAmpUnit = '';
            modulateFreqUnit = '';
            if this.IsOpen
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                pUnit2 = GetStringPtr(this.MAX_STRING_SIZE);
                [ret, modulateAmpUnit, modulateFreqUnit] = calllib('DataSourceDLL', 'DataSourceDllGetRampModulationUnits', pUnit, pUnit2);
                clear pUnit; clear pUnit2;
            end
        end
        
        function [sensUnit] = GetZSensitivityUnits(this, ChannelNumber)
            %Returns Z Sensitivity unit
            if nargin < 2
                ChannelNumber = 0;
            elseif ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            
            sensUnit = '';
            if this.IsOpen
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                [ret, sensUnit] = calllib('DataSourceDLL', 'DataSourceDllGetZSensitivityUnits', ChannelNumber, pUnit);
                clear pUnit;
            end
        end
        
        function [ScalingFactor] = GetScalingFactor(this, ChannelNumber, isMetric)
            %Returns the Scaling factor for specific ChannelNumber
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file.
            %If IsMetric is 1, the function returns the scaling factor to convert the LSB data to metric unit.
            %If IsMetric is 0, the function returns the scaling factor to conver the LSB data to volts unit.
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            
            ScalingFactor = 1.0;
            if this.IsOpen
                [ret, ScalingFactor] = calllib('DataSourceDLL', 'DataSourceDllGetScalingFactor', ChannelNumber, ScalingFactor, isMetric);
            end
        end
        
        function [BufferSize] = GetBufferSize(this, ChannelNumber)
            %Returns the buffer size for specific ChannelNumber
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            BufferSize = 0;
            if this.IsOpen
                [ret, BufferSize] = calllib('DataSourceDLL', 'DataSourceDllGetDataBufferSize', ChannelNumber, BufferSize);
            end
        end
        
        function [SamplesPerLine] = GetSamplesPerLine(this, ChannelNumber)
            %Returns the samples per line for specific ChannelNumber
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            SamplesPerLine = 0;
            if this.IsOpen
                [ret, SamplesPerLine] = calllib('DataSourceDLL', 'DataSourceDllGetSamplesPerLine', ChannelNumber, SamplesPerLine);
            end
        end
        
        function [NumberOfLines] = GetNumberOfLines(this, ChannelNumber)
            %Returns the number of lines for specific ChannelNumber
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            NumberOfLines = 0;
            if this.IsOpen
                [ret, NumberOfLines] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfLines', ChannelNumber, NumberOfLines);
            end
        end
        
        function [AspectRatio] = GetImageAspectRatio(this, ChannelNumber)
            %Returns the Aspect Ratio for specific ChannelNumber
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            AspectRatio = 1;
            if this.IsOpen
                [ret, AspectRatio] = calllib('DataSourceDLL', 'DataSourceDllGetImageAspectRatio', ChannelNumber, AspectRatio);
            end
        end
        
        function [NumberOfForceCurves] = GetNumberOfForceCurves(this)
            %Returns the number of force curves in the file
            NumberOfForceCurves = 0;
            if this.IsOpen
                [ret, NumberOfForceCurves] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfForceCurves', NumberOfForceCurves);
            end
        end
        
        function [retString] = GetStringFromDll(this, dllFunctionStr, ChannelNumber)
            %Returns the description
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            retString = '';
            if this.IsOpen
                pStr = GetStringPtr(this.MAX_STRING_SIZE);
                [ret, retString] = calllib('DataSourceDLL', dllFunctionStr, ChannelNumber, pStr);
                clear pStr;
            end
        end
        
        function [descr] = GetDataTypeDesc(this, ChannelNumber)
            descr = this.GetStringFromDll('DataSourceDllGetDataTypeDesc', ChannelNumber);
        end
        
        function [lineDir] = GetLineDirection(this, ChannelNumber)
            lineDir = this.GetStringFromDll('DataSourceDllGetLineDirection', ChannelNumber);
        end
        
        function [scanLine] = GetScanLine(this, ChannelNumber)
            scanLine = this.GetStringFromDll('DataSourceDllGetScanLine', ChannelNumber);
        end
        
        function [NumberOfPoints] = GetNumberOfPointsPerCurve(this, ChannelNumber)
            %Returns the number of points for specific force curve ChannelNumber ex)Samps/line
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            NumberOfPoints = 0;
            if this.IsOpen
                [ret, NumberOfPoints] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfPointsPerCurve', ChannelNumber, NumberOfPoints);
            end
        end
        
        function [RampSize, RampUnits] = GetRampSize(this, ChannelNumber, isMetric)
            %Returns the ramp size of specific force curve ChannelNumber
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %If IsMetric is 1, the function returns the RampSize to metric unit
            %If IsMetric is 0, the function returns the RampSize to volts unit.
            %Output:
            %Ramp size and unit
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            
            RampSize = 0;
            RampUnits = '';
            if this.IsOpen
                pUnit = GetStringPtr(this.MAX_STRING_SIZE);
                [ret, RampSize] = calllib('DataSourceDLL', 'DataSourceDllGetRampSize', ChannelNumber, RampSize, isMetric);
                [ret, RampUnits] = calllib('DataSourceDLL', 'DataSourceDllGetRampUnits', ChannelNumber, pUnit, isMetric);
                clear pUnit;
            end
        end
        
        function [ZScale] = GetZScaleInSwUnits(this, ChannelNumber)
            %Returns the ZScale of specific force curve ChannelNumber
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %Output:
            %Z scale in sw unit
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            ZScale = 1;
            if this.IsOpen
                [ret, ZScale] = calllib('DataSourceDLL', 'DataSourceDllGetZScaleInSwUnits', ChannelNumber, ZScale);
            end
        end
        
        function [ZScale] = GetZScaleInHwUnits(this, ChannelNumber)
            %Returns the ZScale of specific force curve ChannelNumber
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %Output:
            %Z scale in sw unit
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            ZScale = 1;
            if this.IsOpen
                [ret, ZScale] = calllib('DataSourceDLL', 'DataSourceDllGetZScaleInHwUnits', ChannelNumber, ZScale);
            end
        end
        
        function [NumTrace] = GetNumberOfTracePoints(this, ChannelNumber)
            %Returns the number of points in trace
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %Output:
            %the number of points in trace
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            NumTrace = 0;
            %get number of trace points
            if this.IsOpen
                [ret, NumTrace] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfTracePoints', ChannelNumber, NumTrace);
            end
        end
        
        function [NumHold] = GetNumberOfHoldPoints(this, ChannelNumber)
            %Returns the number of points in hold
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %Output:
            %the number of points in trace
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            NumHold = 0;
            %get number of trace points
            if this.IsOpen
                [ret, NumHold] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfHoldPoints', ChannelNumber, NumHold);
            end
        end
        
        function [NumRetrace] = GetNumberOfRetracePoints(this, ChannelNumber)
            %Returns the number of points in retrace
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %Output:
            %the number of points in retrace
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            NumRetrace = 0;
            %get number of retrace points
            if this.IsOpen
                [ret, NumRetrace] = calllib('DataSourceDLL', 'DataSourceDllGetForceSamplesPerLine', ChannelNumber, NumRetrace);
            end
        end
        
        function [HoldTimeSeconds] = GetForceHoldTime(this, ChannelNumber)
            %Returns the duration in seconds of the Hold Period of either
            %Force or Force Volume File
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %Output:
            %the hold Time in seconds
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            HoldTimeSeconds = double(0);
            %get number of trace points
            if this.IsOpen
                [ret, HoldTimeSeconds] = calllib('DataSourceDLL', 'DataSourceDllGetForceHoldTime', ChannelNumber, HoldTimeSeconds);
            end
        end
        
        function [numSegs] = GetScriptSegmentCount(this)
            %Returns the number of segments in Script file
            numSegs = 0;
            if this.IsOpen
                [ret, numSegs] = calllib('DataSourceDLL', 'DataSourceDllGetScriptSegmentCount', numSegs);
            end
        end
        
        function [nSegments, sizeSegs, descripSegs, typeSegs, durationSegs, periodSegs] = GetScriptSegmentInfo(this)
            %Output:
            %the number of points in and size, type and duration (secs) of each segment
            
            sizeSegs = []; descripSegs = []; typeSegs = []; durationSegs = []; periodSegs = [];
            
            nSegments = GetScriptSegmentCount(this);
            
            if this.IsOpen
                pSegSizes = GetIntBufferPtr(nSegments);
                pSegTypes = GetIntBufferPtr(nSegments);
                pDescripSegs = GetArrayOfStringsPtr(nSegments, this.MAX_STRING_SIZE);
                pSegDurations = GetDoubleBufferPtr(nSegments);
                pSegSampPeriods = GetDoubleBufferPtr(nSegments);
                pSegTtlOutputs= GetIntBufferPtr(nSegments); %note: currently this isn't being returned to caller....this was put in as a "patch" to 
                                                            %fix a bug introduced when the interface to DataSourceDllGetScriptSegmentInfo changed               
                ret = calllib('DataSourceDLL', 'DataSourceDllGetScriptSegmentInfo', nSegments, pDescripSegs, pSegTypes, pSegSizes, pSegDurations, pSegSampPeriods, pSegTtlOutputs);
                
                sizeSegs = GetAllValuesFromPtr(pSegSizes);
                typeSegs = GetAllValuesFromPtr(pSegTypes);
                durationSegs = GetAllValuesFromPtr(pSegDurations);
                periodSegs = GetAllValuesFromPtr(pSegSampPeriods);
                descripSegs = GetAllValuesFromPtr(pDescripSegs); 
                clear pSegTtlOutputs;
            end
        end
        
        function [nSegments, durationUnits, periodUnits] = GetScriptSegmentUnits(this)
            durationUnits = {}; periodUnits = {};
            
            nSegments = GetScriptSegmentCount(this);
            
            if this.IsOpen
                pDurationUnits = GetArrayOfStringsPtr(nSegments, this.MAX_STRING_SIZE);
                pPeriodUnits = GetArrayOfStringsPtr(nSegments, this.MAX_STRING_SIZE);
                
                ret = calllib('DataSourceDLL', 'DataSourceDllGetScriptSegmentTimeUnits', nSegments, pDurationUnits, pPeriodUnits);
                
                durationUnits = GetAllValuesFromPtr(pDurationUnits);
                periodUnits = GetAllValuesFromPtr(pPeriodUnits);
            end
        end
        
        function [nSegments, ampSegs, freqSegs, phaseOffsetSegs] = GetScriptModulationSegmentInfo(this)
            %Output:
            %the modulatin info of each segment
            
            ampSegs = []; freqSegs = []; phaseOffsetSegs = [];
            
            nSegments = GetScriptSegmentCount(this);
            
            if this.IsOpen
                pSegAmps = GetDoubleBufferPtr(nSegments);
                pSegFreqs = GetDoubleBufferPtr(nSegments);
                pSegPhaseOffsets = GetDoubleBufferPtr(nSegments);
                
                ret = calllib('DataSourceDLL', 'DataSourceDllGetScriptModulationSegmentInfo', nSegments, pSegAmps, pSegFreqs, pSegPhaseOffsets);
                
                ampSegs = GetAllValuesFromPtr(pSegAmps);
                freqSegs = GetAllValuesFromPtr(pSegFreqs);
                phaseOffsetSegs = GetAllValuesFromPtr(pSegPhaseOffsets);
            end
        end
        
        function [nSegments, ampUnits, freqUnits, phaseOffsetUnits] = GetScriptModulationSegmentUnits(this)
            ampUnits = {}; freqUnits = {};phaseOffsetUnits = {};
            
            nSegments = GetScriptSegmentCount(this);
            
            if this.IsOpen
                pAmpUnits = GetArrayOfStringsPtr(nSegments, this.MAX_STRING_SIZE);
                pFreqUnits = GetArrayOfStringsPtr(nSegments, this.MAX_STRING_SIZE);
                pPhaseOffsetUnits = GetArrayOfStringsPtr(nSegments, this.MAX_STRING_SIZE);
                
                ret = calllib('DataSourceDLL', 'DataSourceDllGetScriptModulationSegmentUnits', nSegments, pAmpUnits, pFreqUnits, pPhaseOffsetUnits);
                
                ampUnits = GetAllValuesFromPtr(pAmpUnits);
                freqUnits = GetAllValuesFromPtr(pFreqUnits);
                phaseOffsetUnits = GetAllValuesFromPtr(pPhaseOffsetUnits);
            end
        end
        
        function [Ratio] = GetPoissonRatio(this)
            %Returns the Poisson ratio from header file
            %
            %Output:
            %Poisson ratio
            Ratio = 0;
            if this.IsOpen
                [ret, Ratio] = calllib('DataSourceDLL', 'DataSourceDllGetPoissonRatio', Ratio);
            end
        end
        
        function [Radius] = GetTipRadius(this)
            %Returns the Tip radius from the header file
            %Output:
            %Tip Radius
            Radius = 0;
            %get number of retrace points
            if this.IsOpen
                [ret, Radius] = calllib('DataSourceDLL', 'DataSourceDllGetTipRadius', Radius);
            end
        end
        
        function [Velocity] = GetForwardRampVelocity(this, ChannelNumber, isMetric)
            %Returns the Forward ramp velocity from the header file
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %IsMetric is 1 or 0
            %Output:
            %Forward ramp velocity
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            Velocity = 0;
            if this.IsOpen
                [ret, Velocity] = calllib('DataSourceDLL', 'DataSourceDllGetForwardRampVelocity', ChannelNumber, Velocity, isMetric);
            end
        end
        
        function [Velocity] = GetReverseRampVelocity(this, ChannelNumber, isMetric)
            %Returns the Reverse ramp velocity from the header file
            %Input:
            %IsMetric is 1 or 0
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %Output:
            %Reverse ramp velocity
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            Velocity = 0;
            if this.IsOpen
                [ret, Velocity] = calllib('DataSourceDLL', 'DataSourceDllGetReverseRampVelocity', ChannelNumber, Velocity, isMetric);
            end
        end
        
        function [SpringConst] = GetSpringConstant(this, ChannelNumber)
            %Returns the Spring constant
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %Output:
            %Spring constant
            if nargin < 2
                ChannelNumber = 0;
            elseif ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            SpringConst = 1;
            if this.IsOpen
                [ret, SpringConst] = calllib('DataSourceDLL', 'DataSourceDllGetForceSpringConstant', ChannelNumber, SpringConst);
            end
        end
        
        function [NumberOfChannels] = GetNumberOfChannels(this)
            %Returns the Number of Channels in Image file
            %Output:
            %Number of Channels in Image file
            NumberOfChannels = 1;
            if this.IsOpen
                [ret, NumberOfChannels] = calllib('DataSourceDLL', 'DataSourceDllGetNumberOfChannels', NumberOfChannels);
            end
        end
        
        function [sweepTypeDesc] = GetForceSweepTypeDesc(this, ChannelNumber)
            %Returns description of sweep channel
            if nargin < 2
                ChannelNumber = 1;
            end
            sweepTypeDesc = this.GetStringFromDll('DataSourceDllGetForceSweepChannel', ChannelNumber);
        end
        
        function [freqStart, freqStop]  = GetForceSweepFreqRange(this, ChannelNumber)
            %Returns start and end sweep frequency (if found)
            if nargin < 2
                ChannelNumber = 1;
            end
            freqStart = 0.;
            freqStop = 0.;
            if this.IsOpen
                [ret, freqStart, freqStop] = calllib('DataSourceDLL', 'DataSourceDllGetForceSweepFreqRange', ChannelNumber, freqStart, freqStop);
            end
        end
        
        function [HsdcRate] = GetHsdcRate(this, ChannelNumber)
            %Returns the Hsdc rate from the header
            %Input:
            %ChannelNumber ranges from 1 to Number of Channels in the file
            %Output:
            %Hsdc Rate in Hsdc file
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end;
            HsdcRate = 1;
            if this.IsOpen
                [ret, HsdcRate] = calllib('DataSourceDLL', 'DataSourceDllGetHsdcRate', ChannelNumber, HsdcRate);
            end
        end
        
        function [PFTFreq] = GetPeakForceTappingFreq(this)
            %Return the peak force tapping frequency from the header
            %Output:
            %peak force tapping frequency (unit in Hz)
            PFTFreq = 0;
            if this.IsOpen
                [ret, PFTFreq] = calllib('DataSourceDLL', 'DataSourceDllGetPeakForceTappingFreq', PFTFreq);
            end;
        end
        
        function [scanSize, scanSizeUnit] = GetScanSize(this, ChannelNumber)
            %Return the scan size of the specific image channel
            %Input:
            %image channel >= 1, <= Number of Channels in the file
            %Output:
            %Scan size and unit
            
            scanSize = 0;
            scanSizeUnit = '';
            
            scanSizeUnit = this.GetStringFromDll('DataSourceDllGetScanSizeUnit', ChannelNumber); % do before decrement
            
            if ChannelNumber ~= 0
                ChannelNumber = ChannelNumber - 1;
            end
            if this.IsOpen
                [ret, scanSize] = calllib('DataSourceDLL', 'DataSourceDllGetScanSize', ChannelNumber, scanSize);
            end
        end
        
        function [ScanSizeLabel] = GetScanSizeLabel(this)
            %Return the string label of scan size
            %(e.g. 'Scan Size: 2.5(um)')
            ScanSizeLabel = '';
            if this.IsOpen
                [scanSize, scanSizeUnit] = this.GetScanSize(1);
                ScanSizeLabel = sprintf('Scan Size: %.2f(%s)', scanSize, scanSizeUnit);
            end
        end
        
        function [xData, yData, xLabel, yLabel] = CreateForceTimePlot(this, ChannelNumber, UnitType)
            %Returns x, y trace and retrace values and their labels
            %Input:
            %ChannelNumber: ranges from 1 to Number of Channels in the file.
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            xLabel = '';
            yLabel = '';
            xData = [];
            yData = [];
            
            if this.IsOpen
                
                [yTrace, yRetrace, scale_units, type_desc] = this.GetForceCurveData(ChannelNumber, UnitType);
                sizeTrace = max(size(yTrace));
                sizeRetrace = max(size(yRetrace));
                if sizeTrace > 0
                    xData = double(zeros(sizeTrace + sizeRetrace, 1));
                    yData = double(zeros(sizeTrace + sizeRetrace, 1));
                    %initialize variables to 0
                    [RampSize, rampVelRev, rampVelFor, TraceTimeS, RetraceTimeS, tIncrR, tIncr, taccum] = deal(0);
                    RampUnits = '';
                    switch UnitType
                        case {this.RAW, this.VOLTS}
                            [RampSize, RampUnits] = this.GetRampSize(ChannelNumber, 0);
                            rampVelFor = this.GetForwardRampVelocity(ChannelNumber, 0);
                            rampVelRev = this.GetReverseRampVelocity(ChannelNumber, 0);
                        case {this.METRIC, this.FORCE}
                            [RampSize, RampUnits] = this.GetRampSize(ChannelNumber, 1);
                            rampVelFor = this.GetForwardRampVelocity(ChannelNumber, 1);
                            rampVelRev = this.GetReverseRampVelocity(ChannelNumber, 1);
                        otherwise
                            error('Wrong UnitType parameter.')
                    end
                    
                    if sizeRetrace > 0
                        dIncr = RampSize/sizeRetrace;
                        if rampVelFor ~=0
                            tIncr = dIncr/rampVelFor;
                        end
                        if sizeRetrace ~= 0
                            tIncrR = dIncr/rampVelRev;
                        end
                        
                        yData = [yTrace(end:-1:1); yRetrace];    %merge reversed trace and retrace vectors for yData
                        for i = 1:sizeTrace + sizeRetrace
                            xData(i) = taccum;
                            if i <= sizeTrace
                                taccum = taccum + tIncr;
                            else
                                taccum = taccum + tIncrR;
                            end
                        end
                        yLabel = sprintf('%s (%s)', type_desc, scale_units);
                        xLabel = 'Time (s)';
                    end
                end
            end
        end
        
        function [xData, yData, xLabel, yLabel] = CreateForceVolumeForceCurveTimePlot(this, CurveNumber, UnitType)
            %Return force vs time plot (ie; retrieves deflection channel) of specified curve and their labels
            %Input:
            %CurveNumber ranges from 1 to Number of Curves in the FV file
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            
            ichan = this.FindFVDeflectionChannel();
            if ichan ~= -1
                [xData, yData, xLabel, yLabel] = this.CreateForceVolumeForceChannelTimePlot(ichan, CurveNumber, UnitType);
            end
        end
        
        function [xData, yData, xLabel, yLabel] = CreateForceVolumeForceChannelTimePlot(this, ChannelNumber, CurveNumber, UnitType)
            %Return channel vs time plot of specified curve and their labels
            %Input:
            %ChannelNumber: ranges from 1 to Number of Channels in the file.
            %CurveNumber ranges from 1 to Number of Curves in the FV file
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            xData = [];
            yData = [];
            xLabel = '';
            yLabel = '';
            if ChannelNumber >= 0 && ChannelNumber <= this.GetNumberOfChannels(); %let them send in 0, it will get fixed
                [yTrace, yRetrace, scale_units, type_desc] = this.GetForceVolumeForceCurveData(ChannelNumber, CurveNumber, UnitType);
                sizeTrace = max(size(yTrace));
                sizeRetrace = max(size(yRetrace));
                xData = double(zeros(sizeTrace + sizeRetrace, 1));
                
                %initialize variables to 0
                [RampSize, rampVelFor, rampVelRev, TraceTimeS, RetraceTimeS, tIncr, tIncrR, tAccum] = deal(0);
                RampUnits = '';
                switch UnitType
                    case {this.RAW, this.VOLTS}
                        [RampSize, RampUnits] = this.GetRampSize(2, 0);
                        rampVelFor = this.GetForwardRampVelocity(2, 0);
                        rampVelRev = this.GetReverseRampVelocity(2, 0);
                    case {this.METRIC, this.FORCE}
                        [RampSize, RampUnits] = this.GetRampSize(2, 1);
                        rampVelFor = this.GetForwardRampVelocity(2, 1);
                        rampVelRev = this.GetReverseRampVelocity(2, 1);
                    otherwise
                        error('Wrong UnitType parameter.')
                end
                
                if rampVelFor ~=0
                    TraceTimeS = RampSize/rampVelFor;
                end
                if rampVelRev ~=0
                    RetraceTimeS = RampSize/rampVelRev;
                end
                if sizeTrace ~= 0
                    tIncr = TraceTimeS / sizeTrace;
                end
                if sizeRetrace ~= 0
                    tIncrR = RetraceTimeS / sizeRetrace;
                end
                yData = [yTrace(end:-1:1); yRetrace];   %merge reversed trace and retrace vectors for yData
                for i = 1:(sizeTrace + sizeRetrace)
                    xData(i) = tAccum;
                    if  i <= sizeTrace
                        tAccum = tAccum + tIncr;
                    else
                        tAccum = tAccum + tIncrR;
                    end
                end
                yLabel = sprintf('%s (%s)', type_desc, scale_units);
                xLabel = 'Time (s)';
            end
        end
        
        function [xData, yData, xLabel, yLabel] = CreatePeakForceForceCurveTimePlot(this, CurveNumber, UnitType)
            %Return force vs time plot of specified curve and their labels
            %Input:
            %CurveNumber ranges from 1 to Number of Curves in the PFC file
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            xData = [];
            yData = [];
            xLabel = '';
            yLabel = '';
            ichan = this.FindFVDeflectionChannel();
            if ichan ~= -1
                [yTrace, yRetrace, scale_units, type_desc] = this.GetForceVolumeForceCurveData(ichan, CurveNumber, UnitType);
                sizeTrace = max(size(yTrace));
                sizeRetrace = max(size(yRetrace));
                xData = double(zeros(sizeTrace + sizeRetrace, 1));
                
                %initialize variables to 0
                [freq, tInterval, tIncr, tAccum] = deal(0);
                [freq] = this.GetPeakForceTappingFreq();   %peak force tapping frequency (unit in Hz)
                
                if freq ~= 0
                    tInterval = 1000000 / freq;    %tapping period (unit in us)
                end
                if tInterval ~= 0
                    tIncr = tInterval / (sizeTrace + sizeRetrace);
                end
                yData = [yTrace(end:-1:1); yRetrace];   %merge reversed trace and retrace vectors for yData
                for i = 1:(sizeTrace + sizeRetrace)
                    tAccum = tAccum + tIncr;
                    xData(i) = tAccum;
                end
                yLabel = sprintf('%s (%s)', type_desc, scale_units);
                xLabel = 'Time (us)';
            end
        end
        
        function [xTrace, xRetrace, yTrace, yRetrace, xLabel, yLabel] = CreateForceZPlot(this, ChannelNumber, UnitType, isSeparation)
            %Returns x, y trace and retrace values and their labels
            %Input:
            %ChannelNumber: ranges from 1 to Number of Channels in the file.
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            %isSeperation: 1 if you want a separation plot
            
            [yTrace, yRetrace, scale_units, type_desc] = this.GetForceCurveData(ChannelNumber, UnitType);
            sizeTrace = max(size(yTrace));
            sizeRetrace = max(size(yRetrace));
            xTrace = double(zeros(sizeTrace, 1));
            xRetrace = double(zeros(sizeRetrace, 1));
            
            switch UnitType
                case {this.RAW, this.VOLTS}
                    [RampSize, RampUnits] = this.GetRampSize(ChannelNumber, 0);
                case {this.METRIC, this.FORCE}
                    [RampSize, RampUnits] = this.GetRampSize(ChannelNumber, 1);
                otherwise
                    error('Wrong UnitType parameter.')
            end
            
            if isSeparation && ~this.IsDeflectionChannel(ChannelNumber)
                display('Separation not possible for this non-deflection channel!');
                isSeparation = 0;
            end
            
            zIncr = RampSize / sizeRetrace;
            zAccum = 0;
            % Right align force curves
            if sizeTrace < sizeRetrace
                zAccum = (sizeRetrace - sizeTrace) * zIncr;
            end
            %reverse trace
            yTrace = yTrace(end:-1:1);
            yLabel = sprintf('%s (%s)', type_desc, scale_units);
            if isSeparation == 1 && (UnitType == this.FORCE || UnitType == this.METRIC)
                xLabel = sprintf('Separation (%s)', RampUnits);
                
                dSepScale = 1;
                if UnitType == this.FORCE
                    dSepScale = 1/this.GetSpringConstant(ChannelNumber);
                end
                delta = yTrace(sizeTrace);
                maxZ = zIncr * sizeRetrace;
                %xTrace
                for i = 1:sizeTrace
                    xTrace(i) = ((maxZ - zAccum) - (delta - yTrace(i)) * dSepScale);
                    zAccum = zAccum + zIncr;
                end
                zAccum = zAccum - zIncr;
                %xRetrace
                for i = 1:sizeRetrace
                    xRetrace(i) = ((maxZ - zAccum) - (delta - yRetrace(i)) * dSepScale);
                    zAccum = zAccum - zIncr;
                end
                
            else
                xLabel = sprintf('Z (%s)', RampUnits);
                %xTrace
                for i = 1:sizeTrace
                    xTrace(i) = zAccum;
                    zAccum = zAccum + zIncr;
                end
                zAccum = zAccum - zIncr;
                %xRetrace
                for i = 1:sizeRetrace
                    xRetrace(i) = zAccum;
                    zAccum = zAccum - zIncr;
                end
            end
        end
        
        function [xTrace, xRetrace, yTrace, yRetrace, xLabel, yLabel] = CreateForceVolumeForceCurveZplot(this, CurveNumber, UnitType, IsSeparation, varargin)
            %Returns x, y trace and retrace values and their labels of
            %Force curve Z plot in Force volume file
            %Input:
            %CurveNumber: ranges from 1 to Number of Curves in the file.
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            %
            %Note that this function always retrieves deflection and z
            %(so channel is not an input)
            
            nVarargs = length(varargin);
            fprintf('Inputs in varargin(%d):\n', nVarargs)
            useHeightSensor = 0;
            if nVarargs > 0
                useHeightSensor = varargin{1};
            end
            
            yTrace = [];
            yRetrace = [];
            xTrace = [];
            xRetrace = [];
            xLabel = '';
            yLabel = '';
            
            switch UnitType
                case {this.RAW, this.VOLTS}
                    [RampSize, RampUnits] = this.GetRampSize(2, 0);
                case {this.METRIC, this.FORCE}
                    [RampSize, RampUnits] = this.GetRampSize(2, 1);
                otherwise
                    error('Wrong UnitType parameter.')
            end
            
            deflChan = this.FindFVDeflectionChannel();
            heightSensChan = this.FindFVHeightSensorChannel();
            
            if deflChan ~= -1
                
                [yTrace, yRetrace, scale_units, type_desc] = this.GetForceVolumeForceCurveData(deflChan, CurveNumber, UnitType);
                sizeTrace = max(size(yTrace));
                sizeRetrace = max(size(yRetrace));
                
                %reverse trace
                yTrace = yTrace(end:-1:1);
                yLabel = sprintf('%s (%s)', type_desc, scale_units);
                
                %seed xTrace, xRetrace with calculated height based on rampsize, npts
                zStart = 0;
                if sizeTrace < sizeRetrace                           %right align trace/retrace
                    zStart = RampSize*(sizeRetrace - sizeTrace)/sizeRetrace;
                end
                xTrace = linspace(zStart, RampSize, sizeTrace)';
                xRetrace = linspace(RampSize, 0, sizeRetrace)';
                type_desc = 'Height';
                
                %overwrite xTrace, xRetrace with Height Sensor data if requested
                if useHeightSensor && heightSensChan ~= -1
                    [xTrace, xRetrace, scale_units, type_desc] = this.GetForceVolumeForceCurveData(heightSensChan, CurveNumber, this.METRIC); %always want height in metric
                    xTrace = xTrace(end:-1:1); %reverse trace
                end
                
                %Do separation
                if IsSeparation && (UnitType == this.FORCE || UnitType == this.METRIC)
                    xLabel = sprintf('Separation from %s (%s)', type_desc, RampUnits);
                    
                    dSepScale = 1;
                    if UnitType == this.FORCE
                        dSepScale = 1/this.GetSpringConstant(2);
                    end
                    delta = yTrace(sizeTrace);
                    
                    %xTrace
                    maxZ = xTrace(sizeTrace);
                    xTrace = maxZ - xTrace - (delta - yTrace) * dSepScale;
                    
                    %xRetrace
                    maxZ = xRetrace(1);
                    xRetrace = maxZ - xRetrace - (delta - yRetrace) * dSepScale;
                    
                else
                    xLabel = strcat (type_desc, ' (', RampUnits, ')');
                end
            end
        end
        
        function [xTrace, xRetrace, yTrace, yRetrace, xLabel, yLabel] = CreatePeakForceForceCurveZplot(this, CurveNumber, UnitType, IsSeparation)
            %Returns x, y trace and retrace values and their labels of
            %Force curve Z plot in peak force file
            %Input:
            %CurveNumber: ranges from 1 to Number of Curves in the file.
            %UnitType: this.METRIC, this.VOLTS, this.FORCE, this.RAW
            
            yTrace = [];
            yRetrace = [];
            xTrace = [];
            xRetrace = [];
            xLabel = '';
            yLabel = '';
            
            ichan = this.FindFVDeflectionChannel();
            if ichan ~= -1
                
                [yTrace, yRetrace, scale_units, type_desc] = this.GetForceVolumeForceCurveData(ichan, CurveNumber, UnitType);
                sizeTrace = max(size(yTrace));
                sizeRetrace = max(size(yRetrace));
                
                [xTrace, xRetrace, x_scale_units] = this.GetPeakForceCaptureZData(sizeTrace, sizeRetrace);
                yLabel = sprintf('%s (%s)', type_desc, scale_units);
                
                if IsSeparation == 1 && (UnitType == this.FORCE || UnitType == this.METRIC)
                    xLabel = sprintf('Separation (%s)', x_scale_units);
                    
                    dSepScale = 1;
                    if UnitType == this.FORCE
                        dSepScale = 1/this.GetSpringConstant(2);
                    end
                    %xTrace
                    maxDefl = yTrace(1);
                    maxZ = xTrace(1);
                    for i = 1:sizeTrace
                        xTrace(i) = ((maxZ - xTrace(i)) - (maxDefl - yTrace(i)) * dSepScale);
                    end
                    %xRetrace
                    maxDefl = yRetrace(1);
                    maxZ = xRetrace(1);
                    for i = 1:sizeRetrace
                        xRetrace(i) = ((maxZ - xRetrace(i)) - (maxDefl - yRetrace(i)) * dSepScale);
                    end
                else
                    xLabel = sprintf('Z (%s)', x_scale_units);
                end
            end
        end
        
        function [xData, yData, xLabel, yLabel] = CreateHSDCTimePlot(this, ChannelNumber, UnitType)
            %Returns x, y data and their labels
            %Input:
            %ChannelNumber: ranges from 1 to Number of Channels in the file.
            %UnitType: this.METRIC, this.VOLTS, this.RAW
            
            [yData, scale_units, type_desc] = this.GetHSDCData(ChannelNumber, UnitType);
            sizeY = max(size(yData));
            hsdcRate = this.GetHsdcRate(ChannelNumber);
            timeIncr = 0;
            taccum = 0;
            xData = double(zeros(sizeY, 1));
            if hsdcRate ~=0
                timeIncr = 1 / hsdcRate;
            end
            for i = 1:sizeY
                xData(i) = taccum;
                taccum = taccum + timeIncr;
            end
            yLabel = sprintf('%s (%s)', type_desc, scale_units);
            xLabel = 'Time (s)';
        end
        
        function [a, b, c, fitTypeStr] = GetPlanefitSettings(this, ChannelNumber)
            %Returns the planefit settings in Image file
            %Output:
            %a, b, c coefficients in z = ax + by + c
            %fitTypeStr: type of plane fit
            a = 0;
            b = 0;
            c = 0;
            fitType = -1;
            fitTypeStr = '';
            if this.IsOpen
                if ChannelNumber ~= 0
                    ChannelNumber = ChannelNumber - 1;
                end
                [ret, a, b, c, fitType] = calllib('DataSourceDLL', 'DataSourceDllGetPlanefitSettings', ChannelNumber, a, b, c, fitType);
                switch fitType
                    case 0
                        fitTypeStr = 'NEEDSFULL';    %full planefitting needs to be done
                    case 1
                        fitTypeStr = 'OFFSET';       %offset has been removed
                    case 2
                        fitTypeStr = 'LOCAL';        %actual plane in data has been removed
                    case 3
                        fitTypeStr = 'CAPTURED';     %captured plane has been removed
                    case 4
                        fitTypeStr = 'NEEDSOFFSET';  %offset removal needs to be done
                    case 5
                        fitTypeStr = 'NOTHING'       %no planefit has been removed
                    case 6
                        fitTypeStr = 'NEEDSNOTHING'  %don't do any planefitting
                    otherwise
                        error('Wrong planefit fitType.');
                end
            end
        end
        
        function [HalfAngle] = GetHalfAngle(this)
            %Returns the Half Angle parameter (in radians)
            %Input:
            HalfAngle = 0.0;
            if this.IsOpen
                [ret, HalfAngle] = calllib('DataSourceDLL', 'DataSourceDllGetHalfAngle', HalfAngle);
            end
        end
       
        function [channel] = FindFVDeflectionChannel(this)
            channel = this.FindFVChannel('Deflection');
        end
        
        function [channel] = FindFVHeightSensorChannel(this)
            channel = this.FindFVChannel('Height Sensor');
        end
        
        function [channel] = FindFVChannel(this, descr)
            channel = -1;
            if this.IsOpen
                numChan = this.GetNumberOfChannels();
                
                for ichan = 2:numChan %first channel is image, force channels start at 2
                    dataTypeDesc = this.GetDataTypeDesc(ichan);
                    if ~isempty(strfind(lower(dataTypeDesc), lower(descr)))
                        channel = ichan;
                        break;
                    end
                end
            end
        end
        
        function [isDefl] = IsDeflectionChannel(this, channel)
            isDefl = 0;
            if channel > 0 && channel <= this.GetNumberOfChannels
                dataTypeDesc = this.GetDataTypeDesc(channel);
                isDefl =  ~isempty(strfind(lower(dataTypeDesc), 'deflection'));
            end
        end
    end            
end

function [ptr] = GetDoubleBufferPtr(numPts)
    ptr = GetDouble2DPtr(numPts, 1);
end

function [ptr] = GetDouble2DPtr(nRows, nCols)
    ptr = libpointer;
    if nRows > 0 && nCols > 0
        buf =  double(zeros(nRows, nCols));
        ptr = libpointer('doublePtr', buf);
        clear buf; %because libpointer makes a copy and returns pointer to the copy, so we don't need this
    end
end

function [ptr] = GetIntBufferPtr(n)
    ptr = libpointer;
    if n > 0
        buf =  int32(zeros(n, 1));
        ptr = libpointer('int32Ptr', buf);
        clear buf; %because libpointer makes a copy and returns pointer to the copy, so we don't need this
    end
end

function [ptr] = GetArrayOfStringsPtr(n, stringSize)
    ptr = libpointer;
    if n > 0 && stringSize > 0
        buf =  cell(n, 1);
        buf(:) = {blanks(stringSize)};
        ptr = libpointer('stringPtrPtr', buf);
        clear buf; %because libpointer makes a copy and returns pointer to the copy, so we don't need this
    end
end

function [ptr] = GetStringPtr(stringSize)
    ptr = libpointer;
    if stringSize > 0
        str = blanks(stringSize);
        ptr = libpointer('stringPtr', str);
        clear str; %because libpointer makes a copy and returns pointer to the copy, so we don't need this
    end
end

function [vals] = GetAllValuesFromPtr(ptr)
    vals = [];
    if ~isNull(ptr)
        [nr, nc] = size(ptr.Value); %just handling 2d right now, easy to change later on
        vals = GetValuesFrom2DPtr(ptr, nr, nc);
    end
end

function [vals] = GetValuesFrom1DPtr(ptr, n)
    vals = GetValuesFrom2DPtr(ptr, n, 1);
end

function [vals] = GetValuesFrom2DPtr(ptr, nRows, nCols)
    vals = [];
    if nRows > 0 && nCols > 0 && ~isNull(ptr)
        vals = ptr.Value(1:nRows, 1:nCols);
        clear ptr;
    end
end
