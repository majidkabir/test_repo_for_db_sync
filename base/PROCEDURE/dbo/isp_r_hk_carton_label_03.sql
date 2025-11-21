SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_carton_label_03                            */
/* Creation Date: 19-Jan-2021                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Carton Label                                                 */
/*                                                                       */
/* Called By: RCM Report. Datawidnow r_hk_carton_label_03                */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 12/08/2021   ML       1.1  WMS-17709                                  */
/*                            1. Add new fields:                         */
/*                               T_Carton, T_TotalQty, T_ToCustomer,     */
/*                               T_CompanyFrom, Indicator1, Indicator2   */
/*                               Indicator3                              */
/*                            2. Fix incorrect CartonMax issue           */
/* 23/03/2022   ML       1.2  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_carton_label_03] (
       @as_pickslipno      NVARCHAR(10)
     , @as_startcartonno   NVARCHAR(10)
     , @as_endcartonno     NVARCHAR(10)
     , @as_startlabelno    NVARCHAR(20) = ''
     , @as_endlabelno      NVARCHAR(20) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      LabelNo, DocNum, DocKey, InvoiceNo, CartonNo, TotalQty, RefNo, Userdefine04
      C_Company, C_Address1, C_Address2, C_Address3, C_Address4, C_Zip, C_Country, Route, CompanyFrom, DropID, ExtraBarcode
      T_DocNum, T_DocKey, T_InvoiceNo, T_RefNo, T_Userdefine04, T_Carton, T_TotalQty, T_ToCustomer, T_CompanyFrom
      Indicator1, Indicator2, Indicator3

   [MAPVALUE]
      T_DocNum, T_DocNum_Conso, T_DocKey, T_DocKey_Conso, T_InvoiceNo, T_InvoiceNo_Conso, T_RefNo, T_Userdefine04
      T_Carton, T_TotalQty, T_ToCustomer, T_CompanyFrom

   [SHOWFIELD]
      FromCust, ExtraBarcode_HR

   [SQLJOIN]
*/

   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY2') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY2
   IF OBJECT_ID('tempdb..#TEMP_PAKDT') IS NOT NULL
      DROP TABLE #TEMP_PAKDT

   DECLARE @c_DataWindow         NVARCHAR(40)
         , @c_LabelNoExp         NVARCHAR(MAX)
         , @c_DocNumExp          NVARCHAR(MAX)
         , @c_DocKeyExp          NVARCHAR(MAX)
         , @c_InvoiceNoExp       NVARCHAR(MAX)
         , @c_CartonNoExp        NVARCHAR(MAX)
         , @c_TotalQtyExp        NVARCHAR(MAX)
         , @c_RefNoExp           NVARCHAR(MAX)
         , @c_Userdefine04Exp    NVARCHAR(MAX)
         , @c_C_CompanyExp       NVARCHAR(MAX)
         , @c_C_Address1Exp      NVARCHAR(MAX)
         , @c_C_Address2Exp      NVARCHAR(MAX)
         , @c_C_Address3Exp      NVARCHAR(MAX)
         , @c_C_Address4Exp      NVARCHAR(MAX)
         , @c_C_ZipExp           NVARCHAR(MAX)
         , @c_C_CountryExp       NVARCHAR(MAX)
         , @c_RouteExp           NVARCHAR(MAX)
         , @c_CompanyFromExp     NVARCHAR(MAX)
         , @c_DropIDExp          NVARCHAR(MAX)
         , @c_ExtraBarcodeExp    NVARCHAR(MAX)
         , @c_Indicator1Exp      NVARCHAR(MAX)
         , @c_Indicator2Exp      NVARCHAR(MAX)
         , @c_Indicator3Exp      NVARCHAR(MAX)
         , @c_T_DocNumExp        NVARCHAR(MAX)
         , @c_T_DocKeyExp        NVARCHAR(MAX)
         , @c_T_InvoiceNoExp     NVARCHAR(MAX)
         , @c_T_RefNoExp         NVARCHAR(MAX)
         , @c_T_Userdefine04Exp  NVARCHAR(MAX)
         , @c_T_CartonExp        NVARCHAR(MAX)
         , @c_T_TotalQtyExp      NVARCHAR(MAX)
         , @c_T_ToCustomerExp    NVARCHAR(MAX)
         , @c_T_CompanyFromExp   NVARCHAR(MAX)
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(MAX)
         , @c_Storerkey          NVARCHAR(15)
         , @n_CartonNoFrom       INT
         , @n_CartonNoTo         INT

   SELECT @c_DataWindow = 'r_hk_carton_label_03'
        , @n_CartonNoFrom = ISNULL( IIF(ISNULL(@as_startcartonno,'')='', 0, TRY_PARSE(@as_startcartonno AS FLOAT)), 0 )
        , @n_CartonNoTo   = ISNULL( IIF(ISNULL(@as_endcartonno  ,'')='', 0, TRY_PARSE(@as_endcartonno   AS FLOAT)), 0 )

   CREATE TABLE #TEMP_PAKDT (
        PickslipNo       NVARCHAR(18)  NULL
      , Orderkey         NVARCHAR(10)  NULL
      , ExternOrderKey   NVARCHAR(50)  NULL
      , Storerkey        NVARCHAR(15)  NULL
      , Loadkey          NVARCHAR(10)  NULL
      , DocNum           NVARCHAR(50)  NULL
      , DocKey           NVARCHAR(50)  NULL
      , InvoiceNo        NVARCHAR(50)  NULL
      , RefNo            NVARCHAR(50)  NULL
      , Userdefine04     NVARCHAR(50)  NULL
      , C_Company        NVARCHAR(500) NULL
      , C_Address1       NVARCHAR(500) NULL
      , C_Address2       NVARCHAR(500) NULL
      , C_Address3       NVARCHAR(500) NULL
      , C_Address4       NVARCHAR(500) NULL
      , C_Zip            NVARCHAR(500) NULL
      , C_Country        NVARCHAR(500) NULL
      , Route            NVARCHAR(500) NULL
      , CompanyFrom      NVARCHAR(50)  NULL
      , DropID           NVARCHAR(50)  NULL
      , ExtraBarcode     NVARCHAR(50)  NULL
      , T_DocNum         NVARCHAR(50)  NULL
      , T_DocKey         NVARCHAR(50)  NULL
      , T_InvoiceNo      NVARCHAR(50)  NULL
      , T_RefNo          NVARCHAR(50)  NULL
      , T_Userdefine04   NVARCHAR(50)  NULL
      , T_Carton         NVARCHAR(50)  NULL
      , T_TotalQty       NVARCHAR(50)  NULL
      , T_ToCustomer     NVARCHAR(50)  NULL
      , T_CompanyFrom    NVARCHAR(50)  NULL
      , Indicator1       NVARCHAR(50)  NULL
      , Indicator2       NVARCHAR(50)  NULL
      , Indicator3       NVARCHAR(50)  NULL
      , LabelNo          NVARCHAR(50)  NULL
      , CartonNoStr      NVARCHAR(50)  NULL
      , TotalQty         INT           NULL
      , CartonNo         INT           NULL
      , CartonMax        INT           NULL
      , ConsolPick       NVARCHAR(1)   NULL
   )

   -- Final Orderkey
   CREATE TABLE #TEMP_FINALORDERKEY (
        PickslipNo       NVARCHAR(10) NULL
      , Orderkey         NVARCHAR(10) NULL
      , Loadkey          NVARCHAR(10) NULL
      , ConsolPick       NVARCHAR(1)  NULL
      , Storerkey        NVARCHAR(15) NULL
      , TotPikQty        INT          NULL
      , TotPakQty        INT          NULL
      , CartonMax        INT          NULL
   )
   SELECT *
     INTO #TEMP_FINALORDERKEY2
     FROM #TEMP_FINALORDERKEY
    WHERE 1=2


   INSERT INTO #TEMP_FINALORDERKEY(Orderkey, PickslipNo, Loadkey, ConsolPick, Storerkey)
   SELECT OH.Orderkey
        , PH.PickslipNo
        , OH.Loadkey
        , 'N'
        , OH.Storerkey
     FROM dbo.PACKHEADER PH (NOLOCK)
     JOIN dbo.ORDERS     OH (NOLOCK) ON PH.Orderkey = OH.Orderkey AND ISNULL(PH.Orderkey,'')<>''
    WHERE PH.PickSlipNo = @as_PickSlipNo

   INSERT INTO #TEMP_FINALORDERKEY(Orderkey, PickslipNo, Loadkey, ConsolPick, Storerkey)
   SELECT OH.Orderkey
        , PH.PickslipNo
        , OH.Loadkey
        , 'Y'
        , OH.Storerkey
     FROM dbo.PACKHEADER PH (NOLOCK)
     JOIN dbo.ORDERS     OH (NOLOCK) ON PH.Loadkey = OH.Loadkey AND ISNULL(PH.Loadkey,'')<>'' AND ISNULL(PH.Orderkey,'')=''
     LEFT JOIN #TEMP_FINALORDERKEY FOK ON PH.PickslipNo = FOK.PickslipNo
    WHERE PH.PickSlipNo = @as_PickSlipNo
      AND FOK.Orderkey IS NULL


   UPDATE FOK
      SET TotPikQty     = PIK.TotPikQty
     FROM #TEMP_FINALORDERKEY FOK
     JOIN (
        SELECT DISTINCT
               PickslipNo    = FOK.PickslipNo
             , TotPikQty     = SUM(PD.Qty)
          FROM #TEMP_FINALORDERKEY FOK
          JOIN dbo.PICKDETAIL      PD (NOLOCK) ON FOK.Orderkey = PD.Orderkey
         GROUP BY FOK.PickslipNo
     ) PIK ON FOK.PickslipNo = PIK.PickslipNo


    INSERT INTO #TEMP_FINALORDERKEY2 (PickslipNo, Orderkey, Loadkey, ConsolPick, Storerkey, TotPikQty, TotPakQty, CartonMax)
    SELECT DISTINCT
           PickslipNo        = FOK.PickslipNo
         , Orderkey          = FIRST_VALUE(FOK.Orderkey)   OVER(PARTITION BY FOK.PickslipNo ORDER BY FOK.Orderkey)
         , Loadkey           = FIRST_VALUE(FOK.Loadkey)    OVER(PARTITION BY FOK.PickslipNo ORDER BY FOK.Orderkey)
         , ConsolPick        = FIRST_VALUE(FOK.ConsolPick) OVER(PARTITION BY FOK.PickslipNo ORDER BY FOK.Orderkey)
         , Storerkey         = FIRST_VALUE(FOK.Storerkey)  OVER(PARTITION BY FOK.PickslipNo ORDER BY FOK.Orderkey)
         , TotPikQty         = FIRST_VALUE(FOK.TotPikQty)  OVER(PARTITION BY FOK.PickslipNo ORDER BY FOK.Orderkey)
         , TotPakQty         = 0
         , CartonMax         = 0
      FROM #TEMP_FINALORDERKEY FOK


   UPDATE FOK
      SET TotPakQty     = PAK.TotPakQty
        , CartonMax     = CASE WHEN PAK.TotPakQty>=FOK.TotPikQty THEN PAK.CartonMax END
     FROM #TEMP_FINALORDERKEY2 FOK
     JOIN (
        SELECT DISTINCT
               PickslipNo    = FOK.PickslipNo
             , TotPakQty     = SUM(PD.Qty)
             , CartonMax     = MAX(PD.CartonNo)
          FROM #TEMP_FINALORDERKEY2 FOK
          JOIN dbo.PACKDETAIL       PD (NOLOCK) ON FOK.PickslipNo = PD.PickslipNo
         GROUP BY FOK.PickslipNo
     ) PAK ON FOK.PickslipNo = PAK.PickslipNo


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

      SELECT @c_LabelNoExp         = ''
           , @c_DocNumExp          = ''
           , @c_DocKeyExp          = ''
           , @c_InvoiceNoExp       = ''
           , @c_CartonNoExp        = ''
           , @c_TotalQtyExp        = ''
           , @c_RefNoExp           = ''
           , @c_Userdefine04Exp    = ''
           , @c_C_CompanyExp       = ''
           , @c_C_Address1Exp      = ''
           , @c_C_Address2Exp      = ''
           , @c_C_Address3Exp      = ''
           , @c_C_Address4Exp      = ''
           , @c_C_ZipExp           = ''
           , @c_C_CountryExp       = ''
           , @c_RouteExp           = ''
           , @c_CompanyFromExp     = ''
           , @c_DropIDExp          = ''
           , @c_ExtraBarcodeExp    = ''
           , @c_T_DocNumExp        = ''
           , @c_T_DocKeyExp        = ''
           , @c_T_InvoiceNoExp     = ''
           , @c_T_RefNoExp         = ''
           , @c_T_Userdefine04Exp  = ''
           , @c_T_CartonExp        = ''
           , @c_T_TotalQtyExp      = ''
           , @c_T_ToCustomerExp    = ''
           , @c_T_CompanyFromExp   = ''
           , @c_Indicator1Exp      = ''
           , @c_Indicator2Exp      = ''
           , @c_Indicator3Exp      = ''
           , @c_JoinClause         = ''

      SELECT TOP 1
             @c_JoinClause  = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_LabelNoExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LabelNo')), '' )
           , @c_DocNumExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DocNum')), '' )
           , @c_DocKeyExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DocKey')), '' )
           , @c_InvoiceNoExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='InvoiceNo')), '' )
           , @c_CartonNoExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='CartonNo')), '' )
           , @c_TotalQtyExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='TotalQty')), '' )
           , @c_RefNoExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='RefNo')), '' )
           , @c_Userdefine04Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Userdefine04')), '' )
           , @c_C_CompanyExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Company')), '' )
           , @c_C_Address1Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Address1')), '' )
           , @c_C_Address2Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Address2')), '' )
           , @c_C_Address3Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Address3')), '' )
           , @c_C_Address4Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Address4')), '' )
           , @c_C_ZipExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Zip')), '' )
           , @c_C_CountryExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Country')), '' )
           , @c_RouteExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Route')), '' )
           , @c_CompanyFromExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='CompanyFrom')), '' )
           , @c_DropIDExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DropID')), '' )
           , @c_ExtraBarcodeExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ExtraBarcode')), '' )
           , @c_T_DocNumExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_DocNum')), '' )
           , @c_T_DocKeyExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_DocKey')), '' )
           , @c_T_InvoiceNoExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_InvoiceNo')), '' )
           , @c_T_RefNoExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_RefNo')), '' )
           , @c_T_Userdefine04Exp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Userdefine04')), '' )
           , @c_T_CartonExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Carton')), '' )
           , @c_T_TotalQtyExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_TotalQty')), '' )
           , @c_T_ToCustomerExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ToCustomer')), '' )
           , @c_T_CompanyFromExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_CompanyFrom')), '' )
           , @c_Indicator1Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Indicator1')), '' )
           , @c_Indicator2Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Indicator2')), '' )
           , @c_Indicator3Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Indicator3')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      ----------
      SET @c_ExecStatements = N'INSERT INTO #TEMP_PAKDT'
          +' (PickslipNo, Orderkey, ExternOrderKey, Storerkey, Loadkey, DocNum, DocKey, InvoiceNo, RefNo, Userdefine04, C_Company'
          + ', C_Address1, C_Address2, C_Address3, C_Address4, C_Zip, C_Country, Route, CompanyFrom, DropID, ExtraBarcode'
          + ', T_DocNum, T_DocKey, T_InvoiceNo, T_RefNo, T_Userdefine04, T_Carton, T_TotalQty, T_ToCustomer, T_CompanyFrom, Indicator1, Indicator2, Indicator3'
          + ', LabelNo, CartonNoStr, TotalQty, CartonNo, CartonMax, ConsolPick)'
          +' SELECT FOK.PickslipNo'
               + ', OH.OrderKey'
               + ', OH.ExternOrderKey'
               + ', OH.Storerkey'
               + ', OH.Loadkey'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_DocNumExp        ,'')<>'' THEN @c_DocNumExp         ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_DocKeyExp        ,'')<>'' THEN @c_DocKeyExp         ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_InvoiceNoExp     ,'')<>'' THEN @c_InvoiceNoExp      ELSE 'OH.InvoiceNo'      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RefNoExp         ,'')<>'' THEN @c_RefNoExp          ELSE ''''''              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Userdefine04Exp  ,'')<>'' THEN @c_Userdefine04Exp   ELSE ''''''              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_CompanyExp     ,'')<>'' THEN @c_C_CompanyExp      ELSE 'OH.C_Company'      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address1Exp    ,'')<>'' THEN @c_C_Address1Exp     ELSE 'OH.C_Address1'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address2Exp    ,'')<>'' THEN @c_C_Address2Exp     ELSE 'OH.C_Address2'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address3Exp    ,'')<>'' THEN @c_C_Address3Exp     ELSE 'OH.C_Address3'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address4Exp    ,'')<>'' THEN @c_C_Address4Exp     ELSE 'LTRIM(ISNULL(RTRIM(OH.C_Address4),'''')+'' ''+ISNULL(LTRIM(OH.C_City),''''))' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_ZipExp         ,'')<>'' THEN @c_C_ZipExp          ELSE '''ZIP: ''+ISNULL(OH.C_Zip,'''')' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_CountryExp     ,'')<>'' THEN @c_C_CountryExp      ELSE 'NULL'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RouteExp         ,'')<>'' THEN @c_RouteExp          ELSE 'OH.Route'          END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_CompanyFromExp   ,'')<>'' THEN @c_CompanyFromExp    ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_DropIDExp        ,'')<>'' THEN @c_DropIDExp         ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_ExtraBarcodeExp  ,'')<>'' THEN @c_ExtraBarcodeExp   ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_DocNumExp      ,'')<>'' THEN @c_T_DocNumExp       ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_DocKeyExp      ,'')<>'' THEN @c_T_DocKeyExp       ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_InvoiceNoExp   ,'')<>'' THEN @c_T_InvoiceNoExp    ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_RefNoExp       ,'')<>'' THEN @c_T_RefNoExp        ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_Userdefine04Exp,'')<>'' THEN @c_T_Userdefine04Exp ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_CartonExp      ,'')<>'' THEN @c_T_CartonExp       ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_TotalQtyExp    ,'')<>'' THEN @c_T_TotalQtyExp     ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_ToCustomerExp  ,'')<>'' THEN @c_T_ToCustomerExp   ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_CompanyFromExp ,'')<>'' THEN @c_T_CompanyFromExp  ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Indicator1Exp    ,'')<>'' THEN @c_Indicator1Exp     ELSE 'NULL'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Indicator2Exp    ,'')<>'' THEN @c_Indicator2Exp     ELSE 'NULL'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Indicator3Exp    ,'')<>'' THEN @c_Indicator3Exp     ELSE 'NULL'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LabelNoExp       ,'')<>'' THEN @c_LabelNoExp        ELSE 'PD.LabelNo'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CartonNoExp      ,'')<>'' THEN @c_CartonNoExp       ELSE 'ISNULL(CONVERT(VARCHAR(10),PD.CartonNo),'''')+''  of  ''+ISNULL(CONVERT(VARCHAR(10),FOK.CartonMax),'''')' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               +       ', ISNULL(' + CASE WHEN ISNULL(@c_TotalQtyExp      ,'')<>'' THEN @c_TotalQtyExp       ELSE 'PD.Qty'            END + ',0)'
      SET @c_ExecStatements = @c_ExecStatements
               + ', PD.CartonNo'
               + ', FOK.CartonMax'
               + ', FOK.ConsolPick'
          +' FROM #TEMP_FINALORDERKEY2 FOK'
          +' JOIN dbo.ORDERS      OH (NOLOCK) ON FOK.Orderkey=OH.Orderkey'
          +' JOIN dbo.PACKDETAIL  PD (NOLOCK) ON FOK.PickslipNo=PD.PickslipNo'
      SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END
      SET @c_ExecStatements = @c_ExecStatements
          +' WHERE OH.Storerkey=@c_Storerkey'
          +  ' AND PD.CartonNo >= @n_CartonNoFrom'
          +  ' AND PD.CartonNo <= @n_CartonNoTo'
      IF ISNULL(@as_startlabelno,'')<>'' OR ISNULL(@as_endlabelno,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
             +  ' AND PD.LabelNo >= ISNULL(@as_startlabelno,'''')'
             +  ' AND PD.LabelNo <= ISNULL(@as_endlabelno,'''')'

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
        , Storerkey        = RTRIM( MAX( PAKDT.Storerkey ) )
        , Loadkey          = RTRIM( MAX( PAKDT.Loadkey ) )
        , DocNum           = RTRIM( MAX( PAKDT.DocNum ) )
        , DocKey           = RTRIM( MAX( CASE WHEN PAKDT.DocKey IS NOT NULL THEN PAKDT.DocKey
                                              WHEN PAKDT.ConsolPick='Y'     THEN PAKDT.Loadkey ELSE PAKDT.ExternOrderKey END ) )
        , InvoiceNo        = RTRIM( MAX( PAKDT.InvoiceNo ) )
        , Userdefine04     = RTRIM( MAX( PAKDT.Userdefine04 ) )
        , C_Company        = RTRIM( MAX( PAKDT.C_Company ) )
        , C_Address1       = RTRIM( MAX( PAKDT.C_Address1 ) )
        , C_Address2       = RTRIM( MAX( PAKDT.C_Address2 ) )
        , C_Address3       = RTRIM( MAX( PAKDT.C_Address3 ) )
        , C_Address4       = RTRIM( MAX( PAKDT.C_Address4 ) )
        , C_Zip            = RTRIM( MAX( PAKDT.C_Zip ) )
        , C_Country        = RTRIM( MAX( PAKDT.C_Country ) )
        , Route            = RTRIM( MAX( PAKDT.Route ) )
        , CompanyFrom      = RTRIM( MAX( ISNULL(CASE WHEN PAKDT.CompanyFrom IS NOT NULL            THEN PAKDT.CompanyFrom
                                                     WHEN RptCfg.ShowFields LIKE '%,FromCust,%'    THEN STR.Company  ELSE LFL.Company END, '') ) )
        , DropID           = RTRIM( MAX( PAKDT.DropID ) )
        , PrintDate        = CONVERT(CHAR(19), GETDATE(), 120)
        , ConsolPick       = RTRIM( MAX( PAKDT.ConsolPick ) )
        , LabelNo          = RTRIM( PAKDT.LabelNo )
        , CartonNo         = MAX( PAKDT.CartonNo )
        , CartonMax        = MAX( PAKDT.CartonMax )
        , TotalQty         = SUM( PAKDT.TotalQty )
        , ShowFields       = RTRIM( MAX( RptCfg.ShowFields ) )
        , Lbl_DocNum       = CAST( RTRIM( CASE WHEN MAX(PAKDT.T_DocNum) IS NOT NULL            THEN MAX(PAKDT.T_DocNum)
                             WHEN MAX( PAKDT.ConsolPick ) = 'Y'
                             THEN (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DocNum_Conso')
                             ELSE (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DocNum')
                             END ) AS NVARCHAR(50))
        , Lbl_DocKey       = CAST( RTRIM( CASE WHEN MAX(PAKDT.T_DocKey) IS NOT NULL            THEN MAX(PAKDT.T_DocKey)
                             WHEN MAX( PAKDT.ConsolPick ) = 'Y'
                             THEN ISNULL( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DocKey_Conso'), 'LoadKey:')
                             ELSE ISNULL( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DocKey'), 'SO#:')
                             END ) AS NVARCHAR(50))
        , Lbl_InvoiceNo    = CAST( RTRIM( CASE WHEN MAX(PAKDT.T_InvoiceNo) IS NOT NULL THEN MAX(PAKDT.T_InvoiceNo)
                             WHEN MAX( PAKDT.ConsolPick ) = 'Y'
                             THEN ISNULL( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_InvoiceNo_Conso'), 'Pick Ticket:')
                             ELSE ISNULL( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_InvoiceNo'), 'Pick Ticket:')
                             END ) AS NVARCHAR(50))
        , Lbl_Userdefine04 = CAST( RTRIM( CASE WHEN MAX(PAKDT.T_Userdefine04) IS NOT NULL      THEN MAX(PAKDT.T_Userdefine04)
                             ELSE (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Userdefine04') END) AS NVARCHAR(50))
        , ExtraBarcode     = RTRIM( MAX( PAKDT.ExtraBarcode ) )
        , CartonNoStr      = RTRIM( MAX( PAKDT.CartonNoStr ) )
        , Lbl_Carton       = CAST( RTRIM( CASE WHEN MAX(PAKDT.T_Carton) IS NOT NULL THEN MAX(PAKDT.T_Carton)
                             ELSE ISNULL( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Carton'), 'Carton:')
                             END ) AS NVARCHAR(50))
        , Lbl_TotalQty     = CAST( RTRIM( CASE WHEN MAX(PAKDT.T_TotalQty) IS NOT NULL THEN MAX(PAKDT.T_TotalQty)
                             ELSE ISNULL( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_TotalQty'), 'Total Qty:')
                             END ) AS NVARCHAR(50))
        , Lbl_RefNo        = CAST( RTRIM( CASE WHEN MAX(PAKDT.T_RefNo) IS NOT NULL THEN MAX(PAKDT.T_RefNo)
                             ELSE ISNULL( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_RefNo'), '')
                             END ) AS NVARCHAR(50))
        , Lbl_ToCustomer   = CAST( RTRIM( CASE WHEN MAX(PAKDT.T_ToCustomer) IS NOT NULL THEN MAX(PAKDT.T_ToCustomer)
                             ELSE ISNULL( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ToCustomer'), 'To: Customer')
                             END ) AS NVARCHAR(50))
        , Lbl_CompanyFrom  = CAST( RTRIM( CASE WHEN MAX(PAKDT.T_CompanyFrom) IS NOT NULL THEN MAX(PAKDT.T_CompanyFrom)
                             ELSE ISNULL( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_CompanyFrom'), 'From:')
                             END ) AS NVARCHAR(50))
        , RefNo            = RTRIM( MAX( PAKDT.RefNo ) )
        , Indicator1       = RTRIM( MAX( PAKDT.Indicator1 ) )
        , Indicator2       = RTRIM( MAX( PAKDT.Indicator2 ) )
        , Indicator3       = RTRIM( MAX( PAKDT.Indicator3 ) )

   FROM #TEMP_PAKDT PAKDT

   LEFT JOIN STORER LFL (NOLOCK) ON (LFL.Storerkey = '11301')
   LEFT JOIN STORER STR (NOLOCK) ON (PAKDT.Storerkey = STR.Storerkey)

   LEFT JOIN (
      SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=PAKDT.Storerkey AND RptCfg.SeqNo=1

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg3
   ON RptCfg3.Storerkey=PAKDT.Storerkey AND RptCfg3.SeqNo=1

   GROUP BY PAKDT.PickSlipNo
          , PAKDT.CartonNo
          , PAKDT.LabelNo

   ORDER BY PAKDT.PickSlipNo
          , PAKDT.CartonNo
          , PAKDT.LabelNo
END

GO