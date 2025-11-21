SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_22                                              */
/* Creation Date: 05-OCT-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-5031 - New B.C.SPORTS Delivery Note Label FOR MBOL      */
/*        :                                                             */
/* Called By: r_dw_pod_22 (reporttype = 'MBOLPOD')                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_POD_22]
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


   CREATE TABLE #TMP_PODRPT22
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,	 MBOLKey        NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExtOrdKey      NVARCHAR(30)   NULL  DEFAULT('')  
      ,  loadkey        NVARCHAR(10)    NULL  DEFAULT('')
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')
      ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('')
      ,  ST_Company     NVARCHAR(45)   NULL  DEFAULT('') 
      ,  Consigneekey   NVARCHAR(45)   NULL  DEFAULT('') 
      ,  FDESCR         NVARCHAR(120)  NULL  DEFAULT('')
      ,  C_Contact1     NVARCHAR(30)   NULL  DEFAULT('') 
      ,  Qty            INT            NULL  DEFAULT(0) 
      ,  Ctncnt         INT            NULL  DEFAULT(0) 
      ,  Storerkey      NVARCHAR(20)   NULL  DEFAULT('')    
      ,  C_phone1       NVARCHAR(20)   NULL  DEFAULT('')   
      )

           
  INSERT INTO #TMP_PODRPT22
  (
  	-- RowID -- this column value is auto-generated
  	MBOLKey,
  	ExtOrdKey,
  	loadkey,
  	C_Company,
  	Orderkey,
  	ST_Company,
  	Consigneekey,
  	Fdescr,
  	C_Contact1,
  	Qty,
  	Ctncnt,
    Storerkey, 
  	C_phone1
  )

 
   SELECT MH.MBOLKey
         ,OH.ExternOrderKey
         ,OH.loadkey
         ,OH.C_Company    
         ,OH.Orderkey 
         ,ST_Company   = ISNULL(MAX(RTRIM(ST.Company)),'')
         ,OH.Consigneekey
         ,ISNULL(F.Descr,'')
		 ,c_contact1  = ISNULL(MAX(RTRIM(OH.c_contact1)),'')
         ,Qty         = SUM(OD.ShippedQty + OD.QtyPicked)
         ,Ctncnt      = MIN(MD.CtnCnt1+ MD.CtnCnt2 + MD.CtnCnt3 + MD.CtnCnt4 + MD.CtnCnt5)
         ,OH.storerkey 
         ,c_Phone1      = ISNULL(MAX(RTRIM(OH.C_Phone1)),'')
   FROM MBOL         MH  WITH (NOLOCK)
   JOIN MBOLDETAIL   MD  WITH (NOLOCK) ON (MH.MBOLKey  = MD.MBOLKey)
   JOIN ORDERS       OH  WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
   JOIN FACILITY     F   WITH (NOLOCK) ON (F.facility = OH.Facility)
   JOIN STORER       ST  WITH (NOLOCK) ON ST.storerkey = OH.StorerKey                                
   WHERE MH.MBOLKey = @c_MBOLKey
   GROUP BY MH.MBOLKey
         ,OH.ExternOrderKey
         ,OH.loadkey
         ,OH.C_Company    
         ,OH.Orderkey 
         ,OH.Consigneekey
         ,ISNULL(F.Descr,'')
         ,OH.storerkey 
   ORDER BY MH.MBOLKey
           ,OH.Orderkey


  
   SELECT   MBOLKey,
  			ExtOrdKey,
  			loadkey,
  			C_Company,
  			Orderkey,
  			ST_Company,
  			Consigneekey,
  			Fdescr,
  			C_Contact1,
  			Qty,
  			Ctncnt,
			Storerkey, 
  			C_phone1
   FROM #TMP_PODRPT22

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO