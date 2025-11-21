SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_pbsrpt_set_reports] 
AS 
SELECT [rpt_set_id]
, [rpt_seq]
, [rpt_id]
FROM [pbsrpt_set_reports] (NOLOCK) 

GO