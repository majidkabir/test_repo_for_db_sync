SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_DeliveryOrder08                                 */
/* Creation Date: 24-JUL-2018                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-5779-WMS-5779-[MY]- Adidas Ã»Delivery Note Report       */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_delivery_Order_08                  */
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
/* 2018-07-31   JunYan  v1.1  Updated FBR v1.4 CR (CJY01)               */
/* 2018-08-02   JunYan  v1.2  Updated FBR v1.5 CR (CJY02)               */
/* 2018-08-08   JunYan  v1.3  Updated FBR v1.6 CR (CJY03)               */
/* 2018-08-23   JunYan  v1.4  Updated FBR v1.9 CR (CJY04)               */
/* 2018-09-07   CSCHONG v1.5  revised report field logic (CS01)         */
/* 2018-11-16   CSCHONG v1.6  INC0472156 - fix qty issue (CS02)         */
/************************************************************************/

CREATE PROC [dbo].[isp_DeliveryOrder08]
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
         , @c_C_State            NVARCHAR(45)   -- CJY01
         , @c_C_Country          NVARCHAR(30)   -- CJY01
         , @c_SSTYLE             NVARCHAR(20)
         , @dt_EditDate          DATETIME
         , @dt_DepartureDate     DATETIME
         , @c_Userdefine02       NVARCHAR(20)
         , @dt_DeliveryDate      DATETIME
    --   , @c_BuyerPO            NVARCHAR(20)
         , @c_BuyerPO            NVARCHAR(45)   -- CJY04
         , @c_ExternPOKey        NVARCHAR(20)
         , @dt_UserDefine10      DATETIME       -- CJY01
         , @c_Billtokey          NVARCHAR(20)
         , @c_B_Company          NVARCHAR(45)
         , @c_B_Address1         NVARCHAR(45)
         , @c_B_Address2         NVARCHAR(45)
         , @c_B_Address3         NVARCHAR(45)
         , @c_B_Address4         NVARCHAR(45)
         , @c_B_City             NVARCHAR(45)
         , @c_B_Zip              NVARCHAR(18)
         , @c_B_State            NVARCHAR(45)   -- CJY01
         , @c_B_Country          NVARCHAR(30)   -- CJY01
         , @c_ST_Company         NVARCHAR(45)
         , @c_ST_Address1        NVARCHAR(45)
         , @c_ST_Address2        NVARCHAR(45)
         , @c_ST_Address3        NVARCHAR(45)
         , @c_ST_Address4      NVARCHAR(45)
         , @c_ST_Phone1          NVARCHAR(45)
         , @c_ST_Fax1            NVARCHAR(18)
         , @c_ST_VAT             NVARCHAR(18)

         , @C_RPTCode             NVARCHAR(20)
         , @c_RPTCopyname         NVARCHAR(150)
         , @c_OHNotes             NVARCHAR(250)
         , @c_SizeCnt             INT
   , @C_PreRPTCode          NVARCHAR(20)

   DECLARE @dt_OHRDD             DATETIME
         , @c_SkuDesc            NVARCHAR(60)
         , @c_UOM                NVARCHAR(10)
         , @n_TTLCTN             INT
         , @n_Qty                INT
         , @n_UnitPrice          FLOAT

   DECLARE @c_PrevConsigneekey   NVARCHAR(15)
         , @c_PrevNotes          NVARCHAR(4000)
         , @c_VATLblText         NVARCHAR(10)    -- CJY02
   , @c_GMbolkey           NVARCHAR(10)    -- CS01 --start
         , @c_GUserdefine02      NVARCHAR(20)
   , @c_GSTYLE             NVARCHAR(20)
   , @c_GSizeQty           NVARCHAR(50)
   , @c_CGSizeQty          NVARCHAR(250)
   , @n_RecCnt             INT
   , @c_Gsorting           NVARCHAR(150)
   , @n_lineNum            INT
   , @c_GPreSTYLE          NVARCHAR(20)
   , @n_TTLLine            INT
   , @n_MaxSizeLine        INT
   , @n_recgrp             INT
   , @n_pageno             INT
   , @c_PreExtOrdKey       NVARCHAR(30)
   , @c_line               NVARCHAR(1)
   , @n_maxlinenumber      INT
   , @n_MaxLine            INT               -- CS01 --End
   , @c_GUserdefine03      NVARCHAR(20)      -- CS01
     , @c_GUserdefine04      NVARCHAR(20)      -- CS01


   SET @c_ExternOrderkey   = ''
   SET @c_C_Company        = ''
   SET @c_C_Address1       = ''
   SET @c_C_Address2       = ''
   SET @c_C_Address3       = ''
   SET @c_C_Address4       = ''
   SET @c_C_City           = ''
   SET @c_C_Zip            = ''
   SET @c_C_State          = ''  -- CJY01
   SET @c_C_Country        = ''  -- CJY01
   SET @c_Consigneekey     = ''  -- CJY02
 SET @n_recgrp           = 1   -- CS01
 SET @n_MaxLine          = 1   -- CS01

   SET @dt_EditDate        = ''
   SET @dt_DepartureDate   = ''

   SET @c_SkuDesc          = ''
   SET @c_UOM              = ''
   SET @n_TTLCTN           = 0
   SET @n_Qty              = 0

   SET @c_PrevConsigneekey = ''
   SET @c_PrevNotes        = ''
 SET @n_RecCnt           = 1     -- CS01
 SET @n_MaxSizeLine      = 5     -- CS01
 SET @C_PreRPTCode       = ''    -- CS01
 SET @c_PreExtOrdKey     = ''    -- CS01
 SET @c_line             = 'N'   -- CS01

   CREATE TABLE #TMP_DELNote08
   (  MBOLKey           NVARCHAR(10)
 --,  LoadKey           NVARCHAR(10)
   ,  DepartureDate     DATETIME
   ,  UserDefine02      NVARCHAR(20)
   ,  ExternOrderkey    NVARCHAR(30)
   ,  Billtokey         NVARCHAR(15)
   ,  C_Company         NVARCHAR(45)
   ,  C_Address1        NVARCHAR(45)
   ,  C_Address2        NVARCHAR(45)
   ,  C_Address3        NVARCHAR(45)
   ,  C_Address4        NVARCHAR(45)
   ,  C_City            NVARCHAR(45)
   ,  C_Zip             NVARCHAR(18)
   ,  C_State           NVARCHAR(45)   -- CJY01
   ,  C_Country         NVARCHAR(30)   -- CJY01
-- ,  BuyerPO           NVARCHAR(20)
   ,  BuyerPO           NVARCHAR(45)   -- CJY04
   ,  UserDefine10      DATETIME NULL  -- CJY01
   ,  OHRDD             DATETIME NULL
   ,  SkuDesc           NVARCHAR(60)
   ,  UOM               NVARCHAR(10)
   ,  TTLCTN            INT
   ,  Qty               INT
   ,  DeliveryDate      DATETIME
   ,  SSTYLE          NVARCHAR(10)
   ,  UnitPrice         FLOAT
   ,  ST_Company        NVARCHAR(45)
   ,  ST_Address1       NVARCHAR(45)
   ,  ST_Address2       NVARCHAR(45)
   ,  ST_Address3       NVARCHAR(45)
   ,  ST_Address4       NVARCHAR(45)
   ,  ST_Phone1         NVARCHAR(18)
   ,  ST_Fax1           NVARCHAR(18)
   ,  ST_VAT            NVARCHAR(18)
   ,  B_Company         NVARCHAR(45)
   ,  B_Address1        NVARCHAR(45)
   ,  B_Address2        NVARCHAR(45)
   ,  B_Address3        NVARCHAR(45)
   ,  B_Address4        NVARCHAR(45)
   ,  B_City            NVARCHAR(45)
   ,  B_Zip             NVARCHAR(18)
   ,  B_State           NVARCHAR(45)  -- CJY01
   ,  B_Country         NVARCHAR(30)  -- CJY01
   ,  copycode          NVARCHAR(10)
   ,  copyname          NVARCHAR(150)
   ,  OHNotes           NVARCHAR(250)
   ,  SizeCnt           INT
   ,  ConsigneeKey      NVARCHAR(15) -- CJY02
   ,  VATLblText        NVARCHAR(10) -- CJY02
 ,  SizeQty           NVARCHAR(250) NULL --CS
 ,  LineNum           INT             -- CS01 --Start
 ,  RecGrp            INT
 ,  Pageno            INT
 ,  DrawLine          NVARCHAR(1)      -- CS01  -- End
 )

 -- CS01 Start
 CREATE TABLE #TMP_DELNote08Size (
     RowNo             INT IDENTITY(1,1)
  ,  MBOLKey           NVARCHAR(10)  NULL
  ,  UserDefine02      NVARCHAR(20)  NULL
  ,  SSTYLE            NVARCHAR(10)  NULL
  ,  SizeQty           NVARCHAR(250) NULL
  ,  RecLineNo         INT

 )
 -- CS01 End

   DECLARE C_ORDLINE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT ExternOrderkey= ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
       ,UserDefine02  = ISNULL(RTRIM(ORDERDETAIL.UserDefine02),'')
         ,C_Company     = ISNULL(RTRIM(ORDERS.C_Company),'')
         ,C_Address1    = ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,C_Address2    = ISNULL(RTRIM(ORDERS.C_Address2),'')
         ,C_Address3    = ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,C_Address4    = ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,C_City        = ISNULL(RTRIM(ORDERS.C_City),'')
         ,C_Zip         = ISNULL(RTRIM(ORDERS.C_Zip),'')
         ,C_State       = ISNULL(RTRIM(ORDERS.C_State),'')   -- CJY01
         ,C_Country     = ISNULL(C_Country.Long,'')          -- CJY01
      -- ,BuyerPO       = ISNULL(ORDERS.BuyerPO,'')
         ,BuyerPO       = ISNULL(ORDERS.M_Company,'')        -- CJY04
   ,EditDate      = MAX(ORDERS.EditDate)
         ,DepartureDate = MBOL.DepartureDate
         ,UserDefine10  = CASE WHEN ISDATE(ORDERS.UserDefine10) = 1 THEN convert(datetime,convert(nvarchar(10),ORDERS.UserDefine10,112))
                  ELSE NULL END -- CJY01
         ,MBOLKey       = MBOL.MBOLKey
         ,Billtokey     = ISNULL(RTRIM(ORDERS.Billtokey),'')
         ,SkuDesc       = ISNULL(RTRIM(ORDERDETAIL.Descr),'')
         ,UOM           = MIN(ISNULL(RTRIM(ORDERDETAIL.UOM),''))
         ,ttlctns       = PACKHEADER.TTLCNTS
         ,Qty           = ISNULL(SUM(ORDERDETAIL.Qty),0)
         ,DeliveryDate  = convert(datetime,convert(nvarchar(10),ORDERS.Deliverydate,112))
         ,OHRDD         = convert(datetime,convert(nvarchar(10),ISNULL(ORDERS.RDD,''),112))
         ,B_Company     = ISNULL(RTRIM(ORDERS.B_Company),'')
         ,B_Address1    = ISNULL(RTRIM(ORDERS.B_Address1),'')
         ,B_Address2    = ISNULL(RTRIM(ORDERS.B_Address2),'')
         ,B_Address3    = ISNULL(RTRIM(ORDERS.B_Address3),'')
         ,B_Address4    = ISNULL(RTRIM(ORDERS.B_Address4),'')
         ,B_City        = ISNULL(RTRIM(ORDERS.B_City),'')
         ,B_Zip         = ISNULL(RTRIM(ORDERS.B_Zip),'')
         ,B_State       = ISNULL(RTRIM(ORDERS.B_State),'')     -- CJY01
         ,B_Country     = ISNULL(B_Country.Long,'')            -- CJY01
         ,ST_Company    = ISNULL(RTRIM(STORER.Company),'')
         ,ST_Address1   = ISNULL(RTRIM(STORER.Address1),'')
         ,ST_Address2   = ISNULL(RTRIM(STORER.Address2),'')
         ,ST_Address3   = ISNULL(RTRIM(STORER.Address3),'')
         ,ST_Address4   = ISNULL(RTRIM(STORER.Address4),'')
         ,ST_Phone1     = ISNULL(RTRIM(STORER.Phone1),'')
         ,ST_FAX1       = ISNULL(RTRIM(STORER.Fax1),'')
         ,ST_VAT        = ISNULL(RTRIM(STORER.VAT),'')
         ,SSTYLE        = ORDERDETAIL.Style
         ,UnitPrice     = MIN(ISNULL(RTRIM(ORDERDETAIL.UnitPrice),''))
         ,RPTCode       = ISNULL(CODELKUP.code,'')
         ,RPTCopyname   = ISNULL(CODELKUP.Description,'')
         ,OHNotes       = ISNULL(ORDERS.Notes,'')
     --  ,ConsigneeKey  = ISNULL(RTRIM(ORDERS.Consigneekey), '' )  -- CJY02
      ,ConsigneeKey  = ISNULL(REPLACE(RTRIM(ORDERS.Consigneekey), 'AD', ''), '' ) -- CJY04
      ,VATLblText    = ISNULL(VATLblText.Short, '')             -- CJY02
  -- ,UserDefine03  = ISNULL(RTRIM(ORDERDETAIL.UserDefine03),'')     --CS01
    --,UserDefine04  = ISNULL(RTRIM(ORDERDETAIL.UserDefine04),'')     --CS01
   FROM MBOL        WITH (NOLOCK)
   JOIN MBOLDETAIL  WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
