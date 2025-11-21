SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_picking_control_list_07a                   */
/* Creation Date: 04-Sep-2019                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: PVH Picking Control List                                     */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_picking_control_list_07a    */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 19/09/2019   ML       1.1  1. Include PD.Status = 3                   */
/*                            2. Exclude PD.UOM = 2 (FCP)                */
/* 11/08/2021   ML       1.2  WMS-17708 Add MAPFILED: Suggest_PAZone,    */
/*                            T_Suggest_PAZone, T_PutawayZone            */
/* 23/03/2022   ML       1.3  Add NULL to Temp Table                     */
/*************************************************************************/
CREATE PROCEDURE [dbo].[isp_r_hk_picking_control_list_07a] (
       @as_storerkey NVARCHAR(15)
     , @as_wavekey   NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      Suggest_PAZone, T_Suggest_PAZone, T_PutawayZone

   [SQLJOIN]
*/

   DECLARE @c_DataWindow          NVARCHAR(40)  = 'r_hk_picking_control_list_07a'
         , @c_ExecStatements      NVARCHAR(MAX) = ''
         , @c_ExecArguments       NVARCHAR(MAX) = ''
         , @c_JoinClause          NVARCHAR(MAX) = ''
         , @c_ShowFields          NVARCHAR(MAX) = ''
         , @c_Suggest_PAZoneExp   NVARCHAR(MAX) = ''
         , @c_T_Suggest_PAZoneExp NVARCHAR(MAX) = ''
         , @c_T_PutawayZoneExp    NVARCHAR(MAX) = ''
         , @n_Ttl_Carton          INT           = 0


   IF OBJECT_ID('tempdb..#TEMP_PICKDETAIL') IS NOT NULL
      DROP TABLE #TEMP_PICKDETAIL

   CREATE TABLE #TEMP_PICKDETAIL (
        Storerkey          NVARCHAR(30) NULL
      , CustomerGroupCode  NVARCHAR(40) NULL
      , Wavekey            NVARCHAR(20) NULL
      , Wave_AddDate       DATETIME     NULL
      , CaseID             NVARCHAR(40) NULL
      , PutawayZone        NVARCHAR(20) NULL
      , PickZone           NVARCHAR(20) NULL
      , Loc                NVARCHAR(20) NULL
      , Qty                INT          NULL
      , ReqReplen          VARCHAR (1 ) NULL
      , Suggest_PAZone     NVARCHAR(50) NULL
      , T_Suggest_PAZone   NVARCHAR(50) NULL
      , T_PutawayZone      NVARCHAR(50) NULL
   )

   SELECT TOP 1
          @c_ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
      AND Storerkey = @as_storerkey
    ORDER BY Code2

   SELECT TOP 1
          @c_JoinClause = Notes
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
      AND Storerkey = @as_storerkey
    ORDER BY Code2

   SELECT TOP 1
          @c_Suggest_PAZoneExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='Suggest_PAZone')), '' )
        , @c_T_Suggest_PAZoneExp= ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='T_Suggest_PAZone')), '' )
        , @c_T_PutawayZoneExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='T_PutawayZone')), '' )
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
      AND Storerkey = @as_storerkey
    ORDER BY Code2


   SET @c_ExecStatements =
      N'INSERT INTO #TEMP_PICKDETAIL (Storerkey, CustomerGroupCode, Wavekey, Wave_AddDate, CaseID, PutawayZone, PickZone, Loc, Qty, ReqReplen,'
     +                              ' Suggest_PAZone, T_Suggest_PAZone, T_PutawayZone)'
     +' SELECT Storerkey         = ISNULL(RTRIM(OH.Storerkey),'''')'
     +      ', CustomerGroupCode = ISNULL(RTRIM(ST.CustomerGroupCode),'''')'
     +      ', Wavekey           = ISNULL(RTRIM(OH.Userdefine09),'''')'
     +      ', Wave_AddDate      = WAVE.AddDate'
     +      ', CaseID            = ISNULL(RTRIM(PD.CaseID),'''')'
     +      ', PutawayZone       = ISNULL(RTRIM(LOC.PutawayZone),'''')'
     +      ', PickZone          = ISNULL(RTRIM(LOC.PickZone),'''')'
     +      ', Loc               = ISNULL(RTRIM(PD.Loc),'''')'
     +      ', Qty               = PD.Qty'
     +      ', ReqReplen         = IIF(LOC.LocationType=''OTHER'',''Y'',''N'')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', Suggest_PAZone    = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Suggest_PAZoneExp  ,'')<>'' THEN @c_Suggest_PAZoneExp   ELSE ''''''              END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', T_Suggest_PAZone  = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_Suggest_PAZoneExp,'')<>'' THEN @c_T_Suggest_PAZoneExp ELSE '''Suggested First PA Zone:''' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', T_PutawayZone     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_T_PutawayZoneExp   ,'')<>'' THEN @c_T_PutawayZoneExp    ELSE '''PutawayZone'''   END + '),'''')'

   SET @c_ExecStatements = @c_ExecStatements
     + ' FROM dbo.ORDERS     OH  (NOLOCK)'
     + ' JOIN dbo.STORER     ST  (NOLOCK) ON OH.Storerkey = ST.Storerkey'
     + ' JOIN dbo.WAVE       WAVE(NOLOCK) ON OH.Userdefine09 = WAVE.Wavekey'
     + ' JOIN dbo.PICKDETAIL PD  (NOLOCK) ON OH.Orderkey = PD.Orderkey'
     + ' JOIN dbo.LOC        LOC (NOLOCK) ON PD.Loc = LOC.Loc'
   SET @c_ExecStatements = @c_ExecStatements
     + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END

   SET @c_ExecStatements = @c_ExecStatements
     +' WHERE OH.Storerkey    = @as_storerkey'
     +  ' AND OH.Userdefine09 = @as_wavekey'
     +  ' AND OH.Userdefine09<>'''''
     +  ' AND PD.Status <= ''3'''
     +  ' AND ISNULL(PD.UOM,'''') <> ''2'''
     +  ' AND PD.Qty > 0'

   SET @c_ExecArguments = N'@as_storerkey NVARCHAR(15)'
                        + ',@as_wavekey NVARCHAR(10)'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @as_wavekey


   SELECT @n_Ttl_Carton = COUNT(DISTINCT CaseID) FROM #TEMP_PICKDETAIL WHERE CaseID <>''


   SELECT Storerkey         = Z.Storerkey
        , CustomerGroupCode = MAX(Z.CustomerGroupCode)
        , Wavekey           = Z.Wavekey
        , Wave_AddDate      = MAX(Z.Wave_AddDate)
        , ReqReplen         = Z.ReqReplen
        , Suggest_PAZone    = Z.Suggest_PAZone
        , PA_PickZone       = 0
        , PA_PickLoc        = 0
        , PA_NoOfCtn        = 0
        , Qty               = 0
        , LineSeq           = FLOOR((Z.SeqNo+5) / 6)
        , CaseID_01         = MAX(CASE WHEN (Z.SeqNo-1)%6=0 THEN Z.CaseID END)
        , CaseID_02         = MAX(CASE WHEN (Z.SeqNo-1)%6=1 THEN Z.CaseID END)
        , CaseID_03         = MAX(CASE WHEN (Z.SeqNo-1)%6=2 THEN Z.CaseID END)
        , CaseID_04         = MAX(CASE WHEN (Z.SeqNo-1)%6=3 THEN Z.CaseID END)
        , CaseID_05         = MAX(CASE WHEN (Z.SeqNo-1)%6=4 THEN Z.CaseID END)
        , CaseID_06         = MAX(CASE WHEN (Z.SeqNo-1)%6=5 THEN Z.CaseID END)
        , Ttl_Carton        = @n_Ttl_Carton
        , Datawindow        = @c_DataWindow
        , Section           = 2
        , PageNo            = ROW_NUMBER() OVER(PARTITION BY Z.Storerkey, Z.Wavekey ORDER BY Z.ReqReplen, Z.Suggest_PAZone, FLOOR((Z.SeqNo+5) / 6))
        , ShowFields        = @c_ShowFields
        , Lbl_Suggest_PAZone= MAX(Z.T_Suggest_PAZone)
        , Lbl_PutawayZone   = MAX(Z.T_PutawayZone)
   FROM (
      SELECT Y.*
           , SeqNo = ROW_NUMBER() OVER(PARTITION BY Y.Storerkey, Y.Wavekey, Y.ReqReplen, Y.Suggest_PAZone  ORDER BY Y.CaseID)
      FROM (
         SELECT Storerkey         = X.Storerkey
              , CustomerGroupCode = MAX(X.CustomerGroupCode)
              , Wavekey           = X.Wavekey
              , Wave_AddDate      = MAX(X.Wave_AddDate)
              , Suggest_PAZone    = CASE WHEN ISNULL(@c_Suggest_PAZoneExp,'')<>'' THEN MAX(X.Suggest_PAZone)
                                         ELSE ISNULL((SELECT TOP 1 a.PutawayZone FROM #TEMP_PICKDETAIL a
                                             WHERE a.Storerkey=X.Storerkey AND a.Wavekey=X.Wavekey AND a.CaseID=X.CaseID
                                               AND a.CaseID<>'' GROUP BY a.CaseID, a.PutawayZone
                                             ORDER BY SUM(a.Qty) DESC, a.PutawayZone), '')
                                    END
              , CaseID            = X.CaseID
              , ReqReplen         = MAX(X.ReqReplen)
              , T_Suggest_PAZone  = MAX(X.T_Suggest_PAZone)
              , T_PutawayZone     = MAX(X.T_PutawayZone)
         FROM #TEMP_PICKDETAIL X
         GROUP BY X.Storerkey
                , X.Wavekey
                , X.CaseID
      ) Y
   ) Z
   GROUP BY Z.Storerkey
          , Z.Wavekey
          , Z.ReqReplen
          , Z.Suggest_PAZone
          , FLOOR((Z.SeqNo+5) / 6)

   UNION ALL


   SELECT Storerkey         = Y.Storerkey
        , CustomerGroupCode = MAX(Y.CustomerGroupCode)
        , Wavekey           = Y.Wavekey
        , Wave_AddDate      = MAX(Y.Wave_AddDate)
        , ReqReplen         = ''
        , Suggest_PAZone    = Y.Suggest_PAZone
        , PA_PickZone       = COUNT(DISTINCT Y.PickZone)
        , PA_PickLoc        = COUNT(DISTINCT Y.Loc)
        , PA_NoOfCtn        = COUNT(DISTINCT Y.CaseID)
        , Qty               = SUM(Y.Qty)
        , LineSeq           = 0
        , CaseID_01         = ''
        , CaseID_02         = ''
        , CaseID_03         = ''
        , CaseID_04         = ''
        , CaseID_05         = ''
        , CaseID_06         = ''
        , Ttl_Carton        = @n_Ttl_Carton
        , Datawindow        = @c_DataWindow
        , Section           = 1
        , PageNo            = 0
        , ShowFields        = @c_ShowFields
        , Lbl_Suggest_PAZone= MAX(Y.T_Suggest_PAZone)
        , Lbl_PutawayZone   = MAX(Y.T_PutawayZone)
   FROM (
      SELECT Storerkey         = X.Storerkey
           , CustomerGroupCode = X.CustomerGroupCode
           , Wavekey           = X.Wavekey
           , Wave_AddDate      = X.Wave_AddDate
           , Suggest_PAZone    = CASE WHEN ISNULL(@c_Suggest_PAZoneExp,'')<>'' THEN X.Suggest_PAZone ELSE X.PutawayZone END
           , PickZone          = X.PickZone
           , Loc               = X.Loc
           , CaseID            = X.CaseID
           , Qty               = X.Qty
           , T_Suggest_PAZone  = X.T_Suggest_PAZone
           , T_PutawayZone     = X.T_PutawayZone
      FROM #TEMP_PICKDETAIL X
   ) Y
   GROUP BY Y.Storerkey
          , Y.Wavekey
          , Y.Suggest_PAZone

   ORDER BY Storerkey, Wavekey, Section, ReqReplen, Suggest_PAZone, LineSeq
END

GO