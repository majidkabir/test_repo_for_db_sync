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
-- Test:   EXEC BI.dspPickSlip_KFMY 'KFMY', 'KV' ,'2022-04-01','2022-04-20'
-- Test:   EXEC BI.dspPickSlip_KFMY 'KFMY,KFTWI', 'KV' ,'2022-04-01','2022-04-20'
-- Test:   EXEC BI.dspPickSlip_KFMY '','','',''
-- Test:   EXEC BI.dspPickSlip_KFMY NULL,NULL,NULL,NULL

CREATE PROC [BI].[dspPickSlip_KFMY]
	@PARAM_GENERIC_StorerKey NVARCHAR(200) 
  ,@PARAM_GENERIC_Facility  NVARCHAR(200)  
  ,@PARAM_GENERIC_AddDateFrom DATETIME 
  ,@PARAM_GENERIC_AddDateTo DATETIME 

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
         , @Proc      NVARCHAR(128) = 'dspPickSlip_KFMY'
         , @cParamOut NVARCHAR(4000)= ''
         , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_StorerKey":"'    +@PARAM_GENERIC_StorerKey+'"'
                                    + '"PARAM_GENERIC_Facility":"'    +@PARAM_GENERIC_Facility+'"'
                                    + '"PARAM_GENERIC_AddDateFrom":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_AddDateFrom,121)+'",'
                                    + '"PARAM_GENERIC_AddDateTo":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_AddDateTo,121)+'"'
                                    + ' }'

DECLARE @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutionLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (@PARAM_GENERIC_StorerKey, @Proc, @cParamIn);

	DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

	 SET @Stmt ='SELECT [RowIndex] = ROW_NUMBER() OVER (PARTITION BY o.Loadkey ORDER BY ph.PickHeaderkey, pd.Sku, pd.Loc)
	, o.Storerkey
	, o.Facility
	, o.Orderkey
	, o.ExternOrderkey
	, o.DeliveryDate
	, o.OrderDate
	, o.AddDate
	, o.EditDate
	, o.Loadkey
	, o.Consigneekey
	, o.C_Company
	, o.C_Address1
	, o.C_Address2
	, o.C_Address3
	, o.C_Address4
	, o.C_Zip
	, o.C_City
	, o.C_State
	, o.Status
	, [OrderStatus] = (SELECT MAX(Description) FROM CODELKUP (NOLOCK) WHERE LISTNAME = ''ORDRSTATUS'' AND CODE = o.Status)
	, o.SOStatus
	, [ExternOrderStatus] = (SELECT MAX(Description) FROM CODELKUP (NOLOCK) WHERE LISTNAME = ''SOSTATUS'' AND CODE = o.SOStatus)
	, o.Route
	, o.Type
	, PickSlipNo = ph.PickHeaderkey
	, pd.Lot
	, Loc = UPPER(pd.Loc)
	, pd.ID
	, pd.OrderLineNumber
	, pd.Sku
	, s.Descr
	, [Qty] = SUM(pd.Qty)
	, pd.Packkey
	, s.SkuGroup
	, STDGrosswgt = ROUND(s.STDGrosswgt, 4)
	, STDCube = ROUND(s.STDCube, 4)
	, [m3] = s.STDCube * SUM(d.QtyPicked)
	, [TotalKG] = s.STDGrosswgt * SUM(d.Qtypicked)
	, [Ctn] = CASE WHEN p.Casecnt <> 0 THEN ROUND((SUM(pd.Qty)/ p.Casecnt), 6) ELSE (SUM(pd.Qty)/1) END
	, [Plt] = CASE WHEN p.Pallet <> 0 THEN ROUND((SUM(pd.Qty)/ p.Pallet), 6) ELSE (SUM(pd.Qty)/1) END
	, p.PackUOM1
	, p.Casecnt
	, p.PackUOM4
	, p.Pallet
	, la.Lottable01
	, la.Lottable02		--BatchNo
	, la.Lottable03
	, la.Lottable04		--ExpiryDate
	, la.Lottable05		--ReceiptDate
	, l.LogicalLocation
	, [Cases] = CASE WHEN p.Casecnt <> 0 THEN (SUM(d.QtyPicked)/ p.Casecnt) ELSE NULL END
	, [Pallet] = CASE WHEN p.Pallet <> 0 THEN (SUM(d.QtyPicked)/ p.Pallet) ELSE NULL END
	, [Carton_Pallet] = CASE WHEN p.Casecnt <> 0 THEN p.Pallet/ p.Casecnt ELSE p.Pallet/1 END	--CTN/PLT
	, [OrderDay] = DAY(o.OrderDate)
	, [Week] = CASE WHEN DAY(o.OrderDate) > 0 AND DAY(o.OrderDate) <= 7 THEN ''WEEK1''
					WHEN DAY(o.OrderDate) > 7 AND DAY(o.OrderDate) <= 14 THEN ''WEEK2''
					WHEN DAY(o.OrderDate) > 14 AND DAY(o.OrderDate) <= 21 THEN ''WEEK3''
					WHEN DAY(o.OrderDate) > 21 AND DAY(o.OrderDate) <= 28 THEN ''WEEK4'' END
	, [a] = SUBSTRING(s.SkuGroup, 1, 2)
