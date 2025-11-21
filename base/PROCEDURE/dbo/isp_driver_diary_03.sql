SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_driver_diary_03                                     */
/* Creation Date: 04-OCT-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-18053 - SG - FRR - Driver Diary Report                  */
/*        :                                                             */
/* Called By: r_dw_driver_diary_03                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 06-OCT-2021 CSCHONG  1.0   Devops scripts combine                    */
/************************************************************************/
CREATE PROC [dbo].[isp_driver_diary_03]
            @c_MBOLKey        NVARCHAR(10),
            @c_type           NVARCHAR(5) = 'M'  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_Storerkey       NVARCHAR(20)
       
   SET @n_Continue  = 1
   SET @n_StartTCnt = 1

   CREATE TABLE #TMPDRIVERDL03 (
                                 Orderkey              NVARCHAR(20),
                                 Storerkey             NVARCHAR(20),
                                 Company               NVARCHAR(45),
                                 Address1              NVARCHAR(45),     
                                 Address2              NVARCHAR(45), 
                                 Address3              NVARCHAR(45), 
                                 mbolkey               NVARCHAR(20),
                                 DriverName            NVARCHAR(30), 
                                 VehicleNo             NVARCHAR(30),
                                 ExternOrderKey        NVARCHAR(50),
                                 InvoiceNo             NVARCHAR(20),     
                                 RGRNo                 NVARCHAR(50),  
                                 Remarks               NVARCHAR(40), 
                                 SortOrder             NVARCHAR(1),
                                 LineNum               INT,
                                 Route                 NVARCHAR(10),
                                 Pmt                   NVARCHAR(10),
                                 Bag                   NVARCHAR(20),
                                 Carton                NVARCHAR(20),
                                 Pallet                NVARCHAR(20),  
                                 ConsigneeKey          NVARCHAR(15),
                                 Remarks1              NVARCHAR(125),
                                 Remarks2              NVARCHAR(125),
                                 OrderType             NVARCHAR(10),
                                 ORDQty                INT,
                                 StdGrossVolume        FLOAT,
                                 StdGrossWgt           FLOAT,
                                 ShowLine              NVARCHAR(1) 
                                )
  INSERT INTO #TMPDRIVERDL03
  (
      Orderkey,
      Storerkey,
      Company,
      Address1,
      Address2,
      Address3,
      mbolkey,
      DriverName,
      VehicleNo,
      ExternOrderKey,
      InvoiceNo,
      RGRNo,
      Remarks,
      SortOrder,
      LineNum,
      Route,
      Pmt,
      Bag,
      Carton,
      Pallet,
      ConsigneeKey,
      Remarks1,
      Remarks2,
      OrderType,
      ORDQty,
      StdGrossVolume,
      StdGrossWgt,
      ShowLine
  )
   SELECT  Orderkey=ORDERDETAIL.OrderKey,   
        StorerKey=ORDERDETAIL.StorerKey,   
        Company=ORDERS.C_Company,   
        Address1=ORDERS.C_Address1,   
        Address2=ORDERS.C_Address2,   
        Address3=ORDERS.C_Address3,    
        Mbolkey=MBOL.MbolKey,   
        DriverName=MBOL.DRIVERName,   
        VehicleNo=MBOL.Vessel,
        ExternOrderKey=ORDERS.ExternOrderKey,
        InvoiceNo=ORDERS.InvoiceNo,
        RGRNo="", 
        Remarks=CONVERT(NVARCHAR(40), MBOL.Remarks), 
        SortOrder="1",
        LineNum=1,  
        Route=ORDERS.Route,
        Pmt=ORDERS.PmtTerm,
        Bag=MBOLDETAIL.UserDefine01,
        Carton=MBOLDETAIL.UserDefine02,
        Pallet=MBOLDETAIL.UserDefine03,
        ConsigneeKey= ORDERS.ConsigneeKey,
        Remarks1=ISNULL(Convert(NVARCHAR(125), ORDERS.Notes),""),
        Remarks2=ISNULL(Convert(NVARCHAR(125), ORDERS.Notes2),""),
        OrderType=ORDERS.Type,
        ORDQty= SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) 
       ,StdGrossVolume =  Round(Convert(Float, A.StdGrossVolume), 3)
       ,StdGrossWgt = Round(Convert(Float, A.StdGrossWgt), 3)
       ,ShowLine = CASE WHEN ISNULL(CLR.Short,'') <> '' THEN 'Y' ELSE 'N' END
