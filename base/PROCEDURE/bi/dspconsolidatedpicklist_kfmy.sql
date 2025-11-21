SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************************************/
-- Purpose  : MYSLogiReport-Create SP in BI Schema https://jiralfl.atlassian.net/browse/WMS-19521
/* Updates:                                                                                           */
/* Date         Author      Ver.  Purposes                                                            */
/* 22-Apr-2022  gywong      1.0   Created                                                             */
/******************************************************************************************************/
-- Test:   EXEC BI.dspConsolidatedPickList_KFMY 'KFMY', 'KV' ,'2022-04-01','2022-04-20'
-- Test:   EXEC BI.dspConsolidatedPickList_KFMY 'KFMY,KFTWI', 'KV' ,'2022-04-01','2022-04-20'
-- Test:   EXEC BI.dspConsolidatedPickList_KFMY '','','',''
-- Test:   EXEC BI.dspConsolidatedPickList_KFMY NULL,NULL,NULL,NULL

CREATE PROC [BI].[dspConsolidatedPickList_KFMY]
	@PARAM_GENERIC_StorerKey NVARCHAR(200) 
  ,@PARAM_GENERIC_Facility  NVARCHAR(200)  
  ,@PARAM_GENERIC_OrderDateFrom DATETIME 
  ,@PARAM_GENERIC_OrderDateTo DATETIME 