'
SET @stmt = @stmt + '

FROM dbo.ORDERS o (NOLOCK)
JOIN dbo.ORDERDETAIL d (NOLOCK) ON o.ORDERKEY = d.ORDERKEY
JOIN dbo.PICKHEADER ph (NOLOCK) ON o.ORDERKEY = ph.ORDERKEY
JOIN dbo.PICKDETAIL pd (NOLOCK) ON d.ORDERKEY = pd.ORDERKEY AND d.OrderLineNumber = pd.OrderLineNumber AND d.Sku = pd.Sku
JOIN dbo.LOTATTRIBUTE la (NOLOCK) ON pd.LOT = la.LOT
JOIN dbo.SKU s (NOLOCK) ON d.SKU = s.SKU AND d.STORERKEY = s.STORERKEY
JOIN dbo.LOC l (NOLOCK) ON pd.LOC = l.LOC
JOIN dbo.PACK p (NOLOCK) ON s.PACKKEY = p.PACKKEY

WHERE o.STORERKEY IN ('''+ @PARAM_GENERIC_StorerKey +''')  --(''KFMY'', ''KFTWI'')
AND o.FACILITY IN ('''+ @PARAM_GENERIC_Facility +''')--(''KV'', ''KVMDZ'')
AND o.ADDDATE BETWEEN '''+CONVERT(CHAR(10),@PARAM_GENERIC_AddDateFrom,121)+''' AND '''+CONVERT(CHAR(10),@PARAM_GENERIC_AddDateTo,121)+'''
AND o.Status < ''3''

GROUP BY o.Storerkey
	, o.Facility
	, o.Orderkey
	, o.ExternOrderkey
	, o.Loadkey
	, ph.PickHeaderkey
	, pd.Sku
	, pd.Loc
	, o.DeliveryDate
	, o.OrderDate
	, o.AddDate
	, o.EditDate
	, o.Consigneekey
	, o.C_Company
	, o.C_Address1
	, o.C_Address2
	, o.C_Address3
	, o.C_Address4
	, o.C_Zip
	, o.C_City
	, o.C_State
	, o.Status
	, o.SOStatus
	, o.Route
	, o.Type
	, pd.Lot
	, pd.ID
	, pd.OrderLineNumber
	, s.Descr
	, pd.Packkey
	, s.SkuGroup
	, s.STDGrosswgt
	, s.STDCube
	, p.PackUOM1
	, p.Casecnt
	, p.PackUOM4
	, p.Pallet
	, la.Lottable01
	, la.Lottable02		--BatchNo
	, la.Lottable03
	, la.Lottable04		--ExpiryDate
	, la.Lottable05		--ReceiptDate
	, l.LogicalLocation

ORDER BY STORERKEY, FACILITY, PICKSLIPNO, SKU ASC
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