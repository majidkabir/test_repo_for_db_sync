SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_12_rpt                                          */
/* Creation Date: 24-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-4829 - CN_Speedo_POD report_New                         */
/*        :                                                             */
/* Called By: r_dw_pod_12_rpt - view report                             */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_POD_12_rpt]
           @c_storerkey       NVARCHAR(20),
           @c_orderkey        NVARCHAR(20),
           @c_flag            NVARCHAR(20)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @n_ttlCtn          INT

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


   CREATE TABLE #TMP_POD12RPT
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,	DeliveryDate   NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExtOrdKey      NVARCHAR(30)   NULL  DEFAULT('')
      ,  EditDate       DATETIME       NULL
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')
      ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('')
      ,  ST_Phone1      NVARCHAR(30)   NULL  DEFAULT('')
      ,  ST_Company     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address1     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address2     NVARCHAR(45)   NULL  DEFAULT('')
      ,  ST_Address1    NVARCHAR(45)   NULL  DEFAULT('')
      ,  ST_Address2    NVARCHAR(45)   NULL  DEFAULT('')
      ,  ST_Fax1        NVARCHAR(30)   NULL  DEFAULT('')
      ,  OHNotes        NVARCHAR(120)  NULL  DEFAULT('')
      ,  C_Contact1     NVARCHAR(30)   NULL  DEFAULT('')
      --,  C_City         NVARCHAR(18)   NULL  DEFAULT('')
      ,  Qty           INT            NULL  DEFAULT(0)
      --,  CaseQty        INT            NULL  DEFAULT(0)
      --,  STDCube        FLOAT          NULL  DEFAULT(0)
      --,  CUDF03         NVARCHAR(50)   NULL  DEFAULT('')
      --,  CUDF04         NVARCHAR(50)   NULL  DEFAULT('')
      --,  CLNotes        NVARCHAR(120)  NULL  DEFAULT('')
      --,  CUDF05         NVARCHAR(50)   NULL  DEFAULT('')
      --,  CLNotes2       NVARCHAR(120)  NULL  DEFAULT('') 
      --,  MBWGT          FLOAT          NULL  DEFAULT(0)
      --,  C_Address3     NVARCHAR(45)   NULL  DEFAULT('')
      ,  Storerkey      NVARCHAR(20)   NULL  DEFAULT('')
      --,  ShowLogo       NVARCHAR(5)    NULL  DEFAULT('N')     
      --,  C_State        NVARCHAR(18)   NULL  DEFAULT('')      
      ,  C_phone1       NVARCHAR(20)   NULL  DEFAULT('')  
      ,  ODLineNum      NVARCHAR(10)   NULL DEFAULT ('')
      ,  SKU            NVARCHAR(20)   NULL  DEFAULT ('')
      ,  SDESCR         NVARCHAR(120)  NULL  DEFAULT ('') 
      ,  Ctn            INT   
      )
