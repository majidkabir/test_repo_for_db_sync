CREATE TABLE [dbo].[labellist]
(
    [LabelName] nvarchar(30) NOT NULL DEFAULT (' '),
    [LabelDesc] nvarchar(60) NOT NULL DEFAULT (' '),
    [LabelType] nvarchar(10) NOT NULL DEFAULT (' '),
    [DefaultPrinter] nvarchar(60) NOT NULL DEFAULT (' '),
    [PrinterType] nvarchar(20) NOT NULL DEFAULT (' '),
    [DWName] nvarchar(30) NOT NULL DEFAULT (' '),
    [PredownloadFile] nvarchar(100) NOT NULL DEFAULT (' '),
    [DownloadFile] nvarchar(100) NOT NULL DEFAULT (' '),
    [UseTimer] nvarchar(1) NULL DEFAULT (' '),
    [TimerInterval] int NULL DEFAULT ((0)),
    [Resolution] nvarchar(3) NOT NULL DEFAULT (' '),
    [LayOut] nvarchar(10) NOT NULL DEFAULT (' '),
    [PrintPos] int NOT NULL DEFAULT ((1)),
    [Port] nvarchar(4) NOT NULL DEFAULT ('L1'),
    [ClearPrintBuffer] nvarchar(1) NOT NULL DEFAULT ('Y'),
    [LLMSUB] nvarchar(1) NOT NULL DEFAULT ('N'),
    CONSTRAINT [PKLABELLIST] PRIMARY KEY ([LabelName])
);
GO
