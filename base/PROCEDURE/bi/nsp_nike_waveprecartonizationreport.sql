SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************  
 TITLE: NIKE Wave Pre-Cartonization Report  https://jiralfl.atlassian.net/browse/WMS-22171
  
DATE    VER  CREATEDBY   PURPOSE  
2023-02-02   1.0  JAM   MIGRATE FROM HYPERION
************************************************************************/  
  
CREATE    PROC [BI].[nsp_NIKE_WavePreCartonizationReport] --NAME OF SP  
   @PARAM_GENERIC_STORERKEY NVARCHAR(30)=''  
   ,@PARAM_ORDERS_USERDEFINE09 NVARCHAR(30)=''  
   ,@PARAM_ORDERS_EXTERNORDERKEY NVARCHAR(30)=''  
  
AS  
BEGIN  
 SET NOCOUNT ON;  -- keeps the output generated to a minimum   
   SET ANSI_NULLS OFF;  
   SET QUOTED_IDENTIFIER OFF;  
   SET CONCAT_NULL_YIELDS_NULL OFF;  
  
 IF ISNULL(@PARAM_GENERIC_STORERKEY, '') = ''  
  SET @PARAM_GENERIC_STORERKEY = ''  
   
 IF ISNULL(@PARAM_ORDERS_USERDEFINE09, '') = ''  
  SET @PARAM_ORDERS_USERDEFINE09 = ''  
  
 IF ISNULL(@PARAM_ORDERS_EXTERNORDERKEY, '') = ''  
  SET @PARAM_ORDERS_EXTERNORDERKEY = ''  
  
  DECLARE @Debug BIT = 0  
   , @LogId   INT  
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')  
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')  
       , @cParamOut NVARCHAR(4000)= ''  
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_STORERKEY":"'    +@PARAM_GENERIC_STORERKEY+'", '  
         + '"PARAM_ORDERS_USERDEFINE09":"'    +@PARAM_ORDERS_USERDEFINE09+'",  '  
         + '"PARAM_ORDERS_EXTERNORDERKEY":"'    +@PARAM_ORDERS_EXTERNORDERKEY+'"  '  
                                    + ' }'  
  
   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey  
   , @Proc = @Proc  
   , @ParamIn = @cParamIn  
   , @LogId = @LogId OUTPUT  
   , @Debug = @Debug OUTPUT  
   , @Schema = @Schema;  
 DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only  
  
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/  
/**********************************************************************  
 NOTES:  
 USE BI SCHEMA - PHWMS=BI.V_ORDERS , PH_DATAMART=BI.V_DM_ORDERS, PHDTSITF=BI.V_DTS_IN_FILE  
 USE NO LOCK  
 USE JOIN TABLES INSTEAD OF COMMA, FOR EASY & READABLE QUERY  
 **********************************************************************/  
  
 set @stmt =
 '
;WITH A (aStorerkey,aUserdefine09,aExternorderkey,aCartonNo,aCube,aOrderkey) as
(SELECT 
  DISTINCT O.StorerKey, 
  O.UserDefine09, 
  O.ExternOrderKey, 
  COUNT (DISTINCT PAI.CartonNo), 
  SUM (PAI.Cube), 
  O.OrderKey 
FROM 
  BI.V_ORDERS O
  INNER JOIN BI.V_PackHeader PH ON O.StorerKey = PH.StorerKey 
  AND O.OrderKey = PH.OrderKey 
 INNER JOIN BI.V_PackInfo PAI ON PH.PickSlipNo = PAI.PickSlipNo
WHERE 
O.StorerKey ='''+@PARAM_GENERIC_STORERKEY+''''  
if isnull(@PARAM_ORDERS_USERDEFINE09,'') <> ''  
 set @stmt = @stmt + ' AND O.Userdefine09 in ('''+@PARAM_ORDERS_USERDEFINE09+''') '  
if isnull(@PARAM_ORDERS_externORDERKEY,'') <> ''  
 set @stmt = @stmt + ' AND O.ExternOrderKey in ('''+@PARAM_ORDERS_externORDERKEY+''') ' 
 set @stmt = @stmt + '
 GROUP BY 
O.StorerKey, 
O.UserDefine09, 
O.ExternOrderKey, 
O.OrderKey
)
, b (bStdCube,bStorerkey,bOrderkey) as
(SELECT 
DISTINCT SUM (PD.Qty * S.STDCUBE), 
PD.Storerkey, 
PD.OrderKey 
FROM 
BI.V_PICKDETAIL PD
INNER JOIN BI.V_SKU S ON PD.Storerkey = S.StorerKey AND PD.Sku = S.Sku
INNER JOIN A ON A.aStorerkey=PD.Storerkey AND A.aOrderkey=PD.OrderKey
GROUP BY 
PD.Storerkey, 
PD.OrderKey
)
select 
a.aStorerkey [Storerkey]
,a.aOrderkey [Orderkey]
,a.aExternorderkey [ExternOrderkey]
,a.aUserdefine09 [Wavekey]
,a.aCartonNo [Total Cartons]
,a.aCube [Total Carton Cube]
,b.bStdCube [Ttl Sku CMB]
from A join b on a.aStorerkey=b.bStorerkey and a.aOrderkey=b.bOrderkey
'
 
  
  
/*************************** FOOTER *******************************/  
  
   EXEC BI.dspExecStmt @Stmt = @Stmt  
   , @LogId = @LogId  
   , @Debug = @Debug;  
  
END

GO