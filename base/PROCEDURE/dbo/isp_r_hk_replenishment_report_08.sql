SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_replenishment_report_08                    */
/* Creation Date: 02-Dec-2020                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Discrete Pickslip                                            */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_replenishment_report_08     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 23/03/2022   ML       1.1  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROC [dbo].[isp_r_hk_replenishment_report_08] (
       @as_storerkey   NVARCHAR(15)
     , @as_wavekey     NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   /* CODELKUP.REPORTCFG
      [MAPFIELD]
         Channel, Remarks, RemarkKeys

      [MAPVALUE]
         LocationType

      [SHOWFIELD]
         IDBarcode, Channel

      [SQLJOIN]
      [SQLWHERE]
   */

   DECLARE @c_DataWindow       NVARCHAR(40) = 'r_hk_replenishment_report_08'
         , @c_ExecStatements   NVARCHAR(MAX)
         , @c_ExecArguments    NVARCHAR(MAX)
         , @c_JoinClause       NVARCHAR(MAX)
         , @c_WhereClause      NVARCHAR(MAX)
         , @c_ShowFields       NVARCHAR(MAX)
         , @c_LocationTypes    NVARCHAR(MAX)
         , @c_ChannelExp       NVARCHAR(MAX)
         , @c_RemarksExp       NVARCHAR(MAX)
         , @c_RemarkKeysExp    NVARCHAR(MAX)
         , @c_AllStorers       NVARCHAR(1)  = 'N'
         , @c_Storerkey        NVARCHAR(15) = ''
         , @c_Temp             NVARCHAR(20)

   IF OBJECT_ID('tempdb..#TEMP_PIKDT') IS NOT NULL
      DROP TABLE #TEMP_PIKDT

   SET @as_storerkey = RTRIM(@as_storerkey)

   IF ISNULL(@as_wavekey,'')=''
      AND @as_storerkey LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%'
      AND SUBSTRING(@as_storerkey,11,LEN(@as_storerkey)) IN ('', ',WP')
   BEGIN
      SET @c_Temp = LEFT(@as_storerkey,10)
      IF EXISTS(SELECT TOP 1 1 FROM dbo.WAVE (NOLOCK) WHERE Wavekey = @c_Temp)
      BEGIN
         SET @as_wavekey   = @c_Temp
         SET @as_storerkey = ''
         SET @c_AllStorers = 'Y'
      END
   END

   CREATE TABLE #TEMP_PIKDT (
        Storerkey        NVARCHAR(15)   NULL
      , Wavekey          NVARCHAR(10)   NULL
      , Channel          NVARCHAR(20)   NULL
      , PutawayZone      NVARCHAR(10)   NULL
      , PA_Descr         NVARCHAR(60)   NULL
      , LogicalLoc       NVARCHAR(20)   NULL
      , Loc              NVARCHAR(10)   NULL
      , ID               NVARCHAR(20)   NULL
      , Sku              NVARCHAR(20)   NULL
      , Sku_Descr        NVARCHAR(60)   NULL
      , Qty              INT            NULL
      , Remarks          NVARCHAR(4000) NULL
      , SkuCount         INT            NULL
      , ShowFields       NVARCHAR(4000) NULL
   )

   -- Storerkey Loop
   DECLARE C_CUR_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT PD.Storerkey
     FROM dbo.ORDERS      OH (NOLOCK)
     JOIN dbo.PICKDETAIL  PD (NOLOCK) ON OH.Orderkey=PD.Orderkey
     JOIN dbo.LOC         LOC(NOLOCK) ON PD.Loc=LOC.Loc
    WHERE OH.Userdefine09 = @as_wavekey
      AND (@c_AllStorers='Y' OR OH.Storerkey = @as_storerkey)
      AND OH.Userdefine09 <> ''
      AND PD.Qty > 0

   OPEN C_CUR_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_JoinClause     = ''
           , @c_WhereClause    = ''
           , @c_ShowFields     = ''
           , @c_LocationTypes  = 'OTHER'
           , @c_ChannelExp     = ''
           , @c_RemarksExp     = ''
           , @c_RemarkKeysExp  = ''

      SELECT TOP 1
             @c_JoinClause = LTRIM(RTRIM(Notes))
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_WhereClause = LTRIM(RTRIM(Notes))
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

      SELECT TOP 1
             @c_LocationTypes = ISNULL((select top 1 b.ColValue
                                from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)), Notes) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)), Notes2) b
                                where a.SeqNo=b.SeqNo and a.ColValue='LocationType'), '')
      FROM dbo.CODELKUP (NOLOCK)
      WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_ChannelExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Channel')), '' )
           , @c_RemarksExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Remarks')), '' )
           , @c_RemarkKeysExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='RemarkKeys')), '' )
        FROM dbo.CODELKUP (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SET @c_ExecStatements =
        N'INSERT INTO #TEMP_PIKDT ('
        +    ' Storerkey, Wavekey, Channel, PutawayZone, PA_Descr, LogicalLoc, Loc, ID, Sku, Sku_Descr,'
        +    ' Qty, Remarks, SkuCount, ShowFields)'

      SET @c_ExecStatements = @c_ExecStatements
        + ' SELECT Storerkey   = RTRIM( ISNULL( UPPER( OH.Storerkey ), '''') )'
        +       ', Wavekey     = RTRIM( ISNULL( UPPER( OH.Userdefine09 ), '''') )'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Channel     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ChannelExp,'')<>'' THEN @c_ChannelExp ELSE '''''' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PutawayZone = RTRIM( ISNULL( UPPER( LOC.PutawayZone ), '''') )'
        +       ', PA_Descr    = RTRIM( ISNULL( PA.Descr, '''') )'
        +       ', LogicalLoc  = RTRIM( ISNULL( UPPER( LOC.LogicalLocation ), '''') )'
        +       ', Loc         = RTRIM( ISNULL( UPPER( PD.Loc ), '''') )'
        +       ', ID          = RTRIM( ISNULL( UPPER( PD.ID ), '''') )'
        +       ', Sku         = RTRIM( ISNULL( UPPER( PD.Sku ), '''') )'
        +       ', Sku_Descr   = RTRIM( ISNULL( SKU.Descr, '''') )'
        +       ', Qty         = PD.Qty'
      IF ISNULL(@c_RemarksExp,'')<>''
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
           +       ', Remarks  = ISNULL(RTRIM(' + @c_RemarksExp + '),'''')'
      END
      ELSE
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
           +       ', Remarks  = ISNULL(RTRIM(STUFF((SELECT DISTINCT '', '','
           +                   ' ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RemarkKeysExp,'')<>'' THEN @c_RemarkKeysExp ELSE 'OH1.Userdefine09' END + '),'''')'
           +                   ' FROM ORDERS OH1(NOLOCK), PICKDETAIL PD1(NOLOCK)'
           +                   ' WHERE OH1.Orderkey=PD1.Orderkey AND OH1.Userdefine09<>'''' AND PD1.ID<>'''' AND OH1.Userdefine09<>OH.Userdefine09 AND PD1.ID=PD.ID AND PD1.Status<''9'''
           +                   ' FOR XML PATH('''')),1,2,'''') ),'''')'
      END
      SET @c_ExecStatements = @c_ExecStatements
        +       ', SkuCount    = (SELECT COUNT(DISTINCT a.Sku) FROM dbo.LOTxLOCxID a(NOLOCK) WHERE a.Storerkey=PD.Storerkey AND a.ID=PD.ID AND a.Qty>0 AND a.ID<>'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ShowFields       = @c_ShowFields'

      SET @c_ExecStatements = @c_ExecStatements
        +  ' FROM dbo.ORDERS      OH (NOLOCK)'
        +  ' JOIN dbo.PICKDETAIL  PD (NOLOCK) ON OH.Orderkey=PD.Orderkey'
        +  ' JOIN dbo.SKU         SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku'
        +  ' JOIN dbo.LOC         LOC(NOLOCK) ON PD.Loc=LOC.Loc'
        +  ' JOIN dbo.PUTAWAYZONE PA (NOLOCK) ON LOC.PutawayZone=PA.PutawayZone'

      SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END

      SET @c_ExecStatements = @c_ExecStatements
        + ' WHERE OH.Userdefine09 = @c_Wavekey'
        +   ' AND (@c_AllStorers=''Y'' OR OH.Storerkey = @c_Storerkey)'
        +   ' AND OH.Userdefine09 <> '''''
        +   ' AND PD.Qty > 0'

      IF ISNULL(@c_WhereClause,'')<>''
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
             + CASE WHEN ISNULL(@c_WhereClause,'')='' THEN '' ELSE ' AND (' + ISNULL(LTRIM(RTRIM(@c_WhereClause)),'') +')' END
      END
      ELSE
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
           +   ' AND LOC.LocationType IN (SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@c_LocationTypes,'','') WHERE value<>'''')'
      END


      SET @c_ExecArguments = N'@c_DataWindow    NVARCHAR(40)'
                           + ',@c_ShowFields    NVARCHAR(MAX)'
                           + ',@c_LocationTypes NVARCHAR(MAX)'
                           + ',@c_Storerkey     NVARCHAR(15)'
                           + ',@c_Wavekey       NVARCHAR(10)'
                           + ',@c_AllStorers    NVARCHAR(1)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_DataWindow
                       , @c_ShowFields
                       , @c_LocationTypes
                       , @as_Storerkey
                       , @as_wavekey
                       , @c_AllStorers
   END

   CLOSE C_CUR_STORERKEY
   DEALLocATE C_CUR_STORERKEY



   SELECT Storerkey   = X.Storerkey
        , Wavekey     = X.Wavekey
        , Channel     = ISNULL( CASE WHEN MAX(X.ShowFields) LIKE '%,channel,%' THEN MAX(X.Channel) END, '')
        , PutawayZone = MAX( X.PutawayZone )
        , PA_Descr    = MAX( X.PA_Descr )
        , LogicalLoc  = MAX( X.LogicalLoc )
        , Loc         = X.Loc
        , ID          = X.ID
        , Sku         = MAX( CASE WHEN X.SkuCount>1 THEN '**MULTI SKU**' ELSE X.Sku       END )
        , Sku_Descr   = MAX( CASE WHEN X.SkuCount>1 THEN ''              ELSE X.Sku_Descr END )
        , Qty         = SUM( X.Qty )
        , Remarks     = MAX( X.Remarks )
        , DWName      = @c_DataWindow
        , ShowFields  = MAX( X.ShowFields )

   FROM #TEMP_PIKDT X

   GROUP BY X.Storerkey
          , X.Wavekey
          , X.Loc
          , X.ID

   ORDER BY Wavekey
          , PutawayZone
          , LogicalLoc
          , Loc
          , ID
END

GO