INSERT INTO #TMP_POD12RPT
(
	-- RowID -- this column value is auto-generated
	DeliveryDate,
	ExtOrdKey,
	EditDate,
	C_Company,
	Orderkey,
	ST_Phone1,
	ST_Company,
	C_Address1,
	C_Address2,
	ST_Address1,
	ST_Address2,
	ST_Fax1,
	OHNotes,
	C_Contact1,
	Qty,
	Storerkey,
	C_phone1,ODLineNum, SKU, SDESCR,Ctn
)

 
   SELECT deliverydate = Convert(NVARCHAR(10),DateAdd(day,cast(C.Short as int),O.Editdate),121)
         ,O.ExternOrderKey
         ,O.EditDate
         ,O.C_Company    
         ,O.Orderkey 
         ,s.Phone1
         ,ST_Company   = ISNULL(RTRIM(S.Company),'')
         ,C_Address1   = ISNULL(RTRIM(O.C_Address1),'')
         ,C_Address2   = ISNULL(RTRIM(O.C_Address2),'')
         ,ST_Address1   = ISNULL(RTRIM(s.Address1),'')
         ,ST_Address2   = ISNULL(RTRIM(s.Address2),'')
         ,ST_Fax1       = ISNULL(RTRIM(s.Fax1),'')
         ,OHNotes       = ISNULL(RTRIM(O.notes),'')
         ,C_Contact1   = ISNULL(RTRIM(O.C_Contact1),'')
      --   ,C_city       = ISNULL(MAX(RTRIM(OH.C_City)),'')
         ,Qty        = CASE WHEN @c_flag='1' THEN OD.OpenQty ELSE OD.ShippedQty END
         --,caseqty     = SUM(MD.CtnCnt1+ MD.CtnCnt2 + MD.CtnCnt3 + MD.CtnCnt4 + MD.CtnCnt5)
         --,STDCube     = SUM(MD.[CUBE])
         --,CUDF03       = ISNULL(MAX(RTRIM(C.UDF03)),'')
         --,CUDF04       = ISNULL(MAX(RTRIM(C.UDF04)),'')
         --,C.Notes
         --,CUDF05       = ISNULL(MAX(RTRIM(C.UDF05)),'')
         --,C.Notes2
         --,MBWGT         =   SUM(MD.[weight])
         --,C_Address3   = ISNULL(MAX(RTRIM(OH.C_Address3)),'')
         ,O.storerkey 
         --,showlogo = CASE WHEN OH.storerkey = 'speedo' THEN 'Y' ELSE 'N' END
        -- ,c_State      = ISNULL(MAX(RTRIM(OH.C_State)),'')
         ,c_Phone1      = ISNULL(RTRIM(O.C_Phone1),'')
         ,od.OrderLineNumber
         ,od.sku
         ,sku.descr,0
   FROM dbo.ORDERS o WITH (NOLOCK)
   JOIN dbo.ORDERDETAIL od WITH (NOLOCK) ON od.OrderKey = o.OrderKey
   JOIN dbo.STORER s WITH (NOLOCK) ON s.StorerKey = o.StorerKey
   LEFT JOIN dbo.CODELKUP c WITH (NOLOCK) ON O.C_City=C.Short and C.LISTNAME='CityLdTime' AND c.Notes='LCCN'
   JOIN dbo.SKU  WITH (NOLOCK) ON sku.Sku=od.Sku      
   WHERE o.OrderKey=@c_orderkey
   AND o.StorerKey=@c_storerkey
  -- AND o.[Status]='9'
   --GROUP BY Convert(NVARCHAR(10),DateAdd(day,cast(C.Short as int),O.Editdate),121)
   ORDER BY O.Orderkey


	SET @n_ttlCtn = 0
	
	   SELECT @n_ttlCtn = COUNT(DISTINCT(pd.CartonNo))
		FROM PackDetail pd JOIN PackHeader ph ON pd.PickSlipNo=ph.PickSlipNo
		JOIN ORDERS o ON o.OrderKey=ph.OrderKey
		WHERE o.OrderKey=@c_orderkey
      AND o.StorerKey=@c_storerkey

		UPDATE #TMP_POD12RPT
		SET Ctn = @n_ttlCtn
		WHERE Orderkey = @c_orderkey
      AND storerkey = @c_storerkey
      
  SELECT
  	tp.DeliveryDate,
  	tp.ExtOrdKey,
  	tp.EditDate,
  	tp.C_Company,
  	tp.Orderkey,
  	tp.ST_Phone1,
  	tp.ST_Company,
  	tp.C_Address1,
  	tp.C_Address2,
  	tp.ST_Address1,
  	tp.ST_Address2,
  	tp.ST_Fax1,
  	tp.OHNotes,
  	tp.C_Contact1,
  	tp.Qty,
  	tp.Storerkey,
  	tp.C_phone1,tp.ODLineNum, tp.SKU, tp.SDESCR,tp.Ctn
  FROM #TMP_POD12RPT AS tp
  ORDER BY tp.Orderkey

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO