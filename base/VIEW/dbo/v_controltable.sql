SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ControlTable] 
AS 
SELECT [type]
, [filename]
, [trandate]
, [rec_upload]
, [rec_posted]
, [totalqty]
, [addwho]
FROM [ControlTable] (NOLOCK) 

GO