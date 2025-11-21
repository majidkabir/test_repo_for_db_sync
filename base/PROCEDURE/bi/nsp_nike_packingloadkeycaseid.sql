SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
TITLE: PH_LogiReport - Customized Reports - OrderProcessing [SP] https://jiralfl.atlassian.net/browse/WMS-21816 

DATE				VER		CREATEDBY   PURPOSE
19-FEB-2022			1.0		PCN			CONVERT SCRIPT TO SP 
2023-03-21			1.2		Crisnah		Change para datatype and filter condition .
2023-04-11			1.3		Percival	Change para datatype and filter condition .
2023-06-13			1.4		Percival	Deploy the sp in PHWMS PROD & UAT https://jiralfl.atlassian.net/browse/WMS-22570 .
************************************************************************/

CREATE     PROC [BI].[nsp_NIKE_PackingLoadkeyCaseID] --NAME OF SP */		
			@PARAM_GENERIC_Wavekey NVARCHAR(4000) 
			, @PARAM_GENERIC_Loadkey NVARCHAR(50) 
			, @PARAM_GENERIC_ExternOrderKey NVARCHAR(4000) 
			,@PARAM_GENERIC_STARTDATE DATETIME			--REQUIRED
			,@PARAM_GENERIC_ENDDATE DATETIME			--REQUIRED
			
AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

	
  IF ISNULL(@PARAM_GENERIC_Wavekey, '') = ''  or @PARAM_GENERIC_Wavekey = 'ALL'
    SET @PARAM_GENERIC_Wavekey = ''
  IF ISNULL(@PARAM_GENERIC_Loadkey, '') = ''  
    SET @PARAM_GENERIC_Loadkey = ''
  IF ISNULL(@PARAM_GENERIC_ExternOrderKey, '') = ''  or @PARAM_GENERIC_ExternOrderKey ='ALL'
    SET @PARAM_GENERIC_ExternOrderKey = ''
  IF ISNULL(@PARAM_GENERIC_STARTDATE, '') = ''
    SET @PARAM_GENERIC_STARTDATE = getdate()
  IF ISNULL(@PARAM_GENERIC_ENDDATE, '') = ''
	SET @PARAM_GENERIC_ENDDATE = dateadd(hour,-1,getdate())

  SET @PARAM_GENERIC_Wavekey = REPLACE(REPLACE (TRANSLATE (@PARAM_GENERIC_Wavekey,'[ ]',''''''''),'''',''),',',''',''')
	
  -- set @PARAM_GENERIC_ExternOrderKey	= REPLACE(REPLACE(@PARAM_GENERIC_ExternOrderKey			,'[',''),']','')
  SET @PARAM_GENERIC_ExternOrderKey = REPLACE(REPLACE (TRANSLATE (@PARAM_GENERIC_ExternOrderKey,'[ ]',''''''''),'''',''),',',''',''')

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{  '
									+ '"PARAM_GENERIC_Wavekey":"'    +@PARAM_GENERIC_Wavekey+'", ' 
									+ '"PARAM_GENERIC_Loadkey":"'    +@PARAM_GENERIC_Loadkey+'", '
									+ '"PARAM_GENERIC_ExternOrderKey":"'    +@PARAM_GENERIC_ExternOrderKey+'", '
									+ '"PARAM_GENERIC_STARTDATE":"'    +CONVERT(VARCHAR,@PARAM_GENERIC_STARTDATE,120)+'",  '
									+ '"PARAM_GENERIC_ENDDATE":"'    +CONVERT(VARCHAR,@PARAM_GENERIC_ENDDATE,120)+'"  '
                                    + ' }'  

   EXEC BI.dspExecInit @ClientId = 'NIKEPH'
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
	DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/
set @Stmt = '
	SELECT 
	  DISTINCT AL2.MBOLKey as ''01MBOLKey'', 
	  AL2.LoadKey as ''02LoadKey'', 
	  AL2.OrderKey as ''03OrderKey'', 
	  AL2.ExternOrderKey as ''04ExternOrderKey'', 
	  AL1.Status as ''05Status'', 
	  case AL1.Status 
		when ''0'' then ''Open''
		when ''9'' then ''Packed''
	  end as ''06PackStatus'',	
	  AL1.PickSlipNo as ''07PickSlipNo'', 
	  AL3.Loc as ''08Loc'', 
	  AL3.DropID as ''09DropID'', 
	  AL2.PrintFlag as ''10PrintFlag'', 
	  AL2.UserDefine09 as ''11WaveKey'', 
	  SUM (AL3.Qty) as ''12Qty'', 
	  AL3.ID as ''13ID'', 
	  AL3.CaseID ''14CaseID'',
	  AL3.Sku as ''15SKU'', 
	  AL5.DESCR as ''16DESCR'', 
	  AL5.ALTSKU as ''17AltSKU'', 
      AL4A.UOM as ''18UOM'', 
      AL2.ConsigneeKey as ''19ConsigneeKey'', 
      AL2.C_Company as ''20C_Company'', 
      AL2.ExternPOKey as ''21ExternPOKey'', 
      AL2.UserDefine10 as ''22UserDefine10'', 
      AL6.CartonNo as ''23CartonNo'', 
      AL6.Weight as ''24Weight'', 
     SUM (AL6.Cube) as ''25Cube'', 
     AL6.CartonType as ''CartonType''
	FROM 
	  BI.V_ORDERS AL2 (NOLOCK)
	  JOIN BI.V_PackHeader AL1 (NOLOCK) on (AL1.StorerKey = AL2.StorerKey AND AL1.OrderKey = AL2.OrderKey AND AL1.LoadKey = AL2.LoadKey)  
	  JOIN BI.V_PICKDETAIL AL3 (NOLOCK) on (AL2.Storerkey = AL3.StorerKey AND AL2.OrderKey = AL3.OrderKey AND AL2.UserDefine09 = AL3.WaveKey AND AL1.PickSlipNo = AL3.PickSlipNo )
	  JOIN BI.V_WAVE AL4 (NOLOCK) on (AL2.UserDefine09 = AL4.Wavekey)
	  JOIN BI.V_ORDERDETAIL AL4A on (AL3.OrderKey = AL4A.OrderKey AND AL3.Sku = AL4A.Sku AND AL3.Storerkey = AL4A.StorerKey AND AL3.OrderLineNumber = AL4A.OrderLineNumber) 
      JOIN BI.V_SKU AL5 on (AL3.StorerKey = AL5.Storerkey AND AL3.Sku = AL5.Sku) 
      JOIN BI.V_PackDetail AL7 on (AL3.PickSlipNo = AL7.PickSlipNo AND AL3.StorerKey = AL7.Storerkey AND AL3.SKU = AL7.Sku)
	  JOIN BI.V_PackInfo AL6 on (AL7.PickSlipNo = AL6.PickSlipNo AND AL7.CartonNo = AL6.CartonNo)
  
	WHERE 
		  AL1.StorerKey = ''NIKEPH'' 
		  AND AL4.AddDate BETWEEN '''+convert(nvarchar,@PARAM_GENERIC_STARTDATE,120)+''' AND '''+convert(nvarchar,@PARAM_GENERIC_ENDDATE,120) +'''  '

if isnull(@PARAM_GENERIC_Wavekey,'')<>''
	set @stmt = @stmt + ' AND AL2.UserDefine09 IN ('''+@PARAM_GENERIC_Wavekey+''')  '


if isnull(@PARAM_GENERIC_Loadkey,'')<>'' OR isnull(@PARAM_GENERIC_ExternOrderKey,'')<>'' 
	set @stmt = @stmt + ' 
		  AND 
		     (  
'
 if isnull(@PARAM_GENERIC_Loadkey,'')<>''
	set @stmt = @stmt + ' AL2.LoadKey IN ('''+@PARAM_GENERIC_Loadkey+''')  '
 
 if isnull(@PARAM_GENERIC_Loadkey,'')<>'' and isnull(@PARAM_GENERIC_ExternOrderKey,'')<>'' 
	set @stmt = @stmt + ' OR '

 if isnull(@PARAM_GENERIC_ExternOrderKey,'')<>''
	set @stmt = @stmt + 'AL2.ExternOrderKey in ('''+@PARAM_GENERIC_ExternOrderKey+''') '

if isnull(@PARAM_GENERIC_Loadkey,'')<>'' OR isnull(@PARAM_GENERIC_ExternOrderKey,'')<>'' 
	set @stmt = @stmt + ' 
	         )
'

set @stmt = @stmt + '
	GROUP BY 
	  AL2.MBOLKey, 
	  AL2.UserDefine09, 
	  AL2.LoadKey, 
	  AL2.OrderKey, 
	  AL2.ExternOrderKey, 
	  AL1.Status, 
	  AL1.PickSlipNo, 
	  AL3.Loc, 
	  AL3.DropID, 
	  AL2.PrintFlag, 
	  AL3.ID, 
	  AL3.CaseID ,
	  AL3.Sku, 
	  AL5.DESCR, 
	  AL5.ALTSKU, 
      AL4A.UOM, 
      AL2.ConsigneeKey, 
      AL2.C_Company, 
      AL2.ExternPOKey, 
      AL2.UserDefine10, 
      AL6.CartonNo, 
      AL6.Weight,  
     AL6.CartonType 

	ORDER BY 
	  3, 
	  4

'  

/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO