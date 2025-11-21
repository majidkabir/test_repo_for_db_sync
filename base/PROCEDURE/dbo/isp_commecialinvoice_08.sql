SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CommecialInvoice_08                            */
/* Creation Date: 11-Apr-2022                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-19343 [CN] LOGIUS_Shipping Invoice_CR                   */
/*          Copy from isp_CommecialInvoice_06                           */
/*                                                                      */
/*                                                                      */
/* Called By: report dw = r_dw_commercialinvoice_08                     */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 11-APR-2022  CSCHONG   1.0   Devops Scripts Combine                  */
/* 11-Aug-2023  WLChooi   1.1   WMS-23346 - Add new logic (WL01)        */
/************************************************************************/

CREATE   PROC [dbo].[isp_CommecialInvoice_08]
(
   @c_MBOLKey  NVARCHAR(21)
 , @c_type     NVARCHAR(10) = 'H1'
 , @c_Orderkey NVARCHAR(10) = ''
 , @c_ShipType NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   -- SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @n_rowid        INT
         , @n_rowcnt       INT
         , @c_Getmbolkey   NVARCHAR(20)
         , @c_getExtOrdkey NVARCHAR(20)
         , @n_GetUnitPrice FLOAT
         , @n_GetPQty      INT
         , @n_amt          DECIMAL(10, 2)
         , @n_getamt       DECIMAL(10, 2)
         , @n_TTLTaxamt    DECIMAL(10, 2)
         , @c_getCountry   NVARCHAR(10)
         , @n_getttlamt    DECIMAL(10, 2)
         , @c_Con_Company  NVARCHAR(45)
         , @c_Con_Address1 NVARCHAR(45)
         , @c_Con_Address2 NVARCHAR(45)
         , @c_Con_Address3 NVARCHAR(45)
         , @c_Con_Address4 NVARCHAR(45)
         , @c_OrdGrp       NVARCHAR(20)
         --,@c_orderkey      NVARCHAR(20)  
         , @c_PreOrderKey  NVARCHAR(20)
         , @c_FromCountry  NVARCHAR(10)
         , @n_TTLPLT       INT
         , @n_lineno       INT
         , @c_palletkey    NVARCHAR(30)
         , @c_storerkey    NVARCHAR(20)
         , @C_Lottable11   NVARCHAR(30)
         , @c_madein       NVARCHAR(250)
         , @c_delimiter    NVARCHAR(1)
         , @c_GetOrderKey  NVARCHAR(10)
         , @c_getsku       NVARCHAR(20)
         , @n_CntRec       INT
         , @c_company      NVARCHAR(45)
         , @c_lott11       NVARCHAR(30)
         , @c_UPDATECCOM   NVARCHAR(1)
         , @c_getconsignee NVARCHAR(45)
         , @c_OrderKey_Inv NVARCHAR(10)
         , @c_MSKU         NVARCHAR(20) = N''
         , @c_FDESCR       NVARCHAR(50) = N''
         , @c_FADD01       NVARCHAR(45) = N''
         , @c_FADD02       NVARCHAR(45) = N''
         , @c_FADD03       NVARCHAR(45) = N''
         , @c_FADD04       NVARCHAR(45) = N''
         , @c_FCity        NVARCHAR(45) = N''
         , @c_modelno      NVARCHAR(30) = N''
         , @c_SCUDF01      NVARCHAR(50) = N''
         , @c_SIFEX08      NVARCHAR(30) = N''
         , @n_ctncnt       INT          = 0
         , @n_TTLCTNWGT    INT          = 0
         , @n_TTLPLTWGT    INT          = 0
         , @c_CONType      NVARCHAR(50) = ''   --WL01

   CREATE TABLE #TEMP_CommINV08
   (
      Rowid           INT            IDENTITY(1, 1)
    , MBOLKey         NVARCHAR(20)   NULL
    , pmtterm         NVARCHAR(10)   NULL
    , Lottable11      NVARCHAR(30)   NULL
    , ExtPOKey        NVARCHAR(20)   NULL
    , OHUdf05         NVARCHAR(20)   NULL
    , ExternOrdKey    NVARCHAR(30)   NULL
    , IDS_Company     NVARCHAR(45)   NULL
    , IDS_Address1    NVARCHAR(45)   NULL
    , IDS_Address2    NVARCHAR(45)   NULL
    , IDS_Address3    NVARCHAR(45)   NULL
    , IDS_Address4    NVARCHAR(45)   NULL
    , IDS_Phone1      NVARCHAR(18)   NULL
    , IDS_City        NVARCHAR(150)  NULL
    , BILLTO_Company  NVARCHAR(45)   NULL
    , BILLTO_Address1 NVARCHAR(45)   NULL
    , BILLTO_Address2 NVARCHAR(45)   NULL
    , BILLTO_Address3 NVARCHAR(45)   NULL
    , BILLTO_Address4 NVARCHAR(45)   NULL
    , BILLTO_City     NVARCHAR(150)  NULL
    , ShipTO_Company  NVARCHAR(45)   NULL
    , ShipTO_Address1 NVARCHAR(45)   NULL
    , ShipTO_Address2 NVARCHAR(45)   NULL
    , ShipTO_Address3 NVARCHAR(45)   NULL
    , ShipTO_Address4 NVARCHAR(45)   NULL
    , ShipTO_City     NVARCHAR(150)  NULL
    , ShipTO_Phone1   NVARCHAR(18)   NULL
    , ShipTO_Contact1 NVARCHAR(30)   NULL
    , ShipTO_Country  NVARCHAR(30)   NULL
    , From_Country    NVARCHAR(30)   NULL
    , StorerKey       NVARCHAR(15)   NULL
    , SKU             NVARCHAR(20)   NULL
    , Descr           NVARCHAR(90)   NULL
    , QtyShipped      INT            NULL
    , UnitPrice       DECIMAL(10, 2) NULL
    , Currency        NVARCHAR(18)   NULL
    , ShipMode        NVARCHAR(18)   NULL
    , SONo            NVARCHAR(30)   NULL
    , consigneekey    NVARCHAR(20)   NULL
    , ODUDF05         NVARCHAR(50)   NULL
    , Taxtitle        NVARCHAR(20)   NULL
    , Amt             FLOAT
    , TaxAmt          FLOAT          NULL
    , TaxCurSymbol    NVARCHAR(20)   NULL
    , TTLAmt          DECIMAL(10, 2) NULL
    , ShipTitle       NVARCHAR(30)   NULL
    , CON_Company     NVARCHAR(45)   NULL
    , CON_Address1    NVARCHAR(45)   NULL
    , CON_Address2    NVARCHAR(45)   NULL
    , CON_Address3    NVARCHAR(45)   NULL
    , CON_Address4    NVARCHAR(45)   NULL
    , ORDGRP          NVARCHAR(20)   NULL
    , PalletKey       NVARCHAR(20)   NULL
    , TTLPLT          INT            NULL
    , Orderkey        NVARCHAR(20)   NULL
    , Madein          NVARCHAR(250)  NULL
    , OrderKey_Inv    NVARCHAR(10)   NULL
    , Freight         FLOAT
    , MSKU            NVARCHAR(20)   NULL
    , FDESCR          NVARCHAR(50)   NULL
    , FADD01          NVARCHAR(45)   NULL
    , FADD02          NVARCHAR(45)   NULL
    , FADD03          NVARCHAR(45)   NULL
    , FADD04          NVARCHAR(45)   NULL
    , FCity           NVARCHAR(45)   NULL
    , CustProdCode    NVARCHAR(30)   NULL
    , SKUCUDF01       NVARCHAR(50)   NULL
    , SIFEx08         NVARCHAR(30)   NULL
    , NotifyNotes     NVARCHAR(4000) NULL
   --Ctncnt           INT NULL,  
   --TTLCTNWGT        INT NULL,  
   --TTLPLTWGT        INT  NULL      
   )


   CREATE TABLE #TEMP_madein08
   (
      MBOLKey      NVARCHAR(20) NULL
    , OrderKey     NVARCHAR(20) NULL
    , SKU          NVARCHAR(20) NULL
    , lot11        NVARCHAR(50) NULL
    , company      NVARCHAR(45) NULL
    , OrderKey_Inv NVARCHAR(10)
   )

   CREATE TABLE #TEMP_CINVBYSKU08
   (
      TCS08MBOLKey  NVARCHAR(20)   NULL
    , TCS08OrderKey NVARCHAR(20)   NULL
    , TCS08SKU      NVARCHAR(20)   NULL
    , ctncnt        INT            NULL
    , TTLCTNWGT     NUMERIC(10, 2) NULL
    , TTLPLTWGT     NUMERIC(10, 2) NULL
   )

   SET @c_UPDATECCOM = N'N'

   CREATE TABLE #TEMP_Orderkey
   (
      MBOLKey  NVARCHAR(20) NULL
    , Orderkey NVARCHAR(20) NOT NULL PRIMARY KEY,
   )

   SET @c_Orderkey = ISNULL(RTRIM(@c_Orderkey), '')
   SET @c_ShipType = ISNULL(RTRIM(@c_ShipType), '')
   IF @c_Orderkey <> '' -- Sub Report  
   BEGIN
      INSERT INTO #TEMP_Orderkey (MBOLKey, Orderkey)
      VALUES (@c_MBOLKey, @c_Orderkey)
   END
   ELSE
   BEGIN
      INSERT INTO #TEMP_Orderkey (MBOLKey, Orderkey)
      SELECT DISTINCT MBD.MbolKey
                    , MBD.OrderKey
      FROM MBOLDETAIL MBD WITH (NOLOCK)
      WHERE MBD.MbolKey = @c_MBOLKey
   END

   INSERT INTO #TEMP_CommINV08
   SELECT MBOL.MbolKey AS MBOLKEY
        , ORDERS.PmtTerm
        , LOTT.Lottable11
        , ORDERS.ExternPOKey
        , ORDERS.UserDefine05
        , ORDERS.ExternOrderKey
        , ISNULL(S.B_Company, '') AS IDS_Company
        , ISNULL(S.B_Address1, '') AS IDS_Address1
        , ISNULL(S.B_Address2, '') AS IDS_Address2
        , ISNULL(S.B_Address3, '') AS IDS_Address3
        , ISNULL(S.B_Address4, '') AS IDS_Address4
        , ISNULL(S.B_Phone1, '') AS IDS_Phone1
        , (ISNULL(S.B_City, '') + SPACE(2) + ISNULL(S.B_State, '') + SPACE(2) + ISNULL(S.B_Zip, '')
           + ISNULL(S.B_Country, '')) AS IDS_City
        , ISNULL(ORDERS.B_Company, '') AS BILLTO_Company
        , ISNULL(ORDERS.B_Address1, '') AS BILLTO_Address1
        , ISNULL(ORDERS.B_Address2, '') AS BILLTO_Address2
        , ISNULL(ORDERS.B_Address3, '') AS BILLTO_Address3
        , ISNULL(ORDERS.B_Address4, '') AS BILLTO_Address4
        , (ISNULL(ORDERS.B_City, '') + SPACE(2) + ISNULL(ORDERS.B_State, '') + SPACE(2) + ISNULL(ORDERS.B_Zip, '')
           + SPACE(2) + ISNULL(ORDERS.B_Country, '')) AS BILLTO_City
        , CASE WHEN ORDERS.OrderGroup <> 'S01' THEN
                  CASE WHEN ORDERS.Facility = 'WGQAP'
                       AND  (ORDERS.UserDefine05 LIKE 'DDP%' OR ORDERS.UserDefine05 LIKE 'FOB%') THEN
                          CASE WHEN ORDERS.C_Country = 'HK' THEN ISNULL(SHK.Company, '')
                               WHEN ORDERS.C_Country = 'TW' THEN ISNULL(STW.Company, '')
                               ELSE ISNULL(ORDERS.C_Company, '')END
                       ELSE ISNULL(ORDERS.C_Company, '')END
               ELSE CASE WHEN ORDERS.Type = 'WR' THEN ORDERS.C_Company
                         ELSE '' END END AS ShipTO_Company
        , CASE WHEN ORDERS.OrderGroup <> 'S01' THEN
                  CASE WHEN ORDERS.Facility = 'WGQAP'
                       AND  (ORDERS.UserDefine05 LIKE 'DDP%' OR ORDERS.UserDefine05 LIKE 'FOB%') THEN
                          CASE WHEN ORDERS.C_Country = 'HK' THEN ISNULL(SHK.Address1, '')
                               WHEN ORDERS.C_Country = 'TW' THEN ISNULL(STW.Address1, '')
                               ELSE ISNULL(ORDERS.C_Address1, '')END
                       ELSE ISNULL(ORDERS.C_Address1, '')END
               ELSE ISNULL(ORDERS.C_Address1, '')END AS ShipTO_Address1
        , CASE WHEN ORDERS.OrderGroup <> 'S01' THEN
                  CASE WHEN ORDERS.Facility = 'WGQAP'
                       AND  (ORDERS.UserDefine05 LIKE 'DDP%' OR ORDERS.UserDefine05 LIKE 'FOB%') THEN
                          CASE WHEN ORDERS.C_Country = 'HK' THEN ISNULL(SHK.Address2, '')
                               WHEN ORDERS.C_Country = 'TW' THEN ISNULL(STW.Address2, '')
                               ELSE ISNULL(ORDERS.C_Address2, '')END
                       ELSE ISNULL(ORDERS.C_Address2, '')END
               ELSE ISNULL(ORDERS.C_Address2, '')END AS ShipTO_Address2
        , CASE WHEN ORDERS.OrderGroup <> 'S01' THEN
                  CASE WHEN ORDERS.Facility = 'WGQAP'
                       AND  (ORDERS.UserDefine05 LIKE 'DDP%' OR ORDERS.UserDefine05 LIKE 'FOB%') THEN
                          CASE WHEN ORDERS.C_Country = 'HK' THEN ISNULL(SHK.Address3, '')
                               WHEN ORDERS.C_Country = 'TW' THEN ISNULL(STW.Address3, '')
                               ELSE ISNULL(ORDERS.C_Address3, '')END
                       ELSE ISNULL(ORDERS.C_Address3, '')END
               ELSE ISNULL(ORDERS.C_Address3, '')END AS ShipTO_Address3
        , CASE WHEN ORDERS.OrderGroup <> 'S01' THEN
                  CASE WHEN ORDERS.Facility = 'WGQAP'
                       AND  ORDERS.C_Country IN ( 'HK', 'TW' )
                       AND  (ORDERS.UserDefine05 LIKE 'DDP%' OR ORDERS.UserDefine05 LIKE 'FOB%') THEN ''
                       ELSE ISNULL(ORDERS.C_Address4, '')END
               ELSE ISNULL(ORDERS.C_Address4, '')END AS ShipTO_Address4
        , CASE WHEN ORDERS.Facility = 'WGQAP'
               AND  ORDERS.C_Country IN ( 'HK', 'TW' )
               AND  (ORDERS.UserDefine05 LIKE 'DDP%' OR ORDERS.UserDefine05 LIKE 'FOB%') THEN ''
               ELSE
        ( ISNULL(ORDERS.C_City, '') + SPACE(2) + ISNULL(ORDERS.C_State, '') + SPACE(2) + ISNULL(ORDERS.C_Zip, '')
          + SPACE(2) + ISNULL(ORDERS.C_Country, '')) END AS ShipTO_City
        , ISNULL(ORDERS.C_Phone1, '') AS ShipTo_phone1
        , ISNULL(ORDERS.C_contact1, '') AS ShipTo_contact1
        , ISNULL(ORDERS.C_Country, '') AS ShipTo_country
        , 'SHANGHAI' AS From_country
        , ORDERS.StorerKey
        , ORDERDETAIL.Sku
        , RTRIM(SKU.DESCR) AS Descr
        , SUM(PICKDETAIL.Qty) AS QtyShipped
        , CONVERT(DECIMAL(10, 2), ORDERDETAIL.UnitPrice) AS UnitPrice
        , ORDERDETAIL.UserDefine03 AS Currency
        , ORDERS.UserDefine03 AS ShipMode
        , ORDERS.UserDefine01 AS SONo
        , ORDERS.ConsigneeKey AS Consigneekey
        , CASE WHEN ISNULL(CL1.Short, 'N') = 'Y' THEN
                  CASE WHEN LEN(LTRIM(RTRIM(ISNULL(SkuInfo.ExtendedField05, '')))) > 16 THEN
                          SUBSTRING(LTRIM(RTRIM(ISNULL(SkuInfo.ExtendedField05, ''))), 1, 16) + ' '
                          + SUBSTRING(
                               LTRIM(RTRIM(ISNULL(SkuInfo.ExtendedField05, '')))
                             , 17
                             , LEN(LTRIM(RTRIM(ISNULL(SkuInfo.ExtendedField05, '')))))
                       ELSE ISNULL(SkuInfo.ExtendedField05, '')END
               ELSE ORDERDETAIL.UserDefine05 END AS ODUDF05
        , 'Tax:'
        , CASE WHEN ISNUMERIC(ISNULL(ORDERS.InvoiceNo, '')) = 1 THEN
                  ROUND(
                     (1 + (CAST(ORDERS.InvoiceNo AS FLOAT) / 100))
                     * (SUM(PICKDETAIL.Qty) * CONVERT(DECIMAL(10, 2), ORDERDETAIL.UnitPrice))
                   , 2)
               ELSE ROUND(SUM(PICKDETAIL.Qty) * CONVERT(DECIMAL(10, 2), ORDERDETAIL.UnitPrice), 2)END AS Amt
        , ROUND((SUM(PICKDETAIL.Qty) * CONVERT(DECIMAL(10, 2), ORDERDETAIL.UnitPrice) * 0.07), 2) AS taxamt
        , MAX(ORDERDETAIL.UserDefine03) AS TaxCurSymbol
        , 0
        , CASE WHEN ORDERS.OrderGroup <> 'S01' THEN
                  CASE WHEN ORDERS.Facility = 'WGQAP'
                       AND  ORDERS.C_Country IN ( 'HK', 'TW' )
                       AND  (ORDERS.UserDefine05 LIKE 'DDP%' OR ORDERS.UserDefine05 LIKE 'FOB%') THEN 'Consignee:'
                       ELSE 'Ship To:' END
               ELSE 'Ship To/Notify To:' END AS ShipTitle
        , CASE WHEN ORDERS.OrderGroup = 'S01' THEN CASE WHEN ORDERS.C_Country = 'HK' THEN ISNULL(MWRHK.Company, '')
                                                        WHEN ORDERS.C_Country = 'TW' THEN ISNULL(MWRTW.Company, '')
                                                        WHEN ORDERS.C_Country = 'AU' THEN ISNULL(MWRAU.Company, '')
                                                        WHEN ORDERS.C_Country = 'NZ' THEN ISNULL(MWRNZ.Company, '')
                                                        ELSE '' END
               ELSE '' END AS CON_Company
        , CASE WHEN ORDERS.OrderGroup = 'S01' THEN CASE WHEN ORDERS.C_Country = 'HK' THEN ISNULL(MWRHK.Address1, '')
                                                        WHEN ORDERS.C_Country = 'TW' THEN ISNULL(MWRTW.Address1, '')
                                                        WHEN ORDERS.C_Country = 'AU' THEN ISNULL(MWRAU.Address1, '')
                                                        WHEN ORDERS.C_Country = 'NZ' THEN ISNULL(MWRNZ.Address1, '')
                                                        ELSE '' END
               ELSE '' END AS CON_Address1
        , CASE WHEN ORDERS.OrderGroup = 'S01' THEN CASE WHEN ORDERS.C_Country = 'HK' THEN ISNULL(MWRHK.Address2, '')
                                                        WHEN ORDERS.C_Country = 'TW' THEN ISNULL(MWRTW.Address2, '')
                                                        WHEN ORDERS.C_Country = 'AU' THEN ISNULL(MWRAU.Address2, '')
                                                        WHEN ORDERS.C_Country = 'NZ' THEN ISNULL(MWRNZ.Address2, '')
                                                        ELSE '' END
               ELSE '' END AS CON_Address2
        , CASE WHEN ORDERS.OrderGroup = 'S01' THEN CASE WHEN ORDERS.C_Country = 'HK' THEN ISNULL(MWRHK.Address3, '')
                                                        WHEN ORDERS.C_Country = 'TW' THEN ISNULL(MWRTW.Address3, '')
                                                        WHEN ORDERS.C_Country = 'AU' THEN ISNULL(MWRAU.Address3, '')
                                                        WHEN ORDERS.C_Country = 'NZ' THEN ISNULL(MWRNZ.Address3, '')
                                                        ELSE '' END
               ELSE '' END AS CON_Address3
        , CASE WHEN ORDERS.OrderGroup = 'S01' THEN CASE WHEN ORDERS.C_Country = 'HK' THEN ISNULL(MWRHK.Address4, '')
                                                        WHEN ORDERS.C_Country = 'TW' THEN ISNULL(MWRTW.Address4, '')
                                                        WHEN ORDERS.C_Country = 'AU' THEN ISNULL(MWRAU.Address4, '')
                                                        WHEN ORDERS.C_Country = 'NZ' THEN ISNULL(MWRNZ.Address4, '')
                                                        ELSE '' END
               ELSE '' END AS CON_Address4
        , ORDERS.OrderGroup AS OrdGrp
        , '' AS palletkey
        , 0
        , ORDERS.OrderKey
        , '' AS madein
        , OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN ORDERS.OrderKey
                              ELSE '' END
        , CASE WHEN ISNUMERIC(ISNULL(ORDERS.InvoiceNo, '')) = 1 THEN
                  ROUND(
                     (CAST(ORDERS.InvoiceNo AS FLOAT) / 100)
                     * (SUM(PICKDETAIL.Qty) * CONVERT(DECIMAL(10, 2), ORDERDETAIL.UnitPrice))
                   , 2)
               ELSE CONVERT(DECIMAL(10, 2), 0)END AS Freight
        , SKU.MANUFACTURERSKU
        , ISNULL(FACILITY.Descr, '')
        , ISNULL(FACILITY.Address1, '')
        , ISNULL(FACILITY.Address2, '')
        , ISNULL(FACILITY.Address3, '')
        , ISNULL(FACILITY.Address4, '')
        , ISNULL(FACILITY.City, '')
        , ISNULL(ORDERDETAIL.UserDefine05, '')
        , ISNULL(SKUC.userdefine01, '')
        , ISNULL(SkuInfo.ExtendedField08, '')
        , ISNULL(CL2.Notes, '')
        --,0 AS ctncnt , 0 AS ttlctnwgt , 0 AS ttlpltwgt  
   FROM MBOL WITH (NOLOCK)
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   INNER JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku)
   INNER JOIN STORER S WITH (NOLOCK) ON (S.StorerKey = ORDERS.StorerKey)
   INNER JOIN PICKDETAIL WITH (NOLOCK) ON (   PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey
                                          AND ORDERDETAIL.StorerKey = ORDERDETAIL.StorerKey
                                          AND ORDERDETAIL.Sku = PICKDETAIL.Sku
                                          AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
   INNER JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (   LOTT.Lot = PICKDETAIL.Lot
                                                 AND LOTT.StorerKey = PICKDETAIL.Storerkey
                                                 AND LOTT.Sku = PICKDETAIL.Sku)
   LEFT JOIN STORER STW WITH (NOLOCK) ON (STW.StorerKey = 'LOGITWDDP')
   LEFT JOIN STORER SHK WITH (NOLOCK) ON (SHK.StorerKey = 'LOGIHKDDP')
   LEFT JOIN STORER MWRHK WITH (NOLOCK) ON (MWRHK.StorerKey = 'LOGISMWRHK')
   LEFT JOIN STORER MWRTW WITH (NOLOCK) ON (MWRTW.StorerKey = 'LOGISMWRTW')
   LEFT JOIN STORER MWRAU WITH (NOLOCK) ON (MWRAU.StorerKey = 'LOGISMWRAU')
   LEFT JOIN STORER MWRNZ WITH (NOLOCK) ON (MWRNZ.StorerKey = 'LOGISMWRNZ')
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (   CL1.LISTNAME = 'REPORTCFG'
                                           AND CL1.Code = 'ShowModelNumber'
                                           AND CL1.Storerkey = ORDERS.StorerKey
                                           AND CL1.code2 = ORDERS.Facility)
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON  CL2.LISTNAME = 'LOGICOM'
                                        AND CL2.Storerkey = ORDERS.StorerKey
                                        AND CL2.Code = ORDERS.ConsigneeKey
   LEFT JOIN SkuInfo WITH (NOLOCK) ON (   SkuInfo.Storerkey = SKU.StorerKey
                                      AND ORDERDETAIL.Sku = SkuInfo.Sku
                                      AND SKU.Sku = SkuInfo.Sku)
   INNER JOIN FACILITY WITH (NOLOCK) ON (FACILITY.Facility = ORDERS.Facility)
   LEFT JOIN SKUConfig SKUC WITH (NOLOCK) ON SKUC.StorerKey = SKU.StorerKey AND SKUC.SKU = SKU.Sku
   WHERE MBOL.MbolKey = @c_MBOLKey AND EXISTS (  SELECT 1
                                                 FROM #TEMP_Orderkey TMP
                                                 WHERE TMP.Orderkey = ORDERS.OrderKey)
   GROUP BY MBOL.MbolKey
          , ORDERS.PmtTerm
          , LOTT.Lottable11
          , ORDERS.ExternPOKey
          , ORDERS.UserDefine05
          , ORDERS.ExternOrderKey
          , ISNULL(S.B_Company, '')
          , ISNULL(S.B_Address1, '')
          , ISNULL(S.B_Address2, '')
          , ISNULL(S.B_Address3, '')
          , ISNULL(S.B_Address4, '')
          , ISNULL(S.B_Phone1, '')
          , (ISNULL(S.B_City, '') + SPACE(2) + ISNULL(S.B_State, '') + SPACE(2) + ISNULL(S.B_Zip, '')
             + ISNULL(S.B_Country, ''))
          , ISNULL(ORDERS.B_Company, '')
          , ISNULL(ORDERS.B_Address1, '')
          , ISNULL(ORDERS.B_Address2, '')
          , ISNULL(ORDERS.B_Address3, '')
          , ISNULL(ORDERS.B_Address4, '')
          , (ISNULL(ORDERS.B_City, '') + SPACE(2) + ISNULL(ORDERS.B_State, '') + SPACE(2) + ISNULL(ORDERS.B_Zip, '')
             + SPACE(2) + ISNULL(ORDERS.B_Country, ''))
          , ORDERS.C_Company
          , ISNULL(ORDERS.C_Address1, '')
          , ISNULL(ORDERS.C_Address2, '')
          , ISNULL(ORDERS.C_Address3, '')
          , ISNULL(ORDERS.C_Address4, '')
          , (ISNULL(ORDERS.C_City, '') + SPACE(2) + ISNULL(ORDERS.C_State, '') + SPACE(2) + ISNULL(ORDERS.C_Zip, '')
             + SPACE(2) + ISNULL(ORDERS.C_Country, ''))
          , ISNULL(ORDERS.C_Phone1, '')
          , ISNULL(ORDERS.C_contact1, '')
          , ISNULL(ORDERS.C_Country, '')
          , ISNULL(S.Country, '')
          , ORDERS.StorerKey
          , ORDERDETAIL.Sku
          , RTRIM(SKU.DESCR)
          , CONVERT(DECIMAL(10, 2), ORDERDETAIL.UnitPrice)
          , ORDERDETAIL.UserDefine03
          , ORDERS.UserDefine03
          , ORDERS.UserDefine01
          , ORDERS.ConsigneeKey
          , CASE WHEN ISNULL(CL1.Short, 'N') = 'Y' THEN
                    CASE WHEN LEN(LTRIM(RTRIM(ISNULL(SkuInfo.ExtendedField05, '')))) > 16 THEN
                            SUBSTRING(LTRIM(RTRIM(ISNULL(SkuInfo.ExtendedField05, ''))), 1, 16) + ' '
                            + SUBSTRING(
                                 LTRIM(RTRIM(ISNULL(SkuInfo.ExtendedField05, '')))
                               , 17
                               , LEN(LTRIM(RTRIM(ISNULL(SkuInfo.ExtendedField05, ''))))) --WL04  
                         ELSE ISNULL(SkuInfo.ExtendedField05, '')END
                 ELSE ORDERDETAIL.UserDefine05 END
          , ORDERS.Facility
          , ORDERS.C_Country
          , ORDERS.UserDefine05
          , SHK.Company
          , STW.Company
          , SHK.Address1
          , STW.Address1
          , SHK.Address2
          , STW.Address2
          , SHK.Address3
          , STW.Address3
          , ORDERS.OrderGroup
          , ORDERS.Type
          , ISNULL(MWRHK.Company, '')
          , ISNULL(MWRTW.Company, '')
          , ISNULL(MWRAU.Company, '')
          , ISNULL(MWRNZ.Company, '')
          , ISNULL(MWRHK.Address1, '')
          , ISNULL(MWRTW.Address1, '')
          , ISNULL(MWRAU.Address1, '')
          , ISNULL(MWRNZ.Address1, '')
          , ISNULL(MWRHK.Address2, '')
          , ISNULL(MWRTW.Address2, '')
          , ISNULL(MWRAU.Address2, '')
          , ISNULL(MWRNZ.Address2, '')
          , ISNULL(MWRHK.Address3, '')
          , ISNULL(MWRTW.Address3, '')
          , ISNULL(MWRAU.Address3, '')
          , ISNULL(MWRNZ.Address3, '')
          , ISNULL(MWRHK.Address4, '')
          , ISNULL(MWRTW.Address4, '')
          , ISNULL(MWRAU.Address4, '')
          , ISNULL(MWRNZ.Address4, '')
          , ORDERS.OrderKey
          , ORDERS.InvoiceNo
          , SKU.MANUFACTURERSKU
          , ISNULL(FACILITY.Descr, '')
          , ISNULL(FACILITY.Address1, '')
          , ISNULL(FACILITY.Address2, '')
          , ISNULL(FACILITY.Address3, '')
          , ISNULL(FACILITY.Address4, '')
          , ISNULL(FACILITY.City, '')
          , ISNULL(ORDERDETAIL.UserDefine05, '')
          , ISNULL(SKUC.userdefine01, '')
          , ISNULL(SkuInfo.ExtendedField08, '')
          , ISNULL(CL2.Notes, '')

   SET @c_FromCountry = N''
   SET @n_lineno = 1
   SET @c_palletkey = N''
   SET @c_delimiter = N','

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT MBOLKey
                 , ExternOrdKey
                 , SUM(TaxAmt)
                 , Orderkey
                 , StorerKey --sum(UnitPrice*QtyShipped)  
                 , OrderKey_Inv
   FROM #TEMP_CommINV08
   WHERE MBOLKey = @c_MBOLKey
   GROUP BY MBOLKey
          , ExternOrdKey
          , Orderkey
          , StorerKey
          , OrderKey_Inv

   OPEN CUR_RESULT

   FETCH NEXT FROM CUR_RESULT
   INTO @c_Getmbolkey
      , @c_getExtOrdkey
      , @n_getamt
      , @c_Orderkey
      , @c_storerkey
      , @c_OrderKey_Inv

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @c_OrderKey_Inv = ''
      BEGIN
         SELECT TOP 1 @c_getCountry = B_Country
                    , @c_FromCountry = C_Country
                    , @c_getconsignee = ConsigneeKey
         FROM ORDERS (NOLOCK)
         WHERE MBOLKey = @c_Getmbolkey AND OrderKey = @c_OrderKey_Inv
      END
      ELSE
      BEGIN
         SELECT TOP 1 @c_getCountry = B_Country
                    , @c_FromCountry = C_Country
                    , @c_getconsignee = ConsigneeKey
         FROM ORDERS (NOLOCK)
         WHERE MBOLKey = @c_Getmbolkey AND ExternOrderKey = @c_getExtOrdkey
      END

      SET @n_amt = 0
      SET @n_getttlamt = 0
      SET @c_PreOrderKey = N''
      SET @n_TTLPLT = 0

      SELECT @n_amt = SUM(Amt)
           , @n_getttlamt = SUM(TaxAmt)
      FROM #TEMP_CommINV08
      WHERE MBOLKey = @c_Getmbolkey AND OrderKey_Inv = @c_OrderKey_Inv
      GROUP BY MBOLKey

      IF @c_getCountry = 'SG' AND @c_getconsignee <> '31624'
      BEGIN
         --SET @n_amt = @n_getamt * 0.07  
         --SET @n_TTLTaxamt = @n_getttlamt + @n_amt  
         SET @n_TTLTaxamt = CONVERT(DECIMAL(10, 2), (@n_getttlamt + @n_amt))

         --SELECT @n_getamt AS '@n_getamt',@n_amt AS '@n_amt',@n_TTLTaxamt AS '@n_TTLTaxamt',@n_getttlamt AS '@n_getttlamt'  
      END
      ELSE
      BEGIN
         SET @n_TTLTaxamt = @n_amt
      END

      IF @c_FromCountry = 'TH'
      BEGIN
         IF @c_PreOrderKey <> @c_Orderkey
         BEGIN

            IF @n_lineno = 1
            BEGIN
               SELECT @n_TTLPLT = COUNT(DISTINCT CD.PalletKey)
               FROM CONTAINERDETAIL CD WITH (NOLOCK)
               JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey = @c_MBOLKey
               --JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType  
               -- GROUP BY C.UDF01  
            END
         END

         SELECT @c_palletkey = ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'), '')
         FROM PackHeader PH WITH (NOLOCK)
         JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PH.OrderKey
         JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.CaseId = PD.LabelNo AND PLTD.Sku = PD.SKU
         JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON CD.PalletKey = PLTD.PalletKey
         JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey = ORD.MBOLKey
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON  C.LISTNAME = 'CONTAINERT'
                                            AND C.UDF01 = 'P'
                                            AND C.Code = CON.ContainerType
         WHERE PH.OrderKey = @c_Orderkey AND PLTD.StorerKey = @c_storerkey

         DECLARE TH_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT MBOLKey
                       , Orderkey
                       , SKU
         FROM #TEMP_CommINV08
         WHERE MBOLKey = @c_MBOLKey AND OrderKey_Inv = @c_OrderKey_Inv AND ShipTO_Country = 'TH'

         OPEN TH_ORDERS

         FETCH FROM TH_ORDERS
         INTO @c_Getmbolkey
            , @c_GetOrderKey
            , @c_getsku

         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT INTO #TEMP_madein08 (MBOLKey, OrderKey, SKU, lot11, company, OrderKey_Inv)
            SELECT DISTINCT ORD.MBOLKey
                          , ORD.OrderKey
                          , PD.Sku
                          , C.Description
                          , ORD.C_Company
                          , OrderKey_Inv = @c_OrderKey_Inv
            FROM PICKDETAIL PD (NOLOCK)
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PD.OrderKey
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON  PLTD.UserDefine02 = PD.OrderKey
                                                 AND PLTD.Sku = PD.Sku
                                                 AND PLTD.StorerKey = ORD.StorerKey
            JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON CD.PalletKey = PLTD.PalletKey
            JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey = ORD.MBOLKey
            JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (   LOTT.Sku = PD.Sku
                                                    AND LOTT.StorerKey = PD.Storerkey
                                                    AND LOTT.Lot = PD.Lot)
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'CTYCAT' AND C.Code = LOTT.Lottable11
            WHERE ORD.MBOLKey = @c_Getmbolkey AND ORD.OrderKey = @c_GetOrderKey AND PD.Sku = @c_getsku

            FETCH FROM TH_ORDERS
            INTO @c_Getmbolkey
               , @c_GetOrderKey
               , @c_getsku
         END

         CLOSE TH_ORDERS
         DEALLOCATE TH_ORDERS

         --SELECT * FROM #TEMP_madein08  
         SET @n_CntRec = 0
         SET @c_madein = N''

         IF EXISTS (  SELECT 1
                      FROM #TEMP_madein08
                      WHERE MBOLKey = @c_MBOLKey AND OrderKey_Inv = @c_OrderKey_Inv)
         BEGIN
            SET @c_UPDATECCOM = N'Y'
         END

         SELECT @n_CntRec = COUNT(DISTINCT lot11)
              , @C_Lottable11 = MIN(lot11)
              , @c_company = MIN(company)
         FROM #TEMP_madein08
         WHERE MBOLKey = @c_MBOLKey AND OrderKey_Inv = @c_OrderKey_Inv

         SET @n_lineno = 1
         SET @n_lineno = @n_CntRec

         IF @n_CntRec = 1
         BEGIN
            SET @c_madein = @C_Lottable11
         END
         ELSE
         BEGIN
            DECLARE MadeIn_loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT lot11
            FROM #TEMP_madein08
            WHERE MBOLKey = @c_MBOLKey AND OrderKey_Inv = @c_OrderKey_Inv

            OPEN MadeIn_loop

            FETCH FROM MadeIn_loop
            INTO @c_lott11

            WHILE @@FETCH_STATUS = 0
            BEGIN

               IF @n_CntRec >= 2
               BEGIN
                  SET @c_madein = @c_lott11 + @c_delimiter
               END
               ELSE
               BEGIN
                  SET @c_madein = @c_madein + @c_lott11
               END

               SET @n_CntRec = @n_CntRec - 1

               FETCH FROM MadeIn_loop
               INTO @c_lott11
            END

            CLOSE MadeIn_loop
            DEALLOCATE MadeIn_loop
         END

         -- SELECT @c_madein '@c_madein  

         UPDATE #TEMP_CommINV08
         SET TTLPLT = @n_TTLPLT
         -- ,Ctncnt = @n_ctncnt  
         WHERE MBOLKey = @c_Getmbolkey AND Orderkey = @c_GetOrderKey AND SKU = @c_getsku
      END

      IF @n_TTLPLT = 0
      BEGIN

         SELECT @n_TTLPLT = COUNT(DISTINCT CD.PalletKey)
         FROM CONTAINERDETAIL CD WITH (NOLOCK)
         JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey = @c_MBOLKey
      END

      INSERT INTO #TEMP_CINVBYSKU08 (TCS08MBOLKey, TCS08OrderKey, TCS08SKU, ctncnt, TTLCTNWGT, TTLPLTWGT)
      SELECT TC08.MBOLKey
           , TC08.Orderkey
           , TC08.SKU
           , n_ctncnt = COUNT(DISTINCT PD.LabelNo)
           , SUM(P.NetWgt)
           , (SUM(P.NetWgt) + (16.5 * @n_TTLPLT))
      FROM PackHeader PH WITH (NOLOCK)
      JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
      --JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey     
      JOIN #TEMP_CommINV08 TC08 ON TC08.Orderkey = PH.OrderKey AND TC08.SKU = PD.SKU
      JOIN SKU S WITH (NOLOCK) ON S.StorerKey = TC08.StorerKey AND S.Sku = TC08.SKU
      JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PACKKey
      WHERE TC08.Orderkey = @c_Orderkey
      GROUP BY TC08.MBOLKey
             , TC08.Orderkey
             , TC08.SKU

      --SELECT * FROM #TEMP_CINVBYSKU08  
      -- select @c_company '@c_company'  
      UPDATE #TEMP_CommINV08
      SET TaxAmt = CASE WHEN @c_getCountry = 'SG' AND @c_getconsignee <> '31624' THEN TaxAmt
                        ELSE 0.00 END
        , TTLAmt = @n_TTLTaxamt
        , TaxCurSymbol = TaxCurSymbol
        , Madein = @c_madein
        , ShipTO_Company = CASE WHEN @c_UPDATECCOM = 'Y' THEN @c_company
                                ELSE ShipTO_Company END
      WHERE MBOLKey = @c_Getmbolkey AND OrderKey_Inv = @c_OrderKey_Inv
      --AND ExternOrdKey = @c_getExtOrdkey  

      SET @c_PreOrderKey = @c_Orderkey
      SET @n_lineno = @n_lineno + 1

      FETCH NEXT FROM CUR_RESULT
      INTO @c_Getmbolkey
         , @c_getExtOrdkey
         , @n_getamt
         , @c_Orderkey
         , @c_storerkey
         , @c_OrderKey_Inv
   END
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT

   IF @c_ShipType <> 'L'
   BEGIN
      SET @c_company = N''
      SELECT TOP 1 @c_company = company
      FROM #TEMP_madein08 AS tm
      WHERE tm.MBOLKey = @c_Getmbolkey

      UPDATE #TEMP_CommINV08
      SET PalletKey = CASE WHEN @c_FromCountry = 'TH' THEN @c_palletkey
                           ELSE PalletKey END
        , Madein = CASE WHEN @c_FromCountry = 'TH' THEN @c_madein
                        ELSE Madein END
        , ShipTO_Company = CASE WHEN @c_FromCountry = 'TH' THEN @c_company
                                ELSE ShipTO_Company END
      WHERE MBOLKey = @c_Getmbolkey
   END

   DELETE FROM #TEMP_madein08

   --WL01 S
   SET @c_CONType = ''

   SELECT @c_CONType = ISNULL(CON.ContainerType,'')
   FROM CONTAINER CON (NOLOCK)
   WHERE CON.MBOLKey = @c_MBOLKey

   IF (@c_CONType LIKE '%PALLET%' OR @c_CONType LIKE '%PLT%')
   BEGIN
      SET @c_CONType = 'Y'
   END
   --WL01 E

   ---ADD BY HU YUAN ON 2022-06-10  
   DECLARE @FinalPalletWgt NUMERIC(10, 2)
   SELECT @FinalPalletWgt = SUM(TTLCTNWGT)
   FROM #TEMP_CINVBYSKU08

   --WL01 S
   UPDATE #TEMP_CINVBYSKU08
   SET TTLPLTWGT = IIF(@c_CONType = 'Y'
                    , (@FinalPalletWgt + (16.5 * @n_TTLPLT))
                    , (@FinalPalletWgt)
                   )
   --WL01 E

   IF @c_type = 'H1'
      GOTO TYPE_H1
   IF @c_type = 'S01'
      GOTO TYPE_S01
   IF @c_type = 'S02'
      GOTO TYPE_S02

   TYPE_H1:

   SELECT Rowid
        , MBOLKey
        , pmtterm
        , Lottable11
        , ExtPOKey
        , OHUdf05
        , ExternOrdKey
        , IDS_Company
        , IDS_Address1
        , IDS_Address2
        , IDS_Address3
        , IDS_Address4
        , IDS_Phone1
        , IDS_City
        , BILLTO_Company
        , BILLTO_Address1
        , BILLTO_Address2
        , BILLTO_Address3
        , BILLTO_Address4
        , BILLTO_City
        , ShipTO_Company
        , ShipTO_Address1
        , ShipTO_Address2
        , ShipTO_Address3
        , ShipTO_Address4
        , ShipTO_City
        , ShipTO_Phone1
        , ShipTO_Contact1
        , ShipTO_Country
        , From_Country
        , StorerKey
        , SKU
        , Descr
        , QtyShipped
        , UnitPrice
        , Currency
        , ShipMode
        , SONo
        , consigneekey
        , ODUDF05
        , Taxtitle
        , Amt
        , TaxAmt
        , TaxCurSymbol
        , TTLAmt
        , ShipTitle
        , CON_Company
        , CON_Address1
        , CON_Address2
        , CON_Address3
        , CON_Address4
        , ORDGRP
        , PalletKey
        , TTLPLT
        , Madein
        , ShipType = @c_ShipType
        , OrderKey_Inv
        , InvoiceNo = CASE WHEN OrderKey_Inv = '' THEN MBOLKey
                           ELSE 'A' + RTRIM(OrderKey_Inv)END
        , Freight
        , MSKU
        , FDESCR
        , FADD01
        , FADD02
        , FADD03
        , FADD04
        , FCity
        , CustProdCode
        , SKUCUDF01
        , SIFEx08
        , TCS08.ctncnt
        , TCS08.TTLCTNWGT
        , TCS08.TTLPLTWGT
        , 'CARTONS' AS CTNUnit
        , 'KGS' AS CTTWGTUnit
        , 'KGS' AS PLTWGTUnits
        , TC08.NotifyNotes
   FROM #TEMP_CommINV08 TC08
   JOIN #TEMP_CINVBYSKU08 TCS08 ON  TCS08.TCS08MBOLKey = TC08.MBOLKey
                                AND TCS08.TCS08OrderKey = TC08.Orderkey
                                AND TCS08.TCS08SKU = TC08.SKU
   ORDER BY MBOLKey
          , ExternOrdKey

   GOTO QUIT
   TYPE_S01:

   SELECT Rowid
        , MBOLKey
        , ExternOrdKey
        , BILLTO_Company
        , BILLTO_Address1
        , BILLTO_Address2
        , BILLTO_Address3
        , BILLTO_Address4
        , BILLTO_City
        , ShipTO_Company
        , ShipTO_Address1
        , ShipTO_Address2
        , ShipTO_Address3
        , ShipTO_Address4
        , ShipTO_City
        , ShipTO_Phone1
        , ShipTO_Contact1
        , ShipTO_Country
        , From_Country
        , StorerKey
        , ShipTitle
        , CON_Company
        , CON_Address1
        , CON_Address2
        , CON_Address3
        , CON_Address4
        , ORDGRP
   FROM #TEMP_CommINV08
   WHERE MBOLKey = @c_MBOLKey
   ORDER BY MBOLKey
          , ExternOrdKey

   GOTO QUIT

   TYPE_S02:

   SELECT Rowid
        , MBOLKey
        , ExternOrdKey
        , BILLTO_Company
        , BILLTO_Address1
        , BILLTO_Address2
        , BILLTO_Address3
        , BILLTO_Address4
        , BILLTO_City
        , ShipTO_Company
        , ShipTO_Address1
        , ShipTO_Address2
        , ShipTO_Address3
        , ShipTO_Address4
        , ShipTO_City
        , ShipTO_Phone1
        , ShipTO_Contact1
        , ShipTO_Country
        , From_Country
        , StorerKey
        , ShipTitle
        , CON_Company
        , CON_Address1
        , CON_Address2
        , CON_Address3
        , CON_Address4
        , ORDGRP
   FROM #TEMP_CommINV08
   WHERE MBOLKey = @c_MBOLKey
   ORDER BY MBOLKey
          , ExternOrdKey

   GOTO QUIT
   QUIT:
END

GO