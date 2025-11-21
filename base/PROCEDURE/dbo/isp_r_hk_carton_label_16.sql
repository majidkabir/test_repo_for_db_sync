SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_carton_label_16                            */
/* Creation Date: 09-Feb-2021                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Carton Label                                                 */
/*                                                                       */
/* Called By: RCM Report. Datawidnow r_hk_carton_label_16                */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 23/03/2022   ML       1.2  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_carton_label_16] (
       @as_pickslipno      NVARCHAR(20)         -- PickslipNo       / Storerkey
     , @as_startcartonno   NVARCHAR(20)         -- Start CartonNo   / Orderkey
     , @as_endcartonno     NVARCHAR(20)         -- End CartonNo     /
     , @as_startlabelno    NVARCHAR(20) = ''    -- Start LabelNo    /
     , @as_endlabelno      NVARCHAR(20) = ''    -- End LabelNo      /
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      ExternOrderkey, Trackingno, C_Address, C_Zip, C_Contact1, C_Phone1, B_Company, B_Address, B_Phone1, CurrencyCode
      InvoiceAmount, ShipOrigin, Destination, SF_AccountNo, SkuDescr, Qty, ShipDate, TotalCarton

   [MAPVALUE]

   [SHOWFIELD]

   [SQLJOIN]
*/

   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY2') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY2
   IF OBJECT_ID('tempdb..#TEMP_PAKDT') IS NOT NULL
      DROP TABLE #TEMP_PAKDT

   DECLARE @c_DataWindow         NVARCHAR(40)
         , @c_ExternOrderkeyExp  NVARCHAR(MAX)
         , @c_TrackingnoExp      NVARCHAR(MAX)
         , @c_C_AddressExp       NVARCHAR(MAX)
         , @c_C_ZipExp           NVARCHAR(MAX)
         , @c_C_Contact1Exp      NVARCHAR(MAX)
         , @c_C_Phone1Exp        NVARCHAR(MAX)
         , @c_B_CompanyExp       NVARCHAR(MAX)
         , @c_B_AddressExp       NVARCHAR(MAX)
         , @c_B_Phone1Exp        NVARCHAR(MAX)
         , @c_CurrencyCodeExp    NVARCHAR(MAX)
         , @c_InvoiceAmountExp   NVARCHAR(MAX)
         , @c_ShipOriginExp      NVARCHAR(MAX)
         , @c_DestinationExp     NVARCHAR(MAX)
         , @c_SF_AccountNoExp    NVARCHAR(MAX)
         , @c_SkuDescrExp        NVARCHAR(MAX)
         , @c_QtyExp             NVARCHAR(MAX)
         , @c_ShipDateExp        NVARCHAR(MAX)
         , @c_TotalCartonExp     NVARCHAR(MAX)
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(MAX)
         , @c_Storerkey          NVARCHAR(15)
         , @n_CartonNoFrom       INT = 0
         , @n_CartonNoTo         INT = 0
         , @b_FromPackModule     INT = 0

   SELECT @c_DataWindow = 'r_hk_carton_label_16'

   CREATE TABLE #TEMP_PAKDT (
        PickslipNo       NVARCHAR(18)  NULL
      , Storerkey        NVARCHAR(15)  NULL
      , Orderkey         NVARCHAR(10)  NULL
      , ExternOrderkey   NVARCHAR(500) NULL
      , Trackingno       NVARCHAR(500) NULL
      , C_Address        NVARCHAR(500) NULL
      , C_Zip            NVARCHAR(500) NULL
      , C_Contact1       NVARCHAR(500) NULL
      , C_Phone1         NVARCHAR(500) NULL
      , B_Company        NVARCHAR(500) NULL
      , B_Address        NVARCHAR(500) NULL
      , B_Phone1         NVARCHAR(500) NULL
      , CurrencyCode     NVARCHAR(500) NULL
      , InvoiceAmount    NVARCHAR(500) NULL
      , ShipOrigin       NVARCHAR(500) NULL
      , Destination      NVARCHAR(500) NULL
      , SF_AccountNo     NVARCHAR(500) NULL
      , SkuDescr         NVARCHAR(500) NULL
      , Qty              INT           NULL
      , ShipDate         DATE          NULL
      , TotalCarton      INT           NULL
      , CartonNo         INT           NULL
   )

   -- Final Orderkey
   CREATE TABLE #TEMP_FINALORDERKEY (
        PickslipNo       NVARCHAR(10)  NULL
      , Orderkey         NVARCHAR(10)  NULL
      , Loadkey          NVARCHAR(10)  NULL
      , ConsolPick       NVARCHAR(1)   NULL
      , Storerkey        NVARCHAR(15)  NULL
   )

   IF EXISTS( SELECT TOP 1 1 FROM dbo.ORDERS (NOLOCK) WHERE Storerkey = @as_pickslipno AND Orderkey = @as_startcartonno)
   BEGIN
      -- From View Report / RDT
      INSERT INTO #TEMP_FINALORDERKEY(Orderkey, PickslipNo, Loadkey, ConsolPick, Storerkey)
      SELECT OH.Orderkey
           , PH.PickHeaderkey
           , OH.Loadkey
           , 'N'
           , OH.Storerkey
        FROM dbo.PICKHEADER PH (NOLOCK)
        JOIN dbo.ORDERS     OH (NOLOCK) ON PH.Orderkey = OH.Orderkey AND ISNULL(PH.Orderkey,'')<>''
       WHERE OH.Storerkey = @as_pickslipno AND OH.Orderkey = @as_startcartonno

      INSERT INTO #TEMP_FINALORDERKEY(Orderkey, PickslipNo, Loadkey, ConsolPick, Storerkey)
      SELECT OH.Orderkey
           , PH.PickHeaderkey
           , OH.Loadkey
           , 'Y'
           , OH.Storerkey
        FROM dbo.PICKHEADER PH (NOLOCK)
        JOIN dbo.ORDERS     OH (NOLOCK) ON PH.Loadkey = OH.Loadkey AND ISNULL(PH.Loadkey,'')<>'' AND ISNULL(PH.Orderkey,'')=''
        LEFT JOIN #TEMP_FINALORDERKEY FOK ON PH.PickHeaderkey = FOK.PickslipNo
       WHERE OH.Storerkey = @as_pickslipno AND OH.Orderkey = @as_startcartonno
         AND FOK.Orderkey IS NULL
   END
   ELSE
   BEGIN
      -- From Pack Module
      SELECT @b_FromPackModule = 1
           , @n_CartonNoFrom   = ISNULL( IIF(ISNULL(@as_startcartonno,'')='', 0, TRY_PARSE(@as_startcartonno AS FLOAT)), 0 )
           , @n_CartonNoTo     = ISNULL( IIF(ISNULL(@as_endcartonno  ,'')='', 0, TRY_PARSE(@as_endcartonno   AS FLOAT)), 0 )

      INSERT INTO #TEMP_FINALORDERKEY(Orderkey, PickslipNo, Loadkey, ConsolPick, Storerkey)
      SELECT OH.Orderkey
           , PH.PickHeaderkey
           , OH.Loadkey
           , 'N'
           , OH.Storerkey
        FROM dbo.PICKHEADER PH (NOLOCK)
        JOIN dbo.ORDERS     OH (NOLOCK) ON PH.Orderkey = OH.Orderkey AND ISNULL(PH.Orderkey,'')<>''
       WHERE PH.PickHeaderkey = @as_PickSlipNo

      INSERT INTO #TEMP_FINALORDERKEY(Orderkey, PickslipNo, Loadkey, ConsolPick, Storerkey)
      SELECT OH.Orderkey
           , PH.PickHeaderkey
           , OH.Loadkey
           , 'Y'
           , OH.Storerkey
        FROM dbo.PICKHEADER PH (NOLOCK)
        JOIN dbo.ORDERS     OH (NOLOCK) ON PH.Loadkey = OH.Loadkey AND ISNULL(PH.Loadkey,'')<>'' AND ISNULL(PH.Orderkey,'')=''
        LEFT JOIN #TEMP_FINALORDERKEY FOK ON PH.PickHeaderkey = FOK.PickslipNo
       WHERE PH.PickHeaderkey = @as_PickSlipNo
         AND FOK.Orderkey IS NULL
   END


   SELECT DISTINCT
          PickslipNo        = FOK.PickslipNo
        , Orderkey          = FIRST_VALUE(FOK.Orderkey)   OVER(PARTITION BY FOK.PickslipNo ORDER BY FOK.Orderkey)
        , Loadkey           = FIRST_VALUE(FOK.Loadkey)    OVER(PARTITION BY FOK.PickslipNo ORDER BY FOK.Orderkey)
        , ConsolPick        = FIRST_VALUE(FOK.ConsolPick) OVER(PARTITION BY FOK.PickslipNo ORDER BY FOK.Orderkey)
        , Storerkey         = FIRST_VALUE(FOK.Storerkey)  OVER(PARTITION BY FOK.PickslipNo ORDER BY FOK.Orderkey)
     INTO #TEMP_FINALORDERKEY2
     FROM #TEMP_FINALORDERKEY FOK


   -- Storerkey Loop
   DECLARE CUR_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
     FROM #TEMP_FINALORDERKEY2
    ORDER BY 1

   OPEN CUR_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM CUR_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_ExternOrderkeyExp  = ''
           , @c_TrackingnoExp      = ''
           , @c_C_AddressExp       = ''
           , @c_C_ZipExp           = ''
           , @c_C_Contact1Exp      = ''
           , @c_C_Phone1Exp        = ''
           , @c_B_CompanyExp       = ''
           , @c_B_AddressExp       = ''
           , @c_B_Phone1Exp        = ''
           , @c_CurrencyCodeExp    = ''
           , @c_InvoiceAmountExp   = ''
           , @c_ShipOriginExp      = ''
           , @c_DestinationExp     = ''
           , @c_SF_AccountNoExp    = ''
           , @c_SkuDescrExp        = ''
           , @c_QtyExp             = ''
           , @c_ShipDateExp        = ''
           , @c_TotalCartonExp     = ''
           , @c_JoinClause         = ''

      SELECT TOP 1
             @c_JoinClause  = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_ExternOrderkeyExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderkey')), '' )
           , @c_TrackingnoExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Trackingno')), '' )
           , @c_C_AddressExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Address')), '' )
           , @c_C_ZipExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Zip')), '' )
           , @c_C_Contact1Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Contact1')), '' )
           , @c_C_Phone1Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Phone1')), '' )
           , @c_B_CompanyExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Company')), '' )
           , @c_B_AddressExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Address')), '' )
           , @c_B_Phone1Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Phone1')), '' )
           , @c_CurrencyCodeExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='CurrencyCode')), '' )
           , @c_InvoiceAmountExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='InvoiceAmount')), '' )
           , @c_ShipOriginExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ShipOrigin')), '' )
           , @c_DestinationExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Destination')), '' )
           , @c_SF_AccountNoExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='SF_AccountNo')), '' )
           , @c_SkuDescrExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='SkuDescr')), '' )
           , @c_QtyExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Qty')), '' )
           , @c_ShipDateExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ShipDate')), '' )
           , @c_TotalCartonExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='TotalCarton')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      ----------
      SET @c_ExecStatements = N'INSERT INTO #TEMP_PAKDT'
          +' (PickslipNo, CartonNo, Storerkey, Orderkey, ExternOrderkey, Trackingno, C_Address, C_Zip, C_Contact1, C_Phone1'
          +', B_Company, B_Address, B_Phone1, CurrencyCode, InvoiceAmount, ShipOrigin, Destination, SF_AccountNo, SkuDescr, Qty'
          +', ShipDate, TotalCarton)'
          +' SELECT FOK.PickslipNo'
               + ', ' + CASE WHEN @b_FromPackModule = 1 THEN 'PD.CartonNo' ELSE '0' END
               + ', OH.Storerkey'
               + ', OH.OrderKey'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_ExternOrderkeyExp,'')<>'' THEN @c_ExternOrderkeyExp ELSE 'OH.ExternOrderkey' END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_TrackingnoExp    ,'')<>'' THEN @c_TrackingnoExp     ELSE 'OH.Trackingno'     END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_AddressExp     ,'')<>'' THEN @c_C_AddressExp
                                     ELSE 'TRIM(TRIM(TRIM(TRIM(ISNULL(OH.C_Address1,''''))+'' ''+TRIM(ISNULL(OH.C_Address2,'''')))+'' ''+TRIM(ISNULL(OH.C_Address3,'''')))+'' ''+TRIM(ISNULL(OH.C_Address4,'''')))' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_ZipExp         ,'')<>'' THEN @c_C_ZipExp
                                     ELSE 'TRIM(TRIM(TRIM(TRIM(ISNULL(OH.C_City,''''))+'' ''+TRIM(ISNULL(OH.C_State,'''')))+'' ''+TRIM(ISNULL(OH.C_Zip,'''')))+'' ''+TRIM(ISNULL(OH.C_Country,'''')))' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Contact1Exp    ,'')<>'' THEN @c_C_Contact1Exp     ELSE 'OH.C_Contact1'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Phone1Exp      ,'')<>'' THEN @c_C_Phone1Exp       ELSE 'OH.C_Phone1'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_CompanyExp     ,'')<>'' THEN @c_B_CompanyExp      ELSE 'ST.B_Company'      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_AddressExp     ,'')<>'' THEN @c_B_AddressExp
                                     ELSE 'TRIM(TRIM(TRIM(TRIM(TRIM(ISNULL(ST.B_Address1,''''))+'' ''+TRIM(ISNULL(ST.B_Address2,'''')))+'' ''+TRIM(ISNULL(ST.B_Address3,'''')))+'' ''+TRIM(ISNULL(ST.B_Address4,'''')))+'' ''+TRIM(ISNULL(ST.B_City,'''')))'
                                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_Phone1Exp      ,'')<>'' THEN @c_B_Phone1Exp       ELSE 'ST.B_Phone1'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CurrencyCodeExp  ,'')<>'' THEN @c_CurrencyCodeExp   ELSE 'CASE WHEN OH.CurrencyCode = ''TWD'' THEN ''NTD'' ELSE OH.currencycode END' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_InvoiceAmountExp ,'')<>'' THEN @c_InvoiceAmountExp  ELSE 'OH.InvoiceAmount'  END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ShipOriginExp    ,'')<>'' THEN @c_ShipOriginExp     ELSE 'OI.OrderInfo09'    END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DestinationExp   ,'')<>'' THEN @c_DestinationExp    ELSE 'OI.OrderInfo10'    END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SF_AccountNoExp  ,'')<>'' THEN @c_SF_AccountNoExp   ELSE 'SF_PREF.UDF01'          END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SkuDescrExp      ,'')<>'' THEN @c_SkuDescrExp       ELSE 'SKU.Descr'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               +              ', ' + CASE WHEN ISNULL(@c_QtyExp           ,'')<>'' THEN @c_QtyExp            ELSE 'PD.Qty'            END
      SET @c_ExecStatements = @c_ExecStatements
               +              ', ' + CASE WHEN ISNULL(@c_ShipDateExp      ,'')<>'' THEN @c_ShipDateExp       ELSE 'DATEADD(DAY,1,GETDATE())' END
      SET @c_ExecStatements = @c_ExecStatements
               +              ', ' + CASE WHEN ISNULL(@c_TotalCartonExp   ,'')<>'' THEN @c_TotalCartonExp    ELSE '1'                 END

      SET @c_ExecStatements = @c_ExecStatements
          +' FROM #TEMP_FINALORDERKEY2 FOK'
          +' JOIN dbo.ORDERS         OH (NOLOCK) ON FOK.Orderkey=OH.Orderkey'
          +' JOIN dbo.STORER         ST (NOLOCK) ON ST.Storerkey=OH.Storerkey'
          +' JOIN dbo.PACKDETAIL     PD (NOLOCK) ON FOK.PickslipNo=PD.PickslipNo'
          +' JOIN dbo.SKU            SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku'
          +' LEFT JOIN dbo.ORDERINFO OI (NOLOCK) ON OI.Orderkey=OH.Orderkey'
          +' LEFT JOIN dbo.PACKINFO  PI (NOLOCK) ON PD.PickslipNo=PI.PickslipNo AND PD.CartonNo=PI.CartonNo'
          +' LEFT JOIN ('
          +    'SELECT *, SeqNo=ROW_NUMBER() OVER(PARTITION BY a.Storerkey ORDER BY a.Code, a.Code2)'
          +     ' FROM dbo.CODELKUP a(NOLOCK) WHERE a.LISTNAME=''SF_PREF'''
          + ') SF_PREF ON SF_PREF.Storerkey=OH.Storerkey AND SF_PREF.SeqNo=1'

      SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END

      SET @c_ExecStatements = @c_ExecStatements
          +' WHERE OH.Storerkey=@c_Storerkey'
          +  ' AND PD.Qty > 0'

      IF @b_FromPackModule = 1
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
             +  ' AND PD.CartonNo >= @n_CartonNoFrom'
             +  ' AND PD.CartonNo <= @n_CartonNoTo'
         IF ISNULL(@as_startlabelno,'')<>'' OR ISNULL(@as_endlabelno,'')<>''
            SET @c_ExecStatements = @c_ExecStatements
                +  ' AND PD.LabelNo >= ISNULL(@as_startlabelno,'''')'
                +  ' AND PD.LabelNo <= ISNULL(@as_endlabelno,'''')'
      END

      SET @c_ExecArguments = N'@c_Storerkey     NVARCHAR(15)'
                           + ',@n_CartonNoFrom  INT'
                           + ',@n_CartonNoTo    INT'
                           + ',@as_startlabelno NVARCHAR(20)'
                           + ',@as_endlabelno   NVARCHAR(20)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Storerkey
                       , @n_CartonNoFrom
                       , @n_CartonNoTo
                       , @as_startlabelno
                       , @as_endlabelno
   END

   CLOSE CUR_STORERKEY
   DEALLOCATE CUR_STORERKEY



   SELECT PickSlipNo       = RTRIM( PAKDT.PickSlipNo )
        , CartonNo         = PAKDT.CartonNo
        , Storerkey        = RTRIM( MAX( PAKDT.Storerkey ) )
        , Orderkey         = RTRIM( MAX( PAKDT.Orderkey ) )
        , ExternOrderkey   = RTRIM( MAX( PAKDT.ExternOrderkey ) )
        , Trackingno       = RTRIM( MAX( PAKDT.Trackingno ) )
        , C_Address        = RTRIM( MAX( PAKDT.C_Address ) )
        , C_Zip            = RTRIM( MAX( PAKDT.C_Zip ) )
        , C_Contact1       = RTRIM( MAX( PAKDT.C_Contact1 ) )
        , C_Phone1         = RTRIM( MAX( PAKDT.C_Phone1 ) )
        , B_Company        = RTRIM( MAX( PAKDT.B_Company ) )
        , B_Address        = RTRIM( MAX( PAKDT.B_Address ) )
        , B_Phone1         = RTRIM( MAX( PAKDT.B_Phone1 ) )
        , CurrencyCode     = RTRIM( MAX( PAKDT.CurrencyCode ) )
        , InvoiceAmount    = RTRIM( MAX( PAKDT.InvoiceAmount ) )
        , ShipOrigin       = RTRIM( MAX( PAKDT.ShipOrigin ) )
        , Destination      = RTRIM( MAX( PAKDT.Destination ) )
        , SF_AccountNo     = RTRIM( MAX( PAKDT.SF_AccountNo ) )
        , SkuDescr         = RTRIM( CAST( ISNULL( STUFF((SELECT DISTINCT ' '+TRIM(ISNULL(a.SkuDescr,''))
                                    FROM #TEMP_PAKDT a
                                    WHERE a.PickslipNo = PAKDT.PickslipNo AND a.CartonNo = PAKDT.CartonNo
                                    FOR XML PATH('')),1,1,''), '') AS NVARCHAR(500) ) )
        , Qty              = SUM( PAKDT.Qty )
        , ShipDate         = MAX( PAKDT.ShipDate )
        , TotalCarton      = MAX( PAKDT.TotalCarton )

   FROM #TEMP_PAKDT PAKDT

   LEFT JOIN (
      SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=PAKDT.Storerkey AND RptCfg.SeqNo=1

   GROUP BY PAKDT.PickSlipNo
          , PAKDT.CartonNo
END

GO