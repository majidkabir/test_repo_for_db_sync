SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***********************************************************************
	TITLE: nsp_NIKE_InvoiceDatabase https://jiralfl.atlassian.net/browse/WMS-22171

DATE				VER		CREATEDBY   PURPOSE
04-APR-2023		1.0		JAM			MIGRATE FROM HYPERION
25-APR-2023    1.1      Percival    add date from/to parameters
************************************************************************/

CREATE     PROC [BI].[nsp_NIKE_InvoiceDatabase] --NAME OF SP
			@PARAM_GENERIC_STORERKEY NVARCHAR(30)=''
			, @PARAM_GENERIC_EXTERNORDERKEY NVARCHAR(4000)=''
			, @PARAM_MBOL_MBOLKEY NVARCHAR(10)=''
			,@PARAM_GENERIC_STARTDATE DATETIME			--REQUIRED
			,@PARAM_GENERIC_ENDDATE DATETIME			--REQUIRED

AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

	IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		SET @PARAM_GENERIC_StorerKey = ''
	IF ISNULL(@PARAM_GENERIC_EXTERNORDERKEY, '') = ''  or @PARAM_GENERIC_EXTERNORDERKEY ='ALL'
		SET @PARAM_GENERIC_EXTERNORDERKEY = ''
	IF ISNULL(@PARAM_MBOL_MBOLKEY, '') = ''
		SET @PARAM_MBOL_MBOLKEY = ''
	IF ISNULL(@PARAM_GENERIC_STARTDATE, '') = ''
		SET @PARAM_GENERIC_STARTDATE = getdate()
	IF ISNULL(@PARAM_GENERIC_ENDDATE, '') = ''
		SET @PARAM_GENERIC_ENDDATE = dateadd(hour,-1,getdate())

	SET @PARAM_GENERIC_EXTERNORDERKEY = REPLACE(REPLACE (TRANSLATE (@PARAM_GENERIC_EXTERNORDERKEY,'[ ]',''''''''),'''',''),',',''',''')


   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{  "PARAM_GENERIC_StorerKey":"'    +@PARAM_GENERIC_StorerKey+'", '
                                    + ' "PARAM_GENERIC_EXTERNORDERKEY":"'    +@PARAM_GENERIC_EXTERNORDERKEY+'", '
									+ ' "PARAM_MBOL_MBOLKEY":"'    +@PARAM_MBOL_MBOLKEY+'", '
									+ ' "PARAM_GENERIC_STARTDATE":"'    +CONVERT(VARCHAR,@PARAM_GENERIC_STARTDATE,120)+'",  '
									+ ' "PARAM_GENERIC_ENDDATE":"'    +CONVERT(VARCHAR,@PARAM_GENERIC_ENDDATE,120)+'"  '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_STORERKEY
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
	DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/
set @Stmt = '


SELECT 
  DISTINCT AL1.MbolKey AS   ''01MBOLKey'', 
  AL2.ExternOrderKey AS     ''02ExternOrderKey'', 
  AL2.LoadKey AS            ''03LoadKey'', 
  AL4.EditDate AS           ''04EditDate'', 
  AL1.PCMNum AS             ''05PCMNum'', 
  AL1.ExternReason AS       ''06ExternReason'', 
  AL1.InvoiceStatus AS      ''07InvoiceStatus'', 
  AL2.UserDefine09 AS       ''08UserDefine09'', 
  AL2.ConsigneeKey AS       ''09ConsigneeKey'', 
  AL2.C_Company AS          ''10C_Company'', 
  SUM (AL3.Qty) AS          ''11Qty'' , 
  COUNT (DISTINCT AL3.CaseID) AS ''12DistinctID'', 
  AL2.OrderKey AS           ''13OrderKey'', 
  AL4.ShipDate AS           ''14ShipDate'', 
  AL1.UserDefine06 AS       ''15UserDefine06'', 
  AL1.UserDefine07 AS       ''16UserDefine07'' 
FROM BI.V_MBOLDETAIL AL1 (nolock)
JOIN BI.V_ORDERS AL2 (nolock) on  AL1.MBOLKey = AL2.MbolKey AND AL1.OrderKey = AL2.OrderKey
JOIN BI.V_PICKDETAIL AL3 (nolock) on  AL3.OrderKey = AL2.OrderKey AND AL3.Storerkey = AL2.Storerkey
JOIN BI.V_MBOL AL4 (nolock) on AL1.MbolKey = AL4.MbolKey 
WHERE  
    (
      AL2.StorerKey = '''+@PARAM_GENERIC_STORERKEY+'''
	  AND AL4.EditDate BETWEEN '''+convert(nvarchar,@PARAM_GENERIC_STARTDATE,120)+''' AND '''+convert(nvarchar,@PARAM_GENERIC_ENDDATE,120) +'''  

'

 if isnull(@PARAM_GENERIC_EXTERNORDERKEY,'')<>''
	set @stmt = @stmt + ' AND AL2.ExternOrderKey in ('''+@PARAM_GENERIC_EXTERNORDERKEY+''') '

 if isnull(@PARAM_MBOL_MBOLKEY,'')<>''
    set @stmt = @stmt + '  AND AL2.MBOLKey = '''+@PARAM_MBOL_MBOLKEY+'''    '

set @stmt = @stmt + '
    ) 
GROUP BY 
  AL1.MbolKey, 
  AL2.ExternOrderKey, 
  AL2.LoadKey, 
  AL4.EditDate, 
  AL1.PCMNum, 
  AL1.ExternReason, 
  AL1.InvoiceStatus, 
  AL2.UserDefine09, 
  AL2.ConsigneeKey, 
  AL2.C_Company, 
  AL2.OrderKey, 
  AL4.ShipDate, 
  AL1.UserDefine06, 
  AL1.UserDefine07
'

   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO