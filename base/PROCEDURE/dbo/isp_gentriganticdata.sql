SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GenTriganticData                               */
/* Creation Date: 03-Mar-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: IDS                                                      */
/*                                                                      */
/* Purpose: Generate Trigantic data into interface table                */
/*                                                                      */
/* Input Parameters: @c_Type                                            */
/*                   @c_CountryCode                                     */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 08-Mar-2013  Leong     1.0   Move <UNICODE> to View                  */
/* 19-Apr-2013  CSChong   1.0   Unicode conversion.                     */
/* 26-Apr-2013  Leong     1.0   Revise TriganticKey retrieval.          */
/* 24-Jun-2014  Leong     1.1   Bug Fix. (Leong01)                      */
/************************************************************************/

CREATE PROC [dbo].[isp_GenTriganticData]
   @c_Type NVARCHAR(30)
 , @c_CountryCode NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_TriganticLogkey NVARCHAR(10)
         , @b_Success         INT
         , @n_Err             INT
         , @c_ErrMsg          NVARCHAR(250)

   IF @c_Type = 'INV'
   BEGIN
      EXEC ispReCalculateQtyOnHold

      TRUNCATE TABLE DTSITF.dbo.TIPSINV
      BEGIN TRAN
      INSERT INTO DTSITF.dbo.TIPSINV
         ( CountryCode, Facility, StorerKey, Company, Sku, AltSku
         , Sku_Descr, Sku_Scnd_Lang_Descr, Class, GroupCode, ABC
         , ItemClass, Classification, ProductGroup, Qty, QtyAvailable
         , Lottable02, Lottable04, Lottable05, Master_Unit, Master_Unit_Desc
         , MU_Units, Inner_Pack, Inner_Pack_Desc, Inner_UOM_Units
         , Carton, Carton_Desc, Carton_UOM_Units
         , Pallet, Pallet_Desc, Pallet_UOM_Units
         , Units_Per_Layer, Layers_Per_PL, ManufacturerSku
         , RetailSku, AgencyCode, L2Label, L3Label, Lottable03, L4Label, L5Label
         , QtyAllocated, QtyPicked, QtyOnHold
         , Susr4, Busr10, Class_Desc, ItemClass_Desc, SkuGroup_Desc
         , ProdGroup_Desc, Facility_Desc, Expiry_Date
         , Style, Color, Size, Measurement
         )
      SELECT
      CAST(ISNULL(RTRIM(@c_CountryCode),'') AS NVARCHAR(3)) AS CountryCode,
      CAST(LOC.Facility AS NVARCHAR(5)) AS Facility,
      RTRIM(UPPER(LOTxLOCxID.StorerKey)) AS StorerKey,
      ISNULL(RTRIM(STORER.Company),'') AS Company,
      RTRIM(UPPER(LOTxLOCxID.SKU)) AS SKU,
      RTRIM(UPPER(SKU.AltSku)) AS AtlSku,
      ISNULL(RTRIM( CASE WHEN SKU.Descr LIKE '%?%' THEN
                         ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
                    ELSE SKU.Descr END),'') AS SKU_Descr,
      ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS SKU_Scnd_Lang_Descr,
      RTRIM(SKU.Class) AS Class,
      RTRIM(SKU.SKUGroup) AS GroupCode,
      CASE WHEN RTRIM(SKU.ABC) not in ('A', 'B', 'C')
           THEN 'B' ELSE
      RTRIM(SKU.ABC) END AS ABC,
      RTRIM(SKU.ItemClass) AS ItemClass,
      RTRIM(SKU.BUSR3) AS Classification,
      RTRIM(SKU.BUSR5) AS ProductGroup,
      SUM(LOTxLOCxID.Qty) AS Qty,
      SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) AS QtyAvailable,
      ISNULL(RTRIM(UPPER(LOTATTRIBUTE.Lottable02)), '') AS Lottable02,
      CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable04,112)
         + LEFT(CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable04, 108),2)
         + SubString(CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable04,108),4,2)
         + Right(CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable04, 108),2) AS Lottable04,
      CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable05,112)
         + LEFT(CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable05, 108),2)
         + SubString(CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable05,108),4,2)
         + Right(CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable05, 108),2) AS Lottable05,
      RTRIM(PACK.PackUOM3) AS Master_Unit,
      RTRIM(MasterUnit.Description) AS Master_Unit_Desc,
      PACK.Qty AS MU_Units,
      RTRIM(PACK.PackUOM2) AS Inner_Pack,
      RTRIM(InnerPack.Description) AS Inner_Pack_Desc,
      PACK.InnerPack AS Inner_UOM_Units,
      RTRIM(PACK.PackUOM1) AS Carton,
      RTRIM(Carton.Description) AS Carton_Desc,
      PACK.CaseCnt AS Carton_UOM_Units,
      RTRIM(PACK.PackUOM4) AS Pallet,
      RTRIM(Pallet.Description) AS Pallet_Desc,
      PACK.Pallet AS Pallet_UOM_Units,
      PACK.PalletTI AS Units_Per_Layer,
      PACK.PalletHI AS Layers_Per_PL,
      ISNULL(RTRIM(UPPER(SKU.ManufacturerSku)),'') AS ManufacturerSku,
      ISNULL(RTRIM(UPPER(SKU.RetailSku)),'') AS RetailSku,
      ISNULL(RTRIM(UPPER(SKU.susr3)), '') AS AgencyCode,
      RTRIM(UPPER(SKU.lottable02label)) AS L2Label,
      RTRIM(UPPER(SKU.lottable03label)) AS L3Label,
      ISNULL(RTRIM(UPPER(LOTATTRIBUTE.Lottable03)), '') AS Lottable03,
      RTRIM(UPPER(SKU.lottable04label)) AS L4Label,
      RTRIM(UPPER(SKU.lottable05label)) AS L5Label,
      SUM(LOTxLOCxID.QtyAllocated) AS QtyAllocated,
      SUM(LOTxLOCxID.QtyPicked) AS QtyPicked,
      ISNULL(VHOLD.QtyOnHold, 0) AS QtyOnHold,
      ISNULL(RTRIM(SKU.Susr4), '') AS Susr4,
      ISNULL(RTRIM(SKU.busr10), '') AS Busr10,
      RTRIM(Class.Description) AS Class_Desc,
      RTRIM(ItemClass.Description) AS ItemClass_Desc,
      RTRIM(SkuGroup.Description) AS SkuGroup_Desc,
      RTRIM(ProdGroup.Description) AS ProdGroup_Desc,
      RTRIM(UPPER(FACILITY.UserDefine16)) AS Facility_Desc,
      CASE
         WHEN (RTRIM(SKU.Lottable04Label) = 'PRODN_DATE') OR (RTRIM(SKU.Lottable04Label) = 'MANDATE')
            THEN CONVERT(NVARCHAR(8), DATEADD(day,ISNULL(SKU.shelflife,0),LOTATTRIBUTE.Lottable04),112)
                  + LEFT(CONVERT(NVARCHAR(8), DATEADD(day,ISNULL(SKU.shelflife,0),LOTATTRIBUTE.Lottable04), 108),2)
                  + SubString(CONVERT(NVARCHAR(8), DATEADD(day,ISNULL(SKU.shelflife,0),LOTATTRIBUTE.Lottable04),108),4,2)
                  + Right(CONVERT(NVARCHAR(8), DATEADD(day,ISNULL(SKU.shelflife,0),LOTATTRIBUTE.Lottable04), 108),2)
         ELSE CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable04,112)
               + LEFT(CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable04, 108),2)
               + SubString(CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable04,108),4,2)
               + Right(CONVERT(NVARCHAR(8), LOTATTRIBUTE.Lottable04, 108),2)
      END AS Expiry_Date,
      SKU.Style,
      SKU.Color,
      SKU.Size,
      SKU.Measurement
      FROM LOTxLOCxID WITH (NOLOCK)
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.LOT = LOTATTRIBUTE.LOT)
      JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LOTxLOCxID.LOC)
      JOIN FACILITY WITH (NOLOCK) ON (LOC.Facility = FACILITY.Facility)
      JOIN STORER WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = STORER.StorerKey)
      JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKU.StorerKey AND
                            LOTxLOCxID.SKU = SKU.SKU )
      JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT OUTER JOIN Codelkup MasterUnit (NOLOCK) ON
            (PACK.PACKUOM3 = MasterUnit.Code AND
             MasterUnit.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup InnerPack (NOLOCK) ON
     (PACK.PACKUOM2 = InnerPack.Code AND
             InnerPack.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup Carton (NOLOCK) ON
            (PACK.PACKUOM1 = Carton.Code AND
             Carton.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Pallet (NOLOCK) ON
            (PACK.PACKUOM1 = Pallet.Code AND
             Pallet.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Class (NOLOCK) ON
            (SKU.Class = Class.Code AND
             Class.ListName = 'CLASS')
      LEFT OUTER JOIN Codelkup ItemClass (NOLOCK) ON
            (SKU.ItemClass = ItemClass.Code AND
             ItemClass.ListName = 'ITEMCLASS')
      LEFT OUTER JOIN Codelkup SkuGroup (NOLOCK) ON
            (SKU.SkuGroup = SkuGroup.Code AND
             SkuGroup.ListName = 'SKUGROUP')
      LEFT OUTER JOIN Codelkup ProdGroup (NOLOCK) ON
            (SKU.Busr3 = ProdGroup.Code AND
             ProdGroup.ListName = 'SKUFLAG')
      LEFT OUTER JOIN (SELECT Storerkey, SKU, Facility, Lottable02, Lottable03, Lottable04, Lottable05, QtyOnhold = SUM(QtyOnhold)
                       FROM  V_Qtyonhold
                       WHERE QtyOnhold > 0
                       GROUP BY Storerkey, SKU, Facility, Lottable02, Lottable03, Lottable04, Lottable05) VHOLD
                       ON  VHOLD.Storerkey = LOTXLOCXID.Storerkey
                       AND VHOLD.Sku = LOTXLOCXID.Sku
                       AND VHOLD.Facility = LOC.Facility
                       AND ISNULL(VHOLD.Lottable02, '') = ISNULL(LOTATTRIBUTE.Lottable02, '')
                       AND ISNULL(VHOLD.Lottable03, '') = ISNULL(LOTATTRIBUTE.Lottable03, '')
                       AND ISNULL(VHOLD.Lottable04, '') = ISNULL(LOTATTRIBUTE.Lottable04, '')
                       AND ISNULL(VHOLD.Lottable05, '') = ISNULL(LOTATTRIBUTE.Lottable05, '')
      GROUP BY
      CAST(LOC.Facility AS NVARCHAR(5)),
      LOTxLOCxID.StorerKey,
      ISNULL(RTRIM(STORER.Company),''),
      LOTxLOCxID.SKU,
      SKU.AltSku,
      ISNULL(RTRIM( CASE WHEN SKU.Descr LIKE '?%' THEN
                                           ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
                                       ELSE SKU.Descr END),''),
      ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), ''),
      SKU.Class,
      SKU.SKUGroup,
      SKU.ABC,
      SKU.ItemClass,
      SKU.BUSR3,
      SKU.BUSR5,
      LOTATTRIBUTE.Lottable02,
      LOTATTRIBUTE.Lottable04,
      LOTATTRIBUTE.Lottable05,
      PACK.PackUOM3,
      MasterUnit.Description,
      PACK.Qty,
      PACK.PackUOM2,
      InnerPack.Description,
      PACK.InnerPack,
      PACK.PackUOM1,
      Carton.Description,
      PACK.CaseCnt,
      PACK.PackUOM4,
      Pallet.Description,
      PACK.Pallet,
      PACK.PalletTI,
      PACK.PalletHI,
      ISNULL(RTRIM(UPPER(SKU.ManufacturerSku)),''),
      ISNULL(RTRIM(UPPER(SKU.RetailSku)),''),
      ISNULL(RTRIM(UPPER(SKU.susr3)), ''),
      SKU.lottable02label,
      SKU.lottable03label,
      LOTATTRIBUTE.Lottable03,
      SKU.lottable04label,
      SKU.lottable05label,
      VHOLD.QtyOnHold,
      SKU.Susr4,
      SKU.busr10,
      Class.Description,
      ItemClass.Description,
      SkuGroup.Description,
      ProdGroup.Description,
      FACILITY.UserDefine16,
      SKU.shelflife,
      SKU.Descr ,
      SKU.BUSR1,
      SKU.BUSR2,
      SKU.Style,
      SKU.Color,
      SKU.Size,
      SKU.Measurement
      HAVING SUM(LOTxLOCxID.Qty) > 0
      ORDER BY LOTXLOCXID.Storerkey, LOTXLOCXID.SKU, LOTATTRIBUTE.lottable02, LOTATTRIBUTE.lottable04, LOTATTRIBUTE.lottable05

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
   END

   IF @c_Type = 'OHI'
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM TriganticLog WITH (NOLOCK) WHERE TableName = 'ORDHIST')
      BEGIN
         SET @c_TriganticLogkey = ''

         IF @c_CountryCode IN ('CN','TW')
         BEGIN
            EXECUTE isp_GetTriganticKey
                 10
               , @c_TriganticLogkey OUTPUT
               , @b_success         OUTPUT
               , @n_err             OUTPUT
               , @c_errmsg          OUTPUT
         END
         ELSE
         BEGIN
            EXECUTE nspg_getkey
                 'TRIGANTICKEY'
               , 10
               , @c_TriganticLogkey OUTPUT
               , 0
               , 0
               , ''
         END

         INSERT TriganticLog (TriganticLogKey, TableName, Key1, Key2, Key3, EditDate)
         VALUES (@c_TriganticLogkey, 'ORDHIST', '', '', '', DATEADD(Day, -1, GETDATE()))
      END

      TRUNCATE TABLE DTSITF.dbo.TIPSOHI

      BEGIN TRAN
      INSERT INTO DTSITF.dbo.TIPSOHI
         ( CountryCode, Facility, Facility_Desc, Orders_StorerKey, Orders_Company
         , Orders_OrderKey, Order_ExterOrderKey, OrderDetail_OrderLineNumber, OrderDetail_ExternLineNo
         , Orders_OrderDate, Orders_DeliveryDate, Orders_ConsigneeKey, Orders_C_Company
         , Orders_OpenQty, Orders_Status, Orders_Status_Desc, Orders_Type
         , Order_AddDate, Orders_No_Lines, Orders_Principal, Principal_Desc
         , OrderDetail_Sku, Sku_Descr, Sku_Scnd_Lang_Descr, OrderDetail_AtlSku
         , Class, GroupCode, ABC, ItemClass, Classification, ProductGroup
         , OrderDetail_OriginalQty, OrderDetail_ShippedQty, OrderDetail_QtyAllocated, OrderDetail_QtyPicked
         , OrderDetail_UOM, OrderDetail_UOM_Desc, Master_Unit, Master_Unit_Desc
         , MU_Units, Inner_Pack, Inner_Pack_Desc, Inner_UOM_Units
         , Carton, Carton_Desc, Carton_UOM_Units
         , Pallet, Pallet_Desc, Pallet_UOM_Units, Units_Per_Layer, Layers_Per_PL
         , POD_Status, POD_Status_Desc, POD_DeliveryDate, Orders_Shipped_Date, POD_Returned_Date
         , C_Country, Susr4, Userdefine05, Lottable02, Lottable04, Priority
         , PO_Key, Busr10, Route, Route_Desc )
      SELECT
      CAST(ISNULL(RTRIM(@c_CountryCode),'') AS NVARCHAR(3)) AS CountryCode,
      RTRIM(UPPER(CAST(ORDERS.Facility AS NVARCHAR(5)))) AS Facility,
      RTRIM(UPPER(CAST(FACILITY.UserDefine16 AS NVARCHAR(50)))) AS Facility_Desc,
      RTRIM(UPPER(ORDERS.StorerKey)) AS Orders_StorerKey,
      ISNULL(RTRIM(STORER.Company),'') AS Orders_Company,
      ORDERS.OrderKey AS Orders_OrderKey,
      CASE
         WHEN ISNULL(RTRIM(ORDERS.ExternOrderkey),'') = ''
            THEN RTRIM(UPPER(ORDERS.StorerKey)) + RTRIM(UPPER(ORDERS.Type)) + ORDERS.OrderKey
         ELSE
            RTRIM(UPPER(ORDERS.ExternOrderKey))
      END AS Order_ExterOrderKey,
      ORDERDETAIL.OrderLineNumber AS OrderDetail_OrderLineNumber,
      RTRIM(ORDERDETAIL.ExternLineNo) AS ORDERDETAIL_ExternLineNo,
      CONVERT(NVARCHAR(8), ORDERS.OrderDate,112) + LEFT(CONVERT(NVARCHAR(8), ORDERS.OrderDate, 108),2)
            + SUBSTRING(CONVERT(NVARCHAR(8), ORDERS.OrderDate,108),4,2)
            + RIGHT(CONVERT(NVARCHAR(8), ORDERS.OrderDate, 108),2)
            AS ORDERS_OrderDate,
      CONVERT(NVARCHAR(8), ORDERS.DeliveryDate,112) + LEFT(CONVERT(NVARCHAR(8), ORDERS.DeliveryDate, 108),2)
            + SUBSTRING(CONVERT(NVARCHAR(8), ORDERS.DeliveryDate,108),4,2)
            + RIGHT(CONVERT(NVARCHAR(8), ORDERS.DeliveryDate, 108),2)
            AS ORDERS_DeliveryDate,
      RTRIM(ORDERS.ConsigneeKey) AS ORDERS_ConsigneeKey,
      ISNULL(RTRIM(ORDERS.C_Company),'') AS ORDERS_C_Company,
      ORDERS.OpenQty AS Orders_OpenQty,
      RTRIM(ORDERS.Status) AS Orders_Status,
      '9 - Shipped' AS Orders_Status_Desc,
      RTRIM(UPPER(ORDERS.Type)) AS Orders_Type,
      CONVERT(NVARCHAR(8), ORDERS.AddDate,112) + LEFT(CONVERT(NVARCHAR(8), ORDERS.AddDate, 108),2)
            + SUBSTRING(CONVERT(NVARCHAR(8), ORDERS.AddDate,108),4,2)
            + RIGHT(CONVERT(NVARCHAR(8), ORDERS.AddDate, 108),2)
            AS Order_AddDate,
      (SELECT COUNT(*) FROM ORDERDETAIL (NOLOCK) WHERE ORDERDETAIL.OrderKey = ORDERS.ORDERKEY)
      AS Orders_No_Lines,
      RTRIM(UPPER(SKU.susr3)) AS Orders_Principal,
      ISNULL(RTRIM(Principal.Description), '') AS Principal_Desc,
      RTRIM(UPPER(ORDERDETAIL.SKU)) AS OrderDetail_SKU,
      ISNULL(RTRIM( CASE WHEN SKU.Descr LIKE '%?%' THEN
         ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
         ELSE SKU.Descr END),'') AS SKU_Descr,
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60))
      AS SKU_Scnd_Lang_Descr,
      RTRIM(UPPER(ORDERDETAIL.AltSku)) AS OrderDetail_AtlSku,
      RTRIM(SKU.Class) AS Class,
      RTRIM(SKU.SKUGroup) AS GroupCode,
      CASE WHEN RTRIM(SKU.ABC) NOT IN ('A', 'B', 'C')
           THEN 'B' ELSE
      RTRIM(SKU.ABC) END AS ABC,
      RTRIM(SKU.ItemClass) AS ItemClass,
      RTRIM(SKU.BUSR3) AS Classification,
      RTRIM(SKU.BUSR5) AS ProductGroup,
      ORDERDETAIL.OriginalQty AS OrderDetail_OriginalQty,
      CASE RTRIM(ORDERS.Status)
         WHEN '9' THEN ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty
         ELSE 0
      END AS OrderDetail_ShippedQty,
      CASE RTRIM(ORDERS.Status)
         WHEN '9' THEN 0
         ELSE ORDERDETAIL.QtyAllocated
      END AS OrderDetail_QtyAllocated,
      CASE RTRIM(ORDERS.Status)
         WHEN '9' THEN 0
         ELSE ORDERDETAIL.QtyPicked
      END AS OrderDetail_QtyPicked,
      ORDERDETAIL.UOM AS OrderDetail_UOM,
       CASE ORDERDETAIL.UOM
            WHEN PACK.PACKUOM3 THEN
               RTRIM(QtyUOMDesc.Description)
            WHEN PACK.PACKUOM2 THEN
               RTRIM(QtyUOMDesc.Description)
            ELSE
               RTRIM(PackageUOMDesc.Description)
       END  AS OrderDetail_UOM_Desc,
      ISNULL(RTRIM(PACK.PackUOM3), '') AS Master_Unit,
      ISNULL(RTRIM(MasterUnit.Description), '') AS Master_Unit_Desc,
      PACK.Qty AS MU_Units,
      ISNULL(RTRIM(PACK.PackUOM2), '') AS Inner_Pack,
      ISNULL(RTRIM(InnerPack.Description), '') AS Inner_Pack_Desc,
      PACK.InnerPack AS Inner_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM1), '') AS Carton,
      ISNULL(RTRIM(Carton.Description), '') AS Carton_Desc,
      PACK.CaseCnt AS Carton_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM4), '') AS Pallet,
      ISNULL(RTRIM(Pallet.Description), '') AS Pallet_Desc,
      PACK.Pallet AS Pallet_UOM_Units,
      PACK.PalletTI AS Units_Per_Layer,
      PACK.PalletHI AS Layers_Per_PL,
      POD.Status AS POD_Status,
      RTRIM(PODStatus.Description) AS POD_Status_Desc,
      CONVERT(NVARCHAR(8), POD.ActualDeliveryDate,112) + LEFT(CONVERT(NVARCHAR(8), POD.ActualDeliveryDate, 108),2)
            + SUBSTRING(CONVERT(NVARCHAR(8), POD.ActualDeliveryDate,108),4,2)
            + RIGHT(CONVERT(NVARCHAR(8), POD.ActualDeliveryDate, 108),2)
            AS POD_DEliveryDate,
      CASE
         WHEN (ORDERS.Status = '9' OR ORDERS.SoStatus = '9') AND MBOL.MbolKey IS NULL
            THEN CONVERT(NVARCHAR(8), ORDERS.EditDate,112) + LEFT(CONVERT(NVARCHAR(8), ORDERS.EditDate, 108),2)
                  + SUBSTRING(CONVERT(NVARCHAR(8), ORDERS.EditDate,108),4,2)
                  + RIGHT(CONVERT(NVARCHAR(8), ORDERS.EditDate, 108),2)
         ELSE CONVERT(NVARCHAR(8), MBOL.EditDate,112) + LEFT(CONVERT(NVARCHAR(8), MBOL.EditDate, 108),2)
               + SUBSTRING(CONVERT(NVARCHAR(8), MBOL.EditDate,108),4,2)
               + RIGHT(CONVERT(NVARCHAR(8), MBOL.EditDate, 108),2)
      END AS ORDERS_SHIPPED_DATE,
      CONVERT(NVARCHAR(8), POD.PodReceivedDate,112) + LEFT(CONVERT(NVARCHAR(8), POD.PodReceivedDate, 108),2)
            + SUBSTRING(CONVERT(NVARCHAR(8), POD.PodReceivedDate,108),4,2)
        + RIGHT(CONVERT(NVARCHAR(8), POD.PodReceivedDate, 108),2) AS POD_RETURNED_DATE,
      ISNULL(RTRIM(ORDERS.C_Country),'') AS C_Country,
      ISNULL(RTRIM(SKU.susr4),'') AS Susr4,
      ISNULL(RTRIM(ORDERS.userdefine05), '') AS Userdefine05,
      ISNULL(RTRIM(ORDERDETAIL.lottable02), '') AS Lottable02,
      CONVERT(NVARCHAR(8), ORDERDETAIL.Lottable04,112) + LEFT(CONVERT(NVARCHAR(8), ORDERDETAIL.Lottable04, 108),2)
            + SUBSTRING(CONVERT(NVARCHAR(8), ORDERDETAIL.Lottable04,108),4,2)
            + RIGHT(CONVERT(NVARCHAR(8), ORDERDETAIL.Lottable04, 108),2) AS Lottable04,
      ISNULL(RTRIM(ORDERS.Priority), '') AS Priority,
      ISNULL(RTRIM(ORDERS.BuyerPO), '') AS PO_Key,
      ISNULL(RTRIM(SKU.busr10), '') AS Busr10,
      ISNULL(RTRIM(ORDERS.Route), '') AS Route,
      ISNULL(RTRIM(RouteMaster.Descr), '') AS Route_Desc
      FROM ORDERS (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
      JOIN FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)
      JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
      JOIN SKU (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND
                            ORDERDETAIL.SKU = SKU.SKU )
      JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT OUTER JOIN MBOL (NOLOCK) ON (MBOL.MbolKey = ORDERDETAIL.MbolKey)
      LEFT OUTER JOIN POD (NOLOCK) ON (ORDERS.OrderKey = POD.OrderKey
                                          AND ORDERDETAIL.mbolkey = POD.mbolkey
                     AND ORDERDETAIL.loadkey = POD.loadkey)
      LEFT OUTER JOIN CODELKUP QtyUOMDesc (NOLOCK)
           ON (QtyUOMDesc.Code = ORDERDETAIL.UOM AND
               QtyUOMDesc.ListName = 'Quantity')
      LEFT OUTER JOIN CODELKUP PacKageUOMDesc (NOLOCK)
           ON (QtyUOMDesc.Code = ORDERDETAIL.UOM AND
               QtyUOMDesc.ListName = 'Package')
      LEFT OUTER JOIN Codelkup MasterUnit (NOLOCK) ON
            (PACK.PACKUOM3 = MasterUnit.Code AND
             MasterUnit.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup InnerPack (NOLOCK) ON
            (PACK.PACKUOM2 = InnerPack.Code AND
             InnerPack.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup Carton (NOLOCK) ON
            (PACK.PACKUOM1 = Carton.Code AND
             Carton.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Pallet (NOLOCK) ON
            (PACK.PACKUOM4 = Pallet.Code AND
             Pallet.ListName = 'Package')
      LEFT OUTER JOIN Codelkup PODStatus (NOLOCK) ON
            (PODStatus.ListName = 'PODStatus' AND
             PODStatus.Code = POD.Status)
      LEFT OUTER JOIN Codelkup Principal (NOLOCK) ON
            (Principal.ListName = 'PRINCIPAL' AND
             Principal.Code = SKU.susr3)
      --LEFT OUTER JOIN StorerConfig (NOLOCK) -- SOS# 169887 - Remove StorerConfig because Trigantic is mandatory for all storers
      --   ON (StorerConfig.StorerKey = ORDERS.StorerKey
      --         AND ConfigKey = 'TIPS_POD'
      --         AND ((StorerConfig.sValue = '1' AND POD.FinalizeFlag = 'Y')
      --               OR (StorerConfig.sValue <> '1' OR POD.FinalizeFlag IS NULL)))
      LEFT OUTER JOIN RouteMaster (NOLOCK) ON
            (RouteMaster.Route = ORDERS.Route)
      --JOIN StorerConfig s1 (nolock) -- SOS# 169887 - Remove StorerConfig because Trigantic is mandatory for all storers
      --   ON (ORDERS.StorerKey = s1.StorerKey
      --         AND s1.Configkey = 'TRIGANTIC'
      --         AND s1.sValue = '1')
      WHERE ORDERS.EditDate > (SELECT MAX(EditDate) FROM TriganticLog (NOLOCK) WHERE TableName = 'ORDHIST')
      AND ORDERS.Status = '9'
      UNION -- SOS# 158571 - Include Cancelled Order
      SELECT
      CAST(ISNULL(RTRIM(@c_CountryCode),'') AS NVARCHAR(3)) AS CountryCode,
      RTRIM(UPPER(CAST(ORDERS.Facility AS NVARCHAR(5)))) AS Facility,
      RTRIM(UPPER(CAST(FACILITY.UserDefine16 AS NVARCHAR(50)))) AS Facility_Desc,
      RTRIM(UPPER(ORDERS.StorerKey)) AS Orders_StorerKey,
      ISNULL(RTRIM(STORER.Company),'') AS Orders_Company,
      ORDERS.OrderKey AS Orders_OrderKey,
      CASE
         WHEN ISNULL(RTRIM(ORDERS.ExternOrderkey),'') = ''
              THEN RTRIM(UPPER(ORDERS.StorerKey)) + RTRIM(UPPER(ORDERS.Type)) + ORDERS.OrderKey
         ELSE
            RTRIM(UPPER(ORDERS.ExternOrderKey))
      END AS Order_ExterOrderKey,
      ORDERDETAIL.OrderLineNumber AS OrderDetail_OrderLineNumber,
      RTRIM(ORDERDETAIL.ExternLineNo) AS ORDERDETAIL_ExternLineNo,
      CONVERT(CHAR(8), ORDERS.OrderDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.OrderDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERS.OrderDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERS.OrderDate, 108),2)
            AS ORDERS_OrderDate,
      CONVERT(CHAR(8), ORDERS.DeliveryDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.DeliveryDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERS.DeliveryDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERS.DeliveryDate, 108),2)
            AS ORDERS_DeliveryDate,
      RTRIM(ORDERS.ConsigneeKey) AS ORDERS_ConsigneeKey,
      ISNULL(RTRIM(ORDERS.C_Company),'') AS ORDERS_C_Company,
      ORDERS.OpenQty AS Orders_OpenQty,
      CASE RTRIM(ORDERS.Status)
         WHEN 'CANC' THEN 'CANC'
      ELSE CASE RTRIM(ORDERS.SOStatus)
               WHEN 'CANC' THEN 'CANC'
           END
      END AS Orders_Status,
      'Cancelled' AS Orders_Status_Desc,
      RTRIM(UPPER(ORDERS.Type)) AS Orders_Type,
      CONVERT(CHAR(8), ORDERS.AddDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.AddDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERS.AddDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERS.AddDate, 108),2)
            AS Order_AddDate,
      (SELECT COUNT(*) FROM ORDERDETAIL (NOLOCK) WHERE ORDERDETAIL.OrderKey = ORDERS.ORDERKEY)
      AS Orders_No_Lines,
      RTRIM(UPPER(SKU.susr3)) AS Orders_Principal,
      ISNULL(RTRIM(Principal.Description), '') AS Principal_Desc,
      RTRIM(UPPER(ORDERDETAIL.SKU)) AS OrderDetail_SKU,
      ISNULL(RTRIM( CASE WHEN SKU.Descr LIKE '%?%' THEN
         ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
         ELSE SKU.Descr END),'') AS SKU_Descr,
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60))
      AS SKU_Scnd_Lang_Descr,
      RTRIM(UPPER(ORDERDETAIL.AltSku)) AS OrderDetail_AtlSku,
      RTRIM(SKU.Class) AS Class,
      RTRIM(SKU.SKUGroup) AS GroupCode,
      CASE WHEN RTRIM(SKU.ABC) NOT IN ('A', 'B', 'C')
           THEN 'B' ELSE
      RTRIM(SKU.ABC) END AS ABC,
      RTRIM(SKU.ItemClass) AS ItemClass,
      RTRIM(SKU.BUSR3) AS Classification,
      RTRIM(SKU.BUSR5) AS ProductGroup,
      ORDERDETAIL.OriginalQty AS OrderDetail_OriginalQty,
      0 AS OrderDetail_ShippedQty,
      0 AS OrderDetail_QtyAllocated,
      0 AS OrderDetail_QtyPicked,
      ORDERDETAIL.UOM AS OrderDetail_UOM,
       CASE ORDERDETAIL.UOM
            WHEN PACK.PACKUOM3 THEN
               RTRIM(QtyUOMDesc.Description)
            WHEN PACK.PACKUOM2 THEN
               RTRIM(QtyUOMDesc.Description)
            ELSE
               RTRIM(PackageUOMDesc.Description)
       END  AS OrderDetail_UOM_Desc,
      ISNULL(RTRIM(PACK.PackUOM3), '') AS Master_Unit,
      ISNULL(RTRIM(MasterUnit.Description), '') AS Master_Unit_Desc,
      PACK.Qty AS MU_Units,
      ISNULL(RTRIM(PACK.PackUOM2), '') AS Inner_Pack,
      ISNULL(RTRIM(InnerPack.Description), '') AS Inner_Pack_Desc,
      PACK.InnerPack AS Inner_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM1), '') AS Carton,
      ISNULL(RTRIM(Carton.Description), '') AS Carton_Desc,
      PACK.CaseCnt AS Carton_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM4), '') AS Pallet,
      ISNULL(RTRIM(Pallet.Description), '') AS Pallet_Desc,
      PACK.Pallet AS Pallet_UOM_Units,
      PACK.PalletTI AS Units_Per_Layer,
      PACK.PalletHI AS Layers_Per_PL,
      POD.Status AS POD_Status,
      RTRIM(PODStatus.Description) AS POD_Status_Desc,
      CONVERT(CHAR(8), POD.ActualDeliveryDate,112) + LEFT(CONVERT(CHAR(8), POD.ActualDeliveryDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), POD.ActualDeliveryDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), POD.ActualDeliveryDate, 108),2)
            AS POD_DEliveryDate,
      CASE
         WHEN (ORDERS.Status = 'CANC' OR ORDERS.SoStatus = 'CANC') AND MBOL.MbolKey IS NULL
          THEN CONVERT(CHAR(8), ORDERS.EditDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.EditDate, 108),2)
                  + SUBSTRING(CONVERT(CHAR(8), ORDERS.EditDate,108),4,2)
                  + RIGHT(CONVERT(CHAR(8), ORDERS.EditDate, 108),2)
         ELSE CONVERT(CHAR(8), MBOL.EditDate,112) + LEFT(CONVERT(CHAR(8), MBOL.EditDate, 108),2)
               + SUBSTRING(CONVERT(CHAR(8), MBOL.EditDate,108),4,2)
               + RIGHT(CONVERT(CHAR(8), MBOL.EditDate, 108),2)
      END AS ORDERS_SHIPPED_DATE,
      CONVERT(CHAR(8), POD.PodReceivedDate,112) + LEFT(CONVERT(CHAR(8), POD.PodReceivedDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), POD.PodReceivedDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), POD.PodReceivedDate, 108),2) AS POD_RETURNED_DATE,
      ISNULL(RTRIM(ORDERS.C_Country),'') AS C_Country,
      ISNULL(RTRIM(SKU.susr4),'') AS Susr4,
      ISNULL(RTRIM(ORDERS.userdefine05), '') AS Userdefine05,
      ISNULL(RTRIM(ORDERDETAIL.lottable02), '') AS Lottable02,
      CONVERT(CHAR(8), ORDERDETAIL.Lottable04,112) + LEFT(CONVERT(CHAR(8), ORDERDETAIL.Lottable04, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERDETAIL.Lottable04,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERDETAIL.Lottable04, 108),2) AS Lottable04,
      ISNULL(RTRIM(ORDERS.Priority), '') AS Priority,
      ISNULL(RTRIM(ORDERS.BuyerPO), '') AS PO_Key,
      ISNULL(RTRIM(SKU.busr10), '') AS Busr10,
      ISNULL(RTRIM(ORDERS.Route), '') AS Route,
      ISNULL(RTRIM(RouteMaster.Descr), '') AS Route_Desc
      FROM ORDERS (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
      JOIN FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)
      JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
      JOIN SKU (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND
                            ORDERDETAIL.SKU = SKU.SKU )
      JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT OUTER JOIN MBOL (NOLOCK) ON (MBOL.MbolKey = ORDERDETAIL.MbolKey)
      LEFT OUTER JOIN POD (NOLOCK) ON (ORDERS.OrderKey = POD.OrderKey
                                          AND ORDERDETAIL.mbolkey = POD.mbolkey
                     AND ORDERDETAIL.loadkey = POD.loadkey)
      LEFT OUTER JOIN CODELKUP QtyUOMDesc (NOLOCK)
           ON (QtyUOMDesc.Code = ORDERDETAIL.UOM AND
               QtyUOMDesc.ListName = 'Quantity')
      LEFT OUTER JOIN CODELKUP PacKageUOMDesc (NOLOCK)
           ON (QtyUOMDesc.Code = ORDERDETAIL.UOM AND
               QtyUOMDesc.ListName = 'Package')
      LEFT OUTER JOIN Codelkup MasterUnit (NOLOCK) ON
            (PACK.PACKUOM3 = MasterUnit.Code AND
             MasterUnit.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup InnerPack (NOLOCK) ON
            (PACK.PACKUOM2 = InnerPack.Code AND
             InnerPack.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup Carton (NOLOCK) ON
            (PACK.PACKUOM1 = Carton.Code AND
             Carton.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Pallet (NOLOCK) ON
            (PACK.PACKUOM4 = Pallet.Code AND
             Pallet.ListName = 'Package')
      LEFT OUTER JOIN Codelkup PODStatus (NOLOCK) ON
            (PODStatus.ListName = 'PODStatus' AND
             PODStatus.Code = POD.Status)
      LEFT OUTER JOIN Codelkup Principal (NOLOCK) ON
            (Principal.ListName = 'PRINCIPAL' AND
             Principal.Code = SKU.susr3)
      --LEFT OUTER JOIN StorerConfig (NOLOCK)  -- SOS# 169887 - Remove StorerConfig because Trigantic is mandatory for all storers
      --   ON (StorerConfig.StorerKey = ORDERS.StorerKey
      --         AND ConfigKey = 'TIPS_POD'
      --         AND ((StorerConfig.sValue = '1' AND POD.FinalizeFlag = 'Y')
      --               OR (StorerConfig.sValue <> '1' OR POD.FinalizeFlag IS NULL)))
      LEFT OUTER JOIN RouteMaster (NOLOCK) ON
            (RouteMaster.Route = ORDERS.Route)
      --JOIN StorerConfig s1 (nolock)  -- SOS# 169887 - Remove StorerConfig because Trigantic is mandatory for all storers
      --   ON (ORDERS.StorerKey = s1.StorerKey
      --         AND s1.Configkey = 'TRIGANTIC'
      --         AND s1.sValue = '1')
      WHERE ORDERS.EditDate > (SELECT MAX(EditDate) FROM TriganticLog (NOLOCK) WHERE TableName = 'ORDHIST')
      AND (ORDERS.Status = 'CANC' OR ORDERS.SOStatus = 'CANC')
      ORDER BY ORDERS.OrderKey, ORDERDETAIL.OrderLineNumber

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
   END

   IF @c_Type = 'DELORD'
   BEGIN
      TRUNCATE TABLE DTSITF.dbo.TIPSDELORD
      BEGIN TRAN
      INSERT INTO DTSITF.dbo.TIPSDELORD
         ( CountryCode, Facility, Facility_Desc, Del_Orders_StorerKey
         , Del_Orders_Company, Del_Orders_OrderKey, Order_ExterOrderKey, Del_OrderDetail_OrderLineNumber, Del_OrderDetail_ExternLineNo
         , Del_Orders_OrderDate, Del_Orders_DeliveryDate
         , Del_Orders_ConsigneeKey, Del_Orders_C_Company, Del_Orders_OpenQty, Del_Orders_Status
         , Del_Orders_Status_Desc, Del_Orders_Type, Order_AddDate, Del_Orders_No_Lines
         , Del_Orders_Principle, Principle_Desc, Del_OrderDetail_Sku
         , Sku_Descr, Sku_Scnd_Lang_Descr, Del_OrderDetail_AtlSku
         , Class, GroupCode, ABC, ItemClass, Classification, ProductGroup
         , Del_OrderDetail_OriginalQty, Del_OrderDetail_ShippedQty, Del_OrderDetail_QtyAllocated, Del_OrderDetail_QtyPicked
         , Del_OrderDetail_UOM, Del_OrderDetail_UOM_Desc
         , Master_Unit, Master_Unit_Desc, MU_Units
         , Inner_Pack, Inner_Pack_Desc, Inner_UOM_Units
         , Carton, Carton_Desc, Carton_UOM_Units
         , Pallet, Pallet_Desc, Pallet_UOM_Units, Units_Per_Layer, Layers_Per_PL
         , POD_Status, POD_Status_Desc, POD_DeliveryDate, Orders_Shipped_Date, POD_Returned_Date
         , C_Country, Susr4, Userdefine05, Lottable02, Lottable04
         , Priority, PO_Key, Busr10
         )
      SELECT DISTINCT
      CAST(ISNULL(RTRIM(@c_CountryCode),'') AS NVARCHAR(3)) AS CountryCode,
      RTRIM(UPPER(CAST(DEL_ORDERS.Facility AS NVARCHAR(5)))) AS Facility,
      RTRIM(UPPER(CAST(FACILITY.UserDefine16 AS NVARCHAR(50)))) AS Facility_Desc,
      RTRIM(UPPER(DEL_ORDERS.StorerKey)) AS DEL_ORDERS_StorerKey,
      ISNULL(RTRIM(STORER.Company),'') AS DEL_ORDERS_Company,
      DEL_ORDERS.OrderKey AS DEL_ORDERS_OrderKey,
      CASE
         WHEN ISNULL(RTRIM(DEL_ORDERS.ExternOrderkey),'') = ''
            THEN RTRIM(UPPER(DEL_ORDERS.StorerKey)) + RTRIM(UPPER(DEL_ORDERS.Type)) + DEL_ORDERS.OrderKey
         ELSE
            RTRIM(UPPER(DEL_ORDERS.ExternOrderKey))
      END AS Order_ExterOrderKey,
      DEL_ORDERDETAIL.OrderLineNumber AS DEL_ORDERDETAIL_OrderLineNumber,
      RTRIM(DEL_ORDERDETAIL.ExternLineNo) AS DEL_ORDERDETAIL_ExternLineNo,
      CONVERT(CHAR(8), DEL_ORDERS.OrderDate,112) + LEFT(CONVERT(CHAR(8), DEL_ORDERS.OrderDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), DEL_ORDERS.OrderDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), DEL_ORDERS.OrderDate, 108),2)
            AS DEL_ORDERS_OrderDate,
      CONVERT(CHAR(8), DEL_ORDERS.DeliveryDate,112) + LEFT(CONVERT(CHAR(8), DEL_ORDERS.DeliveryDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), DEL_ORDERS.DeliveryDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), DEL_ORDERS.DeliveryDate, 108),2)
            AS DEL_ORDERS_DeliveryDate,
      RTRIM(DEL_ORDERS.ConsigneeKey) AS DEL_ORDERS_ConsigneeKey,
      ISNULL(RTRIM(DEL_ORDERS.C_Company),'') AS DEL_ORDERS_C_Company,
      DEL_ORDERS.OpenQty AS DEL_ORDERS_OpenQty,
      'CANC' AS DEL_ORDERS_Status,
      'Cancelled' AS DEL_ORDERS_Status_Desc,
      RTRIM(UPPER(DEL_ORDERS.Type)) AS DEL_ORDERS_Type,
      CONVERT(CHAR(8), DEL_ORDERS.AddDate,112) + LEFT(CONVERT(CHAR(8), DEL_ORDERS.AddDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), DEL_ORDERS.AddDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), DEL_ORDERS.AddDate, 108),2)
            AS Order_AddDate,
      (SELECT Count(*) FROM DEL_ORDERDETAIL (NOLOCK) WHERE DEL_ORDERDETAIL.OrderKey = DEL_ORDERS.ORDERKEY)
      AS DEL_ORDERS_No_Lines,
      RTRIM(UPPER(SKU.susr3)) AS DEL_ORDERS_Principle,
      ' ' AS Principle_Desc,
      RTRIM(UPPER(DEL_ORDERDETAIL.SKU)) AS DEL_ORDERDETAIL_SKU,
      ISNULL(RTRIM( CASE WHEN SKU.Descr Like '%?%' THEN
       ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
       ELSE SKU.Descr END),'') AS SKU_Descr,
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60))
      AS SKU_Scnd_Lang_Descr,
      RTRIM(UPPER(DEL_ORDERDETAIL.AltSku)) AS DEL_ORDERDETAIL_AtlSku,
      RTRIM(SKU.Class) AS Class,
      RTRIM(SKU.SKUGroup) AS GroupCode,
      CASE WHEN RTRIM(SKU.ABC) not in ('A', 'B', 'C')
           THEN 'B' ELSE
      RTRIM(SKU.ABC) END AS ABC,
      RTRIM(SKU.ItemClass) AS ItemClass,
      RTRIM(SKU.BUSR3) AS Classification,
      RTRIM(SKU.BUSR5) AS ProductGroup,
      DEL_ORDERDETAIL.OriginalQty AS DEL_ORDERDETAIL_OriginalQty,
      DEL_ORDERDETAIL.ShippedQty AS DEL_ORDERDETAIL_ShippedQty,
      DEL_ORDERDETAIL.QtyAllocated AS DEL_ORDERDETAIL_QtyAllocated,
      DEL_ORDERDETAIL.QtyPicked AS DEL_ORDERDETAIL_QtyPicked,
      DEL_ORDERDETAIL.UOM AS DEL_ORDERDETAIL_UOM,
       CASE DEL_ORDERDETAIL.UOM
            WHEN PACK.PACKUOM3 THEN
               RTRIM(QtyUOMDesc.Description)
            WHEN PACK.PACKUOM2 THEN
               RTRIM(QtyUOMDesc.Description)
            ELSE
               RTRIM(PackageUOMDesc.Description)
       END  AS DEL_ORDERDETAIL_UOM_Desc,
      ISNULL(RTRIM(PACK.PackUOM3), '') AS Master_Unit,
      ISNULL(RTRIM(MasterUnit.Description), '') AS Master_Unit_Desc,
      PACK.Qty AS MU_Units,
      ISNULL(RTRIM(PACK.PackUOM2), '') AS Inner_Pack,
      ISNULL(RTRIM(InnerPack.Description), '') AS Inner_Pack_Desc,
      PACK.InnerPack AS Inner_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM1), '') AS Carton,
      ISNULL(RTRIM(Carton.Description), '') AS Carton_Desc,
      PACK.CaseCnt AS Carton_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM4), '') AS Pallet,
      ISNULL(RTRIM(Pallet.Description), '') AS Pallet_Desc,
      PACK.Pallet AS Pallet_UOM_Units,
      PACK.PalletTI AS Units_Per_Layer,
      PACK.PalletHI AS Layers_Per_PL,
      RTRIM(POD.Status) AS POD_Status,
      RTRIM(PODStatus.Description) AS POD_Status_Desc,
      CONVERT(CHAR(8), POD.ActualDeliveryDate,112) + LEFT(CONVERT(CHAR(8), POD.ActualDeliveryDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), POD.ActualDeliveryDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), POD.ActualDeliveryDate, 108),2)
            AS POD_DeliveryDate,
      CONVERT(CHAR(8), MBOL.EditDate,112) + LEFT(CONVERT(CHAR(8), MBOL.EditDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), MBOL.EditDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), MBOL.EditDate, 108),2) AS ORDERS_SHIPPED_DATE,
      CONVERT(CHAR(8), POD.PodReceivedDate,112) + LEFT(CONVERT(CHAR(8), POD.PodReceivedDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), POD.PodReceivedDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), POD.PodReceivedDate, 108),2) AS POD_RETURNED_DATE,
      ISNULL(RTRIM(DEL_ORDERS.C_Country),'') AS C_Country,
      ISNULL(RTRIM(SKU.susr4),'') AS Susr4,
      ISNULL(RTRIM(DEL_ORDERS.userdefine05), '') AS Userdefine05,
      ISNULL(RTRIM(DEL_ORDERDETAIL.lottable02), '') AS Lottable02,
      CONVERT(CHAR(8), DEL_ORDERDETAIL.Lottable04,112) + LEFT(CONVERT(CHAR(8), DEL_ORDERDETAIL.Lottable04, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), DEL_ORDERDETAIL.Lottable04,108),4,2)
            + RIGHT(CONVERT(CHAR(8), DEL_ORDERDETAIL.Lottable04, 108),2) AS Lottable04,
      ISNULL(RTRIM(DEL_ORDERS.Priority), '') AS Priority,
      ISNULL(RTRIM(DEL_ORDERS.BuyerPO), '') AS PO_Key,
      ISNULL(RTRIM(SKU.busr10), '') AS Busr10
      FROM DEL_ORDERS (NOLOCK)
      JOIN DEL_ORDERDETAIL (NOLOCK) ON (DEL_ORDERS.OrderKey = DEL_ORDERDETAIL.OrderKey)
      JOIN FACILITY (NOLOCK) ON (DEL_ORDERS.Facility = FACILITY.Facility)
      JOIN STORER (NOLOCK) ON (DEL_ORDERS.StorerKey = STORER.StorerKey)
      JOIN SKU (NOLOCK) ON (DEL_ORDERDETAIL.StorerKey = SKU.StorerKey AND
                            DEL_ORDERDETAIL.SKU = SKU.SKU )
      JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT OUTER JOIN MBOL (NOLOCK) ON (MBOL.MbolKey = DEL_ORDERDETAIL.MbolKey)
      LEFT OUTER JOIN POD (NOLOCK) ON (DEL_ORDERS.OrderKey = POD.OrderKey
                                          AND DEL_ORDERDETAIL.mbolkey = POD.mbolkey
                     AND DEL_ORDERDETAIL.loadkey = POD.loadkey)
      LEFT OUTER JOIN CODELKUP QtyUOMDesc (NOLOCK)
           ON (QtyUOMDesc.Code = DEL_ORDERDETAIL.UOM AND
               QtyUOMDesc.ListName = 'Quantity')
      LEFT OUTER JOIN CODELKUP PacKageUOMDesc (NOLOCK)
           ON (PacKageUOMDesc.Code = DEL_ORDERDETAIL.UOM AND
               PacKageUOMDesc.ListName = 'Package')
      LEFT OUTER JOIN Codelkup MasterUnit (NOLOCK) ON
            (PACK.PACKUOM3 = MasterUnit.Code AND
             MasterUnit.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup InnerPack (NOLOCK) ON
            (PACK.PACKUOM2 = InnerPack.Code AND
             InnerPack.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup Carton (NOLOCK) ON
            (PACK.PACKUOM1 = Carton.Code AND
             Carton.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Pallet (NOLOCK) ON
            (PACK.PACKUOM4 = Pallet.Code AND
             Pallet.ListName = 'Package')
      LEFT OUTER JOIN Codelkup PODStatus (NOLOCK) ON
            (PODStatus.ListName = 'PODStatus' AND
             PODStatus.Code = POD.Status)
      WHERE DEL_ORDERS.EditDate > DATEADD(DAY, -1, GETDATE())
      UNION ALL
      SELECT DISTINCT
      CAST(ISNULL(RTRIM(@c_CountryCode),'') AS NVARCHAR(3)) AS CountryCode,
      RTRIM(UPPER(CAST(ORDERS.Facility AS NVARCHAR(5)))) AS Facility,
      RTRIM(UPPER(CAST(FACILITY.UserDefine16 AS NVARCHAR(50)))) AS Facility_Desc,
      RTRIM(UPPER(ORDERS.StorerKey)) AS DEL_ORDERS_StorerKey,
      ISNULL(RTRIM(STORER.Company),'') AS DEL_ORDERS_Company,
      ORDERS.OrderKey AS DEL_ORDERS_OrderKey,
      CASE
         WHEN ISNULL(RTRIM(ORDERS.ExternOrderkey),'') = ''
            THEN RTRIM(UPPER(ORDERS.StorerKey)) + RTRIM(UPPER(ORDERS.Type)) + ORDERS.OrderKey
         ELSE
            RTRIM(UPPER(ORDERS.ExternOrderKey))
      END AS Order_ExterOrderKey,
      DEL_ORDERDETAIL.OrderLineNumber AS DEL_ORDERDETAIL_OrderLineNumber,
      RTRIM(DEL_ORDERDETAIL.ExternLineNo) AS DEL_ORDERDETAIL_ExternLineNo,
      CONVERT(CHAR(8), ORDERS.OrderDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.OrderDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERS.OrderDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERS.OrderDate, 108),2)
            AS DEL_ORDERS_OrderDate,
      CONVERT(CHAR(8), ORDERS.DeliveryDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.DeliveryDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERS.DeliveryDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERS.DeliveryDate, 108),2)
            AS DEL_ORDERS_DeliveryDate,
      RTRIM(ORDERS.ConsigneeKey) AS DEL_ORDERS_ConsigneeKey,
      ISNULL(RTRIM(ORDERS.C_Company),'') AS DEL_ORDERS_C_Company,
      ORDERS.OpenQty AS DEL_ORDERS_OpenQty,
      'CANC' AS DEL_ORDERS_Status,
      'Cancelled' AS DEL_ORDERS_Status_Desc,
      RTRIM(UPPER(ORDERS.Type)) AS DEL_ORDERS_Type,
      CONVERT(CHAR(8), ORDERS.AddDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.AddDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERS.AddDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERS.AddDate, 108),2)
            AS Order_AddDate,
      (SELECT Count(*) FROM DEL_ORDERDETAIL (NOLOCK) WHERE DEL_ORDERDETAIL.OrderKey = ORDERS.ORDERKEY)
      AS DEL_ORDERS_No_Lines,
      RTRIM(UPPER(SKU.susr3)) AS DEL_ORDERS_Principle,
      ' ' AS Principle_Desc,
      RTRIM(UPPER(DEL_ORDERDETAIL.SKU)) AS DEL_ORDERDETAIL_SKU,
      ISNULL(RTRIM(SKU.Descr),'') AS SKU_Descr,
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60))
      AS SKU_Scnd_Lang_Descr,
      RTRIM(UPPER(DEL_ORDERDETAIL.AltSku)) AS DEL_ORDERDETAIL_AtlSku,
      RTRIM(SKU.Class) AS Class,
      RTRIM(SKU.SKUGroup) AS GroupCode,
      RTRIM(SKU.ABC) AS ABC,
      RTRIM(SKU.ItemClass) AS ItemClass,
      RTRIM(SKU.BUSR3) AS Classification,
      RTRIM(SKU.BUSR5) AS ProductGroup,
      DEL_ORDERDETAIL.OriginalQty AS DEL_ORDERDETAIL_OriginalQty,
      DEL_ORDERDETAIL.ShippedQty AS DEL_ORDERDETAIL_ShippedQty,
      DEL_ORDERDETAIL.QtyAllocated AS DEL_ORDERDETAIL_QtyAllocated,
      DEL_ORDERDETAIL.QtyPicked AS DEL_ORDERDETAIL_QtyPicked,
      DEL_ORDERDETAIL.UOM AS DEL_ORDERDETAIL_UOM,
      CASE DEL_ORDERDETAIL.UOM
         WHEN PACK.PACKUOM3 THEN
            RTRIM(QtyUOMDesc.Description)
         WHEN PACK.PACKUOM2 THEN
            RTRIM(QtyUOMDesc.Description)
         ELSE
            RTRIM(PackageUOMDesc.Description)
      END AS DEL_ORDERDETAIL_UOM_Desc,
      ISNULL(RTRIM(PACK.PackUOM3), '') AS Master_Unit,
      ISNULL(RTRIM(MasterUnit.Description), '') AS Master_Unit_Desc,
      PACK.Qty AS MU_Units,
      ISNULL(RTRIM(PACK.PackUOM2), '') AS Inner_Pack,
      ISNULL(RTRIM(InnerPack.Description), '') AS Inner_Pack_Desc,
      PACK.InnerPack AS Inner_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM1), '') AS Carton,
      ISNULL(RTRIM(Carton.Description), '') AS Carton_Desc,
      PACK.CaseCnt AS Carton_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM4), '') AS Pallet,
      ISNULL(RTRIM(Pallet.Description), '') AS Pallet_Desc,
      PACK.Pallet AS Pallet_UOM_Units,
      PACK.PalletTI AS Units_Per_Layer,
      PACK.PalletHI AS Layers_Per_PL,
      RTRIM(POD.Status) AS POD_Status,
      RTRIM(PODStatus.Description) AS POD_Status_Desc,
      CONVERT(CHAR(8), POD.ActualDeliveryDate,112) + LEFT(CONVERT(CHAR(8), POD.ActualDeliveryDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), POD.ActualDeliveryDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), POD.ActualDeliveryDate, 108),2)
            AS POD_DEliveryDate,
      CONVERT(CHAR(8), MBOL.EditDate,112) + LEFT(CONVERT(CHAR(8), MBOL.EditDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), MBOL.EditDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), MBOL.EditDate, 108),2) AS ORDERS_SHIPPED_DATE,
      CONVERT(CHAR(8), POD.PodReceivedDate,112) + LEFT(CONVERT(CHAR(8), POD.PodReceivedDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), POD.PodReceivedDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), POD.PodReceivedDate, 108),2) AS POD_RETURNED_DATE,
      ISNULL(RTRIM(ORDERS.C_Country),'') AS C_Country,
      ISNULL(RTRIM(SKU.susr4),'') AS Susr4,
      ISNULL(RTRIM(ORDERS.userdefine05), '') AS Userdefine05,
      ISNULL(RTRIM(DEL_ORDERDETAIL.lottable02), '') AS Lottable02,
      CONVERT(CHAR(8), DEL_ORDERDETAIL.Lottable04,112) + LEFT(CONVERT(CHAR(8), DEL_ORDERDETAIL.Lottable04, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), DEL_ORDERDETAIL.Lottable04,108),4,2)
            + RIGHT(CONVERT(CHAR(8), DEL_ORDERDETAIL.Lottable04, 108),2) AS Lottable04,
      ISNULL(RTRIM(ORDERS.Priority), '') AS Priority,
      ISNULL(RTRIM(ORDERS.BuyerPO), '') AS PO_Key,
      ISNULL(RTRIM(SKU.busr10), '') AS Busr10
      FROM ORDERS (NOLOCK)
      JOIN DEL_ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = DEL_ORDERDETAIL.OrderKey)
      JOIN FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)
      JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
      JOIN SKU (NOLOCK) ON (DEL_ORDERDETAIL.StorerKey = SKU.StorerKey AND
                            DEL_ORDERDETAIL.SKU = SKU.SKU )
      JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT OUTER JOIN MBOL (NOLOCK) ON (MBOL.MbolKey = DEL_ORDERDETAIL.MbolKey)
      LEFT OUTER JOIN POD (NOLOCK) ON (ORDERS.OrderKey = POD.OrderKey
                                       AND DEL_ORDERDETAIL.mbolkey = POD.mbolkey
                                       AND DEL_ORDERDETAIL.loadkey = POD.loadkey)
      LEFT OUTER JOIN CODELKUP QtyUOMDesc (NOLOCK)
           ON (QtyUOMDesc.Code = DEL_ORDERDETAIL.UOM AND
               QtyUOMDesc.ListName = 'Quantity')
      LEFT OUTER JOIN CODELKUP PacKageUOMDesc (NOLOCK)
           ON (PacKageUOMDesc.Code = DEL_ORDERDETAIL.UOM AND
               PacKageUOMDesc.ListName = 'Package')
      LEFT OUTER JOIN Codelkup MasterUnit (NOLOCK) ON
            (PACK.PACKUOM3 = MasterUnit.Code AND
             MasterUnit.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup InnerPack (NOLOCK) ON
            (PACK.PACKUOM2 = InnerPack.Code AND
             InnerPack.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup Carton (NOLOCK) ON
            (PACK.PACKUOM1 = Carton.Code AND
             Carton.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Pallet (NOLOCK) ON
            (PACK.PACKUOM4 = Pallet.Code AND
             Pallet.ListName = 'Package')
      LEFT OUTER JOIN Codelkup PODStatus (NOLOCK) ON
            (PODStatus.ListName = 'PODStatus' AND
             PODStatus.Code = POD.Status)
      WHERE ORDERS.EditDate > DATEADD(DAY, -1, GETDATE())

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
   END

   IF @c_Type = 'ORD'
   BEGIN
      TRUNCATE TABLE DTSITF.dbo.TIPSORD

      BEGIN TRAN
      UPDATE TriganticLog WITH (ROWLOCK)
         SET TransmitFlag = '1'
      WHERE TableName = 'ORDERS'
      AND   TransmitFlag = '0'

      INSERT INTO DTSITF.dbo.TIPSORD
         ( CountryCode, Facility, Facility_Desc, Orders_StorerKey, Orders_Company
         , Orders_OrderKey, Order_ExterOrderKey, OrderDetail_OrderLineNumber, OrderDetail_ExternLineNo
         , Orders_OrderDate, Orders_DeliveryDate, Orders_ConsigneeKey, Orders_C_Company
         , Orders_OpenQty, Orders_Status, Orders_Status_Desc, Orders_Type
         , Order_AddDate, Orders_No_Lines, Orders_Principal, Principal_Desc
         , OrderDetail_Sku, Sku_Descr, Sku_Scnd_Lang_Descr, OrderDetail_AtlSku
         , Class, GroupCode, ABC, ItemClass, Classification, ProductGroup
         , OrderDetail_OriginalQty, OrderDetail_ShippedQty, OrderDetail_QtyAllocated, OrderDetail_QtyPicked
         , OrderDetail_UOM, OrderDetail_UOM_Desc, Master_Unit, Master_Unit_Desc
         , MU_Units, Inner_Pack, Inner_Pack_Desc, Inner_UOM_Units
         , Carton, Carton_Desc, Carton_UOM_Units
         , Pallet, Pallet_Desc, Pallet_UOM_Units, Units_Per_Layer, Layers_Per_PL
         , POD_Status, POD_Status_Desc, POD_DeliveryDate, Orders_Shipped_Date, POD_Returned_Date
         , C_Country, Susr4, Userdefine05, Lottable02, Lottable04
         , Priority, PO_Key, Busr10, Route, Route_Desc, TransactionDate
         )
      SELECT DISTINCT
      CAST(ISNULL(RTRIM(@c_CountryCode),'') AS NVARCHAR(3)) AS CountryCode,
      RTRIM(UPPER(CAST(ORDERS.Facility AS NVARCHAR(5)))) AS Facility,
      RTRIM(UPPER(CAST(FACILITY.UserDefine16 AS NVARCHAR(50)))) AS Facility_Desc,
      RTRIM(UPPER(ORDERS.StorerKey)) AS Orders_StorerKey,
      ISNULL(RTRIM(STORER.Company),'') AS Orders_Company,
      ORDERS.OrderKey AS Orders_OrderKey,
      CASE
         WHEN ISNULL(RTRIM(ORDERS.ExternOrderkey),'') = ''
            THEN RTRIM(UPPER(ORDERS.StorerKey)) + RTRIM(UPPER(ORDERS.Type)) + ORDERS.OrderKey
         ELSE
            RTRIM(UPPER(ORDERS.ExternOrderKey))
      END AS Order_ExterOrderKey,
      ORDERDETAIL.OrderLineNumber AS OrderDetail_OrderLineNumber,
      RTRIM(ORDERDETAIL.ExternLineNo) AS ORDERDETAIL_ExternLineNo,
      CONVERT(CHAR(8), ORDERS.OrderDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.OrderDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERS.OrderDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERS.OrderDate, 108),2)
            AS ORDERS_OrderDate,
      CONVERT(CHAR(8), ORDERS.DeliveryDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.DeliveryDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERS.DeliveryDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERS.DeliveryDate, 108),2)
            AS ORDERS_DeliveryDate,
      RTRIM(ORDERS.ConsigneeKey) AS ORDERS_ConsigneeKey,
      ISNULL(RTRIM(ORDERS.C_Company),'') AS ORDERS_C_Company,
      ORDERS.OpenQty AS Orders_OpenQty,
      CASE RTRIM(TRIGANTICLOG.Key2)
         WHEN 'CANC' THEN 'CANC'
         WHEN '0' THEN '0'
         WHEN '1' THEN '1'
         WHEN '2' THEN '2'
         WHEN '3' THEN '3'
         WHEN '4' THEN '4'
         WHEN '5' THEN '5'
         WHEN '6' THEN '6'
         WHEN '9' THEN '9'
         ELSE ''
      END AS Orders_Status,
      CASE RTRIM(TRIGANTICLOG.Key2)
         WHEN '0' THEN '0 - Normal'
         WHEN '1' THEN '1 - Partially Allocated'
         WHEN '2' THEN '2 - Fully Allocated'
         WHEN '3' THEN '3 - In Process'
         WHEN '4' THEN '4 - Pick Slip Printed'
         WHEN '5' THEN '5 - Picked'
         WHEN '6' THEN '6 - Out of Stock'
         WHEN '9' THEN '9 - Shipped'
         WHEN 'CANC' THEN 'Cancelled'
         ELSE ''
      END AS Orders_Status_Desc,
      RTRIM(UPPER(ORDERS.Type)) AS Orders_Type,
      CONVERT(CHAR(8), ORDERS.AddDate,112) + LEFT(CONVERT(CHAR(8), ORDERS.AddDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERS.AddDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERS.AddDate, 108),2)
            AS Order_AddDate,
      (SELECT Count(*) FROM ORDERDETAIL (NOLOCK) WHERE ORDERDETAIL.OrderKey = ORDERS.ORDERKEY)
      AS Orders_No_Lines,
      RTRIM(UPPER(SKU.susr3)) AS Orders_Principal,
      ISNULL(RTRIM(Principal.Description), '') AS Principal_Desc,
      RTRIM(UPPER(ORDERDETAIL.SKU)) AS OrderDetail_SKU,
      ISNULL(RTRIM(CASE WHEN SKU.Descr Like '%?%' THEN
         ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
         ELSE SKU.Descr END),'') AS SKU_Descr,
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60))
      AS SKU_Scnd_Lang_Descr,
      RTRIM(UPPER(ORDERDETAIL.AltSku)) AS OrderDetail_AtlSku,
      RTRIM(SKU.Class) AS Class,
      RTRIM(SKU.SKUGroup) AS GroupCode,
      CASE WHEN RTRIM(SKU.ABC) not in ('A', 'B', 'C')
           THEN 'B' ELSE
      RTRIM(SKU.ABC) END AS ABC,
      RTRIM(SKU.ItemClass) AS ItemClass,
      RTRIM(SKU.BUSR3) AS Classification,
      RTRIM(SKU.BUSR5) AS ProductGroup,
      ORDERDETAIL.OriginalQty AS OrderDetail_OriginalQty,
      CASE RTRIM(TRIGANTICLOG.Key2)
         WHEN '9' THEN ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty
         ELSE 0
      END AS OrderDetail_ShippedQty,
      CASE RTRIM(TRIGANTICLOG.Key2)
         WHEN '9' THEN 0
         ELSE ORDERDETAIL.QtyAllocated
      END AS OrderDetail_QtyAllocated,
      CASE RTRIM(TRIGANTICLOG.Key2)
         WHEN '9' THEN 0
         ELSE ORDERDETAIL.QtyPicked
      END AS OrderDetail_QtyPicked,
      ORDERDETAIL.UOM AS OrderDetail_UOM,
      CASE ORDERDETAIL.UOM
         WHEN PACK.PACKUOM3 THEN
            RTRIM(QtyUOMDesc.Description)
         WHEN PACK.PACKUOM2 THEN
            RTRIM(QtyUOMDesc.Description)
         ELSE
            RTRIM(PackageUOMDesc.Description)
      END  AS OrderDetail_UOM_Desc,
      ISNULL(RTRIM(PACK.PackUOM3), '') AS Master_Unit,
      ISNULL(RTRIM(MasterUnit.Description), '') AS Master_Unit_Desc,
      PACK.Qty AS MU_Units,
      ISNULL(RTRIM(PACK.PackUOM2), '') AS Inner_Pack,
      ISNULL(RTRIM(InnerPack.Description), '') AS Inner_Pack_Desc,
      PACK.InnerPack AS Inner_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM1), '') AS Carton,
      ISNULL(RTRIM(Carton.Description), '') AS Carton_Desc,
      PACK.CaseCnt AS Carton_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM4), '') AS Pallet,
      ISNULL(RTRIM(Pallet.Description), '') AS Pallet_Desc,
      PACK.Pallet AS Pallet_UOM_Units,
      PACK.PalletTI AS Units_Per_Layer,
      PACK.PalletHI AS Layers_Per_PL,
      -- SOS# 169887 - Remove StorerConfig because Trigantic is mandatory for all storers
      --CASE WHEN (SELECT svalue FROM STORERCONFIG (NOLOCK) WHERE CONFIGKEY = 'TIPS_POD'  AND STORERKEY = ORDERS.Storerkey) = '1'
      --     THEN RTRIM(POD.Status)
      --     ELSE NULL END AS POD_Status,
      --CASE WHEN (SELECT svalue FROM STORERCONFIG (NOLOCK) WHERE CONFIGKEY = 'TIPS_POD'  AND STORERKEY = ORDERS.Storerkey) = '1'
      --     THEN RTRIM(PODStatus.Description)
      --     ELSE NULL END AS POD_Status_Desc,
      ISNULL(RTRIM(POD.Status),'') AS POD_Status,
      ISNULL(RTRIM(PODStatus.Description),'') AS POD_Status_Desc,
      CONVERT(CHAR(8), POD.ActualDeliveryDate,112) + LEFT(CONVERT(CHAR(8), POD.ActualDeliveryDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), POD.ActualDeliveryDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), POD.ActualDeliveryDate, 108),2)
            AS POD_DEliveryDate,
      CONVERT(CHAR(8), MBOL.EditDate,112) + LEFT(CONVERT(CHAR(8), MBOL.EditDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), MBOL.EditDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), MBOL.EditDate, 108),2) AS ORDERS_SHIPPED_DATE,
      CONVERT(CHAR(8), POD.PodReceivedDate,112) + LEFT(CONVERT(CHAR(8), POD.PodReceivedDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), POD.PodReceivedDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), POD.PodReceivedDate, 108),2) AS POD_RETURNED_DATE,
      ISNULL(RTRIM(ORDERS.C_Country),'') AS C_Country,
      ISNULL(RTRIM(SKU.susr4),'') AS Susr4,
      ISNULL(RTRIM(ORDERS.userdefine05), '') AS Userdefine05,
      ISNULL(RTRIM(ORDERDETAIL.lottable02), '') AS Lottable02,
      CONVERT(CHAR(8), ORDERDETAIL.Lottable04,112) + LEFT(CONVERT(CHAR(8), ORDERDETAIL.Lottable04, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), ORDERDETAIL.Lottable04,108),4,2)
            + RIGHT(CONVERT(CHAR(8), ORDERDETAIL.Lottable04, 108),2) AS Lottable04,
      ISNULL(RTRIM(ORDERS.Priority), '') AS Priority,
      ISNULL(RTRIM(ORDERS.BuyerPO), '') AS PO_Key,
      ISNULL(RTRIM(SKU.busr10), '') AS Busr10,
      ISNULL(RTRIM(ORDERS.Route), '') AS Route,
      ISNULL(RTRIM(RouteMaster.Descr), '') AS Route_Desc,
      CONVERT(CHAR(8), TRIGANTICLOG.Adddate,112) + LEFT(CONVERT(CHAR(8), TRIGANTICLOG.Adddate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), TRIGANTICLOG.Adddate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), TRIGANTICLOG.Adddate, 108),2) AS TransactionDate
      FROM ORDERS (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
      JOIN FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)
      JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
      JOIN SKU (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND
                            ORDERDETAIL.SKU = SKU.SKU )
      JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT OUTER JOIN MBOL (NOLOCK) ON (MBOL.MbolKey = ORDERDETAIL.MbolKey)
      LEFT OUTER JOIN POD (NOLOCK) ON (ORDERS.OrderKey = POD.OrderKey
                     AND ORDERDETAIL.mbolkey = POD.mbolkey
                     AND ORDERDETAIL.loadkey = POD.loadkey)
      LEFT OUTER JOIN CODELKUP QtyUOMDesc (NOLOCK)
           ON (QtyUOMDesc.Code = ORDERDETAIL.UOM AND
               QtyUOMDesc.ListName = 'Quantity')
      LEFT OUTER JOIN CODELKUP PacKageUOMDesc (NOLOCK)
           ON (PacKageUOMDesc.Code = ORDERDETAIL.UOM AND
               PacKageUOMDesc.ListName = 'Package')
      LEFT OUTER JOIN Codelkup MasterUnit (NOLOCK) ON
            (PACK.PACKUOM3 = MasterUnit.Code AND
             MasterUnit.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup InnerPack (NOLOCK) ON
            (PACK.PACKUOM2 = InnerPack.Code AND
             InnerPack.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup Carton (NOLOCK) ON
            (PACK.PACKUOM1 = Carton.Code AND
             Carton.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Pallet (NOLOCK) ON
            (PACK.PACKUOM4 = Pallet.Code AND
             Pallet.ListName = 'Package')
      LEFT OUTER JOIN Codelkup PODStatus (NOLOCK) ON
            (PODStatus.ListName = 'PODStatus' AND
             PODStatus.Code = POD.Status)
      LEFT OUTER JOIN Codelkup Principal (NOLOCK) ON
            (Principal.ListName = 'PRINCIPAL' AND
             Principal.Code = SKU.susr3)
      LEFT OUTER JOIN RouteMaster (NOLOCK) ON
            (RouteMaster.Route = ORDERS.Route)
      JOIN TRIGANTICLOG (NOLOCK) ON (ORDERS.OrderKey = TRIGANTICLOG.Key1 AND
                                     TRIGANTICLOG.TableName = 'ORDERS' AND
                                     TRIGANTICLOG.TransmitFlag  = '1' )
      WHERE (MBOL.Editdate IS NOT NULL OR ORDERS.Status < '9' OR ORDERS.Status = 'CANC')
      ORDER BY ORDERS.OrderKey, ORDERDETAIL.OrderLineNumber

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
   END

   IF @c_Type = 'REC'
   BEGIN
      TRUNCATE TABLE DTSITF.dbo.TIPSREC

      BEGIN TRAN
      UPDATE TriganticLog WITH (ROWLOCK)
         SET TransmitFlag = '1'
      WHERE TableName = 'RECEIPT'
      AND   TransmitFlag = '0'

      INSERT INTO DTSITF.dbo.TIPSREC
         ( CountryCode, Facility, Receipt_ReceiptKey, Order_ExternReceiptKey, ReceiptDetail_ExternLineNo
         , Receipt_StorerKey, Receipt_Company, Receipt_EditDate, Receipt_DocType, Receipt_No_Lines
         , Receipt_POKey, ReceiptDetail_Sku, ReceiptDetail_AtlSku, Sku_Descr, Sku_Scnd_Lang_Descr
         , Sku_Principal, Principal_Desc, Class, GroupCode, ABC, ItemClass, Classification, ProductGroup
         , RD_DateReceived, RD_QtyExpected, RD_QtyReceived, Master_Unit, Master_Unit_Desc, MU_Units
         , Inner_Pack, Inner_Pack_Desc, Inner_UOM_Units, Carton, Carton_Desc, Carton_UOM_Units
         , Pallet, Pallet_Desc, Pallet_UOM_Units, Units_Per_Layer, Layers_Per_PL
         , Susr4, Receipt_EffectiveDate, WarehouseReference, CarrierKey, CarrierName
         , ReturnReason, VoyageKey, Busr10, Status, Facility_Desc, Reason_Code, Reason_Code_Desc
         )
      SELECT
      CAST(ISNULL(RTRIM(@c_CountryCode),'') AS NVARCHAR(3)) AS CountryCode,
      CAST(RECEIPT.Facility AS NVARCHAR(5)) AS Facility,
      RECEIPT.RECEIPTKEY AS RECEIPT_RECEIPTKEY,
      RECEIPT.ExternReceiptKey AS Order_ExternReceiptKey,
      SPACE(5) AS RECEIPTDETAIL_ExternLineNo,
      RECEIPT.StorerKey AS RECEIPT_StorerKey,
      ISNULL(RTRIM(STORER.Company),'') AS RECEIPT_Company,
      CONVERT(CHAR(8), RECEIPT.EditDate,112) + LEFT(CONVERT(CHAR(8), RECEIPT.EditDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), RECEIPT.EditDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), RECEIPT.EditDate, 108),2)
            AS RECEIPT_EditDate,
      RECEIPT.DocType AS RECEIPT_DocType,
      (SELECT COUNT(DISTINCT (ExternReceiptKey + SKU)) FROM RECEIPTDETAIL (NOLOCK)
       WHERE RECEIPTDETAIL.RECEIPTKEY = RECEIPT.RECEIPTKEY) AS RECEIPT_No_Lines,
      ISNULL(RTRIM(RECEIPT.POKey),'') AS RECEIPT_POKey,
      RECEIPTDETAIL.SKU AS RECEIPTDETAIL_SKU,
      SKU.AltSku AS RECEIPTDETAIL_AtlSku,
      ISNULL(RTRIM( CASE WHEN SKU.Descr LIKE '%?%' THEN
                         ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
                    ELSE SKU.Descr END),'') AS SKU_Descr,
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60)) AS SKU_Scnd_Lang_Descr,
      SKU.sUsr3 AS SKU_Principal,
      Principal.Description Principal_Desc,
      SKU.Class AS Class,
      SKU.SKUGroup AS GroupCode,
      CASE WHEN RTRIM(SKU.ABC) NOT IN ('A', 'B', 'C')
           THEN 'B'
      ELSE RTRIM(SKU.ABC) END AS ABC,
      SKU.ItemClass AS ItemClass,
      SKU.BUSR3 AS Classification,
      SKU.BUSR5 AS ProductGroup,
      CONVERT(CHAR(8), MAX(ReceiptDetail.DateReceived),112)
            + LEFT(CONVERT(CHAR(8), MAX(ReceiptDetail.DateReceived), 108),2)
            + SUBSTRING(CONVERT(CHAR(8), MAX(ReceiptDetail.DateReceived),108),4,2)
            + RIGHT(CONVERT(CHAR(8), MAX(ReceiptDetail.DateReceived), 108),2)
            AS RD_DateReceived,
      SUM(RECEIPTDETAIL.QtyExpected) AS RD_QtyExpected,
      SUM(RECEIPTDETAIL.QtyReceived) AS RD_QtyReceived,
      ISNULL(PACK.PackUOM3, '') AS Master_Unit,
      ISNULL(MasterUnit.Description, '') AS Master_Unit_Desc,
      PACK.Qty AS MU_Units,
      ISNULL(PACK.PackUOM2, '') AS Inner_Pack,
      ISNULL(InnerPack.Description, '') AS Inner_Pack_Desc,
      PACK.InnerPack AS Inner_UOM_Units,
      ISNULL(PACK.PackUOM1, '') AS Carton,
      ISNULL(Carton.Description, '') AS Carton_Desc,
      PACK.CaseCnt AS Carton_UOM_Units,
      ISNULL(PACK.PackUOM4, '') AS Pallet,
      ISNULL(Pallet.Description, '') AS Pallet_Desc,
      PACK.Pallet AS Pallet_UOM_Units,
      PACK.PalletTI AS Units_Per_Layer,
      PACK.PalletHI AS Layers_Per_PL,
      ISNULL(RTRIM(SKU.Susr4), '') AS Susr4,
      CONVERT(CHAR(8), RECEIPT.EffectiveDate,112) + LEFT(CONVERT(CHAR(8), RECEIPT.EffectiveDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), RECEIPT.EffectiveDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), RECEIPT.EffectiveDate, 108),2)
            AS RECEIPT_EffectiveDate,
      ISNULL(RTRIM(RECEIPT.WarehouseReference), '') AS WarehouseReference,
      ISNULL(RTRIM(RECEIPT.CarrierKey), '') AS CarrierKey,
      ISNULL(RTRIM(RECEIPT.CarrierName), '') AS CarrierName,
      ISNULL(RTRIM(RECEIPT.ASNReason), '') AS ReturnReason,
      ISNULL(RTRIM(MAX(RECEIPTDETAIL.VoyageKey)), '') AS VoyageKey,
      ISNULL(RTRIM(SKU.Busr10), '') AS Busr10,
      RECEIPT.Status AS Status,
      RTRIM(UPPER(FACILITY.UserDefine16)) AS Facility_Desc,
      ISNULL(RTRIM(UPPER(RECEIPTDETAIL.SubReasonCode)), '') AS Reason_Code,
      ISNULL(RTRIM(UPPER(Reason.Description)),'') AS Reason_Code_Desc
      FROM RECEIPT (NOLOCK)
      JOIN RECEIPTDETAIL (NOLOCK) ON (RECEIPT.RECEIPTKEY = RECEIPTDETAIL.RECEIPTKEY)
      JOIN FACILITY (NOLOCK) ON (RECEIPT.Facility = FACILITY.Facility)
      JOIN STORER (NOLOCK) ON (RECEIPT.StorerKey = STORER.StorerKey)
      JOIN SKU (NOLOCK) ON (RECEIPTDETAIL.StorerKey = SKU.StorerKey AND
                            RECEIPTDETAIL.SKU = SKU.SKU )
      LEFT OUTER JOIN CODELKUP Principal (NOLOCK) ON (Principal.ListName = 'PRINCIPAL' AND
                                           SKU.SUsr3 = Principal.Code)
      JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT OUTER JOIN Codelkup MasterUnit (NOLOCK) ON
            (PACK.PACKUOM3 = MasterUnit.Code AND
             MasterUnit.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup InnerPack (NOLOCK) ON
            (PACK.PACKUOM2 = InnerPack.Code AND
             InnerPack.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup Carton (NOLOCK) ON
            (PACK.PACKUOM1 = Carton.Code AND
             Carton.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Pallet (NOLOCK) ON
            (PACK.PACKUOM4 = Pallet.Code AND
             Pallet.ListName = 'Package')
      JOIN TRIGANTICLOG (NOLOCK) ON (RECEIPT.RECEIPTKEY = TRIGANTICLOG.Key1 AND
                                     TRIGANTICLOG.TableName = 'RECEIPT' AND
                                     TRIGANTICLOG.TransmitFlag = '1' )
      LEFT OUTER JOIN CODELKUP Reason (NOLOCK) ON (Reason.ListName = 'ASNSubReason' AND
                                                   RECEIPTDETAIL.SubReasonCode = Reason.Code)
      GROUP BY
      RECEIPT.Facility,
      FACILITY.Descr,
      RECEIPT.StorerKey,
      RECEIPT.ExternReceiptKey,
      ISNULL(RTRIM(STORER.Company),''),
      RECEIPT.RECEIPTKEY,
      RECEIPT.EditDate,
      RECEIPT.DocType,
      ISNULL(RTRIM(RECEIPT.POKey),''),
      RECEIPTDETAIL.SKU,
      SKU.AltSku,
      ISNULL(RTRIM( CASE WHEN SKU.Descr LIKE '%?%' THEN
                         ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
                    ELSE SKU.Descr END),''),
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60)),
      SKU.sUsr3,
      Principal.Description,
      SKU.Class,
      SKU.SKUGroup,
      CASE WHEN RTRIM(SKU.ABC) NOT IN ('A', 'B', 'C')
           THEN 'B' ELSE
      RTRIM(SKU.ABC) END,
      SKU.ItemClass,
      SKU.BUSR3,
      SKU.BUSR5,
      ISNULL(PACK.PackUOM3, ''),
      ISNULL(MasterUnit.Description, ''),
      PACK.Qty,
      ISNULL(PACK.PackUOM2, ''),
      ISNULL(InnerPack.Description, ''),
      PACK.InnerPack,
      ISNULL(PACK.PackUOM1, ''),
      ISNULL(Carton.Description, ''),
      PACK.CaseCnt,
      ISNULL(PACK.PackUOM4, ''),
      ISNULL(Pallet.Description, '') ,
      PACK.Pallet,
      PACK.PalletTI,
      PACK.PalletHI,
      ISNULL(RTRIM(SKU.Susr4),''),                           --Leong01
      RECEIPT.EffectiveDate,
      ISNULL(RTRIM(RECEIPT.WarehouseReference),''),          --Leong01
      ISNULL(RTRIM(RECEIPT.CarrierKey), ''),
      ISNULL(RTRIM(RECEIPT.CarrierName), ''),
      ISNULL(RTRIM(RECEIPT.ASNReason),''),                   --Leong01
      ISNULL(RTRIM(SKU.Busr10),''),                          --Leong01
      RECEIPT.Status,
      FACILITY.UserDefine16,
      ISNULL(RTRIM(UPPER(RECEIPTDETAIL.SubReasonCode)), ''), --Leong01
      ISNULL(RTRIM(UPPER(Reason.Description)),'')
      ORDER BY RECEIPT.RECEIPTKEY, RECEIPTDETAIL.SKU

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
   END

   IF @c_Type = 'RHI'
   BEGIN
      TRUNCATE TABLE DTSITF.dbo.TIPSRHI

      BEGIN TRAN
      UPDATE TriganticLog WITH (ROWLOCK)
         SET TransmitFlag = '1'
      WHERE TableName = 'RCPTHIST'
      AND   TransmitFlag = '0'

      INSERT INTO DTSITF.dbo.TIPSRHI
         ( CountryCode, Facility, Receipt_ReceiptKey, Order_ExternReceiptKey, ReceiptDetail_ExternLineNo
         , Receipt_StorerKey, Receipt_Company, Receipt_EditDate, Receipt_DocType, Receipt_No_Lines
         , Receipt_POKey, ReceiptDetail_Sku, ReceiptDetail_AtlSku, Sku_Descr, Sku_Scnd_Lang_Descr
         , Sku_Principal, Principal_Desc, Class, GroupCode, ABC, ItemClass, Classification, ProductGroup
         , RD_DateReceived, RD_QtyExpected, RD_QtyReceived, Master_Unit, Master_Unit_Desc, MU_Units
         , Inner_Pack, Inner_Pack_Desc, Inner_UOM_Units, Carton, Carton_Desc, Carton_UOM_Units
         , Pallet, Pallet_Desc, Pallet_UOM_Units, Units_Per_Layer, Layers_Per_PL
         , Susr4, Receipt_EffectiveDate, WarehouseReference, CarrierKey, CarrierName
         , ReturnReason, VoyageKey, Busr10, Status, Facility_Desc, Reason_Code, Reason_Code_Desc
         )
      SELECT
      CAST(ISNULL(RTRIM(@c_CountryCode),'') AS NVARCHAR(3)) AS CountryCode,
      RTRIM(UPPER(CAST(RECEIPT.Facility AS NVARCHAR(5)))) AS Facility,
      RECEIPT.RECEIPTKEY AS RECEIPT_RECEIPTKEY,
      RTRIM(UPPER(RECEIPT.ExternReceiptKey)) AS Order_ExternReceiptKey,
      SPACE(5) AS RECEIPTDETAIL_ExternLineNo,
      RTRIM(UPPER(RECEIPT.StorerKey)) AS RECEIPT_StorerKey,
      ISNULL(RTRIM(STORER.Company),'') AS RECEIPT_Company,
      CONVERT(CHAR(8), RECEIPT.EditDate,112) + LEFT(CONVERT(CHAR(8), RECEIPT.EditDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), RECEIPT.EditDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), RECEIPT.EditDate, 108),2)
            AS RECEIPT_EditDate,
      RTRIM(UPPER(RECEIPT.DocType)) AS RECEIPT_DocType,
      (SELECT COUNT(DISTINCT (ExternReceiptKey + SKU)) FROM RECEIPTDETAIL (NOLOCK)
       WHERE RECEIPTDETAIL.RECEIPTKEY = RECEIPT.RECEIPTKEY) AS RECEIPT_No_Lines,
      ISNULL(RTRIM(RECEIPT.POKey),'') AS RECEIPT_POKey,
      RTRIM(UPPER(RECEIPTDETAIL.SKU)) AS RECEIPTDETAIL_SKU,
      RTRIM(UPPER(SKU.AltSku)) AS RECEIPTDETAIL_AtlSku,
      ISNULL(RTRIM( CASE WHEN SKU.Descr LIKE '%?%' THEN
                         ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
                    ELSE SKU.Descr END),'') AS SKU_Descr,
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60)) AS SKU_Scnd_Lang_Descr,
      RTRIM(SKU.sUsr3) AS SKU_Principal,
      RTRIM(Principal.Description) Principal_Desc,
      RTRIM(SKU.Class) AS Class,
      RTRIM(SKU.SKUGroup) AS GroupCode,
      CASE WHEN RTRIM(SKU.ABC) NOT IN ('A', 'B', 'C')
           THEN 'B'
      ELSE RTRIM(SKU.ABC) END AS ABC,
      RTRIM(SKU.ItemClass) AS ItemClass,
      RTRIM(SKU.BUSR3) AS Classification,
      RTRIM(SKU.BUSR5) AS ProductGroup,
      CONVERT(CHAR(8), MAX(ReceiptDetail.DateReceived),112)
            + LEFT(CONVERT(CHAR(8), MAX(ReceiptDetail.DateReceived), 108),2)
            + SUBSTRING(CONVERT(CHAR(8), MAX(ReceiptDetail.DateReceived),108),4,2)
            + RIGHT(CONVERT(CHAR(8), MAX(ReceiptDetail.DateReceived), 108),2)
            AS RD_DateReceived,
      SUM(RECEIPTDETAIL.QtyExpected) AS RD_QtyExpected,
      SUM(RECEIPTDETAIL.QtyReceived) AS RD_QtyReceived,
      ISNULL(RTRIM(PACK.PackUOM3), '') AS Master_Unit,
      ISNULL(RTRIM(MasterUnit.Description), '') AS Master_Unit_Desc,
      PACK.Qty AS MU_Units,
      ISNULL(RTRIM(PACK.PackUOM2), '') AS Inner_Pack,
      ISNULL(RTRIM(InnerPack.Description), '') AS Inner_Pack_Desc,
      PACK.InnerPack AS Inner_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM1), '') AS Carton,
      ISNULL(RTRIM(Carton.Description), '') AS Carton_Desc,
      PACK.CaseCnt AS Carton_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM4), '') AS Pallet,
      ISNULL(RTRIM(Pallet.Description), '') AS Pallet_Desc,
      PACK.Pallet AS Pallet_UOM_Units,
      PACK.PalletTI AS Units_Per_Layer,
      PACK.PalletHI AS Layers_Per_PL,
      ISNULL(RTRIM(SKU.Susr4), '') AS Susr4,
      CONVERT(CHAR(8), RECEIPT.EffectiveDate,112) + LEFT(CONVERT(CHAR(8), RECEIPT.EffectiveDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), RECEIPT.EffectiveDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), RECEIPT.EffectiveDate, 108),2)
            AS RECEIPT_EffectiveDate,
      ISNULL(RTRIM(RECEIPT.WarehouseReference), '') AS WarehouseReference,
      ISNULL(RTRIM(RECEIPT.CarrierKey), '') AS CarrierKey,
      ISNULL(RTRIM(RECEIPT.CarrierName), '') AS CarrierName,
      ISNULL(RTRIM(RECEIPT.ASNReason), '') AS ReturnReason,
      ISNULL(RTRIM(MAX(RECEIPTDETAIL.VoyageKey)), '') AS VoyageKey,
      ISNULL(RTRIM(SKU.Busr10), '') AS Busr10,
      RECEIPT.Status AS Status,
      RTRIM(UPPER(FACILITY.UserDefine16)) AS Facility_Desc,
      ISNULL(RTRIM(UPPER(RECEIPTDETAIL.SubReasonCode)), '') AS Reason_Code,
      ISNULL(RTRIM(UPPER(Reason.Description)),'') AS Reason_Code_Desc
      FROM RECEIPT WITH (NOLOCK)
      JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPT.RECEIPTKEY = RECEIPTDETAIL.RECEIPTKEY)
      JOIN FACILITY WITH (NOLOCK) ON (RECEIPT.Facility = FACILITY.Facility)
      JOIN STORER WITH (NOLOCK) ON (RECEIPT.StorerKey = STORER.StorerKey)
      JOIN SKU WITH (NOLOCK) ON (RECEIPTDETAIL.StorerKey = SKU.StorerKey AND
                                 RECEIPTDETAIL.SKU = SKU.SKU )
      LEFT OUTER JOIN CODELKUP Principal WITH (NOLOCK) ON (Principal.ListName = 'PRINCIPAL' AND
                         SKU.Susr3 = Principal.Code)
      JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT OUTER JOIN Codelkup MasterUnit WITH (NOLOCK) ON
            (PACK.PACKUOM3 = MasterUnit.Code AND
             MasterUnit.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup InnerPack WITH (NOLOCK) ON
            (PACK.PACKUOM2 = InnerPack.Code AND
             InnerPack.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup Carton WITH (NOLOCK) ON
            (PACK.PACKUOM1 = Carton.Code AND
             Carton.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Pallet WITH (NOLOCK) ON
            (PACK.PACKUOM4 = Pallet.Code AND
             Pallet.ListName = 'Package')
      JOIN TRIGANTICLOG WITH (NOLOCK) ON (RECEIPT.RECEIPTKEY = TRIGANTICLOG.Key1 AND
                                          TRIGANTICLOG.TableName = 'RCPTHIST' AND
                                          TRIGANTICLOG.TransmitFlag = '1')
      LEFT OUTER JOIN CODELKUP Reason WITH (NOLOCK) ON (Reason.ListName = 'ASNSubReason' AND
                                                        RECEIPTDETAIL.SubReasonCode = Reason.Code)
      GROUP BY
      RECEIPT.Facility,
      RECEIPT.StorerKey,
      RECEIPT.ExternReceiptKey,
      ISNULL(RTRIM(STORER.Company),''),
      RECEIPT.RECEIPTKEY,
      RECEIPT.EditDate,
      RECEIPT.DocType,
      ISNULL(RTRIM(RECEIPT.POKey),''),
      RECEIPTDETAIL.SKU,
      SKU.AltSku,
      ISNULL(RTRIM( CASE WHEN SKU.Descr LIKE '%?%' THEN
                         ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
                    ELSE SKU.Descr END),''),
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60)),
      SKU.Susr3,
      Principal.Description,
      SKU.Class,
      SKU.SKUGroup,
      SKU.ABC,
      SKU.ItemClass,
      SKU.BUSR3,
      SKU.BUSR5,
      ISNULL(RTRIM(PACK.PackUOM3), ''),
      ISNULL(RTRIM(MasterUnit.Description), ''),
      PACK.Qty,
      ISNULL(RTRIM(PACK.PackUOM2), ''),
      ISNULL(RTRIM(InnerPack.Description), ''),
      PACK.InnerPack,
      ISNULL(RTRIM(PACK.PackUOM1), ''),
      ISNULL(RTRIM(Carton.Description), ''),
      PACK.CaseCnt,
      ISNULL(RTRIM(PACK.PackUOM4), ''),
      ISNULL(RTRIM(Pallet.Description), '') ,
      PACK.Pallet,
      PACK.PalletTI,
      PACK.PalletHI,
      SKU.Susr4,
      RECEIPT.EffectiveDate,
      RECEIPT.WarehouseReference,
      ISNULL(RTRIM(RECEIPT.CarrierKey), ''),
      ISNULL(RTRIM(RECEIPT.CarrierName), ''),
      RECEIPT.ASNReason,
      SKU.Busr10,
      RECEIPT.Status,
      FACILITY.UserDefine16,
      RECEIPTDETAIL.SubReasonCode,
      ISNULL(RTRIM(UPPER(Reason.Description)),'')
      ORDER BY RECEIPT.RECEIPTKEY, RECEIPTDETAIL.SKU

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
   END

   IF @c_Type = 'CCN'
   BEGIN
      TRUNCATE TABLE DTSITF.dbo.TIPSCCN

      BEGIN TRAN
      UPDATE TriganticLog WITH (ROWLOCK)
         SET TransmitFlag = '1'
      WHERE TableName IN ('CCOUNT', 'CCADJ')
      AND   TransmitFlag = '0'

      EXEC ispGenTriganticCC

      INSERT INTO DTSITF.dbo.TIPSCCN
         ( CountryCode, Facility, StorerKey, Company, Sku, AtlSku, Sku_Descr, Sku_Scnd_Lang_Descr
         , Class, GroupCode, ABC, ItemClass, Classification, ProductGroup, CountDate, Qty_Before, Qty_After
         , Master_Unit, Master_Unit_Desc, MU_Units, Inner_Pack, Inner_Pack_Desc, Inner_UOM_Units
         , Carton, Carton_Desc, Carton_UOM_Units, Pallet, Pallet_Desc, Pallet_UOM_Units
         , Units_Per_Layer, Layers_Per_PL, Busr10, Facility_Desc, AgencyCode, AdjCode, AdjCodeDesc, AdjType
         )
      SELECT
      CAST(ISNULL(RTRIM(@c_CountryCode),'') AS NVARCHAR(3)) AS CountryCode,
      CAST(TriganticCC.Facility AS NVARCHAR(5)) AS Facility,
      RTRIM(UPPER(TriganticCC.StorerKey)) AS StorerKey,
      ISNULL(RTRIM(UPPER(STORER.Company)),'') AS Company,
      RTRIM(UPPER(TriganticCC.SKU)) AS SKU,
      RTRIM(UPPER(SKU.AltSku)) AS AtlSku,
      ISNULL(RTRIM( CASE WHEN SKU.Descr Like '%?%' THEN
                         ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '')
                    ELSE SKU.Descr END),'') AS SKU_Descr,
      CAST(ISNULL(RTRIM(LTRIM(SKU.BUSR1)), '') + ISNULL(RTRIM(LTRIM(SKU.BUSR2)), '') AS NVARCHAR(60)) AS SKU_Scnd_Lang_Descr,
      RTRIM(SKU.Class) AS Class,
      RTRIM(SKU.SKUGroup) AS GroupCode,
      CASE WHEN RTRIM(SKU.ABC) not in ('A', 'B', 'C')
           THEN 'B' ELSE RTRIM(SKU.ABC)
      END AS ABC,
      RTRIM(SKU.ItemClass) AS ItemClass,
      RTRIM(SKU.BUSR3) AS Classification,
      RTRIM(SKU.BUSR5) AS ProductGroup,
      CONVERT(CHAR(8), TriganticCC.AddDate,112) + LEFT(CONVERT(CHAR(8), TriganticCC.AddDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), TriganticCC.AddDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), TriganticCC.AddDate, 108),2)
            AS CountDate,
      TriganticCC.Qty_Before,
      TriganticCC.Qty_After,
      ISNULL(RTRIM(PACK.PackUOM3), '') AS Master_Unit,
      ISNULL(RTRIM(MasterUnit.Description), '') AS Master_Unit_Desc,
      PACK.Qty AS MU_Units,
      ISNULL(RTRIM(PACK.PackUOM2), '') AS Inner_Pack,
      ISNULL(RTRIM(InnerPack.Description), '') AS Inner_Pack_Desc,
      PACK.InnerPack AS Inner_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM1), '') AS Carton,
      ISNULL(RTRIM(Carton.Description), '') AS Carton_Desc,
      PACK.CaseCnt AS Carton_UOM_Units,
      ISNULL(RTRIM(PACK.PackUOM4), '') AS Pallet,
      ISNULL(RTRIM(Pallet.Description), '') AS Pallet_Desc,
      PACK.Pallet AS Pallet_UOM_Units,
      PACK.PalletTI AS Units_Per_Layer,
      PACK.PalletHI AS Layers_Per_PL,
      ISNULL(RTRIM(SKU.busr10), '') AS Busr10,
      RTRIM(UPPER(FACILITY.UserDefine16)) AS Facility_Desc,
      ISNULL(RTRIM(SKU.SUSR3), '') AS AgencyCode,
      TriganticCC.AdjCode,
      TriganticCC.AdjCodeDesc,
      TriganticCC.AdjType
      FROM TriganticCC WITH (NOLOCK)
      JOIN FACILITY WITH (NOLOCK) ON (TriganticCC.Facility = FACILITY.Facility)
      JOIN STORER WITH (NOLOCK) ON (STORER.StorerKey = TriganticCC.StorerKey)
      JOIN SKU WITH (NOLOCK) ON (TriganticCC.StorerKey = SKU.StorerKey AND
                            TriganticCC.SKU = SKU.SKU )
      JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT OUTER JOIN Codelkup MasterUnit WITH (NOLOCK) ON
            (PACK.PACKUOM3 = MasterUnit.Code AND
             MasterUnit.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup InnerPack WITH (NOLOCK) ON
            (PACK.PACKUOM2 = InnerPack.Code AND
             InnerPack.ListName = 'Quantity')
      LEFT OUTER JOIN Codelkup Carton WITH (NOLOCK) ON
            (PACK.PACKUOM1 = Carton.Code AND
             Carton.ListName = 'Package')
      LEFT OUTER JOIN Codelkup Pallet WITH (NOLOCK) ON
            (PACK.PACKUOM4 = Pallet.Code AND
             Pallet.ListName = 'Package')
      ORDER BY
      CONVERT(CHAR(8), TriganticCC.AddDate,112) + LEFT(CONVERT(CHAR(8), TriganticCC.AddDate, 108),2)
            + SUBSTRING(CONVERT(CHAR(8), TriganticCC.AddDate,108),4,2)
            + RIGHT(CONVERT(CHAR(8), TriganticCC.AddDate, 108),2),
      TriganticCC.Facility,
      TriganticCC.StorerKey,
      TriganticCC.SKU

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
   END

END --End Proc

GO