SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_pbsrpt_sets] 
AS 
SELECT [rpt_set_id]
, [name]
FROM [pbsrpt_sets] (NOLOCK) 

GO