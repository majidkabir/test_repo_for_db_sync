SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_DeliveryOrder06                                 */
/* Creation Date: 30-Jan-2013                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  SOS#268254-Nike_DeliveryNote (MY/SG/TW)                    */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_delivery_Order_06                  */
/*                                                                      */
/* Called By: Exceed                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 9 May 2013   TLTING01 1.1  Miss datatype Nvarchar                    */
/* 14-May-2013  Audrey   1.2  SOS277376 -Bug fixed             (ang01)  */
/* 10-Jun-2013  NJOW01   1.3  280485-Modify Delivery Note RCM Report    */
/* 27-Jun-2013  NJOW02   1.4  Fix carton count                          */
/* 04-Sep-2013  Audrey   1.5  SOS#288806 - Logic fixed         (ang02)  */  
/************************************************************************/

CREATE PROC [dbo].[isp_DeliveryOrder06]
      (@c_MBOLKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Cnt                INT
         , @c_Loadkey            NVARCHAR(10)
         , @c_ExternOrderkey     NVARCHAR(30)
         , @c_Consigneekey       NVARCHAR(15)
         , @c_C_Company          NVARCHAR(45)
         , @c_C_Address1         NVARCHAR(45)
         , @c_C_Address2         NVARCHAR(45)
         , @c_C_Address3         NVARCHAR(45)
         , @c_C_Address4         NVARCHAR(45)
         , @c_C_City             NVARCHAR(45)
         , @c_C_Zip              NVARCHAR(18)
         , @c_AllNotes           NVARCHAR(4000)
         , @c_Notes              NVARCHAR(4000)
         , @c_Notes1             NVARCHAR(254)
         , @c_Notes2             NVARCHAR(254)
         , @dt_EditDate          DATETIME
         , @dt_DepartureDate     DATETIME
         , @c_Userdefine10       NVARCHAR(20)      -- tlting01
         , @dt_DeliveryDate      DATETIME  --NJOW01
         , @c_Stop               NVARCHAR(10)  --NJOW01
         , @c_ExternPOKey        NVARCHAR(20) --NJOW01
         , @c_Route              NVARCHAR(10) --NJOW01

   DECLARE @c_Model              NVARCHAR(10)
         , @c_SkuDesc            NVARCHAR(60)
         , @c_UOM                NVARCHAR(10)
         , @n_CtnCnt1            INT
         , @n_Qty                INT

   DECLARE @c_PrevConsigneekey   NVARCHAR(15)
         , @c_PrevNotes          NVARCHAR(4000)

   SET @c_Loadkey          = ''
   SET @c_ExternOrderkey   = ''
   SET @c_Consigneekey     = ''
   SET @c_C_Company        = ''
   SET @c_C_Address1       = ''
   SET @c_C_Address2       = ''
   SET @c_C_Address3       = ''
   SET @c_C_Address4       = ''
   SET @c_C_City           = ''
   SET @c_C_Zip            = ''
   SET @c_AllNotes         = ''
   SET @c_Notes            = ''
   SET @c_Notes1           = ''
   SET @c_Notes2           = ''
   SET @dt_EditDate        = ''
   SET @dt_DepartureDate   = ''
   SET @c_Userdefine10     = ''


   SET @c_Model            = ''
   SET @c_SkuDesc          = ''
   SET @c_UOM              = ''
   SET @n_CtnCnt1          = 0
   SET @n_Qty              = 0

   SET @c_PrevConsigneekey = ''
   SET @c_PrevNotes        = ''


   CREATE TABLE #TMP_DELVY
   (  MBOLKey           NVARCHAR(10)
   ,  LoadKey           NVARCHAR(10)
   ,  DepartureDate     DATETIME
   ,  UserDefine10      NVARCHAR(20)
   ,  ExternOrderkey    NVARCHAR(30)
   ,  Consigneekey      NVARCHAR(15)
   ,  C_Company         NVARCHAR(45)
   ,  C_Address1        NVARCHAR(45)
   ,  C_Address2        NVARCHAR(45)
   ,  C_Address3        NVARCHAR(45)
   ,  C_Address4        NVARCHAR(45)
   ,  C_City            NVARCHAR(45)
   ,  C_Zip             NVARCHAR(18)
   ,  Notes1            NVARCHAR(255)
   ,  Notes2            NVARCHAR(255)
   ,  Model             NVARCHAR(10)
   ,  SkuDesc           NVARCHAR(60)
   ,  UOM               NVARCHAR(10)
   ,  CtnCnt1           INT
   ,  Qty               INT
   ,  DeliveryDate      DATETIME   --NJOW01
   ,  Stop              NVARCHAR(10)  --NJOW01
   ,  ExternPOkey       NVARCHAR(20)  --NJOW01
   ,  Route             NVARCHAR(10))  --NJOW01

   DECLARE ORD_CUR CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT Loadkey       = ISNULL(RTRIM(ORDERS.Loadkey),'')
         ,ExternOrderkey= ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,Consigneekey  = ISNULL(RTRIM(ORDERS.Consigneekey),'')
         ,C_Company     = ISNULL(RTRIM(ORDERS.C_Company),'')
         ,C_Address1    = ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,C_Address2    = ISNULL(RTRIM(ORDERS.C_Address2),'')
         ,C_Address3    = ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,C_Address4    = ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,C_City        = ISNULL(RTRIM(ORDERS.C_City),'')
         ,C_Zip         = ISNULL(RTRIM(ORDERS.C_Zip),'')
         ,Notes         = ISNULL(CONVERT(NVARCHAR(4000),ORDERS.Notes),'')
         ,EditDate      = MAX(ORDERS.EditDate)  --NJOW01
         ,DepartureDate = MBOL.DepartureDate
         ,UserDefine10  = CASE WHEN ISNULL(RTRIM(MBOL.UserDefine10),'') = '' THEN '1' ELSE ISNULL(RTRIM(MBOL.UserDefine10),'') END
         ,MBOLKey       = MBOL.MBOLKey
         ,Model         = SUBSTRING(ISNULL(RTRIM(SKU.BUSR10),''),1,10)
         ,SkuDesc       = ISNULL(RTRIM(SKU.Descr),'')
         ,UOM           = MIN(ISNULL(RTRIM(ORDERDETAIL.UOM),''))
         --,CtnCnt1       = ISNULL(SUM(PACKHEADER.CtnCnt1),0)
         --,CtnCnt1       = (SELECT ISNULL(SUM(PACKHEADER.CtnCnt1),0) --ang01 start
         --                 FROM PACKHEADER WITH (NOLOCK)
         --                 where  (Orders.Consigneekey = Packheader.Consigneekey
         --                 AND orders.loadkey = Packheader.loadkey))--ang01 End
         ,CtnCnt1 = (SELECT COUNT(DISTINCT PD.DropID)
                          FROM PACKHEADER PH (NOLOCK)
                          JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
                          JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
                          where Orders.Consigneekey = O.Consigneekey
                          AND orders.loadkey = O.loadkey
                          AND MBOL.Mbolkey = O.Mbolkey
                          AND Orders.Stop = O.Stop
                          AND convert(datetime,convert(nvarchar(10),Orders.Deliverydate,112)) = convert(datetime,convert(nvarchar(10),O.Deliverydate,112))
                          AND LEFT(Orders.ExternPOKey,10) = LEFT(O.ExternPOKey,10)) --NJOW01/02
         ,Qty           = ISNULL(SUM(PACKDETAIL.Qty),0)
         ,DeliveryDate  = convert(datetime,convert(nvarchar(10),ORDERS.Deliverydate,112)) --NJOW01
         ,ORDERS.Stop  --NJOW01
         ,ExternPOkey = LEFT(ORDERS.ExternPOKey,10) --NJOW01
         ,ORDERS.Route --NJOW01
   FROM MBOL        WITH (NOLOCK)
   JOIN MBOLDETAIL  WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
   --JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey) (ang02)
   JOIN (
      SELECT DISTINCT OrderKey, StorerKey, UOM, Sku
      FROM ORDERDETAIL WITH (NOLOCK)
      WHERE MBOLKey = @c_MBOLKey
     ) AS ORDERDETAIL
   ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey) --(ang02)
   JOIN PACKHEADER  WITH (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)
   JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
                                  AND(ORDERDETAIL.Storerkey = PACKDETAIL.Storerkey)
                                  AND(ORDERDETAIL.Sku       = PACKDETAIL.Sku)
   JOIN SKU         WITH (NOLOCK) ON (PACKDETAIL.Storerkey  = SKU.Storerkey)
                                  AND(PACKDETAIL.Sku        = SKU.Sku)
   WHERE MBOL.MBOLKey = @c_MBOLKey
   GROUP BY ISNULL(RTRIM(ORDERS.Loadkey),'')
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(ORDERS.Consigneekey),'')
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address2),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,  ISNULL(RTRIM(ORDERS.C_City),'')
         ,  ISNULL(RTRIM(ORDERS.C_Zip),'')
         ,  ISNULL(CONVERT(NVARCHAR(4000),ORDERS.Notes),'')
        -- ,  ORDERS.EditDate  --NJOW01
	       ,  ORDERS.Consigneekey --ang01
         ,  ORDERS.Loadkey --ang01	
         ,  MBOL.DepartureDate
         ,  CASE WHEN ISNULL(RTRIM(MBOL.UserDefine10),'') = '' THEN '1' ELSE ISNULL(RTRIM(MBOL.UserDefine10),'') END
         ,  MBOL.MBOLKey
         ,  SUBSTRING(ISNULL(RTRIM(SKU.BUSR10),''),1,10)
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  convert(datetime,convert(nvarchar(10),ORDERS.Deliverydate,112)) --NJOW01
         ,  ORDERS.Stop  --NJOW01
         ,  LEFT(ORDERS.ExternPOKey,10) --NJOW01
         ,  ORDERS.Route --NJOW01
   ORDER BY ISNULL(RTRIM(ORDERS.Consigneekey),'')
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(CONVERT(NVARCHAR(4000),ORDERS.Notes),'')

   OPEN ORD_CUR
   FETCH NEXT FROM ORD_CUR INTO @c_Loadkey
                              , @c_ExternOrderkey
                              , @c_Consigneekey
                              , @c_C_Company
                              , @c_C_Address1
                              , @c_C_Address2
                              , @c_C_Address3
                              , @c_C_Address4
                              , @c_C_City
                              , @c_C_Zip
                              , @c_Notes
                              , @dt_EditDate
                              , @dt_DepartureDate
                              , @c_UserDefine10
                              , @c_MBOLKey
                              , @c_Model
                              , @c_SkuDesc
                              , @c_UOM
                              , @n_CtnCnt1
                              , @n_Qty
                              , @dt_deliverydate --NJOW01
                              , @c_Stop --NJOW01,
                              , @c_ExternPOkey --NJOW01
                              , @c_Route --NJOW01

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF CONVERT(NVARCHAR(8), @dt_DepartureDate, 112) = '19000101'
      BEGIN
         SET @dt_DepartureDate = @dt_EditDate
      END

      IF @c_Notes <> @c_PrevNotes AND LEN(@c_Notes) > 0
      BEGIN
         SET @c_AllNotes = @c_AllNotes + @c_Notes + ' '
      END

      INSERT INTO #TMP_DELVY (MBOLKey, Loadkey, DepartureDate, UserDefine10, ExternOrderkey, Consigneekey, C_Company
                             ,C_Address1, C_Address2, C_Address3, C_Address4, C_City, C_Zip, Notes1, Notes2
                             ,Model, SkuDesc, UOM, CtnCnt1, Qty, DeliveryDate, Stop, ExternPOKey, Route)  --NJOW01

      VALUES (@c_MBOLKey, @c_Loadkey, @dt_DepartureDate, @c_UserDefine10, @c_ExternOrderkey, @c_Consigneekey, @c_C_Company
              ,@c_C_Address1, @c_C_Address2, @c_C_Address3, @c_C_Address4, @c_C_City, @c_C_Zip, '', ''
              ,@c_Model, @c_SkuDesc, @c_UOM, @n_CtnCnt1, @n_Qty, @dt_DeliveryDate, @c_Stop, @c_ExternPOKey, @c_Route)  --NJOW01

      SET @c_PrevConsigneekey = @c_Consigneekey
      SET @c_PrevNotes = @c_Notes

      FETCH NEXT FROM ORD_CUR INTO @c_Loadkey
                                 , @c_ExternOrderkey
                                 , @c_Consigneekey
                                 , @c_C_Company
                                 , @c_C_Address1
                                 , @c_C_Address2
                                 , @c_C_Address3
                                 , @c_C_Address4
                                 , @c_C_City
                                 , @c_C_Zip
                                 , @c_Notes
                                 , @dt_EditDate
                                 , @dt_DepartureDate
                                 , @c_UserDefine10
                                 , @c_MBOLKey
                                 , @c_Model
                                 , @c_SkuDesc
                                 , @c_UOM
                                 , @n_CtnCnt1
                                 , @n_Qty
                                 , @dt_deliverydate --NJOW01
                                 , @c_Stop --NJOW01,
                                 , @c_ExternPOkey --NJOW01
                                 , @c_Route --NJOW01

      IF @c_Consigneekey <> @c_PrevConsigneekey OR
         @@FETCH_STATUS = -1
      BEGIN

         SET @c_Notes1 = SUBSTRING(@c_AllNotes, 1,   254)
         SET @c_Notes2 = SUBSTRING(@c_AllNotes, 255, 254)

         UPDATE #TMP_DELVY
         SET Notes1 = @c_Notes1
            ,Notes2 = @c_Notes2
         WHERE Consigneekey = @c_PrevConsigneekey

         SET @c_AllNotes = ''
      END
   END
   CLOSE ORD_CUR
   DEALLOCATE ORD_CUR

   SELECT   MBOLKey
         ,  LoadKey
         ,  DepartureDate
         ,  UserDefine10
         ,  ExternOrderkey
         ,  Consigneekey
         ,  C_Company
         ,  C_Address1
         ,  C_Address2
         ,  C_Address3
         ,  C_Address4
         ,  C_City
         ,  C_Zip
         ,  Notes1
         ,  Notes2
         ,  Model
         ,  SkuDesc
         ,  UOM
         ,  CtnCnt1
         ,  Qty
         ,  DeliveryDate  --NJOW01
         ,  Stop  --NJOW01
         ,  ExternPOKey  --NJOW01
         ,  Route --NJOW01

   FROM #TMP_DELVY

   DROP TABLE #TMP_DELVY
END

GO