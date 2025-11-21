CREATE TABLE [dbo].[ptracedetail]
(
    [PTRACETYPE] nvarchar(30) NOT NULL,
    [PTRACEHEADKey] nvarchar(10) NOT NULL,
    [PA_PutawayStrategyKey] nvarchar(10) NOT NULL,
    [PA_PutawayStrategyLineNumber] nvarchar(10) NOT NULL,
    [PTraceDetailKey] nvarchar(10) NOT NULL,
    [LocKey] nvarchar(10) NOT NULL,
    [Reason] nvarchar(250) NOT NULL,
    CONSTRAINT [PKPTRACEDETAIL] PRIMARY KEY ([PTRACEHEADKey], [PTraceDetailKey])
);
GO
