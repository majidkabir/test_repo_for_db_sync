SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_replenish_to_fpa_02                        */
/* Creation Date: 08-May-2018                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Replenishment Report FPA                                     */
/*                                                                       */
/* Called By: RCM - Popup Replenishment FPA Report in Loadplan/Waveplan  */
/*            Datawidnow r_hk_replenish_to_fpa_02                        */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 29/06/2018   ML       1.1  Change DropID Sequence                     */
/* 05/07/2018   ML       1.2  Add checking of outstanding PD.MoveRefKey  */
/* 01/12/2018   ML       1.3  Add NoOfMoveID checking for VNA            */
/* 04/12/2018   ML       1.4  Add Replen to static PF for piece pick     */
/* 22/12/2018   ML       1.5  Fix missing field when pending replen found*/
/* 03/01/2019   ML       1.6  Update QtyReplen                           */
/* 09/01/2019   ML       1.7  Include OriginalFromLoc, OriginalQty       */
/* 10/01/2019   ML       1.8  Handle Relenishment Confirm Failed         */
/* 04/06/2019   ML       1.9  Add ID to Replen From Stock for RDT Pick   */
/*                            Disable Pending Replen checking            */
/* 07/08/2019   ML       1.10 Bug fix on duplicate key in #TEMP_DPLOC    */
/* 27/11/2020   ML       1.11 1. Add ShowFields field in result          */
/*                            2. Add ShowField: ShowReplenkey            */
/*                            3. Add MapField: Div*, Brand*, CaseCnt*    */
/*                            4. Add MapValue: DPLoc_PAZone_*            */
/* 12/01/2021   ML       1.12 Add ReserveLoc_Cond,                       */
/*                            DPLoc_ReplenALL, DefaultGenReplenALL,      */
/*                            GenReplenALL, ReGenReplenALL               */
/*                            ShowReplenkeyBC,ShowToLocBC,ShowReplenQtyBC*/
/*                            NoGenReplenAllWhenOtherReplenExist         */
/* 17/03/2021   ML       1.13 Fix LogicalLocation length issue           */
/* 10/11/2021   ML       1.14 Allow ToLoc not exist in LOC table         */
/* 29/11/2021   ML       1.15 Add ShowField: IgnoreOrderUDF08,           */
/*                     NotAllowReplenByLoadplan, NotAllowReplenByWaveplan*/
/* 21/01/2022   ML       1.16 Add MapField: FromLoc                      */
/* 23/03/2022   ML       1.17 Add NULL to Temp Table                     */
/*************************************************************************/
CREATE PROCEDURE [dbo].[isp_r_hk_replenish_to_fpa_02] (
       @as_Key_Type  NVARCHAR(13)
     , @b_debug      INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      Div, Brand, CaseCnt, FromLoc, Replen_Div, Replen_Brand, Replen_CaseCnt, ReserveLoc_Cond

   [MAPVALUE]
      DPLoc_PAZone_SEL, DPLoc_PAZone_VNA, DPLoc_PAZone_FPR, DPLoc_ReplenALL

   [SHOWFIELD]
      DefaultNoGenReplen, DefaultGenReplen, DefaultGenReplenALL, ReplenMode2, ClearNoGenReplenFlag, NoResidualInDP
      NoGenReplenSEL, NoGenReplenVNA, NoGenReplenFPR
      ReplenExactQtySEL, ReplenExactQtyVNA
      ReplenToPickFace, TopUpPickFace, AlwaysTopUpPickFace
      ShowReplenkey, ShowReplenkeyBC, ShowToLocBC, ShowReplenQtyBC, NoGenReplenAllWhenOtherReplenExist
      IgnoreOrderUDF08, NotAllowReplenByLoadplan, NotAllowReplenByWaveplan

   [WAVE/LOADPLAN-Userdefine02]
      GenReplen, GenReplenALL, ReGenReplen, ReGenReplenALL, NoGenReplen

   [SQLJOIN]
      UDF02 = *Blank, Replen
*/

   IF OBJECT_ID('tempdb..#TEMP_PICKDETAILKEY') IS NOT NULL
      DROP TABLE #TEMP_PICKDETAILKEY
   IF OBJECT_ID('tempdb..#TEMP_OUTSTANDING') IS NOT NULL
      DROP TABLE #TEMP_OUTSTANDING
   IF OBJECT_ID('tempdb..#TEMP_DPLOC') IS NOT NULL
      DROP TABLE #TEMP_DPLOC
   IF OBJECT_ID('tempdb..#TEMP_PICKFACE') IS NOT NULL
      DROP TABLE #TEMP_PICKFACE
   IF OBJECT_ID('tempdb..#TEMP_REPLENISHMENT') IS NOT NULL
      DROP TABLE #TEMP_REPLENISHMENT
   IF OBJECT_ID('tempdb..#TEMP_REPLENISHMENT_FINAL') IS NOT NULL
      DROP TABLE #TEMP_REPLENISHMENT_FINAL
   IF OBJECT_ID('tempdb..#TEMP_RESULTSET') IS NOT NULL
      DROP TABLE #TEMP_RESULTSET
   IF OBJECT_ID('tempdb..#TEMP_ERROR') IS NOT NULL
      DROP TABLE #TEMP_ERROR


   DECLARE @c_DataWindow         NVARCHAR(40)
         , @n_StartTCnt          INT
         , @c_Type               NVARCHAR(2)
         , @c_Key                NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Facility           NVARCHAR(5)
         , @c_SKU                NVARCHAR(20)
         , @c_LOT                NVARCHAR(10)
         , @c_LOC                NVARCHAR(10)
         , @c_ID                 NVARCHAR(30)
         , @c_NewID              NVARCHAR(30)
         , @n_AllocQty           INT
         , @c_Div                NVARCHAR(100)
         , @c_Brand              NVARCHAR(100)
         , @n_StdCube            FLOAT
         , @n_CaseCnt            INT
         , @c_PA_Floor           NVARCHAR(3)
         , @c_LocAisle           NVARCHAR(10)
         , @n_ReplenQty          INT
         , @n_ReplenCBM          FLOAT
         , @n_RemainReplenQty    INT
         , @n_ReplenCtnCBM       FLOAT
         , @n_ReplenQtyFullCtn   INT
         , @n_ReplenQtyLooseCtn  INT
         , @n_AllocQtyLooseCtn   INT
         , @c_ReplenID           NVARCHAR(20)
         , @c_DPLoc              NVARCHAR(10)
         , @c_PFLoc              NVARCHAR(10)
         , @n_PFTopUpQty         INT
         , @n_MoveID_Count       INT
         , @c_MoveIDPrefix       NVARCHAR(20)
         , @c_MoveID             NVARCHAR(20)
         , @c_ReplenType         NVARCHAR(255)
         , @n_AvailableQty       INT
         , @n_ReplenCount        INT
         , @c_ReplenConfirmed    NVARCHAR(1)
         , @c_ReGenReplen        NVARCHAR(1)
         , @c_NoGenReplen        NVARCHAR(1)
         , @c_NoGenReplenDft     NVARCHAR(1)
         , @c_GenReplenALL       NVARCHAR(1)
         , @c_DP_LocationType    NVARCHAR(10)
         , @c_ReplenGroup        NVARCHAR(10)
         , @c_ReplenishmentKey   NVARCHAR(10)
         , @c_ReplenNo           NVARCHAR(10)
         , @c_LoadKey            NVARCHAR(10)
         , @c_WaveKey            NVARCHAR(10)
         , @c_PackKey            NVARCHAR(10)
         , @c_PackUOM3           NVARCHAR(10)
         , @n_Qty                INT
         , @n_Qty2               INT
         , @b_success            INT
         , @n_err                INT
         , @c_errmsg             NVARCHAR(255)
         , @c_PickDetailKey      NVARCHAR(10)
         , @c_NewPickDetailKey   NVARCHAR(10)
         , @c_MoveRefKey         NVARCHAR(10)
         , @n_PDQty              INT
         , @c_PDStatus           NVARCHAR(10)
         , @c_IsPickFace         NVARCHAR(1)
         , @c_HasResidual        NVARCHAR(1)
         , @n_ReplenKeyLen       INT
         , @n_REPLENISHKEY       BIGINT
         , @c_REPLENISHKEY       NVARCHAR(10)
         , @c_ReplenKeyPrefix1   NVARCHAR(10)
         , @c_ReplenKeyPrefix2   NVARCHAR(10)
         , @c_NewIDPattern       NVARCHAR(100)
         , @n_Temp               INT
         , @c_Temp               NVARCHAR(1000)
         , @c_LoseID             NVARCHAR(1)
         , @c_CommingleSku       NVARCHAR(1)
         , @b_UpdLoc             INT
         , @b_ReserveLocChanged  INT
         , @b_IgnoreOrderUDF08   INT
         , @c_LastStorerkey      NVARCHAR(15)

   DECLARE @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_ShowFields         NVARCHAR(MAX)
         , @c_DPLoc_PAZone_SEL   NVARCHAR(MAX)
         , @c_DPLoc_PAZone_VNA   NVARCHAR(MAX)
         , @c_DPLoc_PAZone_FPR   NVARCHAR(MAX)
         , @c_DPLoc_ReplenALL    NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(MAX)
         , @c_DivExp             NVARCHAR(MAX)
         , @c_BrandExp           NVARCHAR(MAX)
         , @c_CaseCntExp         NVARCHAR(MAX)
         , @c_Replen_JoinClause  NVARCHAR(MAX)
         , @c_Replen_DivExp      NVARCHAR(MAX)
         , @c_Replen_BrandExp    NVARCHAR(MAX)
         , @c_Replen_CaseCntExp  NVARCHAR(MAX)
         , @c_ReserveLoc_Cond    NVARCHAR(MAX)
         , @c_FromLocExp         NVARCHAR(MAX)

   SELECT @c_DataWindow        = 'r_hk_replenish_to_fpa_02'
        , @n_StartTCnt         = @@TRANCOUNT
        , @c_Key               = LEFT(@as_Key_Type, 10)
        , @c_Type              = RIGHT(@as_Key_Type, 2)
        , @c_ReGenReplen       = 'N'
        , @c_DP_LocationType   = 'DYNAMICPK'
        , @c_ReplenGroup       = 'DYNAMIC'
        , @n_ReplenCount       = 0
        , @c_ReplenConfirmed   = ''
        , @n_ReplenKeyLen      = 7
        , @n_REPLENISHKEY      = 0
        , @c_REPLENISHKEY      = ''
        , @c_ReplenKeyPrefix1  = ''
        , @c_ReplenKeyPrefix2  = ''
        , @b_ReserveLocChanged = 0
        , @c_Storerkey         = ''
        , @c_ShowFields        = ''
        , @c_ReserveLoc_Cond   = ''
        , @b_IgnoreOrderUDF08  = 0

   SET @c_MoveIDPrefix = CASE WHEN @c_Type='LP'
                              THEN 'LP' + LTRIM(RTRIM(SUBSTRING(@c_Key, PATINDEX('%[^0 ]%', @c_Key), LEN(@c_Key)+1))) +'-'
                              ELSE LTRIM(RTRIM(@c_Key)) + '-'
                         END
   SET @c_NewIDPattern =  REPLICATE('[0-9]', @n_ReplenKeyLen) + '*%'


   CREATE TABLE #TEMP_PICKDETAILKEY (
        PickdetailKey    NVARCHAR(20)  NOT NULL
      , ORD_Status       NVARCHAR(10)  NULL
      , ToLoc            NVARCHAR(10)  NULL
      , DropID           NVARCHAR(20)  NULL
      , ReplenKey        NVARCHAR(20)  NULL
      , Storerkey        NVARCHAR(15)  NULL
      , PRIMARY KEY (PickdetailKey)
   )

   CREATE TABLE #TEMP_OUTSTANDING (
        PickdetailKey    NVARCHAR(20)  NOT NULL
      , Storerkey        NVARCHAR(15)  NULL
      , Facility         NVARCHAR(5)   NULL
      , SKU              NVARCHAR(20)  NULL
      , LOT              NVARCHAR(10)  NULL
      , LogicalLocation  NVARCHAR(20)  NULL
      , LOC              NVARCHAR(10)  NULL
      , ID               NVARCHAR(20)  NULL
      , Original_DropID  NVARCHAR(20)  NULL
      , Qty              INT           NULL
      , Div              NVARCHAR(100) NULL
      , Brand            NVARCHAR(100) NULL
      , StdCube          FLOAT         NULL
      , CaseCnt          INT           NULL
      , Lottable02       NVARCHAR(20)  NULL
      , Lottable04       DATETIME      NULL
      , PA_Floor         NVARCHAR(3)   NULL
      , LocAisle         NVARCHAR(10)  NULL
      , PackKey          NVARCHAR(10)  NULL
      , PackUOM3         NVARCHAR(10)  NULL
      , Completed        NVARCHAR(1)   NULL
      , PRIMARY KEY (PickdetailKey)
   )
   CREATE INDEX IDX_TEMP_OUTSTANDING ON #TEMP_OUTSTANDING (Storerkey, Facility, Div, SKU, LOC, LOT, PickdetailKey)

   CREATE TABLE #TEMP_DPLOC (
        DPLoc            NVARCHAR(10)  NOT NULL
      , Facility         NVARCHAR(5)   NULL
      , LocAisle         NVARCHAR(10)  NULL
      , PutawayZone      NVARCHAR(10)  NULL
      , LogicalLocation  NVARCHAR(20)  NULL
      , PA_Descr         NVARCHAR(60)  NULL
      , PA_Floor         NVARCHAR(3)   NULL
      , CubicCapacity    FLOAT         NULL
      , CBM              FLOAT         NULL
      , Qty              INT           NULL
      , MaxPallet        INT           NULL
      , NoOfMoveID       INT           NULL
      , Div              NVARCHAR(100) NULL
      , Brand            NVARCHAR(100) NULL
      , Sku              NVARCHAR(20)  NOT NULL
      , Lot              NVARCHAR(10)  NOT NULL
      , ID               NVARCHAR(20)  NOT NULL
      , DropID           NVARCHAR(20)  NOT NULL
      , DivCount         INT           NULL
      , FullPalletReplen NVARCHAR(1)   NULL
      , Type             NVARCHAR(1)   NOT NULL
      , PRIMARY KEY (DPLoc, Sku, Lot, ID, DropID, Type)
   )

   CREATE TABLE #TEMP_PICKFACE (
        Storerkey          NVARCHAR(15) NOT NULL
      , Sku                NVARCHAR(20) NOT NULL
      , Loc                NVARCHAR(10) NOT NULL
      , Facility           NVARCHAR(5)  NULL
      , LogicalLocation    NVARCHAR(20) NULL
      , Qty                INT          NULL
      , QtyLocationLimit   INT          NULL
      , QtyLocationMinimum INT          NULL
      , PRIMARY KEY (StorerKey, Sku, Loc)
   )


   CREATE TABLE #TEMP_REPLENISHMENT (
        DPLoc            NVARCHAR(10)  NOT NULL
      , MoveID           NVARCHAR(20)  NOT NULL
      , ReplenQty        INT           NULL
      , ReplenCBM        FLOAT         NULL
      , Div              NVARCHAR(100) NULL
      , PRIMARY KEY (DPLoc, MoveID)
   )

   CREATE TABLE #TEMP_REPLENISHMENT_FINAL (
        RowID            INT IDENTITY(1,1) NOT NULL
      , StorerKey        NVARCHAR(15)  NULL
      , Sku              NVARCHAR(20)  NULL
      , FromLoc          NVARCHAR(20)  NULL
      , Lot              NVARCHAR(20)  NULL
      , Id               NVARCHAR(20)  NULL
      , ToLoc            NVARCHAR(20)  NULL
      , Qty              INT           NULL
      , CaseCnt          INT           NULL
      , AllocQty         INT           NULL
      , UOM              NVARCHAR(10)  NULL
      , PackKey          NVARCHAR(10)  NULL
      , ReplenNo         NVARCHAR(10)  NULL
      , Remark           NVARCHAR(255) NULL
      , RefNo            NVARCHAR(20)  NULL
      , LoadKey          NVARCHAR(10)  NULL
      , Wavekey          NVARCHAR(10)  NULL
      , Div              NVARCHAR(100) NULL
      , IsPickFace       NVARCHAR(1)   NULL
      , PRIMARY KEY (RowID)
   )

   CREATE TABLE #TEMP_RESULTSET (
        ReplenishmentKey   NVARCHAR(10)   NULL
      , ReplenNo           NVARCHAR(10)   NULL
      , Div                NVARCHAR(250)  NULL
      , PutawayZone        NVARCHAR(10)   NULL
      , Facility           NVARCHAR(10)   NULL
      , StorerKey          NVARCHAR(15)   NULL
      , Sku                NVARCHAR(20)   NULL
      , Descr              NVARCHAR(60)   NULL
      , AltSku             NVARCHAR(20)   NULL
      , LogicalLocation    NVARCHAR(20)   NULL
      , FromLoc            NVARCHAR(20)   NULL
      , FromID             NVARCHAR(20)   NULL
      , ToFacility         NVARCHAR(10)   NULL
      , ToLoc              NVARCHAR(20)   NULL
      , DropID             NVARCHAR(20)   NULL
      , Lottable02         NVARCHAR(20)   NULL
      , Lottable04         DATETIME       NULL
      , PackKey            NVARCHAR(10)   NULL
      , CaseCnt            INT            NULL
      , PACKUOM1           NVARCHAR(10)   NULL
      , PACKUOM3           NVARCHAR(10)   NULL
      , AllocQty           INT            NULL
      , ReplenQty          INT            NULL
      , ReplenType         NVARCHAR(2)    NULL
      , PA_Descr           NVARCHAR(60)   NULL
      , Brand              NVARCHAR(100)  NULL
      , Lot                NVARCHAR(10)   NULL
      , TOLOC_LocationType NVARCHAR(10)   NULL
      , FromID_Long        NVARCHAR(30)   NULL
      , ShowFields         NVARCHAR(4000) NULL
   )

   CREATE TABLE #TEMP_ERROR (
        ErrSeq             INT IDENTITY(1,1) NOT NULL
      , ErrMsg             NVARCHAR(500)     NULL
   )

   IF ISNULL(@c_Type,'') NOT IN ('WP', 'LP') OR ISNULL(@c_Key,'')=''
      GOTO REPORT_RESULTSET

   -- Get Storerkey
   SELECT @c_Storerkey        = ''
        , @c_ShowFields       = ''
        , @c_ReserveLoc_Cond  = ''
        , @b_IgnoreOrderUDF08 = 0

   IF @c_Type = 'WP'
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
        FROM dbo.ORDERS OH(NOLOCK)
       WHERE OH.Userdefine09 = @c_Key
       ORDER BY CASE WHEN OH.Userdefine08 = 'Y' THEN 1 ELSE 2 END
              , OH.Storerkey DESC
   ELSE
   IF @c_Type = 'LP'
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
        FROM dbo.ORDERS OH(NOLOCK)
       WHERE OH.Loadkey = @c_Key
       ORDER BY CASE WHEN OH.Userdefine08 = 'Y' THEN 2 ELSE 1 END
              , OH.Storerkey DESC

   -- Get ShowFields, ReserveLoc_Cond by Storerkey
   IF ISNULL(@c_Storerkey,'')<>''
   BEGIN
      SELECT TOP 1
             @c_ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      IF ISNULL(@c_ShowFields,'') LIKE '%,IgnoreOrderUDF08,%'  
         SET @b_IgnoreOrderUDF08 = 1

      IF (@c_Type = 'LP' AND ISNULL(@c_ShowFields,'') LIKE '%,NotAllowReplenByLoadplan,%') OR
         (@c_Type = 'WP' AND ISNULL(@c_ShowFields,'') LIKE '%,NotAllowReplenByWaveplan,%')
         GOTO REPORT_RESULTSET

      SELECT TOP 1
             @c_ReserveLoc_Cond  = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='ReserveLoc_Cond')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2
   END

   -- Check RegenReplen or not
   IF @c_Type = 'WP'
   BEGIN
      SELECT @c_ReGenReplen    = CASE WHEN X.Userdefine02='ReGenReplen'    THEN 'Y'
                                      WHEN X.Userdefine02='ReGenReplenALL' THEN 'Y'
                                      ELSE 'N'
                                 END
           , @c_NoGenReplen    = CASE WHEN X.Userdefine02='NoGenReplen'    THEN 'Y'
                                      WHEN X.Userdefine02='GenReplen'      THEN 'N'
                                      WHEN X.Userdefine02='GenReplenALL'   THEN 'N'
                                      ELSE ''
                                 END
           , @c_NoGenReplenDft = CASE WHEN ISNULL(@c_ShowFields,'') LIKE '%,DefaultNoGenReplen,%'  THEN 'Y'
                                      WHEN ISNULL(@c_ShowFields,'') LIKE '%,DefaultGenReplen,%'    THEN 'N'
                                      WHEN ISNULL(@c_ShowFields,'') LIKE '%,DefaultGenReplenALL,%' THEN 'N'
                                      ELSE ''
                                 END
           , @c_GenReplenALL   = CASE WHEN X.Userdefine02='GenReplenALL'   THEN 'Y'
                                      WHEN X.Userdefine02='ReGenReplenALL' THEN 'Y'
                                      WHEN ISNULL(@c_ShowFields,'') LIKE '%,DefaultGenReplenALL,%' THEN 'Y'
                                      ELSE 'N'
                                 END
        FROM dbo.WAVE X(NOLOCK)
       WHERE X.Wavekey = @c_Key

      SELECT @n_ReplenCount     = COUNT(1)
           , @c_ReplenConfirmed = ISNULL(MAX(IIF(Confirmed<>'N','Y','')),'')
        FROM dbo.REPLENISHMENT (NOLOCK)
       WHERE Wavekey = @c_Key

      IF ISNULL(@n_ReplenCount,0)<=0
      BEGIN
         SELECT @n_ReplenCount     = SUM(CASE WHEN PD.DropID<>'' THEN 1 ELSE 0 END)
              , @c_ReplenConfirmed = CASE WHEN @c_ReplenConfirmed='Y' THEN 'Y' ELSE IIF(MAX(OH.Status)>=3,'Y', 'N') END
           FROM dbo.ORDERS     OH (NOLOCK)
           JOIN dbo.PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey
          WHERE OH.Userdefine09 = @c_Key
            AND (@b_IgnoreOrderUDF08 = 1 OR OH.Userdefine08 = 'Y')
            AND LEFT(PD.DropID,LEN(@c_MoveIDPrefix)) = @c_MoveIDPrefix
      END

      -- Check Reserve Loc Changed
      SET @c_ExecStatements =
         N'IF EXISTS(SELECT TOP 1 1'
        +     ' FROM dbo.ORDERS     OH (NOLOCK)'
        +     ' JOIN dbo.PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey'
        +     ' JOIN dbo.LOC       LOC (NOLOCK) ON PD.Loc = LOC.Loc'
        +    ' WHERE OH.Userdefine09 =  @c_Key'
      IF @b_IgnoreOrderUDF08 <> 1
         SET @c_ExecStatements = @c_ExecStatements
           +   ' AND OH.Userdefine08 = ''Y'''

      IF ISNULL(@c_GenReplenALL,'')<>'Y'
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
           + ' AND (' + CASE WHEN ISNULL(@c_ReserveLoc_Cond,'')<>'' THEN @c_ReserveLoc_Cond ELSE 'LOC.LocationCategory=''SELECTIVE''' END + ')'
      END
      SET @c_ExecStatements = @c_ExecStatements
        +      ' AND (ISNULL(PD.DropID,'''')='''' OR ISNULL(PD.ToLoc,'''')=''''))'
        +' BEGIN'
        +   ' SET @b_ReserveLocChanged = 1'
        +' END'

      SET @c_ExecStatements = @c_ExecStatements
        +' ELSE IF EXISTS(SELECT TOP 1 1'
        +     ' FROM dbo.REPLENISHMENT RP(NOLOCK)'
        +     ' LEFT JOIN dbo.PICKDETAIL PD(NOLOCK) ON RP.Storerkey=PD.Storerkey AND RP.Lot=PD.Lot AND RP.FromLoc=PD.Loc AND RP.ID=PD.ID AND PD.Status<''9'' AND PD.Qty>0'
        +    ' WHERE RP.Wavekey = @c_Key'
        +      ' AND RP.ReplenishmentGroup = @c_ReplenGroup'
        +      ' AND RP.ID LIKE @c_NewIDPattern'
        +      ' AND RP.Confirmed=''N'''
        +      ' AND RP.Qty>0'
        +      ' AND PD.PickDetailKey IS NULL)'
        +' BEGIN'
        +   ' SET @b_ReserveLocChanged = 1'
        +' END'

      SET @c_ExecStatements = @c_ExecStatements
        +' ELSE IF EXISTS(SELECT TOP 1 1'
        +     ' FROM dbo.ORDERS     OH(NOLOCK)'
        +     ' JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.OrderKey'
        +     ' JOIN dbo.LOC       LOC(NOLOCK) ON PD.Loc=LOC.Loc'
        +     ' LEFT JOIN dbo.REPLENISHMENT RP(NOLOCK) ON PD.Storerkey=RP.Storerkey AND PD.Lot=RP.Lot AND PD.Loc=RP.FromLoc AND PD.ID=RP.ID'
        +                                           ' AND RP.Qty>0 AND RP.Confirmed=''N'' AND RP.ReplenishmentGroup=@c_ReplenGroup'
        +    ' WHERE OH.Userdefine09 =  @c_Key'
        +      ' AND PD.Status<''9'''
        +      ' AND PD.Qty>0'
        +      ' AND PD.ID LIKE @c_NewIDPattern'
        +      ' AND ISNULL(PD.ToLoc,'''')<>'''''
        +      ' AND ISNULL(PD.DropID,'''')<>'''''

      IF @b_IgnoreOrderUDF08 <> 1
         SET @c_ExecStatements = @c_ExecStatements
           +   ' AND OH.Userdefine08 = ''Y'''

      IF ISNULL(@c_GenReplenALL,'')<>'Y'
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
           + ' AND (' + CASE WHEN ISNULL(@c_ReserveLoc_Cond,'')<>'' THEN @c_ReserveLoc_Cond ELSE 'LOC.LocationCategory=''SELECTIVE''' END + ')'
      END
      SET @c_ExecStatements = @c_ExecStatements
        +       ' AND RP.ReplenishmentKey IS NULL)'
        +' BEGIN'
        +   ' SET @b_ReserveLocChanged = 1'
        +' END'

      SET @c_ExecArguments = N'@c_Key               NVARCHAR(10)'
                           + ',@c_ReplenGroup       NVARCHAR(10)'
                           + ',@c_NewIDPattern      NVARCHAR(100)'
                           + ',@b_ReserveLocChanged INT OUTPUT'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Key
                       , @c_ReplenGroup
                       , @c_NewIDPattern
                       , @b_ReserveLocChanged OUTPUT
   END
   ELSE IF @c_Type = 'LP'
   BEGIN
      SELECT @c_ReGenReplen    = CASE WHEN X.Userdefine02='ReGenReplen'    THEN 'Y'
                                      WHEN X.Userdefine02='ReGenReplenALL' THEN 'Y'
                                      ELSE 'N'
                                 END
           , @c_NoGenReplen    = CASE WHEN X.Userdefine02='NoGenReplen'    THEN 'Y'
                                      WHEN X.Userdefine02='GenReplen'      THEN 'N'
                                      WHEN X.Userdefine02='GenReplenALL'   THEN 'N'
                                      ELSE ''
                                 END
           , @c_NoGenReplenDft = CASE WHEN ISNULL(@c_ShowFields,'') LIKE '%,DefaultNoGenReplen,%'  THEN 'Y'
                                      WHEN ISNULL(@c_ShowFields,'') LIKE '%,DefaultGenReplen,%'    THEN 'N'
                                      WHEN ISNULL(@c_ShowFields,'') LIKE '%,DefaultGenReplenALL,%' THEN 'N'
                                      ELSE ''
                                 END
           , @c_GenReplenALL   = CASE WHEN X.Userdefine02='GenReplenALL'   THEN 'Y'
                                      WHEN X.Userdefine02='ReGenReplenALL' THEN 'Y'
                                      WHEN ISNULL(@c_ShowFields,'') LIKE '%,DefaultGenReplenALL,%' THEN 'Y'
                                      ELSE ''
                                 END
        FROM dbo.LOADPLAN X(NOLOCK)
       WHERE X.Loadkey = @c_Key

      SELECT @n_ReplenCount     = COUNT(1)
           , @c_ReplenConfirmed = ISNULL(MAX(IIF(Confirmed<>'N','Y','')),'')
        FROM dbo.REPLENISHMENT (NOLOCK)
       WHERE Loadkey = @c_Key

      IF ISNULL(@n_ReplenCount,0)<=0
      BEGIN
         SELECT @n_ReplenCount     = SUM(CASE WHEN PD.DropID<>'' THEN 1 ELSE 0 END)
              , @c_ReplenConfirmed = CASE WHEN @c_ReplenConfirmed='Y' THEN 'Y' ELSE IIF(MAX(OH.Status)>=3,'Y', 'N') END
           FROM dbo.ORDERS     OH (NOLOCK)
           JOIN dbo.PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey
          WHERE OH.Loadkey = @c_Key
            AND (@b_IgnoreOrderUDF08 = 1 OR ISNULL(OH.Userdefine08,'') <> 'Y')
            AND LEFT(PD.DropID,LEN(@c_MoveIDPrefix)) = @c_MoveIDPrefix
      END

      -- Check Reserve Loc Changed
      SET @c_ExecStatements =
         N'IF EXISTS(SELECT TOP 1 1'
        +     ' FROM dbo.ORDERS     OH (NOLOCK)'
        +     ' JOIN dbo.PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey'
        +     ' JOIN dbo.LOC       LOC (NOLOCK) ON PD.Loc = LOC.Loc'
        +    ' WHERE OH.Loadkey = @c_Key'

      IF @b_IgnoreOrderUDF08 <> 1
         SET @c_ExecStatements = @c_ExecStatements
           +   ' AND ISNULL(OH.Userdefine08,'''') <> ''Y'''

      IF ISNULL(@c_GenReplenALL,'')<>'Y'
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
           + ' AND (' + CASE WHEN ISNULL(@c_ReserveLoc_Cond,'')<>'' THEN @c_ReserveLoc_Cond ELSE 'LOC.LocationCategory=''SELECTIVE''' END + ')'
      END
      SET @c_ExecStatements = @c_ExecStatements
        +      ' AND (ISNULL(PD.DropID,'''')='''' OR ISNULL(PD.ToLoc,'''')=''''))'
        +' BEGIN'
        +   ' SET @b_ReserveLocChanged = 1'
        +' END'

      SET @c_ExecStatements = @c_ExecStatements
        +' ELSE IF EXISTS(SELECT TOP 1 1'
        +     ' FROM dbo.REPLENISHMENT RP(NOLOCK)'
        +     ' LEFT JOIN dbo.PICKDETAIL PD(NOLOCK) ON RP.Storerkey=PD.Storerkey AND RP.Lot=PD.Lot AND RP.FromLoc=PD.Loc AND RP.ID=PD.ID AND PD.Status<''9'' AND PD.Qty>0'
        +    ' WHERE RP.Loadkey = @c_Key'
        +      ' AND RP.ReplenishmentGroup = @c_ReplenGroup'
        +      ' AND RP.ID LIKE @c_NewIDPattern'
        +      ' AND RP.Confirmed=''N'''
        +      ' AND RP.Qty>0'
        +      ' AND PD.PickDetailKey IS NULL)'
        +' BEGIN'
        +   ' SET @b_ReserveLocChanged = 1'
        +' END'

      SET @c_ExecStatements = @c_ExecStatements
        +' ELSE IF EXISTS(SELECT TOP 1 1'
        +     ' FROM dbo.ORDERS     OH(NOLOCK)'
        +     ' JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.OrderKey'
        +     ' JOIN dbo.LOC       LOC(NOLOCK) ON PD.Loc=LOC.Loc'
        +     ' LEFT JOIN dbo.REPLENISHMENT RP(NOLOCK) ON PD.Storerkey=RP.Storerkey AND PD.Lot=RP.Lot AND PD.Loc=RP.FromLoc AND PD.ID=RP.ID'
        +                                           ' AND RP.Qty>0 AND RP.Confirmed=''N'' AND RP.ReplenishmentGroup=@c_ReplenGroup'
        +    ' WHERE OH.Loadkey = @c_Key'
        +      ' AND PD.Status<''9'''
        +      ' AND PD.Qty>0'
        +      ' AND PD.ID LIKE @c_NewIDPattern'
        +      ' AND ISNULL(PD.ToLoc,'''')<>'''''
        +      ' AND ISNULL(PD.DropID,'''')<>'''''

      IF @b_IgnoreOrderUDF08 <> 1
         SET @c_ExecStatements = @c_ExecStatements
           +   ' AND ISNULL(OH.Userdefine08,'''') <> ''Y'''

      IF ISNULL(@c_GenReplenALL,'')<>'Y'
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
           + ' AND (' + CASE WHEN ISNULL(@c_ReserveLoc_Cond,'')<>'' THEN @c_ReserveLoc_Cond ELSE 'LOC.LocationCategory=''SELECTIVE''' END + ')'
      END
      SET @c_ExecStatements = @c_ExecStatements
        +       ' AND RP.ReplenishmentKey IS NULL)'
        +' BEGIN'
        +   ' SET @b_ReserveLocChanged = 1'
        +' END'

      SET @c_ExecArguments = N'@c_Key               NVARCHAR(10)'
                           + ',@c_ReplenGroup       NVARCHAR(10)'
                           + ',@c_NewIDPattern      NVARCHAR(100)'
                           + ',@b_ReserveLocChanged INT OUTPUT'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Key
                       , @c_ReplenGroup
                       , @c_NewIDPattern
                       , @b_ReserveLocChanged OUTPUT
   END

   IF ISNULL(@c_NoGenReplen,'')=''
      SET @c_NoGenReplen = CASE WHEN ISNULL(@c_NoGenReplenDft,'')<>'' THEN @c_NoGenReplenDft ELSE 'Y' END

   IF ISNULL(@c_ReGenReplen,'')='Y'
      SET @c_NoGenReplen = 'N'

   -- If Replenishment record executed, then skip DP Loc Distribution
   IF ISNULL(@c_ReplenConfirmed,'')<>'Y'
   BEGIN
      IF @c_Type = 'WP'
         SELECT TOP 1
                @c_ReplenConfirmed = 'Y'
           FROM dbo.REPLENISHMENT (NOLOCK)
          WHERE Wavekey = @c_Key
            AND (ISNULL(Confirmed,'')<>'N' OR Remark LIKE N'Failed !%')
      ELSE
      IF @c_Type = 'LP'
         SELECT TOP 1
                @c_ReplenConfirmed = 'Y'
           FROM dbo.REPLENISHMENT (NOLOCK)
          WHERE Loadkey = @c_Key
            AND (ISNULL(Confirmed,'')<>'N' OR Remark LIKE N'Failed !%')
   END

   IF ISNULL(@c_ReplenConfirmed,'') = 'Y'
      GOTO REPORT_RESULTSET

   -- If Waveplan/Loadplan Userdefine02<>ReGenReplen and Replenishment record exist then skip DPLoc Distribution
   IF ISNULL(@c_ReGenReplen,'')<>'Y' AND ISNULL(@c_NoGenReplen,'')<>'Y' AND @n_ReplenCount>0 AND @b_ReserveLocChanged=0
      GOTO REPORT_RESULTSET


   IF @n_ReplenKeyLen > 0 AND @n_ReplenKeyLen < 10
   BEGIN
      SELECT TOP 1 @n_REPLENISHKEY = REPLENISHKEY + 10000 FROM dbo.REPLENISHKEY (NOLOCK) ORDER BY REPLENISHKEY DESC
      SET @n_Temp = FLOOR( @n_REPLENISHKEY / POWER(10, @n_ReplenKeyLen) )
      SET @c_ReplenKeyPrefix1 = RIGHT(REPLICATE('0',10) + CONVERT(VARCHAR(10), @n_Temp ), 10 - @n_ReplenKeyLen)
      SET @c_ReplenKeyPrefix2 = RIGHT(REPLICATE('0',10) + CONVERT(VARCHAR(10), IIF(@n_Temp>0, @n_temp-1, @n_Temp) ), 10 - @n_ReplenKeyLen)
   END
   SET @c_REPLENISHKEY = RIGHT(REPLICATE('0',10) + CONVERT(VARCHAR(10), @n_REPLENISHKEY % POWER(10, @n_ReplenKeyLen) ), @n_ReplenKeyLen)

   IF @c_Type = 'WP'
   BEGIN
      SET @c_ExecStatements =
         N'INSERT INTO #TEMP_PICKDETAILKEY (PickdetailKey, ORD_Status, ToLoc, DropID, ReplenKey, Storerkey)'
        +' SELECT PD.PickdetailKey'
        +      ', MAX( ISNULL( RTRIM( OH.Status ), '''' ) )'
        +      ', MAX( ISNULL( RTRIM( PD.ToLoc  ), '''' ) )'
        +      ', MAX( ISNULL( RTRIM( PD.DropID ), '''' ) )'
        +      ', MAX( CASE WHEN RP.ReplenishmentKey IS NOT NULL AND ISNULL(RP.ReplenNo,'''')<>@c_Key'
        +                 ' THEN RP.ReplenishmentKey ELSE '''' END)'
        +      ', MAX( ISNULL( RTRIM( PD.Storerkey ), '''' ) )'
        +  ' FROM dbo.ORDERS     OH (NOLOCK)'
        +  ' JOIN dbo.PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey'
        +  ' JOIN dbo.LOC       LOC (NOLOCK) ON PD.Loc = LOC.Loc'
        +  ' LEFT JOIN dbo.REPLENISHMENT RP (NOLOCK) ON RP.Storerkey=OH.Storerkey AND PD.ID LIKE @c_NewIDPattern AND'
        +       ' RP.ReplenishmentKey = IIF(LEFT(PD.ID,@n_ReplenKeyLen)<=@c_REPLENISHKEY,@c_ReplenKeyPrefix1,@c_ReplenKeyPrefix2) + LEFT(PD.ID,@n_ReplenKeyLen)'
        + ' WHERE OH.Userdefine09 = @c_Key'

      IF @b_IgnoreOrderUDF08 <> 1
         SET @c_ExecStatements = @c_ExecStatements
           +' AND OH.Userdefine08 = ''Y'''

      IF ISNULL(@c_GenReplenALL,'')<>'Y'
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
           + ' AND (' + CASE WHEN ISNULL(@c_ReserveLoc_Cond,'')<>'' THEN @c_ReserveLoc_Cond ELSE 'LOC.LocationCategory=''SELECTIVE''' END + ')'
      END
      SET @c_ExecStatements = @c_ExecStatements
        +   ' AND PD.Qty > 0'
        + ' GROUP BY PD.PickdetailKey'

      SET @c_ExecArguments = N'@c_Key              NVARCHAR(10)'
                           + ',@c_NewIDPattern     NVARCHAR(100)'
                           + ',@n_ReplenKeyLen     INT'
                           + ',@c_REPLENISHKEY     NVARCHAR(10)'
                           + ',@c_ReplenKeyPrefix1 NVARCHAR(10)'
                           + ',@c_ReplenKeyPrefix2 NVARCHAR(10)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Key
                       , @c_NewIDPattern
                       , @n_ReplenKeyLen
                       , @c_REPLENISHKEY
                       , @c_ReplenKeyPrefix1
                       , @c_ReplenKeyPrefix2
   END
   ELSE IF @c_Type = 'LP'
   BEGIN
      SET @c_ExecStatements =
         N'INSERT INTO #TEMP_PICKDETAILKEY (PickdetailKey, ORD_Status, ToLoc, DropID, ReplenKey, Storerkey)'
        +' SELECT PD.PickdetailKey'
        +      ', MAX( ISNULL( RTRIM( OH.Status ), '''' ) )'
        +      ', MAX( ISNULL( RTRIM( PD.ToLoc  ), '''' ) )'
        +      ', MAX( ISNULL( RTRIM( PD.DropID ), '''' ) )'
        +      ', MAX( CASE WHEN RP.ReplenishmentKey IS NOT NULL AND ISNULL(RP.ReplenNo,'''')<>@c_Key'
        +                 ' THEN RP.ReplenishmentKey ELSE '''' END)'
        +      ', MAX( ISNULL( RTRIM( PD.Storerkey ), '''' ) )'
        +  ' FROM dbo.ORDERS     OH (NOLOCK)'
        +  ' JOIN dbo.PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey'
        +  ' JOIN dbo.LOC       LOC (NOLOCK) ON PD.Loc = LOC.Loc'
        +  ' LEFT JOIN dbo.REPLENISHMENT RP (NOLOCK) ON RP.Storerkey=OH.Storerkey AND PD.ID LIKE @c_NewIDPattern AND'
        +       ' RP.ReplenishmentKey = IIF(LEFT(PD.ID,@n_ReplenKeyLen)<=@c_REPLENISHKEY,@c_ReplenKeyPrefix1,@c_ReplenKeyPrefix2) + LEFT(PD.ID,@n_ReplenKeyLen)'
        + ' WHERE OH.Loadkey = @c_Key'

      IF @b_IgnoreOrderUDF08 <> 1
         SET @c_ExecStatements = @c_ExecStatements
           +' AND ISNULL(OH.Userdefine08,'''') <> ''Y'''

      IF ISNULL(@c_GenReplenALL,'')<>'Y'
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements
           + ' AND (' + CASE WHEN ISNULL(@c_ReserveLoc_Cond,'')<>'' THEN @c_ReserveLoc_Cond ELSE 'LOC.LocationCategory=''SELECTIVE''' END + ')'
      END
      SET @c_ExecStatements = @c_ExecStatements
        +   ' AND PD.Qty > 0'
        + ' GROUP BY PD.PickdetailKey'

      SET @c_ExecArguments = N'@c_Key              NVARCHAR(10)'
                           + ',@c_NewIDPattern     NVARCHAR(100)'
                           + ',@n_ReplenKeyLen     INT'
                           + ',@c_REPLENISHKEY     NVARCHAR(10)'
                           + ',@c_ReplenKeyPrefix1 NVARCHAR(10)'
                           + ',@c_ReplenKeyPrefix2 NVARCHAR(10)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Key
                       , @c_NewIDPattern
                       , @n_ReplenKeyLen
                       , @c_REPLENISHKEY
                       , @c_ReplenKeyPrefix1
                       , @c_ReplenKeyPrefix2
   END

   IF NOT EXISTS(SELECT TOP 1 1 FROM #TEMP_PICKDETAILKEY)
      GOTO REPORT_RESULTSET

   -- If already started picking, then skip DP Loc Distribution
   IF EXISTS( SELECT TOP 1 1 FROM #TEMP_PICKDETAILKEY WHERE ORD_Status>='3')
      GOTO REPORT_RESULTSET

   -- Clean up Pickdetail ToLoc, DropID, MoveRefKey
   IF @c_Type = 'WP'
   BEGIN
      UPDATE PD WITH (ROWLOCK)
         SET ToLoc      = ''
           , DropID     = ''
           , Notes      = ''
           , MoveRefKey = ''
           , Trafficcop = NULL
        FROM dbo.ORDERS     OH (NOLOCK)
        JOIN dbo.PICKDETAIL PD ON OH.Orderkey = PD.Orderkey
       WHERE OH.Userdefine09 = @c_Key
         AND (@b_IgnoreOrderUDF08 = 1 OR OH.Userdefine08 = 'Y')
         AND PD.Status < '9' AND PD.ShipFlag<>'Y'
         AND (PD.ToLoc<>'' OR PD.DropID<>'' OR PD.MoveRefKey<>'')
   END
   ELSE IF @c_Type = 'LP'
   BEGIN
      UPDATE PD WITH (ROWLOCK)
         SET ToLoc      = ''
           , DropID     = ''
           , Notes      = ''
           , MoveRefKey = ''
           , Trafficcop = NULL
        FROM dbo.ORDERS     OH (NOLOCK)
        JOIN dbo.PICKDETAIL PD ON OH.Orderkey = PD.Orderkey
       WHERE OH.Loadkey = @c_Key
         AND (@b_IgnoreOrderUDF08 = 1 OR ISNULL(OH.Userdefine08,'') <> 'Y')
         AND PD.Status < '9' AND PD.ShipFlag<>'Y'
         AND (PD.ToLoc<>'' OR PD.DropID<>'' OR PD.MoveRefKey<>'')
   END

   -- Retrieve ToLoc & DropID from other wave/loadplan
   IF EXISTS(SELECT TOP 1 1
        FROM #TEMP_PICKDETAILKEY a
        JOIN dbo.PICKDETAIL PD(NOLOCK) ON a.PickdetailKey=PD.PickdetailKey
        JOIN dbo.REPLENISHMENT RP(NOLOCK) ON a.ReplenKey=RP.ReplenishmentKey
       WHERE ISNULL(a.ReplenKey,'')<>'' AND PD.Status < '9' AND PD.ShipFlag<>'Y' )
   BEGIN
      UPDATE PD WITH (ROWLOCK)
         SET ToLoc      = RP.OriginalFromLoc
           , DropID     = RP.RefNo
           , Notes      = RP.RefNo
           , Trafficcop = NULL
        FROM #TEMP_PICKDETAILKEY a
        JOIN dbo.PICKDETAIL PD ON a.PickdetailKey=PD.PickdetailKey
        JOIN dbo.REPLENISHMENT RP(NOLOCK) ON a.ReplenKey=RP.ReplenishmentKey
       WHERE ISNULL(a.ReplenKey,'')<>'' AND PD.Status < '9' AND PD.ShipFlag<>'Y'

      IF @c_GenReplenALL = 'Y' AND @c_ShowFields LIKE '%,NoGenReplenAllWhenOtherReplenExist,%'
      BEGIN
         INSERT INTO #TEMP_ERROR (ErrMsg) VALUES('ERROR: Pending Replen from other WavePlan / Loadplan')
         GOTO REPORT_RESULTSET
      END
   END


   -- Storerkey Loop
   DECLARE C_CUR_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
     FROM #TEMP_PICKDETAILKEY
    ORDER BY 1

   OPEN C_CUR_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_JoinClause         = ''
           , @c_Replen_JoinClause  = ''
           , @c_DivExp             = ''
           , @c_BrandExp           = ''
           , @c_CaseCntExp         = ''
           , @c_Replen_DivExp      = ''
           , @c_Replen_BrandExp    = ''
           , @c_Replen_CaseCntExp  = ''

      SELECT TOP 1
             @c_JoinClause = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y' AND ISNULL(UDF02,'')=''
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_Replen_JoinClause = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y' AND ISNULL(UDF02,'')='Replen'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_DivExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Div')), '' )
           , @c_BrandExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Brand')), '' )
           , @c_CaseCntExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='CaseCnt')), '' )
           , @c_Replen_DivExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Replen_Div')), '' )
           , @c_Replen_BrandExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Replen_Brand')), '' )
           , @c_Replen_CaseCntExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Replen_CaseCnt')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      IF ISNULL(@c_Replen_JoinClause, '')='' SET @c_Replen_JoinClause = @c_JoinClause
      IF ISNULL(@c_Replen_DivExp    , '')='' SET @c_Replen_DivExp     = @c_DivExp
      IF ISNULL(@c_Replen_BrandExp  , '')='' SET @c_Replen_BrandExp   = @c_BrandExp
      IF ISNULL(@c_Replen_CaseCntExp, '')='' SET @c_Replen_CaseCntExp = @c_CaseCntExp


      -- Get Outstanding Pickdetails
      SET @c_ExecStatements =
         N'INSERT INTO #TEMP_OUTSTANDING ('
           + ' PickdetailKey, Storerkey, Facility, SKU, LOT, LogicalLocation, LOC, ID, Original_DropID, Qty, Div, Brand,'
           + ' StdCube, CaseCnt, Lottable02, Lottable04, PA_Floor, LocAisle, PackKey, PackUOM3)'

      SET @c_ExecStatements = @c_ExecStatements
        + ' SELECT PickdetailKey    = RTRIM( PD.PickdetailKey )'
        +       ', Storerkey        = RTRIM( PD.Storerkey )'
        +       ', Facility         = RTRIM( LOC.Facility )'
        +       ', SKU              = RTRIM( PD.SKU )'
        +       ', LOT              = RTRIM( PD.LOT )'
        +       ', LogicalLocation  = RTRIM( MAX( LOC.LogicalLocation ) )'
        +       ', LOC              = RTRIM( PD.LOC )'
        +       ', ID               = RTRIM( PD.ID )'
        +       ', Original_DropID  = RTRIM( MAX( PDK.DropID ) )'
        +       ', Qty              = SUM(PD.Qty)'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Div              = RTRIM( MAX( ISNULL(' + CASE WHEN ISNULL(@c_Replen_DivExp    ,'')<>'' THEN @c_Replen_DivExp     ELSE '''''' END + ','''')))'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Brand            = RTRIM( MAX( ISNULL(' + CASE WHEN ISNULL(@c_Replen_BrandExp  ,'')<>'' THEN @c_Replen_BrandExp   ELSE '''''' END + ','''')))'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', StdCube          = MAX( ISNULL( SKU.StdCube, '''') )'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', CaseCnt          = MAX( ISNULL(' + CASE WHEN ISNULL(@c_Replen_CaseCntExp  ,'')<>'' THEN @c_Replen_CaseCntExp   ELSE 'PACK.CaseCnt' END + ',0))'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lottable02       = RTRIM( MAX( ISNULL( LA.Lottable02, '''') ) )'
        +       ', Lottable04       = MAX( ISNULL( LA.Lottable04, '''') )'
        +       ', PA_Floor         = RTRIM( MAX( ISNULL( PA.Floor, '''') ) )'
        +       ', LocAisle         = RTRIM( MAX( ISNULL( LOC.LocAisle, '''') ) )'
        +       ', PackKey          = RTRIM( MAX( ISNULL( SKU.PackKey, '''') ) )'
        +       ', PackUOM3         = RTRIM( MAX( ISNULL( PACK.PackUOM3, '''') ) )'

      SET @c_ExecStatements = @c_ExecStatements
        +   ' FROM #TEMP_PICKDETAILKEY PDK'
        +   ' JOIN dbo.PICKDETAIL       PD (NOLOCK) ON PDK.PickdetailKey = PD.PickdetailKey'
        +   ' JOIN dbo.ORDERS           OH (NOLOCK) ON PD.OrderKey = OH.OrderKey'
        +   ' JOIN dbo.SKU             SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.SKU = SKU.SKU'
        +   ' JOIN dbo.PACK            PACK(NOLOCK) ON SKU.Packkey = PACK.Packkey'
        +   ' JOIN dbo.LOTATTRIBUTE     LA (NOLOCK) ON PD.Lot = LA.Lot'
        +   ' JOIN dbo.LOC             LOC (NOLOCK) ON PD.Loc = LOC.Loc'
        +   ' LEFT JOIN dbo.PUTAWAYZONE PA (NOLOCK) ON LOC.PutawayZone = PA.PutawayZone'

      SET @c_ExecStatements = @c_ExecStatements
        +   CASE WHEN ISNULL(@c_Replen_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_Replen_JoinClause)),'') END

      SET @c_ExecStatements = @c_ExecStatements
        +  ' WHERE PDK.Storerkey = @c_Storerkey'
        +    ' AND ISNULL(PDK.ReplenKey,'''')='''''

      SET @c_ExecStatements = @c_ExecStatements
        +  ' GROUP BY PD.PickdetailKey, PD.Storerkey, LOC.Facility, PD.SKU, PD.LOT, PD.LOC, PD.ID'

      SET @c_ExecArguments = N'@c_Storerkey NVARCHAR(15)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Storerkey
   END
   CLOSE C_CUR_STORERKEY
   DEALLOCATE C_CUR_STORERKEY


   -- Start DP Loc Distribution
   DECLARE C_CUR_STR_FAC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey, Facility
     FROM #TEMP_OUTSTANDING
    ORDER BY Storerkey, Facility

   OPEN C_CUR_STR_FAC

   SET @n_MoveID_Count = 0
   SET @c_LastStorerkey = ''

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR_STR_FAC
       INTO @c_Storerkey, @c_Facility

      IF @@FETCH_STATUS<>0
         BREAK

      IF ISNULL(@n_ReplenCount,0)>0 AND ISNULL(@c_Storerkey,'')<>ISNULL(@c_LastStorerkey,'')
      BEGIN
         SET @c_LastStorerkey = @c_Storerkey

         -- Clean up Replenishment Records
         IF @c_Type = 'WP'
            DELETE dbo.REPLENISHMENT WITH (ROWLOCK)
             WHERE Storerkey = @c_Storerkey
               AND Wavekey = @c_Key
               AND ReplenishmentGroup = @c_ReplenGroup
               AND ISNULL(Confirmed,'')<>'Y'
         ELSE
         IF @c_Type = 'LP'
            DELETE dbo.REPLENISHMENT WITH (ROWLOCK)
             WHERE Storerkey = @c_Storerkey
               AND Loadkey = @c_Key
               AND ReplenishmentGroup = @c_ReplenGroup
               AND ISNULL(Confirmed,'')<>'Y'
      END

      -- Get ShowFields From ReportCfg
      SELECT @c_ShowFields       = ''
           , @c_DPLoc_PAZone_SEL = ''
           , @c_DPLoc_PAZone_VNA = ''
           , @c_DPLoc_PAZone_FPR = ''
           , @c_DPLoc_ReplenALL  = ''

      SELECT TOP 1
             @c_ShowFields = RptCfg.ShowFields
      FROM (
         SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
      ) RptCfg
      WHERE RptCfg.Storerkey=@c_Storerkey AND RptCfg.SeqNo=1

      SELECT TOP 1
             @c_DPLoc_PAZone_SEL = CAST( ISNULL(RTRIM( (select top 1 b.ColValue
                                        from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b
                                        where a.SeqNo=b.SeqNo and a.ColValue='DPLoc_PAZone_SEL') ), '') AS NVARCHAR(MAX))
           , @c_DPLoc_PAZone_VNA = CAST( ISNULL(RTRIM( (select top 1 b.ColValue
                                        from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b
                                        where a.SeqNo=b.SeqNo and a.ColValue='DPLoc_PAZone_VNA') ), '') AS NVARCHAR(MAX))
           , @c_DPLoc_PAZone_FPR = CAST( ISNULL(RTRIM( (select top 1 b.ColValue
                                        from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b
                                        where a.SeqNo=b.SeqNo and a.ColValue='DPLoc_PAZone_FPR') ), '') AS NVARCHAR(MAX))
           , @c_DPLoc_ReplenALL  = CAST( ISNULL(RTRIM( (select top 1 b.ColValue
                                        from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b
                                        where a.SeqNo=b.SeqNo and a.ColValue='DPLoc_ReplenALL') ), '') AS NVARCHAR(MAX))
      FROM (
         SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWindow AND Short='Y'
      ) RptCfg3
      WHERE RptCfg3.Storerkey=@c_Storerkey AND RptCfg3.SeqNo=1


      -- Get DPLoc
      TRUNCATE TABLE #TEMP_DPLOC

      SELECT @c_JoinClause         = ''
           , @c_Replen_JoinClause  = ''
           , @c_DivExp             = ''
           , @c_BrandExp           = ''
           , @c_CaseCntExp         = ''
           , @c_Replen_DivExp      = ''
           , @c_Replen_BrandExp    = ''
           , @c_Replen_CaseCntExp  = ''

      SELECT TOP 1
             @c_JoinClause = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y' AND ISNULL(UDF02,'')=''
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_Replen_JoinClause = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y' AND ISNULL(UDF02,'')='Replen'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_DivExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Div')), '' )
           , @c_BrandExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Brand')), '' )
           , @c_CaseCntExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='CaseCnt')), '' )
           , @c_Replen_DivExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Replen_Div')), '' )
           , @c_Replen_BrandExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Replen_Brand')), '' )
           , @c_Replen_CaseCntExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Replen_CaseCnt')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      IF ISNULL(@c_Replen_JoinClause, '')='' SET @c_Replen_JoinClause = @c_JoinClause
      IF ISNULL(@c_Replen_DivExp    , '')='' SET @c_Replen_DivExp     = @c_DivExp
      IF ISNULL(@c_Replen_BrandExp  , '')='' SET @c_Replen_BrandExp   = @c_BrandExp
      IF ISNULL(@c_Replen_CaseCntExp, '')='' SET @c_Replen_CaseCntExp = @c_CaseCntExp


      -- Get Outstanding Pickdetails
      SET @c_ExecStatements =
         N'INSERT INTO #TEMP_DPLOC ('
           + ' DPLoc, Sku, Lot, ID, DropID, Type, Facility, LocAisle, PutawayZone, LogicalLocation,'
           + ' PA_Descr, PA_Floor, CubicCapacity, CBM, Qty, MaxPallet, Div, Brand, FullPalletReplen)'

      SET @c_ExecStatements = @c_ExecStatements
        + ' SELECT DPLoc, Sku, Lot, ID, DropID, Type,'
        +      ' MAX(Facility), MAX(LocAisle), MAX(PutawayZone), MAX(LogicalLocation),'
        +      ' MAX(PA_Descr), MAX(PA_Floor), MAX(CubicCapacity), SUM(CBM), SUM(Qty), MAX(MaxPallet),'
        +      ' MAX(Div), MAX(Brand), MAX(FullPalletReplen)'

      SET @c_ExecStatements = @c_ExecStatements
        + ' FROM ('
        +    ' SELECT DPLoc           = RTRIM( LOC.Loc )'
        +          ', Sku             = RTRIM( ISNULL(LLI.Sku,'''') )'
        +          ', Lot             = RTRIM( ISNULL(LLI.Lot,'''') )'
        +          ', ID              = RTRIM( ISNULL(LLI.ID ,'''') )'
        +          ', DropID          = '''''
        +          ', Type            = ''1'''
        +          ', Facility        = RTRIM( MAX( LOC.Facility ) )'
        +          ', LocAisle        = RTRIM( MAX( ISNULL(LOC.LocAisle,'''') ) )'
        +          ', PutawayZone     = RTRIM( MAX( LOC.PutawayZone ) )'
        +          ', LogicalLocation = RTRIM( MAX( LOC.LogicalLocation ) )'
        +          ', PA_Descr        = RTRIM( MAX( ISNULL(PA.Descr,'''') ) )'
        +          ', PA_Floor        = RTRIM( MAX( ISNULL(PA.Floor,'''') ) )'
        +          ', CubicCapacity   = MAX( ISNULL( LOC.CubicCapacity, 0) )'
        +          ', CBM             = SUM( ISNULL(LLI.Qty - LLI.QtyPicked,0) * ISNULL(SKU.StdCube,0) )'
        +          ', Qty             = SUM( ISNULL(LLI.Qty - LLI.QtyPicked,0) )'
        +          ', MaxPallet       = MAX( ISNULL( LOC.MaxPallet, 0) )'
      SET @c_ExecStatements = @c_ExecStatements
        +          ', Div             = RTRIM( MAX( ISNULL(' + CASE WHEN ISNULL(@c_Replen_DivExp    ,'')<>'' THEN @c_Replen_DivExp     ELSE '''''' END + ','''')))'
      SET @c_ExecStatements = @c_ExecStatements
        +          ', Brand           = RTRIM( MAX( ISNULL(' + CASE WHEN ISNULL(@c_Replen_BrandExp  ,'')<>'' THEN @c_Replen_BrandExp   ELSE '''''' END + ','''')))'
      SET @c_ExecStatements = @c_ExecStatements
        +          ', FullPalletReplen= ''N'''

      SET @c_ExecStatements = @c_ExecStatements
        +      ' FROM dbo.LOC              LOC (NOLOCK)'
        +      ' JOIN dbo.PUTAWAYZONE       PA (NOLOCK) ON LOC.PutawayZone = PA.PutawayZone'
        +      ' LEFT JOIN dbo.LOTxLOCxID  LLI (NOLOCK) ON LOC.Loc = LLI.Loc AND LLI.Qty > 0'
        +      ' LEFT JOIN dbo.SKU         SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku'

      SET @c_ExecStatements = @c_ExecStatements
        +   CASE WHEN ISNULL(@c_Replen_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_Replen_JoinClause)),'') END

      SET @c_ExecStatements = @c_ExecStatements
        +     ' WHERE LOC.Facility = @c_Facility'
        +       ' AND LOC.LocationType = @c_DP_LocationType'
        +     ' GROUP BY LOC.Loc'
        +             ', ISNULL(LLI.Sku,'''')'
        +             ', ISNULL(LLI.Lot,'''')'
        +             ', ISNULL(LLI.ID ,'''')'

      SET @c_ExecStatements = @c_ExecStatements
        +    ' UNION ALL'

        +    ' SELECT DPLoc           = RTRIM( X.DPLoc )'
        +          ', Sku             = RTRIM( ISNULL( X.Sku ,'''') )'
        +          ', Lot             = RTRIM( ISNULL( X.Lot ,'''') )'
        +          ', ID              = RTRIM( ISNULL( X.ID ,'''') )'
        +          ', DropID          = RTRIM( ISNULL( X.DropID ,'''') )'
        +          ', Type            = ''1'''
        +          ', Facility        = RTRIM( MAX( X.Facility ) )'
        +          ', LocAisle        = RTRIM( MAX( X.LocAisle ) )'
        +          ', PutawayZone     = RTRIM( MAX( X.PutawayZone ) )'
        +          ', LogicalLocation = RTRIM( MAX( X.LogicalLocation ) )'
        +          ', PA_Descr        = RTRIM( MAX( X.PA_Descr ) )'
        +          ', PA_Floor        = RTRIM( MAX( X.PA_Floor ) )'
        +          ', CubicCapacity   = MAX( X.CubicCapacity )'
        +          ', CBM             = SUM( X.StdCube * X.Qty )'
        +          ', Qty             = SUM( X.Qty )'
        +          ', MaxPallet       = MAX( X.MaxPallet )'
        +          ', Div             = ISNULL( RTRIM( MAX( X.Div ) ),'''')'
        +          ', Brand           = RTRIM( MAX( X.Brand ) )'
        +          ', FullPalletReplen= MAX( X.FullPalletReplen )'

      SET @c_ExecStatements = @c_ExecStatements
        +    ' FROM ('
        +       ' SELECT DPLoc           = RTRIM( PD.ToLoc )'
        +             ', Sku             = RTRIM( PD.Sku )'
        +             ', Lot             = RTRIM( PD.Lot )'
        +             ', ID              = RTRIM( PD.ID )'
        +             ', DropID          = RTRIM( PD.DropID )'
        +             ', ReplenishmentKey= RP.ReplenishmentKey'
        +             ', OH_Status       = OH.Status'
        +             ', Facility        = RTRIM( MAX( TOLOC.Facility ) )'
        +             ', LocAisle        = RTRIM( MAX( TOLOC.LocAisle ) )'
        +             ', PutawayZone     = RTRIM( MAX( TOLOC.PutawayZone ) )'
        +             ', LogicalLocation = RTRIM( MAX( TOLOC.LogicalLocation ) )'
        +             ', PA_Descr        = RTRIM( MAX( TOPA.Descr ) )'
        +             ', PA_Floor        = RTRIM( MAX( TOPA.Floor ) )'
        +             ', CubicCapacity   = MAX( TOLOC.CubicCapacity )'
        +             ', StdCube         = MAX( SKU.StdCube )'
        +             ', Qty             = CASE WHEN RP.ReplenishmentKey IS NULL THEN IIF(OH.Status < ''3'', SUM(PD.Qty), 0)'
        +                                     ' WHEN MAX(RP.Confirmed) <> ''Y''  THEN IIF(OH.Status < ''3'', MAX(RP.Qty), 0)'
        +                                     ' ELSE                                  IIF(OH.Status < ''3'', 0, -MAX(RP.Qty))'
        +                                ' END'
        +             ', MaxPallet       = MAX( TOLOC.MaxPallet )'
      SET @c_ExecStatements = @c_ExecStatements
        +             ', Div             = RTRIM( MAX( ISNULL(' + CASE WHEN ISNULL(@c_Replen_DivExp    ,'')<>'' THEN @c_Replen_DivExp     ELSE '''''' END + ','''')))'
      SET @c_ExecStatements = @c_ExecStatements
        +             ', Brand           = RTRIM( MAX( ISNULL(' + CASE WHEN ISNULL(@c_Replen_BrandExp  ,'')<>'' THEN @c_Replen_BrandExp   ELSE '''''' END + ','''')))'
      SET @c_ExecStatements = @c_ExecStatements
        +             ', FullPalletReplen= MAX( IIF(PD.DropID LIKE ''%-F%'', ''Y'', ''N'') )'

      SET @c_ExecStatements = @c_ExecStatements
        +         ' FROM dbo.ORDERS          OH (NOLOCK)'
        +         ' JOIN dbo.PICKDETAIL      PD (NOLOCK) ON PD.Orderkey = OH.Orderkey'
        +         ' JOIN dbo.SKU            SKU (NOLOCK) ON SKU.Storerkey = PD.Storerkey AND SKU.SKU = PD.SKU'
        +         ' JOIN dbo.LOC          FRLOC (NOLOCK) ON FRLOC.Loc = PD.Loc'
        +         ' JOIN dbo.LOC          TOLOC (NOLOCK) ON TOLOC.Loc = PD.ToLoc'
        +         ' JOIN dbo.PUTAWAYZONE   TOPA (NOLOCK) ON TOLOC.PutawayZone = TOPA.PutawayZone'
        +         ' LEFT JOIN dbo.REPLENISHMENT   RP (NOLOCK) ON RP.Storerkey = PD.Storerkey AND RP.RefNo = PD.DropID AND RP.ReplenishmentGroup = @c_ReplenGroup'

      SET @c_ExecStatements = @c_ExecStatements
        +   CASE WHEN ISNULL(@c_Replen_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_Replen_JoinClause)),'') END

      SET @c_ExecStatements = @c_ExecStatements
        +        ' WHERE OH.Storerkey = @c_Storerkey'
        +          ' AND FRLOC.Facility = @c_Facility'
        +          ' AND FRLOC.LocationType <> @c_DP_LocationType'
        +          ' AND TOLOC.Facility = @c_Facility'
        +          ' AND TOLOC.LocationType = @c_DP_LocationType'
        +          ' AND @c_Key <> '''''
        +          ' AND IIF(@c_Type=''WP'', OH.Userdefine09, IIF(@c_Type=''LP'', OH.LoadKey, '''')) <> @c_Key'
        +          ' AND PD.Status < ''5'''
        +        ' GROUP BY PD.ToLoc, PD.Sku, PD.Lot, PD.ID, PD.DropID, RP.ReplenishmentKey, OH.Status'
        +    ' ) X'

      SET @c_ExecStatements = @c_ExecStatements
        +    ' GROUP BY X.DPLoc'
        +            ', ISNULL( X.Sku ,'''')'
        +            ', ISNULL( X.Lot ,'''')'
        +            ', ISNULL( X.ID ,'''')'
        +            ', ISNULL( X.DropID ,'''')'
        + ' ) Z'
        + ' GROUP BY DPLoc, Sku, Lot, ID, DropID, Type'

      SET @c_ExecArguments = N'@c_Storerkey       NVARCHAR(15)'
                           + ',@c_Facility        NVARCHAR(5)'
                           + ',@c_Key             NVARCHAR(10)'
                           + ',@c_Type            NVARCHAR(2)'
                           + ',@c_DP_LocationType NVARCHAR(10)'
                           + ',@c_ReplenGroup     NVARCHAR(10)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Storerkey
                       , @c_Facility
                       , @c_Key
                       , @c_Type
                       , @c_DP_LocationType
                       , @c_ReplenGroup


      INSERT INTO #TEMP_DPLOC (
         DPLoc, Facility, LocAisle, PutawayZone, LogicalLocation,
         PA_Descr, PA_Floor, CubicCapacity, CBM, Qty, MaxPallet, NoOfMoveID,
         Div, DivCount, FullPalletReplen, Type, Sku, Lot, ID, DropID
      )
      SELECT DPLoc           = X.DPLoc
           , Facility        = MAX( X.Facility )
           , LocAisle        = MAX( X.LocAisle )
           , PutawayZone     = MAX( X.PutawayZone )
           , LogicalLocation = MAX( X.LogicalLocation )
           , PA_Descr        = MAX( X.PA_Descr )
           , PA_Floor        = MAX( X.PA_Floor )
           , CubicCapacity   = MAX( X.CubicCapacity )
           , CBM             = SUM( X.CBM )
           , Qty             = SUM( X.Qty )
           , MaxPallet       = MAX( X.MaxPallet )
           , NoOfMoveID      = COUNT(DISTINCT MoveID)
           , Div             = MAX( X.MaxDiv )
           , DivCOunt        = COUNT( DISTINCT X.Div )
           , FullPalletReplen= MAX( X.FullPalletReplen )
           , Type            = '2'
           , Sku             = ''
           , Lot             = ''
           , ID              = ''
           , DropID          = ''
       FROM (
          SELECT *
                , MoveID = CASE WHEN Sku IS NOT NULL THEN IIF(ISNULL(DropID,'')<>'', DropID, RTRIM(Lot)+'|'+RTRIM(DPLoc)+'|'+RTRIM(ID)) END
                , MaxDiv = FIRST_VALUE( Div ) OVER(PARTITION BY DPLoc ORDER BY CBM DESC)
            FROM #TEMP_DPLOC
       ) X
       WHERE X.Type = '1'
       GROUP BY X.DPLoc
       ORDER BY PA_Floor, PA_Descr, PutawayZone, LogicalLocation, DPLoc

      DELETE FROM #TEMP_DPLOC WHERE Type='1'


      -- Get Static Pick Face
      TRUNCATE TABLE #TEMP_PICKFACE

      INSERT INTO #TEMP_PICKFACE (Storerkey, Sku, Loc, Facility, LogicalLocation, Qty, QtyLocationLimit, QtyLocationMinimum)
      SELECT Storerkey          = RTRIM( Storerkey )
           , Sku                = RTRIM( Sku )
           , Loc                = RTRIM( Loc )
           , Facility           = RTRIM( MAX( Facility ) )
           , LogicalLocation    = RTRIM( MAX( LogicalLocation ) )
           , Qty                = SUM ( Qty )
           , QtyLocationLimit   = MAX( QtyLocationLimit )
           , QtyLocationMinimum = MAX( QtyLocationMinimum )
      FROM (
         SELECT Storerkey          = SL.Storerkey
              , Sku                = SL.Sku
              , Loc                = SL.Loc
              , Facility           = LOC.Facility
              , LogicalLocation    = LOC.LogicalLocation
              , Qty                = SL.Qty - SL.QtyPicked
              , QtyLocationLimit   = SL.QtyLocationLimit
              , QtyLocationMinimum = SL.QtyLocationMinimum
           FROM dbo.SKUxLOC     SL(NOLOCK)
           JOIN dbo.LOC        LOC(NOLOCK) ON SL.Loc = LOC.Loc
          WHERE LOC.Facility = @c_Facility
            AND SL.Storerkey = @c_Storerkey
            AND SL.LocationType IN ('PICK', 'CASE')

        UNION ALL

         SELECT Storerkey          = RP.Storerkey
              , Sku                = RP.Sku
              , Loc                = RP.ToLoc
              , Facility           = TOLOC.Facility
              , LogicalLocation    = TOLOC.LogicalLocation
              , Qty                = CASE WHEN RP.Confirmed <> 'Y'
                                          THEN IIF(OH.Status < '3', RP.Qty, 0)
                                          ELSE IIF(OH.Status < '3', 0, -RP.Qty)
                                     END
              , QtyLocationLimit   = SL.QtyLocationLimit
              , QtyLocationMinimum = SL.QtyLocationMinimum
           FROM dbo.REPLENISHMENT   RP (NOLOCK)
           JOIN dbo.PICKDETAIL      PD (NOLOCK) ON RP.RefNo = PD.DropID
           JOIN dbo.ORDERS          OH (NOLOCK) ON PD.Orderkey = OH.Orderkey
           JOIN dbo.LOC          TOLOC (NOLOCK) ON TOLOC.Loc = RP.ToLoc
           JOIN dbo.SKUxLOC         SL (NOLOCK) ON RP.Storerkey = SL.Storerkey AND RP.Sku = SL.Sku AND RP.ToLoc = SL.Loc
          WHERE RP.ReplenishmentGroup = @c_ReplenGroup
            AND RP.Storerkey = @c_Storerkey
            AND TOLOC.Facility = @c_Facility
            AND SL.LocationType IN ('PICK', 'CASE')
            AND RP.ReplenNo <> @c_Key
            AND PD.Status < '5'
      ) X
      GROUP BY X.Storerkey, X.Sku, X.Loc



      -- Allocate DP Loc
      DECLARE C_CUR_OUTSTANDING CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT SKU
            , Lot
            , LOC
            , ID
            , CaseCnt
            , Qty              = SUM( Qty )
            , Div              = MAX( Div )
            , Brand            = MAX( Brand )
            , StdCube          = MAX( StdCube )
            , PA_Floor         = MAX( PA_Floor )
            , LocAisle         = MAX( LocAisle )
            , PackKey          = MAX( PackKey )
            , PackUOM3         = MAX( PackUOM3 )
         FROM #TEMP_OUTSTANDING
        WHERE Storerkey = @c_Storerkey AND Facility = @c_Facility
         GROUP BY SKU, Lot, LOC, ID, CaseCnt
         ORDER BY Div
                , CASE MAX(PA_Floor)
                     WHEN 'FPR' THEN '2'
                     WHEN 'VNA' THEN '3'
                     ELSE '1'
                  END
                , MAX(LogicalLocation), Loc, Brand, Sku, Lot, MAX(Original_DropID), ID

      OPEN C_CUR_OUTSTANDING

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_CUR_OUTSTANDING
          INTO @c_SKU
             , @c_LOT
             , @c_LOC
             , @c_ID
             , @n_CaseCnt
             , @n_AllocQty
             , @c_Div
             , @c_Brand
             , @n_StdCube
             , @c_PA_Floor
             , @c_LocAisle
             , @c_PackKey
             , @c_PackUOM3

         IF @@FETCH_STATUS<>0
            BREAK

         SELECT @c_DPLoc      = ''
              , @c_MoveID     = ''
              , @c_ReplenType = ''
              , @c_ReplenID   = ''
              , @n_AvailableQty = 0

         -- Get Available Qty
         SELECT @n_AvailableQty = CASE WHEN @c_ID LIKE @c_NewIDPattern
                                       THEN SUM( LLI.Qty - LLI.QtyPicked - LLI.QtyReplen )
                                       ELSE SUM( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen )
                                  END
           FROM dbo.LOTxLOCxID   LLI (NOLOCK)
           JOIN dbo.LOTATTRIBUTE  LA (NOLOCK) ON LLI.Lot = LA.Lot
           JOIN dbo.SKU          SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
           JOIN dbo.PACK        PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          WHERE LLI.Qty > 0
            AND LLI.Lot = @c_LOT
            AND LLI.Loc = @c_LOC
            AND LLI.ID  = @c_ID

         IF ISNULL(@n_AvailableQty,0) <= 0
            SET @n_AvailableQty = 0

         IF (@c_NoGenReplen = 'Y' OR @c_ShowFields LIKE '%,ReplenMode2,%' )
         BEGIN
            SET @n_ReplenQty = @n_AllocQty
         END
         ELSE
         BEGIN
            -- Round up ReplenQty to Full Case
            SET @n_ReplenQty = IIF(@n_CaseCnt>1, CEILING(CAST(@n_AllocQty AS FLOAT) / @n_CaseCnt) * @n_CaseCnt, @n_AllocQty )

            -- If Available Qty < ReplenQty, then use Available Qty
            IF @c_ID LIKE @c_NewIDPattern
            BEGIN
               IF @n_ReplenQty > @n_AvailableQty
                  SET @n_ReplenQty = @n_AvailableQty
            END
            ELSE
            BEGIN
               IF @n_ReplenQty > @n_AvailableQty + @n_AllocQty
                  SET @n_ReplenQty = @n_AvailableQty + @n_AllocQty
            END
         END

         -- Check Replen Zone
         IF @c_GenReplenALL = 'Y' AND ISNULL(@c_DPLoc_ReplenALL,'')<>'' -- Replen ALL
         BEGIN
            SET @c_ReplenType = 'A'
            SET @n_ReplenQty  = @n_AllocQty
         END
         ELSE IF @c_PA_Floor = 'VNA'     -- VNA zones
         BEGIN
            SET @c_ReplenType = 'V'
            IF @c_ShowFields LIKE '%,ReplenExactQtyVNA,%' OR @c_ShowFields LIKE '%,NoGenReplenVNA,%'
               SET @n_ReplenQty = @n_AllocQty
         END
         ELSE IF @c_PA_Floor = 'FPR' AND @c_ID<>''     -- Full Pallet Replen
         BEGIN
            SET @c_ReplenType = 'F'
            IF @c_ShowFields LIKE '%,NoGenReplenFPR,%'
               SET @n_ReplenQty = @n_AllocQty
         END
         ELSE     -- Selective Zones
         BEGIN
            SET @c_ReplenType = 'S'
            IF @c_ShowFields LIKE '%,ReplenExactQtySEL,%' AND @c_ShowFields LIKE '%,NoGenReplenSEL,%'
               SET @n_ReplenQty = @n_AllocQty
         END


         -- If has residual, then replen the last carton/loose qty to Static Pick Face (Home loc)
         IF @c_ReplenType<>'F' AND @n_CaseCnt>1 AND @n_ReplenQty > @n_AllocQty AND @c_ShowFields LIKE '%,ReplenToPickFace,%'
         BEGIN
            SET @c_PFLoc = ''
            SET @n_ReplenQtyFullCtn  = FLOOR(CAST(@n_AllocQty AS FLOAT) / @n_CaseCnt) * @n_CaseCnt
            SET @n_ReplenQtyLooseCtn = @n_ReplenQty - @n_ReplenQtyFullCtn
            SET @n_AllocQtyLooseCtn  = @n_AllocQty - @n_ReplenQtyFullCtn

            IF @n_ReplenQtyLooseCtn>0
            BEGIN
               SET @n_PFTopUpQty = 0

               SELECT TOP 1
                      @c_PFLoc = Loc
                    , @n_PFTopUpQty = CASE WHEN Qty <= QtyLocationMinimum OR @c_ShowFields LIKE '%,AlwaysTopUpPickFace,%'
                                           THEN FLOOR(CAST(
                                                IIF(@n_AvailableQty + @n_AllocQtyLooseCtn < QtyLocationLimit - Qty,
                                                    @n_AvailableQty + @n_AllocQtyLooseCtn,
                                                    QtyLocationLimit - Qty) AS FLOAT) / @n_CaseCnt) * @n_CaseCnt
                                           ELSE @n_ReplenQtyLooseCtn
                                      END
                 FROM #TEMP_PICKFACE
                WHERE StorerKey = @c_Storerkey
                  AND Sku = @c_SKU
                  AND Qty + @n_ReplenQtyLooseCtn <= QtyLocationLimit
                ORDER BY LogicalLocation, Loc

               IF @c_PFLoc <> ''
               BEGIN
                  SET @n_AllocQty  = @n_ReplenQtyFullCtn
                  SET @n_ReplenQty = @n_ReplenQtyFullCtn

                  IF @c_ShowFields LIKE '%,TopUpPickFace,%' AND @n_CaseCnt>0 AND @n_PFTopUpQty > @n_ReplenQtyLooseCtn AND @n_PFTopUpQty>0
                     SET @n_ReplenQtyLooseCtn = @n_PFTopUpQty

                  -- Assign Move ID
                  SET @n_MoveID_Count += 1
                  SET @c_MoveID = @c_MoveIDPrefix + ISNULL(RTRIM(@c_ReplenType),'') + FORMAT(@n_MoveID_Count, '0000')

                  UPDATE PF SET Qty = Qty + @n_ReplenQtyLooseCtn
                    FROM #TEMP_PICKFACE PF
                   WHERE StorerKey = @c_Storerkey
                     AND Sku = @c_SKU
                     AND Loc = @c_PFLoc

                  INSERT INTO #TEMP_REPLENISHMENT_FINAL (
                       StorerKey, Sku, FromLoc, Lot, Id, ToLoc, Qty, CaseCnt, AllocQty, UOM, PackKey,
                       ReplenNo, Remark, RefNo, LoadKey, Wavekey, Div, IsPickFace)
                  VALUES(
                       @c_Storerkey, @c_Sku, @c_Loc, @c_LOT, @c_ID, @c_PFLoc, @n_ReplenQtyLooseCtn, @n_CaseCnt, @n_AllocQtyLooseCtn, @c_PackUOM3, @c_PackKey,
                       @c_Key, @c_ReplenType, '', IIF(@c_Type='LP',@c_Key,''), IIF(@c_Type='WP',@c_Key,''), @c_Div, 'Y'
                  )
               END
            END
         END

         IF @n_ReplenQty > @n_AllocQty AND @c_ShowFields LIKE '%,NoResidualInDP,%'
            SET @n_ReplenQty = @n_AllocQty

         IF @b_debug=1
            SELECT Action             = 'Replen'
                 , c_ReplenType       = @c_ReplenType
                 , c_Storerkey        = @c_Storerkey
                 , c_Facility         = @c_Facility
                 , c_SKU              = @c_SKU
                 , c_LOT              = @c_LOT
                 , c_LOC              = @c_LOC
                 , c_ID               = @c_ID
                 , n_CaseCnt          = @n_CaseCnt
                 , n_AllocQty         = @n_AllocQty
                 , c_Div              = @c_Div
                 , c_Brand            = @c_Brand
                 , n_StdCube          = @n_StdCube
                 , c_PA_Floor         = @c_PA_Floor
                 , c_LocAisle         = @c_LocAisle
                 , c_PackKey          = @c_PackKey
                 , c_PackUOM3         = @c_PackUOM3
                 , n_AvailableQty     = @n_AvailableQty
                 , n_ReplenQty        = @n_ReplenQty
                 , c_DPLoc_PAZone_SEL = @c_DPLoc_PAZone_SEL
                 , c_DPLoc_PAZone_VNA = @c_DPLoc_PAZone_VNA
                 , c_DPLoc_PAZone_FPR = @c_DPLoc_PAZone_FPR
                 , c_DPLoc_ReplenALL  = @c_DPLoc_ReplenALL

         SET @n_RemainReplenQty = @n_ReplenQty

         WHILE @n_RemainReplenQty > 0
         BEGIN
            SET @n_ReplenQty = @n_RemainReplenQty
            SET @n_ReplenCBM = @n_ReplenQty * @n_StdCube
            SET @n_ReplenCtnCBM = @n_CaseCnt * @n_StdCube

            IF @c_ReplenType = 'V'     -- VNA zones
            BEGIN
               -- Search first available DP Loc
               SELECT TOP 1
                      @c_DPLoc = X.DPLoc
                    , @n_ReplenQty = CASE WHEN X.CubicCapacity > 0 AND @n_CaseCnt > 0 AND @n_ReplenCBM > X.AvailableCapacity
                                           AND @n_ReplenCtnCBM <= X.AvailableCapacity
                                          THEN FLOOR(X.AvailableCapacity / @n_ReplenCtnCBM) * @n_CaseCnt
                                          ELSE @n_ReplenQty END
               FROM (
                  -- Select same Div 1st, then empty DPLoc. If still not found, then mix Div
                  SELECT DP.*
                       , AvailableCapacity = ISNULL(DP.CubicCapacity,0) - ISNULL(DP.CBM,0) - ISNULL(RP.ReplenCBM,0)
                       , DivCountAll = CASE WHEN DP.DivCount>1 OR RP.DivCount>1 THEN 2
                                            ELSE (SELECT COUNT(DISTINCT Div) FROM (SELECT Div = DP.Div UNION SELECT RP.Div UNION SELECT @c_Div ) B)
                                       END
                    FROM #TEMP_DPLOC DP
                    LEFT JOIN (
                       SELECT DPLoc
                            , ReplenCBM        = SUM(ReplenCBM)
                            , NoOfMoveID       = COUNT(DISTINCT MoveID)
                            , Div              = MAX(Div)
                            , DivCount         = COUNT(DISTINCT Div)
                         FROM #TEMP_REPLENISHMENT
                        GROUP BY DPLoc
                    ) RP ON DP.DPLoc = RP.DPLoc
                   WHERE DP.LocAisle = @c_LocAisle
                     AND ISNULL(DP.PA_Floor,'') = 'VNA'
                     AND (ISNULL(@c_DPLoc_PAZone_VNA,'')=''
                       OR DP.PutawayZone IN (SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@c_DPLoc_PAZone_VNA, ',') WHERE value<>''))
                     AND ( ISNULL(DP.CubicCapacity,0) = 0 OR @n_ReplenCtnCBM <= ISNULL(DP.CubicCapacity,0) - ISNULL(DP.CBM,0) - ISNULL(RP.ReplenCBM,0) )
                     AND ( ISNULL(DP.MaxPallet,0) = 0 OR ISNULL(DP.NoOfMoveID,0) + ISNULL(RP.NoOfMoveID,0) <= ISNULL(DP.MaxPallet,0) )
                ) X
                ORDER BY CASE WHEN X.DivCountAll=1 AND X.CubicCapacity>0 THEN 1
                              when X.DivCountAll>1 OR ISNULL(X.CubicCapacity,0)=0 THEN 3
                              ELSE 2
                         END
                       , X.LogicalLocation, X.DPLoc
            END

            ELSE IF @c_ReplenType = 'F'     -- Full Pallet Replen
            BEGIN
               SET @c_ReplenID   = @c_ID

               -- Re-calculate full pallet ReplenQty
               SELECT @n_ReplenQty = SUM(LLI.Qty)
                    , @n_ReplenCBM = SUM(LLI.Qty * ISNULL(SKU.StdCube,0))
                 FROM dbo.LOTxLOCxID LLI (NOLOCK)
                 JOIN dbo.SKU        SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
                 JOIN dbo.LOC        LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                WHERE LLI.Storerkey = @c_Storerkey
                  AND LLI.Sku = @c_SKU
                  AND LLI.Loc = @c_Loc
                  AND LLI.ID  = @c_ID
                  AND LLI.Qty > 0

               -- Search first available DP Loc
               SELECT TOP 1 @c_DPLoc = DP.DPLoc
                 FROM #TEMP_DPLOC DP
                 LEFT JOIN (
                    SELECT DPLoc
                         , ReplenQty  = SUM(ReplenQty)
                      FROM #TEMP_REPLENISHMENT
                     GROUP BY DPLoc
                 ) RP ON DP.DPLoc = RP.DPLoc
                WHERE ISNULL(DP.PA_Floor,'') <> 'VNA'
                  AND (ISNULL(@c_DPLoc_PAZone_FPR,'')=''
                    OR DP.PutawayZone IN (SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@c_DPLoc_PAZone_FPR, ',') WHERE value<>''))
                  AND ( DP.CubicCapacity = 0
                     OR ISNULL(DP.Qty,0) + ISNULL(RP.ReplenQty,0) = 0
                      )
                ORDER BY IIF(DP.CubicCapacity > 0, 1, 2)
                       , DP.LogicalLocation, DP.DPLoc
            END

            ELSE IF @c_ReplenType = 'A'     -- Replen ALL
            BEGIN
               SELECT @c_DPLoc = @c_DPLoc_ReplenALL
            END

            ELSE     -- Selective Zones
            BEGIN
               -- Search first available DP Loc
               SELECT TOP 1
                      @c_DPLoc = X.DPLoc
                    , @n_ReplenQty = CASE WHEN X.CubicCapacity > 0 AND @n_CaseCnt > 0 AND @n_ReplenCBM > X.AvailableCapacity
                                           AND @n_ReplenCtnCBM <= X.AvailableCapacity
                                          THEN FLOOR(X.AvailableCapacity / @n_ReplenCtnCBM) * @n_CaseCnt
                                          ELSE @n_ReplenQty END
               FROM (
                   -- Select same Div 1st, then empty DPLoc. If still not found, then mix Div
                  SELECT DP.*
                       , AvailableCapacity = ISNULL(DP.CubicCapacity,0) - ISNULL(DP.CBM,0) - ISNULL(RP.ReplenCBM,0)
                       , DivCountAll = CASE WHEN DP.DivCount>1 OR RP.DivCount>1 THEN 2
                                            ELSE (SELECT COUNT(DISTINCT Div) FROM (SELECT Div = DP.Div UNION SELECT RP.Div UNION SELECT @c_Div ) B)
                                       END
                    FROM #TEMP_DPLOC DP
                    LEFT JOIN (
                       SELECT DPLoc
                            , ReplenCBM        = SUM(ReplenCBM)
                            , NoOfMoveID       = COUNT(DISTINCT MoveID)
                            , Div              = MAX(Div)
                            , DivCount         = COUNT(DISTINCT Div)
                            , FullPalletReplen = MAX( IIF(MoveID LIKE '%-F%', 'Y', 'N') )
                         FROM #TEMP_REPLENISHMENT
                        GROUP BY DPLoc
                    ) RP ON DP.DPLoc = RP.DPLoc
                   WHERE ISNULL(DP.PA_Floor,'') <> 'VNA'
                     AND ISNULL(DP.FullPalletReplen,'') <> 'Y'
                     AND ISNULL(RP.FullPalletReplen,'') <> 'Y'
                     AND (ISNULL(@c_DPLoc_PAZone_SEL,'')=''
                       OR DP.PutawayZone IN (SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@c_DPLoc_PAZone_SEL, ',') WHERE value<>''))
                     AND ( ISNULL(DP.CubicCapacity,0) = 0 OR @n_ReplenCtnCBM <= ISNULL(DP.CubicCapacity,0) - ISNULL(DP.CBM,0) - ISNULL(RP.ReplenCBM,0) )
                     AND ( ISNULL(DP.MaxPallet,0) = 0 OR ISNULL(DP.NoOfMoveID,0) + ISNULL(RP.NoOfMoveID,0) <= ISNULL(DP.MaxPallet,0) )
                ) X
                ORDER BY CASE WHEN X.DivCountAll=1 AND X.CubicCapacity>0 THEN 1
                              when X.DivCountAll>1 OR ISNULL(X.CubicCapacity,0)=0 THEN 3
                              ELSE 2
                         END
                       , X.LogicalLocation, X.DPLoc
            END

            IF @n_ReplenQty <= 0
               SET @n_ReplenQty = @n_RemainReplenQty

            SET @n_ReplenCBM = @n_ReplenQty * @n_StdCube

            -- If DP Loc found, then update Pickdetail ToLoc & DropID
            IF ISNULL(@c_DPLoc,'')<>'' AND ISNULL(@c_DPLoc,'')<>ISNULL(@c_Loc,'') AND @n_ReplenQty > 0
            BEGIN
               -- Assign Move ID
               SET @n_MoveID_Count += 1
               SET @c_MoveID = @c_MoveIDPrefix + ISNULL(RTRIM(@c_ReplenType),'') + FORMAT(@n_MoveID_Count, '0000')

               INSERT INTO #TEMP_REPLENISHMENT (DPLoc, MoveID, ReplenQty, ReplenCBM, Div)
               VALUES(@c_DPLoc, @c_MoveID, @n_ReplenQty, @n_ReplenCBM, @c_Div)

               INSERT INTO #TEMP_REPLENISHMENT_FINAL (
                    StorerKey, Sku, FromLoc, Lot, Id, ToLoc, Qty, CaseCnt, AllocQty, UOM, PackKey,
                    ReplenNo, Remark, RefNo, LoadKey, Wavekey, Div, IsPickFace)
               VALUES(
                    @c_Storerkey, @c_Sku, @c_Loc, @c_LOT, @c_ID, @c_DPLoc, @n_ReplenQty, @n_CaseCnt, @n_AllocQty, @c_PackUOM3, @c_PackKey,
                    @c_Key, @c_ReplenType, '', IIF(@c_Type='LP',@c_Key,''), IIF(@c_Type='WP',@c_Key,''), @c_Div, 'N'
               )
            END

            SET @n_RemainReplenQty -= @n_ReplenQty
         END
      END
      CLOSE C_CUR_OUTSTANDING
      DEALLOCATE C_CUR_OUTSTANDING

   END
   CLOSE C_CUR_STR_FAC
   DEALLOCATE C_CUR_STR_FAC


   IF EXISTS(SELECT TOP 1 1 FROM #TEMP_REPLENISHMENT_FINAL)
   BEGIN
      -- Re-arrange Move ID sequence
      UPDATE X
         SET RefNo = Y.MoveID
        FROM #TEMP_REPLENISHMENT_FINAL X
        JOIN (
         SELECT RowID  = RP.RowID
              , MoveID = @c_MoveIDPrefix + ISNULL(RTRIM(RP.Remark),'') +
                         FORMAT( ROW_NUMBER() OVER(PARTITION BY RP.Remark ORDER BY RP.Div, FRPA.Descr, FRLOC.PutawayZone,
                         FRLOC.LogicalLocation, RP.FromLoc, TOLOC.LogicalLocation, RP.ToLoc, RP.ID, RP.Lot), '0000')
           FROM #TEMP_REPLENISHMENT_FINAL RP
           LEFT JOIN dbo.LOC        FRLOC(NOLOCK) ON RP.FromLoc = FRLOC.Loc
           LEFT JOIN dbo.PUTAWAYZONE FRPA(NOLOCK) ON FRLOC.PutawayZone = FRPA.PutawayZone
           LEFT JOIN dbo.LOC        TOLOC(NOLOCK) ON RP.ToLoc = TOLOC.Loc
        ) Y ON X.RowID = Y.RowID

      -- Insert Replenishment record and update Pickdetail
      DECLARE C_CUR_REPLENISHMENT_FINAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT StorerKey, Sku, FromLoc, Lot, Id, ToLoc, Qty, CaseCnt, AllocQty, UOM, PackKey,
             ReplenNo, Remark, RefNo, LoadKey, Wavekey, IsPickFace
        FROM #TEMP_REPLENISHMENT_FINAL
       ORDER BY StorerKey, Sku, FromLoc, Lot, Id, IsPickFace, ToLoc

      OPEN C_CUR_REPLENISHMENT_FINAL

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_CUR_REPLENISHMENT_FINAL
          INTO @c_Storerkey, @c_Sku, @c_Loc, @c_LOT, @c_ID, @c_DPLoc, @n_Qty, @n_CaseCnt, @n_AllocQty, @c_PackUOM3, @c_PackKey,
               @c_ReplenNo, @c_ReplenType, @c_MoveID, @c_LoadKey, @c_WaveKey, @c_IsPickFace

         IF @@FETCH_STATUS<>0
            BREAK

         IF @c_NoGenReplen = 'Y' OR
            (@c_ReplenType = 'S' AND @c_ShowFields LIKE '%,NoGenReplenSEL,%') OR
            (@c_ReplenType = 'V' AND @c_ShowFields LIKE '%,NoGenReplenVNA,%') OR
            (@c_ReplenType = 'F' AND @c_ShowFields LIKE '%,NoGenReplenFPR,%') OR
            (@c_ShowFields LIKE '%,ReplenMode2,%' AND
             EXISTS(SELECT TOP 1 1 FROM dbo.PICKDETAIL (NOLOCK)
                     WHERE Status < '9' AND ShipFlag<>'Y'
                       AND Storerkey = @c_Storerkey AND Sku = @c_Sku
                       AND Lot = @c_LOT AND Loc = @c_Loc AND ID = @c_ID
             )
            )
         BEGIN
            UPDATE PD WITH (ROWLOCK)
               SET ToLoc      = RTRIM( @c_DPLoc )
                 , DropID     = RTRIM( @c_MoveID )
                 , Notes      = RTRIM( @c_MoveID )
                 , MoveRefKey = ''
                 , Trafficcop = NULL
              FROM #TEMP_OUTSTANDING OS
              JOIN dbo.PICKDETAIL PD ON OS.PickDetailKey = PD.PickDetailKey
             WHERE PD.Status < '9' AND PD.ShipFlag<>'Y'
               AND PD.Storerkey = @c_Storerkey AND PD.Sku = @c_Sku
               AND PD.Lot = @c_LOT AND PD.Loc = @c_Loc AND PD.ID = @c_ID
         END
         ELSE
         BEGIN
            SET @c_ReplenishmentKey = ''

            IF @n_Qty > 0
            BEGIN
               SET @b_success = 0

               EXECUTE nspg_GetKey
                  'REPLENISHKEY',
                  10,
                  @c_ReplenishmentKey OUTPUT,
                  @b_success OUTPUT,
                  @n_err OUTPUT,
                  @c_errmsg OUTPUT

               SET @c_MoveRefKey = ISNULL(RTRIM(@c_ReplenishmentKey),'')

               IF @c_ID LIKE @c_NewIDPattern
                  AND EXISTS(SELECT TOP 1 1 FROM dbo.PICKDETAIL PD(NOLOCK)
                             LEFT JOIN #TEMP_OUTSTANDING a ON a.PickdetailKey=PD.PickdetailKey
                             WHERE PD.Storerkey = @c_Storerkey
                               AND a.PickDetailKey IS NULL
                               AND PD.Status = '0'
                               AND PD.SKU = @c_Sku
                               AND PD.LOT = @c_LOT
                               AND PD.Loc = @c_Loc
                               AND PD.ID = @c_ID
                               AND PD.Qty > 0)
                  AND (SELECT COUNT(1) FROM #TEMP_REPLENISHMENT_FINAL WHERE LOT = @c_LOT AND FromLoc = @c_Loc AND ID = @c_ID) <= 1
               BEGIN
                  SET @c_MoveRefKey = ''
               END

               -- Update Pickdetail ToLoc, DropID
               DECLARE C_CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.PickDetailKey
                    , PD.Qty
                    , PD.Status
                 FROM #TEMP_OUTSTANDING OS
                 JOIN dbo.PICKDETAIL PD ON OS.PickDetailKey = PD.PickDetailKey
                WHERE ISNULL(OS.Completed,'')<>'Y'
                  AND PD.Status < '9' AND PD.ShipFlag<>'Y'
                  AND PD.Storerkey = @c_Storerkey AND PD.Sku = @c_Sku
                  AND PD.Lot = @c_LOT AND PD.Loc = @c_Loc AND PD.ID = @c_ID
                ORDER BY PD.PickDetailKey

               OPEN C_CUR_PICKDETAIL

               SET @n_Qty2 = @n_Qty

               WHILE @n_Qty2>0
               BEGIN
                  FETCH NEXT FROM C_CUR_PICKDETAIL
                   INTO @c_PickDetailKey, @n_PDQty, @c_PDStatus

                  IF @@FETCH_STATUS<>0
                     BREAK

                  -- Split #TEMP_OUTSTANDING & PickDetail
                  IF @n_PDQty > @n_Qty2 AND @c_PDStatus = '0'
                  BEGIN
                     SET @b_success = 0

                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY',
                        10 ,
                        @c_NewPickDetailKey OUTPUT,
                        @b_success          OUTPUT,
                        @n_err              OUTPUT,
                        @c_errmsg           OUTPUT

                     IF @b_success = 1
                     BEGIN
                        BEGIN TRAN

                        -- #TEMP_OUTSTANDING
                        INSERT INTO #TEMP_OUTSTANDING (
                               PickdetailKey, Storerkey, Facility, SKU, LOT, LOC, ID, Qty,
                               Div, Brand, StdCube, CaseCnt, Lottable02, Lottable04, PA_Floor, LocAisle, PackKey, PackUOM3 )
                        SELECT @c_NewPickDetailKey, Storerkey, Facility, SKU, LOT, LOC, ID, @n_PDQty - @n_Qty2,
                               Div, Brand, StdCube, CaseCnt, Lottable02, Lottable04, PA_Floor, LocAisle, PackKey, PackUOM3
                          FROM #TEMP_OUTSTANDING
                         WHERE PickdetailKey = @c_PickDetailKey

                        UPDATE #TEMP_OUTSTANDING
                           SET Qty = @n_Qty2
                         WHERE PickdetailKey = @c_PickDetailKey

                        -- dbo.PICKDETAIL
                        INSERT INTO dbo.PICKDETAIL (
                               PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,
                               UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID, PackKey, UpdateSource,
                               CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                               WaveKey, EffectiveDate, TrafficCop, ArchiveCop, OptimizeCop, ShipFlag, PickSlipNo, Notes)
                        SELECT @c_NewPickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,
                               UOM, UOMQty, @n_PDQty - @n_Qty2, QtyMoved, Status, DropID, Loc, ID, PackKey, UpdateSource,
                               CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                               WaveKey, EffectiveDate, TrafficCop, ArchiveCop, '1', ShipFlag, PickSlipNo, Notes
                        FROM dbo.PickDetail WITH (NOLOCK)
                        WHERE PickDetailKey = @c_PickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           ROLLBACK TRAN
                           CLOSE C_CUR_PICKDETAIL
                           DEALLOCATE C_CUR_PICKDETAIL
                           CLOSE C_CUR_REPLENISHMENT_FINAL
                           DEALLOCATE C_CUR_REPLENISHMENT_FINAL

                           INSERT INTO #TEMP_ERROR (ErrMsg) VALUES('ERROR: Update Pickdetail Fail')
                           GOTO REPORT_RESULTSET
                        END

                        UPDATE dbo.PickDetail WITH (ROWLOCK)
                           SET Qty = @n_Qty2
                             , TrafficCop = NULL
                         WHERE PickDetailKey = @c_PickDetailKey

                        IF @@ERROR = 0
                           COMMIT TRAN
                        ELSE
                        BEGIN
                           ROLLBACK TRAN
                           CLOSE C_CUR_PICKDETAIL
                           DEALLOCATE C_CUR_PICKDETAIL
                           CLOSE C_CUR_REPLENISHMENT_FINAL
                           DEALLOCATE C_CUR_REPLENISHMENT_FINAL

                           INSERT INTO #TEMP_ERROR (ErrMsg) VALUES('ERROR: Update Pickdetail Fail')
                           GOTO REPORT_RESULTSET
                        END
                     END
                  END

                  UPDATE #TEMP_OUTSTANDING
                     SET Completed = 'Y'
                   WHERE PickdetailKey = @c_PickDetailKey

                  UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
                     SET ToLoc      = RTRIM( @c_DPLoc )
                       , DropID     = RTRIM( @c_MoveID )
                       , Notes      = RTRIM( @c_MoveID )
                       , MoveRefKey = @c_MoveRefKey
                       , Trafficcop = NULL
                   WHERE PickDetailKey = @c_PickDetailKey

                  IF ISNULL(@c_MoveRefKey,'')<>''
                     AND EXISTS(SELECT TOP 1 1 FROM dbo.PICKDETAIL PD(NOLOCK)
                             JOIN #TEMP_PICKDETAILKEY b on b.PickdetailKey=PD.PickdetailKey
                             LEFT JOIN #TEMP_OUTSTANDING a ON a.PickdetailKey=PD.PickdetailKey
                             WHERE PD.Storerkey = @c_Storerkey
                               AND a.PickDetailKey IS NULL
                               AND PD.Status = '0'
                               AND PD.SKU = @c_Sku
                               AND PD.LOT = @c_LOT
                               AND PD.Loc = @c_Loc
                               AND PD.ID = @c_ID
                               AND PD.Qty > 0)
                  BEGIN
                     UPDATE PD WITH(ROWLOCK)
                        SET MoveRefKey = @c_MoveRefKey
                       FROM dbo.PICKDETAIL PD
                       JOIN #TEMP_PICKDETAILKEY b on b.PickdetailKey=PD.PickdetailKey
                       LEFT JOIN #TEMP_OUTSTANDING a ON a.PickdetailKey=PD.PickdetailKey
                      WHERE PD.Storerkey = @c_Storerkey
                        AND a.PickDetailKey IS NULL
                        AND PD.Status = '0'
                        AND PD.SKU = @c_Sku
                        AND PD.LOT = @c_LOT
                        AND PD.Loc = @c_Loc
                        AND PD.ID = @c_ID
                        AND PD.Qty > 0
                  END

                  SET @n_Qty2 = @n_Qty2 - @n_PDQty
               END
               CLOSE C_CUR_PICKDETAIL
               DEALLOCATE C_CUR_PICKDETAIL

               -- Insert Replenishment record
               IF ISNULL(@c_ReplenishmentKey,'')<>''
               BEGIN
                  SELECT @c_NewID = @c_ID
                       , @c_Temp  = @c_ID

                  IF ISNULL(@c_Temp,'') LIKE @c_NewIDPattern AND NOT EXISTS(
                     SELECT TOP 1 1 FROM dbo.REPLENISHMENT (NOLOCK) WHERE Storerkey=@c_Storerkey AND
                     ReplenishmentKey = IIF(LEFT(@c_Temp,@n_ReplenKeyLen)<=@c_REPLENISHKEY,@c_ReplenKeyPrefix1,@c_ReplenKeyPrefix2) + LEFT(@c_Temp,@n_ReplenKeyLen) )
                  BEGIN
                     SELECT @c_Temp = PalletFlag
                       FROM dbo.ID (NOLOCK)
                       WHERE Id = @c_Temp AND Id<>'' AND Len(Id)>=@n_ReplenKeyLen+2
                         AND LEFT(ISNULL(PalletFlag,''),LEN(Id)) = Id
                         AND LEN(PalletFlag)>COLUMNPROPERTY(OBJECT_ID('ID'), 'Id', 'Precision')

                     SET @c_Temp = SUBSTRING(@c_Temp, @n_ReplenKeyLen+2, LEN(@c_Temp))
                  END

                  SET @c_NewID = RIGHT(RTRIM(@c_ReplenishmentKey),@n_ReplenKeyLen) +'*'+ ISNULL(RTRIM(@c_Temp),'')
                  SET @n_Qty2 = @n_Qty

                  IF @c_ID LIKE @c_NewIDPattern
                     AND EXISTS(SELECT TOP 1 1 FROM dbo.PICKDETAIL PD(NOLOCK)
                                LEFT JOIN #TEMP_OUTSTANDING a ON a.PickdetailKey=PD.PickdetailKey
                                WHERE PD.Storerkey = @c_Storerkey
                                  AND a.PickDetailKey IS NULL
                                  AND PD.Status = '0'
                                  AND PD.SKU = @c_Sku
                                  AND PD.LOT = @c_LOT
                                  AND PD.Loc = @c_Loc
                                  AND PD.ID = @c_ID
                                  AND PD.Qty > 0)
                     AND (SELECT COUNT(1) FROM #TEMP_REPLENISHMENT_FINAL WHERE LOT = @c_LOT AND FromLoc = @c_Loc AND ID = @c_ID) <= 1
                  BEGIN
                     -- If other wave/loadplan alloc same LotxLocxId, then update their ToLoc & DropID
                     SELECT @n_Qty2 = SUM(Qty - QtyPicked)
                       FROM dbo.LOTxLOCxID (NOLOCK)
                      WHERE Storerkey = @c_Storerkey
                        AND SKU = @c_Sku
                        AND LOT = @c_LOT
                        AND Loc = @c_Loc
                        AND ID  = @c_ID
                        AND Qty > 0

                     UPDATE PD WITH (ROWLOCK)
                        SET ToLoc      = RTRIM( @c_DPLoc )
                          , DropID     = RTRIM( @c_MoveID )
                          , Notes      = RTRIM( @c_MoveID )
                          , Trafficcop = NULL
                       FROM dbo.PICKDETAIL PD
                       LEFT JOIN #TEMP_OUTSTANDING a ON a.PickdetailKey=PD.PickdetailKey
                      WHERE PD.Storerkey = @c_Storerkey
                        AND a.PickDetailKey IS NULL
                        AND PD.Status = '0'
                        AND PD.SKU = @c_Sku
                        AND PD.LOT = @c_LOT
                        AND PD.Loc = @c_Loc
                        AND PD.ID = @c_ID
                        AND PD.Qty > 0
                  END

                  IF ISNULL(@n_Qty2,0) > 0
                  BEGIN
                     IF @b_debug=1
                        SELECT Action = 'nspItrnAddMove'
                             , c_StorerKey  = @c_Storerkey
                             , c_SKU        = @c_Sku
                             , c_LOT        = @c_LOT
                             , c_FromLoc    = @c_Loc
                             , c_FromID     = @c_ID
                             , c_ToLoc      = @c_Loc
                             , c_ToID       = @c_NewID
                             , n_Qty        = @n_Qty2
                             , c_SourceKey  = @c_ReplenishmentKey
                             , c_PackKey    = @c_PackKey
                             , c_UOM        = @c_PackUOM3
                             , c_MoveRefKey = @c_MoveRefKey

                     SELECT @b_UpdLoc       = 0
                          , @c_LoseID       = ''
                          , @c_CommingleSku = ''


                     SELECT @c_LoseID = LoseID
                          , @c_CommingleSku = CommingleSku
                       FROM dbo.LOC (NOLOCK)
                      WHERE Loc = @c_Loc

                     IF ISNULL(@c_LoseID,'') = '1'
                     BEGIN
                        SET @b_UpdLoc = 1
                        UPDATE dbo.LOC WITH(ROWLOCK) SET LoseID = '0' WHERE Loc = @c_Loc
                     END

                     IF ISNULL(@c_CommingleSku,'') NOT IN ('1', 'Y')
                     BEGIN
                        IF EXISTS (SELECT TOP 1 1 FROM LOTxLOCxID LLI WITH (NOLOCK)
                                    WHERE LLI.Loc = @c_Loc
                                      AND  (LLI.Storerkey <> @c_Storerkey OR  LLI.Sku <> @c_Sku)
                                      AND   LLI.Qty - LLI.QtyPicked > 0)
                        BEGIN
                           SET @b_UpdLoc = 1
                           UPDATE dbo.LOC WITH(ROWLOCK) SET CommingleSku = '1' WHERE Loc = @c_Loc
                        END
                     END

                     EXECUTE nspItrnAddMove
                          @n_ItrnSysId  = NULL
                        , @c_StorerKey  = @c_Storerkey
                        , @c_SKU        = @c_Sku
                        , @c_LOT        = @c_LOT
                        , @c_FromLoc    = @c_Loc
                        , @c_FromID     = @c_ID
                        , @c_ToLoc      = @c_Loc
                        , @c_ToID       = @c_NewID
                        , @c_Status     = ''
                        , @c_LOTtable01 = ''
                        , @c_LOTtable02 = ''
                        , @c_LOTtable03 = ''
                        , @d_lottable04 = NULL
                        , @d_lottable05 = NULL
                        , @c_LOTtable06 = ''
                        , @c_LOTtable07 = ''
                        , @c_LOTtable08 = ''
                        , @c_LOTtable09 = ''
                        , @c_LOTtable10 = ''
                        , @c_LOTtable11 = ''
                        , @c_LOTtable12 = ''
                        , @d_lottable13 = NULL
                        , @d_lottable14 = NULL
                        , @d_lottable15 = NULL
                        , @n_casecnt    = 0
                        , @n_innerpack  = 0
                        , @n_Qty        = @n_Qty2
                        , @n_pallet     = 0
                        , @f_cube       = 0
                        , @f_grosswgt   = 0
                        , @f_netwgt     = 0
                        , @f_otherunit1 = 0
                        , @f_otherunit2 = 0
                        , @c_SourceKey  = ''
                        , @c_SourceType = ''
                        , @c_PackKey    = @c_PackKey
                        , @c_UOM        = @c_PackUOM3
                        , @b_UOMCalc    = 1
                        , @d_EffectiveDate = NULL
                        , @c_itrnkey    = ''
                        , @b_Success    = @b_Success OUTPUT
                        , @n_Err        = @n_Err OUTPUT
                        , @c_ErrMsg     = @c_ErrMsg OUTPUT
                        , @c_MoveRefKey = @c_MoveRefKey

                     IF @b_UpdLoc = 1
                     BEGIN
                        UPDATE dbo.LOC WITH(ROWLOCK)
                           SET LoseID       = @c_LoseID
                             , CommingleSku = @c_CommingleSku
                         WHERE Loc = @c_Loc
                     END
                  END

                  IF @b_Success = 1
                  BEGIN
                     SET @c_ID = @c_NewID
                     SET @c_Temp = LEFT(@c_NewID, COLUMNPROPERTY(OBJECT_ID('ID'), 'Id', 'Precision'))
                     IF ISNULL(@c_Temp,'')<>'' AND @c_NewID <> @c_Temp
                     BEGIN
                        UPDATE dbo.ID WITH(ROWLOCK)
                           SET PalletFlag = @c_NewID
                         WHERE Id = @c_Temp
                     END
                  END

                  IF ISNULL(@c_ID,'') = ISNULL(@c_NewID,'') AND ISNULL(@c_NewID,'')<>''
                  BEGIN
                     INSERT INTO dbo.REPLENISHMENT (
                          ReplenishmentGroup, ReplenishmentKey, StorerKey, Sku, FromLoc, Lot, Id, ToLoc,
                          Qty, UOM, PackKey, Confirmed, ReplenNo, Remark, RefNo, DropID,
                          LoadKey, Wavekey,
                          OriginalFromLoc, OriginalQty)
                     VALUES(
                          @c_ReplenGroup, @c_ReplenishmentKey, @c_Storerkey, @c_Sku, @c_Loc, @c_LOT, @c_ID, @c_DPLoc,
                          @n_Qty, @c_PackUOM3, @c_PackKey, 'N', @c_ReplenNo, @c_ReplenType, @c_MoveID, '',
                          @c_LoadKey, @c_WaveKey,
                          @c_DPLoc, @n_Qty
                     )
                  END

                  IF EXISTS( SELECT TOP 1 1 FROM dbo.PICKDETAIL (NOLOCK)
                              WHERE Storerkey = @c_Storerkey
                                AND DropID    = @c_MoveID
                                AND ISNULL(MoveRefKey,'')<>'' )
                  BEGIN
                     UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
                        SET MoveRefKey = ''
                          , Trafficcop = NULL
                      WHERE Storerkey = @c_Storerkey
                        AND DropID    = @c_MoveID
                        AND ISNULL(MoveRefKey,'')<>''
                  END
               END
            END
         END
      END
      CLOSE C_CUR_REPLENISHMENT_FINAL
      DEALLOCATE C_CUR_REPLENISHMENT_FINAL
   END

   -- Clear Waveplan/Loadplan ReGenReplen/ReGenReplenALL flag (Userdefine02)
   IF ISNULL(@c_ReGenReplen,'')='Y'
   BEGIN
      IF @c_Type = 'WP'
         UPDATE dbo.WAVE WITH (ROWLOCK)
            SET Userdefine02 = SUBSTRING(Userdefine02,3,LEN(Userdefine02))
          WHERE Wavekey = @c_Key
            AND Userdefine02 IN ('ReGenReplen', 'ReGenReplenALL')
      ELSE
      IF @c_Type = 'LP'
         UPDATE dbo.LOADPLAN WITH (ROWLOCK)
            SET Userdefine02 = SUBSTRING(Userdefine02,3,LEN(Userdefine02))
          WHERE Loadkey = @c_Key
            AND Userdefine02 IN ('ReGenReplen', 'ReGenReplenALL')
   END

   -- Clear Waveplan/Loadplan NoGenReplen flag (Userdefine02)
   IF ISNULL(@c_NoGenReplen,'')='Y' AND @c_ShowFields LIKE '%,ClearNoGenReplenFlag,%'
   BEGIN
      IF @c_Type = 'WP'
         UPDATE dbo.WAVE WITH (ROWLOCK)
            SET Userdefine02 = ''
          WHERE Wavekey = @c_Key
            AND Userdefine02 = 'NoGenReplen'
      ELSE
      IF @c_Type = 'LP'
         UPDATE dbo.LOADPLAN WITH (ROWLOCK)
            SET Userdefine02 = ''
          WHERE Loadkey = @c_Key
            AND Userdefine02 = 'NoGenReplen'
   END


REPORT_RESULTSET:
   TRUNCATE TABLE #TEMP_PICKDETAILKEY
   TRUNCATE TABLE #TEMP_RESULTSET

   IF NOT EXISTS(SELECT TOP 1 1 FROM #TEMP_ERROR)
   BEGIN
      INSERT INTO #TEMP_PICKDETAILKEY (PickdetailKey, Storerkey)
      SELECT PickdetailKey = PD.PickdetailKey
           , Storerkey     = MAX(PD.Storerkey)
        FROM dbo.ORDERS          OH (NOLOCK)
        JOIN dbo.PICKDETAIL      PD (NOLOCK) ON OH.Orderkey = PD.OrderKey
        WHERE @c_Key <> ''
         AND ( @c_Type = 'WP' OR @c_Type = 'LP' )
         AND ((@c_Type = 'WP' AND OH.Userdefine09 = @c_Key)
           OR (@c_Type = 'LP' AND OH.Loadkey      = @c_Key)
             )
         AND PD.DropID<>''
         AND LEFT(PD.DropID,LEN(@c_MoveIDPrefix)) = @c_MoveIDPrefix
       GROUP BY PD.PickdetailKey


      -- Storerkey Loop
      DECLARE C_CUR_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Storerkey
        FROM #TEMP_PICKDETAILKEY
       ORDER BY 1

      OPEN C_CUR_STORERKEY

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_CUR_STORERKEY
          INTO @c_Storerkey

         IF @@FETCH_STATUS<>0
            BREAK

         SELECT @c_JoinClause         = ''
              , @c_DivExp             = ''
              , @c_BrandExp           = ''
              , @c_CaseCntExp         = ''
              , @c_FromLocExp         = ''

         SELECT TOP 1
                @c_JoinClause = Notes
           FROM dbo.CodeLkup (NOLOCK)
          WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y' AND ISNULL(UDF02,'')=''
            AND Storerkey = @c_Storerkey
          ORDER BY Code2

         SELECT TOP 1
                @c_DivExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                        from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                        where a.SeqNo=b.SeqNo and a.ColValue='Div')), '' )
              , @c_BrandExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                        from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                        where a.SeqNo=b.SeqNo and a.ColValue='Brand')), '' )
              , @c_CaseCntExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                        from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                        where a.SeqNo=b.SeqNo and a.ColValue='CaseCnt')), '' )
              , @c_FromLocExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                        from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                        where a.SeqNo=b.SeqNo and a.ColValue='FromLoc')), '' )
           FROM dbo.CodeLkup (NOLOCK)
          WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
            AND Storerkey = @c_Storerkey
          ORDER BY Code2


         SET @c_ExecStatements =
            N'INSERT INTO #TEMP_RESULTSET ('
              + ' ReplenishmentKey, ReplenNo, Div, PutawayZone, Facility, StorerKey, Sku, Descr, AltSku, LogicalLocation'
              +', FromLoc, FromID, ToFacility, ToLoc, DropID, Lottable02, Lottable04, PackKey, CaseCnt, PACKUOM1'
              +', PACKUOM3, AllocQty, ReplenQty, ReplenType, PA_Descr, Brand, Lot'
              +', TOLOC_LocationType, FromID_Long, ShowFields)'

         SET @c_ExecStatements = @c_ExecStatements
           + ' SELECT ReplenishmentKey   = RTRIM( ISNULL(RP.ReplenishmentKey, '''') )'
           +       ', ReplenNo           = RTRIM( @c_Key )'
         SET @c_ExecStatements = @c_ExecStatements
           +       ', Div                = RTRIM( ISNULL(' + CASE WHEN ISNULL(@c_DivExp,'')<>'' THEN @c_DivExp ELSE '''''' END + ',''''))'
         SET @c_ExecStatements = @c_ExecStatements
           +       ', PutawayZone        = RTRIM( FRLOC.PutawayZone )'
           +       ', Facility           = RTRIM( FRLOC.Facility )'
           +       ', StorerKey          = RTRIM( PD.StorerKey )'
           +       ', Sku                = RTRIM( PD.Sku )'
           +       ', Descr              = RTRIM( SKU.Descr )'
           +       ', AltSku             = RTRIM( ISNULL(SKU.AltSku, '''') )'
           +       ', LogicalLocation    = RTRIM( FRLOC.LogicalLocation )'
         SET @c_ExecStatements = @c_ExecStatements
           +       ', FromLoc            = RTRIM( ISNULL(' + CASE WHEN ISNULL(@c_FromLocExp,'')<>'' THEN @c_FromLocExp ELSE 'PD.Loc' END + ',''''))'
         SET @c_ExecStatements = @c_ExecStatements
           +       ', FromID             = RTRIM( PD.ID )'
           +       ', ToFacility         = RTRIM( TOLOC.Facility )'
           +       ', ToLoc              = RTRIM( PD.ToLoc )'
           +       ', DropID             = RTRIM( PD.DropID )'
           +       ', Lottable02         = RTRIM( LA.Lottable02 )'
           +       ', Lottable04         = LA.Lottable04'
           +       ', PackKey            = RTRIM( SKU.PackKey )'
         SET @c_ExecStatements = @c_ExecStatements
           +       ', CaseCnt            = ISNULL(' + CASE WHEN ISNULL(@c_CaseCntExp  ,'')<>'' THEN @c_CaseCntExp ELSE 'PACK.CaseCnt' END + ',0)'
         SET @c_ExecStatements = @c_ExecStatements
           +       ', PACKUOM1           = RTRIM( IIF(ISNULL(PACK.PACKUOM1,'''')='''', ''CS'', PACK.PACKUOM1) )'
           +       ', PACKUOM3           = RTRIM( PACK.PACKUOM3 )'
           +       ', AllocQty           = PD.Qty'
           +       ', ReplenQty          = RP.Qty'
           +       ', ReplenType         = RTRIM( @c_Type )'
           +       ', PA_Descr           = RTRIM( FRPA.Descr )'
         SET @c_ExecStatements = @c_ExecStatements
           +       ', Brand              = RTRIM( ISNULL(' + CASE WHEN ISNULL(@c_BrandExp,'')<>'' THEN @c_BrandExp ELSE '''''' END + ',''''))'
         SET @c_ExecStatements = @c_ExecStatements
           +       ', Lot                = PD.Lot'
           +       ', TOLOC_LocationType = ISNULL(TOLOC.LocationType,''DYNAMICPK'')'
           +       ', FromID_Long        = RTRIM( CASE WHEN ISNULL(ID.PalletFlag,'''')<>'''' AND LEFT(ID.PalletFlag,COLUMNPROPERTY(OBJECT_ID(''ID''), ''Id'', ''Precision''))=PD.ID'
           +                                         ' THEN ID.PalletFlag ELSE PD.ID END )'
           +       ', ShowFields         = RptCfg.ShowFields'

         SET @c_ExecStatements = @c_ExecStatements
           +   ' FROM #TEMP_PICKDETAILKEY PDK'
           +   ' JOIN dbo.PICKDETAIL      PD (NOLOCK) ON PDK.PickdetailKey = PD.PickdetailKey'
           +   ' JOIN dbo.ORDERS          OH (NOLOCK) ON PD.Orderkey = OH.OrderKey'
           +   ' JOIN dbo.SKU            SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.SKU = SKU.SKU'
           +   ' JOIN dbo.PACK          PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey'
           +   ' JOIN dbo.LOTATTRIBUTE    LA (NOLOCK) ON PD.Lot = LA.Lot'
           +   ' JOIN dbo.LOC          FRLOC (NOLOCK) ON PD.Loc = FRLOC.Loc'
           +   ' JOIN dbo.PUTAWAYZONE   FRPA (NOLOCK) ON FRLOC.PutawayZone = FRPA.PutawayZone'
           +   ' LEFT JOIN dbo.LOC     TOLOC (NOLOCK) ON PD.ToLoc = TOLOC.Loc'
           +   ' LEFT JOIN dbo.REPLENISHMENT RP (NOLOCK) ON PD.DropID = RP.RefNo'
           +   ' LEFT JOIN dbo.ID            ID (NOLOCK) ON PD.Id = ID.Id'
           +   ' LEFT JOIN ('
           +   '    SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))'
           +   '         , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)'
           +   '      FROM dbo.CodeLkup (NOLOCK) WHERE Listname=''REPORTCFG'' AND Code=''SHOWFIELD'' AND Long=@c_DataWindow AND Short=''Y'''
           +   ' ) RptCfg ON RptCfg.Storerkey=PD.Storerkey AND RptCfg.SeqNo=1'

         SET @c_ExecStatements = @c_ExecStatements
             + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END

         SET @c_ExecStatements = @c_ExecStatements
           +   ' WHERE PDK.Storerkey = @c_Storerkey'


         SET @c_ExecArguments = N'@c_DataWindow   NVARCHAR(40)'
                              + ',@c_Key          NVARCHAR(10)'
                              + ',@c_Type         NVARCHAR(2)'
                              + ',@c_Storerkey    NVARCHAR(15)'

         EXEC sp_ExecuteSql @c_ExecStatements
                          , @c_ExecArguments
                          , @c_DataWindow
                          , @c_Key
                          , @c_Type
                          , @c_Storerkey
      END
      CLOSE C_CUR_STORERKEY
      DEALLOCATE C_CUR_STORERKEY
   END

   -- Result Set
   SELECT ReplenishmentKey   = X.ReplenishmentKey
        , ReplenNo           = MAX(X.ReplenNo)
        , Div                = MAX(X.Div)
        , PutawayZone        = MAX(X.PutawayZone)
        , Facility           = MAX(X.Facility)
        , StorerKey          = MAX(X.StorerKey)
        , Sku                = MAX(X.Sku)
        , Descr              = MAX(X.Descr)
        , AltSku             = MAX(X.AltSku)
        , LogicalLocation    = MAX(X.LogicalLocation)
        , FromLoc            = X.FromLoc
        , FromID             = X.FromID
        , ToFacility         = MAX(X.ToFacility)
        , ToLoc              = MAX(X.ToLoc)
        , DropID             = X.DropID
        , Lottable02         = MAX(X.Lottable02)
        , Lottable04         = MAX(X.Lottable04)
        , PackKey            = MAX(X.PackKey)
        , CaseCnt            = MAX(X.CaseCnt)
        , PACKUOM1           = MAX(X.PACKUOM1)
        , PACKUOM3           = MAX(X.PACKUOM3)
        , AllocQty           = SUM(X.AllocQty)
        , ReplenQty          = ISNULL( MAX(X.ReplenQty), SUM(X.AllocQty) )
        , PA_LoosePiece      = ISNULL( MAX(X.ReplenQty), SUM(X.AllocQty) ) - SUM(X.AllocQty)
        , UserName           = RTRIM( SUSER_SNAME() )
        , datawindow         = @c_DataWindow
        , ReplenType         = MAX(X.ReplenType)
        , PA_Descr           = MAX(X.PA_Descr)
        , Brand              = MAX(X.Brand)
        , Lot                = X.Lot
        , TOLOC_LocationType = MAX(X.TOLOC_LocationType)
        , FromID_Long        = MAX(X.FromID_Long)
        , ShowFields         = MAX(X.ShowFields)
        , ErrSeq             = NULL
        , ErrMsg             = NULL
     FROM #TEMP_RESULTSET X
    GROUP BY X.ReplenishmentKey, X.Lot, X.FromLoc, X.FromID, X.DropID

   UNION ALL

   SELECT NULL, RTRIM(@c_Key), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
        , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
        , NULL, NULL, NULL, NULL, NULL, @c_DataWindow, RTRIM(@c_Type), NULL, NULL, NULL
        , NULL, NULL, NULL
        , ErrSeq, ErrMsg
     FROM #TEMP_ERROR

    ORDER BY ReplenNo, Div, PA_Descr, PutawayZone, LogicalLocation, FromLoc, DropID, ErrSeq

QUIT:
   WHILE @@TRANCOUNT > @n_StartTCnt
   BEGIN
      COMMIT TRAN
   END
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO