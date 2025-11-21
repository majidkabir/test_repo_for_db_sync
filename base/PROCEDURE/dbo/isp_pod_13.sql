SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_13                                              */
/* Creation Date: 30-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-4958 - CN_AEO_Report_POD                                */
/*        :                                                             */
/* Called By: r_dw_pod_13 (reporttype = 'MBOLPOD')                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_POD_13]
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
         , @n_NoOfLine         INT 

   SET @n_StartTCnt = @@TRANCOUNT
   
   SET @n_NoOfLine = 12

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


   CREATE TABLE #TMP_POD13
      (  RowID       INT IDENTITY (1,1) NOT NULL 
      ,	MBOLKey        NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExtOrdKey      NVARCHAR(30)   NULL  DEFAULT('')
      ,  ShipDate       DATETIME       NULL
      ,  consigneekey   NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address1     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address2     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Phone2       NVARCHAR(30)   NULL  DEFAULT('')
      ,  CargoName      NVARCHAR(30)   NULL  DEFAULT('')
      ,  C_Contact1     NVARCHAR(30)   NULL  DEFAULT('')
      ,  C_Phone1       NVARCHAR(18)   NULL  DEFAULT('')
      ,  Qty            INT            NULL  DEFAULT(0)
      ,  TTLCtn         INT            NULL  DEFAULT(0)
      ,  C_City         NVARCHAR(45)   NULL  DEFAULT('')
      ,  CUDF01         NVARCHAR(50)   NULL  DEFAULT('')
      ,  CUDF02         NVARCHAR(50)   NULL  DEFAULT('')
      ,  STNotes        NVARCHAR(120)  NULL  DEFAULT('')
      ,  CUDF03         NVARCHAR(30)   NULL  DEFAULT('')
      ,  RecGrp         INT
      )

           
  INSERT INTO #TMP_POD13
  (
  	-- RowID -- this column value is auto-generated
  	MBOLKey,
  	ExtOrdKey,
  	ShipDate,
  	consigneekey,
  	C_Company,
  	C_Address1,
  	C_Address2,
  	C_Phone2,
  	CargoName,
  	C_Contact1,
  	C_Phone1,
  	Qty,
  	TTLCtn,
  	C_City,
  	CUDF01,
  	CUDF02,
  	STNotes,
  	CUDF03,
  	RecGrp
  )

 
   SELECT MH.MBOLKey
         ,OH.ExternOrderKey
         ,MH.ShipDate 
         ,OH.ConsigneeKey 
         ,C_Company    = ISNULL(MAX(RTRIM(OH.C_Company)),'')
         ,C_Address1   = ISNULL(MAX(RTRIM(OH.C_Address1)),'')
         ,C_Address2   = ISNULL(MAX(RTRIM(OH.C_Address2)),'')
         ,C_Phone2     = ISNULL(MAX(RTRIM(OH.C_Phone2)),'')
         ,Cargoname    = 'AEO'
         ,C_Contact1   = ISNULL(MAX(RTRIM(OH.C_Contact1)),'')
         ,C_Phone1    = ISNULL(MAX(RTRIM(OH.C_Phone1)),'')
         ,PQty        = SUM(OD.ShippedQty + OD.QtyPicked+OD.QtyAllocated)
         ,ttlctn     = MD.TotalCartons
         ,C_City  = ISNULL(MAX(RTRIM(OH.C_city)),'')
         ,CUDF01 = ISNULL(MAX(RTRIM(C.UDF01)),'')
         ,CUDF02 = ISNULL(MAX(RTRIM(C.UDF02)),'')
         ,ISNULL(ST.Notes2,'')
         ,CUDF03 = ISNULL(MAX(RTRIM(C.UDF03)),'')
         ,(Row_Number() OVER (PARTITION BY  MH.MBOLKey ORDER BY OH.ExternOrderKey Asc)-1)/@n_NoOfLine+1 AS recgrp
   FROM MBOL         MH  WITH (NOLOCK)
   JOIN MBOLDETAIL   MD  WITH (NOLOCK) ON (MH.MBOLKey  = MD.MBOLKey)
   JOIN ORDERS       OH  WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
   JOIN FACILITY     F   WITH (NOLOCK) ON (F.facility = OH.Facility)
   JOIN STORER       ST  WITH (NOLOCK) ON ST.storerkey = OH.StorerKey
   JOIN SKU          SKU WITH (NOLOCK) ON (SKU.Storerkey = OD.Storerkey)
                                     AND(SKU.Sku = OD.Sku)   
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME='AEOPOD' AND c.Code=OH.Facility                                                           
   WHERE MH.MBOLKey = @c_MBOLKey
   GROUP BY  MH.MBOLKey
         ,OH.ExternOrderKey
         ,MH.ShipDate 
         ,OH.ConsigneeKey
         ,MD.TotalCartons
         ,ST.Notes2
   ORDER BY MH.MBOLKey
           ,OH.ExternOrderKey


  
 SELECT
 	tp.consigneekey,
 	tp.CargoName,
 	tp.MBOLKey,	
 	tp.ExtOrdKey,
  	tp.ShipDate,
 	tp.C_Contact1,
 	tp.C_Address1,
 	tp.C_Company,
 	tp.C_Phone1,
 	tp.C_Phone2,
 	tp.C_Address2,
 	tp.C_City,
 	tp.CUDF01,
 	tp.CUDF02,
 	tp.CUDF03,
 	tp.STNotes,
 	tp.Qty,
 	tp.TTLCtn,
 	tp.RecGrp
 FROM
 	#TMP_POD13 AS tp

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO