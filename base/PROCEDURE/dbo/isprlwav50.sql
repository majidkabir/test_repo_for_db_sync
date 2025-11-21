SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRLWAV50                                         */
/* Creation Date: 12-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19079 - CN NIKE PHC RELEASE TASK                        */
/*                                                                      */
/* Called By: Wave                                                      */
/*                                                                      */
/* GitLab Version: 1.5                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 12-Apr-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 23-Feb-2023  WLChooi  1.1  WMS-19079 - Fix FP/PP Calculation (WL01)  */
/* 27-Feb-2023  WLChooi  1.2  WMS-19079 - Fix ToLoc is blank (WL02)     */
/* 24-Mar-2023  WLChooi  1.3  Performance Tune (WL03)                   */
/* 11-Apr-2023  WLChooi  1.4  WMS-19079 - Change empty loc logic (WL05) */
/* 02-Mar-2023  WLChooi  1.5  WMS-19079 - Add new logic to generate     */
/*                            Case ID by SKU.PackQtyIndicator and fixed */
/*                            FP/PP Calculation by Wave (WL04)          */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispRLWAV50]
   @c_Wavekey NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_err     INT           OUTPUT
 , @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue            INT
         , @b_Debug               INT
         , @n_StartTranCnt        INT
         , @n_PEMaxQty            INT           = 0
         , @n_MaxCountPDLoc       INT           = 0
         , @c_Storerkey           NVARCHAR(15)
         , @c_Facility            NVARCHAR(5)
         , @c_DocType             NVARCHAR(10)
         , @c_Orderkey            NVARCHAR(10)
         , @c_SKU                 NVARCHAR(20)
         , @c_PrevSKU             NVARCHAR(20)
         , @c_Lot                 NVARCHAR(20)
         , @c_Loc                 NVARCHAR(20)
         , @c_ID                  NVARCHAR(50)
         , @c_Pickzone            NVARCHAR(10)
         , @c_PrevPickzone        NVARCHAR(10)
         , @c_SKUGroup            NVARCHAR(50)
         , @n_Qty                 INT
         , @c_CaseID              NVARCHAR(20)  = N''
         , @n_TotalQty            INT           = 0
         , @c_SeqNo               NVARCHAR(10)  = N''
         , @n_CountLoc            INT           = 0
         , @c_NewCaseID           NVARCHAR(10)  = N'N'
         , @c_Pickdetailkey       NVARCHAR(10)
         , @c_SQL                 NVARCHAR(MAX)
         , @c_SQLArgument         NVARCHAR(MAX)
         , @n_packqty             INT
         , @n_pickqty             INT
         , @n_cnt                 INT
         , @n_splitqty            INT
         , @c_GetPickdetCondition NVARCHAR(MAX)
         , @c_NewPickdetailkey    NVARCHAR(10)
         , @c_ItemClass           NVARCHAR(50)
         , @c_PrevItemClass       NVARCHAR(50)
         , @n_PDQtyPerID          INT
         , @n_UCCQty              INT
         , @c_Loadkey             NVARCHAR(10)
         , @c_PrevLoadkey         NVARCHAR(10)
         , @n_RowID               INT
         , @c_FromLoc             NVARCHAR(20)
         , @c_ToLoc               NVARCHAR(20)
         , @c_FinalLoc            NVARCHAR(20)
         , @c_PrevLoc             NVARCHAR(20)  
         , @c_TempToLoc           NVARCHAR(20)
         , @c_KeyName             NVARCHAR(10)  = N'NIKEPHC_SeqNo'
         , @n_Casecnt             INT
         , @n_RemainQty           INT           = 0
         , @n_AvailableQty        INT           = 0
         , @c_TaskDetailKey       NVARCHAR(10)
         , @c_TaskType            NVARCHAR(10)  = N'RPF'
         , @c_SourceType          NVARCHAR(20)  = N'ispRLWAV50'
         , @c_LocRoom             NVARCHAR(20)
         , @c_Remark              NVARCHAR(20)
         , @n_SystemQty           INT           = 0
         , @c_MaxEmptyLocPZ       NVARCHAR(20)
         , @c_CallFrom            NVARCHAR(20)
         , @c_curPickdetailkey    NVARCHAR(20)
         , @n_ReplenQty           INT
         , @c_Site                NVARCHAR(30)
         , @c_Packkey             NVARCHAR(20)
         , @c_ProcessType         NVARCHAR(30)
         , @c_UOM                 NVARCHAR(10)
         , @c_Pickmethod          NVARCHAR(10)
         , @c_TableJoin           NVARCHAR(1000)
         , @n_SKUPackQtyIndicator INT
         , @c_Areakey             NVARCHAR(10)
         , @c_Type                NVARCHAR(10)
         , @c_Message01           NVARCHAR(50)
         , @c_DropID              NVARCHAR(50)
         , @dt_StartTime          DATETIME        
         , @dt_EndTime            DATETIME    
         , @c_PrevTaskType        NVARCHAR(10)
         , @n_MaxQty              INT   --WL04

   SET @b_Debug = @n_err

   SELECT @n_StartTranCnt = @@TRANCOUNT
        , @n_Continue = 1
        , @b_Success = 1
        , @n_err = 0
        , @c_errmsg = ''

   -----Get Wave Info-----
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT @c_Storerkey = MAX(OH.StorerKey)
           , @c_Facility = MAX(OH.Facility)
           , @c_DocType = MAX(OH.DocType)
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.WaveKey = @c_Wavekey
   END

   ---Wave Validation-----            
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM WAVE W (NOLOCK)
                   WHERE W.WaveKey = @c_Wavekey AND W.TMReleaseFlag IN ( 'Y' ))
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_err = 87000
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + ': This Wave has been released, RPF task is generated. (ispRLWAV50)'
      END
   END

   ------Temp Table--------
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      CREATE TABLE #TMP_CASEID
      (
         RowID         INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , Loadkey       NVARCHAR(10) NULL
       , SKU           NVARCHAR(20)
       , LOC           NVARCHAR(10)
       , Pickzone      NVARCHAR(10)
       , Qty           INT
       , LocRoom       NVARCHAR(50) NULL
       , ItemClass     NVARCHAR(50)
       , CaseID        NVARCHAR(20)
       , [Status]      NVARCHAR(10) NULL
       , SKUGroup      NVARCHAR(50) NULL
       , Taskdetailkey NVARCHAR(10) NULL
      )

      CREATE TABLE #TMP_CODELKUP
      (
         Pickzone NVARCHAR(50)
       , SKUGroup NVARCHAR(50)
       , PEMaxQty INT
       , LocQty   INT
       , [Site]   NVARCHAR(10)
      )

      --Current wave assigned dynamic pick location    
      CREATE TABLE #DYNPICK_LOCASSIGNED
      (
         Rowref       INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , STORERKEY    NVARCHAR(15) NULL
       , SKU          NVARCHAR(20) NULL
       , TOLOC        NVARCHAR(10) NULL
       , LocationType NVARCHAR(10) NULL
       , Putawayzone  NVARCHAR(50) NULL
      )
      CREATE INDEX IDX_TOLOC ON #DYNPICK_LOCASSIGNED (TOLOC)

      CREATE TABLE #DYNPICK_TASK
      (
         Rowref      INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , TOLOC       NVARCHAR(10) NULL
       , Putawayzone NVARCHAR(50) NULL
      )

      CREATE TABLE #DYNPICK_NON_EMPTY
      (
         Rowref      INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , LOC         NVARCHAR(10) NULL
       , Putawayzone NVARCHAR(50) NULL
      )

      CREATE TABLE #DYNLOC
      (
         Rowref          INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , Loc             NVARCHAR(10) NULL
       , logicallocation NVARCHAR(18) NULL
       , MaxPallet       INT          NULL
       , Putawayzone     NVARCHAR(50) NULL
       , LocScore        INT          NULL
       , LocationRoom    NVARCHAR(30) NULL
       , Pickzone        NVARCHAR(30) NULL
      )
      CREATE INDEX IDX_DLOC ON #DYNLOC (Loc)

      CREATE TABLE #EXCLUDELOC
      (
         Rowref      INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , LOC         NVARCHAR(10) NULL
       , Putawayzone NVARCHAR(50) NULL
      )
      CREATE INDEX IDX_LOC ON #EXCLUDELOC (LOC)

      --Current wave assigned SAFETYSTOCK location
      CREATE TABLE #SAFETYSTOCK_LOCASSIGNED
      (
         Rowref       INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , STORERKEY    NVARCHAR(15) NULL
       , SKU          NVARCHAR(20) NULL
       , TOLOC        NVARCHAR(10) NULL
       , LocationType NVARCHAR(20) NULL
       , ItemClass    NVARCHAR(50) NULL
       , Pickzone     NVARCHAR(50) NULL
       , Putawayzone  NVARCHAR(50) NULL
      )
      CREATE INDEX IDX_SAFETYSTOCK_TOLOC ON #SAFETYSTOCK_LOCASSIGNED (TOLOC)

      CREATE TABLE #SAFETYSTOCK_TASK
      (
         Rowref      INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , TOLOC       NVARCHAR(10) NULL
       , ItemClass   NVARCHAR(50) NULL
       , Pickzone    NVARCHAR(50) NULL
       , Putawayzone NVARCHAR(50) NULL
      )

      CREATE TABLE #SAFETYSTOCK_NON_EMPTY
      (
         Rowref      INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , LOC         NVARCHAR(10) NULL
       , ItemClass   NVARCHAR(50) NULL
       , Pickzone    NVARCHAR(50) NULL
       , Putawayzone NVARCHAR(50) NULL
      )

      CREATE TABLE #SAFETYSTOCK_LOC
      (
         Rowref          INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , Loc             NVARCHAR(10) NULL
       , logicallocation NVARCHAR(18) NULL
       , MaxPallet       INT          NULL
       , ItemClass       NVARCHAR(50) NULL
       , Pickzone        NVARCHAR(50) NULL
       , Putawayzone     NVARCHAR(50) NULL
       , LocScore        INT          NULL
       , LocationRoom    NVARCHAR(30) NULL
      )
      CREATE INDEX IDX_SAFETYSTOCK_LOC ON #SAFETYSTOCK_LOC (Loc)

      CREATE TABLE #SAFETYSTOCK_EXCLUDELOC
      (
         Rowref      INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
       , LOC         NVARCHAR(10) NULL
       , ItemClass   NVARCHAR(50) NULL
       , Pickzone    NVARCHAR(50) NULL
       , Putawayzone NVARCHAR(50) NULL
      )
      CREATE INDEX IDX_SAFETYSTOCK_ELOC ON #SAFETYSTOCK_EXCLUDELOC (LOC)

      INSERT INTO #TMP_CODELKUP (Pickzone, SKUGroup, PEMaxQty, LocQty, [Site])
      SELECT DISTINCT CL.Code
                    , CL.code2
                    , CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CL.Long
                           ELSE 0 END
                    , CASE WHEN ISNUMERIC(CL.UDF01) = 1 THEN CL.UDF01
                           ELSE 0 END
                    , CASE WHEN ISNULL(CL.Notes, 'N') = 'Y' THEN 'Offsite'
                           ELSE 'Onsite' END
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'NKEPKTSK' AND CL.Storerkey = @c_Storerkey AND CL.Short = 'Y'
		  
      DECLARE @T_ID TABLE (Storerkey NVARCHAR(15), ID NVARCHAR(50), Pickmethod NVARCHAR(10) )   --WL03
		  
      --WL04 S
      DECLARE @T_Numbers TABLE (
         RowID           INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
         Dummy           NVARCHAR(1)
      )
      --WL04 E
   END

   --WHILE @@TRANCOUNT > 0 
   --BEGIN
   --   COMMIT TRAN
   --END

   --IF @@TRANCOUNT = 0
   --   BEGIN TRAN

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      IF OBJECT_ID('#PickDetail_WIP') IS NOT NULL
      BEGIN
         DROP TABLE #PickDetail_WIP
      END

      CREATE TABLE #PickDetail_WIP
      (
         [PickDetailKey]        [NVARCHAR](18)   NOT NULL PRIMARY KEY
       , [CaseID]               [NVARCHAR](20)   NOT NULL DEFAULT (' ')
       , [PickHeaderKey]        [NVARCHAR](18)   NOT NULL
       , [OrderKey]             [NVARCHAR](10)   NOT NULL
       , [OrderLineNumber]      [NVARCHAR](5)    NOT NULL
       , [Lot]                  [NVARCHAR](10)   NOT NULL
       , [Storerkey]            [NVARCHAR](15)   NOT NULL
       , [Sku]                  [NVARCHAR](20)   NOT NULL
       , [AltSku]               [NVARCHAR](20)   NOT NULL DEFAULT (' ')
       , [UOM]                  [NVARCHAR](10)   NOT NULL DEFAULT (' ')
       , [UOMQty]               [INT]            NOT NULL DEFAULT ((0))
       , [Qty]                  [INT]            NOT NULL DEFAULT ((0))
       , [QtyMoved]             [INT]            NOT NULL DEFAULT ((0))
       , [Status]               [NVARCHAR](10)   NOT NULL DEFAULT ('0')
       , [DropID]               [NVARCHAR](20)   NOT NULL DEFAULT ('')
       , [Loc]                  [NVARCHAR](10)   NOT NULL DEFAULT ('UNKNOWN')
       , [ID]                   [NVARCHAR](18)   NOT NULL DEFAULT (' ')
       , [PackKey]              [NVARCHAR](10)   NULL DEFAULT (' ')
       , [UpdateSource]         [NVARCHAR](10)   NULL DEFAULT ('0')
       , [CartonGroup]          [NVARCHAR](10)   NULL
       , [CartonType]           [NVARCHAR](10)   NULL
       , [ToLoc]                [NVARCHAR](10)   NULL DEFAULT (' ')
       , [DoReplenish]          [NVARCHAR](1)    NULL DEFAULT ('N')
       , [ReplenishZone]        [NVARCHAR](10)   NULL DEFAULT (' ')
       , [DoCartonize]          [NVARCHAR](1)    NULL DEFAULT ('N')
       , [PickMethod]           [NVARCHAR](1)    NOT NULL DEFAULT (' ')
       , [WaveKey]              [NVARCHAR](10)   NOT NULL DEFAULT (' ')
       , [EffectiveDate]        [DATETIME]       NOT NULL DEFAULT (GETDATE())
       , [AddDate]              [DATETIME]       NOT NULL DEFAULT (GETDATE())
       , [AddWho]               [NVARCHAR](128)  NOT NULL DEFAULT (SUSER_SNAME())
       , [EditDate]             [DATETIME]       NOT NULL DEFAULT (GETDATE())
       , [EditWho]              [NVARCHAR](128)  NOT NULL DEFAULT (SUSER_SNAME())
       , [TrafficCop]           [NVARCHAR](1)    NULL
       , [ArchiveCop]           [NVARCHAR](1)    NULL
       , [OptimizeCop]          [NVARCHAR](1)    NULL
       , [ShipFlag]             [NVARCHAR](1)    NULL DEFAULT ('0')
       , [PickSlipNo]           [NVARCHAR](10)   NULL
       , [TaskDetailKey]        [NVARCHAR](10)   NULL
       , [TaskManagerReasonKey] [NVARCHAR](10)   NULL
       , [Notes]                [NVARCHAR](4000) NULL
       , [MoveRefKey]           [NVARCHAR](10)   NULL DEFAULT ('')
       , [WIP_Refno]            [NVARCHAR](30)   NOT NULL DEFAULT ('')
       , [Channel_ID]           [BIGINT]         NULL DEFAULT ((0))
      )

      CREATE INDEX IDX_PDWIP_Orderkey ON #PickDetail_WIP (OrderKey)
      CREATE INDEX IDX_PDWIP_SKU ON #PickDetail_WIP (Storerkey, Sku)
      CREATE INDEX IDX_PDWIP_CaseID ON #PickDetail_WIP (PickSlipNo, CaseID)
   END

   --Initialize Pickdetail work in progress staging table
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_Wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'I' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
                                  , @c_RemoveTaskdetailkey = 'Y' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_err OUTPUT
                                  , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
      END
   END

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SET @c_curPickdetailkey = N''

      DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey
      FROM WAVEDETAIL WITH (NOLOCK)
      JOIN #PickDetail_WIP PICKDETAIL WITH (NOLOCK) ON WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey
      WHERE WAVEDETAIL.WaveKey = @c_Wavekey

      OPEN Orders_Pickdet_cur
      FETCH NEXT FROM Orders_Pickdet_cur
      INTO @c_curPickdetailkey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE #PickDetail_WIP WITH (ROWLOCK)
         SET --TaskdetailKey   = '', 
            Notes = ''
          , WaveKey = @c_Wavekey
          , EditWho = SUSER_SNAME()
          , EditDate = GETDATE()
          , TrafficCop = NULL
         WHERE PickDetailKey = @c_curPickdetailkey

         SELECT @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            CLOSE Orders_Pickdet_cur
            DEALLOCATE Orders_Pickdet_cur
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 87005 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + ': Update Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END

         FETCH NEXT FROM Orders_Pickdet_cur
         INTO @c_curPickdetailkey
      END
      CLOSE Orders_Pickdet_cur
      DEALLOCATE Orders_Pickdet_cur
   END

   --Filter #PICKDETAIL_WIP with only CaseID = '' records
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      DELETE FROM #PickDetail_WIP
      WHERE CaseID <> '' AND WaveKey = @c_Wavekey

      DELETE FROM #PickDetail_WIP
      WHERE TaskDetailKey <> '' AND WaveKey = @c_Wavekey
   END

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SET @dt_StartTime = GETDATE()

      IF  EXISTS (  SELECT 1
                    FROM #PickDetail_WIP PD (NOLOCK)
                    WHERE PD.WaveKey = @c_Wavekey
                    AND   (PD.UOM = '2' AND PD.PickMethod = 'C')
                    AND   ISNULL(PD.TaskDetailKey, '') = ''
                    AND   ISNULL(PD.CaseID, '') = ''
                    UNION ALL
                    SELECT 1
                    FROM #PickDetail_WIP PD (NOLOCK)
                    JOIN LOC L (NOLOCK) ON L.Loc = PD.Loc
                    WHERE PD.WaveKey = @c_Wavekey
                    AND   PD.UOM = '6'
                    AND   ISNULL(PD.TaskDetailKey, '') = ''
                    AND   ISNULL(PD.CaseID, '') = ''
                    AND   L.LocationRoom = 'HIGHBAY')
      BEGIN
         -----Generate DPP Temporary Ref Data-----  
         IF (@n_Continue = 1 OR @n_Continue = 2)
         BEGIN
            INSERT INTO #DYNLOC (Loc, logicallocation, Putawayzone, LocScore, LocationRoom, Pickzone)
            SELECT Loc
                 , LogicalLocation
                 , PutawayZone
                 , Score
                 , LocationRoom
                 , PickZone
            FROM LOC (NOLOCK)
            WHERE Facility = @c_Facility AND LocationType = 'DYNPPICK'

            --location have pending Replenishment tasks  
            INSERT INTO #DYNPICK_TASK (TOLOC, Putawayzone)
            SELECT L.Loc
                 , L.PutawayZone
            FROM TaskDetail TD (NOLOCK)
            JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
            WHERE L.Facility = @c_Facility AND TD.Status = '0' AND TD.TaskType IN ( 'RPF' )
            AND TD.Storerkey = @c_Storerkey
            GROUP BY L.Loc
                   , L.PutawayZone
            HAVING SUM(TD.Qty) > 0

            --Dynamic pick loc have qty and pending move in  
            INSERT INTO #DYNPICK_NON_EMPTY (LOC, Putawayzone)
            SELECT LLI.Loc
                 , L.PutawayZone
            FROM LOTxLOCxID LLI (NOLOCK)
            JOIN LOC L (NOLOCK) ON LLI.Loc = L.Loc
            WHERE L.Facility = @c_Facility
            AND LLI.StorerKey = @c_Storerkey
            GROUP BY LLI.Loc
                   , L.PickZone
                   , L.PutawayZone
            HAVING SUM(LLI.Qty + LLI.PendingMoveIN - LLI.QtyPicked) > 0   --WL05

            INSERT INTO #EXCLUDELOC (LOC, Putawayzone)
            SELECT E.LOC
                 , E.Putawayzone
            FROM #DYNPICK_NON_EMPTY E
            UNION ALL
            SELECT ReplenLoc.TOLOC
                 , ReplenLoc.Putawayzone
            FROM #DYNPICK_TASK ReplenLoc
         END

         -----Generate SAFETYSTOCK Temporary Ref Data-----  
         IF (@n_Continue = 1 OR @n_Continue = 2)
         BEGIN
            INSERT INTO #SAFETYSTOCK_LOC (Loc, logicallocation, Pickzone, Putawayzone, LocationRoom, LocScore)
            SELECT Loc
                 , LogicalLocation
                 , PickZone
                 , PutawayZone
                 , LocationRoom
                 , Score
            FROM LOC (NOLOCK)
            WHERE Facility = @c_Facility
            AND   LocationRoom IN ( 'SAFETYSTOCK' )
            AND   LocationType NOT IN ( 'DYNPPICK' )

            --location have pending Replenishment tasks  
            INSERT INTO #SAFETYSTOCK_TASK (TOLOC, Pickzone, Putawayzone)
            SELECT L.Loc
                 , L.PickZone
                 , L.PutawayZone
            FROM TaskDetail TD (NOLOCK)
            JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
            WHERE L.LocationRoom IN ( 'SAFETYSTOCK' )
            AND   L.Facility = @c_Facility
            AND   TD.Status = '0'
            AND   TD.TaskType IN ( 'RPF' )
            AND   TD.Storerkey = @c_Storerkey
            AND   L.LocationType NOT IN ('DYNPPICK')   
            GROUP BY L.Loc
                   , L.PickZone
                   , L.PutawayZone
            HAVING SUM(TD.Qty) > 0

            --ST Loc have qty and pending move in  
            INSERT INTO #SAFETYSTOCK_NON_EMPTY (LOC, Pickzone, Putawayzone)
            SELECT LLI.Loc
                 , L.PickZone
                 , L.PutawayZone
            FROM LOTxLOCxID LLI (NOLOCK)
            JOIN LOC L (NOLOCK) ON LLI.Loc = L.Loc
            WHERE L.LocationRoom IN ( 'SAFETYSTOCK' ) 
            AND   L.Facility = @c_Facility
            AND   LLI.StorerKey = @c_Storerkey
            AND    L.LocationType NOT IN ('DYNPPICK') 
            GROUP BY LLI.Loc
                   , L.PickZone
                   , L.PutawayZone
            HAVING SUM(LLI.Qty + LLI.PendingMoveIN - LLI.QtyPicked) > 0   --WL05

            INSERT INTO #SAFETYSTOCK_EXCLUDELOC (LOC, Pickzone, Putawayzone)
            SELECT E.LOC
                 , E.Pickzone
                 , E.Putawayzone
            FROM #SAFETYSTOCK_NON_EMPTY E
            UNION ALL
            SELECT ReplenLoc.TOLOC
                 , ReplenLoc.Pickzone
                 , ReplenLoc.Putawayzone
            FROM #SAFETYSTOCK_TASK ReplenLoc
         END
      END

      SET @dt_EndTime = GETDATE()

      IF @b_Debug = 2
      BEGIN
         INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1)  
         VALUES ( 'ispRLWAV50_1_TMP', @dt_StartTime, @dt_EndTime  
                , CONVERT(CHAR(12),@dt_EndTime - @dt_StartTime ,114)  
                , @c_Wavekey)  
      END
   END

   SET @dt_StartTime = GETDATE()

   --Create RPF Task
   --Pickdetail.UOM = 2 AND Pickmethod <> C
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      --IF @@TRANCOUNT = 0
      --   BEGIN TRAN

      --WL01 S
      SELECT TOP 1 @c_ToLoc = LOC.Loc
      FROM LOC (NOLOCK)
      WHERE LOC.LocationRoom = 'PACKSTATION' 
      AND LOC.LocationFlag = 'NONE'
      AND LOC.Facility = @c_Facility
      GROUP BY LOC.Loc

      IF ISNULL(@c_ToLoc, '') = ''
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 87010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': ' + ' PACKSTATION not found for Facility: '
                            + @c_Facility + '. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg)
                            + ' ) '
         GOTO RETURN_SP
      END
      --WL01 E

      DECLARE CUR_NEWRPF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PDW.Storerkey
           , PDW.Lot
           , PDW.Loc
           , PDW.DropID
           , PDW.Sku
           , SUM(PDW.Qty)
           , CASE WHEN TC.[Site] = 'ONSITE' THEN 1 ELSE 2 END AS SiteSeq
           , PDW.ID
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN #PickDetail_WIP PDW (NOLOCK) ON PDW.OrderKey = WD.OrderKey
      JOIN LOC L (NOLOCK) ON L.Loc = PDW.Loc
      JOIN SKU S (NOLOCK) ON S.Sku = PDW.Sku AND S.StorerKey = PDW.Storerkey
      JOIN #TMP_CODELKUP TC ON TC.Pickzone = L.PickZone AND TC.SKUGroup = S.SKUGROUP 
      WHERE WD.WaveKey = @c_Wavekey
      AND   PDW.UOM = '2'
      AND   PDW.PickMethod <> 'C'
      GROUP BY PDW.Storerkey
             , PDW.Lot
             , PDW.Loc
             , PDW.DropID
             , PDW.Sku
             , TC.[Site]
             , PDW.ID
      ORDER BY SiteSeq
             , ID
             , DropID
             , PDW.Sku

      OPEN CUR_NEWRPF
      FETCH NEXT FROM CUR_NEWRPF
      INTO @c_Storerkey
         , @c_Lot
         , @c_FromLoc
         , @c_DropID
         , @c_SKU
         , @n_Qty
         , @c_Site
         , @c_ID

      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 )
      BEGIN
         --SET @c_ToLoc = N''   --WL02
         SET @c_TaskType = N'RPF'
         SET @c_Areakey = N''
         SET @c_Message01 = N'0'
         SET @n_AvailableQty = 0
         SET @n_Casecnt = 0
         SET @c_Pickmethod = 'PP'

         --Full Case Area, 1 Loc 1 UCC, ID is blank
         IF @c_ID = ''
         BEGIN
            SET @c_Pickmethod = 'PP'
         END
         --WL03 S
         ELSE IF EXISTS ( SELECT 1
                          FROM @T_ID TI
                          WHERE TI.Storerkey = @c_Storerkey AND TI.Id = @c_ID)
         BEGIN
            SELECT @c_Pickmethod = TI.Pickmethod 
            FROM @T_ID TI
            WHERE TI.Storerkey = @c_Storerkey AND TI.Id = @c_ID
         END
         ELSE IF EXISTS (  SELECT 1 
                           FROM LotxLocxID LLI (NOLOCK)
                           JOIN UCC U (NOLOCK) ON U.Lot = LLI.Lot AND U.Loc = LLI.Loc  AND U.ID = LLI.ID 
                           WHERE LLI.Storerkey = @c_Storerkey AND LLI.Id = @c_ID
                           HAVING COUNT(DISTINCT U.SKU) = 1 AND COUNT(DISTINCT U.qty) = 1 ) --1 ID 1 SKU, 1 ID 1 Qty
         BEGIN
         --WL03 E
            --SELECT @n_AvailableQty = SUM(PDW.Qty)
            --FROM PICKDETAIL PDW (NOLOCK)
            --WHERE PDW.Storerkey = @c_Storerkey
            --AND PDW.UOM = '2' AND PDW.Pickmethod <> 'C'
            --AND PDW.ID = @c_ID

            SELECT @n_AvailableQty = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)
            FROM LOTxLOCxID LLI (NOLOCK)
            WHERE LLI.Storerkey = @c_Storerkey
            AND LLI.ID = @c_ID

            --Available qty > 0, not fully allocated
            --WL01 S
            IF @n_AvailableQty > 0
            BEGIN
               SET @c_Pickmethod = 'PP'
            END
            ELSE
            BEGIN
               IF EXISTS (SELECT 1
                          FROM #PickDetail_WIP PDW (NOLOCK)
                          WHERE PDW.WaveKey = @c_Wavekey
                          AND PDW.UOM = '2'
                          AND PDW.ID = @c_ID
                          HAVING COUNT(DISTINCT PDW.Pickmethod) > 1)
               BEGIN
                  SET @c_Pickmethod = 'PP'
               END
               ELSE IF EXISTS (SELECT 1   --WL05 S
                               FROM PICKDETAIL PD (NOLOCK)
                               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey
                               WHERE PD.Storerkey = @c_Storerkey
                               AND PD.ID = @c_ID
                               HAVING COUNT(DISTINCT OH.UserDefine09) > 1)   --Multi Wave allocate same ID
               BEGIN
                  SET @c_Pickmethod = 'PP'
               END   --WL05 E
               ELSE
               BEGIN
                  SET @c_Pickmethod = 'FP'
               END
            END
            --WL01 E

            --SELECT @n_Casecnt = SUM(U.Qty)
            --FROM UCC U (NOLOCK)
            --WHERE U.Storerkey = @c_Storerkey
            --AND U.Id = @c_ID

            --IF @n_AvailableQty = @n_Casecnt
            --BEGIN
            --   SET @c_Pickmethod = 'FP'
            --END
            --ELSE
            --BEGIN
            --   SET @c_Pickmethod = 'PP'
            --END

            --WL03 S
            IF NOT EXISTS (SELECT 1 FROM @T_ID TI WHERE Storerkey = @c_Storerkey AND ID = @c_ID)
            BEGIN
               INSERT INTO @T_ID (Storerkey, ID, Pickmethod)
               SELECT @c_Storerkey, @c_ID, @c_Pickmethod
            END
            --WL03 E
         END

         --WL01 S
         --SELECT @c_ToLoc = LOC.Loc
         --FROM LOC (NOLOCK)
         --WHERE LOC.LocationRoom = 'PACKSTATION' AND LOC.Facility = @c_Facility
         
         --IF ISNULL(@c_ToLoc, '') = ''
         --BEGIN
         --   SELECT @n_Continue = 3
         --   SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
         --        , @n_err = 87010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         --   SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': ' + ' PACKSTATION not found for Facility: '
         --                      + @c_Facility + '. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg)
         --                      + ' ) '
         --   GOTO RETURN_SP
         --END
         --WL01 E

         --function to insert taskdetail  
         SELECT @b_Success = 1
         EXECUTE nspg_GetKey 'TaskDetailKey'
                           , 10
                           , @c_TaskDetailKey OUTPUT
                           , @b_Success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF NOT @b_Success = 1
         BEGIN
            SELECT @n_Continue = 3
         END

         SELECT @c_Areakey = AD.AreaKey
         FROM LOC L (NOLOCK)
         JOIN AreaDetail AD (NOLOCK) ON AD.PutawayZone = L.PutawayZone
         WHERE L.Loc = @c_Loc

         IF @b_Success = 1
         BEGIN
            INSERT TaskDetail (TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot, FromLoc
                             , FromID, ToLoc, ToID, SourceType, SourceKey, Priority, SourcePriority, Status
                             , LogicalFromLoc, LogicalToLoc, PickMethod, WaveKey, AreaKey, QtyReplen, PendingMoveIn
                             , Message01, Caseid)
            VALUES (@c_TaskDetailKey, @c_TaskType --Tasktype    
                  , @c_Storerkey, @c_SKU, '2' -- UOM   
                  , @n_Qty --UOMQty
                  , @n_Qty --Qty   
                  , @n_Qty --systemqty  
                  , @c_Lot, @c_FromLoc, @c_ID -- from id    
                  , @c_ToLoc, @c_ID -- to id    
                  , @c_SourceType --Sourcetype    
                  , @c_Wavekey --Sourcekey    
                  , '9' -- Priority    
                  , '9' -- Sourcepriority    
                  , '0' -- Status    
                  , @c_FromLoc --Logical from loc    
                  , @c_ToLoc --Logical to loc    
                  , @c_Pickmethod, @c_Wavekey, @c_Areakey, 0, @n_Qty, @c_Message01
                  , @c_DropID)

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 87015 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + ': Insert Taskdetail Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_errmsg) + ' ) '
               GOTO NEXT_LOOP_NEWRPF
            END
         END

         --Update taskdetailkey to pickdetail  
         IF @n_Continue = 1 OR @n_Continue = 2
         BEGIN
            SELECT @c_Pickdetailkey = N''
                 , @n_ReplenQty = @n_Qty
            WHILE @n_ReplenQty > 0
            BEGIN
               SELECT TOP 1 @c_Pickdetailkey = PICKDETAIL.PickDetailKey
                          , @n_pickqty = Qty
               FROM WAVEDETAIL (NOLOCK)
               JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey
               WHERE WAVEDETAIL.WaveKey = @c_Wavekey
               AND   ISNULL(PICKDETAIL.TaskDetailKey, '') = ''
               AND   PICKDETAIL.Storerkey = @c_Storerkey
               AND   PICKDETAIL.Sku = @c_SKU
               AND   PICKDETAIL.Lot = @c_Lot
               AND   PICKDETAIL.Loc = @c_FromLoc
               AND   PICKDETAIL.ID = @c_ID
               AND   PICKDETAIL.DropID = @c_DropID
               AND   (PICKDETAIL.UOM = '2' AND PICKDETAIL.PickMethod <> 'C')
               AND   PICKDETAIL.PickDetailKey > @c_Pickdetailkey
               ORDER BY PICKDETAIL.PickDetailKey

               SELECT @n_cnt = @@ROWCOUNT

               IF @n_cnt = 0
                  BREAK

               IF @n_pickqty <= @n_ReplenQty
               BEGIN
                  UPDATE #PickDetail_WIP WITH (ROWLOCK)
                  SET TaskDetailKey = @c_TaskDetailKey
                    , TrafficCop = NULL
                  WHERE PickDetailKey = @c_Pickdetailkey

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 87020
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Update Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                        + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     BREAK
                  END
                  SELECT @n_ReplenQty = @n_ReplenQty - @n_pickqty
               END
               ELSE
               BEGIN -- pickqty > replenqty     
                  SELECT @n_splitqty = @n_pickqty - @n_ReplenQty
                  EXECUTE nspg_GetKey 'PICKDETAILKEY'
                                    , 10
                                    , @c_NewPickdetailkey OUTPUT
                                    , @b_Success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

                  IF NOT @b_Success = 1
                  BEGIN
                     SELECT @n_Continue = 3
                     BREAK
                  END

                  INSERT #PickDetail_WIP (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot
                                        , Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID
                                        , PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish
                                        , ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, OptimizeCop
                                        , ShipFlag, PickSlipNo, WIP_Refno)
                  SELECT @c_NewPickdetailkey
                       , CaseID
                       , PickHeaderKey
                       , OrderKey
                       , OrderLineNumber
                       , Lot
                       , Storerkey
                       , Sku
                       , AltSku
                       , UOM
                       , CASE WHEN UOM IN ( '6', '7' ) THEN @n_splitqty
                              ELSE 1 END
                       , @n_splitqty
                       , QtyMoved
                       , Status
                       , DropID
                       , Loc
                       , ID
                       , PackKey
                       , UpdateSource
                       , CartonGroup
                       , CartonType
                       , ToLoc
                       , DoReplenish
                       , ReplenishZone
                       , DoCartonize
                       , PickMethod
                       , WaveKey
                       , EffectiveDate
                       , '9'
                       , ShipFlag
                       , PickSlipNo
                       , @c_SourceType
                  FROM #PickDetail_WIP PDW (NOLOCK)
                  WHERE PickDetailKey = @c_Pickdetailkey

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 87025
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Insert Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                        + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     BREAK
                  END

                  UPDATE #PickDetail_WIP WITH (ROWLOCK)
                  SET TaskDetailKey = @c_TaskDetailKey
                    , Qty = @n_ReplenQty
                    , UOMQty = CASE WHEN UOM IN ( '6', '7' ) THEN @n_ReplenQty
                                    ELSE 1 END
                    , TrafficCop = NULL
                  WHERE PickDetailKey = @c_Pickdetailkey
                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 87030
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Update Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                        + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     BREAK
                  END
                  SELECT @n_ReplenQty = 0
               END
            END -- While Qty > 0  
         END

         NEXT_LOOP_NEWRPF:
         FETCH NEXT FROM CUR_NEWRPF
         INTO @c_Storerkey
            , @c_Lot
            , @c_FromLoc
            , @c_DropID
            , @c_SKU
            , @n_Qty
            , @c_Site
            , @c_ID
      END
      CLOSE CUR_NEWRPF
      DEALLOCATE CUR_NEWRPF

   --WHILE @@TRANCOUNT > 0
   --BEGIN
   --   COMMIT TRAN
   --END
   END

   SET @dt_EndTime = GETDATE()

   IF @b_Debug = 2
   BEGIN
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1)  
      VALUES ( 'ispRLWAV50_2_!C2', @dt_StartTime, @dt_EndTime  
             , CONVERT(CHAR(12),@dt_EndTime - @dt_StartTime ,114)  
             , @c_Wavekey)  
   END

   SET @dt_StartTime = GETDATE()

   --Pickdetail.UOM = 2 AND Pickmethod = C
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      --IF @@TRANCOUNT = 0
      --   BEGIN TRAN

      DECLARE CUR_NEWRPF2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PDW.Storerkey
           , PDW.Lot
           , PDW.Loc
           , PDW.ID
           , PDW.Sku
           , SUM(PDW.Qty)
           , CASE WHEN TC.[Site] = 'ONSITE' THEN 1 ELSE 2 END AS SiteSeq
           , S.SKUGROUP
           , PDW.DropID
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN #PickDetail_WIP PDW (NOLOCK) ON PDW.OrderKey = WD.OrderKey
      JOIN LOC L (NOLOCK) ON L.Loc = PDW.Loc
      JOIN SKU S (NOLOCK) ON S.Sku = PDW.Sku AND S.StorerKey = PDW.Storerkey
      JOIN #TMP_CODELKUP TC ON TC.Pickzone = L.PickZone AND TC.SKUGroup = S.SKUGROUP 
      WHERE WD.WaveKey = @c_Wavekey
      AND   PDW.UOM = '2'
      AND   PDW.PickMethod = 'C'
      GROUP BY PDW.Storerkey
             , PDW.Lot
             , PDW.Loc
             , PDW.ID
             , PDW.Sku
             , S.SKUGROUP
             , TC.[Site]
             , PDW.DropID
      ORDER BY SiteSeq
             , ID
             , DropID
             , PDW.Sku
             , S.SKUGROUP

      OPEN CUR_NEWRPF2
      FETCH NEXT FROM CUR_NEWRPF2
      INTO @c_Storerkey
         , @c_Lot
         , @c_FromLoc
         , @c_ID
         , @c_SKU
         , @n_Qty
         , @c_Site
         , @c_SKUGroup
         , @c_DropID

      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 )
      BEGIN
         SET @c_ToLoc = N''
         SET @c_TaskType = N'RPF'
         SET @c_Areakey = N''
         SET @c_FinalLoc = N''
         SET @c_Pickmethod = N'PP'
         SET @n_AvailableQty = 0
         SET @n_Casecnt = 0

         --WL03 S
         --Full Case Area, 1 Loc 1 UCC, ID is blank
         IF @c_ID = ''
         BEGIN
            SET @c_Pickmethod = 'PP'
         END
         ELSE IF EXISTS ( SELECT 1
                          FROM @T_ID TI
                          WHERE TI.Storerkey = @c_Storerkey AND TI.Id = @c_ID)
         BEGIN
            SELECT @c_Pickmethod = TI.Pickmethod 
            FROM @T_ID TI
            WHERE TI.Storerkey = @c_Storerkey AND TI.Id = @c_ID
         END
         ELSE IF EXISTS (  SELECT 1 
                           FROM LotxLocxID LLI (NOLOCK)
                           JOIN UCC U (NOLOCK) ON U.Lot = LLI.Lot AND U.Loc = LLI.Loc  AND U.ID = LLI.ID 
                           WHERE LLI.Storerkey = @c_Storerkey AND LLI.Id = @c_ID
                           HAVING COUNT(DISTINCT U.SKU) = 1 AND COUNT(DISTINCT U.qty) = 1) --1 ID 1 SKU, 1 ID 1 Qty
         BEGIN
         --WL03 E
            --SELECT @n_AvailableQty = SUM(PDW.Qty)
            --FROM PICKDETAIL PDW (NOLOCK)
            --WHERE PDW.Storerkey = @c_Storerkey
            --AND PDW.UOM = '2' AND PDW.Pickmethod = 'C'
            --AND PDW.ID = @c_ID

            SELECT @n_AvailableQty = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)
            FROM LOTxLOCxID LLI (NOLOCK)
            WHERE LLI.Storerkey = @c_Storerkey
            AND LLI.ID = @c_ID

            --Available qty > 0, not fully allocated
            --WL01 S
            IF @n_AvailableQty > 0
            BEGIN
               SET @c_Pickmethod = 'PP'
            END
            ELSE
            BEGIN
               IF EXISTS (SELECT 1
                          FROM #PickDetail_WIP PDW (NOLOCK)
                          WHERE PDW.WaveKey = @c_Wavekey
                          AND PDW.UOM = '2'
                          AND PDW.ID = @c_ID
                          HAVING COUNT(DISTINCT PDW.Pickmethod) > 1)
               BEGIN
                  SET @c_Pickmethod = 'PP'
               END
               ELSE IF EXISTS (SELECT 1   --WL05 S
                               FROM PICKDETAIL PD (NOLOCK)
                               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey
                               WHERE PD.Storerkey = @c_Storerkey
                               AND PD.ID = @c_ID
                               HAVING COUNT(DISTINCT OH.UserDefine09) > 1)   --Multi Wave allocate same ID
               BEGIN
                  SET @c_Pickmethod = 'PP'
               END   --WL05 E
               ELSE
               BEGIN
                  SET @c_Pickmethod = 'FP'
               END
            END
            --WL01 E

            --SELECT @n_Casecnt = SUM(U.Qty)
            --FROM UCC U (NOLOCK)
            --WHERE U.Storerkey = @c_Storerkey
            --AND U.Id = @c_ID

            --IF @n_AvailableQty = @n_Casecnt
            --BEGIN
            --   SET @c_Pickmethod = 'FP'
            --END
            --ELSE
            --BEGIN
            --   SET @c_Pickmethod = 'PP'
            --END

            --WL03 S
            IF NOT EXISTS (SELECT 1 FROM @T_ID TI WHERE Storerkey = @c_Storerkey AND ID = @c_ID)
            BEGIN
               INSERT INTO @T_ID (Storerkey, ID, Pickmethod)
               SELECT @c_Storerkey, @c_ID, @c_Pickmethod
            END
            --WL03 E

         END

         IF @n_Continue IN ( 1, 2 )
         BEGIN
            SELECT TOP 1 @c_ToLoc = L.Loc
            FROM #DYNLOC L (NOLOCK)
            LEFT JOIN #EXCLUDELOC EL ON L.Loc = EL.LOC
            LEFT JOIN #DYNPICK_LOCASSIGNED DynPick ON L.Loc = DynPick.TOLOC
            WHERE EL.LOC IS NULL AND DynPick.TOLOC IS NULL --AND L.Putawayzone = @c_SKUGroup
            GROUP BY L.LocScore
                   , L.logicallocation
                   , L.Loc
            ORDER BY L.LocScore
                   , L.logicallocation
                   , L.Loc

            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 87200 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': '
                                  + ' DPP not found for SKU: ' + @c_SKU
                                  + '. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END

            --Insert current location assigned  
            IF NOT EXISTS (  SELECT 1
                             FROM #DYNPICK_LOCASSIGNED DL
                             WHERE STORERKEY = @c_Storerkey AND SKU = @c_SKU AND TOLOC = @c_ToLoc)
            BEGIN
               INSERT INTO #DYNPICK_LOCASSIGNED (STORERKEY, SKU, TOLOC, LocationType)
               VALUES (@c_Storerkey, @c_SKU, @c_ToLoc, 'DPP')
            END

            --SET @c_FinalLoc = @c_ToLoc
            --SET @c_ToLoc = ''
            
            --SELECT @c_ToLoc = ISNULL(PZ.InLoc, '')
            --FROM LOC L (NOLOCK)
            --JOIN Pickzone PZ (NOLOCK) ON PZ.Pickzone = L.Pickzone
            --WHERE L.Loc = @c_FinalLoc

            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 87040 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': '
                                  + ' ToLoc not found for SKU ' + @c_SKU
                                  + '. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END

            SET @c_Message01 = N'1'
         END

         --function to insert taskdetail  
         SELECT @b_Success = 1
         EXECUTE nspg_GetKey 'TaskDetailKey'
                           , 10
                           , @c_TaskDetailKey OUTPUT
                           , @b_Success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF NOT @b_Success = 1
         BEGIN
            SELECT @n_Continue = 3
         END

         SELECT @c_Areakey = AD.AreaKey
         FROM LOC L (NOLOCK)
         JOIN AreaDetail AD (NOLOCK) ON AD.PutawayZone = L.PutawayZone
         WHERE L.Loc = @c_ToLoc

         IF @b_Success = 1
         BEGIN
            INSERT TaskDetail (TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot, FromLoc
                             , FromID, ToLoc, ToID, SourceType, SourceKey, Priority, SourcePriority, Status
                             , LogicalFromLoc, LogicalToLoc, PickMethod, WaveKey, AreaKey, QtyReplen, PendingMoveIn
                             , Message01, Caseid, FinalLOC)
            VALUES (@c_TaskDetailKey, @c_TaskType --Tasktype    
                  , @c_Storerkey, @c_SKU, '2' -- UOM   
                  , @n_Qty --UOMQty
                  , @n_Qty --Qty   
                  , @n_Qty --systemqty  
                  , @c_Lot, @c_FromLoc, @c_ID -- from id    
                  , @c_ToLoc, @c_ID -- to id    
                  , @c_SourceType --Sourcetype    
                  , @c_Wavekey --Sourcekey    
                  , '9' -- Priority    
                  , '9' -- Sourcepriority    
                  , '0' -- Status    
                  , @c_FromLoc --Logical from loc    
                  , @c_ToLoc --Logical to loc    
                  , @c_Pickmethod, @c_Wavekey, @c_Areakey, 0, @n_Qty, @c_Message01
                  , @c_DropID, '')

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 87045 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + ': Insert Taskdetail Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_errmsg) + ' ) '
               GOTO NEXT_LOOP_NEWRPF
            END
         END

         --Update taskdetailkey to pickdetail  
         IF @n_Continue = 1 OR @n_Continue = 2
         BEGIN
            SELECT @c_Pickdetailkey = N''
                 , @n_ReplenQty = @n_Qty
            WHILE @n_ReplenQty > 0
            BEGIN
               SELECT TOP 1 @c_Pickdetailkey = PICKDETAIL.PickDetailKey
                          , @n_pickqty = Qty
               FROM WAVEDETAIL (NOLOCK)
               JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey
               WHERE WAVEDETAIL.WaveKey = @c_Wavekey
               AND   ISNULL(PICKDETAIL.TaskDetailKey, '') = ''
               AND   PICKDETAIL.Storerkey = @c_Storerkey
               AND   PICKDETAIL.Sku = @c_SKU
               AND   PICKDETAIL.Lot = @c_Lot
               AND   PICKDETAIL.Loc = @c_FromLoc
               AND   PICKDETAIL.ID = @c_ID
               AND   PICKDETAIL.DropID = @c_DropID
               AND   (PICKDETAIL.UOM = '2' AND PICKDETAIL.PickMethod = 'C')
               AND   PICKDETAIL.PickDetailKey > @c_Pickdetailkey
               ORDER BY PICKDETAIL.PickDetailKey

               SELECT @n_cnt = @@ROWCOUNT

               IF @n_cnt = 0
                  BREAK

               IF @n_pickqty <= @n_ReplenQty
               BEGIN
                  UPDATE #PickDetail_WIP WITH (ROWLOCK)
                  SET TaskDetailKey = @c_TaskDetailKey
                    , TrafficCop = NULL
                  WHERE PickDetailKey = @c_Pickdetailkey

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 87050
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Update Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                        + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     BREAK
                  END
                  SELECT @n_ReplenQty = @n_ReplenQty - @n_pickqty
               END
               ELSE
               BEGIN -- pickqty > replenqty     
                  SELECT @n_splitqty = @n_pickqty - @n_ReplenQty
                  EXECUTE nspg_GetKey 'PICKDETAILKEY'
                                    , 10
                                    , @c_NewPickdetailkey OUTPUT
                                    , @b_Success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

                  IF NOT @b_Success = 1
                  BEGIN
                     SELECT @n_Continue = 3
                     BREAK
                  END

                  INSERT #PickDetail_WIP (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot
                                        , Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID
                                        , PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish
                                        , ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, OptimizeCop
                                        , ShipFlag, PickSlipNo, WIP_Refno)
                  SELECT @c_NewPickdetailkey
                       , CaseID
                       , PickHeaderKey
                       , OrderKey
                       , OrderLineNumber
                       , Lot
                       , Storerkey
                       , Sku
                       , AltSku
                       , UOM
                       , CASE WHEN UOM IN ( '6', '7' ) THEN @n_splitqty
                              ELSE 1 END
                       , @n_splitqty
                       , QtyMoved
                       , Status
                       , DropID
                       , Loc
                       , ID
                       , PackKey
                       , UpdateSource
                       , CartonGroup
                       , CartonType
                       , ToLoc
                       , DoReplenish
                       , ReplenishZone
                       , DoCartonize
                       , PickMethod
                       , WaveKey
                       , EffectiveDate
                       , '9'
                       , ShipFlag
                       , PickSlipNo
                       , @c_SourceType
                  FROM #PickDetail_WIP PDW (NOLOCK)
                  WHERE PickDetailKey = @c_Pickdetailkey

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 87055
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Insert Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                        + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     BREAK
                  END

                  UPDATE #PickDetail_WIP WITH (ROWLOCK)
                  SET TaskDetailKey = @c_TaskDetailKey
                    , Qty = @n_ReplenQty
                    , UOMQty = CASE WHEN UOM IN ( '6', '7' ) THEN @n_ReplenQty
                                    ELSE 1 END
                    , TrafficCop = NULL
                  WHERE PickDetailKey = @c_Pickdetailkey
                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 87060
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Update Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                        + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     BREAK
                  END
                  SELECT @n_ReplenQty = 0
               END
            END -- While Qty > 0  
         END

         NEXT_LOOP_NEWRPF2:
         FETCH NEXT FROM CUR_NEWRPF2
         INTO @c_Storerkey
            , @c_Lot
            , @c_FromLoc
            , @c_ID
            , @c_SKU
            , @n_Qty
            , @c_Site
            , @c_SKUGroup
            , @c_DropID
      END
      CLOSE CUR_NEWRPF2
      DEALLOCATE CUR_NEWRPF2

   --WHILE @@TRANCOUNT > 0
   --BEGIN
   --   COMMIT TRAN
   --END
   END

   SET @dt_EndTime = GETDATE()

   IF @b_Debug = 2
   BEGIN
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1)  
      VALUES ( 'ispRLWAV50_3_C2', @dt_StartTime, @dt_EndTime  
             , CONVERT(CHAR(12),@dt_EndTime - @dt_StartTime ,114)  
             , @c_Wavekey)  
   END

   SET @dt_StartTime = GETDATE()

   --Pickdetail.UOM = 6 AND LocationRoom = HIGHBAY
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      --IF @@TRANCOUNT = 0
      --   BEGIN TRAN

      DECLARE CUR_NEWRPF3 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PDW.Storerkey
           , PDW.Lot
           , PDW.Loc
           , PDW.ID
           , PDW.Sku
           , SUM(PDW.Qty)
           , MAX(UCC.Qty)
           , CASE WHEN TC.[Site] = 'ONSITE' THEN 1 ELSE 2 END AS SiteSeq
           , S.SKUGROUP
           , S.itemclass
           , PDW.DropID
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN #PickDetail_WIP PDW (NOLOCK) ON PDW.OrderKey = WD.OrderKey
      JOIN UCC (NOLOCK) ON UCC.Storerkey = PDW.Storerkey AND UCC.UCCNo = PDW.DropID
      JOIN LOC L (NOLOCK) ON L.Loc = PDW.Loc
      JOIN SKU S (NOLOCK) ON S.Sku = PDW.Sku AND S.StorerKey = PDW.Storerkey
      JOIN #TMP_CODELKUP TC ON TC.Pickzone = L.PickZone AND TC.SKUGroup = S.SKUGROUP 
      WHERE WD.WaveKey = @c_Wavekey AND PDW.UOM = '6' AND L.LocationRoom = 'HIGHBAY'
      GROUP BY PDW.Storerkey
             , PDW.Lot
             , PDW.Loc
             , PDW.ID
             , PDW.DropID
             , PDW.Sku
             , S.SKUGROUP
             , S.itemclass
             , TC.[Site]
      ORDER BY SiteSeq
             , PDW.ID
             , PDW.DropID
             , PDW.Sku
             , S.SKUGROUP

      OPEN CUR_NEWRPF3
      FETCH NEXT FROM CUR_NEWRPF3
      INTO @c_Storerkey
         , @c_Lot
         , @c_FromLoc
         , @c_ID
         , @c_SKU
         , @n_Qty
         , @n_UCCQty
         , @c_Site
         , @c_SKUGroup
         , @c_ItemClass
         , @c_DropID

      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 )
      BEGIN
         SET @c_ToLoc = N''
         SET @c_TaskType = N'RPF'
         SET @c_Areakey = N''
         SET @c_FinalLoc = N''
         SET @c_Message01 = N'1'
         SET @c_ProcessType = ''
         
         IF @n_Qty < @n_UCCQty
         BEGIN
            SET @c_ProcessType = 'ST'
         END
         ELSE
         BEGIN
            SET @c_ProcessType = 'DPP'
         END

         IF @c_ProcessType = 'DPP' --Assign DPP Loc
         BEGIN
            SELECT TOP 1 @c_ToLoc = L.Loc
            FROM #DYNLOC L (NOLOCK)
            LEFT JOIN #EXCLUDELOC EL ON L.Loc = EL.LOC
            LEFT JOIN #DYNPICK_LOCASSIGNED DynPick ON L.Loc = DynPick.TOLOC
            WHERE EL.LOC IS NULL AND DynPick.TOLOC IS NULL --AND L.Putawayzone = @c_SKUGroup
            GROUP BY L.LocScore
                   , L.logicallocation
                   , L.Loc
            ORDER BY L.LocScore
                   , L.logicallocation
                   , L.Loc

            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 87201 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': '
                                  + ' DPP not found for SKU: ' + @c_SKU
                                  + '. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END

            --Insert current location assigned  
            IF NOT EXISTS (  SELECT 1
                             FROM #DYNPICK_LOCASSIGNED DL
                             WHERE STORERKEY = @c_Storerkey AND SKU = @c_SKU AND TOLOC = @c_ToLoc)
            BEGIN
               INSERT INTO #DYNPICK_LOCASSIGNED (STORERKEY, SKU, TOLOC, LocationType)
               VALUES (@c_Storerkey, @c_SKU, @c_ToLoc, 'DPP')
            END

            --SET @c_FinalLoc = @c_ToLoc
            --SET @c_ToLoc = ''

            --SELECT @c_ToLoc = ISNULL(PZ.InLoc, '')
            --FROM LOC L (NOLOCK)
            --JOIN Pickzone PZ (NOLOCK) ON PZ.Pickzone = L.Pickzone
            --WHERE L.Loc = @c_FinalLoc

            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 87065 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': '
                                  + ' ToLoc not found for SKU ' + @c_SKU
                                  + '. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END
         END
         ELSE --Assign Safetystock Loc
         BEGIN
            --If having stock with same SKU.Itemclass same SKU.SKUGroup, take next empty Loc
            --If having stock with max empty Loc in Pickzone, same SKU.SKUGroup, take next empty Loc
            --Take next empty loc which having max empty Loc in Pickzone

            PRINT 'Get Safetystock Loc - START'

            --If having stock with same SKU.Itemclass same SKU.SKUGroup, take next empty Loc - START
            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               --Get MIN(Loc) that have stock with same SKU.Itemclass
               ;WITH CTE AS
                (
                   SELECT TD.ToLoc
                        , L.Score
                        , L.LogicalLocation
                        , L.LocationRoom
                        , 2 AS SeqNo
                   FROM TaskDetail TD (NOLOCK)
                   JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
                   JOIN LOTxLOCxID LLI (NOLOCK) ON LLI.Loc = L.Loc
                   JOIN SKU S (NOLOCK) ON S.StorerKey = LLI.StorerKey AND S.Sku = LLI.Sku
                   WHERE L.Facility = @c_Facility
                   AND   LLI.StorerKey = @c_Storerkey
                   AND   S.itemclass = @c_ItemClass
                   AND   L.PutawayZone = @c_SKUGroup
                   AND   L.LocationRoom IN ( 'SAFETYSTOCK' )
                   AND   TD.Status = '0'
                   AND   TD.TaskType IN ( 'RPF' )
                   --AND   TD.Sku <> @c_SKU
                   GROUP BY TD.ToLoc
                          , L.Score
                          , L.LogicalLocation
                          , L.LocationRoom
                   UNION ALL
                   SELECT LLI.Loc AS ToLoc
                        , L.Score
                        , L.LogicalLocation
                        , L.LocationRoom
                        , 1 AS SeqNo
                   FROM LOTxLOCxID LLI (NOLOCK)
                   JOIN LOC L (NOLOCK) ON LLI.Loc = L.Loc
                   JOIN SKU S (NOLOCK) ON S.StorerKey = LLI.StorerKey AND S.Sku = LLI.Sku
                   WHERE L.Facility = @c_Facility
                   AND   LLI.StorerKey = @c_Storerkey
                   AND   S.itemclass = @c_ItemClass
                   AND   L.PutawayZone = @c_SKUGroup
                   AND   L.LocationRoom IN ( 'SAFETYSTOCK' )
                   --AND   S.Sku <> @c_SKU
                   AND   (LLI.Qty + LLI.PendingMoveIN) > 0
                   GROUP BY LLI.Loc
                          , L.Score
                          , L.LogicalLocation
                          , L.LocationRoom
                )
               SELECT TOP 1 @c_ToLoc = CTE.ToLoc
               FROM CTE
               GROUP BY CTE.SeqNo
                      , CTE.Score
                      , CTE.LogicalLocation
                      , CTE.ToLoc
               ORDER BY CTE.SeqNo
                      , CTE.Score
                      , CTE.LogicalLocation
                      , CTE.ToLoc
               
               --If able to get Loc, get next empty loc
               IF ISNULL(@c_ToLoc, '') <> ''
               BEGIN
                  SELECT @c_Pickzone = PickZone
                  FROM LOC (NOLOCK)
                  WHERE Loc = @c_ToLoc

                  SET @c_TempToLoc = ''
                  --Get Next Empty Loc
                  SELECT TOP 1 @c_TempToLoc = L.Loc
                  FROM #SAFETYSTOCK_LOC L (NOLOCK)
                  LEFT JOIN #SAFETYSTOCK_EXCLUDELOC EL ON L.Loc = EL.LOC
                  LEFT JOIN #SAFETYSTOCK_LOCASSIGNED SSPick ON L.Loc = SSPick.TOLOC
                  WHERE EL.LOC IS NULL
                  AND   SSPick.TOLOC IS NULL
                  AND   L.Loc > @c_ToLoc
                  AND   L.Putawayzone = @c_SKUGroup
                  AND   L.Pickzone = @c_Pickzone
                  AND   L.LocationRoom IN ( 'SAFETYSTOCK' )
                  GROUP BY L.LocScore
                         , L.logicallocation
                         , L.Loc
                  ORDER BY L.LocScore
                         , L.logicallocation
                         , L.Loc

                  SET @c_ToLoc = @c_TempToLoc

                  --If not able to get Next Empty Loc, find from starting
                  IF ISNULL(@c_ToLoc, '') = ''
                  BEGIN
                     SELECT TOP 1 @c_ToLoc = L.Loc
                     FROM #SAFETYSTOCK_LOC L (NOLOCK)
                     LEFT JOIN #SAFETYSTOCK_EXCLUDELOC EL ON L.Loc = EL.LOC
                     LEFT JOIN #SAFETYSTOCK_LOCASSIGNED SSPick ON L.Loc = SSPick.TOLOC
                     WHERE EL.LOC IS NULL
                     AND   SSPick.TOLOC IS NULL
                     AND   L.Putawayzone = @c_SKUGroup
                     AND   L.Pickzone = @c_Pickzone
                     AND   L.LocationRoom IN ( 'SAFETYSTOCK' )
                     ORDER BY L.LocScore
                            , L.logicallocation
                            , L.Loc
                  END
               END

               PRINT 'Get same SKU.Itemclass same SKU.SKUGroup Loc - ' + @c_ToLoc
            END
            --If having stock with same SKU.Itemclass same SKU.SKUGroup, take next empty Loc - END

            --If having stock with max empty Loc in Pickzone, same SKU.SKUGroup, take next empty Loc - START
            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SET @c_MaxEmptyLocPZ = N'';
               WITH CTE AS
               (
                  SELECT L.Pickzone
                       , COUNT(DISTINCT L.Loc) AS CountLoc
                  FROM #SAFETYSTOCK_LOC L (NOLOCK)
                  LEFT JOIN #SAFETYSTOCK_EXCLUDELOC EL ON L.Loc = EL.LOC
                  LEFT JOIN #SAFETYSTOCK_LOCASSIGNED SSPick ON L.Loc = SSPick.TOLOC
                  WHERE EL.LOC IS NULL
                  AND   SSPick.TOLOC IS NULL
                  AND   L.LocationRoom IN ( 'SAFETYSTOCK' )
                  AND   L.Putawayzone = @c_SKUGroup
                  GROUP BY L.Pickzone
               )
               SELECT TOP 1 @c_MaxEmptyLocPZ = CTE.Pickzone
               FROM CTE
               GROUP BY CTE.CountLoc, CTE.Pickzone
               ORDER BY CTE.CountLoc DESC

               SELECT TOP 1 @c_ToLoc = L.Loc
               FROM #SAFETYSTOCK_LOC L (NOLOCK)
               LEFT JOIN #SAFETYSTOCK_EXCLUDELOC EL ON L.Loc = EL.LOC
               LEFT JOIN #SAFETYSTOCK_LOCASSIGNED SSPick ON L.Loc = SSPick.TOLOC
               WHERE EL.LOC IS NULL
               AND   SSPick.TOLOC IS NULL
               AND   L.Pickzone = @c_MaxEmptyLocPZ
               AND   L.Putawayzone = @c_SKUGroup
               AND   L.LocationRoom IN ( 'SAFETYSTOCK' )
               GROUP BY L.LocScore
                      , L.logicallocation
                      , L.Loc
               ORDER BY L.LocScore
                      , L.logicallocation
                      , L.Loc
               
               PRINT 'Get MaxEmptyLocPZ, same SKU.SKUGroup Loc - ' + @c_ToLoc
            END
            --If having stock with max empty Loc in Pickzone, same SKU.SKUGroup, take next empty Loc - END

            --Take next empty loc which having max empty Loc in Pickzone - START
            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SET @c_MaxEmptyLocPZ = N''

               SELECT TOP 1 @c_ToLoc = L.Loc
               FROM #SAFETYSTOCK_LOC L (NOLOCK)
               LEFT JOIN #SAFETYSTOCK_EXCLUDELOC EL ON L.Loc = EL.LOC
               LEFT JOIN #SAFETYSTOCK_LOCASSIGNED SSPick ON L.Loc = SSPick.TOLOC
               WHERE EL.LOC IS NULL
               AND   SSPick.TOLOC IS NULL
               AND   L.Putawayzone = @c_SKUGroup
               AND   L.LocationRoom IN ( 'SAFETYSTOCK' )
               ORDER BY L.Pickzone
                      , L.LocScore
                      , L.logicallocation
                      , L.Loc

               PRINT 'Get MaxEmptyLocPZ Loc - ' + @c_ToLoc
            END
            --Take next empty loc which having max empty Loc in Pickzone - END

            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 87070 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': '
                                  + ' SAFETYSTOCK ToLOC not found for SKU: ' + @c_SKU
                                  + '. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END

            --Insert current location assigned  
            IF NOT EXISTS (  SELECT 1
                             FROM #SAFETYSTOCK_LOCASSIGNED
                             WHERE STORERKEY = @c_Storerkey AND SKU = @c_SKU AND TOLOC = @c_ToLoc)
            BEGIN
               INSERT INTO #SAFETYSTOCK_LOCASSIGNED (STORERKEY, SKU, TOLOC, LocationType)
               VALUES (@c_Storerkey, @c_SKU, @c_ToLoc, 'SAFETYSTOCK')
            END

            --SET @c_FinalLoc = @c_ToLoc
            --SET @c_ToLoc = ''

            --SELECT @c_ToLoc = ISNULL(PZ.InLoc, '')
            --FROM LOC L (NOLOCK)
            --JOIN Pickzone PZ (NOLOCK) ON PZ.Pickzone = L.Pickzone
            --WHERE L.Loc = @c_FinalLoc

            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 87075 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': '
                                  + ' ToLoc not found for SKU ' + @c_SKU
                                  + '. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END
         END

         --function to insert taskdetail  
         SELECT @b_Success = 1
         EXECUTE nspg_GetKey 'TaskDetailKey'
                           , 10
                           , @c_TaskDetailKey OUTPUT
                           , @b_Success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF NOT @b_Success = 1
         BEGIN
            SELECT @n_Continue = 3
         END

         SELECT @c_Areakey = AD.AreaKey
         FROM LOC L (NOLOCK)
         JOIN AreaDetail AD (NOLOCK) ON AD.PutawayZone = L.PutawayZone
         WHERE L.Loc = @c_ToLoc

         IF @b_Success = 1
         BEGIN
            INSERT TaskDetail (TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot, FromLoc
                             , FromID, ToLoc, ToID, SourceType, SourceKey, Priority, SourcePriority, Status
                             , LogicalFromLoc, LogicalToLoc, PickMethod, WaveKey, AreaKey, QtyReplen, PendingMoveIn
                             , Message01, Caseid, FinalLOC)
            VALUES (@c_TaskDetailKey, @c_TaskType --Tasktype    
                  , @c_Storerkey, @c_SKU, '6' -- UOM   
                  , @n_UCCQty --UOMQty
                  , @n_UCCQty --Qty   
                  , @n_Qty --systemqty  
                  , @c_Lot, @c_FromLoc, @c_ID -- from id    
                  , @c_ToLoc, @c_ID -- to id    
                  , @c_SourceType --Sourcetype    
                  , @c_Wavekey --Sourcekey    
                  , '9' -- Priority    
                  , '9' -- Sourcepriority    
                  , '0' -- Status    
                  , @c_FromLoc --Logical from loc    
                  , @c_ToLoc --Logical to loc    
                  , 'PP', @c_Wavekey, @c_Areakey, @n_UCCQty - @n_Qty, @n_UCCQty, @c_Message01, @c_DropID, '')

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 87080 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + ': Insert Taskdetail Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_errmsg) + ' ) '
               GOTO NEXT_LOOP_NEWRPF
            END
         END

         --Update taskdetailkey to pickdetail  
         IF (@n_Continue = 1 OR @n_Continue = 2)
         BEGIN
            SELECT @c_Pickdetailkey = N''
                 , @n_ReplenQty = @n_Qty
            WHILE @n_ReplenQty > 0
            BEGIN
               SELECT TOP 1 @c_Pickdetailkey = PICKDETAIL.PickDetailKey
                          , @n_pickqty = Qty
               FROM WAVEDETAIL (NOLOCK)
               JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey
               JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC
               WHERE WAVEDETAIL.WaveKey = @c_Wavekey
               AND   ISNULL(PICKDETAIL.TaskDetailKey, '') = ''
               AND   PICKDETAIL.Storerkey = @c_Storerkey
               AND   PICKDETAIL.Sku = @c_SKU
               AND   PICKDETAIL.Lot = @c_Lot
               AND   PICKDETAIL.Loc = @c_FromLoc
               AND   PICKDETAIL.DropID = @c_DropID
               AND   PICKDETAIL.ID = @c_ID
               AND   PICKDETAIL.UOM = '6'
               AND   LOC.LocationRoom = 'HIGHBAY'
               AND   PICKDETAIL.PickDetailKey > @c_Pickdetailkey
               ORDER BY PICKDETAIL.PickDetailKey

               SELECT @n_cnt = @@ROWCOUNT

               IF @n_cnt = 0
                  BREAK

               IF @n_pickqty <= @n_ReplenQty
               BEGIN
                  UPDATE #PickDetail_WIP WITH (ROWLOCK)
                  SET TaskDetailKey = @c_TaskDetailKey
                    , TrafficCop = NULL
                  WHERE PickDetailKey = @c_Pickdetailkey

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 87085
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Update Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                        + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     BREAK
                  END
                  SELECT @n_ReplenQty = @n_ReplenQty - @n_pickqty
               END
               ELSE
               BEGIN -- pickqty > replenqty     
                  SELECT @n_splitqty = @n_pickqty - @n_ReplenQty
                  EXECUTE nspg_GetKey 'PICKDETAILKEY'
                                    , 10
                                    , @c_NewPickdetailkey OUTPUT
                                    , @b_Success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

                  IF NOT @b_Success = 1
                  BEGIN
                     SELECT @n_Continue = 3
                     BREAK
                  END

                  INSERT #PickDetail_WIP (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot
                                        , Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID
                                        , PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish
                                        , ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, OptimizeCop
                                        , ShipFlag, PickSlipNo, WIP_Refno)
                  SELECT @c_NewPickdetailkey
                       , CaseID
                       , PickHeaderKey
                       , OrderKey
                       , OrderLineNumber
                       , Lot
                       , Storerkey
                       , Sku
                       , AltSku
                       , UOM
                       , CASE WHEN UOM IN ( '6', '7' ) THEN @n_splitqty
                              ELSE 1 END
                       , @n_splitqty
                       , QtyMoved
                       , Status
                       , DropID
                       , Loc
                       , ID
                       , PackKey
                       , UpdateSource
                       , CartonGroup
                       , CartonType
                       , ToLoc
                       , DoReplenish
                       , ReplenishZone
                       , DoCartonize
                       , PickMethod
                       , WaveKey
                       , EffectiveDate
                       , '9'
                       , ShipFlag
                       , PickSlipNo
                       , @c_SourceType
                  FROM #PickDetail_WIP PDW (NOLOCK)
                  WHERE PickDetailKey = @c_Pickdetailkey

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 87090
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Insert Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                        + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     BREAK
                  END

                  UPDATE #PickDetail_WIP WITH (ROWLOCK)
                  SET TaskDetailKey = @c_TaskDetailKey
                    , Qty = @n_ReplenQty
                    , UOMQty = CASE WHEN UOM IN ( '6', '7' ) THEN @n_ReplenQty
                                    ELSE 1 END
                    , TrafficCop = NULL
                  WHERE PickDetailKey = @c_Pickdetailkey
                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                          , @n_err = 87095
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Update Pickdetail Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE='
                                        + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     BREAK
                  END
                  SELECT @n_ReplenQty = 0
               END
            END -- While Qty > 0  
         END

         NEXT_LOOP_NEWRPF3:
         FETCH NEXT FROM CUR_NEWRPF3
         INTO @c_Storerkey
            , @c_Lot
            , @c_FromLoc
            , @c_ID
            , @c_SKU
            , @n_Qty
            , @n_UCCQty
            , @c_Site
            , @c_SKUGroup
            , @c_ItemClass
            , @c_DropID
      END
      CLOSE CUR_NEWRPF3
      DEALLOCATE CUR_NEWRPF3

   --WHILE @@TRANCOUNT > 0
   --BEGIN
   --   COMMIT TRAN
   --END
   END

   SET @dt_EndTime = GETDATE()

   IF @b_Debug = 2
   BEGIN
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1)  
      VALUES ( 'ispRLWAV50_4_HB6', @dt_StartTime, @dt_EndTime  
             , CONVERT(CHAR(12),@dt_EndTime - @dt_StartTime ,114)  
             , @c_Wavekey)  
   END


   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_Wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'U' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
                                  , @c_RemoveTaskdetailkey = 'N' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_err OUTPUT
                                  , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
      END
   END

   SET @dt_StartTime = GETDATE()

   --Generate CaseID for 
   --Pickdetail.UOM = 2 AND Pickmethod = C
   --Pickdetail.UOM = 6 AND LocationRoom = HIGHBAY
   --Pickdetail.UOM = 6 AND LocationRoom <> HIGHBAY
   IF (@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      SET @c_NewCaseID = 'Y'
      SET @n_AvailableQty = 0
      SET @c_PrevLoadkey = ''
      SET @c_PrevSKU = ''
      SET @c_PrevPickzone = ''
      SET @c_PrevLoc = ''
      SET @c_TaskDetailKey = ''

      DECLARE cur_GenCaseID_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         WITH CTE1 AS
            (
               --Loadkey + SKU + ToLoc.Pickzone (Pickdetail.UOM = 2 AND Pickmethod = C)
               --> DPP
               SELECT OH.Loadkey, PD.SKU, '' AS Loc, L.PickZone, S.SKUGroup
                    , SUM(PD.Qty) AS QtyRequired
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)   --WL04 S 
                           THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator)
                           ELSE MAX(TC.PEMaxQty) 
                           END AS PEMaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN MAX(TC.PEMaxQty) ELSE 0 END
                           END AS MaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(SUM(PD.Qty) / ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) AS INT) 
                                     ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN CAST(SUM(PD.Qty) / MAX(TC.PEMaxQty) AS INT) ELSE 0 END
                           END AS WHOLES 
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN SUM(PD.Qty) % ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) 
                                     ELSE SUM(PD.Qty) END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN SUM(PD.Qty) % MAX(TC.PEMaxQty) ELSE SUM(PD.Qty) END
                           END AS PARTIALS   --WL04 E
                    , 'RPF_1' AS TaskType
               --FROM WAVEDETAIL WD (NOLOCK)   --WL04 S
               --JOIN #PickDetail_WIP PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey   --WL04 E
               JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
               JOIN TASKDETAIL TD (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
               JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
               CROSS APPLY (SELECT TOP 1 PEMaxQty
                            FROM #TMP_CODELKUP (NOLOCK)
                            WHERE Pickzone = L.Pickzone AND SKUGroup = S.SKUGroup) AS TC
               WHERE ISNULL(PD.CaseID,'') = ''
               AND ISNULL(PD.TaskDetailKey,'') <> ''
               AND (PD.UOM = '2' AND PD.PickMethod = 'C')
               AND PD.WaveKey = @c_Wavekey
               AND TD.TaskType = 'RPF'
               AND ISNULL(TD.ToLoc,'') <> ''
               GROUP BY OH.Loadkey, PD.SKU, L.PickZone, S.SKUGroup
               UNION ALL
               --Loadkey + SKU + ToLoc.Pickzone (Pickdetail.UOM = 6 AND LocationRoom = HIGHBAY)
               SELECT OH.Loadkey, PD.SKU, '' AS Loc, L.PickZone, S.SKUGroup
                    , SUM(PD.Qty) AS QtyRequired
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)   --WL04 S 
                           THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator)
                           ELSE MAX(TC.PEMaxQty) 
                           END AS PEMaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN MAX(TC.PEMaxQty) ELSE 0 END
                           END AS MaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(SUM(PD.Qty) / ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) AS INT) 
                                     ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN CAST(SUM(PD.Qty) / MAX(TC.PEMaxQty) AS INT) ELSE 0 END
                           END AS WHOLES 
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN SUM(PD.Qty) % ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) 
                                     ELSE SUM(PD.Qty) END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN SUM(PD.Qty) % MAX(TC.PEMaxQty) ELSE SUM(PD.Qty) END
                           END AS PARTIALS   --WL04 E
                    , 'RPF_1' AS TaskType
               --FROM WAVEDETAIL WD (NOLOCK)   --WL04 S
               --JOIN #PickDetail_WIP PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey   --WL04 E
               JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
               JOIN TASKDETAIL TD (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
               JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
               CROSS APPLY (SELECT TOP 1 PEMaxQty
                            FROM #TMP_CODELKUP (NOLOCK)
                            WHERE Pickzone = L.Pickzone AND SKUGroup = S.SKUGroup) AS TC
               WHERE ISNULL(PD.CaseID,'') = '' 
               AND ISNULL(PD.TaskDetailKey,'') <> ''
               AND PD.UOM = '6'
               AND PD.WaveKey = @c_Wavekey   --WL04
               AND TD.TaskType = 'RPF'
               AND ISNULL(TD.ToLoc,'') <> ''
               GROUP BY OH.Loadkey, PD.SKU, L.PickZone, S.SKUGroup
               UNION ALL
               --Loadkey + SKU + Pickzone (Pickdetail.UOM = 6 AND LocationRoom <> HIGHBAY)
               SELECT OH.Loadkey, PD.SKU, '' AS Loc, L.PickZone, S.SKUGroup
                    , SUM(PD.Qty) AS QtyRequired
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)   --WL04 S 
                           THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator)
                           ELSE MAX(TC.PEMaxQty) 
                           END AS PEMaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN MAX(TC.PEMaxQty) ELSE 0 END
                           END AS MaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(SUM(PD.Qty) / ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) AS INT) 
                                     ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN CAST(SUM(PD.Qty) / MAX(TC.PEMaxQty) AS INT) ELSE 0 END
                           END AS WHOLES 
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN SUM(PD.Qty) % ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) 
                                     ELSE SUM(PD.Qty) END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN SUM(PD.Qty) % MAX(TC.PEMaxQty) ELSE SUM(PD.Qty) END
                           END AS PARTIALS   --WL04 E
                    , 'NA_1' AS TaskType
               --FROM WAVEDETAIL WD (NOLOCK)   --WL04 S
               --JOIN #PickDetail_WIP PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey   --WL04 E
               JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
               JOIN LOC L (NOLOCK) ON PD.LOC = L.Loc
               CROSS APPLY (SELECT TOP 1 PEMaxQty
                            FROM #TMP_CODELKUP (NOLOCK)
                            WHERE Pickzone = L.Pickzone AND SKUGroup = S.SKUGroup) AS TC
               WHERE ISNULL(PD.CaseID,'') = '' 
               AND ISNULL(PD.TaskDetailKey,'') = ''
               AND PD.UOM = '6'
               AND PD.WaveKey = @c_Wavekey   --WL04
               GROUP BY OH.Loadkey, PD.SKU, L.PickZone, S.SKUGroup
            )
            ,CTE2 AS 
            (
                SELECT Loadkey, SKU, Loc, PickZone, SKUGroup, Tasktype, PEMaxQty, MaxQty, WHOLES, 'BASE ' AS Remark
                FROM CTE1
                UNION ALL
                SELECT Loadkey, SKU, Loc, PickZone, SKUGroup, TaskType, PEMaxQty, MaxQty, WHOLES - 1, 'RECUR' AS Remark
                FROM CTE2 
                WHERE WHOLES > 1
            )
            SELECT Loadkey, SKU, Loc, PickZone, SKUGroup, TaskType, PEMaxQty, MaxQty AS QuantityRequired 
            FROM CTE2
            WHERE MaxQty > 0
            UNION ALL
            SELECT Loadkey, SKU, Loc, PickZone, SKUGroup, TaskType, PEMaxQty, PARTIALS AS QuantityRequired 
            FROM CTE1 
            WHERE PARTIALS > 0
            ORDER BY Loadkey ASC, SKU ASC, Pickzone ASC, LOC ASC, QuantityRequired DESC
            OPTION (MAXRECURSION 0)

      OPEN cur_GenCaseID_1  
      FETCH NEXT FROM cur_GenCaseID_1 INTO @c_Loadkey, @c_SKU, @c_Loc, @c_PickZone, @c_SKUGroup, @c_TaskType, @n_PEMaxQty, @n_Qty
      
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2) 
      BEGIN
         SET @c_CaseID = ''

         IF @n_Qty >= @n_PEMaxQty
         BEGIN
            EXECUTE dbo.nspg_GetKey
               @c_KeyName,
               10,
               @c_SeqNo       OUTPUT,
               @b_Success     OUTPUT,
               @n_err         OUTPUT,
               @c_errmsg      OUTPUT

            SET @c_CaseID = @c_SeqNo

            INSERT INTO #TMP_CASEID(Loadkey, SKU, LOC, Pickzone, Qty, ItemClass, LocRoom, CaseID, [Status], SKUGroup
                                  , Taskdetailkey)
            SELECT @c_Loadkey, @c_SKU, @c_Loc, @c_Pickzone, @n_Qty, '', @c_TaskType
                 , @c_CaseID, 'FULL', @c_SKUGroup, ''
         END

         FETCH NEXT FROM cur_GenCaseID_1 INTO @c_Loadkey, @c_SKU, @c_Loc, @c_PickZone, @c_SKUGroup, @c_TaskType, @n_PEMaxQty, @n_Qty
      END
      CLOSE cur_GenCaseID_1  
      DEALLOCATE cur_GenCaseID_1 

      SET @c_CallFrom = 'GenCaseID_1'

      GOTO UPDATE_PD
      RETURN_GenCaseID_1:
   END

   SET @dt_EndTime = GETDATE()

   IF @b_Debug = 2
   BEGIN
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1)  
      VALUES ( 'ispRLWAV50_5_CID1', @dt_StartTime, @dt_EndTime  
             , CONVERT(CHAR(12),@dt_EndTime - @dt_StartTime ,114)  
             , @c_Wavekey)  
   END

   SET @dt_StartTime = GETDATE()

   IF (@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      SET @c_NewCaseID = 'Y'
      SET @n_AvailableQty = 0
      SET @c_PrevLoadkey = ''
      SET @c_PrevSKU = ''
      SET @c_PrevPickzone = ''
      SET @c_PrevLoc = ''
      SET @c_TaskDetailKey = ''

      DECLARE cur_GenCaseID_2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         WITH CTE1 AS
            (
               --Loadkey + SKU + Pickzone + Itemclass (Pickdetail.UOM = 2 AND Pickmethod = C)
               --> DPP
               SELECT OH.Loadkey, PD.SKU, '' AS Loc, L.PickZone, S.SKUGroup
                    , SUM(PD.Qty) AS QtyRequired
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)   --WL04 S 
                           THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator)
                           ELSE MAX(TC.PEMaxQty) 
                           END AS PEMaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN MAX(TC.PEMaxQty) ELSE 0 END
                           END AS MaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(SUM(PD.Qty) / ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) AS INT) 
                                     ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN CAST(SUM(PD.Qty) / MAX(TC.PEMaxQty) AS INT) ELSE 0 END
                           END AS WHOLES 
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN SUM(PD.Qty) % ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) 
                                     ELSE SUM(PD.Qty) END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN SUM(PD.Qty) % MAX(TC.PEMaxQty) ELSE SUM(PD.Qty) END
                           END AS PARTIALS   --WL04 E
                    , 'RPF_2' AS TaskType
                    , S.itemclass
               --FROM WAVEDETAIL WD (NOLOCK)   --WL04 S
               --JOIN #PickDetail_WIP PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey   --WL04 E
               JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
               JOIN TASKDETAIL TD (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
               JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
               CROSS APPLY (SELECT TOP 1 PEMaxQty
                            FROM #TMP_CODELKUP (NOLOCK)
                            WHERE Pickzone = L.Pickzone AND SKUGroup = S.SKUGroup) AS TC
               WHERE ISNULL(PD.CaseID,'') = ''
               AND ISNULL(PD.TaskDetailKey,'') <> ''
               AND (PD.UOM = '2' AND PD.PickMethod = 'C')
               AND PD.WaveKey = @c_Wavekey   --WL04
               AND TD.TaskType = 'RPF'
               AND ISNULL(TD.ToLoc,'') <> ''
               GROUP BY OH.Loadkey, PD.SKU, L.PickZone, S.SKUGroup, S.itemclass
               UNION ALL
               --Loadkey + SKU + Pickzone + Itemclass (Pickdetail.UOM = 6 AND LocationRoom = HIGHBAY)
               SELECT OH.Loadkey, PD.SKU, '' AS Loc, L.PickZone, S.SKUGroup
                    , SUM(PD.Qty) AS QtyRequired
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)   --WL04 S 
                           THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator)
                           ELSE MAX(TC.PEMaxQty) 
                           END AS PEMaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN MAX(TC.PEMaxQty) ELSE 0 END
                           END AS MaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(SUM(PD.Qty) / ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) AS INT) 
                                     ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN CAST(SUM(PD.Qty) / MAX(TC.PEMaxQty) AS INT) ELSE 0 END
                           END AS WHOLES 
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN SUM(PD.Qty) % ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) 
                                     ELSE SUM(PD.Qty) END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN SUM(PD.Qty) % MAX(TC.PEMaxQty) ELSE SUM(PD.Qty) END
                           END AS PARTIALS   --WL04 E
                    , 'RPF_2' AS TaskType
                    , S.itemclass
               --FROM WAVEDETAIL WD (NOLOCK)   --WL04 S
               --JOIN #PickDetail_WIP PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey   --WL04 E
               JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
               JOIN TASKDETAIL TD (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
               JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
               CROSS APPLY (SELECT TOP 1 PEMaxQty
                            FROM #TMP_CODELKUP (NOLOCK)
                            WHERE Pickzone = L.Pickzone AND SKUGroup = S.SKUGroup) AS TC
               WHERE ISNULL(PD.CaseID,'') = '' 
               AND ISNULL(PD.TaskDetailKey,'') <> ''
               AND PD.UOM = '6'
               AND PD.WaveKey = @c_Wavekey   --WL04
               AND TD.TaskType = 'RPF'
               AND ISNULL(TD.ToLoc,'') <> ''
               GROUP BY OH.Loadkey, PD.SKU, L.PickZone, S.SKUGroup, S.itemclass
               UNION ALL
               --Loadkey + SKU + Pickzone + Itemclass (Pickdetail.UOM = 6 AND LocationRoom <> HIGHBAY)
               SELECT OH.Loadkey, PD.SKU, '' AS Loc, L.PickZone, S.SKUGroup
                    , SUM(PD.Qty) AS QtyRequired
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)   --WL04 S 
                           THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator)
                           ELSE MAX(TC.PEMaxQty) 
                           END AS PEMaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN MAX(TC.PEMaxQty) ELSE 0 END
                           END AS MaxQty
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN CAST(SUM(PD.Qty) / ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) AS INT) 
                                     ELSE 0 END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN CAST(SUM(PD.Qty) / MAX(TC.PEMaxQty) AS INT) ELSE 0 END
                           END AS WHOLES 
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)
                           THEN CASE WHEN SUM(PD.Qty) > CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) 
                                     THEN SUM(PD.Qty) % ( CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator) ) 
                                     ELSE SUM(PD.Qty) END
                           ELSE CASE WHEN SUM(PD.Qty) > MAX(TC.PEMaxQty) THEN SUM(PD.Qty) % MAX(TC.PEMaxQty) ELSE SUM(PD.Qty) END
                           END AS PARTIALS   --WL04 E
                    , 'NA_2' AS TaskType
                    , S.itemclass
               --FROM WAVEDETAIL WD (NOLOCK)   --WL04 S
               --JOIN #PickDetail_WIP PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey   --WL04 E
               JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
               JOIN LOC L (NOLOCK) ON PD.LOC = L.Loc
               CROSS APPLY (SELECT TOP 1 PEMaxQty
                            FROM #TMP_CODELKUP (NOLOCK)
                            WHERE Pickzone = L.Pickzone AND SKUGroup = S.SKUGroup) AS TC
               WHERE ISNULL(PD.CaseID,'') = '' 
               AND ISNULL(PD.TaskDetailKey,'') = ''
               AND PD.UOM = '6'
               AND PD.WaveKey = @c_Wavekey   --WL04
               GROUP BY OH.Loadkey, PD.SKU, L.PickZone, S.SKUGroup, S.itemclass
            )
            ,CTE2 AS 
            (
                SELECT Loadkey, SKU, Loc, PickZone, SKUGroup, Tasktype, Itemclass, PEMaxQty, MaxQty, WHOLES, 'BASE ' AS Remark
                FROM CTE1
                UNION ALL
                SELECT Loadkey, SKU, Loc, PickZone, SKUGroup, TaskType, Itemclass, PEMaxQty, MaxQty, WHOLES - 1, 'RECUR' AS Remark
                FROM CTE2 
                WHERE WHOLES > 1
            )
            SELECT Loadkey, SKU, Loc, PickZone, SKUGroup, TaskType, Itemclass, PEMaxQty, MaxQty AS QuantityRequired 
            FROM CTE2
            WHERE MaxQty > 0
            UNION ALL
            SELECT Loadkey, SKU, Loc, PickZone, SKUGroup, TaskType, Itemclass, PEMaxQty, PARTIALS AS QuantityRequired 
            FROM CTE1 
            WHERE PARTIALS > 0
            ORDER BY Loadkey ASC, SKU ASC, Pickzone ASC, LOC ASC, Itemclass ASC, QuantityRequired DESC
            OPTION (MAXRECURSION 0)

      OPEN cur_GenCaseID_2  
      FETCH NEXT FROM cur_GenCaseID_2 INTO @c_Loadkey, @c_SKU, @c_Loc, @c_PickZone, @c_SKUGroup, @c_TaskType, @c_ItemClass, @n_PEMaxQty, @n_Qty
      
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2) 
      BEGIN
         SET @c_CaseID = ''

         IF @n_Qty >= @n_PEMaxQty
         BEGIN
            EXECUTE dbo.nspg_GetKey
               @c_KeyName,
               10,
               @c_SeqNo       OUTPUT,
               @b_Success     OUTPUT,
               @n_err         OUTPUT,
               @c_errmsg      OUTPUT

            SET @c_CaseID = @c_SeqNo

            INSERT INTO #TMP_CASEID(Loadkey, SKU, LOC, Pickzone, Qty, ItemClass, LocRoom, CaseID, [Status], SKUGroup
                                  , Taskdetailkey)
            SELECT @c_Loadkey, @c_SKU, @c_Loc, @c_Pickzone, @n_Qty, '', @c_TaskType
                 , @c_CaseID, 'FULL', @c_SKUGroup, ''
         END

         FETCH NEXT FROM cur_GenCaseID_2 INTO @c_Loadkey, @c_SKU, @c_Loc, @c_PickZone, @c_SKUGroup, @c_TaskType, @c_ItemClass, @n_PEMaxQty, @n_Qty
      END
      CLOSE cur_GenCaseID_2  
      DEALLOCATE cur_GenCaseID_2 

      SET @c_CallFrom = 'GenCaseID_2'

      GOTO UPDATE_PD
      RETURN_GenCaseID_2:
   END

   SET @dt_EndTime = GETDATE()

   IF @b_Debug = 2
   BEGIN
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1)  
      VALUES ( 'ispRLWAV50_6_CID2', @dt_StartTime, @dt_EndTime  
             , CONVERT(CHAR(12),@dt_EndTime - @dt_StartTime ,114)  
             , @c_Wavekey)  
   END

   SET @dt_StartTime = GETDATE()

   IF (@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      SET @c_NewCaseID = 'Y'
      SET @n_AvailableQty = 0
      SET @c_PrevLoadkey = ''
      SET @c_PrevSKU = ''
      SET @c_PrevPickzone = ''
      SET @c_PrevLoc = ''
      SET @c_TaskDetailKey = ''
      SET @c_PrevTaskType = ''

      --WL04 S
      SELECT @n_MaxQty = SUM(QTY)
      FROM #PickDetail_WIP PDW (NOLOCK)
      WHERE WaveKey = @c_Wavekey

      WHILE @n_MaxQty > 0
      BEGIN
         INSERT INTO @T_Numbers (Dummy)
         VALUES (NULL -- Dummy - nvarchar(1)
            )
         SET @n_MaxQty = @n_MaxQty - 1
      END

      --Loadkey + Pickzone
      DECLARE cur_GenCaseID_3 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         WITH t1 AS
            (
               --Loadkey + Pickzone (Pickdetail.UOM = 2 AND Pickmethod = C)
               --> DPP
               SELECT OH.Loadkey, L.PickZone, S.SKUGroup
                    , SUM(PD.Qty) AS QtyRequired
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)   --WL04 S 
                           THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator)
                           ELSE MAX(TC.PEMaxQty) 
                           END AS PEMaxQty
                    , 'RPF_3' AS TaskType, PD.SKU
                    , MAX(S.PackQtyIndicator) AS PackQtyIndicator
               --FROM WAVEDETAIL WD (NOLOCK)   --WL04 S
               --JOIN #PickDetail_WIP PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey   --WL04 E
               JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
               JOIN TASKDETAIL TD (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
               JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
               CROSS APPLY (SELECT TOP 1 PEMaxQty
                            FROM #TMP_CODELKUP (NOLOCK)
                            WHERE Pickzone = L.Pickzone AND SKUGroup = S.SKUGroup) AS TC
               WHERE ISNULL(PD.CaseID,'') = ''
               AND ISNULL(PD.TaskDetailKey,'') <> ''
               AND (PD.UOM = '2' AND PD.PickMethod = 'C')
               AND PD.WaveKey = @c_Wavekey   --WL04
               AND TD.TaskType = 'RPF'
               AND ISNULL(TD.ToLoc,'') <> ''
               GROUP BY OH.Loadkey, L.PickZone, S.SKUGroup, S.PackQtyIndicator, PD.SKU   --WL04
               UNION ALL
               --Loadkey + Pickzone (Pickdetail.UOM = 6 AND LocationRoom = HIGHBAY)
               SELECT OH.Loadkey, L.PickZone, S.SKUGroup
                    , SUM(PD.Qty) AS QtyRequired
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)   --WL04 S 
                           THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator)
                           ELSE MAX(TC.PEMaxQty) 
                           END AS PEMaxQty
                    , 'RPF_3' AS TaskType, PD.SKU
                    , MAX(S.PackQtyIndicator) AS PackQtyIndicator
               --FROM WAVEDETAIL WD (NOLOCK)   --WL04 S
               --JOIN #PickDetail_WIP PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey   --WL04 E
               JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
               JOIN TASKDETAIL TD (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
               JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
               CROSS APPLY (SELECT TOP 1 PEMaxQty
                            FROM #TMP_CODELKUP (NOLOCK)
                            WHERE Pickzone = L.Pickzone AND SKUGroup = S.SKUGroup) AS TC
               WHERE ISNULL(PD.CaseID,'') = '' 
               AND ISNULL(PD.TaskDetailKey,'') <> ''
               AND PD.UOM = '6'
               AND PD.WaveKey = @c_Wavekey   --WL04
               AND TD.TaskType = 'RPF'
               AND ISNULL(TD.ToLoc,'') <> ''
               GROUP BY OH.Loadkey, L.PickZone, S.SKUGroup, S.PackQtyIndicator, PD.SKU   --WL04
               UNION ALL
               --Loadkey + Pickzone (Pickdetail.UOM = 6 AND LocationRoom <> HIGHBAY)
               SELECT OH.Loadkey, L.PickZone, S.SKUGroup
                    , SUM(PD.Qty) AS QtyRequired
                    , CASE WHEN MAX(S.PackQtyIndicator) > 1 AND MAX(S.PackQtyIndicator) <= MAX(TC.PEMaxQty)   --WL04 S 
                           THEN CAST(MAX(TC.PEMaxQty) / MAX(S.PackQtyIndicator) AS INT) * MAX(S.PackQtyIndicator)
                           ELSE MAX(TC.PEMaxQty) 
                           END AS PEMaxQty
                    , 'NA_3' AS TaskType, PD.SKU
                    , MAX(S.PackQtyIndicator) AS PackQtyIndicator
               --FROM WAVEDETAIL WD (NOLOCK)   --WL04 S
               --JOIN #PickDetail_WIP PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey   --WL04 E
               JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
               JOIN LOC L (NOLOCK) ON PD.LOC = L.Loc
               CROSS APPLY (SELECT TOP 1 PEMaxQty
                            FROM #TMP_CODELKUP (NOLOCK)
                            WHERE Pickzone = L.Pickzone AND SKUGroup = S.SKUGroup) AS TC
               WHERE ISNULL(PD.CaseID,'') = '' 
               AND ISNULL(PD.TaskDetailKey,'') = ''
               AND PD.UOM = '6'
               AND PD.WaveKey = @c_Wavekey   --WL04
               GROUP BY OH.Loadkey, L.PickZone, S.SKUGroup, S.PackQtyIndicator, PD.SKU   --WL04
            )
            ,t2 AS 
            (
                --SELECT Loadkey, PickZone, SKUGroup, Tasktype, SKU, PEMaxQty, MaxQty, WHOLES, 'BASE ' AS Remark
                --FROM CTE1
                --UNION ALL
                --SELECT Loadkey, PickZone, SKUGroup, TaskType, SKU, PEMaxQty, MaxQty, WHOLES - 1, 'RECUR' AS Remark
                --FROM CTE2 
                --WHERE WHOLES > 1
                SELECT ROW_NUMBER() OVER (ORDER BY TN.RowID) AS Val FROM @T_Numbers TN
            )
            --SELECT Loadkey, PickZone, SKUGroup, TaskType, SKU, PEMaxQty, MaxQty AS QuantityRequired 
            --FROM CTE2
            --WHERE MaxQty > 0
            --UNION ALL
            --SELECT Loadkey, PickZone, SKUGroup, TaskType, SKU, PEMaxQty, PARTIALS AS QuantityRequired 
            --FROM CTE1 
            --WHERE PARTIALS > 0
            --ORDER BY Loadkey ASC, Pickzone ASC, TaskType ASC, SKU ASC, QuantityRequired DESC
            SELECT t1.Loadkey, t1.Pickzone, t1.SKUGroup, t1.TaskType, t1.SKU, t1.PEMaxQty, t1.PackQtyIndicator
            FROM t1, t2
            WHERE t1.QtyRequired / t1.PackQtyIndicator >= t2.Val
            ORDER BY t1.Loadkey, t1.Pickzone, t1.TaskType, t1.SKU, t1.QtyRequired DESC
            OPTION (MAXRECURSION 0)
            --WL04 E

      OPEN cur_GenCaseID_3  
      FETCH NEXT FROM cur_GenCaseID_3 INTO @c_Loadkey, @c_PickZone, @c_SKUGroup, @c_TaskType, @c_SKU, @n_PEMaxQty, @n_Qty
      
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2) 
      BEGIN
         SET @c_CaseID = ''

         --WL04 S
         --Get existing CaseID that still can fit in
         SELECT TOP 1 @c_CaseID = CaseID
                    , @n_AvailableQty = SUM(TC.Qty) + @n_Qty
         FROM #TMP_CASEID TC
         WHERE TC.Loadkey = @c_Loadkey
         AND TC.Pickzone = @c_Pickzone
         AND TC.SKUGroup = @c_SKUGroup
         AND TC.LocRoom = @c_TaskType
         GROUP BY CaseID
         HAVING SUM(TC.Qty) + @n_Qty <= @n_PEMaxQty
         ORDER BY CaseID

         IF ISNULL(@c_CaseID,'') <> ''
            SET @c_SeqNo = @c_CaseID
         --WL04 E

         IF ( (@c_Loadkey <> @c_PrevLoadkey) OR
              (@c_Pickzone <> @c_PrevPickzone) OR
              (@c_TaskType <> @c_PrevTaskType) )
         BEGIN
            SET @c_NewCaseID = 'Y'
            SET @n_AvailableQty = @n_Qty
         END
         ELSE
         BEGIN
            SET @n_AvailableQty = @n_AvailableQty + @n_Qty
         END

         IF @n_AvailableQty > @n_PEMaxQty
         BEGIN
            SET @c_NewCaseID = 'Y'
            SET @n_AvailableQty = @n_Qty
         END

         IF @c_NewCaseID = 'Y'
         BEGIN
            SELECT TOP 1 @c_CaseID = CaseID
                       , @n_AvailableQty = SUM(TC.Qty) + @n_Qty
            FROM #TMP_CASEID TC
            WHERE TC.Loadkey = @c_Loadkey
            AND TC.Pickzone = @c_Pickzone
            AND TC.SKUGroup = @c_SKUGroup
            AND TC.LocRoom = @c_TaskType
            GROUP BY CaseID
            HAVING SUM(TC.Qty) + @n_Qty <= @n_PEMaxQty
            ORDER BY CaseID   --WL04

            IF ISNULL(@c_CaseID,'') = ''
            BEGIN
               EXECUTE dbo.nspg_GetKey
                  @c_KeyName,
                  10,
                  @c_SeqNo       OUTPUT,
                  @b_Success     OUTPUT,
                  @n_err         OUTPUT,
                  @c_errmsg      OUTPUT
               
               SET @c_NewCaseID = 'N'
            END
            ELSE
            BEGIN
               SET @c_NewCaseID = 'N'
               SET @c_SeqNo = @c_CaseID
            END
         END

         SET @c_CaseID = @c_SeqNo

         INSERT INTO #TMP_CASEID(Loadkey, SKU, LOC, Pickzone, Qty, ItemClass, LocRoom, CaseID, [Status], SKUGroup
                               , Taskdetailkey)
         SELECT @c_Loadkey, @c_SKU, '', @c_Pickzone, @n_Qty, '', @c_TaskType 
              , @c_CaseID, CASE WHEN @n_Qty >= @n_PEMaxQty THEN 'FULL' ELSE 'PARTIAL' END, @c_SKUGroup, ''

         SET @c_PrevLoadkey = @c_Loadkey
         SET @c_PrevPickzone = @c_Pickzone
         SET @c_PrevTaskType = @c_TaskType

         FETCH NEXT FROM cur_GenCaseID_3 INTO @c_Loadkey, @c_PickZone, @c_SKUGroup, @c_TaskType, @c_SKU, @n_PEMaxQty, @n_Qty
      END
      CLOSE cur_GenCaseID_3  
      DEALLOCATE cur_GenCaseID_3

      SET @c_CallFrom = 'GenCaseID_3'

      GOTO UPDATE_PD
      RETURN_GenCaseID_3:
   END

   SET @dt_EndTime = GETDATE()

   IF @b_Debug = 2
   BEGIN
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1)  
      VALUES ( 'ispRLWAV50_7_CID3', @dt_StartTime, @dt_EndTime  
             , CONVERT(CHAR(12),@dt_EndTime - @dt_StartTime ,114)  
             , @c_Wavekey)  
   END

   SET @dt_StartTime = GETDATE()

   IF @b_Debug = 2
      SELECT T.*, SKU.PackQtyIndicator FROM #TMP_CASEID T
      LEFT JOIN SKU (NOLOCK) ON T.SKU = SKU.SKU AND SKU.StorerKey = 'NIKECN'
      ORDER BY T.CASEID, T.Loadkey, T.Pickzone, T.SKU   --WL04

   GOTO CONTINUE_SP

   UPDATE_PD:
   --Update CaseID to Pickdetail / Split Pickdetail
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SET @c_GetPickdetCondition = ''

      DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TC.Loadkey, TC.Pickzone, TC.SKU, TC.Itemclass, TC.LocRoom, TC.CaseID, SUM(TC.Qty)
           , TC.SKUGroup, TC.LOC, TC.Taskdetailkey, TC2.[Site]
      FROM #TMP_CASEID TC
      JOIN #TMP_CODELKUP TC2 ON TC2.Pickzone = TC.Pickzone AND TC2.SKUGroup = TC.SKUGroup
      WHERE TC.[Status] NOT IN ('','DONE')
      GROUP BY TC.Loadkey, TC.Pickzone, TC.SKU, TC.Itemclass, TC.LocRoom, TC.CaseID, TC.SKUGroup
             , TC.LOC, TC.Taskdetailkey, TC2.[Site]
      ORDER BY TC.CaseID

      OPEN CUR_UPD

      FETCH NEXT FROM CUR_UPD INTO @c_Loadkey, @c_Pickzone, @c_SKU, @c_Itemclass, @c_LocRoom, @c_CaseID
                                 , @n_packqty, @c_SKUGroup, @c_Loc, @c_TaskDetailKey, @c_Site

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @c_pickdetailkey = ''  

         WHILE @n_packqty > 0  
         BEGIN
            SET @n_cnt = 0  
            SET @c_PickDetailKey = ''

            IF @c_LocRoom LIKE 'RPF%'
            BEGIN
               SET @c_TableJoin = ' JOIN LOC L (NOLOCK) ON TD.ToLoc = L.LOC ' + CHAR(13)
               
               SET @c_SQL = ' SELECT TOP 1 @c_Pickdetailkey = PICKDETAIL.PickDetailKey ' + CHAR(13)
                          + ' , @n_pickqty = PICKDETAIL.Qty ' + CHAR(13)
                          + ' , @n_cnt = 1 ' + CHAR(13)
                          + ' FROM WAVEDETAIL (NOLOCK) ' + CHAR(13)
                          + ' JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey ' + CHAR(13)
                          + ' JOIN TASKDETAIL TD (NOLOCK) ON TD.TaskDetailKey = PICKDETAIL.TaskDetailKey ' + CHAR(13)
                          + @c_TableJoin
                          + ' JOIN ORDERS OH WITH (NOLOCK) ON PICKDETAIL.Orderkey = OH.Orderkey '
                          + ' JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey '
                          + ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PICKDETAIL.Storerkey AND S.SKU = PICKDETAIL.SKU '
                          + ' WHERE WAVEDETAIL.WaveKey = @c_Wavekey ' + CHAR(13)
                          + ' AND   ISNULL(PICKDETAIL.CaseID, '''') = '''' ' + CHAR(13)
                          + ' AND   PICKDETAIL.Storerkey = @c_Storerkey ' + CHAR(13)
                          + ' AND   PICKDETAIL.Sku = CASE WHEN ISNULL(@c_SKU,'''') = '''' THEN PICKDETAIL.Sku ELSE @c_SKU END ' + CHAR(13)
                          + ' AND   L.PickZone = @c_Pickzone ' + CHAR(13)
                          + ' AND   LPD.Loadkey = @c_Loadkey ' + CHAR(13)
                          --+ ' AND   L.Loc = @c_Loc ' + CHAR(13)
                          + ' AND   ((PICKDETAIL.UOM = ''2'' AND PICKDETAIL.PickMethod = ''C'') OR PICKDETAIL.UOM = ''6'') ' + CHAR(13)
                          --+ ' AND   PICKDETAIL.PickDetailKey > @c_Pickdetailkey ' + CHAR(13)
                          + ' AND   S.Itemclass = CASE WHEN ISNULL(@c_Itemclass,'''') = '''' THEN S.Itemclass ELSE @c_Itemclass END '
                          + ' ORDER BY LPD.Loadkey, L.Pickzone, S.Itemclass, PICKDETAIL.Loc ' + CHAR(13)
                          + '        , CASE WHEN PICKDETAIL.Qty = @n_packqty THEN 1 ELSE 2 END, PICKDETAIL.Pickdetailkey '
            END
            ELSE IF @c_LocRoom LIKE 'NA%'   --@c_LocRoom = 'NA'
            BEGIN
               SET @c_SQL = ' SELECT TOP 1 @c_Pickdetailkey = PICKDETAIL.PickDetailKey ' + CHAR(13)
                          + '            , @n_pickqty = PICKDETAIL.Qty ' + CHAR(13)
                          + '            , @n_cnt = 1 ' + CHAR(13)
                          + ' FROM WAVEDETAIL (NOLOCK) ' + CHAR(13)
                          + ' JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey ' + CHAR(13)
                          + ' JOIN LOC L (NOLOCK) ON PICKDETAIL.LOC = L.LOC ' + CHAR(13)
                          + ' JOIN ORDERS OH WITH (NOLOCK) ON PICKDETAIL.Orderkey = OH.Orderkey '
                          + ' JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey '
                          + ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PICKDETAIL.Storerkey AND S.SKU = PICKDETAIL.SKU '
                          + ' WHERE WAVEDETAIL.WaveKey = @c_Wavekey ' + CHAR(13)
                          + ' AND   ISNULL(PICKDETAIL.CaseID, '''') = '''' ' + CHAR(13)
                          + ' AND   ISNULL(PICKDETAIL.TaskDetailKey, '''') = '''' ' + CHAR(13)
                          + ' AND   PICKDETAIL.Storerkey = @c_Storerkey ' + CHAR(13)
                          + ' AND   PICKDETAIL.Sku = CASE WHEN ISNULL(@c_SKU,'''') = '''' THEN PICKDETAIL.Sku ELSE @c_SKU END ' + CHAR(13)
                          + ' AND   L.PickZone = @c_Pickzone ' + CHAR(13)
                          --+ ' AND   L.Loc = @c_Loc ' + CHAR(13)
                          + ' AND   LPD.Loadkey = @c_Loadkey ' + CHAR(13)
                          + ' AND   PICKDETAIL.UOM = ''6'' ' + CHAR(13)
                          --+ ' AND   PICKDETAIL.PickDetailKey > @c_Pickdetailkey ' + CHAR(13)
                          + ' AND   S.Itemclass = CASE WHEN ISNULL(@c_Itemclass,'''') = '''' THEN S.Itemclass ELSE @c_Itemclass END '
                          + ' ORDER BY LPD.Loadkey, L.Pickzone, S.Itemclass, PICKDETAIL.Loc ' + CHAR(13)
                          + '        , CASE WHEN PICKDETAIL.Qty = @n_packqty THEN 1 ELSE 2 END, PICKDETAIL.Pickdetailkey '
            END

            SET @c_SQLArgument = N' @n_cnt             INT            OUTPUT'  
                               +  ',@n_pickqty         INT            OUTPUT'  
                               +  ',@c_PickDetailKey   NVARCHAR(10)   OUTPUT'  
                               +  ',@c_Wavekey         NVARCHAR(10)'    
                               +  ',@c_StorerKey       NVARCHAR(15)' 
                               +  ',@c_Loc             NVARCHAR(10)'
                               +  ',@c_Pickzone        NVARCHAR(20)'
                               +  ',@c_Loadkey         NVARCHAR(10)'
                               +  ',@c_SKU             NVARCHAR(20)'
                               +  ',@c_Itemclass       NVARCHAR(20)'
                               +  ',@n_packqty         INT '  
            
            EXEC sp_executesql @c_SQL  
                            ,  @c_SQLArgument  
                            ,  @n_Cnt            OUTPUT  
                            ,  @n_pickqty        OUTPUT   
                            ,  @c_PickDetailKey  OUTPUT  
                            ,  @c_Wavekey       
                            ,  @c_StorerKey  
                            ,  @c_Loc
                            ,  @c_Pickzone 
                            ,  @c_Loadkey  
                            ,  @c_SKU      
                            ,  @c_Itemclass
                            ,  @n_packqty

            IF @n_cnt = 0 
            BEGIN 
               PRINT @c_Wavekey   + ' AS @c_Wavekey   ' + CHAR(13)
                   + @c_StorerKey + ' AS @c_StorerKey ' + CHAR(13)
                   + @c_Pickzone  + ' AS @c_Pickzone  ' + CHAR(13)
                   + @c_Loadkey   + ' AS @c_Loadkey   ' + CHAR(13)
                   + @c_SKU       + ' AS @c_SKU       ' + CHAR(13)
                   + @c_Itemclass + ' AS @c_Itemclass ' + CHAR(13)
                   + @c_LocRoom   + ' AS @c_LocRoom   ' + CHAR(13)
                   + CAST(@n_packqty AS NVARCHAR) + ' AS @n_packqty ' + CHAR(13)
               BREAK
            END

            IF @n_pickqty <= @n_packqty  
            BEGIN  
               UPDATE #PickDetail_WIP WITH (ROWLOCK)  
               SET CaseID = @c_CaseID 
                  ,TrafficCop = NULL  
                  ,EditWho = SUSER_SNAME()
                  ,EditDate = GETDATE()
               WHERE Pickdetailkey = @c_pickdetailkey  

               SELECT @n_err = @@ERROR  

               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 87100  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #PickDetail_WIP Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  BREAK  
               END  

               SELECT @n_packqty = @n_packqty - @n_pickqty  
            END  
            ELSE  
            BEGIN  -- pickqty > packqty  
               SELECT @n_splitqty = @n_pickqty - @n_packqty  
               EXECUTE nspg_GetKey  
               'PICKDETAILKEY',  
               10,  
               @c_newpickdetailkey OUTPUT,  
               @b_success OUTPUT,  
               @n_err OUTPUT,  
               @c_errmsg OUTPUT  
               IF NOT @b_success = 1  
               BEGIN  
                  SELECT @n_continue = 3  
                  BREAK  
               END  

               INSERT #PickDetail_WIP  
               (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,  
                Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,  
                DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,  
                WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Channel_ID,
                TaskDetailKey, Notes, WIP_Refno
               )  
               SELECT @c_newpickdetailkey  
                    , ''
                    , PickHeaderKey, OrderKey, OrderLineNumber, Lot
                    , Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END, @n_splitqty, QtyMoved
                    , Status, DropID
                    , Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType
                    , ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod 
                    , WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, Channel_ID
                    , TaskDetailKey, Notes, @c_SourceType
               FROM #PickDetail_WIP (NOLOCK)  
               WHERE PickdetailKey = @c_pickdetailkey  
         
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 87105  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert #PickDetail_WIP Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  BREAK  
               END  
         
               UPDATE #PickDetail_WIP WITH (ROWLOCK)  
               SET CaseID = @c_CaseID 
                  ,Qty = @n_packqty  
                  ,UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END   
                  ,TrafficCop = NULL  
                  ,EditWho = SUSER_SNAME()
                  ,EditDate = GETDATE()
                WHERE Pickdetailkey = @c_pickdetailkey  

                SELECT @n_err = @@ERROR  

                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 87110  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #PickDetail_WIP Table Failed. (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                   BREAK  
                END  
         
               SELECT @n_packqty = 0  
            END  
         END -- While packqty > 0

         UPDATE #TMP_CASEID
         SET [Status] = 'DONE'
         WHERE CaseID = @c_CaseID

         NEXT_LOOP_UPD:
         FETCH NEXT FROM CUR_UPD INTO @c_Loadkey, @c_Pickzone, @c_SKU, @c_Itemclass, @c_LocRoom, @c_CaseID
                                    , @n_packqty, @c_SKUGroup, @c_Loc, @c_TaskDetailKey, @c_Site
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
      
      -----Update pickdetail_WIP work in progress staging table back to pickdetail 
      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                     , @c_Wavekey = @c_Wavekey
                                     , @c_WIP_RefNo = @c_SourceType
                                     , @c_PickCondition_SQL = ''
                                     , @c_Action = 'U' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
                                     , @c_RemoveTaskdetailkey = 'N' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
                                     , @b_Success = @b_Success OUTPUT
                                     , @n_Err = @n_err OUTPUT
                                     , @c_ErrMsg = @c_errmsg OUTPUT
      
         IF @b_Success <> 1
         BEGIN
            SET @n_Continue = 3
         END
      END

      IF @c_CallFrom = 'GenCaseID_1'
         GOTO RETURN_GenCaseID_1
      IF @c_CallFrom = 'GenCaseID_2'
         GOTO RETURN_GenCaseID_2
      IF @c_CallFrom = 'GenCaseID_3'
         GOTO RETURN_GenCaseID_3
   END
   
   CONTINUE_SP:

   -----Update Wave Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE WAVE WITH (ROWLOCK)
      SET TMReleaseFlag = 'Y'        
       ,  TrafficCop = NULL      
       ,  EditWho = SUSER_SNAME()
       ,  EditDate= GETDATE()    
      WHERE WAVEKEY = @c_wavekey  

      SELECT @n_err = @@ERROR  

      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 87115   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END 

   RETURN_SP:
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -----Delete pickdetail_WIP work in progress staging table
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_Wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'D' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
                                  , @c_RemoveTaskdetailkey = 'N' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_err OUTPUT
                                  , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
      END
   END

   IF (SELECT CURSOR_STATUS('LOCAL', 'CUR_NEWRPF')) >= 0
   BEGIN
      CLOSE CUR_NEWRPF
      DEALLOCATE CUR_NEWRPF
   END

   IF (SELECT CURSOR_STATUS('LOCAL', 'CUR_NEWRPF2')) >= 0
   BEGIN
      CLOSE CUR_NEWRPF2
      DEALLOCATE CUR_NEWRPF2
   END

   IF (SELECT CURSOR_STATUS('LOCAL', 'CUR_NEWRPF3')) >= 0
   BEGIN
      CLOSE CUR_NEWRPF3
      DEALLOCATE CUR_NEWRPF3
   END

   IF (SELECT CURSOR_STATUS('LOCAL', 'cur_GenCaseID_1')) >= 0
   BEGIN
      CLOSE cur_GenCaseID_1
      DEALLOCATE cur_GenCaseID_1
   END

   IF (SELECT CURSOR_STATUS('LOCAL', 'cur_GenCaseID_2')) >= 0
   BEGIN
      CLOSE cur_GenCaseID_2
      DEALLOCATE cur_GenCaseID_2
   END

   IF (SELECT CURSOR_STATUS('LOCAL', 'CUR_UPD')) >= 0
   BEGIN
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   IF OBJECT_ID('tempdb..#TMP_CASEID') IS NOT NULL
      DROP TABLE #TMP_CASEID

   IF OBJECT_ID('tempdb..#TMP_CODELKUP') IS NOT NULL
      DROP TABLE #TMP_CODELKUP

   IF OBJECT_ID('tempdb..#DYNPICK_LOCASSIGNED') IS NOT NULL
      DROP TABLE #DYNPICK_LOCASSIGNED

   IF OBJECT_ID('tempdb..#DYNPICK_TASK') IS NOT NULL
      DROP TABLE #DYNPICK_TASK

   IF OBJECT_ID('tempdb..#DYNPICK_NON_EMPTY') IS NOT NULL
      DROP TABLE #DYNPICK_NON_EMPTY

   IF OBJECT_ID('tempdb..#DYNLOC') IS NOT NULL
      DROP TABLE #DYNLOC

   IF OBJECT_ID('tempdb..#EXCLUDELOC') IS NOT NULL
      DROP TABLE #EXCLUDELOC

   IF OBJECT_ID('tempdb..#SAFETYSTOCK_LOCASSIGNED') IS NOT NULL
      DROP TABLE #SAFETYSTOCK_LOCASSIGNED

   IF OBJECT_ID('tempdb..#SAFETYSTOCK_TASK') IS NOT NULL
      DROP TABLE #SAFETYSTOCK_TASK

   IF OBJECT_ID('tempdb..#SAFETYSTOCK_NON_EMPTY') IS NOT NULL
      DROP TABLE #SAFETYSTOCK_NON_EMPTY

   IF OBJECT_ID('tempdb..#SAFETYSTOCK_LOC') IS NOT NULL
      DROP TABLE #SAFETYSTOCK_LOC

   IF OBJECT_ID('tempdb..#SAFETYSTOCK_EXCLUDELOC') IS NOT NULL
      DROP TABLE #SAFETYSTOCK_EXCLUDELOC
      
   IF @n_Continue = 3 -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV50'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      --RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
   --RETURN
   END

--WHILE @@TRANCOUNT < @n_StartTranCnt
--   BEGIN TRAN
END

GO