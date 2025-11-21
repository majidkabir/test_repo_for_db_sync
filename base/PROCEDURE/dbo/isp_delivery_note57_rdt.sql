SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_Delivery_Note57_RDT                                 */
/* Creation Date: 24-JAN-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-18798 - VN - Adidas-CR-E-Com DeliveryNote               */
/*        :                                                             */
/* Called By: r_dw_delivery_note57_rdt                                  */
/*          :                                                           */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 24-JAN-2022 CSCHONG  1.0   Devops Scripts Combine                    */
/* 01-MAR-2022 CSCHONG  1.1   WMS-18798 Fix total amt issue (CS01)      */
/* 12-JUL-2022 CSCHONG  1.2   WMS-20148 revised field logic (CS02)      */
/* 14-MAR-2022 CSCHONG  1.3   WMS-21922 add new field (CS03)            */
/* 18-APR-2023 WLChooi  1.4   WMS-22333 Get text from Codelkup (WL01)   */
/************************************************************************/
CREATE   PROC [dbo].[isp_Delivery_Note57_RDT] @c_OrderKey NVARCHAR(50)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_ExtOrderkey     NVARCHAR(50)
         , @c_SKU             NVARCHAR(20)
         , @c_Sdescr          NVARCHAR(120)
         , @c_altsku          NVARCHAR(20)
         , @c_sbusr4          NVARCHAR(200)
         , @c_BoxNo           NVARCHAR(10)
         , @n_pqty            INT
         , @c_casecnt         FLOAT
         , @c_FullCtn         INT
         , @n_looseqty        INT
         , @n_Ctn             INT
         , @n_startcnt        INT
         , @n_Packqty         INT
         , @n_cntsku          INT
         , @n_ttlctn          INT
         , @n_ttlqty          INT
         , @n_lastctn         INT
         , @n_lineno          INT
         , @c_Storerkey       NVARCHAR(20)
         , @c_Rpttitle16      NVARCHAR(200)
         , @c_Rpttitle17      NVARCHAR(200)
         , @c_Rpttitle18      NVARCHAR(200)
         , @c_Rpttitle19      NVARCHAR(200)
         , @c_CLRCode         NVARCHAR(50)
         , @c_GetOrdkey       NVARCHAR(20) = N''
         , @n_ttlqtyunitprice INT          = 0 --(CS01 S) 
         , @n_ShipCharge      INT          = 0
         , @n_ttlamt          INT          = 0 --(CS01 E)
         , @c_Mobile          NVARCHAR(50) --(CS02 S)
         , @c_URLENCONT       NVARCHAR(150)
         , @c_URLENRETU       NVARCHAR(150)
         , @c_URLVNCONT       NVARCHAR(150)
         , @c_URLVNRETU       NVARCHAR(150)
         , @c_CSV             NVARCHAR(150)
         , @c_CSE             NVARCHAR(150) --(CS02 E)

   IF OBJECT_ID('tempdb..#TempDELNOTES57rdt') IS NOT NULL
      DROP TABLE #TempDELNOTES57rdt

   IF OBJECT_ID('tempdb..#TempORDDELNOTES57rdt') IS NOT NULL
      DROP TABLE #TempORDDELNOTES57rdt

   CREATE TABLE #TempDELNOTES57rdt
   (
      OrderKey       NVARCHAR(10)  NULL
    , ExternOrderkey NVARCHAR(50)  NULL
    , CCountry       NVARCHAR(45)
    , DelDate        NVARCHAR(10)  NULL
    , UnitPrice      FLOAT
    , QtyUnitPrice   FLOAT
    , QTY            INT
    , SKU            NVARCHAR(20)  NULL
    , SDESCR         NVARCHAR(120) NULL
    , CCompany       NVARCHAR(45)
    , CContact2      NVARCHAR(45)
    , CPhone1        NVARCHAR(45)
    , CCity          NVARCHAR(45)
    , DeliveryNote   INT
    , SSize          NVARCHAR(10)  NULL
    --    , TTLAmt             INT                 
    , Address1N2     NVARCHAR(90)
    , Address3N4     NVARCHAR(90)
    , CState         NVARCHAR(45)
    , CZip           NVARCHAR(45)
    , xdockpokey     NVARCHAR(20) --CS03             
   )

   CREATE TABLE #TempORDDELNOTES57rdt
   (
      storerkey      NVARCHAR(20)
    , OrderKey       NVARCHAR(10) NULL
    , ExternOrderkey NVARCHAR(50) NULL
    , CLCode         NVARCHAR(50) NULL   --WL01
   )

   --WL01 S
   DECLARE @T_CODELKUP AS TABLE
   (
      Code     NVARCHAR(30)
    , Notes    NVARCHAR(500) NULL
    , Orderkey NVARCHAR(10)  NULL
    , CLCode   NVARCHAR(50)  NULL
   )
   --WL01 E

   --SET @n_StartTCnt = @@TRANCOUNT
   SET @n_startcnt = 1
   SET @n_lastctn = 1
   SET @n_lineno = 1

   IF EXISTS (  SELECT 1
                FROM ORDERS OH WITH (NOLOCK)
                WHERE OH.ExternOrderKey = @c_OrderKey)
   BEGIN
      INSERT INTO #TempORDDELNOTES57rdt (storerkey, OrderKey, ExternOrderkey, CLCode)   --WL01
      SELECT OH.StorerKey
           , OH.OrderKey
           , OH.ExternOrderKey
           , CASE WHEN OH.Salesman = 'Shopee_MP' THEN 'BD_SH'  --WL01 S
                  WHEN OH.Salesman = 'Lazada_MP' THEN 'BD_LZ'
                  ELSE 'BD_COM' END   --WL01 E
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.ExternOrderKey = @c_OrderKey
   END
   ELSE IF EXISTS (  SELECT 1
                     FROM ORDERS OH WITH (NOLOCK)
                     WHERE OH.OrderKey = @c_OrderKey)
   BEGIN
      INSERT INTO #TempORDDELNOTES57rdt (storerkey, OrderKey, ExternOrderkey, CLCode)   --WL01
      SELECT OH.StorerKey
           , OH.OrderKey
           , OH.ExternOrderKey
           , CASE WHEN OH.Salesman = 'Shopee_MP' THEN 'BD_SH'  --WL01 S
                  WHEN OH.Salesman = 'Lazada_MP' THEN 'BD_LZ'
                  ELSE 'BD_COM' END   --WL01 E
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.OrderKey = @c_OrderKey
   END

   --CS02 S
   SET @c_Mobile = N''
   SET @c_URLENCONT = N''
   SET @c_URLENRETU = N''
   SET @c_URLVNRETU = N''
   SET @c_URLVNCONT = N''
   --SET @c_CSV =N'Thá»i gian: Thá»© Hai Ä‘áº¿n Thá»© Báº£y (ngoáº¡i trá»« ngÃ y lá»…): Tá»« 9 giá» sÃ¡ng Ä‘áº¿n 9 giá» tá»‘i.'
   --SET @c_CSE = 'Open: Monday - Saturday, 9am - 9pm'
   SET @c_CSV = N''
   SET @c_CSE = N''

   SELECT TOP 1 @c_Storerkey = storerkey
   FROM #TempORDDELNOTES57rdt WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey

   SELECT @c_Mobile = ISNULL(C.Notes, '')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME = 'ADIDNECOM' AND C.Storerkey = @c_Storerkey AND C.Code = 'MB'

   SELECT @c_URLENCONT = ISNULL(C.Notes, '')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME = 'ADIDNECOM' AND C.Storerkey = @c_Storerkey AND C.Code = 'URLENCONT'

   SELECT @c_URLENRETU = ISNULL(C.Notes, '')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME = 'ADIDNECOM' AND C.Storerkey = @c_Storerkey AND C.Code = 'URLENCONT'

   SELECT @c_URLVNCONT = ISNULL(C.Notes, '')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME = 'ADIDNECOM' AND C.Storerkey = @c_Storerkey AND C.Code = 'URLVNCONT'

   SELECT @c_URLVNRETU = ISNULL(C.Notes, '')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME = 'ADIDNECOM' AND C.Storerkey = @c_Storerkey AND C.Code = 'URLVNRETU'

   SELECT @c_CSV = ISNULL(C.Notes, '')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME = 'ADIDNECOM' AND C.Storerkey = @c_Storerkey AND C.Code = 'FT01'

   SELECT @c_CSE = ISNULL(C.Notes, '')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME = 'ADIDNECOM' AND C.Storerkey = @c_Storerkey AND C.Code = 'FT02'
   --CS02 E

   --WL01 S
   --Header
   INSERT INTO @T_CODELKUP (Orderkey, Code, Notes, CLCode)
   SELECT TOR.OrderKey, CL.Code, ISNULL(CL.Notes,''), TOR.CLCode
   FROM CODELKUP CL (NOLOCK)
   JOIN #TempORDDELNOTES57rdt TOR (NOLOCK) ON TOR.Storerkey = CL.Storerkey
                                          AND CL.Code LIKE TOR.CLCode + '%'
   WHERE CL.LISTNAME = 'ADIDNECOM'
   GROUP BY TOR.OrderKey, CL.Code, ISNULL(CL.Notes,''), TOR.CLCode

   --Footer
   INSERT INTO @T_CODELKUP (Orderkey, Code, Notes, CLCode)
   SELECT TOR.OrderKey, CL.Code
        , CASE WHEN TOR.CLCode IN ('BD_SH','BD_LZ') THEN '' ELSE ISNULL(CL.Notes,'') END
        , TOR.CLCode
   FROM CODELKUP CL (NOLOCK)
   JOIN #TempORDDELNOTES57rdt TOR (NOLOCK) ON TOR.Storerkey = CL.Storerkey
                                          AND CL.Code LIKE 'FT%'
   WHERE CL.LISTNAME = 'ADIDNECOM'
   GROUP BY TOR.OrderKey, CL.Code
          , CASE WHEN TOR.CLCode IN ('BD_SH','BD_LZ') THEN '' ELSE ISNULL(CL.Notes,'') END
          , TOR.CLCode
   --WL01 E

   INSERT INTO #TempDELNOTES57rdt (OrderKey, ExternOrderkey, CCountry, DelDate, UnitPrice, QtyUnitPrice, QTY, SKU
                                 , SDESCR, CCompany, CContact2, CPhone1, CCity, DeliveryNote, SSize --  TTLAmt,
                                 , Address1N2, Address3N4, CState, CZip, xdockpokey --CS03
   )
   SELECT DISTINCT ORD.OrderKey
                 , ORD.ExternOrderKey
                 , ORD.C_Country
                 , CONVERT(NVARCHAR(10), ORD.DeliveryDate, 104)
                 , OD.UnitPrice AS UnitPrice
                 , SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) * OD.UnitPrice
                 , SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                 , OD.Sku
                 , S.DESCR
                 , ORD.C_Company
                 , ORD.C_Contact2
                 , ORD.C_Phone1
                 , ORD.C_City
                 , CASE WHEN ISNUMERIC(ORD.DeliveryNote) = 1 THEN CAST(ORD.DeliveryNote AS INT)
                        ELSE 0 END
                 , S.Size
                 , ISNULL(ORD.C_Address1, '') + SPACE(1) + ISNULL(ORD.C_Address2, '')
                 , ISNULL(ORD.C_Address3, '') + SPACE(1) + ISNULL(ORD.C_Address4, '')
                 , ORD.C_State
                 , ORD.C_Zip
                 , ISNULL(ORD.xdockpokey, '') --CS03
   FROM ORDERS ORD WITH (NOLOCK)
   JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORD.OrderKey
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.Sku = OD.Sku
   JOIN #TempORDDELNOTES57rdt TORH ON  TORH.storerkey = ORD.StorerKey
                                   AND TORH.OrderKey = ORD.OrderKey
                                   AND TORH.ExternOrderkey = ORD.ExternOrderKey
   --WHERE ORD.Orderkey = @c_GetOrdkey
   GROUP BY ORD.OrderKey
          , ORD.ExternOrderKey
          , ORD.C_Country
          , CONVERT(NVARCHAR(10), ORD.DeliveryDate, 104)
          , OD.UnitPrice
          , OD.Sku
          , S.DESCR
          , ORD.C_Company
          , ORD.C_Contact2
          , ORD.C_Phone1
          , ORD.C_City
          , CASE WHEN ISNUMERIC(ORD.DeliveryNote) = 1 THEN CAST(ORD.DeliveryNote AS INT)
                 ELSE 0 END
          , S.Size
          , ISNULL(ORD.C_Address1, '') + SPACE(1) + ISNULL(ORD.C_Address2, '')
          , ISNULL(ORD.C_Address3, '') + SPACE(1) + ISNULL(ORD.C_Address4, '')
          , ORD.C_State
          , ORD.C_Zip
          , ISNULL(ORD.xdockpokey, '') --CS03
   ORDER BY ORD.OrderKey
          , OD.Sku

   --(CS01 S) 
   SELECT @n_ttlqtyunitprice = SUM(QtyUnitPrice)
        , @n_ShipCharge = MAX(DeliveryNote)
   FROM #TempDELNOTES57rdt

   SET @n_ttlamt = @n_ShipCharge + @n_ttlqtyunitprice
   --(CS01 E)

   SELECT *
        , @n_ttlamt AS ttlvatamt --(DeliveryNote + QtyUnitPrice) AS ttlvatamt    --CS01    
        , @c_Mobile AS MobileText
        , @c_URLENCONT AS URLENCONTText
        , @c_URLENRETU AS URLENRETUtext --CS02 S
        , @c_URLVNCONT AS URLVNCONTText
        , @c_URLVNRETU AS URLVNRETUText
        , @c_CSV AS CSVText
        , @c_CSE AS CSEText --CS02 E
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '01') AS Col01   --WL01 S
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '02') AS Col02
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '03') AS Col03
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '04') AS Col04
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '05') AS Col05
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '06') AS Col06
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '07') AS Col07
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '08') AS Col08
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '09') AS Col09
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '10') AS Col10
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = TC.CLCode + '11') AS Col11
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = 'FT11') AS FT11
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = 'FT12') AS FT12
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = 'FT13') AS FT13
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = 'FT14') AS FT14
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = 'FT15') AS FT15
        , (SELECT MAX(TC.Notes) FROM @T_CODELKUP TC WHERE TC.Orderkey = #TempDELNOTES57rdt.OrderKey AND TC.Code = 'FT16') AS FT16   --WL01 E
   FROM #TempDELNOTES57rdt
   -- WHERE OrderKey = @c_GetOrdkey
   ORDER BY #TempDELNOTES57rdt.OrderKey   --WL01
          , #TempDELNOTES57rdt.SKU        --WL01

   IF OBJECT_ID('tempdb..#TempDELNOTES57rdt') IS NOT NULL
      DROP TABLE #TempDELNOTES57rdt

   IF OBJECT_ID('tempdb..#TempORDDELNOTES57rdt') IS NOT NULL
      DROP TABLE #TempORDDELNOTES57rdt

END -- procedure

GO