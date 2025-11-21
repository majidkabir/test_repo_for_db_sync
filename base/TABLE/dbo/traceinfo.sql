CREATE TABLE [dbo].[traceinfo]
(
    [TraceName] nvarchar(80) NULL,
    [TimeIn] datetime NULL,
    [TimeOut] datetime NULL,
    [TotalTime] nvarchar(20) NULL,
    [Step1] nvarchar(20) NULL,
    [Step2] nvarchar(20) NULL,
    [Step3] nvarchar(20) NULL,
    [Step4] nvarchar(20) NULL,
    [Step5] nvarchar(20) NULL,
    [Col1] nvarchar(50) NULL,
    [Col2] nvarchar(50) NULL,
    [Col3] nvarchar(50) NULL,
    [Col4] nvarchar(50) NULL,
    [Col5] nvarchar(50) NULL
);
GO

CREATE INDEX [IX_TraceInfo_TimeIn] ON [dbo].[traceinfo] ([TimeIn]);
GO