AS
BEGIN
SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;


		IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		      SET @PARAM_GENERIC_StorerKey = ''

		IF ISNULL(@PARAM_GENERIC_Facility, '') = ''
		      SET @PARAM_GENERIC_Facility = ''

         SET @PARAM_GENERIC_StorerKey = REPLACE(REPLACE(TRANSLATE (@PARAM_GENERIC_StorerKey,'[ ]',''' '''),'''',''),',',''',''')
         SET @PARAM_GENERIC_Facility = REPLACE(REPLACE (TRANSLATE (@PARAM_GENERIC_Facility,'[ ]',''' '''),'''',''),',',''',''')



DECLARE    @nRowCnt INT = 0
         , @Proc      NVARCHAR(128) = 'dspConsolidatedPickList_KFMY'
         , @cParamOut NVARCHAR(4000)= ''
         , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_StorerKey":"'    +@PARAM_GENERIC_StorerKey+'"'
                                    + '"PARAM_GENERIC_Facility":"'    +@PARAM_GENERIC_Facility+'"'
                                    + '"PARAM_GENERIC_OrderDateFrom":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_OrderDateFrom,121)+'",'
                                    + '"PARAM_GENERIC_OrderDateTo":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_OrderDateTo,121)+'"'
                                    + ' }'

DECLARE @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutionLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (@PARAM_GENERIC_StorerKey, @Proc, @cParamIn);

	DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

	SET @Stmt ='
	
	SELECT o.Storerkey
	, o.Facility
	, o.Orderkey
	, o.ExternOrderkey
	, o.DeliveryDate
	, o.OrderDate
	, o.AddDate
	, o.EditDate
	, o.Loadkey
	, o.Status
	, [OrderStatus] = (SELECT MAX(Description) FROM CODELKUP (NOLOCK) WHERE LISTNAME = ''ORDRSTATUS'' AND CODE = o.Status)
	, o.SOStatus
	, [ExternOrderStatus] = (SELECT MAX(Description) FROM CODELKUP (NOLOCK) WHERE LISTNAME = ''SOSTATUS'' AND CODE = o.SOStatus)
	, [PODStatus] = pod.Status
	, [POD_Status] = (SELECT MAX(Description) FROM CODELKUP (NOLOCK) WHERE LISTNAME = ''PODSTATUS'' AND CODE = pod.Status)
	, o.Consigneekey
	, o.C_Company
	, o.C_Address1
	, o.C_Address2
	, o.C_Address3
	, o.C_Address4
	, o.C_Zip
	, o.C_City
	, o.C_State
	, o.C_Contact1
	, o.C_Contact2
	, o.BilltoKey
	, o.B_Company
	, o.B_Address1
	, o.B_Address2
	, o.B_Address3
	, o.B_Address4
	, o.B_Contact1
	, o.B_Contact2
	--, o.Mbolkey
	, o.Type
	, o.Route
	, d.OrderLineNumber
	, d.ExternLineNo
	, d.Sku
	, s.Descr
	, d.OriginalQty
	, d.QtyAllocated
	, d.QtyPicked
	, d.ShippedQty
	, [PickedQty] = pd.Qty
	, d.Packkey
	, p.PackDescr
	, STDGrosswgt  =ROUND(s.STDGrosswgt, 4)
	, STDCube = ROUND(s.STDCube, 4)
	, s.SkuGroup
	, [m3] = s.STDCube * d.QtyPicked
	, [TotalKG] = s.STDGrosswgt * d.Qtypicked
	, s.Price
	, [TotalAmount] = d.QtyPicked * s.Price
	, s.SUSR4		--Sku Tolerance
	, s.Shelflife
	, Loc = UPPER(pd.Loc)
	, pd.Lot
	, pd.ID
	, p.PackUOM1
	, p.PackUOM2
	, p.PackUOM3
	, p.Casecnt
	, p.Innerpack
	, p.Pallet
	, [Cases] = CASE WHEN p.Casecnt <> 0 THEN (d.QtyPicked/ p.Casecnt) ELSE NULL END
	, [Pallet] = CASE WHEN p.Pallet <> 0 THEN (d.QtyPicked/ p.Pallet) ELSE NULL END
	, [Calplt] = CASE WHEN p.Casecnt <> 0 THEN (d.QtyPicked/ p.Pallet) ELSE NULL END
	, [OrderDay] = DAY(o.OrderDate)
	, [Week] = CASE WHEN DAY(o.OrderDate) > 0 AND DAY(o.OrderDate) <= 7 THEN ''WEEK1''
					WHEN DAY(o.OrderDate) > 7 AND DAY(o.OrderDate) <= 14 THEN ''WEEK2''
					WHEN DAY(o.OrderDate) > 14 AND DAY(o.OrderDate) <= 21 THEN ''WEEK3''
					WHEN DAY(o.OrderDate) > 21 AND DAY(o.OrderDate) <= 28 THEN ''WEEK4'' END
	, l.Lottable01
	, l.Lottable02
	, l.Lottable03
	, l.Lottable04
	, l.Lottable05
'

SET @Stmt = @Stmt+ '
FROM dbo.ORDERS o (NOLOCK)
JOIN dbo.ORDERDETAIL d (NOLOCK) ON o.ORDERKEY = d.ORDERKEY
JOIN dbo.PICKDETAIL pd (NOLOCK) ON o.ORDERKEY = pd.ORDERKEY AND d.ORDERLINENUMBER = pd.ORDERLINENUMBER
JOIN dbo.SKU s (NOLOCK) ON d.SKU = s.SKU AND d.STORERKEY = s.STORERKEY
JOIN dbo.PACK p (NOLOCK) ON s.PACKKEY = p.PACKKEY
LEFT JOIN dbo.POD pod (NOLOCK) ON o.MBOLKEY = pod.MBOLKEY AND o.ORDERKEY = pod.ORDERKEY
JOIN dbo.LOTATTRIBUTE l (NOLOCK) ON pd.Lot = l.Lot

WHERE o.Storerkey IN ('''+ @PARAM_GENERIC_StorerKey +''') 
AND o.Facility IN ('''+ @PARAM_GENERIC_Facility +''')--(''KV'', ''KVMDZ'')
AND o.OrderDate BETWEEN '''+CONVERT(CHAR(10),@PARAM_GENERIC_OrderDateFrom,121)+''' AND '''+CONVERT(CHAR(10),@PARAM_GENERIC_OrderDateTo,121)+'''

ORDER BY STORERKEY, FACILITY, ORDERKEY ASC
'
  --PRINT @Stmt  
   --PRINT SUBSTRING(@stmt,4001,8000)
   --PRINT SUBSTRING(@stmt,8001,12000)
   --PRINT SUBSTRING(@stmt,12001,16000)
    EXEC sp_ExecuteSql @Stmt;

   SET @nRowCnt = @@ROWCOUNT;
   SET @cParamOut = '{ "Stmt": "'+@Stmt+'" }'; -- for dynamic SQL only
   UPDATE dbo.ExecutionLog SET TimeEnd = GETDATE(), RowCnt = @nRowCnt, ParamOut = @cParamOut
   WHERE LogId = (SELECT TOP 1 LogId FROM @tVarLogId);

END --procedure

GO