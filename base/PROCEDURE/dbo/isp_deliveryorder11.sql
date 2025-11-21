SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_DeliveryOrder11                                 */
/* Creation Date: 14-AUG-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: ChongCS                                                  */
/*                                                                      */
/* Purpose:  WMS-14644 - [MY]- Delivery Order for New Customer-NEW      */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_delivery_Order_11                  */
/*                                                                      */
/* Called By: RCM from MBOL, ReportType = 'DELORDER'                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 18-NOV-2020  CSCHONG 1.1   WMS-14644 fix ttlctn issue (CS01)         */
/************************************************************************/
CREATE PROC [dbo].[isp_DeliveryOrder11]
      (@c_MBOLKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1, @n_MaxLine INT = 20
          ,@c_userid   nvarchar(125)

  SET @c_userid =suser_name()



   CREATE TABLE #Temp_DOrder11(
      DCompany        NVARCHAR(45),  
      DAddress1       NVARCHAR(45),
      DAddress2       NVARCHAR(45),
      DAddress3       NVARCHAR(45), 
      DZip            NVARCHAR(45),
      OHNotes         NVARCHAR(250),  
      DCity           NVARCHAR(45),
      DeliveryDate    DATETIME ,
      Orderkey        NVARCHAR(20),
      DState          NVARCHAR(45),  
      DCountry        NVARCHAR(45),
      SDESCR          NVARCHAR(250),
      Qty             INT,
      SKU             NVARCHAR(20),
      DeliveryNote    NVARCHAR(20),
      FAddress1       NVARCHAR(45),
      FAddress2       NVARCHAR(45),
      FAddress3       NVARCHAR(45), 
      FZip            NVARCHAR(45),
      FCity           NVARCHAR(45),
      RetailSKU       NVARCHAR(20),
      FState          NVARCHAR(45),
      FCompany        NVARCHAR(45),   
      FCountry        NVARCHAR(45), 
      ExtPOKey        NVARCHAR(20),
      ExtOrdKey       NVARCHAR(50),
      LOTT01          NVARCHAR(20),
      AltSKU          NVARCHAR(20), 
      SPrice          FLOAT,
      SSUSR2          NVARCHAR(20),   
      ExtLineNo       NVARCHAR(20),
      TTLCTN          INT,
      UOM             NVARCHAR(10),     
      mbolkey         NVARCHAR(20), 
      PrepareBy       NVARCHAR(125),
      AreaCode        NVARCHAR(20)         
      )

   IF(@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      INSERT INTO #Temp_DOrder11 (DCompany,DAddress1,DAddress2,DAddress3,DZip,OHNotes,DCity,DeliveryDate,Orderkey,DState,DCountry,
                                  SDESCR,Qty,SKU,DeliveryNote,FAddress1,FAddress2,FAddress3,FZip,FCity,RetailSKU,FState,FCompany,   
                                  FCountry,ExtPOKey,ExtOrdKey,LOTT01,AltSKU,SPrice,SSUSR2,ExtLineNo,TTLCTN,UOM,mbolkey,PrepareBy,AreaCode)
      SELECT  DISTINCT ISNULL(DELA.company,''),ISNULL(DELA.Address1,''),ISNULL(DELA.Address2,''),ISNULL(DELA.Address3,''),
       ISNULL(DELA.zip,''),OH.Notes,ISNULL(DELA.city,''),OH.Deliverydate,OH.Orderkey,ISNULL(DELA.State,''),ISNULL(DELA.country,''),
       S.descr, (OD.QtyPicked + OD.ShippedQty),OD.SKU,OH.DeliveryNote,ISNULL(FRA.Address1,''),ISNULL(FRA.Address2,''),ISNULL(FRA.Address3,''),
       ISNULL(FRA.zip,''),ISNULL(FRA.city,''),S.RetailSKU,ISNULL(FRA.state,''),ISNULL(FRA.company,''),
       ISNULL(FRA.country,''),OH.ExternPOKey,OH.ExternOrderkey,OD.Lottable01, S.Altsku,S.Price,S.susr2,OD.ExternLineno,
       --CASE WHEN OH.Ordergroup = 'PO' THEN (OH.ContainerQty) ELSE ISNULL(PH.TTLCNTS,0) END as TTLCTN,
       --ISNULL(PH.TTLCNTS,OH.ContainerQty) ,  --CS01
       CASE WHEN ISNULL(PH.TTLCNTS,'0') <> 0 THEN PH.TTLCNTS ELSE  OH.ContainerQty END , --CS01
       OD.UOM,MB.Mbolkey,@c_userid,ISNULL(SOD.Route,'')
      FROM MBOL MB (NOLOCK)
      JOIN MBOLDETAIL MD (NOLOCK) ON MB.MBOLKEY = MD.MBOLKEY
      JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = MD.ORDERKEY
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
      LEFT JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
      LEFT JOIN STORER FRA WITH (NOLOCK) ON FRA.Storerkey = OD.Lottable01 AND FRA.Type='2'
      LEFT JOIN STORER DELA WITH (NOLOCK) ON DELA.Storerkey = OH.consigneekey AND DELA.Type='2'
      LEFT OUTER JOIN STORERSODEFAULT SOD WITH (NOLOCK) ON SOD.Storerkey = DELA.Storerkey
      JOIN SKU S WITH (NOLOCK) ON S.Storerkey = OD.Storerkey AND S.SKU = OD.SKU
      WHERE MB.MBOLKEY = @c_MBOLKey
      ORDER BY  MB.Mbolkey,OH.Orderkey,OD.ExternLineno,OD.SKU
      END

      SELECT *
      FROM #Temp_DOrder11
      ORDER BY Mbolkey,Orderkey,ExtLineNo,sku


      IF OBJECT_ID('tempdb..#Temp_DOrder11') IS NOT NULL
         DROP TABLE #Temp_DOrder11

END


GO