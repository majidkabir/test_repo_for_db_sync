SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_invoice_detail_01                          */
/* Creation Date: 06-Sep-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Invoice Detail for GBG                                       */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_invoice_detail_01           */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2017-09-09   ML       1.1  Specification Change                       */
/* 2017-09-28   ML       1.2  Include BOM parent SKU                     */
/* 2018-02-23   ML       1.3  Change COO to get from Lottable01          */
/* 2018-05-02   ML       1.4  Change UPC get from SKU.AltSku (ML01)      */
/* 2018-05-11   ML       1.5  Add Group by C_Company                     */
/* 2018-06-11   ML       1.6  Add CodeLkup for ShipperCompany mapping    */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_invoice_detail_01] (
   @as_mbolkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF OBJECT_ID('tempdb..#TEMP_BOM') IS NOT NULL
      DROP TABLE #TEMP_BOM
   IF OBJECT_ID('tempdb..#TEMP_HSCODE_TEMP') IS NOT NULL
      DROP TABLE #TEMP_HSCODE_TEMP
   IF OBJECT_ID('tempdb..#TEMP_HSCODE') IS NOT NULL
      DROP TABLE #TEMP_HSCODE
   IF OBJECT_ID('tempdb..#TEMP_INVOICEDETAIL') IS NOT NULL
      DROP TABLE #TEMP_INVOICEDETAIL

   ------------------------

   SELECT Storerkey     = OD.Storerkey
        , Sku           = MAX ( ISNULL( BOM.ComponentSku, OD.Sku ) )
        , ParentSku     = OD.Sku
        , ComponentSku  = BOM.ComponentSku
        , BOM_Qty       = MAX ( BOM.Qty )
        , BOM_ParentQty = MAX ( BOM.ParentQty )
        , BOM_SeqNo     = ROW_NUMBER() OVER(PARTITION BY OD.Storerkey, OD.Sku ORDER BY BOM.ComponentSku)
   INTO #TEMP_BOM
   FROM dbo.ORDERS      OH (NOLOCK)
   JOIN dbo.ORDERDETAIL OD (NOLOCK) ON OH.Orderkey = OD.Orderkey
   LEFT OUTER JOIN dbo.BillOfMaterial BOM (NOLOCK) ON OD.Storerkey=BOM.Storerkey AND OD.Sku=BOM.Sku
   WHERE OH.MBOLKey = @as_mbolkey
   GROUP BY OD.Storerkey
          , OD.Sku
          , BOM.ComponentSku
   ORDER BY 1, 2, 3

   ------------------------

   SELECT *
   INTO #TEMP_HSCODE_TEMP
   FROM (
         SELECT Storerkey = BOM.Storerkey
              , Sku       = BOM.Sku
              , HS_Code   = SKU.SUSR1
         FROM #TEMP_BOM BOM, dbo.SKU SKU (NOLOCK)
         WHERE SKU.Storerkey = BOM.Storerkey AND SKU.SKu = BOM.Sku AND SKU.SUSR1 <> ''
      UNION
         SELECT BOM.Storerkey, BOM.Sku, SKU.SUSR2
         FROM #TEMP_BOM BOM, dbo.SKU SKU (NOLOCK)
         WHERE SKU.Storerkey = BOM.Storerkey AND SKU.SKu = BOM.Sku AND SKU.SUSR2 <> ''
      UNION
         SELECT BOM.Storerkey, BOM.Sku, SKU.SUSR3
         FROM #TEMP_BOM BOM, dbo.SKU SKU (NOLOCK)
         WHERE SKU.Storerkey = BOM.Storerkey AND SKU.SKu = BOM.Sku AND SKU.SUSR3 <> ''
      UNION
         SELECT BOM.Storerkey, BOM.Sku, SKU.SUSR4
         FROM #TEMP_BOM BOM, dbo.SKU SKU (NOLOCK)
         WHERE SKU.Storerkey = BOM.Storerkey AND SKU.SKu = BOM.Sku AND SKU.SUSR4 <> ''
      UNION
         SELECT BOM.Storerkey, BOM.Sku, SKU.SUSR5
         FROM #TEMP_BOM BOM, dbo.SKU SKU (NOLOCK)
         WHERE SKU.Storerkey = BOM.Storerkey AND SKU.SKu = BOM.Sku AND SKU.SUSR5 <> ''
      UNION
         SELECT BOM.Storerkey, BOM.Sku, SKU.BUSR4
         FROM #TEMP_BOM BOM, dbo.SKU SKU (NOLOCK)
         WHERE SKU.Storerkey = BOM.Storerkey AND SKU.SKu = BOM.Sku AND SKU.BUSR4 <> ''
   ) HSCODE

   ------------------------

   SELECT Storerkey
        , Sku
        , HS_Code
        , HSCODE_SeqNo = ROW_NUMBER() OVER(PARTITION BY Storerkey, Sku ORDER BY HS_Code)
   INTO #TEMP_HSCODE
   FROM #TEMP_HSCODE_TEMP
   ORDER BY 1,2,3


   ------------------------

   SELECT MBOLKey           = RTRIM ( OH.MBOLKey )
        , MarkForKey        = ISNULL ( RTRIM ( OH.MarkForKey ), '' )
        , ExternOrderkey    = ISNULL ( RTRIM ( MAX ( OH.ExternOrderkey ) ), '' )
        , Company           = ISNULL ( RTRIM ( MAX ( ISNULL( DIV.Description, ST.B_Company ) ) ), '' )
        , Address1          = ISNULL ( RTRIM ( MAX ( ST.B_Address1 ) ), '' )
        , Address2          = ISNULL ( RTRIM ( MAX ( ST.B_Address2 ) ), '' )
        , City              = ISNULL ( RTRIM ( MAX ( ST.B_City ) ), '' )
        , State             = ISNULL ( RTRIM ( MAX ( ST.B_State ) ), '' )
        , Country           = ISNULL ( RTRIM ( MAX ( ST.B_Country ) ), '' )
        , Zip               = ISNULL ( RTRIM ( MAX ( ST.B_Zip ) ), '' )
        , StoreName         = ISNULL ( RTRIM ( MAX ( OH.M_Company ) ), '' )
        , C_Company         = ISNULL ( RTRIM ( OH.C_Company ), '' )
        , C_Address1        = ISNULL ( RTRIM ( MAX ( OH.C_Address1 ) ), '' )
        , C_Address2        = ISNULL ( RTRIM ( MAX ( OH.C_Address2 ) ), '' )
        , C_Address3        = ISNULL ( RTRIM ( MAX ( OH.C_Address3 ) ), '' )
        , C_City            = ISNULL ( RTRIM ( MAX ( OH.C_City ) ), '' )
        , C_State           = ISNULL ( RTRIM ( MAX ( OH.C_State ) ), '' )
        , C_Country         = ISNULL ( RTRIM ( MAX ( OH.C_Country ) ), '' )
        , C_Zip             = ISNULL ( RTRIM ( MAX ( OH.C_Zip ) ), '' )
        , B_Company         = ISNULL ( RTRIM ( MAX ( OH.B_Company ) ), '' )
        , B_Address1        = ISNULL ( RTRIM ( MAX ( OH.B_Address1 ) ), '' )
        , B_Address2        = ISNULL ( RTRIM ( MAX ( OH.B_Address2 ) ), '' )
        , B_Address3        = ISNULL ( RTRIM ( MAX ( OH.B_Address3 ) ), '' )
        , B_City            = ISNULL ( RTRIM ( MAX ( OH.B_City ) ), '' )
        , B_State           = ISNULL ( RTRIM ( MAX ( OH.B_State ) ), '' )
        , B_Country         = ISNULL ( RTRIM ( MAX ( OH.B_Country ) ), '' )
        , B_Zip             = ISNULL ( RTRIM ( MAX ( OH.B_Zip ) ), '' )
        , IncoTerm          = ISNULL ( RTRIM ( MAX ( OH.IncoTerm ) ), '' )
        , Notes             = ISNULL ( RTRIM ( MAX ( OH.Notes ) ), '' )
        , Notes2            = ISNULL ( RTRIM ( MAX ( OH.Notes2 ) ), '' )
        , Salesman          = ISNULL ( RTRIM ( MAX ( OH.Salesman ) ), '' )
        , OH_Userdefine10   = ISNULL ( RTRIM ( MAX ( OH.Userdefine10 ) ), '' )
        , OD_Userdefine06   = ISNULL ( RTRIM ( MAX ( OD.Userdefine06 ) ), '' )
        , TTLCNTS           = ISNULL ( MAX ( PAKDET.TTLCNTS ), 0 )
        , TTLWeight         = ISNULL ( MAX ( PAKINFO.TTLWeight), 0 )
        , AllOHUserdefine04 = CAST( SUBSTRING(
                            ( SELECT DISTINCT TOP 50 ', ', RTRIM(Userdefine04) FROM dbo.ORDERS (NOLOCK)
                              WHERE Userdefine04<>'' AND MBOLKey = OH.MBOLKey AND C_Company = OH.C_Company
                              ORDER BY 2
                              FOR XML PATH('')),3,1600) AS NVARCHAR(1600) )
        , AllExtOrderkey    = CAST( SUBSTRING(
                            ( SELECT DISTINCT TOP 50 ', ', RTRIM(ExternOrderkey) FROM dbo.ORDERS (NOLOCK)
                              WHERE ExternOrderkey<>'' AND MBOLKey = OH.MBOLKey AND C_Company = OH.C_Company
                              ORDER BY 2
                              FOR XML PATH('')),3,1600) AS NVARCHAR(1600) )

        , Storer_Logo       = RTRIM( MAX( ST.Logo ) )

        , Storerkey         = RTRIM ( OD.Storerkey )
        , OD_Sku            = RTRIM ( OD.Sku )
        , ComponentSku      = CAST ( '' AS NVARCHAR(20) )
        , BOM_SeqNo         = 0
        , HS_SeqNo          = HSCODE.HSCODE_SeqNo

        , Material          = RTRIM ( MAX ( SKU.BUSR1 ) )
        , Size              = RTRIM ( MAX ( SKU.Size  ) )
        , Descr             = RTRIM ( MAX ( SKU.Descr ) )
        , Qty               = SUM ( CASE WHEN ISNULL(HSCODE.HSCODE_SeqNo,1)=1 THEN PD.Qty ELSE 0 END )
        , UOM               = RTRIM ( MAX ( PACK.PackUOM3 ) )
        , UnitPrice         = MAX ( CASE WHEN ISNULL(HSCODE.HSCODE_SeqNo,1)=1 THEN OD.UnitPrice ELSE 0 END )
        , Amount            = SUM ( CASE WHEN ISNULL(HSCODE.HSCODE_SeqNo,1)=1 THEN PD.Qty * OD.UnitPrice ELSE 0 END )
-- ML01        , UPC               = RTRIM ( MAX ( IIF( ISNULL(OD.Userdefine03,'')<>'', OD.Userdefine03, OD.Sku ) ) )
        , UPC               = RTRIM ( MAX ( IIF( ISNULL(SKU.AltSKU,'')<>'', SKU.AltSKU, OD.Sku ) ) )   -- ML01
        , COO               = RTRIM ( LA.Lottable01 )
        , HS_Code           = RTRIM ( HSCODE.HS_Code )
        , HS_Descr          = ISNULL( RTRIM ( MAX ( SC.Notes ) ),'' )

   INTO #TEMP_INVOICEDETAIL

   FROM dbo.ORDERS       OH (NOLOCK)
   JOIN dbo.STORER       ST (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
   JOIN dbo.ORDERDETAIL  OD (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN dbo.PICKDETAIL   PD (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber)
   JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON (PD.Lot = LA.Lot)
   LEFT OUTER JOIN dbo.SKU            SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.SKu
   LEFT OUTER JOIN dbo.PACK          PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   LEFT OUTER JOIN #TEMP_HSCODE    HSCODE (NOLOCK) ON SKU.Storerkey = HSCODE.Storerkey AND SKU.Sku = HSCODE.Sku
   LEFT OUTER JOIN dbo.SKUCONFIG       SC (NOLOCK) ON HSCODE.Storerkey = SC.Storerkey AND HSCODE.Sku = SC.Sku AND HSCODE.HS_Code = SC.ConfigType

   LEFT OUTER JOIN (
      SELECT MBOLKey    = a.MBOLKey
           , C_Company  = a.C_Company
           , TTLCNTS    = ISNULL ( COUNT ( DISTINCT c.LabelNo ), 0 )
        FROM dbo.ORDERS     a (NOLOCK)
        JOIN dbo.PACKHEADER b (NOLOCK) ON a.Orderkey = b.Orderkey
        JOIN dbo.PACKDETAIL c (NOLOCK) ON b.Pickslipno = c.Pickslipno
       WHERE a.MBOLKey = @as_mbolkey
       GROUP BY a.MBOLKey, a.C_Company
   ) PAKDET ON (OH.MBOLKey=PAKDET.MBOLKey AND OH.C_Company=PAKDET.C_Company)

   LEFT OUTER JOIN (
      SELECT MBOLKey    = a.MBOLKey
           , C_Company  = a.C_Company
           , TTLWeight  = ISNULL ( SUM ( c.Weight ), 0 )
        FROM dbo.ORDERS     a (NOLOCK)
        JOIN dbo.PACKHEADER b (NOLOCK) ON a.Orderkey = b.Orderkey
        JOIN dbo.PACKINFO   c (NOLOCK) ON b.Pickslipno = c.Pickslipno
       WHERE a.MBOLKey = @as_mbolkey
       GROUP BY a.MBOLKey, a.C_Company
   ) PAKINFO ON (OH.MBOLKey=PAKINFO.MBOLKey AND OH.C_Company=PAKINFO.C_Company)
      
   LEFT JOIN CodeLkup DIV(NOLOCK) ON DIV.Listname='GBG_DIV' AND DIV.Storerkey=OH.Storerkey AND DIV.Code=OH.Userdefine01

   WHERE PD.Qty > 0
     AND OH.MBOLKey = @as_mbolkey

   GROUP BY OH.MBOLKey, OH.C_Company, OH.MarkForKey, OD.Storerkey, OD.Sku, LA.Lottable01, HSCODE.HS_Code, HSCODE.HSCODE_SeqNo


   ------------------------

   SELECT *
   FROM #TEMP_INVOICEDETAIL

   UNION

   SELECT INV.MBOLKey
        , INV.MarkForKey
        , INV.ExternOrderkey
        , INV.Company
        , INV.Address1
        , INV.Address2
        , INV.City
        , INV.State
        , INV.Country
        , INV.Zip
        , INV.StoreName
        , INV.C_Company
        , INV.C_Address1
        , INV.C_Address2
        , INV.C_Address3
        , INV.C_City
        , INV.C_State
        , INV.C_Country
        , INV.C_Zip
        , INV.B_Company
        , INV.B_Address1
        , INV.B_Address2
        , INV.B_Address3
        , INV.B_City
        , INV.B_State
        , INV.B_Country
        , INV.B_Zip
        , INV.IncoTerm
        , INV.Notes
        , INV.Notes2
        , INV.Salesman
        , INV.OH_Userdefine10
        , INV.OD_Userdefine06
        , INV.TTLCNTS
        , INV.TTLWeight
        , INV.AllOHUserdefine04
        , INV.AllExtOrderkey
        , INV.Storer_Logo
        , INV.Storerkey
        , INV.OD_Sku
        , ComponentSku      = RTRIM ( BOM.ComponentSku )
        , BOM_SeqNo         = BOM.BOM_SeqNo
        , HS_SeqNo          = HSCODE.HSCODE_SeqNo
        , Material          = RTRIM ( SKU.BUSR1 )
        , Size              = RTRIM ( SKU.Size  )
        , Descr             = RTRIM ( SKU.Descr )
        , Qty               = 0
        , UOM               = RTRIM ( PACK.PackUOM3 )
        , UnitPrice         = 0
        , Amount            = 0
        , UPC               = RTRIM ( BOM.ComponentSku )
        , COO               = INV.COO
        , HS_Code           = RTRIM ( HSCODE.HS_Code )
        , HS_Descr          = ISNULL( RTRIM ( SC.Notes ),'' )

   FROM #TEMP_INVOICEDETAIL INV
   JOIN #TEMP_BOM           BOM (NOLOCK) ON INV.Storerkey = BOM.Storerkey AND INV.OD_Sku = BOM.ParentSku AND BOM.ComponentSku IS NOT NULL
   LEFT OUTER JOIN dbo.SKU            SKU (NOLOCK) ON BOM.Storerkey = SKU.Storerkey AND BOM.ComponentSku = SKU.SKu
   LEFT OUTER JOIN dbo.PACK          PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   LEFT OUTER JOIN #TEMP_HSCODE    HSCODE (NOLOCK) ON SKU.Storerkey = HSCODE.Storerkey AND SKU.Sku = HSCODE.Sku
   LEFT OUTER JOIN dbo.SKUCONFIG       SC (NOLOCK) ON HSCODE.Storerkey = SC.Storerkey AND HSCODE.Sku = SC.Sku AND HSCODE.HS_Code = SC.ConfigType

   ORDER BY MBOLKey, C_Company, MarkforKey, Storerkey, OD_Sku, BOM_SeqNo, HS_SeqNo
END

GO