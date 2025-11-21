SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLWAV08                                          */  
/* Creation Date: 10-Apr-2017                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-1587 - CN&SG - Logitech Wave Release Pick Tasks          */  
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 20-Jul-2017 NJOW01   1.O   WMS-2441 allow re-release with added orders*/
/* 31-Jul-2017 NJOW02   1.1   Fix FP checking cater for multi sku        */
/* 22-Aug-2017 NJOW03   1.2   WMS-2770 Skip generate replenishmet task   */
/*                            if found available replenish from other    */
/*                            wave.                                      */
/* 06-Jun-2018 NJOW04   1.3   WMS-5591 DPP Location distinguish by       */
/*                            lottable08                                 */
/* 06-Jun-2019 TLTING01 1.4   deadlock tune                              */ 
/* 03-Jan-2020 NJOW05   1.5   WMS-11656 Disable replenishment loose pick */
/*                            to DPP for SG                              */
/* 01-04-2020  Wan01    1.6   Sync Exceed & SCE                          */
/* 15-05-2022  NJOW06   1.7   WMS-19647 if full pallet pick with multi   */
/*                            Wave set pickmethod as PP                  */
/* 15-05-2022  NJOW06   1.7   DEVOPS Combine script                      */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV08]      
  @c_wavekey      NVARCHAR(10)  
 ,@b_Success      int        OUTPUT  
 ,@n_err          int        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @n_cnt int
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0

    DECLARE  @c_Storerkey NVARCHAR(15)
            ,@c_Sku NVARCHAR(20)
            ,@c_Lot NVARCHAR(10)
            ,@c_FromLoc NVARCHAR(10)
            ,@c_FromID NVARCHAR(18)
            ,@c_ID NVARCHAR(18)
            ,@n_Qty INT
            ,@n_TakeQty INT
            ,@n_CaseCnt INT
            ,@c_Priority NVARCHAR(10)
            ,@c_Areakey NVARCHAR(20)
            ,@c_PickMethod NVARCHAR(10)
            ,@c_Toloc NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)  
            ,@c_UOM NVARCHAR(10)
            ,@c_DestinationType NVARCHAR(30)
            ,@c_SourceType NVARCHAR(30)
            ,@c_Pickdetailkey NVARCHAR(18)
            ,@c_NewPickdetailKey NVARCHAR(18)
            ,@n_Pickqty INT
            ,@n_ReplenQty INT
            ,@n_SplitQty  INT
            ,@c_Pickslipno NVARCHAR(10)
            ,@c_TaskType NVARCHAR(10)
            ,@c_FPLoc NVARCHAR(10) --Pack Station for full pallet
            ,@c_CSLoc NVARCHAR(10) --Pack Station for full case
            ,@c_EALoc NVARCHAR(10) --Pack Station for piece (replen fromm bulk to DPP, pick from DPP to piece pack station)
            ,@c_DPPLoc NVARCHAR(10) --DPP location 
            ,@c_DispatchPalletPickMethod NVARCHAR(10)
            ,@c_DispatchCasePickMethod NVARCHAR(10)
            ,@c_DispatchPiecePickMethod NVARCHAR(10)
            ,@c_Loadkey NVARCHAR(10)
            ,@n_UOMQty INT
            ,@c_Facility NVARCHAR(5)
            ,@c_Pickdetailloc NVARCHAR(10)
            ,@c_pickdetailtoloc NVARCHAR(10)           
            ,@c_pickdetailID NVARCHAR(18)
            ,@c_pickdetailReplenishZone NVARCHAR(10)
            ,@c_FoundTaskdetailkey NVARCHAR(10) --NJOW03
            ,@c_FoundDPPLoc NVARCHAR(10) --NJOW03
            ,@c_FoundID NVARCHAR(18) --NJOW03
            ,@c_RefTaskkey NVARCHAR(10) --NJOW03
            ,@c_Message03 NVARCHAR(20) --NJOW03           
            ,@c_Lottable08 NVARCHAR(30) --NJOW04
            ,@c_Country NVARCHAR(10) --NJOW05

    SET @c_SourceType = 'ispRLWAV08'    
    
    --NJOW05
    SELECT @c_Country = NSQLValue
    FROM NSQLCONFIG (NOLOCK) 
    WHERE Configkey = 'COUNTRY'

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_Sourcetype AND TD.Tasktype IN('FPK','FCP','RPF')
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 82010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV08)'       
       END
    END
    
    /*  --NJOW01 Remove
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = 'ispRLWAV08'
                   AND TD.Tasktype IN('FPK','FCP','RPF'))
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 82020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV08)'       
        END                 
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 
                  FROM WAVEDETAIL WD(NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                  WHERE O.Status > '2'
                  AND WD.Wavekey = @c_Wavekey)
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 82030    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV08)'         
        END                 
    END
    */    
    
    -----Get Storerkey, facility and dispatch method
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility,
                     @c_DispatchPalletPickMethod = W.DispatchPalletPickMethod,
                     @c_DispatchCasePickMethod =  W.DispatchCasePickMethod,
                     @c_DispatchPiecePickMethod = W.DispatchPiecePickMethod
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey 
    END

    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS(SELECT 1 FROM PickDetail_WIP WITH (NOLOCK)
                 WHERE WaveKey = @c_Wavekey AND WIP_Refno = @c_SourceType)
       BEGIN
         DELETE PickDetail_WIP 
         WHERE WaveKey = @c_Wavekey      
         AND WIP_Refno = @c_SourceType    
       END 
       
       INSERT INTO PickDetail_WIP 
       (
         PickDetailKey,      CaseID,             PickHeaderKey,
         OrderKey,           OrderLineNumber, Lot,
         Storerkey,          Sku,                AltSku,     UOM,
         UOMQty,              Qty,               QtyMoved,   [Status],
         DropID,              Loc,             ID,        PackKey,
         UpdateSource,       CartonGroup,     CartonType,
         ToLoc,               DoReplenish,     ReplenishZone,
         DoCartonize,        PickMethod,      WaveKey,
         EffectiveDate,      AddDate,         AddWho,
         EditDate,           EditWho,         TrafficCop,
         ArchiveCop,         OptimizeCop,     ShipFlag,
         PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,
         Notes,               MoveRefKey,        WIP_RefNo 
       )
       SELECT PD.PickDetailKey,  PD.CaseID,                    PD.PickHeaderKey, 
         PD.OrderKey,                PD.OrderLineNumber,  PD.Lot,
         PD.Storerkey,               PD.Sku,             PD.AltSku,        PD.UOM,
         PD.UOMQty,                  PD.Qty,             PD.QtyMoved,      PD.[Status],
         PD.DropID,                  PD.Loc,             PD.ID,             PD.PackKey,
         PD.UpdateSource,            PD.CartonGroup,      PD.CartonType,
         PD.ToLoc,                   PD.DoReplenish,      PD.ReplenishZone,
         PD.DoCartonize,             PD.PickMethod,       WD.Wavekey,
         PD.EffectiveDate,           PD.AddDate,           PD.AddWho,
         PD.EditDate,                PD.EditWho,           PD.TrafficCop,
         PD.ArchiveCop,              PD.OptimizeCop,      PD.ShipFlag,
         PD.PickSlipNo,              PD.TaskDetailKey,    PD.TaskManagerReasonKey,
         PD.Notes,                   PD.MoveRefKey,            @c_SourceType 
       FROM WAVEDETAIL WD (NOLOCK) 
       JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
       LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_Sourcetype AND TD.Tasktype IN('FPK','FCP','RPF') --NJOW01     
       WHERE WD.Wavekey = @c_Wavekey
       AND TD.Taskdetailkey IS NULL --NJOW01
       
       SET @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82040     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END      
    END

    --Remove invalid taskdetailkey 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
         UPDATE PICKDETAIL_WIP WITH (ROWLOCK) 
         SET PICKDETAIL_WIP.TaskdetailKey = '',
             PICKDETAIL_WIP.TrafficCop = NULL
         FROM WAVEDETAIL (NOLOCK)  
         JOIN PICKDETAIL_WIP ON WAVEDETAIL.Orderkey = PICKDETAIL_WIP.Orderkey AND WAVEDETAIL.Wavekey = PICKDETAIL_WIP.Wavekey
         LEFT JOIN TASKDETAIL TD (NOLOCK) ON PICKDETAIL_WIP.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_Sourcetype AND TD.Tasktype IN('FPK','FCP','RPF')  --NJOW01
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey
          AND PICKDETAIL_WIP.WIP_Refno = @c_SourceType             
         AND TD.Taskdetailkey IS NULL  --NJOW01
         
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82050  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 
    END
    
    -----Create LOC BY ID data temporary table for full/partial pallet picking checking (FP/PP) for Bulk Pallet loc
    IF (@n_continue = 1 OR @n_continue = 2) 
    BEGIN      
       --Current wave assigned dynamic pick location
       CREATE TABLE #DYNPICK_LOCASSIGNED (RowId BIGINT Identity(1,1) PRIMARY KEY
                                         ,STORERKEY NVARCHAR(15) NULL
                                         ,SKU NVARCHAR(20) NULL
                                         ,TOLOC NVARCHAR(10) NULL
                                         ,Lottable08 NVARCHAR(30) NULL)  --NJOW04
       CREATE INDEX IDX_AS1 ON #DYNPICK_LOCASSIGNED (TOLOC)
       CREATE INDEX IDX_AS2 ON #DYNPICK_LOCASSIGNED (STORERKEY,SKU)

       CREATE TABLE #DYNPICK_TASK (RowId BIGINT Identity(1,1) PRIMARY KEY, TOLOC NVARCHAR(10) NULL)

       CREATE TABLE #DYNPICK_NON_EMPTY (RowId BIGINT Identity(1,1) PRIMARY KEY, LOC NVARCHAR(10) NULL)
       CREATE INDEX IDX_EMPTY ON #DYNPICK_NON_EMPTY (LOC)

       --Dynamic pick loc have qty and pending move in
       INSERT INTO #DYNPICK_NON_EMPTY (LOC)
       SELECT LLI.LOC
       FROM   LOTxLOCxID LLI (NOLOCK)
       JOIN   LOC L (NOLOCK) ON LLI.LOC = L.LOC
       WHERE  (L.LocationType = 'DYNPPICK' OR L.LocationCategory = 'DYNPPICK')
       AND    L.Facility = @c_Facility
       GROUP BY LLI.LOC
       HAVING SUM((LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) - LLI.QtyPicked ) > 0

       --location have pending Replenishment tasks
       INSERT INTO #DYNPICK_TASK (TOLOC)
       SELECT TD.ToLoc 
       FROM TASKDETAIL TD (NOLOCK)
       JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
       WHERE (L.LocationType = 'DYNPPICK' OR L.LocationCategory = 'DYNPPICK') 
       AND TD.TaskType = 'RPF'
       AND L.Facility = @c_Facility
       AND TD.SourceType = @c_SourceType
       AND TD.Status = '0'
       AND TD.Qty > 0
       GROUP BY TD.ToLoc
       
       --get qty available of bulk pallet location       
       SELECT LLI.Storerkey, LLI.Loc, LLI.ID, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS LOCXID_QTYAVAILABLE,
              COUNT(DISTINCT LLI.Sku) AS SkuCnt,  --NJOW02
              ISNULL(W.WaveCnt,0) As WaveCnt --NJOW06
       INTO #LOCXID_QTYAVAILABLE
       FROM LOTXLOCXID LLI WITH (NOLOCK)
       JOIN LOC            WITH (NOLOCK) ON LLI.Loc = LOC.Loc
       OUTER APPLY (SELECT COUNT(DISTINCT WD.Wavekey) AS WaveCnt
                    FROM PICKDETAIL PD (NOLOCK)
                    JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey
                    LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_Sourcetype AND TD.Tasktype IN('FPK','FCP','RPF')
                    WHERE PD.Storerkey = LLI.Storerkey AND PD.Loc = LLI.Loc AND PD.Id = LLI.ID
                    AND TD.Taskdetailkey IS NULL
                    AND PD.Status < '5') AS W  --NJOW06
       --JOIN SKUXLOC SL     WITH (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
       WHERE LLI.Storerkey = @c_Storerkey
       AND LLI.Qty > 0
       --AND SL.LocationType NOT IN('PICK','CASE')       
       AND LOC.LocationType NOT IN('DYNPPICK','PICK','CASE')
       AND LOC.LocationCategory NOT IN('DYNPPICK','SHELVING')
       AND LOC.LocationHandling <> '2'  --Not Case pick loc
       GROUP BY LLI.Storerkey, LLI.Loc, LLI.ID, W.WaveCnt   
    END
     
    -----Create pick task for full pallet & carton. Create replenish task for loose(replen full carton) to DPP & Create pick task from DPP to pack station
    -----pickdetail to be replenish will be moved to DPP with overallocation waiting for RDT replenishment
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN             
       
       --Get full pallet pack station
       /*SELECT @c_FPLoc = Short
       FROM CODELKUP(NOLOCK)       
       WHERE Listname = 'DIPALPKMTD'
       AND Code = @c_DispatchPalletPickMethod*/
       
       --Get full case pack station
       SELECT @c_CSLoc = Short,
              @c_FPLoc = Short,
              @c_EALoc = Short
       FROM CODELKUP(NOLOCK)       
       WHERE Listname = 'DICSEPKMTD'
       AND Code = @c_DispatchCasePickMethod 

       --Get piece pack station
       /*SELECT @c_EALoc = Short
       FROM CODELKUP(NOLOCK)       
       WHERE Listname = 'DIPCEPKMTD'
       AND Code = @c_DispatchPiecePickMethod*/

       SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM,
              CASE WHEN PD.UOM = '1' OR 
                       (LOC.LocationType NOT IN('PICK','CASE','DYNPPICK') AND LOC.LocationCategory NOT IN('DYNPPICK','SHELVING') 
                        AND LOC.LocationHandling <> '2' AND 
                        ((ISNULL(QA.LOCXID_QTYAVAILABLE,0) < PACK.Casecnt AND QA.SkuCnt = 1) OR ISNULL(QA.LOCXID_QTYAVAILABLE,0) = 0) AND ISNULL(QA.WaveCnt,0) < 2) THEN --if last partial carton from bulk will take full pallet also   --NJOW02  --NJOW06 if more than 1 Wave not FC
                        'FP'                           
                   ELSE 'PP' END AS PickMethod,
              CASE WHEN PD.UOM IN('6','7') AND LOC.LocationType NOT IN('PICK','CASE','DYNPPICK') AND LOC.LocationCategory <> 'DYNPPICK' THEN 'DPP' ELSE 'PACKSTATION' END AS DestinationType, --if full pallet/case pick to pack station. if partil carton from bulk replen to dpp then DPP pick to pack station
              CASE WHEN PD.UOM IN('6','7') AND LOC.LocationType NOT IN('PICK','CASE','DYNPPICK') AND LOC.LocationCategory <> 'DYNPPICK' THEN  
                      CEILING(SUM(PD.Qty) / (PACK.Casecnt * 1.00)) * PACK.Casecnt   -- convert to take full case if from bulk
                   ELSE SUM(PD.Qty)  
              END AS TakeQty,
              LOC.LocationType,
              LOC.LocationCategory,
              LOC.LocationHandling,
              PACK.CaseCnt,
              --(SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) FROM LOTXLOCXID LLI (NOLOCK) 
              (SELECT SUM(LLI.Qty - LLI.QtyPicked) FROM LOTXLOCXID LLI (NOLOCK)  --NJOW03  
               WHERE LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.Id = PD.Id) AS QtyAvailable,
              MAX(O.Loadkey) AS Loadkey
       INTO #TMP_PICK              
       FROM WAVEDETAIL WD (NOLOCK)
       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
       JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND WD.Wavekey = PD.Wavekey AND PD.WIP_RefNo = @c_SourceType
       JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
       JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
       JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
       LEFT JOIN #LOCXID_QTYAVAILABLE QA ON PD.Storerkey = QA.Storerkey AND PD.Loc = QA.Loc AND PD.Id = QA.Id
       WHERE WD.Wavekey = @c_Wavekey
       AND PD.Status = '0'
       GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LocationType, PACK.CaseCnt, --PD.Pickmethod, 
                LOC.LocationCategory, LOC.LocationHandling,
                CASE WHEN PD.UOM = '1' OR 
                         (LOC.LocationType NOT IN('PICK','CASE','DYNPPICK') AND LOC.LocationCategory NOT IN('DYNPPICK','SHELVING') 
                          AND LOC.LocationHandling <> '2' AND 
                          ((ISNULL(QA.LOCXID_QTYAVAILABLE,0) < PACK.Casecnt  AND QA.SkuCnt = 1) OR ISNULL(QA.LOCXID_QTYAVAILABLE,0) = 0) AND ISNULL(QA.WaveCnt,0) < 2) THEN  --NJOW02  --NJOW06
                          'FP'                          
                     ELSE 'PP' END,
                CASE WHEN PD.UOM IN('6','7') AND LOC.LocationType NOT IN('PICK','CASE','DYNPPICK') AND LOC.LocationCategory <> 'DYNPPICK' THEN 'DPP' ELSE 'PACKSTATION' END
       ORDER BY PD.Storerkey, PD.UOM, PD.Sku, PD.Lot       
       
       DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT TP.Storerkey, TP.Sku, TP.Lot, TP.Loc, TP.ID, SUM(TP.Qty) AS Qty,             
                   CASE WHEN TP.UOM IN('6','7') AND TP.LocationType NOT IN('PICK','CASE','DYNPPICK') AND TP.LocationCategory <> 'DYNPPICK' THEN --loose allocation from bulk convert to carton replen
                        '2'
                        ELSE TP.UOM 
                   END AS UOM,
                   TP.PickMethod, TP.DestinationType, 
                   --SUM(CASE WHEN (TP.TakeQty - TP.Qty) > TP.QtyAvailable THEN TP.Qty ELSE TP.TakeQty END) AS TakeQty, --if partial allocate(uom 6,7) convert to full case but not enough qty then take allocate qty
                   SUM(CASE WHEN (TP.TakeQty - TP.Qty) > TP.QtyAvailable - TP.Qty THEN TP.Qty ELSE TP.TakeQty END) AS TakeQty, --if partial allocate(uom 6,7) convert to full case but not enough qty then take allocate qty  --NJOW05  
                   TP.Casecnt,
                   TP.Loadkey,
                   LA.Lottable08 --NJOW04
            FROM #TMP_PICK TP
            JOIN LOTATTRIBUTE LA (NOLOCK) ON TP.Lot = LA.Lot  --NJOW04                        
            GROUP BY TP.Storerkey, TP.Sku, TP.Lot, TP.Loc, TP.ID,
                   CASE WHEN TP.UOM IN('6','7') AND TP.LocationType NOT IN('PICK','CASE','DYNPPICK') AND TP.LocationCategory <> 'DYNPPICK' THEN
                        '2'
                        ELSE TP.UOM 
                   END,
                   TP.PickMethod, TP.DestinationType, TP.CaseCnt, TP.QtyAvailable, TP.Loadkey, LA.Lottable08 --NJOW04
            ORDER BY TP.DestinationType, 6, TP.Sku, TP.Loc
              
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_FromID, @n_Qty, @c_UOM, 
                                     @c_PickMethod, @c_DestinationType, @n_TakeQty, @n_CaseCnt, @c_Loadkey, @c_Lottable08 --NJOW04
       
       WHILE @@FETCH_STATUS = 0  
       BEGIN   
                   
           SET @c_ID = @c_FromID
           
           --NJOW03
           SET @c_RefTaskkey = '' 
           SET @c_Message03 = ''  
           SET @c_FoundTaskdetailkey = ''
           SET @c_FoundDPPLoc = '' 
           SET @c_FoundID = ''
           
          --NJOW05
           IF @c_Country = 'SG' AND @c_DestinationType = 'DPP'
           BEGIN
              SET @c_DestinationType = 'PACKSTATION'  --Skip replenish loose from bulk to DPP and diect pick to Packstation for SG only
              SET @n_TakeQty = @n_Qty  --take allocated qty only no convert to full case
           END

          --Full Pallet/Case pick to pack station
           IF @c_DestinationType = 'PACKSTATION'           
           BEGIN
             SET @c_Priority = '9'
             SET @c_Areakey = 'PACKSTATION'

             --Full pallet pick to pack station
             IF @c_PickMethod = 'FP'
             BEGIN
                 SET @c_ToLoc = @c_FPLoc
                  SET @c_TaskType = 'FPK'
                  SET @c_UOM =  '1'
                  SET @n_UOMQty = 1
               END

            --Full case pick to pack station
              IF @c_PickMethod = 'PP'
              BEGIN
                 SET @c_ToLoc = @c_CSLoc
                  SET @c_TaskType = 'FCP'
                  SET @n_UOMQty =  CEILING(@n_TakeQty / @n_Casecnt) 
              END
    
             GOTO INSERT_TASKS
             RTN_INSERT_TASKS:              
           END
 
          --Piece replen to DDP by carton and Pick from DPP to Pack station
           IF @c_DestinationType = 'DPP' 
           BEGIN                       
             --NJOW03 Start
             --find pending replen from other wave. if available skip replen
             SELECT TOP 1 @c_FoundTaskDetailKey = TD.Taskdetailkey, @c_FoundDPPLoc = TD.ToLoc, @c_FoundID = TD.ToID
             FROM TASKDETAIL TD (NOLOCK)
             JOIN LOTXLOCXID LLI (NOLOCK) ON TD.Lot = LLI.Lot AND TD.ToLoc = LLI.Loc
             AND TD.TaskType = 'RPF'
             AND TD.SourceType = @c_SourceType
             AND TD.Status = '0'
             AND TD.Qty > 0
             AND TD.Lot = @c_Lot
             AND TD.Wavekey <> @c_Wavekey
             GROUP BY TD.Taskdetailkey, TD.ToLoc, TD.Qty, TD.ToID
             HAVING TD.Qty - SUM(LLI.QtyExpected) >= @n_Qty
             
             --find DPP already have stock just replenished by other wave
             IF ISNULL(@c_FoundDPPLoc,'') = ''
             BEGIN
                SELECT TOP 1 @c_FoundDPPLoc = L.LOC, @c_FoundID = LLI.Id
                FROM LOTxLOCxID LLI (NOLOCK)
                JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC
                WHERE (L.LocationType = 'DYNPPICK' OR L.LocationCategory = 'DYNPPICK') 
                AND   L.Facility = @c_Facility
                AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) >= @n_Qty
                AND  LLI.Lot = @c_Lot
                ORDER BY L.LogicalLocation, L.Loc               
             END
             --NJOW03 End
             
             IF ISNULL(@c_FoundDPPLoc,'') <> '' --NJOW03
             BEGIN
                SET @c_DPPLoc = @c_FoundDPPLoc
                SET @c_ToLoc = @c_FoundDPPLoc
                SET @c_ID = @c_FoundID
                IF ISNULL(@c_FoundTaskDetailKey,'') <> ''
                BEGIN
                   SET @c_RefTaskkey = @c_FoundTaskdetailkey
                   SET @c_Message03 = 'REPLEN BY OTH WAVE'
                END
                ELSE
                BEGIN
                   SET @c_Message03 = 'DPP HAVE STOCK'
                END
             END
             ELSE
             BEGIN
                --create carton replen task to DPP
                 SET @c_Priority = '5'
                SET @c_Areakey = 'DPP'
                  SET @c_TaskType = 'RPF'
                SET @n_UOMQty =  CEILING(@n_TakeQty / @n_Casecnt)
                
                GOTO FIND_DPP_LOC
                RTN_FIND_DPP_LOC:
                
                 SET @c_ToLoc = @c_DPPLoc

                GOTO INSERT_TASKS
                RTN_INSERT_TASKS_REPLENDPP:
                
                SET @c_RefTaskkey = @c_Taskdetailkey --NJOW03
              END
             
             IF EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE Loc = @c_DPPLoc AND loseid = '1')
                SET @c_ID = ''  --DPP loc will lose id
             
             --Move the replenish pickdetail to DPP with overallocation (allow overallocate must be enabled and loc.locationcategory must be DYNPPICK)
             UPDATE PICKDETAIL_WIP
             SET PICKDETAIL_WIP.Loc = @c_DPPLoc,
                 PICKDETAIL_WIP.Toloc = @c_FromLoc, --store as previous loc(bulk) after move to DPP for reversal use
                 PICKDETAIL_WIP.ReplenishZone = RIGHT(RTRIM(@c_FromID),10), --storer as previous id(bulk) after move to DPP with loose id for revseral use
                 PICKDETAIL_WIP.Id = @c_ID
             FROM PICKDETAIL_WIP 
             WHERE PICKDETAIL_WIP.Lot = @c_Lot
             AND PICKDETAIL_WIP.Loc = @c_FromLoc
             AND PICKDETAIL_WIP.ID = @c_FromId
             AND PICKDETAIL_WIP.UOM IN ('6','7')
             AND PICKDETAIL_WIP.Wavekey = @c_Wavekey
             AND PICKDETAIL_WIP.WIP_Refno = @c_SourceType   

                          
             --create piece pick task from DPP to pack station
             SET @n_TakeQty = @n_Qty --replen qty(takeqty) from bulk to DPP already convert to full case, now from DPP to pack station convert back to actual order(pick) qty
             SET @c_FromLoc = @c_DPPLoc --pick from DPP location after replenish as above
              SET @c_ToLoc = @c_EALoc
              SET @c_Priority = '9'
             SET @c_Areakey = 'PACKSTATION'
               SET @c_TaskType = 'FCP'
               SET @c_PickMethod = 'PP'                        
               SET @c_UOM =  '6'              
             SET @n_UOMQty = @n_TakeQty

             GOTO INSERT_TASKS
             RTN_INSERT_TASKS_PICKDPP:
           END                        
               
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_FromID, @n_Qty, @c_UOM, 
                                        @c_PickMethod, @c_DestinationType, @n_TakeQty, @n_CaseCnt, @c_Loadkey, @c_Lottable08 --NJOW04
       END 
       CLOSE cur_pick  
       DEALLOCATE cur_pick                                                
    END  
          
    -----Generate Pickslip No-------
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN
       DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT DISTINCT ORDERS.Loadkey
          FROM   WAVEDETAIL (NOLOCK)  
          JOIN  ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
          WHERE  WAVEDETAIL.Wavekey = @c_wavekey   
          ORDER BY ORDERS.Loadkey
  
       OPEN CUR_LOAD  
  
       FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey   
  
       WHILE @@FETCH_STATUS <> -1  
       BEGIN  
          SET @c_PickSlipno = ''      
          SELECT @c_PickSlipno = PickheaderKey  
          FROM   PICKHEADER (NOLOCK)  
          WHERE  ExternOrderkey = @c_Loadkey
          AND ISNULL(Orderkey,'') = ''
                             
          -- Create Pickheader      
          IF ISNULL(@c_PickSlipno, '') = ''  
          BEGIN  
             EXECUTE nspg_GetKey   
             'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT      
                
             SELECT @c_Pickslipno = 'P' + @c_Pickslipno      
                        
             INSERT INTO PICKHEADER  
               (PickHeaderKey, Wavekey, Orderkey, ExternOrderkey ,PickType, Zone, TrafficCop)  
             VALUES  
               (@c_Pickslipno, @c_Wavekey, '', @c_Loadkey, '0' ,'7', '')      
               
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END  
          END 
       
          UPDATE PICKDETAIL_WIP WITH (ROWLOCK)  
          SET    PICKDETAIL_WIP.PickSlipNo = @c_PickSlipNo  
                ,TrafficCop = NULL  
          FROM PICKDETAIL_WIP
          JOIN ORDERS (NOLOCK) ON PICKDETAIL_WIP.Orderkey = ORDERS.Orderkey
          JOIN Loadplandetail (NOLOCK) ON Loadplandetail.Orderkey = ORDERS.Orderkey  --tlting01
          WHERE Loadplandetail.Loadkey = @c_Loadkey  
          AND PICKDETAIL_WIP.WIP_Refno = @c_SourceType             

          SELECT @n_err = @@ERROR  
          IF @n_err <> 0  
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END  
          
          /*
          IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookUp WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
          BEGIN
             INSERT INTO dbo.RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
             SELECT PickdetailKey, PickSlipNo, OrderKey, OrderLineNumber 
             FROM PICKDETAIL_WIP (NOLOCK)  
             WHERE PickSlipNo = @c_PickSlipNo  
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0   
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060     
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
             END   
          END
          */        
            
          FETCH NEXT FROM CUR_LOAD INTO @c_LoadKey      
       END   
       CLOSE CUR_LOAD  
       DEALLOCATE CUR_LOAD 
    END      
    
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT PickDetailKey,Storerkey, Sku, Qty, UOMQty, PickSlipNo, TaskDetailKey, loc, ToLoc, lot, id, ReplenishZone
       FROM PickDetail_WIP WITH (NOLOCK)
       WHERE WaveKey = @c_Wavekey 
       AND WIP_Refno = @c_SourceType   
       ORDER BY PickDetailKey 
             
       OPEN cur_PickDetailKey
       
       FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @c_Storerkey, @c_Sku, @n_Qty, @n_UOMQty, @c_PickslipNo, @c_TaskDetailkey, @c_Pickdetailloc, @c_pickdetailtoloc, @c_lot, @c_pickdetailID, @c_pickdetailreplenishzone   --pickdetailtoloc previouse loc(bulk)
       
       WHILE @@FETCH_STATUS = 0
       BEGIN
          IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
                    WHERE PickDetailKey = @c_PickDetailKey)
          BEGIN
                IF EXISTS(SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE Pickdetailkey = @c_PickDetailkey AND Loc <> @c_Pickdetailloc) --pickdetail change location
                BEGIN
               --IF EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE Loc = @c_Pickdetailloc AND loseid = '1')
                --   SET @c_ID = ''  --DPP loc will lose id
                --ELSE
                --   SET @c_ID = @c_pickdetailID   
                  
                    --need to create dummy lotxlocxid and skuxloc if not exist for overallocation
                    IF NOT EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK) WHERE lot = @c_Lot AND loc = @c_pickdetailloc AND Id = @c_pickdetailID  )
                    BEGIN
                      INSERT INTO LOTXLOCXID (Storerkey, Sku, Lot, Loc, Id, Qty)
                      VALUES (@c_Storerkey, @c_Sku, @c_Lot, @c_PickdetailLoc, @c_pickdetailID  , 0)
                      
                   SELECT @n_err = @@ERROR
             
                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue = 3  
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 820586   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Lotxlocxid Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                      END                              
                    END

                    IF NOT EXISTS(SELECT 1 FROM SKUXLOC (NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku AND loc = @c_pickdetailloc)
                    BEGIN
                      INSERT INTO SKUXLOC (Storerkey, Sku, Loc, Qty)
                      VALUES (@c_Storerkey, @c_Sku, @c_PickdetailLoc, 0)
                      
                   SELECT @n_err = @@ERROR
             
                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue = 3  
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 820587   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Skuxloc Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                      END                              
                    END
                    
                UPDATE PICKDETAIL WITH (ROWLOCK) 
                SET Loc = @c_Pickdetailloc,
                    ID = @c_pickdetailid, 
                    ToLoc = @c_pickdetailtoloc,
                    ReplenishZone = @c_pickdetailreplenishzone
                WHERE PickDetailKey = @c_PickDetailKey  

                SELECT @n_err = @@ERROR
             
                IF @n_err <> 0
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82058   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                   END                              
                END                        
            
             UPDATE PICKDETAIL WITH (ROWLOCK) 
             SET Qty = @n_Qty, 
                 UOMQty = @n_UOMQty, 
                 PickSlipNo = @c_PickslipNo,
                 TaskDetailKey = @c_TaskDetailKey,
                 WaveKey = @c_Wavekey,
                 EditDate = GETDATE(),                             
                 TrafficCop = NULL
             WHERE PickDetailKey = @c_PickDetailKey  
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END                              
          END
          ELSE 
          BEGIN            
             INSERT INTO PICKDETAIL 
                  (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                   Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                   DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                   WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
                   Taskdetailkey, TaskManagerReasonkey, Notes )
             SELECT PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                   Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                   DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                   WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, 
                   Taskdetailkey, TaskManagerReasonkey, Notes
             FROM PICKDETAIL_WIP WITH (NOLOCK)
             WHERE PickDetailKey = @c_PickDetailKey
             AND PICKDETAIL_WIP.Wavekey = @c_Wavekey
             AND PICKDETAIL_WIP.WIP_Refno = @c_SourceType   
             
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END         
          END
       
           FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @c_Storerkey, @c_Sku, @n_Qty, @n_UOMQty, @c_PickslipNo, @c_TaskDetailkey, @c_Pickdetailloc, @c_pickdetailtoloc, @c_lot, @c_pickdetailID, @c_pickdetailreplenishzone
       END   
       CLOSE cur_PickDetailKey
       DEALLOCATE cur_PickDetailKey      
    END
    
    -----remove records from pickdetail working table
    IF EXISTS(SELECT 1 FROM PickDetail_WIP WITH (NOLOCK)
              WHERE WaveKey = @c_Wavekey)
    BEGIN
       DELETE PickDetail_WIP 
       WHERE WaveKey = @c_Wavekey 
       AND WIP_Refno = @c_SourceType   
    END               
    
    -----Update Wave Status-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       UPDATE WAVE 
          --SET STATUS = '1' -- Released        --(Wan01) 
          SET TMReleaseFlag = 'Y'               --(Wan01) 
           ,  TrafficCop = NULL                 --(Wan01) 
           ,  EditWho = SUSER_SNAME()           --(Wan01) 
           ,  EditDate= GETDATE()               --(Wan01) 
       WHERE WAVEKEY = @c_wavekey  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
RETURN_SP:

    IF @n_continue=3  -- Error Occured - Process And Return  
    BEGIN  
       SELECT @b_success = 0  
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          ROLLBACK TRAN  
       END  
       ELSE  
       BEGIN  
          WHILE @@TRANCOUNT > @n_starttcnt  
          BEGIN  
             COMMIT TRAN  
          END  
       END  
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV08"  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN  
    END  
    ELSE  
    BEGIN  
       SELECT @b_success = 1  
       WHILE @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          COMMIT TRAN  
       END  
       RETURN  
    END

 --------------------Function to insert taskdetail & pickdetail update (qtyreplen, taskdetailkey)---------------------     
 INSERT_TASKS:

 SELECT @b_success = 1  
 EXECUTE   nspg_getkey  
 "TaskDetailKey"  
 , 10  
 , @c_taskdetailkey OUTPUT  
 , @b_success OUTPUT  
 , @n_err OUTPUT  
 , @c_errmsg OUTPUT  
 IF NOT @b_success = 1  
 BEGIN  
    SELECT @n_continue = 3  
 END  

 IF @b_success = 1  
 BEGIN      
   INSERT TASKDETAIL  
    (  
      TaskDetailKey  
     ,TaskType  
     ,Storerkey  
     ,Sku  
     ,UOM  
     ,UOMQty  
     ,Qty  
     ,SystemQty
     ,Lot  
     ,FromLoc  
     ,FromID  
     ,ToLoc  
     ,ToID  
     ,SourceType  
     ,SourceKey  
     ,Priority  
     ,SourcePriority  
     ,Status  
     ,LogicalFromLoc  
     ,LogicalToLoc  
     ,PickMethod
     ,Wavekey
     ,Areakey
     ,Loadkey
     ,RefTaskkey --NJOW03
     ,Message03 --NJOW03
    )  
    VALUES  
    (  
      @c_taskdetailkey  
     ,@c_TaskType --Tasktype  FPK/SCP 
     ,@c_Storerkey  
     ,@c_Sku  
     ,@c_UOM -- UOM,  
     ,@n_UOMQty  -- UOMQty,  
     ,@n_TakeQty --pick/replenishment qty
     ,@n_Qty  --systemqty allocated qty
     ,@c_Lot   
     ,@c_fromloc   
     ,@c_ID -- from id  
     ,@c_toloc 
     ,@c_ID -- to id  
     ,@c_SourceType --Sourcetype  
     ,@c_Wavekey --Sourcekey  
     ,@c_Priority -- Priority  
     ,'9' -- Sourcepriority  
     ,'0' -- Status  
     ,@c_FromLoc --Logical from loc  
     ,@c_ToLoc --Logical to loc  
     ,@c_PickMethod
     ,@c_Wavekey
     ,'' --@c_Areakey
     ,@c_Loadkey
     ,@c_RefTaskkey --NJOW03
     ,@c_Message03 --NJOW03
    )
    
    SELECT @n_err = @@ERROR  
    IF @n_err <> 0  
    BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
        GOTO RETURN_SP
    END   
 END
 
 --Update qty replen to lotxlocxid
 IF (@n_continue = 1 OR @n_continue = 2)  AND @c_TaskType = 'RPF' --AND @c_DestinationType = 'DPP' AND @c_Areakey = 'DPP'
 BEGIN
     --IF @n_Qty < @n_TakeQty 
     --BEGIN
       UPDATE LOTXLOCXID WITH (ROWLOCK)
       SET QtyReplen = QtyReplen + @n_TakeQty --(@n_TakeQty - @n_Qty) --reserve all for replenish 
       WHERE Lot = @c_Lot
       AND Loc = @c_FromLoc
       AND Id = @c_ID

       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
           GOTO RETURN_SP
       END   
     --END
 END 
 
 --Update taskdetailkey to pickdetail
 IF (@n_continue = 1 OR @n_continue = 2) AND @c_TaskType <> 'RPF' --replenish task no need link to pickdetail becuase the pick will be moved to DPP(overallocate) for another SCP task from DPP
 BEGIN
     SELECT @c_Pickdetailkey = '', @n_ReplenQty = @n_Qty
     WHILE @n_ReplenQty > 0 
    BEGIN                        
       SET ROWCOUNT 1   
       
       SELECT @c_PickdetailKey = PICKDETAIL_WIP.Pickdetailkey, @n_PickQty = Qty
       FROM WAVEDETAIL (NOLOCK) 
       JOIN PICKDETAIL_WIP (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL_WIP.Orderkey AND WAVEDETAIL.Wavekey = PICKDETAIL_WIP.Wavekey
       JOIN LOC (NOLOCK) ON PICKDETAIL_WIP.Loc = LOC.Loc
       WHERE WAVEDETAIL.Wavekey = @c_Wavekey
       AND ISNULL(PICKDETAIL_WIP.Taskdetailkey,'') = ''
       AND PICKDETAIL_WIP.Storerkey = @c_Storerkey
       AND PICKDETAIL_WIP.Sku = @c_sku
       AND PICKDETAIL_WIP.Lot = @c_Lot
       AND PICKDETAIL_WIP.Loc = @c_FromLoc
       AND PICKDETAIL_WIP.ID = @c_ID
       --AND PICKDETAIL_WIP.UOM = @c_UOM 
       AND 1 = CASE WHEN @c_DestinationType = 'PACKSTATION' AND PICKDETAIL_WIP.UOM IN('6','7') AND LOC.LocationCategory <> 'DYNPPICK' AND LOC.LocationType <> 'DYNPPICK'  THEN 0 ELSE 1 END
       AND PICKDETAIL_WIP.Pickdetailkey > @c_pickdetailkey
       AND PICKDETAIL_WIP.WIP_Refno = @c_SourceType          
       ORDER BY PICKDETAIL_WIP.Pickdetailkey
       
       SELECT @n_cnt = @@ROWCOUNT
       SET ROWCOUNT 0
       
       IF @n_cnt = 0
           BREAK
       
       IF @n_PickQty <= @n_ReplenQty
       BEGIN
          UPDATE PICKDETAIL_WIP WITH (ROWLOCK)
          SET Taskdetailkey = @c_TaskdetailKey,
              TrafficCop = NULL
          WHERE Pickdetailkey = @c_PickdetailKey
          AND Wavekey = @c_Wavekey
            AND WIP_Refno = @c_SourceType    
          
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82110   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK
         END 
         SELECT @n_ReplenQty = @n_ReplenQty - @n_PickQty
       END
       ELSE
       BEGIN  -- pickqty > replenqty   
          SELECT @n_SplitQty = @n_PickQty - @n_ReplenQty
          EXECUTE nspg_GetKey      
          'PICKDETAILKEY',      
          10,      
          @c_NewPickdetailKey OUTPUT,         
          @b_success OUTPUT,      
          @n_err OUTPUT,      
          @c_errmsg OUTPUT      
          IF NOT @b_success = 1      
          BEGIN
             SELECT @n_continue = 3      
             BREAK      
          END      
                
          INSERT PICKDETAIL_WIP      
                 (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],       
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
                  TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo)      
          SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                 Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                 '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                 WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,
                 TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, @c_SourceType                 
          FROM PICKDETAIL_WIP (NOLOCK)
          WHERE PickdetailKey = @c_PickdetailKey
          AND PICKDETAIL_WIP.Wavekey = @c_Wavekey
                             
          SELECT @n_err = @@ERROR
          IF @n_err <> 0     
          BEGIN     
             SELECT @n_continue = 3      
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82120   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK    
          END
          
          UPDATE PICKDETAIL_WIP WITH (ROWLOCK)
          SET Taskdetailkey = @c_TaskdetailKey,
             Qty = @n_ReplenQty,
             UOMQTY = CASE UOM WHEN '6' THEN @n_ReplenQty ELSE UOMQty END,            
             TrafficCop = NULL
          WHERE Pickdetailkey = @c_PickdetailKey
          AND Wavekey = @c_Wavekey
            AND WIP_Refno = @c_SourceType    
          
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82130   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK
          END
          SELECT @n_ReplenQty = 0
       END     
     END -- While Qty > 0
 END        

 --return back to calling point
 IF @c_DestinationType = 'PACKSTATION'
    GOTO RTN_INSERT_TASKS

 IF @c_DestinationType = 'DPP' AND @c_Areakey = 'DPP'
    GOTO RTN_INSERT_TASKS_REPLENDPP

 IF @c_DestinationType = 'DPP' AND @c_Areakey = 'PACKSTATION'
    GOTO RTN_INSERT_TASKS_PICKDPP

 --------------------Function to find DPP Loc---------------------     
 FIND_DPP_LOC:

 SET @c_DPPLoc = ''

  -- Assign loc with same sku qty already assigned in current replenishment
 IF ISNULL(@c_DPPLoc,'')=''
 BEGIN
     SELECT TOP 1 @c_DPPLoc = DL.ToLoc
     FROM #DYNPICK_LOCASSIGNED DL
     JOIN LOC (NOLOCK) ON LOC.Loc = DL.ToLoc
     WHERE DL.Storerkey = @c_Storerkey
     AND DL.Sku = @c_Sku
     AND DL.Lottable08 = @c_Lottable08 --NJOW04
     ORDER BY LOC.LogicalLocation, DL.ToLoc
 END

  -- Assign loc with same sku already assigned in other wave replenishment 
 IF ISNULL(@c_DPPLoc,'')=''
 BEGIN   
      SELECT TOP 1 @c_DPPLoc = TD.ToLoc 
     FROM TASKDETAIL TD (NOLOCK)
     JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
     JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot --NJOW04
     WHERE (L.LocationType = 'DYNPPICK' OR L.LocationCategory = 'DYNPPICK') 
     AND TD.TaskType = 'RPF'
     AND L.Facility = @c_Facility
     AND TD.SourceType = @c_SourceType
     AND TD.Storerkey = @c_Storerkey
     AND TD.Sku = @C_sKU
     AND TD.Status = '0'
     AND TD.Qty > 0
     AND LA.Lottable08 = @c_Lottable08 --NJOW04
     GROUP BY L.LogicalLocation, TD.ToLoc
 END

  -- Assign loc with same sku, qty available / pending move in
 IF ISNULL(@c_DPPLoc,'')=''
 BEGIN
     SELECT TOP 1 @c_DPPLoc = L.LOC
     FROM LOTxLOCxID LLI (NOLOCK)
     JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
     JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC
     WHERE (L.LocationType = 'DYNPPICK' OR L.LocationCategory = 'DYNPPICK') 
     AND   L.Facility = @c_Facility
     --AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0
     AND (LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) > 0
     AND  LLI.Storerkey = @c_Storerkey
     AND  LLI.Sku = @c_Sku
     AND LA.Lottable08 = @c_Lottable08 --NJOW04     
     ORDER BY L.LogicalLocation, L.Loc
 END

 -- If no location with same sku found, then assign the empty location
 IF ISNULL(@c_DPPLoc,'')=''
 BEGIN
     SELECT TOP 1 @c_DPPLoc = L.LOC
     FROM   LOC L (NOLOCK)
     WHERE  (L.LocationType = 'DYNPPICK' OR L.LocationCategory = 'DYNPPICK') 
     AND    L.Facility = @c_Facility
     AND    NOT EXISTS(
                SELECT 1
                FROM   #DYNPICK_NON_EMPTY E
                WHERE  E.LOC = L.LOC
            ) AND
            NOT EXISTS(
                SELECT 1
                FROM   #DYNPICK_TASK AS ReplenLoc
                WHERE  ReplenLoc.TOLOC = L.LOC
            ) AND
            NOT EXISTS(
                SELECT 1
                FROM   #DYNPICK_LOCASSIGNED AS DynPick
                WHERE  DynPick.ToLoc = L.LOC
            )
     ORDER BY L.LogicalLocation, L.Loc
 END

 IF @n_debug = 1
    SELECT '@c_DPPLoc', @c_DPPLoc

 -- Terminate. Can't find any dynamic location
 IF ISNULL(@c_DPPLoc,'')=''
 BEGIN
    SELECT @n_continue = 3  
    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '       
    GOTO RETURN_SP
 END

 SELECT @c_ToLoc = @c_DPPLoc

 --Insert current location assigned
 IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED
                WHERE Storerkey = @c_Storerkey
                AND Sku = @c_Sku
                AND ToLoc = @c_ToLoc)
 BEGIN
    INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, Lottable08) --NJOW04
    VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @c_Lottable08 )
 END

 GOTO RTN_FIND_DPP_LOC    
      
 END --sp end

GO