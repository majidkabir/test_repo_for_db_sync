SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_pbsrpt_reports]   
AS   
SELECT [rpt_id]  
, [rpt_datawindow]  
, [rpt_library]  
, [rpt_title]  
, [rpt_purpose]  
, [rpt_descr]  
, [rpt_header]  
, [rpt_active]  
, [rpt_type]  
, [rpt_where]  
, [rpt_filter]  
, [rpt_sort]  
, [enable_filter]  
, [enable_sort]  
, [autoretrieve]  
, [category_id]  
, [show_criteria]  
, [query_mode]  
, [shared_rpt_id]  
, [HeaderFlag]  
, [FooterFlag]  
, SCEPrintType
FROM [pbsrpt_reports] (NOLOCK)   
  

GO