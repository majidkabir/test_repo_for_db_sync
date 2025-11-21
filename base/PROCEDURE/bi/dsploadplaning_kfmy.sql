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
-- Test:   EXEC BI.dspLoadPlaning_KFMY 'KFMY', 'KV' ,'2022-04-01','2022-04-20'
-- Test:   EXEC BI.dspLoadPlaning_KFMY 'KFMY,KFTWI', 'KV' ,'2022-04-01','2022-04-20'
-- Test:   EXEC BI.dspLoadPlaning_KFMY '','','',''
-- Test:   EXEC BI.dspLoadPlaning_KFMY NULL,NULL,NULL,NULL

CREATE PROC [BI].[dspLoadPlaning_KFMY]
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
         , @Proc      NVARCHAR(128) = 'dspLoadPlaning_KFMY'
         , @cParamOut NVARCHAR(4000)= ''
         , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_StorerKey":"'    +@PARAM_GENERIC_StorerKey+'"'
                                    + '"PARAM_GENERIC_Facility":"'    +@PARAM_GENERIC_Facility+'"'
                                    + '"PARAM_GENERIC_AddDateFrom":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_AddDateFrom,121)+'",'
                                    + '"PARAM_GENERIC_AddDateTo":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_AddDateTo,121)+'"'
                                    + ' }'

DECLARE @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutionLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (@PARAM_GENERIC_StorerKey, @Proc, @cParamIn);

	DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

	 SET @Stmt ='SELECT o.Storerkey
	, o.Facility
	, o.Orderkey 
	, o.ExternOrderkey
	, o.DeliveryDate
	, o.AddDate
	, o.OrderDate
	, o.EditDate
	, o.EffectiveDate
	, o.Loadkey
	, t.Route
	, o.Status
	, [OrderStatus] = (SELECT MAX(Description) FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME = ''ORDRSTATUS'' AND CODE = o.Status)
	, o.Consigneekey
	, o.C_Company
	, o.C_Address1
	, o.C_Address2
	, o.C_Address3
	, o.C_Address4
	, o.C_City
	, o.C_State
	, o.C_Zip
	, o.C_Country
	, [NoofOrderLine] = COUNT(d.Sku)
	, d.Sku
	, s.Descr
	, d.OriginalQty
	, d.QtyAllocated
	, d.ShippedQty
	, [CTN] = CASE WHEN p.Casecnt <> 0 THEN ROUND((d.OriginalQty - (d.OriginalQty % CAST(p.Casecnt AS INT))/ p.Casecnt), 4) ELSE 0 END
	, [OTR] = CASE WHEN p.Innerpack <> 0 THEN ((d.OriginalQty - (ROUND((d.OriginalQty - (d.OriginalQty % CAST(p.Casecnt AS INT))/ p.Casecnt), 4) * p.Casecnt)) - ((d.OriginalQty - (ROUND((d.OriginalQty - (d.OriginalQty % CAST(p.Casecnt AS INT))/ CAST(p.Casecnt AS INT)), 4) * CAST(p.Casecnt AS INT))) % CAST(p.Innerpack AS INT)))/ p.Innerpack ELSE 0 END
	--(Originalqty-(Ctn*Casecnt)-((Originalqty-(Ctn*Casecnt))%Innerpack))/Innerpack
	, [PLT] = CASE WHEN p.Pallet <> 0 THEN ROUND((d.OriginalQty/ p.Pallet), 4) ELSE 0 END
	, [Ctn_S] = CASE WHEN p.Casecnt <> 0 THEN ROUND((d.ShippedQty/ p.Casecnt), 4) ELSE 0 END
	, [EstimatePlt] = CASE WHEN p.Pallet <> 0 THEN ROUND((d.OriginalQty/ p.Pallet), 4) ELSE 0 END
	, [CartonCount] = CASE WHEN p.Casecnt <> 0 THEN ROUND((d.OriginalQty/ p.Casecnt), 1) ELSE 0 END
	, p.Casecnt
	, p.Innerpack
	, p.Pallet
	, p.PackUOM1
	, p.PackUOM2
	, p.PackUOM3
	, s.Length
	, s.Width
	, s.Height
	, [a] = s.Length * s.Width * s.Height
	, [b] = (s.Length * s.Width * s.Height)/ 10
	, [c] = ((s.Length * s.Width * s.Height)/ 10)/ 100
	, [m3] = CASE WHEN p.Casecnt <> 0 THEN ROUND((((((s.Length * s.Width * s.Height)/ 10)/ 100)/ 1000000) * (d.OriginalQty - (d.OriginalQty % CAST(p.Casecnt AS INT))/ p.Casecnt)), 4) END
	, [STDGrosswgt] = ROUND(s.STDGrosswgt, 4)
	, [STDCube] = ROUND(s.STDCube, 4)
	, [Estimatedm3] = ROUND((s.STDCube * d.OriginalQty), 4)
	, [EstimatedWeight] = ROUND((s.STDGrosswgt * d.OriginalQty), 4)
	, o.Userdefine01'

SET @stmt = @stmt + '

FROM dbo.ORDERS o (NOLOCK)
JOIN dbo.ORDERDETAIL d (NOLOCK) ON o.ORDERKEY = d.ORDERKEY
JOIN dbo.SKU s (NOLOCK) ON d.SKU = s.SKU AND d.STORERKEY = s.STORERKEY
JOIN dbo.PACK p (NOLOCK) ON s.PACKKEY = p.PACKKEY
LEFT JOIN dbo.STORERSODEFAULT t (NOLOCK) ON o.CONSIGNEEKEY = t.STORERKEY

WHERE o.STORERKEY IN ('''+ @PARAM_GENERIC_StorerKey +''')  --(''KFMY'', ''KFTWI'')
AND o.FACILITY IN ('''+ @PARAM_GENERIC_Facility +''')--(''KV'', ''KVMDZ'')
AND o.ADDDATE BETWEEN '''+CONVERT(char(10),@PARAM_GENERIC_AddDateFrom,121)+''' AND '''+CONVERT(char(10),@PARAM_GENERIC_AddDateTo,121)+'''

GROUP BY o.Storerkey
	, o.Facility
	, o.Orderkey
	, o.ExternOrderkey
	, o.DeliveryDate
	, o.AddDate
	, o.OrderDate
	, o.EditDate
	, o.EffectiveDate
	, o.Loadkey
	, o.Consigneekey
	, o.C_Company
	, o.C_Address1
	, o.C_Address2
	, o.C_Address3
	, o.C_Address4
	, o.C_City
	, o.C_State
	, o.C_Zip
	, o.C_Country
	, d.Sku
	, s.Descr
	, d.OriginalQty
	, d.QtyAllocated
	, d.ShippedQty
	, p.Casecnt
	, p.Innerpack
	, p.Pallet
	, p.PackUOM1
	, p.PackUOM2
	, p.PackUOM3
	, t.Route
	, o.Status
	, s.Length
	, s.Width
	, s.Height
	, s.STDGrosswgt
	, s.STDCube
	, o.Userdefine01

ORDER BY STORERKEY, FACILITY, LOADKEY, ORDERKEY ASC
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