SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV18                                          */  
/* Creation Date: 21-Aug-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-5651 - CN Livi's B2B Release task                        */
/*          Full case(2) to pack and Conso(6) carton to DPP and          */
/*          replenish overallocated loose(7) from bulk to pick           */
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.4                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 04/10/2018  NJOW01   1.0   Change replenishment priority to 9         */
/* 08/10/2018  NJOW02   1.1   Conso carton(uom6) to pick loc             */
/* 09/10/2018  NJOW03   1.2   Conso remove update pendingmovein & qtyreplen*/ 
/* 2020-02-18  Wan01    1.3   WMS-12056 - [CN]Levis Exceed Release Wave(CR)*/
/* 01-04-2020  Wan02    1.4   Sync Exceed & SCE                          */
/* 02-06-2010  NJOW04   1.5   WMS-17192 addition qty to replen           */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV18]      
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

   DECLARE @c_Storerkey            NVARCHAR(15)
         ,@c_Facility            NVARCHAR(5)
         ,@c_TaskType            NVARCHAR(10)            
         ,@c_SourceType          NVARCHAR(30)
         ,@c_Priority            NVARCHAR(10)
         ,@c_Toloc               NVARCHAR(10)
         ,@c_PickMethod          NVARCHAR(10)
         ,@c_Message03           NVARCHAR(20)
         ,@c_PickCondition_SQL   NVARCHAR(4000)
         ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
         ,@c_ToLoc_Strategy      NVARCHAR(30)
         ,@c_ToLoc_StrategyParam NVARCHAR(4000)
         ,@c_WaveType            NVARCHAR(10)

   --(Wan01)
   DECLARE @c_PickdetailKey         NVARCHAR(10) = ''
         , @c_NewPickDetailKey      NVARCHAR(10) = ''
         , @c_ReplenishmentGroup    NVARCHAR(10) = ''
         , @c_ReplenishmentKey      NVARCHAR(10) = ''

         , @c_SKU                   NVARCHAR(20) = ''   
         , @c_FromLOC               NVARCHAR(10) = ''
         , @c_Loc                   NVARCHAR(10) = ''
         , @c_Lot                   NVARCHAR(10) = ''
         , @c_ID                    NVARCHAR(18) = ''   
         , @c_UOM                   NVARCHAR(10) = '' 
         , @c_UOM_Prev              NVARCHAR(10) = ''
         , @c_PackUOM               NVARCHAR(10) = ''     
         , @c_PackKey               NVARCHAR(10) = ''    
         , @c_MoveRefKey            NVARCHAR(10) = ''
         , @c_LogicalLocation       NVARCHAR(10) = ''
         
         , @n_Qty                   INT = 0
         , @n_PickQty               INT = 0
         , @n_SplitQty              INT = 0
         , @n_QtyToTake             INT = 0
         , @n_QtyReplen             INT = 0
         , @n_QtyInPickLoc          INT = 0

         , @n_UCCQty                INT = 0
         , @n_UCC_RowRef            INT = 0
         , @c_UCCNo                 NVARCHAR(20) = ''

         , @CUR_PICK                CURSOR
         , @CUR_UCC                 CURSOR
         , @CUR_UCCPICK             CURSOR
                            
   SET @c_SourceType = 'ispRLWAV18'    
   SET @c_Priority = '9'
   SET @c_TaskType = 'RPF'
   SET @c_PickMethod = 'PP'

   -----Get Storerkey and facility
   --(Wan01) - START 
   SELECT TOP 1 @c_Storerkey = O.Storerkey, 
            @c_Facility = O.Facility,
            @c_WaveType = W.WaveType
   FROM WAVE W (NOLOCK)
   JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   AND W.Wavekey = @c_Wavekey
   --(Wan01) - END 
 
   -----Wave Validation-----            
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      IF NOT EXISTS (SELECT 1 
                     FROM WAVEDETAIL WD (NOLOCK)
                     JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                     LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN('RPF')
                     WHERE WD.Wavekey = @c_Wavekey                   
                     AND PD.Status = '0'
                     AND TD.Taskdetailkey IS NULL
                  )
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83000  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV18)'       
      END      
   END
    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan01) - START 
      IF @c_WaveType = 'B2B-P'
      BEGIN
         IF EXISTS ( SELECT 1 FROM REPLENISHMENT RPL (NOLOCK) 
                     WHERE RPL.Wavekey = @c_Wavekey
                     AND   RPL.Storerkey = @c_Storerkey
                   )
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 83008    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has generated Replenishment records. (ispRLWAV18)'       
         END 
      END
      ELSE
      BEGIN
         IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                     WHERE TD.Wavekey = @c_Wavekey
                     AND TD.Sourcetype = @c_SourceType
                     AND TD.Tasktype IN('RPF'))
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 83010    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV18)'       
         END 
      END
      --(Wan01) - END                         
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1
                  FROM WAVEDETAIL WD (NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
                  WHERE WD.WaveKey = @c_wavekey
                  AND ISNULL(O.Loadkey,'') = '')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83020    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found some orders of this wave without load planning. Release is not allowed. (ispRLWAV18)'       
      END                 
   END
          
   IF @@TRANCOUNT = 0
      BEGIN TRAN
   
   --(Wan01) - START     
   -----Get Storerkey and facility
   --IF  (@n_continue = 1 OR @n_continue = 2)
   --BEGIN
   --    SELECT TOP 1 @c_Storerkey = O.Storerkey, 
   --                 @c_Facility = O.Facility,
   --                 @c_WaveType = W.WaveType
   --    FROM WAVE W (NOLOCK)
   --    JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
   --    JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   --    AND W.Wavekey = @c_Wavekey 
   --END 

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      IF OBJECT_ID('#PickDetail_WIP') IS NOT NULL
      BEGIN 
         DROP TABLE #PickDetail_WIP;
      END

      CREATE TABLE #PickDetail_WIP
      (  
         [PickDetailKey]         [nvarchar](18)    NOT NULL PRIMARY KEY  
      ,  [CaseID]                [nvarchar](20)    NOT NULL DEFAULT (' ')  
      ,  [PickHeaderKey]         [nvarchar](18)    NOT NULL  
      ,  [OrderKey]              [nvarchar](10)    NOT NULL  
      ,  [OrderLineNumber]       [nvarchar](5)     NOT NULL  
      ,  [Lot]                   [nvarchar](10)    NOT NULL  
      ,  [Storerkey]             [nvarchar](15)    NOT NULL  
      ,  [Sku]                   [nvarchar](20)    NOT NULL  
      ,  [AltSku]                [nvarchar](20)    NOT NULL    DEFAULT (' ')  
      ,  [UOM]                   [nvarchar](10)    NOT NULL    DEFAULT (' ')  
      ,  [UOMQty]                [int]             NOT NULL    DEFAULT ((0))  
      ,  [Qty]                   [int]             NOT NULL    DEFAULT ((0))  
      ,  [QtyMoved]              [int]             NOT NULL    DEFAULT ((0))  
      ,  [Status]                [nvarchar](10)    NOT NULL    DEFAULT ('0')  
      ,  [DropID]                [nvarchar](20)    NOT NULL    DEFAULT ('')  
      ,  [Loc]                   [nvarchar](10)    NOT NULL    DEFAULT ('UNKNOWN')  
      ,  [ID]                    [nvarchar](18)    NOT NULL    DEFAULT (' ')  
      ,  [PackKey]               [nvarchar](10)    NULL        DEFAULT (' ')  
      ,  [UpdateSource]          [nvarchar](10)    NULL        DEFAULT ('0')  
      ,  [CartonGroup]           [nvarchar](10)    NULL  
      ,  [CartonType]            [nvarchar](10)    NULL  
      ,  [ToLoc]                 [nvarchar](10)    NULL        DEFAULT (' ')  
      ,  [DoReplenish]           [nvarchar](1)     NULL        DEFAULT ('N')  
      ,  [ReplenishZone]         [nvarchar](10)    NULL        DEFAULT (' ')  
      ,  [DoCartonize]           [nvarchar](1)     NULL        DEFAULT ('N')  
      ,  [PickMethod]            [nvarchar](1)     NOT NULL    DEFAULT (' ')  
      ,  [WaveKey]               [nvarchar](10)    NOT NULL    DEFAULT (' ')  
      ,  [EffectiveDate]         [datetime]        NOT NULL    DEFAULT (getdate())  
      ,  [AddDate]               [datetime]        NOT NULL    DEFAULT (getdate())  
      ,  [AddWho]                [nvarchar](128)   NOT NULL    DEFAULT (suser_sname())  
      ,  [EditDate]              [datetime]        NOT NULL    DEFAULT (getdate())  
      ,  [EditWho]               [nvarchar](128)   NOT NULL    DEFAULT (suser_sname())  
      ,  [TrafficCop]            [nvarchar](1)     NULL  
      ,  [ArchiveCop]            [nvarchar](1)     NULL  
      ,  [OptimizeCop]           [nvarchar](1)     NULL  
      ,  [ShipFlag]              [nvarchar](1)     NULL        DEFAULT ('0')  
      ,  [PickSlipNo]            [nvarchar](10)    NULL  
      ,  [TaskDetailKey]         [nvarchar](10)    NULL  
      ,  [TaskManagerReasonKey]  [nvarchar](10)    NULL  
      ,  [Notes]                 [nvarchar](4000)  NULL  
      ,  [MoveRefKey]            [nvarchar](10)    NULL        DEFAULT ('')  
      ,  [WIP_Refno]             [nvarchar](30)    NOT NULL    DEFAULT ('')  
      ,  [Channel_ID]            [bigint]          NULL        DEFAULT ((0))
      )      
            
      CREATE INDEX PDWIP_Wave ON #PickDetail_WIP (Wavekey, WIP_RefNo, UOM, [Status]) 
      
      IF OBJECT_ID('#MoveRefKey') IS NOT NULL
      BEGIN 
         DROP TABLE #MoveRefKey;
      END

      CREATE TABLE #MoveRefKey
      (  
         MoveRefKey  [nvarchar](10)    NOT NULL PRIMARY KEY   
      ,  Lot         [nvarchar](10)    NOT NULL DEFAULT ('')
      ,  Loc         [nvarchar](10)    NOT NULL DEFAULT ('')
      ,  ID          [nvarchar](18)    NOT NULL DEFAULT ('')      
      ,  UOM         [nvarchar](10)    NOT NULL DEFAULT ('')
      ) 
      CREATE INDEX MoveRefKey_Wave ON #MoveRefKey (Loc, Lot, ID, UOM)                           
   END  
   --(Wan01) - END
                        
   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
         @c_Loadkey               = ''
         ,@c_Wavekey               = @c_Wavekey  
         ,@c_WIP_RefNo             = @c_SourceType 
         ,@c_PickCondition_SQL     = ''
         ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
         ,@c_RemoveTaskdetailkey   = 'Y'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
         ,@b_Success               = @b_Success OUTPUT
         ,@n_Err                   = @n_Err     OUTPUT 
         ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END          
   END

   --(Wan01) - START    
   IF @c_WaveType = 'B2B-P'  -- Generate Replenishment
   BEGIN
      SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, Qty = SUM(PD.Qty), PD.UOM, SKU.Packkey, PACK.PACKUOM3
          ,  LOC.LogicalLocation
      FROM #PICKDETAIL_WIP PD   
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc  
      WHERE PD.Wavekey = @c_Wavekey
      AND PD.WIP_RefNo = @c_SourceType         
      AND PD.[Status] = '0'  
      AND PD.UOM IN ('2', '6')       
      AND SL.LocationType NOT IN ('PICK','CASE')  
      GROUP BY PD.UOM, PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SKU.Packkey, PACK.PACKUOM3, LOC.LogicalLocation
      UNION
      SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, ID = ''
          , Qty = CASE WHEN SUM(PD.Qty) <= (-1 * (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn)) 
                       THEN SUM(PD.Qty)                                                                -- If OverAllocated Qty > Wave Qty, Get Wave Qty to Replen
                       ELSE (-1 * (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn))
                       END 
          ,  PD.UOM
          ,  SKU.Packkey, PACK.PACKUOM3
          ,  LOC.LogicalLocation
      FROM #PICKDETAIL_WIP PD   
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc  
      JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
      JOIN LOC (NOLOCK) ON LOC.Loc = LLI.Loc 
      WHERE PD.Wavekey = @c_Wavekey  
      AND PD.[Status] = '0'  
      AND PD.WIP_RefNo = @c_SourceType  
      AND PD.UOM IN ('7')
      AND SL.LocationType IN ('PICK')  
      AND LOC.Facility = @c_Facility 
      GROUP BY PD.UOM, PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, SKU.Packkey, PACK.PACKUOM3, LOC.LogicalLocation
            ,  LLI.Qty, LLI.QtyAllocated, LLI.QtyPicked, LLI.PendingMoveIn                         --2020-07-08 fixed
      HAVING (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn < 0  --overallocate  --2020-07-08 fixed 
      ORDER BY PD.UOM, PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot         
         
      OPEN @CUR_PICK    
         
      FETCH NEXT FROM @CUR_PICK INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_ID, @n_Qty, @c_UOM, @c_Packkey, @c_PackUOM, @c_LogicalLocation
         
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)  
      BEGIN
         IF @c_UOM = '6'
         BEGIN
            SET @c_ToLoc = ''
            SELECT TOP 1 @c_ToLoc = SL.Loc
            FROM SKUxLOC SL WITH (NOLOCK)
            WHERE SL.Storerkey = @c_Storerkey
            AND   SL.Sku = @c_Sku
            AND   SL.LocationType = 'PICK'
         END

         IF @c_UOM IN ('2', '6')   --has UOM 6 when storerconfig 'PostAllocIdentifyConsoUnit' turn on. Currently turn off
         BEGIN
            SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
            SELECT UCCNo, Qty, UCC_RowRef, Loc, ID  
            FROM UCC WITH (NOLOCK)  
            WHERE StorerKey = @c_StorerKey  
            AND SKU = @c_Sku
            AND Lot = @c_Lot  
            AND Loc = @c_Loc  
            AND ID = @c_Id  
            AND [Status] = '1'  
            AND Qty <= @n_Qty  
            ORDER BY EditDate DESC, UCCNo  
         END
         ELSE IF @c_UOM IN ('7')
         BEGIN
            IF @n_Qty < 0 
            BEGIN
               SET @n_Qty = @n_Qty * -1
            END

            SET @c_ToLoc = @c_Loc
            --Only Get OverAllocate
            SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
            SELECT UCC.UCCNo, UCC.Qty, UCC.UCC_RowRef, UCC.Loc, UCC.ID  
            FROM LOT LOT WITH (NOLOCK)
            JOIN LOTxLOCxID LLI WITH (NOLOCK) ON LLI.Lot = LOT.Lot
            JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = LLI.Loc AND LOC.[Status] = 'OK'
            JOIN ID ID WITH (NOLOCK) ON ID.ID = LLI.ID AND ID.[Status] = 'OK'
            JOIN SKUxLOC SL WITH (NOLOCK) ON SL.Storerkey = LLI.Storerkey AND SL.Sku = LLI.Sku AND SL.Loc = LLI.Loc 
            JOIN UCC WITH (NOLOCK) ON UCC.Lot = LLI.Lot AND UCC.Loc = LLI.Loc AND UCC.ID = LLI.ID AND UCC.[Status] = '1' 
            WHERE LOT.StorerKey = @c_StorerKey  
            AND LOT.SKU = @c_Sku
            AND LOT.Lot = @c_Lot
            AND LOT.[Status] = 'OK'
            AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND LOC.Facility = @c_Facility
            AND SL.LocationType NOT IN ('PICK', 'CASE') 
            AND LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)) > 0  
            ORDER BY UCC.EditDate DESC, UCC.UCCNo  
         END
                           
         OPEN @CUR_UCC  
                  
         FETCH NEXT FROM @CUR_UCC INTO @c_UCCNo, @n_UCCQty, @n_UCC_RowRef, @c_FromLoc, @c_ID           
                     
         WHILE @@FETCH_STATUS = 0 AND @n_Qty > 0 AND @n_continue IN (1,2)  
         BEGIN            
            SET @n_QtyToTake = @n_UCCQty  
            SET @n_QtyInPickLoc = @n_QtyToTake

            
            SET @c_MoveRefKey = ''
            IF @c_UOM = @c_UOM_Prev 
            BEGIN        
               SELECT TOP 1 @c_MoveRefKey = MoveRefKey 
               FROM #MoveRefkey
               WHERE Loc = @c_FromLoc
               AND   Lot = @c_Lot
               AND   ID  = @c_ID
               AND   UOM = @c_UOM
            END

            IF @c_MoveRefKey = ''
            BEGIN
               EXECUTE nspg_GetKey  
                            'MoveRefKey'  
                         ,  10  
                         ,  @c_MoveRefKey OUTPUT  
                         ,  @b_Success    OUTPUT   
                         ,  @n_Err        OUTPUT   
                         ,  @c_ErrMsg     OUTPUT  
                        
               IF @b_Success <> 1   
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err = 83121  
                  SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Get MoveRefKey Failed! (ispRLWAV18)'  
               END

               IF @n_continue IN (1,2)
               BEGIN
                  INSERT INTO #MoveRefkey (MoveRefKey, Lot, Loc, ID, UOM)
                  VALUES (@c_MoveRefKey, @c_Lot, @c_FromLoc, @c_ID, @c_UOM) 
               END
            END

            IF @n_continue IN (1,2)
            BEGIN
               IF @c_UOM IN ('7')
               BEGIN
                  SET @n_QtyInPickLoc = @n_Qty 
                  IF @n_Qty > @n_UCCQty  
                  BEGIN
                     SET @n_QtyInPickLoc = @n_UCCQty 
                  END
                  SET @n_Qty = @n_Qty - @n_UCCQty
                  
                  IF @n_Qty = 0  --NJOW04 take addition carton if demand qty = replen qty
                     SET @n_Qty = 1                  
               END
               ELSE IF @c_UOM IN ('2', '6')
               BEGIN
                  SET @CUR_UCCPICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                  SELECT PD.PickDetailkey, PD.Qty
                  FROM #PICKDETAIL_WIP PD  
                  WHERE PD.Wavekey = @c_Wavekey  
                  AND PD.WIP_RefNo = @c_SourceType  
                  AND PD.Lot = @c_Lot
                  AND PD.Loc = @c_Loc
                  AND PD.ID  = @c_ID
                  AND PD.UOM = @c_UOM
                  AND PD.Status = '0'  
                  AND NOT EXISTS (  SELECT 1 FROM UCC WITH (NOLOCK)
                                    WHERE Lot = PD.lot
                                    AND   Loc = PD.Loc
                                    AND   ID  = PD.ID
                                    AND   UCCNo = PD.DropID
                                  )
                  OPEN @CUR_UCCPICK

                  FETCH NEXT FROM @CUR_UCCPICK INTO @c_Pickdetailkey, @n_PickQty           
                     
                  WHILE @@FETCH_STATUS = 0 AND @n_UCCQty > 0 AND @n_continue IN (1,2)  
                  BEGIN
                     IF @n_PickQty <= @n_UCCQty
                     BEGIN
                        UPDATE #PICKDETAIL_WIP
                           SET DropID = @c_UCCNo
                              ,MoveRefKey = @c_MoveRefKey
                        WHERE PickDetailKey = @c_Pickdetailkey

                        IF @@ERROR <> 0   
                        BEGIN  
                           SET @n_continue = 3  
                           SET @n_err = 83122  
                           SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispRLWAV18)'  
                        END   
                          
                        SET @n_UCCQty = @n_UCCQty - @n_PickQty                                                                          
                        SET @n_Qty =  @n_Qty - @n_PickQty   
                     END
                     ELSE  
                     BEGIN  
                        SET @c_NewPickDetailKey = ''  
                                                
                        EXECUTE dbo.nspg_GetKey    
                           'PICKDETAILKEY'     
                           , 10    
                           , @c_NewPickDetailKey   OUTPUT    
                           , @b_success            OUTPUT    
                           , @n_err                OUTPUT    
                           , @c_errmsg             OUTPUT    
                           
                        IF @b_success <> 1    
                        BEGIN    
                           SET @n_Err = 83123    
                           SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Get Pickdetailkey Failed! (ispRLWAV18)'  
                           SET @n_Continue = 3  
                        END   
                     
                        IF @n_continue IN (1,2)
                        BEGIN                           
                           SET @n_SplitQty = @n_PickQty - @n_UCCQty  
                  
                           INSERT INTO #PICKDETAIL_WIP  
                              (  
                                 PickDetailKey    ,CaseID           ,PickHeaderKey  
                              ,  OrderKey         ,OrderLineNumber  ,Lot  
                              ,  Storerkey        ,Sku              ,AltSku  
                              ,  UOM              ,UOMQty           ,Qty  
                              ,  QtyMoved         ,[STATUS]         ,DropID  
                              ,  Loc              ,ID               ,PackKey  
                              ,  UpdateSource     ,CartonGroup      ,CartonType  
                              ,  ToLoc            ,DoReplenish      ,ReplenishZone  
                              ,  DoCartonize      ,PickMethod       ,WaveKey  
                              ,  EffectiveDate    ,TrafficCop       ,ArchiveCop  
                              ,  OptimizeCop      ,ShipFlag         ,PickSlipNo  
                              ,  WIP_Refno  
                              )  
                           SELECT @c_NewPickDetailKey  AS PickDetailKey  
                                 ,CaseID           ,PickHeaderKey    ,OrderKey  
                                 ,OrderLineNumber  ,@c_Lot           ,Storerkey  
                                 ,Sku              ,AltSku           ,@c_UOM  
                                 ,UOMQty           ,@n_SplitQty  
                                 ,QtyMoved         ,[STATUS]         ,DropID         
                                 ,Loc              ,ID               ,PackKey        
                                 ,UpdateSource     ,CartonGroup      ,CartonType        
                                 ,@c_PickDetailKey ,DoReplenish      ,ReplenishZone='SplitToUCC'        
                                 ,DoCartonize      ,PickMethod       ,WaveKey        
                                 ,EffectiveDate    ,TrafficCop       ,ArchiveCop        
                                 ,'9'              ,ShipFlag         ,PickSlipNo  
                                 ,@c_SourceType   
                           FROM   #PICKDETAIL_WIP WITH (NOLOCK)  
                           WHERE  PickDetailKey = @c_PickDetailKey   
                  
                           IF @@ERROR <> 0   
                           BEGIN  
                              SET @n_continue = 3  
                              SET @n_err = 83124 
                              SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT PickDetail Failed! (ispRLWAV18)'  
                           END                     
                        END  
                  
                        IF @n_continue IN (1,2)
                        BEGIN                                                               
                           UPDATE #PICKDETAIL_WIP WITH (ROWLOCK)  
                           SET DropID = @c_UCCNo     
                              ,Qty = @n_UCCQty   
                              ,MoveRefKey = @c_MoveRefKey
                              ,TrafficCop = NULL 
                              ,ReplenishZone='SplitFrUCC'  
                           WHERE PickDetailKey = @c_PickDetailKey  
                  
                           IF @@ERROR <> 0   
                           BEGIN  
                              SET @n_continue = 3  
                              SET @n_err = 83125  
                              SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispRLWAV18)'  
                           END   
                        END  
                        SET @n_Qty = @n_Qty - @n_UCCQty   
                        SET @n_UCCQty = 0                     
                     END  

                     FETCH NEXT FROM @CUR_UCCPICK INTO @c_Pickdetailkey, @n_PickQty   
                  END 
                  CLOSE @CUR_UCCPICK
                  DEALLOCATE @CUR_UCCPICK
               END
            END

            SET @c_ReplenishmentKey = ''
      
            IF @c_UOM IN ( '6', '7') AND @n_continue IN (1,2)
            BEGIN
               EXECUTE nspg_GetKey  
                         'REPLENISHKEY'  
                      ,  10  
                      ,  @c_ReplenishmentKey  OUTPUT  
                      ,  @b_Success           OUTPUT   
                      ,  @n_Err               OUTPUT   
                      ,  @c_ErrMsg            OUTPUT  
                        
               IF @b_Success <> 1   
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err = 83126  
                  SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Get Replenishkey Failed! (ispRLWAV18)'  
               END  

               IF @n_continue IN (1,2)
               BEGIN 
                  SET @n_QtyReplen = 0
                   
                  IF @c_UOM = '7'
                  BEGIN
                     SET @n_QtyReplen = @n_QtyToTake
                  END 
                                     
                  INSERT INTO REPLENISHMENT
                     (  
                        Replenishmentgroup, ReplenishmentKey, StorerKey,  
                        Sku,                FromLoc,          ToLoc,  
                        Lot,                Id,               Qty,  
                        UOM,                PackKey,          Confirmed,   
                        MoveRefKey,         ToID,             PendingMoveIn,   
                        QtyReplen,          QtyInPickLoc,     RefNo,  
                        Wavekey,            Remark          
                     )  
                  VALUES (
                        @c_ReplenishmentGroup, @c_ReplenishmentKey, @c_StorerKey,   
                        @c_SKU,                @c_FromLOC,          @c_ToLoc,   
                        @c_Lot,                @c_ID,               @n_QtyToTake,   
                        @c_PackUOM,            @c_PackKey,          'N',   
                        @c_MoveRefKey,         @c_ID,               @n_QtyToTake,   
                        @n_QtyReplen,          @n_QtyInPickLoc,     @c_UCCNo,  
                        @c_Wavekey,            ''
                          )    
                                 
                  IF @@ERROR <> 0   
                  BEGIN  
                     SET @n_continue = 3  
                     SET @n_err = 83127  
                     SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Replenishment Failed! (ispRLWAV18)'  
                  END  
               END                                           
            END

            IF @n_continue IN (1,2)
            BEGIN                                       
               UPDATE UCC   
               SET [Status] = '5'   
                  ,Userdefined10 = @c_ReplenishmentKey        
               WHERE UCC_RowRef = @n_UCC_RowRef 
               AND [Status] = '1'  
                  
               IF @@ERROR <> 0   
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err = 83128 
                  SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update UCC Failed! (ispRLWAV18)'  
               END
            END

            FETCH NEXT FROM @CUR_UCC INTO @c_UCCNo, @n_UCCQty, @n_UCC_RowRef, @c_FromLoc, @c_ID                 
         END
         CLOSE @CUR_UCC
         DEALLOCATE @CUR_UCC

         SET @c_UOM_Prev = @c_UOM_Prev
         FETCH NEXT FROM @CUR_PICK INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_ID, @n_Qty, @c_UOM, @c_Packkey, @c_PackUOM, @c_LogicalLocation       
      END
      CLOSE @CUR_PICK
      DEALLOCATE @CUR_PICK 
   END
   ELSE
   BEGIN
      --Full carton to packstation    
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SET @c_ToLoc = ''
         SET @c_ToLoc_Strategy = '' 
         SET @c_Message03 = 'PACKSTATION'
         SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM = ''2'' AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'') AND SKUXLOC.LocationType <> ''PICK'''         
         SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'
       
         SELECT TOP 1 @c_ToLoc = CL.Short
         FROM CODELKUP CL (NOLOCK)
         JOIN LOC (NOLOCK) ON CL.Short = LOC.Loc
         WHERE CL.Listname = 'LEVISLOC'
         AND CL.Storerkey = @c_Storerkey
         AND CL.Code = 'PACK'
         AND CL.Code2 = @c_WaveType
       
         IF ISNULL(@c_Toloc,'') = ''
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 83030    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid pack station setup at codelkup ''LEVISLOC''. (ispRLWAV18)'              
         END
         ELSE
         BEGIN              
            EXEC isp_CreateTaskByPick
               @c_TaskType              = @c_TaskType
               ,@c_Wavekey               = @c_Wavekey  
               ,@c_ToLoc                 = @c_ToLoc       
               ,@c_ToLoc_Strategy        = @c_ToLoc_Strategy
               ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
               ,@c_Priority              = @c_Priority      
               ,@c_Message03             = @c_Message03       
               ,@c_SourceType            = @c_SourceType      
               ,@c_SourceKey             = @c_Wavekey         
               ,@c_CallSource            = 'WAVE' -- WAVE / LOADPLAN 
               ,@c_PickCondition_SQL     = @c_PickCondition_SQL   -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LocationType = 'OTHER'
               ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
               ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
               ,@c_ReserveQtyReplen      = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
               ,@c_ReservePendingMoveIn  = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
               ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
               ,@c_RoundUpQty            = 'N'    -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
               ,@c_SplitTaskByCase       = 'Y'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
               ,@c_CasecntbyLocUCC       = 'Y'    -- N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
               ,@c_ZeroSystemQty         = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
               ,@b_Success               = @b_Success OUTPUT
               ,@n_Err                   = @n_Err     OUTPUT        
               ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
              
            IF @b_Success <> 1
            BEGIN
               SET @n_continue = 3
            END                      
         END          
      END

      --Conso carton (6) from bulk to Pick.
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN        
         SET @c_ToLoc = ''
         SET @c_ToLoc_Strategy = 'PICK'  --'ispToLoc_DynamicLoc' 
         SET @c_ToLoc_StrategyParam = '' --'@c_CaseCntByLocUCC=Y'
         SET @c_Message03 = 'PICKLOC'
         SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM IN(''6'') AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'') AND SKUXLOC.LocationType <> ''PICK'''         
         SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'
             
         EXEC isp_CreateTaskByPick
            @c_TaskType              = @c_TaskType
            ,@c_Wavekey               = @c_Wavekey  
            ,@c_ToLoc                 = @c_ToLoc 
            ,@c_ToLoc_Strategy        = @c_ToLoc_Strategy
            ,@c_ToLoc_StrategyParam   = @c_ToLoc_StrategyParam
            ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
            ,@c_Priority              = @c_Priority      
            ,@c_Message03             = @c_Message03   
            ,@c_SourceType            = @c_SourceType      
            ,@c_SourceKey             = @c_Wavekey         
            ,@c_CallSource            = 'WAVE' -- WAVE / LOADPLAN 
            ,@c_PickCondition_SQL     = @c_PickCondition_SQL  -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LocationType = 'OTHER'
            ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
            ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL     -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
            ,@c_ReserveQtyReplen      = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
            ,@c_ReservePendingMoveIn  = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
            ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
            ,@c_RoundUpQty            = 'N'             -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
            ,@c_SplitTaskByCase       = 'Y'              -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
            ,@c_CasecntbyLocUCC       = 'Y'    -- N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
            ,@c_ZeroSystemQty         = 'N'              -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT        
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
         END                                
      END
   
      --create replenishment for overallocated pick loc
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         EXEC isp_CreateReplenishTask
            @c_Storerkey = @c_Storerkey
            ,@c_Facility = @c_Facility
            ,@c_PutawayZones = '' --putawayzone list to filter delimited by comma e.g. Zone1, Zone3, Bulkarea, Pickarea
            ,@c_SQLCondition = 'SKUXLOC.Locationtype = ''PICK''' --additional condition to filter the pick/dynamic loc. e.g. LOC.locationhandling = '1' AND SKUXLOC.Locationtype = 'PICK'
            ,@c_CaseLocRoundUpQty  = 'FC' --case pick loc round up qty replen from bulk. FC=Round up to full case  FP=Round up to full pallet  FL=Round up to full location qty
            ,@c_PickLocRoundUpQty  = 'FC' --pick/dynamic loc round up qty replen from bulk. FC=Round up to full case  FP=Round up to full pallet  FL=Round up to full location qty
            ,@c_CaseLocReplenPickCode  = '' --custom replen pickcode for case loc lot sorting. the sp name must start from 'nspRP'. Put 'NOPICKCODE' to use standard lot sorting. put empty to use pickcode from sku table.
            ,@c_PickLocReplenPickCode  = '' --custom replen pickcode for pick/dynamic loc lot sorting. the sp name must start from 'nspRP'. Put 'NOPICKCODE' to use standard lot sorting. put empty to use pickcode from sku table.
            ,@c_QtyReplenFormula       = 'QtyExpectedNoLocLimit' --custom formula to calculate the qty to replenish. e.g. (@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) - @n_PendingMoveIn 
                                             --the formula is a stadard sql statement and can apply below variables to calculate. the above example is the default.                                                    
                                             --@n_Qty, @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit, @n_CaseCnt, @n_Pallet, n_QtyExpected, @n_PendingMoveIn, @n_QtyExpectedFinal, @c_LocationType, @c_LocLocationType
                                             --it can pass in preset formula code. QtyExpectedFitLocLimit=try fit the overallocaton qty to location limit. usually apply when @c_BalanceExclQtyAllocated = 'Y' and do not want to replen overallocate qty exceed limit
                                             --QtyExpectedNoLocLimit=replenish overallocated qty without check location limit. 
            ,@c_Priority              = @c_Priority  --task priority default is 5 ?LOC=get the priority from skuxloc.ReplenishmentPriority  ?STOCK=calculate priority by on hand stock level against limit. if empty default is 5.
            ,@c_SplitTaskByCarton     = 'Y' --Y=Slplit the task by carton. Casecnt must set and not applicable if roundupqty is FP,FL. 
            ,@c_CasecntbyLocUCC       = 'Y' --N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
            ,@c_OverAllocateOnly      = 'Y' --Y=Only replenish pick/dynamic loc with overallocated qty  N=replen loc with overallocated qty and below minimum qty.
                                             --Dynamic loc only replenish when overallocated.
            ,@c_BalanceExclQtyAllocated = 'N'  --Y=the qtyallocated is deducted when calculate loc balance. N=the qtyallocated is not deducated.
            ,@c_TaskType                = 'RPF'
            ,@c_Wavekey                 = @c_Wavekey   --set to replenish only pick/dynamic loc involved by the wave
            ,@c_Loadkey                 = ''  --set to replenish only pick/dynamic loc involved by the load
            ,@c_SourceType              = @c_SourceType
            ,@c_Message03               = 'PICKLOC'
            ,@c_PickMethod              = 'PP'
            ,@c_ReplenWithExtra         = 'Y'   --N=No extra Y=Make sure the pick loc have balance after replenish qty - Demand(allocated) qty. Usually apply to @c_OverAllocateOnly to ensure the loc have balance after pickded. --NJOW04
            ,@c_ReplenIncludeLocNoTrans = 'Y'   --N=Not include pick loc without any pickdetail of the wave/load  Y=Include pick location without pickdetail of the wave/load. Usually apply for wave/load to trigger replen by sku of the wave/load  --NJOW04
            ,@b_Success                 = @b_Success OUTPUT
            ,@n_Err                     = @n_Err     OUTPUT 
            ,@c_ErrMsg                  = @c_ErrMsg  OUTPUT       
         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
         END            
      END
   END                    
   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
         ,@c_Wavekey               = @c_wavekey  
         ,@c_WIP_RefNo             = @c_SourceType 
         ,@c_PickCondition_SQL     = ''
         ,@c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
         ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
         ,@b_Success               = @b_Success OUTPUT
         ,@n_Err                   = @n_Err     OUTPUT 
         ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END             
   END
   --(Wan01) - END    

   -----Generate Pickslip No------
   IF @n_continue = 1 or @n_continue = 2 
   BEGIN
      EXEC isp_CreatePickSlip
         @c_Wavekey = @c_Wavekey
         ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
         ,@c_ConsolidateByLoad = 'Y'
         ,@b_Success = @b_Success OUTPUT
         ,@n_Err = @n_err OUTPUT 
         ,@c_ErrMsg = @c_errmsg OUTPUT          
       
      IF @b_Success = 0
         SELECT @n_continue = 3    
   END
            
   -----Update Wave Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE WAVE 
          --SET STATUS = '1' -- Released        --(Wan02) 
          SET TMReleaseFlag = 'Y'               --(Wan02) 
           ,  TrafficCop = NULL                 --(Wan02) 
           ,  EditWho = SUSER_SNAME()           --(Wan02) 
           ,  EditDate= GETDATE()               --(Wan02)
      WHERE WAVEKEY = @c_wavekey  
      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  
   
RETURN_SP:

   -----Delete pickdetail_WIP work in progress staging table
   IF @n_continue IN (1,2)
   BEGIN
      EXEC isp_CreatePickdetail_WIP
          @c_Loadkey               = ''
         ,@c_Wavekey               = @c_wavekey  
         ,@c_WIP_RefNo             = @c_SourceType 
         ,@c_PickCondition_SQL     = ''
         ,@c_Action                = 'D'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
         ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
         ,@b_Success               = @b_Success OUTPUT
         ,@n_Err                   = @n_Err     OUTPUT 
         ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END             
   END

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
      execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV18"  
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
END --sp end

GO