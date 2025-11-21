SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
TITLE: PH_LogiReport - Create SP ULP Case Fill Rate PHWMS https://jiralfl.atlassian.net/browse/WMS-23068

DATE				VER		CREATEDBY   PURPOSE
2023-07-14			1.0		JAM			MIGRATE FROM HYPERION USING PHWMS
************************************************************************/

CREATE   PROC [BI].[nsp_ULP_PHWMSCaseFillRate] --NAME OF SP
	@PARAM_GENERIC_STORERKEY		NVARCHAR(20)	
	,@PARAM_GENERIC_FACILITY		NVARCHAR(20)	
	,@PARAM_GENERIC_EDITDATEFROM	DATETIME		
	,@PARAM_GENERIC_EDITDATETO		DATETIME
	,@Param_Orders_Status     NVARCHAR(30)	
	,@PARAM_ORDERS_USERDEFINE06STARTDATE DATETIME
	,@PARAM_ORDERS_USERDEFINE06ENDDATE DATETIME

AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

	IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		SET @PARAM_GENERIC_StorerKey = ''
	IF ISNULL(@PARAM_GENERIC_FACILITY, '') = ''
		  SET @PARAM_GENERIC_FACILITY = ''
	IF ISNULL(@PARAM_GENERIC_EDITDATEFROM, '') = ''
		  SET @PARAM_GENERIC_EDITDATEFROM = CONVERT(VARCHAR(10), GETDATE()-32, 121)
	IF ISNULL(@PARAM_GENERIC_EDITDATETO, '') = ''
		  SET @PARAM_GENERIC_EDITDATETO = CONVERT(VARCHAR(10), GETDATE()-32, 121)
	IF ISNULL(@Param_Orders_Status, '') = ''
		SET @Param_Orders_Status = '9'
	SET @Param_Orders_Status = REPLACE(REPLACE (TRANSLATE (@Param_Orders_Status,'[ ]',''' '''),'''',''),', ',''',''')

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_StorerKey":"'    +@PARAM_GENERIC_StorerKey+'"'
                                    + '"PARAM_GENERIC_FACILITY":"'    +@PARAM_GENERIC_FACILITY+'"'
                                    + '"PARAM_GENERIC_EDITDATEFROM":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EDITDATEFROM,121)+'",'
                                    + '"PARAM_GENERIC_EDITDATETO":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EDITDATETO,121)+'"'
                                    + '"PARAM_GENERIC_STATUS":"'    +@Param_Orders_Status+'"  '+  '}'

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

set @Stmt = 'SELECT 
M.EditDate as ''ShippedDate'', 
  O.UserDefine06 as ''LoadingDate'', 
  O.AddDate as ''InterfaceDate'', 
  O.UserDefine09 as ''Wave'',
  O.Status,
  O.OrderGroup as ''Shipment'', 
  O.ExternOrderKey as ''OBD'', 
  O.ConsigneeKey as ''ShipTo'', 
  O.C_Company as ''ShipTo Name'', 
  s.SUSR2 as ''RotationRule'', 
  M.EditDate as ''ShipDateTime'', 
  M.MbolKey, 
  OD.Sku, 
  S.DESCR, 
  SUM (OD.OriginalQty / nullif(P.CaseCnt, 0)  ) as ''OrderQty-CS'', 
  SUM (OD.QtyAllocated / nullif(P.CaseCnt, 0)  ) as ''QtyAllocated-CS'', 
  SUM (OD.QtyPreAllocated / nullif(P.CaseCnt, 0)  ) as ''QtyPreallocated-CS'', 
  SUM (OD.QtyPicked / nullif(P.CaseCnt, 0)  ) as ''QtyPicked-CS'', 
  SUM (OD.ShippedQty / nullif(P.CaseCnt, 0)  ) as ''QtyShipped-CS'', 
  case O.Status when ''0'' then ''Open'' when ''1'' then ''Partially Allocated'' when ''2'' then ''Fully Allocated''
  when ''3'' then ''Pick In Progress'' when ''5'' then ''Picked'' when ''9'' then ''Shipped'' end as ''OrderStatus'', 
  O.EditDate 
FROM 
	BI.V_ORDERS O (NOLOCK) 
	JOIN BI.V_ORDERDETAIL OD (nolock) ON O.ORDERKEY=OD.ORDERKEY
	LEFT JOIN BI.V_MBOL M (nolock) ON M.MbolKey=O.MBOLKey 
		and m.EditDate BETWEEN '''+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EDITDATEFROM,121)+''' 
		AND '''+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EDITDATETO,121)+'''
	JOIN BI.V_SKU S (nolock) ON OD.StorerKey=S.StorerKey AND OD.Sku=S.Sku
	JOIN BI.V_PACK P (nolock) ON S.PACKKey=P.PackKey
WHERE 
	O.StorerKey='''+@PARAM_GENERIC_STORERKEY+''' 
	AND o.FACILITY='''+@PARAM_GENERIC_FACILITY+''' 
	and o.EditDate BETWEEN '''+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EDITDATEFROM,121)+''' 
	AND '''+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EDITDATETO,121)+'''
	AND O.STATUS IN ('''+@Param_Orders_Status+''')
	AND O.USERDEFINE06 >= '''+CONVERT(NVARCHAR(19),@PARAM_ORDERS_USERDEFINE06STARTDATE,101)+'''
	AND O.USERDEFINE06 <= '''+CONVERT(NVARCHAR(19),@PARAM_ORDERS_USERDEFINE06ENDDATE,101)+'''
GROUP BY 
  O.UserDefine06, 
  O.AddDate, 
  O.UserDefine09, 
  O.OrderGroup, 
  O.ExternOrderKey, 
  O.ConsigneeKey, 
  O.C_Company, 
  S.SUSR2, 
  M.EditDate, 
  M.MbolKey, 
  OD.Sku, 
  S.DESCR, 
  O.Status,
  case O.Status when ''0'' then ''Open'' when ''1'' then ''Partially Allocated'' when ''2'' then ''Fully Allocated''
  when ''3'' then ''Pick In Progress'' when ''5'' then ''Picked'' when ''9'' then ''Shipped'' end, 
  O.EditDate 
ORDER BY 
  2 DESC, 
  4, 
5'

/*************************** FOOTER *******************************/

   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO