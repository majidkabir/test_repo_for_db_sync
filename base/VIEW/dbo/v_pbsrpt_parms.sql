SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_pbsrpt_parms] 
AS 
SELECT [rpt_id]
, [parm_no]
, [parm_datatype]
, [parm_label]
, [parm_default]
, [style]
, [name]
, [display]
, [data]
, [attributes]
, [visible]
FROM [pbsrpt_parms] (NOLOCK) 

GO