FROM ORDERDETAIL (nolock)   
INNER JOIN ORDERS (nolock) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
INNER JOIN PACK (nolock) ON ( ORDERDETAIL.PackKey = PACK.PackKey )   
INNER JOIN MBOL (nolock) ON ( ORDERDETAIL.MBOLKey = MBOL.MbolKey )
INNER JOIN MBOLDETAIL (nolock) ON ( ORDERDETAIL.ORDERKEY = MBOLDETAIL.ORDERKEY ) 
LEFT OUTER JOIN PACKHEADER (nolock) ON ( ORDERS.OrderKey = PACKHEADER.OrderKey )
LEFT OUTER JOIN dbo.Codelkup CLR WITH (NOLOCK) ON CLR.Storerkey = ORDERDETAIL.StorerKey  AND CLR.Code = 'SHOWLINE'   AND CLR.Listname = 'REPORTCFG' 
                                                         AND CLR.Long = 'r_dw_driver_diary_01' AND ISNULL(CLR.Short,'') <> 'N'
LEFT JOIN (SELECT OD.StorerKey, OD.OrderKey,
         StdGrossVolume = (Case (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'DeriveVolume' and storerkey = OD.StorerKey)
                        When 'OD' Then Sum(OD.Capacity) * (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'ConvertVolume' and storerkey = OD.StorerKey)
                         When '0' Then  Sum(OD.QtyPicked + OD.ShippedQty * ISNULL(S.STDCube, 0)) * (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'ConvertVolume' and storerkey = OD.StorerKey)
                        When '' Then  Sum(OD.QtyPicked + OD.ShippedQty * ISNULL(S.STDCube, 0)) * (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'ConvertVolume' and storerkey = OD.StorerKey)
                     ELSE (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'DeriveVolume' and storerkey = OD.StorerKey) * CONVERT(FLOAT, (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'ConvertVolume' and storerkey = OD.StorerKey))
                  End),
      StdGrossWgt = (Case (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'DeriveWeight' and storerkey = OD.StorerKey)
                        When 'OD' Then Sum(OD.GrossWeight) * (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'ConvertWeight' and storerkey = OD.StorerKey)
                        When '0' Then  Sum(OD.QtyPicked + OD.ShippedQty * ISNULL(S.STDGrossWgt, 0)) * (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'ConvertWeight' and storerkey = OD.StorerKey)
                        When '' Then  Sum(OD.QtyPicked + OD.ShippedQty * ISNULL(S.STDGrossWgt, 0)) * (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'ConvertWeight' and storerkey = OD.StorerKey)
                     ELSE (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'DeriveWeight' and storerkey = OD.StorerKey) * CONVERT(FLOAT, (Select CL.Short From CodeLkup CL WITH (NOLOCK) where CL.code = 'ConvertWeight' and storerkey = OD.StorerKey))
                  End)
      FROM dbo.OrderDetail OD WITH (NOLOCK) Inner Join dbo.SKU S WITH (NOLOCK) ON (OD.StorerKey = S.StorerKey AND OD.SKU = S.SKU)
           Inner Join dbo.Pack P WITH (NOLOCK) ON (OD.PackKey = P.PackKey)
      Group By OD.StorerKey, OD.OrderKey) A on A.storerkey = ORDERS.storerkey and A.orderkey =  ORDERS.Orderkey
      WHERE ( MBOL.MBOLKEY = @c_MBOLKey )
     GROUP BY ORDERDETAIL.OrderKey,   
        ORDERDETAIL.StorerKey,   
        ORDERS.C_Company,   
        ORDERS.C_Address1,   
        ORDERS.C_Address2,   
        ORDERS.C_Address3,     
        MBOL.MbolKey,   
        MBOL.DRIVERName,    
        MBOL.Vessel, 
        ORDERS.ExternOrderKey, 
        ORDERS.InvoiceNo,
        CONVERT(NVARCHAR(40), MBOL.Remarks),  
        PACKHEADER.OrderKey, 
        ORDERS.Route,
        ORDERS.PmtTerm,
        MBOLDETAIL.UserDefine01,
        MBOLDETAIL.UserDefine02,
        MBOLDETAIL.UserDefine03,    
        ORDERS.ConsigneeKey,
        ISNULL(Convert(NVARCHAR(125), ORDERS.Notes),""),
        ISNULL(Convert(NVARCHAR(125), ORDERS.Notes2),""),
        ORDERS.Type   ,Round(Convert(Float, A.StdGrossVolume), 3)
        ,Round(Convert(Float, A.StdGrossWgt), 3) 
        ,CASE WHEN ISNULL(CLR.Short,'') <> '' THEN 'Y' ELSE 'N' END
