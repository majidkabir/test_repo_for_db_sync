SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_picking_slip_06                            */
/* Creation Date: 23-May-2018                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: WMS-5016 - Rewrite Hyperion Report                           */
/*                     "LFC15b - Picking Slip (Herschel, Nanos)"         */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_picking_slip_06             */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 06/05/2020   ML       1.1  1. Add parameter Loadkey                   */
/*                            2. Handle OH.ECom_Single_Flag              */
/* 04/08/2020   ML       1.2  WMS-14597 - Add InterfaceDate              */
/* 10/09/2020   ML       1.3  Add PickslipNo Barcode                     */
/* 15/03/2021   ML       1.4  WMS-16584 - Add DocType, SpecialHandling   */
/*                                        Delivery Date, OrderType       */
/* 31/03/2021   ML       1.5  Fix PickHeader join issue for Conso order  */
/* 23/03/2022   ML       1.6  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROC [dbo].[isp_r_hk_picking_slip_06] (
       @as_storerkey  NVARCHAR(15)
     , @as_wavekey    NVARCHAR(4000)
     , @as_loadkey    NVARCHAR(4000)
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
      Company, PutawayZone, Wavekey, LoadKey, Courier, EcomSingleFlag, C_Country, OrderKey, ExternOrderKey, PickslipNo
      GiftWrapping, OH_AddDate, OrderType, DocType, SpecialHandling, DeliveryDate, LogicalLocation, Loc, ID, Sku, DESCR

   [MAPVALUE]

   [SHOWFIELD]
      GroupByOrderkey, InterfaceDate, PickslipNo, GiftWrapping, OrderType, DocType, SpecialHandling, DeliveryDate
   [SQLJOIN]
*/
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_PIKDT') IS NOT NULL
      DROP TABLE #TEMP_PIKDT

   DECLARE @c_DataWindow         NVARCHAR(40)   = 'r_hk_picking_slip_06'
         , @c_Storerkey          NVARCHAR(15)
         , @c_CompanyExp         NVARCHAR(MAX)
         , @c_PutawayZoneExp     NVARCHAR(MAX)
         , @c_WavekeyExp         NVARCHAR(MAX)
         , @c_LoadKeyExp         NVARCHAR(MAX)
         , @c_CourierExp         NVARCHAR(MAX)
         , @c_EcomSingleFlagExp  NVARCHAR(MAX)
         , @c_C_CountryExp       NVARCHAR(MAX)
         , @c_OrderKeyExp        NVARCHAR(MAX)
         , @c_ExternOrderKeyExp  NVARCHAR(MAX)
         , @c_PickslipNoExp      NVARCHAR(MAX)
         , @c_GiftWrappingExp    NVARCHAR(MAX)
         , @c_OH_AddDateExp      NVARCHAR(MAX)
         , @c_OrderTypeExp       NVARCHAR(MAX)
         , @c_DocTypeExp         NVARCHAR(MAX)
         , @c_SpecialHandlingExp NVARCHAR(MAX)
         , @c_DeliveryDateExp    NVARCHAR(MAX)
         , @c_LogicalLocationExp NVARCHAR(MAX)
         , @c_LocExp             NVARCHAR(MAX)
         , @c_IDExp              NVARCHAR(MAX)
         , @c_SkuExp             NVARCHAR(MAX)
         , @c_DESCRExp           NVARCHAR(MAX)
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(MAX)

   CREATE TABLE #TEMP_PIKDT (
        Storerkey        NVARCHAR(15)  NULL
      , Company          NVARCHAR(500) NULL
      , PutawayZone      NVARCHAR(500) NULL
      , Wavekey          NVARCHAR(500) NULL
      , LoadKey          NVARCHAR(500) NULL
      , Courier          NVARCHAR(500) NULL
      , EcomSingleFlag   NVARCHAR(500) NULL
      , C_Country        NVARCHAR(500) NULL
      , OrderKey         NVARCHAR(500) NULL
      , ExternOrderKey   NVARCHAR(500) NULL
      , PickslipNo       NVARCHAR(500) NULL
      , GiftWrapping     NVARCHAR(500) NULL
      , OH_AddDate       DATETIME      NULL
      , OrderType        NVARCHAR(500) NULL
      , DocType          NVARCHAR(500) NULL
      , SpecialHandling  NVARCHAR(500) NULL
      , DeliveryDate     NVARCHAR(500) NULL
      , LogicalLocation  NVARCHAR(500) NULL
      , Loc              NVARCHAR(500) NULL
      , ID               NVARCHAR(500) NULL
      , Sku              NVARCHAR(500) NULL
      , DESCR            NVARCHAR(500) NULL
      , Qty              INT           NULL
   )

   -- Final Orderkey, PickslipNo List
   CREATE TABLE #TEMP_FINALORDERKEY (
        Orderkey         NVARCHAR(10)  NULL
      , PickslipNo       NVARCHAR(10)  NULL
      , Loadkey          NVARCHAR(10)  NULL
      , ConsolPick       NVARCHAR(1)   NULL
      , DocKey           NVARCHAR(50)  NULL
      , Storerkey        NVARCHAR(15)  NULL
   )

   SET @c_ExecArguments = N'@as_storerkey NVARCHAR(15)'
                        + ',@as_wavekey   NVARCHAR(4000)'
                        + ',@as_loadkey   NVARCHAR(4000)'
                        + ',@as_orderkey  NVARCHAR(4000)'

   -- Discrete Orders
   SET @c_ExecStatements =
      N'INSERT INTO #TEMP_FINALORDERKEY'
     + ' SELECT Orderkey   = OH.Orderkey'
     +       ', PickslipNo = MAX( PIKHD.PickheaderKey )'
     +       ', Loadkey    = MAX( OH.Loadkey )'
     +       ', ConsolPick = ''N'''
     +       ', DocKey     = MAX( OH.Orderkey )'
     +       ', Storerkey  = MAX( OH.Storerkey )'
     +   ' FROM dbo.ORDERS        OH (NOLOCK)'
     +   ' JOIN dbo.PICKHEADER PIKHD (NOLOCK) ON OH.Orderkey = PIKHD.Orderkey AND OH.Orderkey<>'''''
     +   ' JOIN dbo.PICKDETAIL    PD (NOLOCK) ON OH.OrderKey = PD.OrderKey'
     +  ' WHERE PD.Qty > 0'
     +    ' AND OH.Status <= ''9'''
     +    ' AND OH.Storerkey = @as_storerkey'
   IF (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_loadkey,'')<>'' OR ISNULL(@as_orderkey,'')<>'')
   BEGIN
      IF ISNULL(@as_wavekey,'')<>''
         SET @c_ExecStatements += ' AND ISNULL(OH.Userdefine09,'''')<>'''' AND OH.Userdefine09 IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@as_wavekey,'','')  WHERE value<>'''')'
      IF ISNULL(@as_loadkey,'')<>''
         SET @c_ExecStatements += ' AND ISNULL(OH.LoadKey,'''')<>''''      AND OH.LoadKey      IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@as_loadkey,'','')  WHERE value<>'''')'
      IF ISNULL(@as_orderkey,'')<>''
         SET @c_ExecStatements += ' AND ISNULL(OH.Orderkey,'''')<>''''     AND OH.Orderkey     IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@as_orderkey,'','') WHERE value<>'''')'
   END
   ELSE
   BEGIN
      SET @c_ExecStatements += ' AND (1=2)'
   END
   SET @c_ExecStatements += ' GROUP BY OH.Orderkey'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @as_wavekey
                    , @as_loadkey
                    , @as_orderkey

   -- Consol Orders
   SET @c_ExecStatements =
       N'INSERT INTO #TEMP_FINALORDERKEY'
     + ' SELECT Orderkey   = OH.Orderkey'
     +       ', PickslipNo = MAX( PIKHD.PickheaderKey )'
     +       ', Loadkey    = MAX( OH.Loadkey )'
     +       ', ConsolPick = ''Y'''
     +       ', DocKey     = MAX( OH.Loadkey )'
     +       ', Storerkey  = MAX( OH.Storerkey )'
     +   ' FROM dbo.ORDERS        OH (NOLOCK)'
     +   ' JOIN dbo.PICKHEADER PIKHD (NOLOCK) ON OH.Loadkey = PIKHD.ExternOrderkey AND ISNULL(PIKHD.Orderkey,'''')='''''
     +   ' JOIN dbo.PICKDETAIL    PD (NOLOCK) ON OH.OrderKey = PD.OrderKey'
     +   ' LEFT JOIN #TEMP_FINALORDERKEY  FOK ON OH.Orderkey = FOK.Orderkey'
     +  ' WHERE OH.Loadkey<>'''''
     +    ' AND PD.Qty > 0'
     +    ' AND FOK.Orderkey IS NULL'
   IF (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_loadkey,'')<>'' OR ISNULL(@as_orderkey,'')<>'')
   BEGIN
      IF ISNULL(@as_wavekey,'')<>''
         SET @c_ExecStatements += ' AND ISNULL(OH.Userdefine09,'''')<>'''' AND OH.Userdefine09 IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@as_wavekey,'','')  WHERE value<>'''')'
      IF ISNULL(@as_loadkey,'')<>''
         SET @c_ExecStatements += ' AND ISNULL(OH.LoadKey,'''')<>''''      AND OH.LoadKey      IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@as_loadkey,'','')  WHERE value<>'''')'
      IF ISNULL(@as_orderkey,'')<>''
         SET @c_ExecStatements += ' AND ISNULL(OH.Orderkey,'''')<>''''     AND OH.Orderkey     IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@as_orderkey,'','') WHERE value<>'''')'
   END
   ELSE
   BEGIN
      SET @c_ExecStatements += ' AND (1=2)'
   END
   SET @c_ExecStatements += ' GROUP BY OH.Orderkey'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @as_wavekey
                    , @as_loadkey
                    , @as_orderkey


   -- Storerkey Loop
   DECLARE C_STORER_KEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
     FROM #TEMP_FINALORDERKEY
    ORDER BY 1

   OPEN C_STORER_KEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_STORER_KEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_CompanyExp         = ''
           , @c_PutawayZoneExp     = ''
           , @c_WavekeyExp         = ''
           , @c_LoadKeyExp         = ''
           , @c_CourierExp         = ''
           , @c_EcomSingleFlagExp  = ''
           , @c_C_CountryExp       = ''
           , @c_OrderKeyExp        = ''
           , @c_ExternOrderKeyExp  = ''
           , @c_PickslipNoExp      = ''
           , @c_GiftWrappingExp    = ''
           , @c_OH_AddDateExp      = ''
           , @c_OrderTypeExp       = ''
           , @c_DocTypeExp         = ''
           , @c_SpecialHandlingExp = ''
           , @c_DeliveryDateExp    = ''
           , @c_LogicalLocationExp = ''
           , @c_LocExp             = ''
           , @c_IDExp              = ''
           , @c_SkuExp             = ''
           , @c_DESCRExp           = ''
           , @c_ExecStatements     = ''
           , @c_ExecArguments      = ''
           , @c_JoinClause         = ''

      ----------
      SELECT TOP 1
             @c_JoinClause = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      ----------
      SELECT TOP 1
             @c_CompanyExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Company')), '' )
           , @c_PutawayZoneExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='PutawayZone')), '' )
           , @c_WavekeyExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Wavekey')), '' )
           , @c_LoadKeyExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LoadKey')), '' )
           , @c_CourierExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Courier')), '' )
           , @c_EcomSingleFlagExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='EcomSingleFlag')), '' )
           , @c_C_CountryExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Country')), '' )
           , @c_OrderKeyExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='OrderKey')), '' )
           , @c_ExternOrderKeyExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderKey')), '' )
           , @c_PickslipNoExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='PickslipNo')), '' )
           , @c_GiftWrappingExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='GiftWrapping')), '' )
           , @c_OH_AddDateExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='OH_AddDate')), '' )
           , @c_OrderTypeExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='OrderType')), '' )
           , @c_DocTypeExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DocType')), '' )
           , @c_SpecialHandlingExp = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='SpecialHandling')), '' )
           , @c_DeliveryDateExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DeliveryDate')), '' )
           , @c_LogicalLocationExp = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LogicalLocation')), '' )
           , @c_LocExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Loc')), '' )
           , @c_IDExp              = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ID')), '' )
           , @c_SkuExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Sku')), '' )
           , @c_DESCRExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DESCR')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2




      ----------
      SET @c_ExecStatements = N'INSERT INTO #TEMP_PIKDT'
          +' (Storerkey, Company, PutawayZone, Wavekey, LoadKey, Courier, EcomSingleFlag, C_Country, OrderKey, ExternOrderKey'
          +', PickslipNo, GiftWrapping, OH_AddDate, OrderType, DocType, SpecialHandling, DeliveryDate, LogicalLocation, Loc, ID, Sku, DESCR, Qty)'
          +' SELECT ISNULL( RTRIM( OH.Storerkey ), '''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CompanyExp        ,'')<>'' THEN @c_CompanyExp         ELSE 'ST.Company'                 END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PutawayZoneExp    ,'')<>'' THEN @c_PutawayZoneExp     ELSE 'LOC.PutawayZone'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_WavekeyExp        ,'')<>'' THEN @c_WavekeyExp         ELSE 'OH.UserDefine09'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LoadKeyExp        ,'')<>'' THEN @c_LoadKeyExp         ELSE 'OH.LoadKey'                 END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CourierExp        ,'')<>'' THEN @c_CourierExp         ELSE 'OH.ShipperKey'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_EcomSingleFlagExp ,'')<>'' THEN @c_EcomSingleFlagExp  ELSE 'UPPER( CASE OH.ECOM_SINGLE_FLAG WHEN ''S'' THEN ''SINGLE'' WHEN ''M'' THEN ''MULTI'' ELSE OH.ECOM_SINGLE_FLAG END)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_CountryExp      ,'')<>'' THEN @c_C_CountryExp       ELSE
          +                   ' STUFF((SELECT DISTINCT '', ''+ISNULL(TRIM(a.C_Country),'''')'
          +                          ' FROM dbo.ORDERS a(NOLOCK)'
          +                          ' JOIN dbo.PICKDETAIL b(NOLOCK) ON a.Orderkey=b.Orderkey'
          +                          ' JOIN dbo.LOC c(NOLOCK) ON b.Loc=c.Loc'
          +                          ' WHERE a.StorerKey = OH.Storerkey'
          +                            ' AND c.PutawayZone = LOC.PutawayZone'
          +                            ' AND a.UserDefine09 = OH.Userdefine09'
          +                            ' AND a.Loadkey = OH.Loadkey'
          +                            ' AND a.ECOM_SINGLE_FLAG = OH.ECOM_SINGLE_FLAG'
          +                            ' AND a.ShipperKey = OH.ShipperKey'
          +                            ' AND ISNULL(a.C_Country,'''')<>'''''
          +                         ' ORDER BY 1'
          +                         ' FOR XML PATH('''')), 1, 2, '''')'
                                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_OrderKeyExp       ,'')<>'' THEN @c_OrderKeyExp        ELSE 'OH.OrderKey'                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExternOrderKeyExp ,'')<>'' THEN @c_ExternOrderKeyExp  ELSE 'OH.ExternOrderKey'          END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PickslipNoExp     ,'')<>'' THEN @c_PickslipNoExp      ELSE 'PH.PickheaderKey'           END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_GiftWrappingExp   ,'')<>'' THEN @c_GiftWrappingExp    ELSE ''''''                       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', '              + CASE WHEN ISNULL(@c_OH_AddDateExp     ,'')<>'' THEN @c_OH_AddDateExp      ELSE 'OH.AddDate'                 END
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_OrderTypeExp      ,'')<>'' THEN @c_OrderTypeExp       ELSE 'OH.Type'                    END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DocTypeExp        ,'')<>'' THEN @c_DocTypeExp         ELSE 'OH.DocType'                 END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SpecialHandlingExp,'')<>'' THEN @c_SpecialHandlingExp ELSE 'OH.SpecialHandling'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DeliveryDateExp   ,'')<>'' THEN @c_DeliveryDateExp    ELSE
          +                   ' STUFF((SELECT DISTINCT '', ''+CONVERT(NVARCHAR(10),a.DeliveryDate,120)'
          +                          ' FROM dbo.ORDERS a(NOLOCK)'
          +                          ' WHERE a.StorerKey = OH.Storerkey'
          +                            ' AND a.UserDefine09 = OH.Userdefine09'
          +                            ' AND a.Loadkey = OH.Loadkey'
          +                            ' AND a.ECOM_SINGLE_FLAG = OH.ECOM_SINGLE_FLAG'
          +                            ' AND a.ShipperKey = OH.ShipperKey'
          +                            ' AND a.DeliveryDate IS NOT NULL'
          +                         ' ORDER BY 1'
          +                         ' FOR XML PATH('''')), 1, 2, '''')'
                                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LogicalLocationExp,'')<>'' THEN @c_LogicalLocationExp ELSE 'UPPER(LOC.LogicalLocation)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LocExp            ,'')<>'' THEN @c_LocExp             ELSE 'UPPER(PD.Loc)'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_IDExp             ,'')<>'' THEN @c_IDExp              ELSE 'PD.ID'                      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SkuExp            ,'')<>'' THEN @c_SkuExp             ELSE 'PD.Sku'                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DESCRExp          ,'')<>'' THEN @c_DESCRExp           ELSE 'SKU.DESCR'                  END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', Qty             = PD.Qty'
      SET @c_ExecStatements = @c_ExecStatements
          +' FROM #TEMP_FINALORDERKEY FOK'
          +' JOIN dbo.ORDERS          OH (NOLOCK) ON FOK.Orderkey = OH.Orderkey'
          +' JOIN dbo.PICKDETAIL      PD (NOLOCK) ON OH.OrderKey = PD.OrderKey'
          +' JOIN dbo.PICKHEADER      PH (NOLOCK) ON FOK.PickslipNo = PH.PickHeaderkey'
          +' JOIN dbo.SKU             SKU(NOLOCK) ON PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku'
          +' JOIN dbo.LOC             LOC(NOLOCK) ON PD.Loc = LOC.Loc'
          +' JOIN dbo.STORER          ST (NOLOCK) ON OH.StorerKey = ST.StorerKey'
          +' LEFT JOIN dbo.ORDERINFO  OI (NOLOCK) ON OH.OrderKey = OI.OrderKey'
      SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END
      SET @c_ExecStatements = @c_ExecStatements
          +' WHERE PD.Qty > 0 AND OH.Storerkey=@c_Storerkey'

      SET @c_ExecArguments = N'@c_Storerkey         NVARCHAR(15)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Storerkey
   END

   CLOSE C_STORER_KEY
   DEALLOCATE C_STORER_KEY



   ----------
   SELECT Storerkey       = X.Storerkey
        , Company         = MAX( X.Company )
        , Wavekey         = X.Wavekey
        , LoadKey         = X.LoadKey
        , Courier         = X.Courier
        , PmtTerm         = X.EcomSingleFlag
        , Section         = SN.Section
        , C_Country       = IIF( SN.Section=1, MAX( X.C_Country ), '')
        , OrderKey        = IIF( SN.Section=1, X.OrderKey, '')
        , ExternOrderKey  = IIF( SN.Section=1, X.ExternOrderKey, '')
        , PickslipNo      = IIF( SN.Section=1, MAX( X.PickslipNo ), '')
        , GiftWrapping    = IIF( SN.Section=1, X.GiftWrapping, '' )
        , OH_AddDate      = IIF( SN.Section=1, MAX( X.OH_AddDate ), NULL)
        , DocType         = IIF( SN.Section=1, MAX( X.DocType ), '' )
        , SpecialHandling = IIF( SN.Section=1, MAX( X.SpecialHandling ), '' )
        , PutawayZone     = IIF( SN.Section=2, X.PutawayZone, '')
        , LogicalLocation = IIF( SN.Section=2, X.LogicalLocation, '')
        , Loc             = IIF( SN.Section=2, X.Loc, '')
        , ID              = IIF( SN.Section=2, X.ID, '')
        , Sku             = IIF( SN.Section=2, X.Sku, '')
        , DESCR           = IIF( SN.Section=2, MAX( X.DESCR ), '')
        , Qty             = SUM( X.Qty )
        , GroupByOrderkey = CASE WHEN CHARINDEX(',GroupByOrderkey,', RptCfg.ShowFields)>0 AND ISNULL(X.EcomSingleFlag,'')='MULTI' THEN X.Orderkey ELSE ''             END
        , GroupByPAZone   = CASE WHEN CHARINDEX(',GroupByOrderkey,', RptCfg.ShowFields)>0 AND ISNULL(X.EcomSingleFlag,'')='MULTI' THEN ''         ELSE X.PutawayZone  END
        , ShowFields      = MAX( RptCfg.ShowFields )
        , DeliveryDate    = IIF( SN.Section=1, MAX( X.DeliveryDate ), '')
        , OrderType       = IIF( SN.Section=1, MAX( X.OrderType ), '')

   FROM (
      SELECT *
           , SeqNo = ROW_NUMBER() OVER(PARTITION BY PutawayZone, Orderkey ORDER BY Sku)
      FROM #TEMP_PIKDT
   ) X
   JOIN (SELECT Section = 1 UNION SELECT 2) SN ON 1=1

   LEFT JOIN (
      SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=X.Storerkey AND RptCfg.SeqNo=1

   GROUP BY X.Storerkey
          , X.Wavekey
          , X.LoadKey
          , X.Courier
          , X.EcomSingleFlag
          , SN.Section
          , IIF( SN.Section=1, X.OrderKey, '')
          , IIF( SN.Section=1, X.ExternOrderKey, '')
          , IIF( SN.Section=1, X.GiftWrapping, '' )
          , IIF( SN.Section=2, X.PutawayZone, '')
          , IIF( SN.Section=2, X.LogicalLocation, '')
          , IIF( SN.Section=2, X.Loc, '')
          , IIF( SN.Section=2, X.ID, '')
          , IIF( SN.Section=2, X.Sku, '')
          , CASE WHEN CHARINDEX(',GroupByOrderkey,', RptCfg.ShowFields)>0 AND ISNULL(X.EcomSingleFlag,'')='MULTI' THEN X.Orderkey ELSE ''             END
          , CASE WHEN CHARINDEX(',GroupByOrderkey,', RptCfg.ShowFields)>0 AND ISNULL(X.EcomSingleFlag,'')='MULTI' THEN ''         ELSE X.PutawayZone  END

   ORDER BY Storerkey, PutawayZone, PmtTerm, Courier, Wavekey, Loadkey, Section, LogicalLocation, Loc, ID, Sku
END

GO