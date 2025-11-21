SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_LABELLIST] 
AS 
SELECT [LabelName]
, [LabelDesc]
, [LabelType]
, [DefaultPrinter]
, [PrinterType]
, [DWName]
, [PredownloadFile]
, [DownloadFile]
, [UseTimer]
, [TimerInterval]
, [Resolution]
, [LayOut]
, [PrintPos]
, [Port]
, [ClearPrintBuffer]
, [LLMSUB]
FROM [LABELLIST] (NOLOCK) 

GO