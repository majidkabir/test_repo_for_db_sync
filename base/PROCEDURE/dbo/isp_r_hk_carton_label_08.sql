SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_carton_label_08                            */
/* Creation Date: 24-May-2019                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: L'Oreal Carton Label                                         */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_carton_label_08             */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 03/08/2020   Michael  1.1  Handle print from RDT                      */
/* 02/09/2021   Michael  1.2  WMS-17862 - LEGO HK CR                     */
/*                            Convert to Dynamic SQL                     */
/* 21/01/2022   Michael  1.3  Add new field Sku (MAPFIELD)               */
/*                            Handle print all labels in Waveplan        */
/* 24/02/2022   Michael  1.4  Add MAPFIELD: Sorting                      */
/* 23/03/2022   Michael  1.5  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_carton_label_08] (
       @as_PickSlipNo         NVARCHAR(4000)          -- PickSlipNo    / Storerkey
     , @as_StartCartonNo      NVARCHAR(4000) = ''     -- StartCartonNo / Wavekey
     , @as_EndCartonNo        NVARCHAR(4000) = ''     -- EndCartonNo   / Loadkey
     , @as_StartLabelNo       NVARCHAR(4000) = ''     -- StartLabelNo  / Orderkey
     , @as_EndLabelNo         NVARCHAR(4000) = ''     -- EndLabelNo    / CartonNo
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      ExternOrderKey, Company, Div, Consigneekey, C_Company, C_Address1, C_Address2, C_Address3, C_Address4, Notes2
      Route, Wavekey, Deliverydate, ContainerQty, LabelNo, StorerLogo, StoreNo, Sku, Qty, Sorting
      T_Dock, T_Div, T_ExternOrderkey, T_ShipTo, T_Remark, T_Route, T_Wavekey, T_DeliveryOn, T_Carton, T_StoreNo

   [MAPVALUE]

   [SHOWFIELD]
      GenPrintLog

   [SQLJOIN]
*/
   DECLARE @c_DataWindow          NVARCHAR(40) = 'r_hk_carton_label_08'
         , @c_JobName             NVARCHAR(50) = OBJECT_NAME(@@procid)
         , @n_StartTCnt           INT          = @@TRANCOUNT
         , @b_FromRptModule       INT          = 0
         , @n_CartonNoFrom        INT          = ISNULL( IIF(ISNULL(@as_StartCartonNo,'')='', 0, TRY_PARSE(@as_StartCartonNo AS FLOAT)), 0 )
         , @n_CartonNoTo          INT          = ISNULL( IIF(ISNULL(@as_EndCartonNo  ,'')='', 0, TRY_PARSE(@as_EndCartonNo   AS FLOAT)), 0 )
         , @c_PickslipNo          NVARCHAR(20)
         , @n_CartonNo            INT
         , @c_LabelNo             NVARCHAR(50)
         , @c_Orderkey            NVARCHAR(10)
         , @c_ExternOrderkey      NVARCHAR(50)
         , @c_Storerkey           NVARCHAR(15)
         , @n_JobID               INT
         , @n_ErrNo               INT
         , @c_WavekeyList         NVARCHAR(MAX) = ''
         , @c_LoadkeyList         NVARCHAR(MAX) = ''
         , @c_OrderkeyList        NVARCHAR(MAX) = ''
         , @c_ExternOrderKeyExp   NVARCHAR(MAX)
         , @c_CompanyExp          NVARCHAR(MAX)
         , @c_DivExp              NVARCHAR(MAX)
         , @c_ConsigneekeyExp     NVARCHAR(MAX)
         , @c_C_CompanyExp        NVARCHAR(MAX)
         , @c_C_Address1Exp       NVARCHAR(MAX)
         , @c_C_Address2Exp       NVARCHAR(MAX)
         , @c_C_Address3Exp       NVARCHAR(MAX)
         , @c_C_Address4Exp       NVARCHAR(MAX)
         , @c_Notes2Exp           NVARCHAR(MAX)
         , @c_RouteExp            NVARCHAR(MAX)
         , @c_WavekeyExp          NVARCHAR(MAX)
         , @c_DeliverydateExp     NVARCHAR(MAX)
         , @c_ContainerQtyExp     NVARCHAR(MAX)
         , @c_LabelNoExp          NVARCHAR(MAX)
         , @c_StorerLogoExp       NVARCHAR(MAX)
         , @c_StoreNoExp          NVARCHAR(MAX)
         , @c_SkuExp              NVARCHAR(MAX)
         , @c_QtyExp              NVARCHAR(MAX)
         , @c_SortingExp          NVARCHAR(MAX)
         , @c_T_DockExp           NVARCHAR(MAX)
         , @c_T_DivExp            NVARCHAR(MAX)
         , @c_T_ExternOrderkeyExp NVARCHAR(MAX)
         , @c_T_ShipToExp         NVARCHAR(MAX)
         , @c_T_RemarkExp         NVARCHAR(MAX)
         , @c_T_RouteExp          NVARCHAR(MAX)
         , @c_T_WavekeyExp        NVARCHAR(MAX)
         , @c_T_DeliveryOnExp     NVARCHAR(MAX)
         , @c_T_CartonExp         NVARCHAR(MAX)
         , @c_T_StoreNoExp        NVARCHAR(MAX)
         , @c_ExecStatements      NVARCHAR(MAX)
         , @c_ExecArguments       NVARCHAR(MAX)
         , @c_JoinClause          NVARCHAR(MAX)


   IF OBJECT_ID('tempdb..#TEMP_PAKDT') IS NOT NULL
      DROP TABLE #TEMP_PAKDT
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY2') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY2
   IF OBJECT_ID('tempdb..#TEMP_CARTONNOLIST') IS NOT NULL
      DROP TABLE #TEMP_CARTONNOLIST

   CREATE TABLE #TEMP_PAKDT (
        PickSlipNo       NVARCHAR(20)  NULL
      , Storerkey        NVARCHAR(15)  NULL
      , Orderkey         NVARCHAR(10)  NULL
      , ExternOrderKey   NVARCHAR(50)  NULL
      , Company          NVARCHAR(50)  NULL
      , Div              NVARCHAR(50)  NULL
      , Consigneekey     NVARCHAR(50)  NULL
      , C_company        NVARCHAR(500) NULL
      , C_Address1       NVARCHAR(500) NULL
      , C_Address2       NVARCHAR(500) NULL
      , C_Address3       NVARCHAR(500) NULL
      , C_Address4       NVARCHAR(500) NULL
      , Notes2           NVARCHAR(500) NULL
      , Route            NVARCHAR(50)  NULL
      , Wavekey          NVARCHAR(50)  NULL
      , Deliverydate     DATETIME      NULL
      , ContainerQty     INT           NULL
      , LabelNo          NVARCHAR(50)  NULL
      , Storer_Logo      NVARCHAR(50)  NULL
      , StoreNo          NVARCHAR(50)  NULL
      , Sku              NVARCHAR(500) NULL
      , Qty              INT           NULL
      , Sorting          NVARCHAR(500) NULL
      , CartonNo         INT           NULL
      , TotalCarton      INT           NULL
      , ConsolPick       NVARCHAR(1)   NULL
      , T_Dock           NVARCHAR(50)  NULL
      , T_Div            NVARCHAR(50)  NULL
      , T_ExternOrderkey NVARCHAR(50)  NULL
      , T_ShipTo         NVARCHAR(50)  NULL
      , T_Remark         NVARCHAR(50)  NULL
      , T_Route          NVARCHAR(50)  NULL
      , T_Wavekey        NVARCHAR(50)  NULL
      , T_DeliveryOn     NVARCHAR(50)  NULL
      , T_Carton         NVARCHAR(50)  NULL
      , T_StoreNo        NVARCHAR(50)  NULL
   )

   -- Final Orderkey
   CREATE TABLE #TEMP_FINALORDERKEY (
        PickslipNo       NVARCHAR(10)  NULL
      , Orderkey         NVARCHAR(10)  NULL
      , Loadkey          NVARCHAR(10)  NULL
      , ConsolPick       NVARCHAR(1)   NULL
      , Storerkey        NVARCHAR(15)  NULL
      , TotPikQty        INT           NULL
      , TotPakQty        INT           NULL
      , CartonMax        INT           NULL
   )
   SELECT *
     INTO #TEMP_FINALORDERKEY2
     FROM #TEMP_FINALORDERKEY
    WHERE 1=2

   IF EXISTS(SELECT TOP 1 1 FROM dbo.PACKHEADER(NOLOCK) WHERE PickslipNo=@as_PickSlipNo)
   BEGIN
      SET @b_FromRptModule = 0

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
   END
   ELSE IF EXISTS(SELECT TOP 1 1 FROM dbo.STORER (NOLOCK) WHERE Storerkey=@as_PickSlipNo AND Type='1')
   BEGIN
      SET @b_FromRptModule = 1

      SELECT @c_Storerkey    = @as_PickSlipNo
           , @c_WavekeyList  = REPLACE(@as_StartCartonNo,CHAR(13)+CHAR(10),',')
           , @c_LoadkeyList  = REPLACE(@as_EndCartonNo  ,CHAR(13)+CHAR(10),',')
           , @c_OrderkeyList = REPLACE(@as_StartLabelNo ,CHAR(13)+CHAR(10),',')

      SELECT DISTINCT CartonNo = TRY_PARSE(ISNULL(value,'') AS INT)
        INTO #TEMP_CARTONNOLIST
        FROM STRING_SPLIT(REPLACE(@as_EndLabelNo,CHAR(13)+CHAR(10),','), ',')
        WHERE value<>''

      INSERT INTO #TEMP_FINALORDERKEY(Orderkey, PickslipNo, Loadkey, ConsolPick, Storerkey)
      SELECT OH.Orderkey
           , PH.PickslipNo
           , OH.Loadkey
           , 'N'
           , OH.Storerkey
        FROM dbo.PACKHEADER PH (NOLOCK)
        JOIN dbo.ORDERS     OH (NOLOCK) ON PH.Orderkey = OH.Orderkey AND ISNULL(PH.Orderkey,'')<>''
       WHERE OH.Storerkey = @c_Storerkey
         AND (ISNULL(@c_WavekeyList,'')<>'' OR ISNULL(@c_LoadkeyList,'')<>'' OR ISNULL(@c_OrderkeyList,'')<>'')
         AND (ISNULL(@c_WavekeyList ,'')='' OR OH.UserDefine09 IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@c_WavekeyList,',') WHERE value<>''))
         AND (ISNULL(@c_LoadkeyList ,'')='' OR OH.Loadkey      IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@c_LoadkeyList,',') WHERE value<>''))
         AND (ISNULL(@c_OrderkeyList,'')='' OR OH.Orderkey     IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@c_OrderkeyList,',') WHERE value<>''))

      INSERT INTO #TEMP_FINALORDERKEY(Orderkey, PickslipNo, Loadkey, ConsolPick, Storerkey)
      SELECT OH.Orderkey
           , PH.PickslipNo
           , OH.Loadkey
           , 'Y'
           , OH.Storerkey
        FROM dbo.PACKHEADER PH (NOLOCK)
        JOIN dbo.ORDERS     OH (NOLOCK) ON PH.Loadkey = OH.Loadkey AND ISNULL(PH.Loadkey,'')<>'' AND ISNULL(PH.Orderkey,'')=''
        LEFT JOIN #TEMP_FINALORDERKEY FOK ON PH.PickslipNo = FOK.PickslipNo
       WHERE FOK.Orderkey IS NULL
         AND OH.Storerkey = @c_Storerkey
         AND (ISNULL(@c_WavekeyList,'')<>'' OR ISNULL(@c_LoadkeyList,'')<>'' OR ISNULL(@c_OrderkeyList,'')<>'')
         AND (ISNULL(@c_WavekeyList ,'')='' OR OH.UserDefine09 IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@c_WavekeyList,',') WHERE value<>''))
         AND (ISNULL(@c_LoadkeyList ,'')='' OR OH.Loadkey      IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@c_LoadkeyList,',') WHERE value<>''))
         AND (ISNULL(@c_OrderkeyList,'')='' OR OH.Orderkey     IN (SELECT DISTINCT TRIM(value) FROM STRING_SPLIT(@c_OrderkeyList,',') WHERE value<>''))
   END


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

      SELECT @c_ExternOrderKeyExp   = ''
           , @c_CompanyExp          = ''
           , @c_DivExp              = ''
           , @c_ConsigneekeyExp     = ''
           , @c_C_CompanyExp        = ''
           , @c_C_Address1Exp       = ''
           , @c_C_Address2Exp       = ''
           , @c_C_Address3Exp       = ''
           , @c_C_Address4Exp       = ''
           , @c_Notes2Exp           = ''
           , @c_RouteExp            = ''
           , @c_WavekeyExp          = ''
           , @c_DeliverydateExp     = ''
           , @c_ContainerQtyExp     = ''
           , @c_LabelNoExp          = ''
           , @c_StorerLogoExp       = ''
           , @c_StoreNoExp          = ''
           , @c_SkuExp              = ''
           , @c_QtyExp              = ''
           , @c_SortingExp          = ''
           , @c_T_DockExp           = ''
           , @c_T_DivExp            = ''
           , @c_T_ExternOrderkeyExp = ''
           , @c_T_ShipToExp         = ''
           , @c_T_RemarkExp         = ''
           , @c_T_RouteExp          = ''
           , @c_T_WavekeyExp        = ''
           , @c_T_DeliveryOnExp     = ''
           , @c_T_CartonExp         = ''
           , @c_T_StoreNoExp        = ''
           , @c_JoinClause          = ''

      SELECT TOP 1
             @c_JoinClause  = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_ExternOrderKeyExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderKey')), '' )
           , @c_CompanyExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Company')), '' )
           , @c_DivExp              = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Div')), '' )
           , @c_ConsigneekeyExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Consigneekey')), '' )
           , @c_C_CompanyExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='C_Company')), '' )
           , @c_C_Address1Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='C_Address1')), '' )
           , @c_C_Address2Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='C_Address2')), '' )
           , @c_C_Address3Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='C_Address3')), '' )
           , @c_C_Address4Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='C_Address4')), '' )
           , @c_Notes2Exp           = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Notes2')), '' )
           , @c_RouteExp            = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Route')), '' )
           , @c_WavekeyExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Wavekey')), '' )
           , @c_DeliverydateExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Deliverydate')), '' )
           , @c_ContainerQtyExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='ContainerQty')), '' )
           , @c_LabelNoExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='LabelNo')), '' )
           , @c_StorerLogoExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='StorerLogo')), '' )
           , @c_StoreNoExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='StoreNo')), '' )
           , @c_SkuExp              = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Sku')), '' )
           , @c_QtyExp              = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Qty')), '' )
           , @c_SortingExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='Sorting')), '' )
           , @c_T_DockExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_Dock')), '' )
           , @c_T_DivExp            = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_Div')), '' )
           , @c_T_ExternOrderkeyExp = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_ExternOrderKey')), '' )
           , @c_T_ShipToExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_ShipTo')), '' )
           , @c_T_RemarkExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_Remark')), '' )
           , @c_T_RouteExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_Route')), '' )
           , @c_T_WavekeyExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_Wavekey')), '' )
           , @c_T_DeliveryOnExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_DeliveryOn')), '' )
           , @c_T_CartonExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_Carton')), '' )
           , @c_T_StoreNoExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                      from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                      where a.SeqNo=b.SeqNo and a.ColValue='T_StoreNo')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      ----------
      SET @c_ExecStatements = N'INSERT INTO #TEMP_PAKDT'
          +' (PickSlipNo, Storerkey, Orderkey, ExternOrderKey, Company, Div, Consigneekey, C_company, C_Address1, C_Address2,'
          + ' C_Address3, C_Address4, Notes2, Route, Wavekey, Deliverydate, ContainerQty, LabelNo, Storer_Logo,'
          + ' StoreNo, Sku, Qty, Sorting, CartonNo, TotalCarton, ConsolPick,'
          + ' T_Dock, T_Div, T_ExternOrderkey, T_ShipTo, T_Remark, T_Route, T_Wavekey, T_DeliveryOn, T_Carton, T_StoreNo)'
          +' SELECT FOK.PickslipNo'
          +      ', OH.Storerkey'
          +      ', OH.OrderKey'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExternOrderKeyExp  ,'')<>'' THEN @c_ExternOrderKeyExp   ELSE 'CASE WHEN FOK.ConsolPick=''Y'' THEN OH.Loadkey ELSE OH.ExternOrderKey END' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CompanyExp         ,'')<>'' THEN @c_CompanyExp          ELSE 'ST.Company'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DivExp             ,'')<>'' THEN @c_DivExp              ELSE 'NULL'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ConsigneekeyExp    ,'')<>'' THEN @c_ConsigneekeyExp     ELSE 'OH.Consigneekey'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_CompanyExp       ,'')<>'' THEN @c_C_CompanyExp        ELSE 'OH.C_Company'      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address1Exp      ,'')<>'' THEN @c_C_Address1Exp       ELSE 'OH.C_Address1'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address2Exp      ,'')<>'' THEN @c_C_Address2Exp       ELSE 'OH.C_Address2'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address3Exp      ,'')<>'' THEN @c_C_Address3Exp       ELSE 'OH.C_Address3'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address4Exp      ,'')<>'' THEN @c_C_Address4Exp       ELSE 'OH.C_Address4'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Notes2Exp          ,'')<>'' THEN @c_Notes2Exp           ELSE 'OH.Notes2'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RouteExp           ,'')<>'' THEN @c_RouteExp            ELSE 'OH.Route'          END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_WavekeyExp         ,'')<>'' THEN @c_WavekeyExp          ELSE 'OH.Userdefine09'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +                   ', ' + CASE WHEN ISNULL(@c_DeliverydateExp    ,'')<>'' THEN @c_DeliverydateExp     ELSE 'OH.Deliverydate'   END
      SET @c_ExecStatements = @c_ExecStatements
          +                   ', ' + CASE WHEN ISNULL(@c_ContainerQtyExp    ,'')<>'' THEN @c_ContainerQtyExp     ELSE 'OH.ContainerQty'   END
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LabelNoExp         ,'')<>'' THEN @c_LabelNoExp          ELSE 'PD.LabelNo'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_StorerLogoExp      ,'')<>'' THEN @c_StorerLogoExp       ELSE 'RL.Notes'          END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_StoreNoExp         ,'')<>'' THEN @c_StoreNoExp          ELSE 'NULL'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SkuExp             ,'')<>'' THEN @c_SkuExp              ELSE 'NULL'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +            ', ISNULL(' + CASE WHEN ISNULL(@c_QtyExp             ,'')<>'' THEN @c_QtyExp              ELSE 'PD.Qty'            END + ',0)'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SortingExp         ,'')<>'' THEN @c_SortingExp          ELSE 'NULL'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', PD.CartonNo'
          +      ', FOK.CartonMax'
          +      ', FOK.ConsolPick'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_DockExp          ,'')<>'' THEN @c_T_DockExp           ELSE '''Dock#'''         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_DivExp           ,'')<>'' THEN @c_T_DivExp            ELSE '''Div :'''         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_ExternOrderkeyExp,'')<>'' THEN @c_T_ExternOrderkeyExp ELSE 'CASE WHEN FOK.ConsolPick=''Y'' THEN ''LP#:'' ELSE ''SO#'' END' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_ShipToExp        ,'')<>'' THEN @c_T_ShipToExp         ELSE '''Ship To :'''     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_RemarkExp        ,'')<>'' THEN @c_T_RemarkExp         ELSE '''Remark :'''      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_RouteExp         ,'')<>'' THEN @c_T_RouteExp          ELSE '''Route :'''       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_WavekeyExp       ,'')<>'' THEN @c_T_WavekeyExp        ELSE '''Wavekey :'''     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_DeliveryOnExp    ,'')<>'' THEN @c_T_DeliveryOnExp     ELSE '''Deliver on :'''  END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_CartonExp        ,'')<>'' THEN @c_T_CartonExp         ELSE '''Carton'''        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
          +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_StoreNoExp       ,'')<>'' THEN @c_T_StoreNoExp        ELSE '''Store #'''       END + '),'''')'

      SET @c_ExecStatements = @c_ExecStatements
          +' FROM #TEMP_FINALORDERKEY2 FOK'
          +' JOIN dbo.ORDERS        OH (NOLOCK) ON FOK.Orderkey=OH.Orderkey'
          +' JOIN dbo.PACKDETAIL    PD (NOLOCK) ON FOK.PickslipNo=PD.PickslipNo'
          +' JOIN dbo.STORER        ST (NOLOCK) ON OH.Storerkey=ST.Storerkey'
          +' LEFT JOIN dbo.CODELKUP RL (NOLOCK) ON RL.Listname=''RPTLOGO'' AND RL.Code=''LOGO'' AND RL.Storerkey=OH.Storerkey AND RL.Long=@c_DataWindow'
      SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END

      SET @c_ExecStatements = @c_ExecStatements
          +' WHERE OH.Storerkey=@c_Storerkey'

      IF @b_FromRptModule = 1
      BEGIN
         IF EXISTS(SELECT TOP 1 1 FROM #TEMP_CARTONNOLIST)
            SET @c_ExecStatements = @c_ExecStatements
                +  ' AND PD.CartonNo IN (SELECT CartonNo FROM #TEMP_CARTONNOLIST)'
      END
      ELSE
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
             +  ' AND PD.CartonNo >= @n_CartonNoFrom'
             +  ' AND PD.CartonNo <= @n_CartonNoTo'
         IF ISNULL(@as_StartLabelNo,'')<>'' OR ISNULL(@as_EndLabelNo,'')<>''
            SET @c_ExecStatements = @c_ExecStatements
                +  ' AND PD.LabelNo >= ISNULL(@as_StartLabelNo,'''')'
                +  ' AND PD.LabelNo <= ISNULL(@as_EndLabelNo,'''')'
      END

      SET @c_ExecArguments = N'@c_DataWindow    NVARCHAR(40)'
                           + ',@c_Storerkey     NVARCHAR(15)'
                           + ',@n_CartonNoFrom  INT'
                           + ',@n_CartonNoTo    INT'
                           + ',@as_StartLabelNo NVARCHAR(40)'
                           + ',@as_EndLabelNo   NVARCHAR(40)'
                           + ',@b_FromRptModule INT'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_DataWindow
                       , @c_Storerkey
                       , @n_CartonNoFrom
                       , @n_CartonNoTo
                       , @as_StartLabelNo
                       , @as_EndLabelNo
                       , @b_FromRptModule
   END

   CLOSE CUR_STORERKEY
   DEALLOCATE CUR_STORERKEY


   -- Insert Print Log
   IF ISNULL(@c_JobName,'')<>'' AND ISNULL(@as_StartLabelNo,'') <> ''
      AND EXISTS(SELECT TOP 1 1 FROM #TEMP_PAKDT)
   BEGIN
      DECLARE C_PRINTLOG CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT a.PickslipNo, a.CartonNo, a.LabelNo, a.Orderkey, a.ExternOrderkey, a.Storerkey
         FROM #TEMP_PAKDT a
         JOIN (
            SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
                 , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
              FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
         ) RptCfg
         ON RptCfg.Storerkey=a.Storerkey AND RptCfg.SeqNo=1
        WHERE RptCfg.ShowFields LIKE '%,GenPrintLog,%'
        ORDER BY PickslipNo, CartonNo

      OPEN C_PRINTLOG

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_PRINTLOG
          INTO @c_PickslipNo, @n_CartonNo, @c_LabelNo, @c_Orderkey, @c_ExternOrderkey, @c_Storerkey

         IF @@FETCH_STATUS<>0
            BREAK

         INSERT INTO rdt.rdtPrintJob (
             JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
             Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10)
         VALUES(
             @c_JobName, 'UCCLABEL', '9', @c_DataWindow, 0, '', 0, 0, DB_NAME(), '', '', @c_StorerKey,
             @c_PickslipNo, ISNULL(CONVERT(NVARCHAR(10),@n_CartonNo),''), @c_LabelNo, @c_Orderkey, @c_ExternOrderkey, '', '', '', '', ''
         )

         SELECT @n_JobID = SCOPE_IDENTITY(), @n_ErrNo = @@ERROR

         IF @n_ErrNo = 0
            AND EXISTS(SELECT TOP 1 1 FROM SYS.PROCEDURES (NOLOCK) WHERE Name='isp_UpdateRDTPrintJobStatus')
         BEGIN
            EXEC isp_UpdateRDTPrintJobStatus @n_JobID, '9', ''
         END
      END

      CLOSE C_PRINTLOG
      DEALLOCATE C_PRINTLOG
   END



   SELECT PickSlipNo         = PAKDT.PickSlipNo
        , Storerkey          = MAX( PAKDT.Storerkey )
        , Company            = MAX( PAKDT.Company )
        , Div                = MAX( PAKDT.Div )
        , Orderkey           = MAX( PAKDT.Orderkey )
        , ExternOrderKey     = MAX( PAKDT.ExternOrderKey )
        , Consigneekey       = MAX( PAKDT.Consigneekey )
        , C_company          = MAX( PAKDT.C_company )
        , C_Address1         = MAX( PAKDT.C_Address1 )
        , C_Address2         = MAX( PAKDT.C_Address2 )
        , C_Address3         = MAX( PAKDT.C_Address3 )
        , C_Address4         = MAX( PAKDT.C_Address4 )
        , Notes2             = MAX( PAKDT.Notes2 )
        , Route              = MAX( PAKDT.Route )
        , Wavekey            = MAX( PAKDT.Wavekey )
        , Deliverydate       = MAX( PAKDT.Deliverydate )
        , ContainerQty       = MAX( PAKDT.ContainerQty )
        , LabelNo            = PAKDT.LabelNo
        , CartonNo           = PAKDT.CartonNo
        , StoreNo            = MAX( PAKDT.StoreNo )
        , TotalCarton        = MAX( PAKDT.TotalCarton )
        , Qty                = SUM( PAKDT.Qty )
        , ConsolPick         = MAX( PAKDT.ConsolPick )
        , Storer_Logo        = MAX( PAKDT.Storer_Logo )
        , Lbl_Dock           = MAX( PAKDT.T_Dock )
        , Lbl_Div            = MAX( PAKDT.T_Div )
        , Lbl_ExternOrderkey = MAX( PAKDT.T_ExternOrderkey )
        , Lbl_ShipTo         = MAX( PAKDT.T_ShipTo )
        , Lbl_Remark         = MAX( PAKDT.T_Remark )
        , Lbl_Route          = MAX( PAKDT.T_Route )
        , Lbl_Wavekey        = MAX( PAKDT.T_Wavekey )
        , Lbl_DeliveryOn     = MAX( PAKDT.T_DeliveryOn )
        , Lbl_Carton         = MAX( PAKDT.T_Carton )
        , Lbl_StoreNo        = MAX( PAKDT.T_StoreNo )
        , Sku                = MAX( PAKDT.Sku )
        , Sorting            = MAX( PAKDT.Sorting )

   FROM #TEMP_PAKDT PAKDT

   GROUP BY PAKDT.PickSlipNo
          , PAKDT.CartonNo
          , PAKDT.LabelNo

   ORDER BY PickSlipNo
          , CartonNo
          , LabelNo


   WHILE @@TRANCOUNT > @n_StartTCnt
      COMMIT TRAN
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN
END

GO