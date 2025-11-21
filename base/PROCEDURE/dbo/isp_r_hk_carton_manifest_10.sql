SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_carton_manifest_10                         */
/* Creation Date: 22-Apr-2020                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: VF Carton Manifest Label                                     */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_carton_manifest_10          */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 26/03/2021   Michael  v1.1 WMS-16649 AEO - Manifest Label Modification*/
/* 16/03/2022   Michael  v1.2 WMS-19215 AEO - 1. Add SQLWHERE            */
/*                            2. Add MapField: Notes, Descr, T_*, N_*    */
/*                            3. Add ShowField                           */
/* 23/03/2022   Michael  v1.3 Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_carton_manifest_10] (
       @as_pickslipno     NVARCHAR(10)
     , @as_cartonnostart  NVARCHAR(20)
     , @as_cartonnoend    NVARCHAR(20)
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
      ExternOrderkey, DischargePlace, Notes, CartonNo, LabelNo, Class, Style, Color, Size, Measurement, MaxCartonNo, PrintDate, Qty, Descr, Refno
      T_UCCNo, T_OBD, T_CARTON, T_TotalQty, T_Class, T_Style, T_Color, T_Size_Dim, T_Qty
      N_Xpos_Class, N_Xpos_Style, N_Xpos_Color, N_Xpos_Size_Dim, N_Xpos_Qty
      N_Width_Class, N_Width_Style, N_Width_Color, N_Width_Size_Dim, N_Width_Qty

   [MAPVALUE]
      T_UCCNo, T_OBD, T_CARTON, T_TotalQty, T_Class, T_Style, T_Color, T_Size_Dim, T_Qty
      N_Xpos_Class, N_Xpos_Style, N_Xpos_Color, N_Xpos_Size_Dim, N_Xpos_Qty
      N_Width_Class, N_Width_Style, N_Width_Color, N_Width_Size_Dim, N_Width_Qty

   [SHOWFIELD]
      Class, HideStyle, HideColor, HideSizeDim, HideQty, DischargePlaceFontS, DischargePlaceFontS2, DescrFontS, DescrFontS2

   [SQLJOIN]

   [SQLWHERE]
*/

   IF OBJECT_ID('tempdb..#TEMP_PACKDETAIL') IS NOT NULL
      DROP TABLE #TEMP_PACKDETAIL
   IF OBJECT_ID('tempdb..#TEMP_PAKDT') IS NOT NULL
      DROP TABLE #TEMP_PAKDT

   DECLARE @c_DataWindow         NVARCHAR(40)  = 'r_hk_carton_manifest_10'
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(MAX)
         , @c_WhereClause        NVARCHAR(MAX)
         , @c_ShowFields         NVARCHAR(MAX)
         , @c_ExternOrderkeyExp  NVARCHAR(MAX)
         , @c_DischargePlaceExp  NVARCHAR(MAX)
         , @c_NotesExp           NVARCHAR(MAX)
         , @c_CartonNoExp        NVARCHAR(MAX)
         , @c_LabelNoExp         NVARCHAR(MAX)
         , @c_ClassExp           NVARCHAR(MAX)
         , @c_StyleExp           NVARCHAR(MAX)
         , @c_ColorExp           NVARCHAR(MAX)
         , @c_SizeExp            NVARCHAR(MAX)
         , @c_MeasurementExp     NVARCHAR(MAX)
         , @c_MaxCartonNoExp     NVARCHAR(MAX)
         , @c_QtyExp             NVARCHAR(MAX)
         , @c_DescrExp           NVARCHAR(MAX)
         , @c_PrintDateExp       NVARCHAR(MAX)
         , @c_RefnoExp           NVARCHAR(MAX)
         , @c_T_UCCNoExp         NVARCHAR(MAX)
         , @c_T_OBDExp           NVARCHAR(MAX)
         , @c_T_CARTONExp        NVARCHAR(MAX)
         , @c_T_TotalQtyExp      NVARCHAR(MAX)
         , @c_T_ClassExp         NVARCHAR(MAX)
         , @c_T_StyleExp         NVARCHAR(MAX)
         , @c_T_ColorExp         NVARCHAR(MAX)
         , @c_T_Size_DimExp      NVARCHAR(MAX)
         , @c_T_QtyExp           NVARCHAR(MAX)
         , @c_N_X_ClassExp       NVARCHAR(MAX)
         , @c_N_X_StyleExp       NVARCHAR(MAX)
         , @c_N_X_ColorExp       NVARCHAR(MAX)
         , @c_N_X_Size_DimExp    NVARCHAR(MAX)
         , @c_N_X_QtyExp         NVARCHAR(MAX)
         , @c_N_W_ClassExp       NVARCHAR(MAX)
         , @c_N_W_StyleExp       NVARCHAR(MAX)
         , @c_N_W_ColorExp       NVARCHAR(MAX)
         , @c_N_W_Size_DimExp    NVARCHAR(MAX)
         , @c_N_W_QtyExp         NVARCHAR(MAX)
         , @c_Storerkey          NVARCHAR(15)

   CREATE TABLE #TEMP_PAKDT (
        PickSlipNo       NVARCHAR(10)  NULL
      , ExternOrderkey   NVARCHAR(50)  NULL
      , DischargePlace   NVARCHAR(50)  NULL
      , Notes            NVARCHAR(500) NULL
      , CartonNo         INT           NULL
      , LabelNo          NVARCHAR(50)  NULL
      , [Class]          NVARCHAR(50)  NULL
      , Style            NVARCHAR(50)  NULL
      , Color            NVARCHAR(50)  NULL
      , [Size]           NVARCHAR(50)  NULL
      , Measurement      NVARCHAR(50)  NULL
      , MaxCartonNo      NVARCHAR(50)  NULL
      , Qty              INT           NULL
      , Descr            NVARCHAR(500) NULL
      , PrintDate        NVARCHAR(50)  NULL
      , RefNo            NVARCHAR(500) NULL
      , Storerkey        NVARCHAR(15)  NULL
      , T_UCCNo          NVARCHAR(500) NULL
      , T_OBD            NVARCHAR(500) NULL
      , T_CARTON         NVARCHAR(500) NULL
      , T_TotalQty       NVARCHAR(500) NULL
      , T_Class          NVARCHAR(500) NULL
      , T_Style          NVARCHAR(500) NULL
      , T_Color          NVARCHAR(500) NULL
      , T_Size_Dim       NVARCHAR(500) NULL
      , T_Qty            NVARCHAR(500) NULL
      , N_Xpos_Class     NVARCHAR(50)  NULL
      , N_Xpos_Style     NVARCHAR(50)  NULL
      , N_Xpos_Color     NVARCHAR(50)  NULL
      , N_Xpos_Size_Dim  NVARCHAR(50)  NULL
      , N_Xpos_Qty       NVARCHAR(50)  NULL
      , N_Width_Class    NVARCHAR(50)  NULL
      , N_Width_Style    NVARCHAR(50)  NULL
      , N_Width_Color    NVARCHAR(50)  NULL
      , N_Width_Size_Dim NVARCHAR(50)  NULL
      , N_Width_Qty      NVARCHAR(50)  NULL
   )

   SELECT *
     INTO #TEMP_PACKDETAIL
     FROM dbo.PACKDETAIL (NOLOCK)
    WHERE 1=2

   IF EXISTS (SELECT TOP 1 1 FROM PACKDETAIL WITH (NOLOCK) WHERE PickSlipNo = @as_pickslipno AND (LabelNo = @as_cartonnostart OR LabelNo = @as_cartonnoend) )
   BEGIN
      INSERT INTO #TEMP_PACKDETAIL
      SELECT *
        FROM dbo.PACKDETAIL (NOLOCK)
       WHERE PickSlipNo = @as_pickslipno
         AND LabelNo BETWEEN @as_cartonnostart AND @as_cartonnoend
   END
   ELSE
   BEGIN
      INSERT INTO #TEMP_PACKDETAIL
      SELECT *
        FROM dbo.PACKDETAIL (NOLOCK)
       WHERE PickSlipNo = @as_pickslipno
         AND CartonNo BETWEEN CAST(@as_cartonnostart AS INT) AND CAST(@as_cartonnoend AS INT)
   END


   -- Storerkey Loop
   DECLARE C_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
     FROM #TEMP_PACKDETAIL
    ORDER BY 1

   OPEN C_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_ExecStatements    = ''
           , @c_ExecArguments     = ''
           , @c_JoinClause        = ''
           , @c_WhereClause       = ''
           , @c_ShowFields        = ''
           , @c_ExternOrderkeyExp = ''
           , @c_DischargePlaceExp = ''
           , @c_NotesExp          = ''
           , @c_CartonNoExp       = ''
           , @c_LabelNoExp        = ''
           , @c_ClassExp          = ''
           , @c_StyleExp          = ''
           , @c_ColorExp          = ''
           , @c_SizeExp           = ''
           , @c_MeasurementExp    = ''
           , @c_MaxCartonNoExp    = ''
           , @c_QtyExp            = ''
           , @c_DescrExp          = ''
           , @c_PrintDateExp      = ''
           , @c_RefnoExp          = ''
           , @c_T_UCCNoExp        = ''
           , @c_T_OBDExp          = ''
           , @c_T_CARTONExp       = ''
           , @c_T_TotalQtyExp     = ''
           , @c_T_StyleExp        = ''
           , @c_T_ColorExp        = ''
           , @c_T_Size_DimExp     = ''
           , @c_T_QtyExp          = ''
           , @c_N_X_ClassExp      = ''
           , @c_N_X_StyleExp      = ''
           , @c_N_X_ColorExp      = ''
           , @c_N_X_Size_DimExp   = ''
           , @c_N_X_QtyExp        = ''
           , @c_N_W_ClassExp      = ''
           , @c_N_W_StyleExp      = ''
           , @c_N_W_ColorExp      = ''
           , @c_N_W_Size_DimExp   = ''
           , @c_N_W_QtyExp        = ''

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

      SELECT TOP 1
             @c_ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
      FROM dbo.CODELKUP (NOLOCK)
      WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      ----------
      SELECT TOP 1
             @c_ExternOrderkeyExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderkey')), '' )
           , @c_DischargePlaceExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DischargePlace')), '' )
           , @c_NotesExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Notes')), '' )
           , @c_CartonNoExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='CartonNo')), '' )
           , @c_LabelNoExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LabelNo')), '' )
           , @c_ClassExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Class')), '' )
           , @c_StyleExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Style')), '' )
           , @c_ColorExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Color')), '' )
           , @c_SizeExp            = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Size')), '' )
           , @c_MeasurementExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Measurement')), '' )
           , @c_MaxCartonNoExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='MaxCartonNo')), '' )
           , @c_QtyExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Qty')), '' )
           , @c_DescrExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Descr')), '' )
           , @c_PrintDateExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='PrintDate')), '' )
           , @c_RefnoExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Refno')), '' )
           , @c_T_UCCNoExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_UCCNo')), '' )
           , @c_T_OBDExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_OBD')), '' )
           , @c_T_CARTONExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_CARTON')), '' )
           , @c_T_TotalQtyExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_TotalQty')), '' )
           , @c_T_ClassExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Class')), '' )
           , @c_T_StyleExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Style')), '' )
           , @c_T_ColorExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Color')), '' )
           , @c_T_Size_DimExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Size_Dim')), '' )
           , @c_T_QtyExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Qty')), '' )
           , @c_N_X_ClassExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Class')), '' )
           , @c_N_X_StyleExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Style')), '' )
           , @c_N_X_ColorExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Color')), '' )
           , @c_N_X_Size_DimExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Size_Dim')), '' )
           , @c_N_X_QtyExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Qty')), '' )
           , @c_N_W_ClassExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Class')), '' )
           , @c_N_W_StyleExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Style')), '' )
           , @c_N_W_ColorExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Color')), '' )
           , @c_N_W_Size_DimExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Size_Dim')), '' )
           , @c_N_W_QtyExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Qty')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SET @c_ExecStatements = N'INSERT INTO #TEMP_PAKDT'
        + ' (PickSlipNo, ExternOrderkey, DischargePlace, Notes, CartonNo, LabelNo, [Class], Style, Color, [Size], Measurement, MaxCartonNo, Qty, Descr, PrintDate, RefNo,'
        +  ' T_UCCNo, T_OBD, T_CARTON, T_TotalQty, T_Class, T_Style, T_Color, T_Size_Dim, T_Qty,'
        +  ' N_Xpos_Class, N_Xpos_Style, N_Xpos_Color, N_Xpos_Size_Dim, N_Xpos_Qty, N_Width_Class, N_Width_Style, N_Width_Color, N_Width_Size_Dim, N_Width_Qty,'
        +  ' Storerkey)'
        +  ' SELECT PickSlipNo     = PH.PickSlipNo'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', ExternOrderkey = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExternOrderkeyExp ,'')<>'' THEN @c_ExternOrderkeyExp  ELSE 'OH.ExternOrderkey'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', DischargePlace = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DischargePlaceExp ,'')<>'' THEN @c_DischargePlaceExp  ELSE 'OH.DischargePlace'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', Notes          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_NotesExp          ,'')<>'' THEN @c_NotesExp           ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', CartonNo       = '              + CASE WHEN ISNULL(@c_CartonNoExp       ,'')<>'' THEN @c_CartonNoExp        ELSE 'PD.CartonNo'              END
      SET @c_ExecStatements = @c_ExecStatements
        +        ', LabelNo        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LabelNoExp        ,'')<>'' THEN @c_LabelNoExp         ELSE 'FORMATMESSAGE(''(%s) %s %s %s %s %s'','
        +                          ' LEFT(PD.LabelNo,2),SUBSTRING(PD.LabelNo,3,1),SUBSTRING(PD.LabelNo,4,2),SUBSTRING(PD.LabelNo,6,5),SUBSTRING(PD.LabelNo,11,9),SUBSTRING(PD.LabelNo,20,1))' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', [Class]        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ClassExp          ,'')<>'' THEN @c_ClassExp           ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', Style          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_StyleExp          ,'')<>'' THEN @c_StyleExp           ELSE 'SKU.Style'                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', Color          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ColorExp          ,'')<>'' THEN @c_ColorExp           ELSE 'SKU.Color'                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', [Size]         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SizeExp           ,'')<>'' THEN @c_SizeExp            ELSE 'SKU.Size'                 END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', Measurement    = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_MeasurementExp    ,'')<>'' THEN @c_MeasurementExp     ELSE 'SKU.Measurement'          END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', MaxCartonNo    = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_MaxCartonNoExp    ,'')<>'' THEN @c_MaxCartonNoExp     ELSE
        +                               '(SELECT ISNULL(CONVERT(NVARCHAR(10),MAX(P2.CartonNo)),'''')'
        +                               ' FROM PACKDETAIL P2(NOLOCK)'
        +                               ' WHERE P2.PickSlipNo=PH.PickSlipNo'
        +                               ' HAVING SUM(P2.Qty)>='
        +                                      '(SELECT SUM(ISNULL(c.Qty,e.Qty))'
        +                                      ' FROM PICKHEADER      a(NOLOCK)'
        +                                      ' LEFT JOIN ORDERS     b(NOLOCK) ON a.Orderkey=b.Orderkey AND a.Orderkey<>'''''
        +                                      ' LEFT JOIN PICKDETAIL c(NOLOCK) ON b.Orderkey=c.Orderkey'
        +                                      ' LEFT JOIN ORDERS     d(NOLOCK) ON a.ExternOrderkey = d.Loadkey AND a.ExternOrderkey<>'''' AND ISNULL(a.Orderkey,'''')='''''
        +                                      ' LEFT JOIN PICKDETAIL e(NOLOCK) ON d.Orderkey=e.Orderkey'
        +                                      ' WHERE a.PickHeaderkey=PH.PickSlipNo))'
                                               END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', Qty            = ISNULL('       + CASE WHEN ISNULL(@c_QtyExp            ,'')<>'' THEN @c_QtyExp             ELSE 'PD.Qty'                   END + ','''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', Descr          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DescrExp          ,'')<>'' THEN @c_DescrExp           ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', PrintDate      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PrintDateExp      ,'')<>'' THEN @c_PrintDateExp       ELSE 'CONVERT(NVARCHAR(10),GETDATE(),103)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', RefNo          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RefnoExp          ,'')<>'' THEN @c_RefnoExp           ELSE ''''''                     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_UCCNoExp        ,'')<>'' THEN @c_T_UCCNoExp         ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_OBDExp          ,'')<>'' THEN @c_T_OBDExp           ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_CARTONExp       ,'')<>'' THEN @c_T_CARTONExp        ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_TotalQtyExp     ,'')<>'' THEN @c_T_TotalQtyExp      ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_ClassExp        ,'')<>'' THEN @c_T_ClassExp         ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_StyleExp        ,'')<>'' THEN @c_T_StyleExp         ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_ColorExp        ,'')<>'' THEN @c_T_ColorExp         ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_Size_DimExp     ,'')<>'' THEN @c_T_Size_DimExp      ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_T_QtyExp          ,'')<>'' THEN @c_T_QtyExp           ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_X_ClassExp      ,'')<>'' THEN @c_N_X_ClassExp       ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_X_StyleExp      ,'')<>'' THEN @c_N_X_StyleExp       ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_X_ColorExp      ,'')<>'' THEN @c_N_X_ColorExp       ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_X_Size_DimExp   ,'')<>'' THEN @c_N_X_Size_DimExp    ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_X_QtyExp        ,'')<>'' THEN @c_N_X_QtyExp         ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_W_ClassExp      ,'')<>'' THEN @c_N_W_ClassExp       ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_W_StyleExp      ,'')<>'' THEN @c_N_W_StyleExp       ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_W_ColorExp      ,'')<>'' THEN @c_N_W_ColorExp       ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_W_Size_DimExp   ,'')<>'' THEN @c_N_W_Size_DimExp    ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
               +        ', RTRIM(' + CASE WHEN ISNULL(@c_N_W_QtyExp        ,'')<>'' THEN @c_N_W_QtyExp         ELSE 'NULL'              END + ')'
      SET @c_ExecStatements = @c_ExecStatements
        +        ', Storerkey      = OH.Storerkey'
        +  ' FROM dbo.ORDERS       OH (NOLOCK)'
        +  ' JOIN dbo.PACKHEADER   PH (NOLOCK) ON OH.OrderKey   = PH.OrderKey'
        +  ' JOIN #TEMP_PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo'
        +  ' JOIN dbo.SKU          SKU(NOLOCK) ON PD.Storerkey  = SKU.Storerkey AND PD.Sku = SKU.Sku'
      SET @c_ExecStatements = @c_ExecStatements
        + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END

      SET @c_ExecStatements = @c_ExecStatements
        +  ' WHERE OH.Storerkey = @c_Storerkey'
      SET @c_ExecStatements = @c_ExecStatements
        + CASE WHEN ISNULL(@c_WhereClause,'')='' THEN '' ELSE ' AND (' + ISNULL(LTRIM(RTRIM(@c_WhereClause)),'') + ')' END


      SET @c_ExecArguments = N'@c_Storerkey   NVARCHAR(15)'
                           + ',@c_DataWindow  NVARCHAR(40)'
                           + ',@c_ShowFields  NVARCHAR(MAX)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Storerkey
                       , @c_DataWindow
                       , @c_ShowFields
   END

   CLOSE C_STORERKEY
   DEALLOCATE C_STORERKEY


   SELECT PickSlipNo        = PAKDT.PickSlipNo
        , ExternOrderkey    = PAKDT.ExternOrderkey
        , DischargePlace    = PAKDT.DischargePlace
        , CartonNo          = PAKDT.CartonNo
        , LabelNo           = PAKDT.LabelNo
        , Style             = PAKDT.Style
        , Color             = PAKDT.Color
        , [Size]            = PAKDT.[Size]
        , Measurement       = PAKDT.Measurement
        , MaxCartonNo       = PAKDT.MaxCartonNo
        , Qty               = SUM( PAKDT.Qty )
        , PrintDate         = MAX( PAKDT.PrintDate )
        , RefNo             = PAKDT.RefNo
        , Lbl_UCCNo         = CAST( RTRIM( ISNULL(MAX(PAKDT.T_UCCNo), (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_UCCNo')) ) AS NVARCHAR(500))
        , Lbl_OBD           = CAST( RTRIM( ISNULL(MAX(PAKDT.T_OBD), (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_OBD')) ) AS NVARCHAR(500))
        , Lbl_CARTON        = CAST( RTRIM( ISNULL(MAX(PAKDT.T_CARTON), (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_CARTON')) ) AS NVARCHAR(500))
        , Lbl_TotalQty      = CAST( RTRIM( ISNULL(MAX(PAKDT.T_TotalQty), (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_TotalQty')) ) AS NVARCHAR(500))
        , Lbl_Style         = CAST( RTRIM( ISNULL(MAX(PAKDT.T_Style), (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Style')) ) AS NVARCHAR(500))
        , Lbl_Color         = CAST( RTRIM( ISNULL(MAX(PAKDT.T_Color), (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Color')) ) AS NVARCHAR(500))
        , Lbl_Size_Dim      = CAST( RTRIM( ISNULL(MAX(PAKDT.T_Size_dim), (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Size_Dim')) ) AS NVARCHAR(500))
        , Lbl_Qty           = CAST( RTRIM( ISNULL(MAX(PAKDT.T_Qty), (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Qty')) ) AS NVARCHAR(500))
        , Lbl_Class         = CAST( RTRIM( ISNULL(MAX(PAKDT.T_Class), (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Class')) ) AS NVARCHAR(500))
        , Notes             = MAX( PAKDT.Notes )
        , [Class]           = PAKDT.[Class]
        , Descr             = MAX( PAKDT.Descr )
        , N_Xpos_Class      = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Xpos_Class), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Class')) ) AS NVARCHAR(50))
        , N_Xpos_Style      = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Xpos_Style), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Style')) ) AS NVARCHAR(50))
        , N_Xpos_Color      = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Xpos_Color), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Color')) ) AS NVARCHAR(50))
        , N_Xpos_Size_Dim   = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Xpos_Size_Dim), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Size_Dim')) ) AS NVARCHAR(50))
        , N_Xpos_Qty        = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Xpos_Qty), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Qty')) ) AS NVARCHAR(50))
        , N_Width_Class     = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Width_Class), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Class')) ) AS NVARCHAR(50))
        , N_Width_Style     = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Width_Style), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Style')) ) AS NVARCHAR(50))
        , N_Width_Color     = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Width_Color), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Color')) ) AS NVARCHAR(50))
        , N_Width_Size_Dim  = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Width_Size_Dim), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Size_Dim')) ) AS NVARCHAR(50))
        , N_Width_Qty       = CAST( RTRIM( ISNULL(MAX(PAKDT.N_Width_Qty), (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Qty')) ) AS NVARCHAR(50))
        , ShowFields         = MAX( RptCfg.ShowFields )

   FROM #TEMP_PAKDT PAKDT

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
          , PAKDT.ExternOrderkey
          , PAKDT.DischargePlace
          , PAKDT.CartonNo
          , PAKDT.LabelNo
          , PAKDT.[Class]
          , PAKDT.Style
          , PAKDT.Color
          , PAKDT.[Size]
          , PAKDT.Measurement
          , PAKDT.MaxCartonNo
          , PAKDT.RefNo

   ORDER BY PickSlipNo, CartonNo, Style, Color, Size, Measurement
END

GO