UNION   
SELECT  Orderkey= ( CASE WHEN RECEIPT.POKEY = "" THEN "ZZZ"
                         ELSE RECEIPT.POKEY
                    END ),   
        StorerKey=RECEIPT.StorerKey,    
        Company="",   
        Address1="", 
        Address2="",   
        Address3="",    
        MbolKey=RECEIPT.MbolKey,    
        DriverName=MBOL.DRIVERName,    
        VehicleNo=MBOL.Vessel, 
        ExternOrderKey="", 
        InvoiceNo="", 
        RGRNo=RECEIPT.ExternReceiptKey, 
        Remarks=CONVERT(NVARCHAR(40), RECEIPT.Notes),  
        SortOrder="2", 
        LineNum=0,
        Route="",
        Pmt="",
        Bag="",
        Carton="",
        Carton="" ,
        ConsigneeKey= "",
        Remarks1="",
        Remarks2="",
        OrderType="",
        ORDQty=0  ,
        StdGrossVolume = '',
        StdGrossWgt = '',
        ShowLine = CASE WHEN ISNULL(CLR.Short,'') <> '' THEN 'Y' ELSE 'N' END   
FROM RECEIPT (nolock)
INNER JOIN MBOL (nolock) ON ( RECEIPT.MBOLKey = MBOL.MbolKey )
LEFT OUTER JOIN Codelkup CLR WITH (NOLOCK) ON CLR.Storerkey = RECEIPT.StorerKey  AND CLR.Code = 'SHOWLINE'   AND CLR.Listname = 'REPORTCFG' 
                                                         AND CLR.Long = 'r_dw_driver_diary_01' AND ISNULL(CLR.Short,'') <> 'N'  
 WHERE ( MBOL.MBOLKEY = @c_MBOLKey )  
 
  IF @c_type = 'M'
  BEGIN
     SELECT @c_MBOLKey AS MBOLKEY
   
  END
  ELSE IF @c_type = 'H'
  BEGIN
      SELECT * FROM #TMPDRIVERDL03
      ORDER BY Route,Company
   END
   ELSE IF @c_type = 'S1'
   BEGIN

      SELECT Type = Orders.Type, 
             CodeDescription= Codelkup.Description, 
             Qty = SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty),
             CountOrd = (SELECT COUNT(Ord.Orderkey) FROM ORDERS Ord(NOLOCK) 
                         WHERE Ord.MBOLKey = @c_MBOLKey and Ord.Type = Orders.Type)
            ,StdGrossVolume = Round((Convert(Float, IsNull(A.StdGrossVolume, 0))), 3) 
            ,StdGrossWgt = Round((Convert(Float, IsNull(A.StdGrossWgt, 0))), 3)    
      FROM ORDERS (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      LEFT OUTER JOIN CODELKUP (NOLOCK) ON (CODELKUP.Code = ORDERS.Type and CODELKUP.Listname = 'ORDERTYPE')
      LEFT JOIN (SELECT  O.MBOLKey,
                  StdGrossVolume = (Case (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'DeriveVolume' and storerkey = O.StorerKey)
                              When 'OD' Then Sum(OD.Capacity) * (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'ConvertVolume' and storerkey = O.StorerKey)
                               When '0' Then  Sum(OD.QtyPicked + OD.ShippedQty * ISNULL(S.STDCube, 0)) * (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'ConvertVolume' and storerkey = O.StorerKey)
                              When '' Then  Sum(OD.QtyPicked + OD.ShippedQty * ISNULL(S.STDCube, 0)) * (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'ConvertVolume' and storerkey = O.StorerKey)
                           ELSE (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'DeriveVolume' and storerkey = O.StorerKey) * CONVERT(FLOAT, (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'ConvertVolume' and storerkey = O.StorerKey))
                           End),
                 StdGrossWgt = (Case (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'DeriveWeight' and storerkey = O.StorerKey)
                              When 'OD' Then Sum(OD.Capacity) * (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'ConvertWeight' and storerkey = O.StorerKey)
                               When '0' Then  Sum(OD.QtyPicked + OD.ShippedQty * ISNULL(S.STDCube, 0)) * (Select CL.Short From CodeLkup CL   WITH (NOLOCK) where CL.code = 'ConvertWeight' and storerkey = O.StorerKey)
                              When '' Then  Sum(OD.QtyPicked + OD.ShippedQty * ISNULL(S.STDCube, 0)) * (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'ConvertWeight' and storerkey = O.StorerKey)
                           ELSE (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'DeriveWeight' and storerkey = O.StorerKey) * CONVERT(FLOAT, (Select CL.Short From CodeLkup CL  WITH (NOLOCK) where CL.code = 'ConvertWeight' and storerkey = O.StorerKey))
                           End)
            FROM dbo.Orders O WITH (NOLOCK) Inner Join dbo.OrderDetail OD WITH (NOLOCK) ON OD.StorerKey = O.StorerKey and OD.OrderKey = O.OrderKey
                  Inner Join dbo.SKU S WITH (NOLOCK) ON (OD.StorerKey = S.StorerKey AND OD.SKU = S.SKU)
                 Inner Join dbo.Pack P WITH (NOLOCK) ON (OD.PackKey = P.PackKey)
            WHERE O.MBOLKey  = @c_MBOLKey 
            Group By O.StorerKey, O.MBOLKey) A ON A.mbolkey=ORDERS.MBOLKey 
      WHERE ORDERS.MBOLKey = @c_MBOLKey  
      GROUP BY Orders.Type, Codelkup.Description  ,Round((Convert(Float, IsNull(A.StdGrossVolume, 0))), 3) ,Round((Convert(Float, IsNull(A.StdGrossWgt, 0))), 3)   
  END
  ELSE IF @c_type = 'S2'
  BEGIN
      SELECT s.ALTSKU AS Altsku,od.Sku AS sku,LOTT.Lottable01 AS lottable01,SUM(pd.Qty)/CAST(nullif(p.casecnt,0) AS INT) AS qtycarton,
           CASE WHEN  (SUM(pd.Qty)%CAST(nullif(p.casecnt,0) AS INT)) <> 0 THEN  (SUM(pd.Qty)%CAST(nullif(p.casecnt,0) AS INT)/CAST(nullif(p.InnerPack,0) AS INT) )  ELSE 0 END AS qtyinner
      FROM MBOL MB WITH (NOLOCK)
      JOIN MBOLDETAIL MBD WITH (NOLOCK) ON MBD.mbolkey = MB.MbolKey
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON Od.OrderKey=MBD.orderkey
      JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.Storerkey=OD.StorerKey AND PD.Sku = OD.Sku AND PD.OrderLineNumber = OD.OrderLineNumber
      JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.Storerkey AND S.sku=PD.Sku
      JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PD.Lot AND LOTT.Sku=PD.Sku AND LOTT.StorerKey = PD.Storerkey
      JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey
      WHERE MB.MbolKey = @c_MBOLKey
      GROUP BY s.ALTSKU,od.Sku,LOTT.Lottable01,p.casecnt,p.InnerPack
      ORDER BY s.ALTSKU

  END

QUIT:


END -- procedure

GO