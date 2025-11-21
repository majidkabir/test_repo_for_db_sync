SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_invoice_detail_07_rdt                      */
/* Creation Date: 26-Feb-2021                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: WMS-16438 - HK-Nike-Ecom Macau Invoice (ReportType=INVOICE01)*/
/*                                                                       */
/* Called By: RDT - Fn842, Fn593                                         */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 18/03/2022   Michael  1.1  WMS-19257 Add MapField: GiftUnitPrice      */
/* 23/03/2022   Michael  1.2  Add NULL to Temp Table                     */
/* 20/09/2022   Michael  1.3  Remove ShipFromName dft value LF Logistics */
/*************************************************************************/

CREATE PROC [dbo].[isp_r_hk_invoice_detail_07_rdt] (
       @as_storerkey  NVARCHAR(15)
     , @as_orderkey   NVARCHAR(4000)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      ExternORderkey, C_Contact, C_Address, C_Phone, InvoiceNo, InvoiceAmount, PmtTerm, TermOfSale, NH_Number, TrackingNo, TotalWeight
      TotalCarton, SellerName, SellerAddress, SellerPhone, ShipFromName, ShipFromAddress, ShipFromPhone, Carrier
      Sku, Size, Descr, Qty, UOM, HTSCode, COO, UnitPrice, GiftUnitPrice, FooterNotes1, FooterNotes2

   [MAPVALUE]
   [SHOWFIELD]
   [SQLJOIN]
   [SQLWHERE]
*/
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_PIKDT') IS NOT NULL
      DROP TABLE #TEMP_PIKDT

   DECLARE @c_DataWindow         NVARCHAR(40)   = 'r_hk_invoice_detail_07_rdt'
         , @c_Storerkey          NVARCHAR(15)
         , @c_ExternorderkeyExp  NVARCHAR(MAX)
         , @c_C_ContactExp       NVARCHAR(MAX)
         , @c_C_AddressExp       NVARCHAR(MAX)
         , @c_C_PhoneExp         NVARCHAR(MAX)
         , @c_InvoiceNoExp       NVARCHAR(MAX)
         , @c_InvoiceAmountExp   NVARCHAR(MAX)
         , @c_PmtTermExp         NVARCHAR(MAX)
         , @c_TermOfSaleExp      NVARCHAR(MAX)
         , @c_NH_NumberExp       NVARCHAR(MAX)
         , @c_TrackingNoExp      NVARCHAR(MAX)
         , @c_TotalWeightExp     NVARCHAR(MAX)
         , @c_TotalCartonExp     NVARCHAR(MAX)
         , @c_SellerNameExp      NVARCHAR(MAX)
         , @c_SellerAddressExp   NVARCHAR(MAX)
         , @c_SellerPhoneExp     NVARCHAR(MAX)
         , @c_ShipFromNameExp    NVARCHAR(MAX)
         , @c_ShipFromAddressExp NVARCHAR(MAX)
         , @c_ShipFromPhoneExp   NVARCHAR(MAX)
         , @c_CarrierExp         NVARCHAR(MAX)
         , @c_SkuExp             NVARCHAR(MAX)
         , @c_SizeExp            NVARCHAR(MAX)
         , @c_DescrExp           NVARCHAR(MAX)
         , @c_QtyExp             NVARCHAR(MAX)
         , @c_UOMExp             NVARCHAR(MAX)
         , @c_HTSCodeExp         NVARCHAR(MAX)
         , @c_COOExp             NVARCHAR(MAX)
         , @c_UnitPriceExp       NVARCHAR(MAX)
         , @c_GiftUnitPriceExp   NVARCHAR(MAX)
         , @c_FooterNotes1Exp    NVARCHAR(MAX)
         , @c_FooterNotes2Exp    NVARCHAR(MAX)
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(MAX)
         , @c_WhereClause        NVARCHAR(MAX)


   CREATE TABLE #TEMP_PIKDT (
        Orderkey         NVARCHAR(10)  NULL
      , PickslipNo       NVARCHAR(10)  NULL
      , Loadkey          NVARCHAR(10)  NULL
      , ConsolPick       NVARCHAR(1)   NULL
      , DocKey           NVARCHAR(20)  NULL
      , Storerkey        NVARCHAR(15)  NULL
      , Externorderkey   NVARCHAR(500) NULL
      , C_Contact        NVARCHAR(500) NULL
      , C_Address        NVARCHAR(500) NULL
      , C_Phone          NVARCHAR(500) NULL
      , InvoiceNo        NVARCHAR(500) NULL
      , InvoiceAmount    NVARCHAR(500) NULL
      , PmtTerm          NVARCHAR(500) NULL
      , TermOfSale       NVARCHAR(500) NULL
      , NH_Number        NVARCHAR(500) NULL
      , TrackingNo       NVARCHAR(500) NULL
      , TotalWeight      NVARCHAR(500) NULL
      , TotalCarton      NVARCHAR(500) NULL
      , SellerName       NVARCHAR(500) NULL
      , SellerAddress    NVARCHAR(500) NULL
      , SellerPhone      NVARCHAR(500) NULL
      , ShipFromName     NVARCHAR(500) NULL
      , ShipFromAddress  NVARCHAR(500) NULL
      , ShipFromPhone    NVARCHAR(500) NULL
      , Carrier          NVARCHAR(500) NULL
      , Sku              NVARCHAR(500) NULL
      , Size             NVARCHAR(500) NULL
      , Descr            NVARCHAR(500) NULL
      , Qty              INT           NULL
      , UOM              NVARCHAR(500) NULL
      , HTSCode          NVARCHAR(500) NULL
      , COO              NVARCHAR(500) NULL
      , UnitPrice        FLOAT         NULL
      , GiftUnitPrice    FLOAT         NULL
      , FooterNotes1     NVARCHAR(500) NULL
      , FooterNotes2     NVARCHAR(500) NULL
   )

   -- Final Orderkey, PickslipNo List
   CREATE TABLE #TEMP_FINALORDERKEY (
        Orderkey         NVARCHAR(10)  NULL
      , PickslipNo       NVARCHAR(10)  NULL
      , Loadkey          NVARCHAR(10)  NULL
      , ConsolPick       NVARCHAR(1)   NULL
      , DocKey           NVARCHAR(20)  NULL
      , Storerkey        NVARCHAR(15)  NULL
   )

   INSERT INTO #TEMP_FINALORDERKEY
   SELECT Orderkey   = OH.Orderkey
        , PickslipNo = MAX( PIKHD.PickheaderKey )
        , Loadkey    = MAX( OH.Loadkey )
        , ConsolPick = 'N'
        , DocKey     = MAX( OH.Orderkey )
        , Storerkey  = MAX( OH.Storerkey )
     FROM dbo.ORDERS        OH (NOLOCK)
     JOIN dbo.PICKHEADER PIKHD (NOLOCK) ON OH.Orderkey = PIKHD.Orderkey AND OH.Orderkey<>''
     JOIN dbo.PICKDETAIL    PD (NOLOCK) ON OH.Orderkey = PD.Orderkey
    WHERE OH.Storerkey = @as_storerkey
      AND OH.OrderKey IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(REPLACE(@as_orderkey,CHAR(13)+CHAR(10),','),',') WHERE value<>'')
      AND PD.Qty > 0
    GROUP BY OH.Orderkey

   INSERT INTO #TEMP_FINALORDERKEY
   SELECT Orderkey   = OH.Orderkey
        , PickslipNo = MAX( PIKHD.PickheaderKey )
        , Loadkey    = MAX( OH.Loadkey )
        , ConsolPick = 'Y'
        , DocKey     = MAX( 'LP'+OH.Loadkey )
        , Storerkey  = MAX( OH.Storerkey )
     FROM dbo.ORDERS        OH (NOLOCK)
     JOIN dbo.PICKHEADER PIKHD (NOLOCK) ON OH.Loadkey = PIKHD.ExternOrderkey AND ISNULL(PIKHD.Orderkey,'')=''
     JOIN dbo.PICKDETAIL    PD (NOLOCK) ON OH.Orderkey = PD.Orderkey
     LEFT JOIN #TEMP_FINALORDERKEY  FOK ON OH.Orderkey = FOK.Orderkey
    WHERE OH.Storerkey = @as_storerkey
      AND OH.Loadkey IN (SELECT DISTINCT a.Loadkey FROM dbo.ORDERS a(NOLOCK) WHERE ISNULL(a.Loadkey,'')<>'' AND a.OrderKey IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(REPLACE(@as_orderkey,CHAR(13)+CHAR(10),','),',') WHERE value<>''))
      AND OH.Loadkey<>''
      AND PD.Qty > 0
      AND FOK.Orderkey IS NULL
    GROUP BY OH.Orderkey


   -- Storerkey Loop
   DECLARE C_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
     FROM #TEMP_FINALORDERKEY
    ORDER BY 1

   OPEN C_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_ExternORderkeyExp  = ''
           , @c_C_ContactExp       = ''
           , @c_C_AddressExp       = ''
           , @c_C_PhoneExp         = ''
           , @c_InvoiceNoExp       = ''
           , @c_InvoiceAmountExp   = ''
           , @c_PmtTermExp         = ''
           , @c_TermOfSaleExp      = ''
           , @c_NH_NumberExp       = ''
           , @c_TrackingNoExp      = ''
           , @c_TotalWeightExp     = ''
           , @c_TotalCartonExp     = ''
           , @c_SellerNameExp      = ''
           , @c_SellerAddressExp   = ''
           , @c_SellerPhoneExp     = ''
           , @c_ShipFromNameExp    = ''
           , @c_ShipFromAddressExp = ''
           , @c_ShipFromPhoneExp   = ''
           , @c_CarrierExp         = ''
           , @c_SkuExp             = ''
           , @c_SizeExp            = ''
           , @c_DescrExp           = ''
           , @c_QtyExp             = ''
           , @c_UOMExp             = ''
           , @c_HTSCodeExp         = ''
           , @c_COOExp             = ''
           , @c_UnitPriceExp       = ''
           , @c_GiftUnitPriceExp   = ''
           , @c_FooterNotes1Exp    = ''
           , @c_FooterNotes2Exp    = ''
           , @c_JoinClause         = ''
           , @c_WhereClause        = ''


      ----------
      SELECT TOP 1
             @c_JoinClause = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_WhereClause = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLWHERE' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      ----------
      SELECT TOP 1
             @c_ExternOrderkeyExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderkey')), '' )
           , @c_C_ContactExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Contact')), '' )
           , @c_C_AddressExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Address')), '' )
           , @c_C_PhoneExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Phone')), '' )
           , @c_InvoiceNoExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='InvoiceNo')), '' )
           , @c_InvoiceAmountExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='InvoiceAmount')), '' )
           , @c_PmtTermExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='PmtTerm')), '' )
           , @c_TermOfSaleExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='TermOfSale')), '' )
           , @c_NH_NumberExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='NH_Number')), '' )
           , @c_TrackingNoExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='TrackingNo')), '' )
           , @c_TotalWeightExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='TotalWeight')), '' )
           , @c_TotalCartonExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='TotalCarton')), '' )
           , @c_SellerNameExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='SellerName')), '' )
           , @c_SellerAddressExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='SellerAddress')), '' )
           , @c_SellerPhoneExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='SellerPhone')), '' )
           , @c_ShipFromNameExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ShipFromName')), '' )
           , @c_ShipFromAddressExp = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ShipFromAddress')), '' )
           , @c_ShipFromPhoneExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ShipFromPhone')), '' )
           , @c_CarrierExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Carrier')), '' )
           , @c_SkuExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Sku')), '' )
           , @c_SizeExp            = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Size')), '' )
           , @c_DescrExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Descr')), '' )
           , @c_QtyExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Qty')), '' )
           , @c_UOMExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='UOM')), '' )
           , @c_HTSCodeExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='HTSCode')), '' )
           , @c_COOExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='COO')), '' )
           , @c_UnitPriceExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='UnitPrice')), '' )
           , @c_GiftUnitPriceExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='GiftUnitPrice')), '' )
           , @c_FooterNotes1Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='FooterNotes1')), '' )
           , @c_FooterNotes2Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='FooterNotes2')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2




      ----------
      SET @c_ExecStatements = N'INSERT INTO #TEMP_PIKDT'
          +' (Orderkey, PickslipNo, Loadkey, ConsolPick, DocKey, Storerkey'
          +', Externorderkey, C_Contact, C_Address, C_Phone, InvoiceNo, InvoiceAmount, PmtTerm, TermOfSale, NH_Number, TrackingNo, TotalWeight'
          +', TotalCarton, SellerName, SellerAddress, SellerPhone, ShipFromName, ShipFromAddress, ShipFromPhone, Carrier'
          +', Sku, Size, Descr, Qty, UOM, HTSCode, COO, UnitPrice, GiftUnitPrice, FooterNotes1, FooterNotes2)'
          +' SELECT FOK.Orderkey'
               + ', FOK.PickslipNo'
               + ', FOK.Loadkey'
               + ', FOK.ConsolPick'
               + ', FOK.DocKey'
               + ', FOK.Storerkey'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExternOrderkeyExp ,'')<>'' THEN @c_ExternOrderkeyExp  ELSE 'OH.ExternORderkey'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_ContactExp      ,'')<>'' THEN @c_C_ContactExp       ELSE 'OH.C_Contact1'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_AddressExp      ,'')<>'' THEN @c_C_AddressExp       ELSE 'TRIM(TRIM(TRIM(TRIM(ISNULL(OH.C_Address1,''''))+'' ''+TRIM(ISNULL(OH.C_Address2,'''')))+'' ''+TRIM(ISNULL(OH.C_Address3,'''')))+'' ''+TRIM(ISNULL(OH.C_Address4,'''')))' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_PhoneExp        ,'')<>'' THEN @c_C_PhoneExp         ELSE 'OH.C_Phone1'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_InvoiceNoExp      ,'')<>'' THEN @c_InvoiceNoExp       ELSE 'OH.ExternORderkey'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_InvoiceAmountExp  ,'')<>'' THEN @c_InvoiceAmountExp   ELSE 'OH.InvoiceAmount'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PmtTermExp        ,'')<>'' THEN @c_PmtTermExp         ELSE '''Prepaid'''              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_TermOfSaleExp     ,'')<>'' THEN @c_TermOfSaleExp      ELSE '''DPP'''                  END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_NH_NumberExp      ,'')<>'' THEN @c_NH_NumberExp       ELSE 'OH.M_Company'             END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_TrackingNoExp     ,'')<>'' THEN @c_TrackingNoExp      ELSE 'STUFF((SELECT DISTINCT '', ''+ISNULL(TRIM(a.TrackingNo),'''') FROM dbo.CARTONTRACK a(NOLOCK) WHERE a.LabelNo=OH.Orderkey ORDER BY 1 FOR XML PATH('''')), 1, 2, '''')' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_TotalWeightExp    ,'')<>'' THEN @c_TotalWeightExp     ELSE '(SELECT SUM(a.Weight) FROM dbo.PACKINFO a(NOLOCK) WHERE a.PickslipNo=FOK.PickslipNo)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_TotalCartonExp    ,'')<>'' THEN @c_TotalCartonExp     ELSE '(SELECT COUNT(DISTINCT a.LabelNo) FROM dbo.PACKDETAIL a(NOLOCK) WHERE a.PickslipNo=FOK.PickslipNo)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SellerNameExp     ,'')<>'' THEN @c_SellerNameExp      ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SellerAddressExp  ,'')<>'' THEN @c_SellerAddressExp   ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SellerPhoneExp    ,'')<>'' THEN @c_SellerPhoneExp     ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ShipFromNameExp   ,'')<>'' THEN @c_ShipFromNameExp    ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ShipFromAddressExp,'')<>'' THEN @c_ShipFromAddressExp ELSE 'TRIM(TRIM(ISNULL(FAC.Address1,''''))+'' ''+TRIM(ISNULL(FAC.Address2,'''')))' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ShipFromPhoneExp  ,'')<>'' THEN @c_ShipFromPhoneExp   ELSE 'FAC.Phone1'               END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CarrierExp        ,'')<>'' THEN @c_CarrierExp         ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SkuExp            ,'')<>'' THEN @c_SkuExp             ELSE 'PD.Sku'                   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SizeExp           ,'')<>'' THEN @c_SizeExp            ELSE 'SKU.Size'                 END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DescrExp          ,'')<>'' THEN @c_DescrExp           ELSE 'SKU.Descr'                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_QtyExp            ,'')<>'' THEN @c_QtyExp             ELSE 'PD.Qty'                   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_UOMExp            ,'')<>'' THEN @c_UOMExp             ELSE '''PCS'''                  END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_HTSCodeExp        ,'')<>'' THEN @c_HTSCodeExp         ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_COOExp            ,'')<>'' THEN @c_COOExp             ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_UnitPriceExp      ,'')<>'' THEN @c_UnitPriceExp       ELSE 'CASE WHEN OD.OriginalQty=0 THEN 0 ELSE OD.UnitPrice/OD.OriginalQty END' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_GiftUnitPriceExp  ,'')<>'' THEN @c_GiftUnitPriceExp   ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_FooterNotes1Exp   ,'')<>'' THEN @c_FooterNotes1Exp    ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_FooterNotes2Exp   ,'')<>'' THEN @c_FooterNotes2Exp    ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +' FROM #TEMP_FINALORDERKEY FOK'
          +' JOIN dbo.ORDERS      OH(NOLOCK) ON FOK.Orderkey = OH.Orderkey'
          +' JOIN dbo.FACILITY   FAC(NOLOCK) ON OH.Facility = FAC.Facility'
          +' JOIN dbo.ORDERDETAIL OD(NOLOCK) ON OH.Orderkey = OD.Orderkey'
          +' JOIN dbo.PICKDETAIL  PD(NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber'
          +' JOIN dbo.SKU        SKU(NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku'
          +' JOIN dbo.PACK      PACK(NOLOCK) ON SKU.PACKKey = PACK.PackKey'
          +' JOIN dbo.STORER      ST(NOLOCK) ON OH.StorerKey = ST.StorerKey'

      SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(TRIM(@c_JoinClause),'') END

      SET @c_ExecStatements = @c_ExecStatements
          +' WHERE PD.Qty > 0 AND OH.Storerkey=@c_Storerkey'

      SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_WhereClause,'')='' THEN '' ELSE ' AND (' + ISNULL(TRIM(@c_WhereClause),'') + ')' END

      SET @c_ExecArguments = N'@c_Storerkey         NVARCHAR(15)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Storerkey
   END

   CLOSE C_STORERKEY
   DEALLOCATE C_STORERKEY


   ----------
   UPDATE a
      SET Externorderkey  = b.Externorderkey
        , C_Contact       = b.C_Contact
        , C_Address       = b.C_Address
        , C_Phone         = b.C_Phone
        , InvoiceNo       = b.InvoiceNo
        , InvoiceAmount   = b.InvoiceAmount
        , PmtTerm         = b.PmtTerm
        , TermOfSale      = b.TermOfSale
        , NH_Number       = b.NH_Number
        , TrackingNo      = b.TrackingNo
        , TotalWeight     = b.TotalWeight
        , TotalCarton     = b.TotalCarton
        , SellerName      = b.SellerName
        , SellerAddress   = b.SellerAddress
        , SellerPhone     = b.SellerPhone
        , ShipFromName    = b.ShipFromName
        , ShipFromAddress = b.ShipFromAddress
        , ShipFromPhone   = b.ShipFromPhone
        , Carrier         = b.Carrier
     FROM #TEMP_PIKDT a
     JOIN (
        SELECT *, SeqNo = ROW_NUMBER() OVER(PARTITION BY DocKey ORDER BY Orderkey)
          FROM #TEMP_PIKDT
     ) b ON a.DocKey = b.DocKey AND b.SeqNo = 1



   ----------
   SELECT Orderkey           = RTRIM( MAX( PIKDT.Orderkey ) )
        , PickslipNo         = RTRIM( MAX( PIKDT.PickslipNo ) )
        , Loadkey            = RTRIM( MAX( PIKDT.Loadkey ) )
        , ConsolPick         = RTRIM( MAX( PIKDT.ConsolPick ) )
        , DocKey             = RTRIM( PIKDT.DocKey )
        , Storerkey          = UPPER( RTRIM( PIKDT.Storerkey ) )
        , Externorderkey     = RTRIM( MAX( PIKDT.Externorderkey ) )
        , C_Contact          = RTRIM( MAX( PIKDT.C_Contact ) )
        , C_Address          = RTRIM( MAX( PIKDT.C_Address ) )
        , C_Phone            = RTRIM( MAX( PIKDT.C_Phone ) )
        , InvoiceNo          = RTRIM( MAX( PIKDT.InvoiceNo ) )
        , InvoiceAmount      = MAX( PIKDT.InvoiceAmount )
        , PmtTerm            = RTRIM( MAX( PIKDT.PmtTerm ) )
        , TermOfSale         = RTRIM( MAX( PIKDT.TermOfSale ) )
        , NH_Number          = RTRIM( MAX( PIKDT.NH_Number ) )
        , TrackingNo         = RTRIM( MAX( PIKDT.TrackingNo ) )
        , TotalWeight        = MAX( PIKDT.TotalWeight )
        , TotalCarton        = RTRIM( MAX( PIKDT.TotalCarton ) )
        , SellerName         = RTRIM( MAX( PIKDT.SellerName ) )
        , SellerAddress      = RTRIM( MAX( PIKDT.SellerAddress ) )
        , SellerPhone        = RTRIM( MAX( PIKDT.SellerPhone ) )
        , ShipFromName       = RTRIM( MAX( PIKDT.ShipFromName ) )
        , ShipFromAddress    = RTRIM( MAX( PIKDT.ShipFromAddress ) )
        , ShipFromPhone      = RTRIM( MAX( PIKDT.ShipFromPhone ) )
        , Carrier            = RTRIM( MAX( PIKDT.Carrier ) )
        , Sku                = RTRIM( PIKDT.Sku )
        , Size               = RTRIM( PIKDT.Size )
        , Descr              = RTRIM( MAX( PIKDT.Descr ) )
        , Qty                = SUM( PIKDT.Qty )
        , UOM                = RTRIM( PIKDT.UOM )
        , HTSCode            = RTRIM( PIKDT.HTSCode )
        , COO                = RTRIM( PIKDT.COO )
        , UnitPrice          = PIKDT.UnitPrice
        , FooterNotes1       = RTRIM( MAX( PIKDT.FooterNotes1 ) )
        , FooterNotes2       = RTRIM( MAX( PIKDT.FooterNotes2 ) )
        , ShowFields         = MAX( RptCfg.ShowFields )
        , GiftUnitPrice      = PIKDT.GiftUnitPrice

   FROM #TEMP_PIKDT PIKDT

   LEFT JOIN (
      SELECT Storerkey, ShowFields = TRIM(UDF01) + LOWER(TRIM(Notes)) + TRIM(UDF01)
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=PIKDT.Storerkey AND RptCfg.SeqNo=1

   GROUP BY PIKDT.Storerkey
          , PIKDT.DocKey
          , PIKDT.Sku
          , PIKDT.Size
          , PIKDT.UOM
          , PIKDT.HTSCode
          , PIKDT.COO
          , PIKDT.UnitPrice
          , PIKDT.GiftUnitPrice

   ORDER BY DocKey, Sku, Size, UOM, UnitPrice, GiftUnitPrice
END

GO