-- JOIN ORDERDETAIL (NOLOCK) ON  ORDERDETAIL.Orderkey = ORDERS.orderkey
   JOIN (
      --SELECT DISTINCT OrderKey, StorerKey, UOM, sku,unitprice,UserDefine02
      SELECT OD.OrderKey,
   CASE WHEN ISNULL(ADUOM.Short,'') = '' THEN OD.UOM ELSE ADUOM.Short END AS UOM, -- CJY04
   OD.unitprice, OD.UserDefine02, sum(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) AS Qty, --,UserDefine03,UserDefine04
   MIN(OD.Userdefine03) AS Userdefine03, MIN(OD.Userdefine04) AS Userdefine04, SKU.Style, MAX(SKU.Descr) AS Descr
   FROM ORDERDETAIL OD WITH (NOLOCK)
   JOIN SKU WITH (NOLOCK) ON OD.Storerkey =  SKU.Storerkey AND OD.Sku = SKU.sku
   LEFT JOIN CODELKUP ADUOM WITH (NOLOCK) ON ADUOM.LISTNAME = 'ADUOM' AND ADUOM.code = OD.UOM AND ADUOM.Storerkey = OD.Storerkey -- CJY04
     WHERE OD.MBOLKey = @c_MBOLKey
   GROUP BY OD.OrderKey, OD.unitprice, OD.UserDefine02, CASE WHEN ISNULL(ADUOM.Short,'') = '' THEN OD.UOM ELSE ADUOM.Short END, SKU.Style
     ) AS ORDERDETAIL
   ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey )
   JOIN PACKHEADER  WITH (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)
   --JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   --                               AND(ORDERDETAIL.Storerkey = PACKDETAIL.Storerkey)
   --                               AND(ORDERDETAIL.Sku       = PACKDETAIL.Sku)
   --JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey  = SKU.Storerkey)
   --                               AND(ORDERDETAIL.Sku        = SKU.Sku)
   JOIN STORER      WITH (NOLOCK) ON STORER.STORERKEY = ORDERS.STORERKEY
   LEFT JOIN CODELKUP    WITH (NOLOCK) ON CODELKUP.LISTNAME = 'REPORTCOPY' AND CODELKUP.long = 'r_dw_delivery_Order_08'
                                AND CODELKUP.Storerkey = ORDERS.Storerkey
   -- CJY01 START --
   LEFT JOIN CODELKUP C_Country WITH (NOLOCK) ON C_Country.LISTNAME = 'ISOCountry' AND C_Country.code = ORDERS.C_Country
             AND C_Country.Storerkey = ORDERS.Storerkey
   LEFT JOIN CODELKUP B_Country WITH (NOLOCK) ON B_Country.LISTNAME = 'ISOCountry' AND B_Country.code = ORDERS.B_Country
                                AND B_Country.Storerkey = ORDERS.Storerkey
   -- CJY01 END --
   -- CJY02 START --
   LEFT JOIN CODELKUP VATLblText WITH (NOLOCK) ON VATLblText.LISTNAME = 'REPORTCFG' AND VATLblText.code = 'VATLblText'
        AND VATLblText.Storerkey = ORDERS.Storerkey
   -- CJY02 END --
 --LEFT JOIN CODELKUP ADUOM WITH (NOLOCK) ON ADUOM.LISTNAME = 'ADUOM' AND ADUOM.code = ORDERDETAIL.UOM AND ADUOM.Storerkey = ORDERDETAIL.Storerkey
   WHERE MBOL.MBOLKey = @c_MBOLKey
   GROUP BY ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address1),'')
   ,  ISNULL(RTRIM(ORDERS.C_Address2),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,  ISNULL(RTRIM(ORDERS.C_City),'')
         ,  ISNULL(RTRIM(ORDERS.C_Zip),'')
         ,  ISNULL(RTRIM(ORDERS.C_State),'')     -- CJY01
         ,  ISNULL(C_Country.Long,'')            -- CJY01
    --   ,  ISNULL(ORDERS.BuyerPO,'')
         ,  ISNULL(ORDERS.M_Company,'')          -- CJY04
         ,  MBOL.DepartureDate
         ,  CASE WHEN ISDATE(ORDERS.UserDefine10) = 1 THEN convert(datetime,convert(nvarchar(10),ORDERS.UserDefine10,112))
                    ELSE NULL END  -- CJY01
         ,  MBOL.MBOLKey
         ,  ISNULL(RTRIM(ORDERS.Billtokey),'')
         ,  convert(datetime,convert(nvarchar(10),ORDERS.Deliverydate,112))
         ,  PACKHEADER.TTLCNTS
         ,  convert(datetime,convert(nvarchar(10),ISNULL(ORDERS.RDD,''),112))
         ,  ISNULL(RTRIM(ORDERS.B_Company),'')
         ,  ISNULL(RTRIM(ORDERS.B_Address1),'')
         ,  ISNULL(RTRIM(ORDERS.B_Address2),'')
         ,  ISNULL(RTRIM(ORDERS.B_Address3),'')
         ,  ISNULL(RTRIM(ORDERS.B_Address4),'')
         ,  ISNULL(RTRIM(ORDERS.B_City),'')
         ,  ISNULL(RTRIM(ORDERS.B_Zip),'')
         ,  ISNULL(RTRIM(ORDERS.B_State),'')     -- CJY01
         ,  ISNULL(B_Country.Long,'')            -- CJY01
         ,  ISNULL(RTRIM(STORER.Company),'')
         ,  ISNULL(RTRIM(STORER.Address1),'')
         ,  ISNULL(RTRIM(STORER.Address2),'')
         ,  ISNULL(RTRIM(STORER.Address3),'')
         ,  ISNULL(RTRIM(STORER.Address4),'')
         ,  ISNULL(RTRIM(STORER.Phone1),'')
         ,  ISNULL(RTRIM(STORER.Fax1),'')
         ,  ISNULL(RTRIM(STORER.VAT),'')
         ,  ORDERDETAIL.Style
         ,  ISNULL(CODELKUP.code,'')
         ,  ISNULL(CODELKUP.Description,'')
         ,  ISNULL(RTRIM(ORDERDETAIL.UserDefine02),'')
         ,  ISNULL(ORDERS.Notes,'')
     --  ,  ISNULL(RTRIM(ORDERS.Consigneekey), '' )  -- CJY02
     ,  ISNULL(REPLACE(RTRIM(ORDERS.Consigneekey), 'AD', ''), '' ) -- CJY04
         ,  ISNULL(VATLblText.Short, '')             -- CJY02
   ,  ISNULL(RTRIM(ORDERDETAIL.Descr),'')
   ORDER BY  MBOL.MBOLKey,ISNULL(RTRIM(ORDERS.ExternOrderkey),''),ISNULL(CODELKUP.code,''),
 ISNULL(RTRIM(ORDERDETAIL.UserDefine02),''),
 MIN(ISNULL(RTRIM(ORDERDETAIL.UserDefine03),'')), MIN(ISNULL(RTRIM(ORDERDETAIL.UserDefine04),''))

   OPEN C_ORDLINE
   FETCH NEXT FROM C_ORDLINE INTO @c_ExternOrderkey
                              , @c_Userdefine02
                              , @c_C_Company
                              , @c_C_Address1
                              , @c_C_Address2
                              , @c_C_Address3
                              , @c_C_Address4
  , @c_C_City
                              , @c_C_Zip
                              , @c_C_State    -- CJY01
                              , @c_C_Country  -- CJY01
                              , @c_BuyerPO
                              , @dt_EditDate
                              , @dt_DepartureDate
                              , @dt_UserDefine10   -- CJY01
                              , @c_MBOLKey
                              , @c_Billtokey
                              , @c_SkuDesc
                              , @c_UOM
                              , @n_TTLCTN
                              , @n_Qty
                              , @dt_deliverydate
                              , @dt_OHRDD
                              , @c_B_Company
                              , @c_B_Address1
                              , @c_B_Address2
                              , @c_B_Address3
                              , @c_B_Address4
                              , @c_B_City
                              , @c_B_Zip
                              , @c_B_State    -- CJY01
                              , @c_B_Country  -- CJY01
                              , @c_ST_Company
                              , @c_ST_Address1
                              , @c_ST_Address2
                              , @c_ST_Address3
                              , @c_ST_Address4
                              , @c_ST_Phone1
                              , @c_ST_Fax1
                              , @c_ST_VAT
                              , @c_SSTYLE
                              , @n_UnitPrice
                              , @C_RPTCode
                              , @c_RPTCopyname
                              , @c_OHNotes
                              , @c_ConsigneeKey -- CJY02
                , @c_VATLblText   -- CJY02
         -- , @c_GUserdefine03  --CS01
         -- , @c_GUserdefine04  --CS01

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF CONVERT(NVARCHAR(8), @dt_DepartureDate, 112) = '19000101'
      BEGIN
         SET @dt_DepartureDate = @dt_EditDate
      END

  IF CONVERT(NVARCHAR(8), @dt_UserDefine10, 112) = '19000101'   -- CJY01
      BEGIN
         SET @dt_UserDefine10 = NULL   -- CJY01
      END

  IF CONVERT(NVARCHAR(8), @dt_OHRDD, 112) = '19000101'
      BEGIN
         SET @dt_OHRDD = NULL
      END

  SET @c_SizeCnt = 0
  SET @c_line = 'N'   -- CS01
  SET @n_MaxLine = 1  -- CS01

  SELECT
     @c_SizeCnt = COUNT(distinct ISNULL(RTRIM(SKU.SIZE),'')),
  @n_Qty = SUM(ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0))  -- CJY03
  FROM MBOLDETAIL  WITH (NOLOCK)
  JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
  JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
  JOIN PACKHEADER  WITH (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)
  --JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo AND PACKDEtail.SKU = ORDERDETAIL.SKU )   -- CJY03
  JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                    AND (ORDERDETAIL.Sku = SKU.Sku)
  WHERE MBOLDETAIL.MBOLKey  = @c_MBOLKey
  AND   ORDERDETAIL.UserDefine02  = @c_UserDefine02
  AND   SKU.Style = @c_SSTYLE
  AND ORDERS.ExternOrderkey = @c_ExternOrderkey                --CS02
  AND   ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0) <> 0
  GROUP BY MBOLDETAIL.MBOLKey,ORDERDETAIL.UserDefine02 ,SKU.Style
  HAVING SUM(ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0)) >0

   SET @n_TTLLine =  (@c_SizeCnt/@n_MaxSizeLine)   -- CS01 Start
 IF (@c_SizeCnt%@n_MaxSizeLine) <> 0
 BEGIN
   SET @n_TTLLine = @n_TTLLine + 1
 END

 SET @n_MaxLine = @n_TTLLine
   SET @n_RecCnt = 1
 --SET @n_recgrp =1

   --SELECT @c_SSTYLE '@c_SSTYLE',@C_PreRPTCode '@C_PreRPTCode' ,@C_RPTCode '@C_RPTCode',@n_recgrp '@n_recgrp'

   IF @C_PreRPTCode<> ''
 BEGIN

   IF @C_PreRPTCode <> @C_RPTCode
   BEGIN

    SET @n_recgrp = 0

   END

   SET @C_PreRPTCode = @C_RPTCode
  END
  ELSE
  BEGIN
    SET @n_recgrp = 0
    SET @C_PreRPTCode = @C_RPTCode
  END

   SET @n_recgrp = @n_recgrp + 1         -- CS01 End

      INSERT INTO #TMP_DELNote08 (MBOLKey,  DepartureDate,  UserDefine02,  ExternOrderkey,  Billtokey,  C_Company,  C_Address1,
           C_Address2,  C_Address3  ,  C_Address4 ,  C_City  ,  C_Zip, C_State, C_Country, BuyerPO ,  UserDefine10,   -- CJY01
           OHRDD ,  SkuDesc ,  UOM,  TTLCTN ,  Qty ,  DeliveryDate,  SSTYLE,  UnitPrice,  ST_Company,
           ST_Address1,  ST_Address2,  ST_Address3,  ST_Address4 ,  ST_Phone1,  ST_Fax1 ,  ST_VAT  ,
           B_Company,  B_Address1, B_Address2,  B_Address3,  B_Address4,  B_City ,  B_Zip, B_State, B_Country, copycode, copyname,OHNotes,SizeCnt,
           ConsigneeKey, VATLblText,SizeQty,Linenum,RecGrp,Pageno,DrawLine -- CJY02
     )
      VALUES (@c_MBOLKey,@dt_DepartureDate, @c_UserDefine02, @c_ExternOrderkey, @c_Billtokey, @c_C_Company
            , @c_C_Address1, @c_C_Address2, @c_C_Address3, @c_C_Address4, @c_C_City, @c_C_Zip, @c_C_State, @c_C_Country, @c_BuyerPO, @dt_UserDefine10   -- CJY01
            , @dt_OHRDD, @c_SkuDesc, @c_UOM, @n_TTLCTN, @n_Qty, @dt_DeliveryDate, @c_SSTYLE, @n_UnitPrice,  @c_ST_Company, @c_ST_Address1
            , @c_ST_Address2, @c_ST_Address3, @c_ST_Address4, @c_ST_Phone1, @c_ST_Fax1, @c_ST_VAT, @c_B_Company, @c_B_Address1, @c_B_Address2
            , @c_B_Address3, @c_B_Address4 , @c_B_City, @c_B_Zip , @c_B_State, @c_B_Country, @C_RPTCode, @c_RPTCopyname,@c_OHNotes,@c_SizeCnt
            , @c_Consigneekey, @c_VATLblText,'',0,@n_recgrp,1,@c_line -- CJY02
   )

   --CS01 Start

 SET @c_CGSizeQty = ''
 SET @n_LineNum = 1

 DECLARE C_SizeQty CURSOR FAST_FORWARD READ_ONLY FOR
  SELECT MBOLKey,
           UserDefine02 ,
          Style ,
        SkuSizeQty = Size + '/' + CAST(PackQty AS NVARCHAR(10)), Sorting
  FROM (
  SELECT
     ISNULL(RTRIM(SKU.SIZE),'') AS Size,MBOLDETAIL.MBOLKey , ORDERDETAIL.UserDefine02,SKU.Style,
        SUM(ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0)) AS PackQty,
        MIN(ISNULL(RTRIM(ORDERDETAIL.UserDefine03),'') + ISNULL(RTRIM(ORDERDETAIL.UserDefine04),'')) AS Sorting
  FROM MBOLDETAIL  WITH (NOLOCK)
  JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
  JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
  JOIN PACKHEADER  WITH (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)
  JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                    AND (ORDERDETAIL.Sku = SKU.Sku)
  WHERE MBOLDETAIL.MBOLKey  =  @c_MBOLKey
  AND   ORDERDETAIL.UserDefine02  = @c_UserDefine02
  AND   SKU.Style = @c_SSTYLE
  AND ORDERS.ExternOrderkey = @c_ExternOrderkey                --CS02
  GROUP BY Size,MBOLDETAIL.MBOLKey , ORDERDETAIL.UserDefine02,SKU.Style
  HAVING  SUM(ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0)) > 0
  ) A ORDER BY mbolkey,userdefine02,Sorting,style

   OPEN C_SizeQty
   FETCH NEXT FROM C_SizeQty INTO @c_Gmbolkey,@c_Guserdefine02,@c_GStyle,@c_GSizeqty,@c_Gsorting

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

  --SELECT @c_GPreSTYLE '@c_GPreSTYLE',@c_GStyle '@c_GStyle',@n_RecCnt '@n_RecCnt',@c_CGSizeQty '@c_CGSizeQty',@c_GSizeqty '@c_GSizeqty'

  SET @c_CGSizeQty = @c_CGSizeQty + space(2) +@c_GSizeqty
  --select @n_RecCnt '@n_RecCnt',@c_SSTYLE '@c_SSTYLE',@C_RPTCode '@C_RPTCode'

  IF @n_RecCnt%5 <> 0
  BEGIN

     IF  @n_RecCnt =  @c_SizeCnt
   BEGIN
     IF @n_LineNum = 1 AND @n_TTLLine = 1
   BEGIN
     UPDATE #TMP_DELNote08
     SET SizeQty = LTRIM(@c_CGSizeQty)
      ,Linenum = @n_LineNum
      ,DrawLine = 'Y'
    FROM #TMP_DELNote08
    Where MBOLKey= @c_MBOLKey
    AND   UserDefine02 = @c_UserDefine02
    AND  SSTYLE = @c_SSTYLE
    AND copycode = @C_RPTCode
    AND ExternOrderkey = @c_ExternOrderkey                --CS02

     SET @c_CGSizeQty  = ''

   END
   ELSE
   BEGIN

   IF @n_LineNum=@n_MaxLine
   BEGIN
     SET @c_line = 'Y'
   END

   IF @n_TTLLine <> 0
   BEGIN

     INSERT INTO #TMP_DELNote08 (MBOLKey,  DepartureDate,  UserDefine02,  ExternOrderkey,  Billtokey,  C_Company,  C_Address1,
           C_Address2,  C_Address3  ,  C_Address4 ,  C_City  ,  C_Zip, C_State, C_Country, BuyerPO ,  UserDefine10,   -- CJY01
           OHRDD ,  SkuDesc ,  UOM,  TTLCTN ,  Qty ,  DeliveryDate,  SSTYLE,  UnitPrice,  ST_Company,
           ST_Address1,  ST_Address2,  ST_Address3,  ST_Address4 ,  ST_Phone1,  ST_Fax1 ,  ST_VAT  ,
           B_Company,  B_Address1, B_Address2,  B_Address3,  B_Address4,  B_City ,  B_Zip, B_State, B_Country, copycode, copyname,OHNotes,SizeCnt,
           ConsigneeKey, VATLblText,SizeQty,Linenum,recgrp,Pageno,DrawLine -- CJY02
     )
      VALUES (@c_MBOLKey,@dt_DepartureDate, '', @c_ExternOrderkey, @c_Billtokey, @c_C_Company
            , @c_C_Address1, @c_C_Address2, @c_C_Address3, @c_C_Address4, @c_C_City, @c_C_Zip, @c_C_State, @c_C_Country, @c_BuyerPO, @dt_UserDefine10   -- CJY01
            , @dt_OHRDD, '', '', @n_TTLCTN, 0, @dt_DeliveryDate, '', 0,  @c_ST_Company, @c_ST_Address1
            , @c_ST_Address2, @c_ST_Address3, @c_ST_Address4, @c_ST_Phone1, @c_ST_Fax1, @c_ST_VAT, @c_B_Company, @c_B_Address1, @c_B_Address2
            , @c_B_Address3, @c_B_Address4 , @c_B_City, @c_B_Zip , @c_B_State, @c_B_Country, @C_RPTCode, @c_RPTCopyname,@c_OHNotes,@c_SizeCnt
            , @c_Consigneekey, @c_VATLblText,LTRIM(@c_CGSizeQty),@n_LineNum,@n_recgrp,1,@c_line -- CJY02
     )


         SET @c_CGSizeQty  = ''
     SET @n_LineNum = @n_LineNum + 1
     SET @n_TTLLine = @n_TTLLine - 1

   END
  END
   END
  END
  ELSE
  BEGIN
 --  select '123'

 --  select @n_RecCnt '@n_RecCnt',@c_SSTYLE '@c_SSTYLE',@C_RPTCode '@C_RPTCode',@n_LineNum '@n_LineNum',@n_TTLLine '@n_TTLLine'

  IF @n_LineNum = 1 AND @n_TTLLine = 1
   BEGIN

   -- select @c_SSTYLE '@c_SSTYLE',@c_CGSizeQty '@c_CGSizeQty',@C_RPTCode '@C_RPTCode'

     UPDATE #TMP_DELNote08
     SET SizeQty = LTRIM(@c_CGSizeQty)
      ,Linenum = @n_LineNum
      ,DrawLine = 'Y'
    FROM #TMP_DELNote08
    Where MBOLKey= @c_MBOLKey
    AND   UserDefine02 = @c_UserDefine02
    AND  SSTYLE = @c_SSTYLE
    AND copycode = @C_RPTCode
    AND ExternOrderkey = @c_ExternOrderkey                --CS02

     SET @c_CGSizeQty  = ''

   END
   ELSE
   BEGIN

   IF @n_LineNum=@n_MaxLine
   BEGIN
     SET @c_line = 'Y'
   END

     IF @n_TTLLine >= 1
     BEGIN

       INSERT INTO #TMP_DELNote08 (MBOLKey,  DepartureDate,  UserDefine02,  ExternOrderkey,  Billtokey,  C_Company,  C_Address1,
       C_Address2,  C_Address3  ,  C_Address4 ,  C_City  ,  C_Zip, C_State, C_Country, BuyerPO ,  UserDefine10,   -- CJY01
       OHRDD ,  SkuDesc ,  UOM,  TTLCTN ,  Qty ,  DeliveryDate,  SSTYLE,  UnitPrice,  ST_Company,
       ST_Address1,  ST_Address2,  ST_Address3,  ST_Address4 ,  ST_Phone1,  ST_Fax1 ,  ST_VAT  ,
       B_Company,  B_Address1, B_Address2,  B_Address3,  B_Address4,  B_City ,  B_Zip, B_State, B_Country, copycode, copyname,OHNotes,SizeCnt,
       ConsigneeKey, VATLblText,SizeQty,Linenum,recgrp,Pageno,DrawLine -- CJY02
     )
    VALUES (@c_MBOLKey,@dt_DepartureDate, @c_UserDefine02, @c_ExternOrderkey, @c_Billtokey, @c_C_Company
      , @c_C_Address1, @c_C_Address2, @c_C_Address3, @c_C_Address4, @c_C_City, @c_C_Zip, @c_C_State, @c_C_Country, @c_BuyerPO, @dt_UserDefine10   -- CJY01
      , @dt_OHRDD, @c_SkuDesc, @c_UOM, @n_TTLCTN, case when @n_LineNum=1 then @n_Qty else 0 end, @dt_DeliveryDate, @c_SSTYLE,
      case when @n_LineNum=1 then @n_UnitPrice else 0 end,  @c_ST_Company, @c_ST_Address1
      , @c_ST_Address2, @c_ST_Address3, @c_ST_Address4, @c_ST_Phone1, @c_ST_Fax1, @c_ST_VAT, @c_B_Company, @c_B_Address1, @c_B_Address2
      , @c_B_Address3, @c_B_Address4 , @c_B_City, @c_B_Zip , @c_B_State, @c_B_Country, @C_RPTCode, @c_RPTCopyname,@c_OHNotes,@c_SizeCnt
      , @c_Consigneekey, @c_VATLblText,LTRIM(@c_CGSizeQty),@n_LineNum,@n_recgrp,1,@c_line -- CJY02
     )


       SET @c_CGSizeQty  = ''
       SET @n_LineNum = @n_LineNum + 1
       SET @n_TTLLine = @n_TTLLine - 1

     END
      END
 END

   --select * from #TMP_DELNote08
   SET @n_RecCnt = @n_RecCnt +  1


 FETCH NEXT FROM C_SizeQty INTO @c_Gmbolkey,@c_Guserdefine02,@c_GStyle,@c_GSizeqty,@c_Gsorting
 END
   CLOSE C_SizeQty
   DEALLOCATE C_SizeQty

  --select * from #TMP_DELNote08
 --CS01 END

   --SET @c_PreExtOrdKey = @c_ExternOrderkey
      FETCH NEXT FROM C_ORDLINE INTO @c_ExternOrderkey
                              , @c_Userdefine02
                              , @c_C_Company
                              , @c_C_Address1
                              , @c_C_Address2
                              , @c_C_Address3
                              , @c_C_Address4
                              , @c_C_City
                              , @c_C_Zip
                              , @c_C_State    -- CJY01
                              , @c_C_Country  -- CJY01
                              , @c_BuyerPO
                              , @dt_EditDate
                              , @dt_DepartureDate
                              , @dt_UserDefine10  -- CJY01
                              , @c_MBOLKey
                              , @c_Billtokey
                              , @c_SkuDesc
                              , @c_UOM
                              , @n_TTLCTN
                              , @n_Qty
                              , @dt_deliverydate
                              , @dt_OHRDD
                              , @c_B_Company
                              , @c_B_Address1
                              , @c_B_Address2
                              , @c_B_Address3
                              , @c_B_Address4
                              , @c_B_City
                              , @c_B_Zip
                              , @c_B_State    -- CJY01
                              , @c_B_Country  -- CJY01
                              , @c_ST_Company
                              , @c_ST_Address1
                              , @c_ST_Address2
                              , @c_ST_Address3
                              , @c_ST_Address4
                              , @c_ST_Phone1
                              , @c_ST_Fax1
                              , @c_ST_VAT
                              , @c_SSTYLE
                              , @n_UnitPrice
                              , @C_RPTCode
                              , @c_RPTCopyname
                              , @c_OHNotes
                              , @c_ConsigneeKey -- CJY02
                , @c_VATLblText   -- CJY02
        --  , @c_GUserdefine03  --CS01
        --  , @c_GUserdefine04  --CS01
   END
   CLOSE C_ORDLINE
   DEALLOCATE C_ORDLINE




   SELECT  DISTINCT
      MBOLKey,  DepartureDate,  UserDefine02,  ExternOrderkey,  Billtokey,  C_Company,  C_Address1,
      C_Address2,  C_Address3  ,  C_Address4 ,  C_City  ,  C_Zip, C_State, C_Country,  BuyerPO , UserDefine10,
      OHRDD ,  SkuDesc ,  UOM,  TTLCTN ,  Qty ,  DeliveryDate,  SSTYLE,  UnitPrice,  ST_Company,
      ST_Address1,  ST_Address2,  ST_Address3,  ST_Address4 ,  ST_Phone1,  ST_Fax1 ,  ST_VAT  ,
      B_Company,  B_Address1, B_Address2,  B_Address3,  B_Address4,  B_City ,  B_Zip, B_State, B_Country, copycode,  copyname,OHNotes,SizeCnt,
      ConsigneeKey, VATLblText,SizeQty,LineNum,recgrp,Pageno,DrawLine -- CJY02     -- CS01
   FROM #TMP_DELNote08
 Where linenum<> 0
   ORDER BY MBOLKey,ExternOrderkey,copycode,copyname,recgrp ,LineNum   -- CS01

   DROP TABLE #TMP_DELNote08
 DROP TABLE #TMP_DELNote08Size
END


GO