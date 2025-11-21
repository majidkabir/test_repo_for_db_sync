SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_picking_control_list_07b                   */
/* Creation Date: 04-Sep-2019                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: PVH Picking Slip                                             */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_picking_control_list_07b    */
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
/* 11/08/2021   ML       1.2  WMS-17708 Add MAPFILED:                    */
/*                            Suggest_PAZone, T_Suggest_PAZone           */
/* 23/03/2022   ML       1.3  Add NULL to Temp Table                     */
/*************************************************************************/
CREATE PROCEDURE [dbo].[isp_r_hk_picking_control_list_07b] (
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
      Suggest_PAZone, T_Suggest_PAZone

   [SQLJOIN]
*/

   DECLARE @c_DataWindow          NVARCHAR(40)  = 'r_hk_picking_control_list_07b'
         , @c_ExecStatements      NVARCHAR(MAX) = ''
         , @c_ExecArguments       NVARCHAR(MAX) = ''
         , @c_JoinClause          NVARCHAR(MAX) = ''
         , @c_ShowFields          NVARCHAR(MAX) = ''
         , @c_Suggest_PAZoneExp   NVARCHAR(MAX) = ''
         , @c_T_Suggest_PAZoneExp NVARCHAR(MAX) = ''
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
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
      AND Storerkey = @as_storerkey
    ORDER BY Code2


   SET @c_ExecStatements =
      N'INSERT INTO #TEMP_PICKDETAIL (Storerkey, CustomerGroupCode, Wavekey, Wave_AddDate, CaseID, PutawayZone, PickZone, Loc, Qty, ReqReplen,'
     +                              ' Suggest_PAZone, T_Suggest_PAZone)'
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


   SELECT Storerkey         = Q.Storerkey
        , CustomerGroupCode = MAX(Q.CustomerGroupCode)
        , Wavekey           = Q.Wavekey
        , ReqReplen         = Q.ReqReplen
        , Suggest_PAZone    = Q.Suggest_PAZone
        , LineSeq           = FLOOR((Q.SeqNo2+1) / 2)

        , CaseID_1          = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.CaseID END)
        , PAZone_101        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_01 END)
        , PAZone_102        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_02 END)
        , PAZone_103        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_03 END)
        , PAZone_104        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_04 END)
        , PAZone_105        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_05 END)
        , PAZone_106        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_06 END)
        , PAZone_107        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_07 END)
        , PAZone_108        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_08 END)
        , PAZone_109        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_09 END)
        , PAZone_110        = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.PAZone_10 END)
        , Qty_101           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_01 END)
        , Qty_102           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_02 END)
        , Qty_103           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_03 END)
        , Qty_104           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_04 END)
        , Qty_105           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_05 END)
        , Qty_106           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_06 END)
        , Qty_107           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_07 END)
        , Qty_108           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_08 END)
        , Qty_109           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_09 END)
        , Qty_110           = MAX(CASE WHEN (Q.SeqNo2-1)%2=0 THEN Q.Qty_10 END)

        , CaseID_2          = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.CaseID END)
        , PAZone_201        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_01 END)
        , PAZone_202        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_02 END)
        , PAZone_203        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_03 END)
        , PAZone_204        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_04 END)
        , PAZone_205        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_05 END)
        , PAZone_206        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_06 END)
        , PAZone_207        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_07 END)
        , PAZone_208        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_08 END)
        , PAZone_209        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_09 END)
        , PAZone_210        = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.PAZone_10 END)
        , Qty_201           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_01 END)
        , Qty_202           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_02 END)
        , Qty_203           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_03 END)
        , Qty_204           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_04 END)
        , Qty_205           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_05 END)
        , Qty_206           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_06 END)
        , Qty_207           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_07 END)
        , Qty_208           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_08 END)
        , Qty_209           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_09 END)
        , Qty_210           = MAX(CASE WHEN (Q.SeqNo2-1)%2=1 THEN Q.Qty_10 END)

        , Ttl_Carton        = @n_Ttl_Carton
        , Datawindow        = @c_DataWindow
        , ShowFields        = @c_ShowFields
        , Lbl_Suggest_PAZone= MAX(Q.T_Suggest_PAZone)

   FROM (
      SELECT Storerkey         = Z.Storerkey
           , CustomerGroupCode = MAX(Z.CustomerGroupCode)
           , Wavekey           = Z.Wavekey
           , ReqReplen         = Z.ReqReplen
           , Suggest_PAZone    = Z.Suggest_PAZone
           , CaseID            = Z.CaseID
           , PAZone_01         = MAX(CASE WHEN (Z.SeqNo-1)%10=0 THEN Z.PutawayZone END)
           , PAZone_02         = MAX(CASE WHEN (Z.SeqNo-1)%10=1 THEN Z.PutawayZone END)
           , PAZone_03         = MAX(CASE WHEN (Z.SeqNo-1)%10=2 THEN Z.PutawayZone END)
           , PAZone_04         = MAX(CASE WHEN (Z.SeqNo-1)%10=3 THEN Z.PutawayZone END)
           , PAZone_05         = MAX(CASE WHEN (Z.SeqNo-1)%10=4 THEN Z.PutawayZone END)
           , PAZone_06         = MAX(CASE WHEN (Z.SeqNo-1)%10=5 THEN Z.PutawayZone END)
           , PAZone_07         = MAX(CASE WHEN (Z.SeqNo-1)%10=6 THEN Z.PutawayZone END)
           , PAZone_08         = MAX(CASE WHEN (Z.SeqNo-1)%10=7 THEN Z.PutawayZone END)
           , PAZone_09         = MAX(CASE WHEN (Z.SeqNo-1)%10=8 THEN Z.PutawayZone END)
           , PAZone_10         = MAX(CASE WHEN (Z.SeqNo-1)%10=9 THEN Z.PutawayZone END)
           , Qty_01            = SUM(CASE WHEN (Z.SeqNo-1)%10=0 THEN Z.Qty END)
           , Qty_02            = SUM(CASE WHEN (Z.SeqNo-1)%10=1 THEN Z.Qty END)
           , Qty_03            = SUM(CASE WHEN (Z.SeqNo-1)%10=2 THEN Z.Qty END)
           , Qty_04            = SUM(CASE WHEN (Z.SeqNo-1)%10=3 THEN Z.Qty END)
           , Qty_05            = SUM(CASE WHEN (Z.SeqNo-1)%10=4 THEN Z.Qty END)
           , Qty_06            = SUM(CASE WHEN (Z.SeqNo-1)%10=5 THEN Z.Qty END)
           , Qty_07            = SUM(CASE WHEN (Z.SeqNo-1)%10=6 THEN Z.Qty END)
           , Qty_08            = SUM(CASE WHEN (Z.SeqNo-1)%10=7 THEN Z.Qty END)
           , Qty_09            = SUM(CASE WHEN (Z.SeqNo-1)%10=8 THEN Z.Qty END)
           , Qty_10            = SUM(CASE WHEN (Z.SeqNo-1)%10=9 THEN Z.Qty END)
           , SeqNo2            = ROW_NUMBER() OVER(PARTITION BY Z.Storerkey, Z.Wavekey, Z.ReqReplen, Z.Suggest_PAZone ORDER BY Z.CaseID)
           , T_Suggest_PAZone  = MAX(Z.T_Suggest_PAZone)
      FROM (
         SELECT Storerkey         = Y.Storerkey
              , CustomerGroupCode = Y.CustomerGroupCode
              , Wavekey           = Y.Wavekey
              , Suggest_PAZone    = Y.Suggest_PAZone
              , CaseID            = Y.CaseID
              , PutawayZone       = Y.PutawayZone
              , Qty               = Y.Qty
              , ReqReplen         = MAX(Y.ReqReplen)  OVER(PARTITION BY Y.Storerkey, Y.Wavekey, Y.CaseID)
              , SeqNo             = ROW_NUMBER() OVER(PARTITION BY Y.Storerkey, Y.Wavekey, Y.CaseID ORDER BY Y.PutawayZone)
              , T_Suggest_PAZone  = Y.T_Suggest_PAZone
         FROM (
            SELECT Storerkey         = X.Storerkey
                 , CustomerGroupCode = MAX(X.CustomerGroupCode)
                 , Wavekey           = X.Wavekey
                 , Suggest_PAZone    = CASE WHEN ISNULL(@c_Suggest_PAZoneExp,'')<>'' THEN MAX(X.Suggest_PAZone)
                                            ELSE ISNULL((SELECT TOP 1 a.PutawayZone FROM #TEMP_PICKDETAIL a
                                                WHERE a.Storerkey=X.Storerkey AND a.Wavekey=X.Wavekey AND a.CaseID=X.CaseID
                                                  AND a.CaseID<>'' GROUP BY a.CaseID, a.PutawayZone
                                                ORDER BY SUM(a.Qty) DESC, a.PutawayZone), '')
                                       END
                 , CaseID            = X.CaseID
                 , PutawayZone       = X.PutawayZone
                 , Qty               = SUM(X.Qty)
                 , ReqReplen         = MAX(X.ReqReplen)
                 , T_Suggest_PAZone  = MAX(X.T_Suggest_PAZone)
            FROM #TEMP_PICKDETAIL X
            GROUP BY X.Storerkey
                   , X.Wavekey
                   , X.CaseID
                   , X.PutawayZone
         ) Y
      ) Z
      WHERE Z.SeqNo <= 10
      GROUP BY Z.Storerkey
             , Z.Wavekey
             , Z.ReqReplen
             , Z.Suggest_PAZone
             , Z.CaseID
   ) Q
   GROUP BY Q.Storerkey
          , Q.Wavekey
          , Q.ReqReplen
          , Q.Suggest_PAZone
          , FLOOR((Q.SeqNo2+1) / 2)

   ORDER BY Storerkey, Wavekey, ReqReplen, Suggest_PAZone, LineSeq
END

GO