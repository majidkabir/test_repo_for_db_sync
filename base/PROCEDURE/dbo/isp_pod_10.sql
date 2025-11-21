SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_10                                              */
/* Creation Date: 04-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-4829 - CN_Speedo_POD report_New                         */
/*        :                                                             */
/* Called By: r_dw_pod_10 (reporttype = 'MBOLPOD')                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_POD_10]
           @c_MBOLKey   NVARCHAR(10),
           @c_exparrivaldate  NVARCHAR(30) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


   CREATE TABLE #TMP_PODRPT10
      (  RowID       INT IDENTITY (1,1) NOT NULL 
      ,	MBOLKey        NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExtOrdKey      NVARCHAR(30)   NULL  DEFAULT('')
      ,  EditDate       DATETIME       NULL
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')
      ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('')
      ,  buyerPO        NVARCHAR(30)   NULL  DEFAULT('')
      ,  ST_Company     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address1     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address2     NVARCHAR(45)   NULL  DEFAULT('')
      ,  Consigneekey   NVARCHAR(45)   NULL  DEFAULT('')
      ,  Facility       NVARCHAR(10)   NULL  DEFAULT('')
      ,  CUDF01         NVARCHAR(50)   NULL  DEFAULT('')
      ,  CUDF02         NVARCHAR(50)   NULL  DEFAULT('')
      ,  C_Contact1     NVARCHAR(30)   NULL  DEFAULT('')
      ,  C_City         NVARCHAR(18)   NULL  DEFAULT('')
      ,  PQty           INT            NULL  DEFAULT(0)
      ,  CaseQty        INT            NULL  DEFAULT(0)
      ,  STDCube        FLOAT          NULL  DEFAULT(0)
      ,  CUDF03         NVARCHAR(50)   NULL  DEFAULT('')
      ,  CUDF04         NVARCHAR(50)   NULL  DEFAULT('')
      ,  CLNotes        NVARCHAR(120)  NULL  DEFAULT('')
      ,  CUDF05         NVARCHAR(50)   NULL  DEFAULT('')
      ,  CLNotes2       NVARCHAR(120)  NULL  DEFAULT('') 
      ,  MBWGT          FLOAT          NULL  DEFAULT(0)
      ,  C_Address3     NVARCHAR(45)   NULL  DEFAULT('')
      ,  Storerkey      NVARCHAR(20)   NULL  DEFAULT('')
      ,  ShowLogo       NVARCHAR(5)    NULL  DEFAULT('N')     
      ,  C_State        NVARCHAR(18)   NULL  DEFAULT('')      
      ,  C_phone1       NVARCHAR(20)   NULL  DEFAULT('')      
      )

           
  INSERT INTO #TMP_PODRPT10
  (
  	-- RowID -- this column value is auto-generated
  	MBOLKey,
  	ExtOrdKey,
  	EditDate,
  	C_Company,
  	Orderkey,
  	buyerPO,
  	ST_Company,
  	C_Address1,
  	C_Address2,
  	Consigneekey,
  	Facility,
  	CUDF01,
  	CUDF02,
  	C_Contact1,
  	C_City,
  	PQty,
  	CaseQty,
  	STDCube,
  	CUDF03,
  	CUDF04,
  	CLNotes,
  	CUDF05,
  	CLNotes2,
  	MBWGT,C_Address3, Storerkey, ShowLogo
  	,C_State,C_phone1
  )

 
   SELECT MH.MBOLKey
         ,OH.ExternOrderKey
         ,OH.EditDate
         ,OH.C_Company    
         ,OH.Orderkey 
         ,OH.BuyerPO
         ,ST_Company   = ISNULL(MAX(RTRIM(ST.Company)),'')
         ,C_Address1   = ISNULL(MAX(RTRIM(OH.C_Address1)),'')
         ,C_Address2   = ISNULL(MAX(RTRIM(OH.C_Address2)),'')
         ,OH.Consigneekey
         ,OH.Facility
         ,CUDF01       = ISNULL(MAX(RTRIM(C.UDF01)),'')
         ,CUDF02       = ISNULL(MAX(RTRIM(C.UDF02)),'')
         ,C_Contact1   = ISNULL(MAX(RTRIM(OH.C_Contact1)),'')
         ,C_city       = ISNULL(MAX(RTRIM(OH.C_City)),'')
         ,PQty        = SUM(OD.ShippedQty + OD.QtyPicked)
         ,caseqty     = (MD.CtnCnt1+ MD.CtnCnt2 + MD.CtnCnt3 + MD.CtnCnt4 + MD.CtnCnt5)
         ,STDCube     = (MD.[CUBE])
         ,CUDF03       = ISNULL(MAX(RTRIM(C.UDF03)),'')
         ,CUDF04       = ISNULL(MAX(RTRIM(C.UDF04)),'')
         ,C.Notes
         ,CUDF05       = ISNULL(MAX(RTRIM(C.UDF05)),'')
         ,C.Notes2
         ,MBWGT         = (MD.[weight])
         ,C_Address3   = ISNULL(MAX(RTRIM(OH.C_Address3)),'')
         ,OH.storerkey 
         ,showlogo = CASE WHEN OH.storerkey = 'speedo' THEN 'Y' ELSE 'N' END
         ,c_State      = ISNULL(MAX(RTRIM(OH.C_State)),'')
         ,c_Phone1      = ISNULL(MAX(RTRIM(OH.C_Phone1)),'')
   FROM MBOL         MH  WITH (NOLOCK)
   JOIN MBOLDETAIL   MD  WITH (NOLOCK) ON (MH.MBOLKey  = MD.MBOLKey)
   JOIN ORDERS       OH  WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
   JOIN FACILITY     F   WITH (NOLOCK) ON (F.facility = OH.Facility)
   JOIN STORER       ST  WITH (NOLOCK) ON ST.storerkey = OH.StorerKey
   LEFT JOIN CODELKUP C  WITH (NOLOCK) ON C.ListName = 'PODN' and C.Storerkey = OH.Storerkey and C.Code = '1'
   JOIN SKU          SKU WITH (NOLOCK) ON (SKU.Storerkey = OD.Storerkey)
                                     AND(SKU.Sku = OD.Sku)                                 
   WHERE MH.MBOLKey = @c_MBOLKey
   GROUP BY  MH.MBOLKey
         ,OH.ExternOrderKey
         ,OH.EditDate
         ,OH.C_Company 
         ,OH.Orderkey 
         ,OH.BuyerPO
         ,OH.Consigneekey
         ,OH.Facility
         ,C.Notes
         ,C.Notes2
         ,OH.Notes
         ,OH.storerkey
		,CASE WHEN OH.storerkey = 'speedo' THEN 'Y' ELSE 'N' END
		,(MD.CtnCnt1+ MD.CtnCnt2 + MD.CtnCnt3 + MD.CtnCnt4 + MD.CtnCnt5)
		,(MD.[CUBE])
		,(MD.[weight])
   ORDER BY MH.MBOLKey
           ,OH.Orderkey


  
   SELECT  	  	    MBOLKey,
					ExtOrdKey,
					EditDate,
					C_Company,
					Orderkey,
					buyerPO,
					ST_Company,
					C_Address1,
					C_Address2,
					Consigneekey,
					Facility,
					CUDF01,
					CUDF02,
					C_Contact1,
					C_City,
					PQty,
					CaseQty,
					STDCube,
					CUDF03,
					CUDF04,
					CLNotes,
					CUDF05,
					CLNotes2,
					MBWGT,C_Address3, Storerkey, ShowLogo
					,C_State,C_phone1
   FROM #TMP_PODRPT10

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO