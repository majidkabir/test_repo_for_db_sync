SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV14                                          */  
/* Creation Date: 09-Jan-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-3652 - CN H&M Release replenishment tasks                */
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.3                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 11-Nov-2018 NJOW01   1.0   Double 11 fix - exclude pick already have  */
/*                            taskdetailkey                              */
/* 20-Mar-2019 NJOW02   1.1   WMS-8348 Update single or multi pickzone to*/
/*                            orders                                     */
/* 07-Aug-2019 NJOW03   1.2   WMS-10181 Change toloc logic               */
/* 01-04-2020  Wan01    1.3   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV14]      
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
            ,@c_Facility NVARCHAR(5)
            ,@c_Sku NVARCHAR(20)
            ,@c_PickLot NVARCHAR(10)
            ,@c_Lot NVARCHAR(10)
            ,@c_FromLoc NVARCHAR(10)
            ,@c_Toloc NVARCHAR(10)
            ,@c_ID NVARCHAR(18)
            ,@c_ToID NVARCHAR(18)
            ,@n_Qty INT
            ,@c_SourceType NVARCHAR(30)
            ,@c_TaskType NVARCHAR(10)
            ,@c_UOM NVARCHAR(10)
            ,@n_UOMQty INT
            ,@c_PickMethod NVARCHAR(10)            
            ,@c_Priority NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)  
            ,@c_Taskdetailkey_PND NVARCHAR(10)  
            ,@c_PickDetailKey NVARCHAR(10)
            ,@c_NewPickdetailkey NVARCHAR(10)
            ,@c_PickslipNo NVARCHAR(10)                        
            ,@c_UCCNo NVARCHAR(20)
            ,@n_UCCQty INT
            ,@n_PickQty INT
            ,@n_SystemQty INT
            ,@c_DPPLoc NVARCHAR(10)
            ,@n_SafetyStock INT
            ,@n_PickLocQty INT 
            ,@n_QtyReplenForOrder INT
            ,@c_CallSource NVARCHAR(10)
            ,@c_Orderkey NVARCHAR(15)
            ,@n_TaskBalQty INT
            ,@n_LocBalQty INT
            ,@c_TaskState NVARCHAR(10)
            ,@c_SQL      NVARCHAR(MAX)
            ,@c_SQLParm  NVARCHAR(1000)
            ,@c_Lottable01 NVARCHAR(18)    
            ,@c_Lottable02 NVARCHAR(18)    
            ,@c_Lottable03 NVARCHAR(18)    
            ,@d_Lottable04 DATETIME   
            ,@d_Lottable05 DATETIME   
            ,@c_Lottable06 NVARCHAR(30)    
            ,@c_Lottable07 NVARCHAR(30)    
            ,@c_Lottable08 NVARCHAR(30)    
            ,@c_Lottable09 NVARCHAR(30)    
            ,@c_Lottable10 NVARCHAR(30)    
            ,@c_Lottable11 NVARCHAR(30)    
            ,@c_Lottable12 NVARCHAR(30)    
            ,@d_Lottable13 DATETIME   
            ,@d_Lottable14 DATETIME    
            ,@d_Lottable15 DATETIME            
            ,@c_CaseId     NVARCHAR(20)
            ,@c_PickZone   NVARCHAR(10)  --NJOW02
            ,@c_Busr9      NVARCHAR(30) --NJOW03
                        
    SET @c_SourceType = 'ispRLWAV14'    
    SET @c_Priority = '9'
    SET @c_TaskType = 'RPF'
    SET @c_PickMethod = ''

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType 
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV14)'           
       END      
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = @c_SourceType
                   AND TD.Tasktype IN(@c_TaskType)
                   AND TD.Status <> 'X')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV14)'       
        END                 
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = 'HM-DFLOC')
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83015    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Loc HM-DFLOC. Please Setup. (ispRLWAV14)'       
       END
    END   
    
    -----Get Storerkey, facility
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey 
    END

    --Create pickdetail Work in progress temporary table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       CREATE TABLE #PickDetail_WIP(
          [PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,
          [CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),
          [PickHeaderKey] [nvarchar](18) NOT NULL,
          [OrderKey] [nvarchar](10) NOT NULL,
          [OrderLineNumber] [nvarchar](5) NOT NULL,
          [Lot] [nvarchar](10) NOT NULL,
          [Storerkey] [nvarchar](15) NOT NULL,
          [Sku] [nvarchar](20) NOT NULL,
          [AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),
          [UOM] [nvarchar](10) NOT NULL DEFAULT (' '),
          [UOMQty] [int] NOT NULL DEFAULT ((0)),
          [Qty] [int] NOT NULL DEFAULT ((0)),
          [QtyMoved] [int] NOT NULL DEFAULT ((0)),
          [Status] [nvarchar](10) NOT NULL DEFAULT ('0'),
          [DropID] [nvarchar](20) NOT NULL DEFAULT (''),
          [Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),
          [ID] [nvarchar](18) NOT NULL DEFAULT (' '),
          [PackKey] [nvarchar](10) NULL DEFAULT (' '),
          [UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),
          [CartonGroup] [nvarchar](10) NULL,
          [CartonType] [nvarchar](10) NULL,
          [ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
          [DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
          [ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
          [DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
          [PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
          [WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
          [EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [EditDate] [datetime] NOT NULL DEFAULT (getdate()),
          [EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [TrafficCop] [nvarchar](1) NULL,
          [ArchiveCop] [nvarchar](1) NULL,
          [OptimizeCop] [nvarchar](1) NULL,
          [ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
          [PickSlipNo] [nvarchar](10) NULL,
          [TaskDetailKey] [nvarchar](10) NULL,
          [TaskManagerReasonKey] [nvarchar](10) NULL,
          [Notes] [nvarchar](4000) NULL,
          [MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
          [WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
          [Channel_ID] [bigint] NULL DEFAULT ((0)))      
    END

    
    WHILE @@TRANCOUNT > 0
    BEGIN
       COMMIT TRAN
    END
    
    BEGIN TRAN   
    ----Reallocate bulk pickdetail to pick face----
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      --Get available qty from pick that can swap from pickdetail at bulk
      DECLARE cur_pickloc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT LOTxLOCxID.Storerkey, LOTxLOCxID.Sku, LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.Id,
             LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen,
             LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
             LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
             LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15 
      FROM LOTATTRIBUTE LA (NOLOCK) 
      JOIN LOT (NOLOCK) ON LOT.LOT = LA.LOT 
      JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT   
      JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc 
      JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
      JOIN (SELECT DISTINCT PD.Storerkey, PD.Sku    
            FROM WAVEDETAIL WD (NOLOCK) 
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey 
            JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc 
            AND WD.Wavekey = @c_Wavekey
            AND PD.UOM IN ('6','7')
            AND LOC.LocationType = 'BUFFER') AS BulkSku ON LOTxLOCxID.Storerkey = BulkSku.Storerkey AND LOTxLOCxID.Sku = BulkSku.Sku  
      WHERE LOT.STATUS = 'OK' 
      AND LOC.STATUS = 'OK' 
      AND ID.STATUS = 'OK'   
      AND LOC.LocationFlag = 'NONE' 
      AND LOC.Facility = @c_facility  
      AND LOC.LocationType = 'PICK'
      AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen > 0
      ORDER BY LOTxLOCxID.Storerkey, LOTxLOCxID.Sku, LOC.LocationGroup, LA.Lottable02, LA.Lottable05, 
               LA.Lot, LOC.LogicalLocation, LOC.Loc      
      
      OPEN cur_pickloc  
       
      FETCH NEXT FROM cur_pickloc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty,
                                       @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15 
       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
          --get pickdetail from bulk which can swap to available at pick
         SELECT @C_SQL = N'
            DECLARE cur_Bulkloc CURSOR FAST_FORWARD READ_ONLY FOR  
                SELECT PD.Pickdetailkey, PD.Lot, PD.Qty           
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber 
                JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
                JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                WHERE WD.Wavekey = @c_Wavekey
                AND PD.Status = ''0''
                AND PD.UOM IN (''6'',''7'')
                AND LOC.LocationType = ''BUFFER''
                AND PD.Storerkey = @c_Storerkey
                AND PD.Sku = @c_Sku
                AND ISNULL(PD.Taskdetailkey,'''') = ''''      
                AND OD.Lottable01 = CASE WHEN OD.Lottable01 <> '''' AND OD.Lottable01 IS NOT NULL THEN @c_Lottable01 ELSE OD.Lottable01 END
                AND OD.Lottable02 = CASE WHEN OD.Lottable02 <> '''' AND OD.Lottable02 IS NOT NULL THEN @c_Lottable02 ELSE OD.Lottable02 END
                AND OD.Lottable03 = CASE WHEN OD.Lottable03 <> '''' AND OD.Lottable03 IS NOT NULL THEN @c_Lottable03 ELSE OD.Lottable03 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable04 ,112) <> ''19000101'' AND OD.Lottable04 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable04, @d_Lottable04),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable05 ,112) <> ''19000101'' AND OD.Lottable05 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable05, @d_Lottable05),1) ELSE 0 END
                AND OD.Lottable06 = CASE WHEN OD.Lottable06 <> '''' AND OD.Lottable06 IS NOT NULL THEN @c_Lottable06 ELSE OD.Lottable06 END
                AND OD.Lottable07 = CASE WHEN OD.Lottable07 <> '''' AND OD.Lottable07 IS NOT NULL THEN @c_Lottable07 ELSE OD.Lottable07 END
                AND OD.Lottable08 = CASE WHEN OD.Lottable08 <> '''' AND OD.Lottable08 IS NOT NULL THEN @c_Lottable08 ELSE OD.Lottable08 END
                AND OD.Lottable09 = CASE WHEN OD.Lottable09 <> '''' AND OD.Lottable09 IS NOT NULL THEN @c_Lottable09 ELSE OD.Lottable09 END
                AND OD.Lottable10 = CASE WHEN OD.Lottable10 <> '''' AND OD.Lottable10 IS NOT NULL THEN @c_Lottable10 ELSE OD.Lottable10 END
                AND OD.Lottable11 = CASE WHEN OD.Lottable11 <> '''' AND OD.Lottable11 IS NOT NULL THEN @c_Lottable11 ELSE OD.Lottable11 END
                AND OD.Lottable12 = CASE WHEN OD.Lottable12 <> '''' AND OD.Lottable12 IS NOT NULL THEN @c_Lottable12 ELSE OD.Lottable12 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable13 ,112) <> ''19000101'' AND OD.Lottable13 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable13, @d_Lottable13),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable14 ,112) <> ''19000101'' AND OD.Lottable14 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable14, @d_Lottable14),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable15 ,112) <> ''19000101'' AND OD.Lottable15 IS NOT NULL THEN  ISNULL(DATEDIFF(DAY, OD.Lottable15, @d_Lottable15),1) ELSE 0 END ' +
                ' ORDER BY CASE WHEN PD.Lot = ''' + RTRIM(@c_Lot) + ''' THEN 1 ELSE 2 END, LOC.LocationGroup DESC, LA.Lottable02 DESC, LOC.LogicalLocation DESC, PD.Loc DESC '

             SET @c_SQLParm =  N'@c_Wavekey    NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20),' +
                                '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                                '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                                '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 
             
             EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Wavekey, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                                @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                                @d_Lottable13, @d_Lottable14, @d_Lottable15
                                
         OPEN cur_Bulkloc  
          
         FETCH NEXT FROM cur_Bulkloc INTO @c_Pickdetailkey, @c_PickLot, @n_Pickqty
          
         WHILE @@FETCH_STATUS = 0 AND @n_Qty > 0 AND @n_continue IN(1,2)
         BEGIN
              IF @n_Qty >= @n_PickQty
              BEGIN
                --swap pickdetail to pick include swap to different lot
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = 0
                 WHERE Pickdetailkey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
                 
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Lot = @c_Lot,
                     Loc = @c_ToLoc,
                     Id = @c_ID,
                     Qty = @n_PickQty,
                     Notes = 'Swap from bulk'
                 WHERE Pickdetailkey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END  
               
               SET @n_Qty = @n_Qty - @n_PickQty    
              END              
              ELSE
              BEGIN
                --split pickdetail to pick
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = Qty - @n_Qty
                 WHERE Pickdetailkey = @c_Pickdetailkey
                 
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
               END                  
            
                 INSERT INTO PICKDETAIL
                           (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                            Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                            WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                            TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_Lot,                                      
                      Storerkey, Sku, AltSku, UOM, CASE WHEN UOM IN('6','7') THEN @n_Qty ELSE UOMQty END , @n_Qty, QtyMoved, Status,       
                      '', @c_ToLoc, @c_ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                      TaskDetailKey, TaskManagerReasonKey, 'Split From Pickdetail#'+@c_Pickdetailkey , MoveRefKey                                                           
               FROM PICKDETAIL (NOLOCK)                                                                                             
               WHERE PickdetailKey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
               
               SET @n_Qty = 0    
              END
            
            FETCH NEXT FROM cur_Bulkloc INTO @c_Pickdetailkey, @c_PickLot, @n_Pickqty
         END
         CLOSE cur_Bulkloc
         DEALLOCATE cur_Bulkloc
                                                              
         FETCH NEXT FROM cur_pickloc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty,
                                          @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15          
      END
      CLOSE cur_pickloc
      DEALLOCATE cur_pickloc              
    END

    IF @n_continue = 3
       ROLLBACK
    ELSE
       COMMIT TRAN   
        
    BEGIN TRAN   
    ----Reallocate bulk pickdetail to bulk and PnD in replenish----
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      --Get available qty from replenish task include PND that can merge from pickdetail at bulk
      SELECT TD.Storerkey, TD.Sku, TD.Lot, TD.FromLoc AS Loc, TD.FromID AS ID, 
             CASE WHEN (TD.Qty - TD.SystemQty) > (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) THEN
                  (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  ELSE (TD.Qty - TD.SystemQty) END AS TaskBalQty,  --NJOW01
             LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked AS LocBalQty,
             LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
             LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
             LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15 
      INTO #TMP_REPLEN       
      FROM TASKDETAIL TD (NOLOCK)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot
      JOIN LOTXLOCXID LLI (NOLOCK) ON TD.Lot = LLI.Lot AND TD.FromLoc = LLI.Loc AND TD.FromID = LLI.ID
      WHERE TD.TaskType = 'RPF' 
      AND TD.Status = '0' 
      AND TD.SourceType = @c_SourceType
      AND TD.Qty > TD.SystemQty
      AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0
      UNION ALL    
      SELECT TD.Storerkey, TD.Sku, PND.Lot, PND.FromLoc AS Loc, PND.FromID AS ID, 
             CASE WHEN (TD.Qty - TD.SystemQty) > (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) THEN
                  (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  ELSE (TD.Qty - TD.SystemQty) END AS TaskBalQty,  --NJOW01
             LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked AS LocBalQty, 
             LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
             LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
             LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15 
      FROM TASKDETAIL TD (NOLOCK)
      JOIN TASKDETAIL PND ON TD.Taskdetailkey = PND.Sourcekey AND TD.Storerkey = PND.Storerkey AND TD.Sku = PND.Sku
      JOIN LOTATTRIBUTE LA (NOLOCK) ON PND.Lot = LA.Lot
      JOIN LOTXLOCXID LLI (NOLOCK) ON PND.Lot = LLI.Lot AND PND.FromLoc = LLI.Loc AND PND.FromID = LLI.ID
      WHERE TD.TaskType = 'RPF' 
      AND PND.TaskType = 'RPT' 
      AND TD.Status = '9'  
      AND PND.Taskdetailkey IS NOT NULL
      AND PND.Status NOT IN('9','X')
      AND TD.SourceType = @c_SourceType
      AND TD.Qty > TD.SystemQty
      AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0

      DECLARE cur_replen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT REP.Storerkey, REP.Sku, REP.Lot, REP.Loc, REP.ID, SUM(REP.TaskBalQty), SUM(REP.LocBalQty),
             REP.Lottable01, REP.Lottable02, REP.Lottable03, REP.Lottable04, REP.Lottable05, 
             REP.Lottable06, REP.Lottable07, REP.Lottable08, REP.Lottable09, REP.Lottable10, 
             REP.Lottable11, REP.Lottable12, REP.Lottable13, REP.Lottable14, REP.Lottable15 
      FROM #TMP_REPLEN REP
      JOIN LOC (NOLOCK) ON REP.Loc = LOC.Loc
      WHERE REP.TaskBalQty > 0 --NJOW01
      GROUP BY REP.Storerkey, REP.Sku, REP.Lot, REP.Loc, REP.ID, LOC.LocationType, LOC.LocationGroup, LOC.LogicalLocation,
               REP.Lottable01, REP.Lottable02, REP.Lottable03, REP.Lottable04, REP.Lottable05, 
               REP.Lottable06, REP.Lottable07, REP.Lottable08, REP.Lottable09, REP.Lottable10, 
               REP.Lottable11, REP.Lottable12, REP.Lottable13, REP.Lottable14, REP.Lottable15        
      ORDER BY REP.Storerkey, REP.Sku, CASE WHEN LOC.LocationType = 'BUFFER' THEN 1 ELSE 2 END, 
               LOC.LocationGroup, REP.Lottable02, REP.Lottable05, REP.Lot, LOC.LogicalLocation, REP.Loc      
      
      OPEN cur_replen  
       
      FETCH NEXT FROM cur_replen INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_TaskBalQty, @n_LocBalQty,
                                       @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15 
       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         IF @n_TaskBalQty < @n_LocBalQty --make sure qty not over task bal qty or loc bal qty
            SET @n_Qty = @n_TaskBalQty 
         ELSE 
            SET @n_Qty = @n_LocBalQty
        
        --print  '@c_Sku ' + @c_sku + ' @c_Lot ' + @c_lot + ' @c_ToLoc ' + @c_toloc + ' @c_ID ' + @c_id +  ' @n_TaskBalQty ' + cast(@n_taskbalqty as nvarchar) + ' @n_LocBalQty ' + cast(@n_LocBalQty as nvarchar)   
         
          --get pickdetail from bulk which can swap to replen at bulk and PND
         SELECT @C_SQL = N'
            DECLARE cur_BulklocRep CURSOR FAST_FORWARD READ_ONLY FOR  
                SELECT PD.Pickdetailkey, PD.Lot, PD.Qty           
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber 
                JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
                JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                LEFT JOIN #TMP_REPLEN TR ON PD.Lot = TR.Lot AND PD.Loc = TR.Loc AND PD.Id = TR.Id 
                WHERE WD.Wavekey = @c_Wavekey
                AND PD.Status = ''0''
                AND PD.UOM IN (''6'',''7'')
                AND LOC.LocationType = ''BUFFER''
                AND PD.Storerkey = @c_Storerkey
                AND PD.Sku = @c_Sku
                AND ISNULL(PD.Taskdetailkey,'''') = ''''      
                AND OD.Lottable01 = CASE WHEN OD.Lottable01 <> '''' AND OD.Lottable01 IS NOT NULL THEN @c_Lottable01 ELSE OD.Lottable01 END
                AND OD.Lottable02 = CASE WHEN OD.Lottable02 <> '''' AND OD.Lottable02 IS NOT NULL THEN @c_Lottable02 ELSE OD.Lottable02 END
                AND OD.Lottable03 = CASE WHEN OD.Lottable03 <> '''' AND OD.Lottable03 IS NOT NULL THEN @c_Lottable03 ELSE OD.Lottable03 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable04 ,112) <> ''19000101'' AND OD.Lottable04 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable04, @d_Lottable04),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable05 ,112) <> ''19000101'' AND OD.Lottable05 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable05, @d_Lottable05),1) ELSE 0 END
                AND OD.Lottable06 = CASE WHEN OD.Lottable06 <> '''' AND OD.Lottable06 IS NOT NULL THEN @c_Lottable06 ELSE OD.Lottable06 END
                AND OD.Lottable07 = CASE WHEN OD.Lottable07 <> '''' AND OD.Lottable07 IS NOT NULL THEN @c_Lottable07 ELSE OD.Lottable07 END
                AND OD.Lottable08 = CASE WHEN OD.Lottable08 <> '''' AND OD.Lottable08 IS NOT NULL THEN @c_Lottable08 ELSE OD.Lottable08 END
                AND OD.Lottable09 = CASE WHEN OD.Lottable09 <> '''' AND OD.Lottable09 IS NOT NULL THEN @c_Lottable09 ELSE OD.Lottable09 END
                AND OD.Lottable10 = CASE WHEN OD.Lottable10 <> '''' AND OD.Lottable10 IS NOT NULL THEN @c_Lottable10 ELSE OD.Lottable10 END
                AND OD.Lottable11 = CASE WHEN OD.Lottable11 <> '''' AND OD.Lottable11 IS NOT NULL THEN @c_Lottable11 ELSE OD.Lottable11 END
                AND OD.Lottable12 = CASE WHEN OD.Lottable12 <> '''' AND OD.Lottable12 IS NOT NULL THEN @c_Lottable12 ELSE OD.Lottable12 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable13 ,112) <> ''19000101'' AND OD.Lottable13 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable13, @d_Lottable13),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable14 ,112) <> ''19000101'' AND OD.Lottable14 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable14, @d_Lottable14),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable15 ,112) <> ''19000101'' AND OD.Lottable15 IS NOT NULL THEN  ISNULL(DATEDIFF(DAY, OD.Lottable15, @d_Lottable15),1) ELSE 0 END 
                AND TR.Loc IS NULL ' +  --only retrieve pickdetail without other replen task                
                ' GROUP BY PD.Pickdetailkey, PD.Lot, PD.Qty, LOC.LocationGroup, LA.Lottable02, LOC.LogicalLocation, PD.Loc ' +                        --              
                ' ORDER BY CASE WHEN PD.Lot = ''' + RTRIM(@c_Lot) + ''' THEN 1 ELSE 2 END, LOC.LocationGroup DESC, LA.Lottable02 DESC, LOC.LogicalLocation DESC, PD.Loc DESC '

             SET @c_SQLParm =  N'@c_Wavekey    NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20),' +
                                '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                                '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                                '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 
             
             EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Wavekey, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                                @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                                @d_Lottable13, @d_Lottable14, @d_Lottable15
                                
         OPEN cur_BulklocRep  
          
         FETCH NEXT FROM cur_BulklocRep INTO @c_Pickdetailkey, @c_PickLot, @n_Pickqty
          
         WHILE @@FETCH_STATUS = 0 AND @n_Qty > 0 AND @n_continue IN(1,2)
         BEGIN            
            --print  '@c_Pickdetailkey ' + @c_Pickdetailkey + ' @c_PickLot ' + @c_PickLot + ' @n_Pickqty ' + cast(@n_Pickqty as nvarchar)+  ' @n_Qty ' + cast(@n_Qty as nvarchar)   

              IF @n_Qty >= @n_PickQty
              BEGIN
                --swap pickdetail to pick include swap to different lot
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = 0
                 WHERE Pickdetailkey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
                 
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Lot = @c_Lot,
                     Loc = @c_ToLoc,
                     Id = @c_ID,
                     Qty = @n_PickQty,
                     Notes = 'Swap from bulk'
                 WHERE Pickdetailkey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END  
               
               SET @n_Qty = @n_Qty - @n_PickQty    
              END              
              ELSE
              BEGIN
                --split pickdetail to pick
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = Qty - @n_Qty
                 WHERE Pickdetailkey = @c_Pickdetailkey
                 
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
               END                  
            
                 INSERT INTO PICKDETAIL
                           (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                            Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                            WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                            TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_Lot,                                      
                      Storerkey, Sku, AltSku, UOM, CASE WHEN UOM IN('6','7') THEN @n_Qty ELSE UOMQty END , @n_Qty, QtyMoved, Status,       
                      '', @c_ToLoc, @c_ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                      TaskDetailKey, TaskManagerReasonKey, 'Split From Pickdetail#'+@c_Pickdetailkey , MoveRefKey                                                           
               FROM PICKDETAIL (NOLOCK)                                                                                             
               WHERE PickdetailKey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
               
               SET @n_Qty = 0    
              END
            
            FETCH NEXT FROM cur_BulklocRep INTO @c_Pickdetailkey, @c_PickLot, @n_Pickqty
         END
         CLOSE cur_BulklocRep
         DEALLOCATE cur_BulklocRep
                                                              
         FETCH NEXT FROM cur_replen INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_TaskBalQty, @n_LocBalQty,
                                         @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                         @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15 
      END
      CLOSE cur_replen
      DEALLOCATE cur_replen            
    END
    IF @n_continue = 3
       ROLLBACK
    ELSE
       COMMIT TRAN   

    BEGIN TRAN   
    ----Combine bulk and PnD pickdetail to existing replen task----
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      --Get available qty from replenish task include PND that can merge from pickdetail of same loc
      DECLARE cur_combinereplen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TD.Taskdetailkey, TD.Storerkey, TD.Sku, TD.Lot, TD.FromLoc AS Loc, TD.FromID AS ID, 
                TD.Qty - TD.SystemQty AS TaskBalQty, 
                --CASE WHEN (TD.Qty - TD.SystemQty) > (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) THEN
                --  (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  ELSE (TD.Qty - TD.SystemQty) END AS TaskBalQty,  --NJOW01
                'REP', '' AS Taskdetailkey_PND, TD.CaseID
         FROM TASKDETAIL TD (NOLOCK)
         JOIN LOTXLOCXID LLI (NOLOCK) ON TD.Lot = LLI.Lot AND TD.FromLoc = LLI.Loc AND TD.FromID = LLI.ID --NJOW01         
         WHERE TD.TaskType = 'RPF' 
         AND TD.Status = '0'
         AND TD.SourceType = @c_SourceType
         AND TD.Qty > TD.SystemQty
         UNION ALL    
         SELECT TD.Taskdetailkey, TD.Storerkey, TD.Sku, PND.Lot, PND.FromLoc AS Loc, PND.FromID AS ID, 
                TD.Qty - TD.SystemQty AS TaskBalQty, 
                --CASE WHEN (TD.Qty - TD.SystemQty) > (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) THEN
                --  (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  ELSE (TD.Qty - TD.SystemQty) END AS TaskBalQty,  --NJOW01
                'PND', PND.TaskDetailKey, PND.CaseID 
         FROM TASKDETAIL TD (NOLOCK)
         JOIN TASKDETAIL PND ON TD.Taskdetailkey = PND.Sourcekey AND TD.Storerkey = PND.Storerkey AND TD.Sku = PND.Sku
         JOIN LOTXLOCXID LLI (NOLOCK) ON PND.Lot = LLI.Lot AND PND.FromLoc = LLI.Loc AND PND.FromID = LLI.ID --NJOW01         
         WHERE TD.TaskType = 'RPF' 
         AND PND.TaskType = 'RPT' 
         AND TD.Status = '9'  
         AND PND.Taskdetailkey IS NOT NULL
         AND PND.Status NOT IN('9','X')
         AND TD.SourceType = @c_SourceType
         AND TD.Qty > TD.SystemQty
            
      OPEN cur_combinereplen  
       
      FETCH NEXT FROM cur_combinereplen INTO @c_Taskdetailkey, @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty, @c_TaskState, @c_Taskdetailkey_PND, @c_CaseID
       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN       
          --get pickdetail from replen which can merge to replen task at bulk and PND
         DECLARE cur_RepLocPickDet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT PD.Pickdetailkey, PD.Qty           
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
            WHERE WD.Wavekey = @c_Wavekey
            AND PD.Status = '0'
            AND PD.UOM IN ('6','7')
            AND PD.Lot = @c_Lot
            AND PD.Loc =  @c_ToLoc
            AND PD.Id = @c_ID
            AND PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
            AND ISNULL(PD.Taskdetailkey,'') = '' 
            ORDER BY PD.Qty 
                                
         OPEN cur_RepLocPickDet  
          
         FETCH NEXT FROM cur_RepLocPickDet INTO @c_Pickdetailkey, @n_Pickqty
          
         WHILE @@FETCH_STATUS = 0 AND @n_Qty > 0 AND @n_continue IN(1,2)
         BEGIN            
              IF @n_Qty >= @n_PickQty
              BEGIN
                --Assign pickdetail to the task
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET TaskDetailkey = CASE WHEN @c_TaskState = 'PND' THEN @c_Taskdetailkey_PND ELSE @c_Taskdetailkey END,
                     DropID =  CASE WHEN @c_TaskState = 'PND' THEN @c_CaseID ELSE DropID END,
                     TrafficCop = NULL
                 WHERE Pickdetailkey = @c_Pickdetailkey  
                                                                                                                                    
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END
               
               IF @c_TaskState = 'PND'  
               BEGIN
                    --Pick and drop loc no need update qty replen
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      SystemQty = SystemQty + @n_PickQty,
                      TrafficCop = NULL
                  WHERE Taskdetailkey = @c_Taskdetailkey

                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      TrafficCop = NULL
                  WHERE Taskdetailkey = @c_Taskdetailkey_PND
               END
               ELSE
               BEGIN                
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      SystemQty = SystemQty + @n_PickQty,
                      QtyReplen = CASE WHEN QtyReplen - @n_PickQty < 0 THEN 0 ELSE QtyReplen - @n_PickQty END
                  WHERE Taskdetailkey = @c_Taskdetailkey
               END
               
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Taskdetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
                                                                    
               SET @n_Qty = @n_Qty - @n_PickQty    
              END              
              ELSE
              BEGIN
                --split pickdetail to pick
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = Qty - @n_Qty
                 WHERE Pickdetailkey = @c_Pickdetailkey
                 
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
               END                  
            
                 INSERT INTO PICKDETAIL
                           (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                            Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                            WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                            TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                      Storerkey, Sku, AltSku, UOM, CASE WHEN UOM IN('6','7') THEN @n_Qty ELSE UOMQty END , @n_Qty, QtyMoved, Status,       
                      @c_CaseID, Loc, Id, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                      @c_Taskdetailkey, TaskManagerReasonKey, 'Split From Pickdetail#'+@c_Pickdetailkey + ' (MergeTsk)' , MoveRefKey                                                           
               FROM PICKDETAIL (NOLOCK)                                                                                             
               WHERE PickdetailKey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83100     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
               
               IF @c_TaskState = 'PND'  
               BEGIN
                    --Pick and drop loc no need update qty replen
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      SystemQty = SystemQty + @n_PickQty
                  WHERE Taskdetailkey = @c_Taskdetailkey
               END
               ELSE
               BEGIN
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      SystemQty = SystemQty + @n_PickQty,
                      QtyReplen = CASE WHEN QtyReplen - @n_PickQty < 0 THEN 0 ELSE QtyReplen - @n_PickQty END
                  WHERE Taskdetailkey = @c_Taskdetailkey
               END

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83110     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Taskdetail Table. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
               
               SET @n_Qty = 0    
              END
            
            FETCH NEXT FROM cur_RepLocPickDet INTO @c_Pickdetailkey, @n_Pickqty
         END
         CLOSE cur_RepLocPickDet
         DEALLOCATE cur_RepLocPickDet
                                                              
         FETCH NEXT FROM cur_combinereplen INTO @c_Taskdetailkey, @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty, @c_TaskState, @c_Taskdetailkey_PND, @c_CaseID
      END
      CLOSE cur_combinereplen
      DEALLOCATE cur_combinereplen              
    END
    IF @n_continue = 3
       ROLLBACK
    ELSE
       COMMIT TRAN   
    
    WHILE @@TRANCOUNT < @n_starttcnt
    BEGIN
       BEGIN TRAN
    END
    
    IF @@TRANCOUNT  = 0
      BEGIN TRAN
        
    -----Generate Pickslip No------
    /*
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       EXEC isp_CreatePickSlip
            @c_Wavekey = @c_Wavekey
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@b_Success = @b_Success OUTPUT
           ,@n_Err = @n_err OUTPUT 
           ,@c_ErrMsg = @c_errmsg OUTPUT        
       
       IF @b_Success = 0
          SELECT @n_continue = 3    
    END
    */
    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_Wavekey               = @c_wavekey  
           ,@c_WIP_RefNo             = @c_SourceType 
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT 
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
        IF @b_Success <> 1
        BEGIN
           SET @n_continue = 3
        END          
    END    
           
    -----Update Replenishment require flag to ORDRES
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN            
       UPDATE ORDERS WITH (ROWLOCK)
       SET ORDERS.OrderGroup = 'N',
           ORDERS.TrafficCop = NULL
       FROM WAVEDETAIL WD (NOLOCK)
       JOIN ORDERS ON WD.Orderkey = ORDERS.Orderkey    
       WHERE WD.Wavekey = @c_Wavekey 
       
       DECLARE cur_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT DISTINCT PD.Orderkey           
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey 
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = '0'
          AND LOC.LocationType <> 'PICK'
          ORDER BY PD.Orderkey

       OPEN cur_Order  
       
       FETCH NEXT FROM cur_Order INTO @c_Orderkey
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN                      
           UPDATE ORDERS WITH (ROWLOCK)
           SET OrderGroup = 'Y',
              TrafficCop = NULL          
           WHERE Orderkey = @c_Orderkey 
           
          FETCH NEXT FROM cur_Order INTO @c_Orderkey
       END
       CLOSE cur_Order
       DEALLOCATE cur_Order       
    END    
                           
    -----Create Replenishment task by pickdetail
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN            
       DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,
                 SKU.Busr9  --NJOW03           
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku --NJOW03
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = '0'
          AND PD.WIP_RefNo = @c_SourceType
          AND LOC.LocationType = 'BUFFER'
          AND ISNULL(PD.Taskdetailkey,'') = '' --NJOW01
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, LOC.LogicalLocation, 
                   SKU.Busr9 --NJOW03 
          ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot       
                 
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Busr9
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN             
          SET @c_PickMethod = 'PP'
          SET @c_UOM = '2'
          SET @n_UOMQty = 1
          
          --NJOW03 S
          SET @c_ToLoc = ''
          
          SELECT TOP 1 @c_ToLoc = Long
          FROM CODELKUP (NOLOCK)
          WHERE Storerkey = @c_Storerkey
          AND Code = @c_Busr9
          AND Listname = 'HMTASKLOC'
          
          IF ISNULL(@c_ToLoc,'') = ''
             SET @c_ToLoc = 'HM-DFLOCX'
          --NJOW03 E
    
          DECLARE cur_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
             SELECT U.UCCNo, U.Qty
             FROM UCC U (NOLOCK)
             LEFT JOIN TASKDETAIL T (NOLOCK) ON U.Storerkey = T.Storerkey AND U.Sku = T.Sku AND U.Lot = T.Lot
                                                AND U.Loc = T.FromLoc AND U.Id = T.FromID AND U.UccNo = T.CaseID
            LEFT JOIN REPLENISHMENT R (NOLOCK) ON  U.Storerkey = T.Storerkey AND U.Sku = T.Sku AND U.Lot = R.Lot
                                                  AND U.Loc = R.FromLoc AND U.Id = R.ID AND U.UCCNo = R.DropID AND R.Confirmed = 'N'                                                
             WHERE U.Storerkey = @c_Storerkey
             AND U.Sku = @c_Sku
             AND U.Lot = @c_Lot
             AND U.Loc = @c_FromLoc
             AND U.ID = @c_ID
             AND U.Status <= '3'
             ORDER BY CASE WHEN T.CaseID IS NULL AND R.DropID IS NULL THEN 1 ELSE 2 END, U.Qty
             
          OPEN cur_UCC  
          
          FETCH NEXT FROM cur_UCC INTO @c_UCCNo, @n_UCCQty
          
          SET @n_PickQty = @n_Qty          
          WHILE @@FETCH_STATUS = 0 AND @n_PickQty > 0 AND @n_continue IN(1,2)
          BEGIN            
             IF @n_UCCQty >= @n_PickQty
             BEGIN
                SET @n_SystemQty = @n_PickQty
                SET @n_PickQty = 0
             END
             ELSE
             BEGIN
                SET @n_SystemQty = @n_UCCQty
                SET @n_PickQty = @n_PickQty - @n_UCCQty
             END
             
             SET @c_CallSource = 'PICKREPL'
             
             --SET @c_ToLoc = 'HM-DFLOC'
             --GOTO FIND_DPP_LOC
             --RTN_FIND_DPP_LOC:

              EXEC isp_InsertTaskDetail   
                 @c_TaskType              = @c_TaskType             
                ,@c_Storerkey             = @c_Storerkey
                ,@c_Sku                   = @c_Sku
                ,@c_Lot                   = @c_Lot 
                ,@c_UOM                   = @c_UOM      
                ,@n_UOMQty                = @n_UOMQty  
                ,@n_Qty                   = @n_UCCQty
                ,@n_SystemQty             = @n_SystemQty      
                ,@c_FromLoc               = @c_Fromloc      
                ,@c_LogicalFromLoc        = @c_FromLoc 
                ,@c_FromID                = @c_ID     
                ,@c_ToLoc                 = @c_ToLoc       
                ,@c_LogicalToLoc          = @c_ToLoc 
                ,@c_ToID                  = @c_ID       
                ,@c_CaseID                = @c_UCCNo
                ,@c_PickMethod            = @c_PickMethod
                ,@c_Priority              = @c_Priority     
                ,@c_SourcePriority        = '9'      
                ,@c_SourceType            = @c_SourceType      
                ,@c_SourceKey             = @c_Wavekey      
                ,@c_WaveKey               = @c_Wavekey      
                ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                ,@c_ReserveQtyReplen      = 'ROUNDUP' --  ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
                ,@c_ReservePendingMoveIn  = 'Y'  -- Y=Update @n_qty to @n_PendingMoveIn
                ,@c_CombineTasks          = 'C'  -- C=Same as Y option but only combine when extra qty (qty-systemqty) is sufficient to cover systemqty. Usually apply for combine carton per task.
                ,@c_WIP_RefNo             = @c_SourceType
                ,@b_Success               = @b_Success OUTPUT
                ,@n_Err                   = @n_err OUTPUT 
                ,@c_ErrMsg                = @c_errmsg OUTPUT         
             
                IF @b_Success <> 1 
                BEGIN
                   SELECT @n_continue = 3  
                END               
                       
             FETCH NEXT FROM cur_UCC INTO @c_UCCNo, @n_UCCQty
          END
          CLOSE cur_UCC
          DEALLOCATE cur_UCC   
                                                                                       
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Busr9
       END 
       CLOSE cur_pick  
       DEALLOCATE cur_pick                                                
    END     
    
    -----Create Replenishment task by safety level
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN                  
       SELECT PD.Storerkey, PD.Sku, 
               CAST(SKU.Busr4 AS INT) AS SafetyStock,
              (SELECT SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn) 
               FROM LOTXLOCXID LLI (NOLOCK)
               JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
               WHERE LLI.Storerkey = PD.Storerkey 
               AND LLI.Sku = PD.Sku
               AND LOC.LocationType = 'PICK'
               AND LOC.Facility = @c_Facility) AS PickLocQty, --qty in pick loc including pendingmovein
              (SELECT SUM(TD.SystemQty)                        
               FROM TASKDETAIL TD (NOLOCK)            
               JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
               WHERE L.LocationType = 'PICK'          
               AND TD.TaskType = @c_TaskType          
               AND L.Facility = @c_Facility           
               --AND TD.SourceType = @c_SourceType      
               AND TD.Storerkey = PD.Storerkey 
               AND TD.Sku = PD.Sku
               AND TD.Status IN('0','H')                    
               AND TD.Qty > 0) AS QtyReplenForOrder  --qty include in pendingmovein to be picked after replen
       INTO #TMP_REPLENSKU                   
       FROM WAVEDETAIL WD (NOLOCK)
       JOIN #PICKDETAIL_WIP PD (NOLOCK) ON WD.Orderkey = PD.Orderkey 
       JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
       WHERE WD.Wavekey = @c_Wavekey
       AND PD.WIP_RefNo = @c_SourceType
       AND CASE WHEN ISNUMERIC(SKU.Busr4) = 1 THEN CAST(SKU.Busr4 AS INT) ELSE 0 END > 0
       GROUP BY PD.Storerkey, PD.Sku,
                CAST(SKU.Busr4 AS INT)
             
       DECLARE cur_replen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT R.Storerkey, R.Sku, R.SafetyStock, R.PickLocQty, R.QtyReplenForOrder
          FROM #TMP_REPLENSKU R
          WHERE R.SafetyStock > (R.PickLocQty - R.QtyReplenForOrder)
                 
       OPEN cur_replen  
       
       FETCH NEXT FROM cur_replen INTO @c_Storerkey, @c_Sku, @n_SafetyStock, @n_PickLocQty, @n_QtyReplenForOrder
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN          
           SET @n_PickQty = @n_SafetyStock - (@n_PickLocQty - @n_QtyReplenForOrder)
           
          DECLARE cur_buffer CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
             SELECT LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.Id,
                    LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen 
             FROM LOTATTRIBUTE (NOLOCK) 
             JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT 
             JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
             JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc 
             JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
             JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
             WHERE LOT.STORERKEY = @c_storerkey 
             AND LOT.SKU = @c_Sku
             AND LOT.STATUS = 'OK' 
             AND LOC.STATUS = 'OK' 
             AND ID.STATUS = 'OK'   
             AND LOC.LocationFlag = 'NONE' 
             AND LOC.Facility = @c_facility  
             AND LOC.LocationType = 'BUFFER'
             AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen > 0
             ORDER BY LOC.LocationGroup, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lot

          OPEN cur_buffer  
          
          FETCH NEXT FROM cur_buffer INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty
          
          WHILE @@FETCH_STATUS = 0 AND @n_PickQty > 0 AND @n_continue IN(1,2)
          BEGIN
             SET @c_PickMethod = 'PP'
             SET @c_UOM = '2'
             SET @n_UOMQty = 1
             SET @n_SystemQty = -1
             
             DECLARE cur_UCC2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR             
                SELECT  U.UCCNo,  U.Qty
                FROM UCC U (NOLOCK)
                LEFT JOIN TASKDETAIL T (NOLOCK) ON U.Storerkey = T.Storerkey AND U.Sku = T.Sku AND U.Lot = T.Lot
                                                   AND U.Loc = T.FromLoc AND U.Id = T.FromID  AND U.UccNo = T.CaseID
                 LEFT JOIN REPLENISHMENT R (NOLOCK) ON  U.Storerkey = T.Storerkey AND U.Sku = T.Sku AND U.Lot = R.Lot
                                                   AND U.Loc = R.FromLoc AND U.Id = R.ID AND U.UCCNo = R.DropID AND R.Confirmed = 'N'                                               
                WHERE U.Storerkey = @c_Storerkey
                AND U.Sku = @c_Sku
                AND U.Lot = @c_Lot
                AND U.Loc = @c_FromLoc
                AND U.ID = @c_ID
                AND U.Status <= '3'
                AND T.CaseID IS NULL
                AND R.DropID IS NULL
                ORDER BY U.Qty
             
             OPEN cur_UCC2  
             
             FETCH NEXT FROM cur_UCC2 INTO @c_UCCNo, @n_UCCQty
             
             WHILE @@FETCH_STATUS = 0 AND @n_PickQty > 0 AND @n_continue IN(1,2)
             BEGIN            
                IF @n_UCCQty >= @n_PickQty
                   SET @n_PickQty = 0
                ELSE
                   SET @n_PickQty = @n_PickQty - @n_UCCQty
                
               SET @c_CallSource = 'SAFTYREPL'
               SET @c_ToLoc = 'HM-DFLOC'
                --GOTO FIND_DPP_LOC
                --RTN_FIND_DPP_LOC_SAFTY:
             
                 EXEC isp_InsertTaskDetail   
                    @c_TaskType              = @c_TaskType             
                   ,@c_Storerkey             = @c_Storerkey
                   ,@c_Sku                   = @c_Sku
                   ,@c_Lot                   = @c_Lot 
                   ,@c_UOM                   = @c_UOM      
                   ,@n_UOMQty                = @n_UOMQty  
                   ,@n_Qty                   = @n_UCCQty
                   ,@n_SystemQty             = @n_SystemQty      
                   ,@c_FromLoc               = @c_Fromloc      
                   ,@c_LogicalFromLoc        = @c_FromLoc 
                   ,@c_FromID                = @c_ID     
                   ,@c_ToLoc                 = @c_ToLoc       
                   ,@c_LogicalToLoc          = @c_ToLoc 
                   ,@c_ToID                  = @c_ID       
                   ,@c_CaseID                = @c_UCCNo
                   ,@c_PickMethod            = @c_PickMethod
                   ,@c_Priority              = @c_Priority     
                   ,@c_SourcePriority        = '9'      
                   ,@c_SourceType            = @c_SourceType      
                   ,@c_SourceKey             = @c_Wavekey      
                   ,@c_WaveKey               = @c_Wavekey      
                   ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                   ,@c_ReserveQtyReplen      = 'TASKQTY' --  TASKQTY=Reserve all task qty for replenish at Lotxlocxid
                   ,@c_ReservePendingMoveIn  = 'Y'  -- Y=Update @n_qty to @n_PendingMoveIn
                   --,@c_CombineTasks          = 'Y' --Y=Combine task of same lot,from/to loc and id. usually apply for replenishment task with round up full case/pallet and systemqty is the actual pickdetail.qty
                   ,@c_WIP_RefNo             = @c_SourceType
                   ,@b_Success               = @b_Success OUTPUT
                   ,@n_Err                   = @n_err OUTPUT 
                   ,@c_ErrMsg                = @c_errmsg OUTPUT         
                
                   IF @b_Success <> 1 
                   BEGIN
                      SELECT @n_continue = 3  
                   END               
                          
                FETCH NEXT FROM cur_UCC2 INTO @c_UCCNo, @n_UCCQty
             END
             CLOSE cur_UCC2
             DEALLOCATE cur_UCC2     

                      
             FETCH NEXT FROM cur_buffer INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty
          END
          CLOSE cur_buffer
          DEALLOCATE cur_buffer
           
          FETCH NEXT FROM cur_replen INTO @c_Storerkey, @c_Sku, @n_SafetyStock, @n_PickLocQty, @n_QtyReplenForOrder
       END  
       CLOSE cur_replen
       DEALLOCATE cur_replen                  
    END
    
    --Update single or multi pickzone to orders  NJOW02
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       DECLARE cur_orderpickzone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT O.Orderkey, CASE WHEN COUNT(DISTINCT ISNULL(LOC.Pickzone,'')) > 1 THEN 'MULTIZONES' ELSE MAX(LOC.PickZone) END 
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN #PickDetail_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.WIP_RefNo = @c_SourceType
          GROUP BY O.Orderkey
                 
       OPEN cur_orderpickzone
       
       FETCH FROM cur_orderpickzone INTO @c_Orderkey, @c_Pickzone
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN         
           UPDATE ORDERS WITH (ROWLOCK)
           SET Userdefine02 = @c_PickZone,
               TrafficCop = NULL
           WHERE Orderkey = @c_Orderkey
           
          SELECT @n_err = @@ERROR
          
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83135   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orders Table Failed. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
             END                   
         
          FETCH FROM cur_orderpickzone INTO @c_Orderkey, @c_Pickzone           
       END
       CLOSE cur_orderpickzone
       DEALLOCATE cur_orderpickzone       
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
                
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    /*
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT PickDetail_WIP.PickDetailKey, PickDetail_WIP.Qty, PickDetail_WIP.UOMQty, 
                 PickDetail_WIP.TaskDetailKey, PickDetail_WIP.Pickslipno
          FROM PickDetail_WIP (NOLOCK)
          JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey
          WHERE ORDERS.Userdefine09 = @c_Wavekey 
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType
          ORDER BY PickDetail_WIP.PickDetailKey 
       
       OPEN cur_PickDetailKey
       
       FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_PickslipNo
       
       WHILE @@FETCH_STATUS = 0
       BEGIN
          IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
                    WHERE PickDetailKey = @c_PickDetailKey)
          BEGIN
             UPDATE PICKDETAIL WITH (ROWLOCK) 
             SET Qty = @n_Qty, 
                 UOMQty = @n_UOMQty, 
                 TaskDetailKey = @c_TaskDetailKey,
                 PickslipNo = @c_Pickslipno,
                 WaveKey = @c_Wavekey,
                 EditDate = GETDATE(),                             
                 TrafficCop = NULL
             WHERE PickDetailKey = @c_PickDetailKey  
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
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
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END         
          END
       
           FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno
       END   
       CLOSE cur_PickDetailKey
       DEALLOCATE cur_PickDetailKey             
    END
    */
          
    -----Validation taskdetail at pickdetail-----
    /*IF @n_continue = 1 or @n_continue = 2  
    BEGIN      
       IF EXISTS(SELECT 1 
                 FROM TASKDETAIL TD (NOLOCK)
                 LEFT JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey 
                 WHERE TD.Wavekey = @c_Wavekey                   
                 AND TD.Sourcetype = @c_SourceType 
                 AND TD.Tasktype IN('RFP')                 
                 AND PD.Taskdetailkey IS NULL)
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetailkey To Pickdetail Failed. (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                             
       END          
    END
    */
            
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
        
    IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
       DROP TABLE #PICKDETAIL_WIP
       
    /*   
    IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
              JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
              WHERE O.Userdefine09 = @c_Wavekey
              AND PD.WIP_RefNo = @c_SourceType)
    BEGIN
       DELETE PickDetail_WIP 
       FROM PickDetail_WIP (NOLOCK)
       JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey              
       WHERE ORDERS.Userdefine09 = @c_Wavekey 
       AND PickDetail_WIP.WIP_RefNo = @c_SourceType       
    END        
    */

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV14"  
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
    
    --------------------Function to find Dynamic Pick Loc--------------------- 
    /*
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
        ORDER BY LOC.LogicalLocation, DL.ToLoc
    END   
        
    -- If no location with same sku found, then assign the empty location
    IF ISNULL(@c_DPPLoc,'')=''
    BEGIN
        SELECT TOP 1 @c_DPPLoc = L.LOC
  FROM   LOC L (NOLOCK)
        WHERE  L.LocationType = 'PICK' 
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
        
    -- Terminate. Can't find any dynamic pick location
    IF ISNULL(@c_DPPLoc,'')=''
    BEGIN
       SELECT @n_continue = 3  
       SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82180   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pick Location Not Setup / Not enough Pick Location. (ispRLWAV08)(' + RTRIM(@c_callsource) + ') ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '       
       GOTO RETURN_SP
    END
    
    SELECT @c_ToLoc = @c_DPPLoc
    
    --Insert current location assigned
    IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED
                   WHERE Storerkey = @c_Storerkey
                   AND Sku = @c_Sku
                   AND ToLoc = @c_ToLoc)
    BEGIN
       INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc)
       VALUES (@c_Storerkey, @c_Sku, @c_Toloc )
    END
    
    IF @c_CallSource = 'PICKREPL'    
       GOTO RTN_FIND_DPP_LOC    

    IF @c_CallSource = 'SAFTYREPL'    
       GOTO RTN_FIND_DPP_LOC_SAFTY          
    */   
 END --sp end

GO