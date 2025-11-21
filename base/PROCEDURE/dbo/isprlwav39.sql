SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/  
/* Stored Procedure: ispRLWAV39                                             */  
/* Creation Date: 16-SEP-2020                                               */  
/* Copyright: LFL                                                           */  
/* Written by:                                                              */  
/*                                                                          */  
/* Purpose: WMS-14638 - CN Converse release task                            */
/*                                                                          */  
/* Called By: wave                                                          */  
/*                                                                          */  
/* PVCS Version: 1.1                                                        */  
/*                                                                          */  
/* Version: 7.0                                                             */  
/*                                                                          */  
/* Data Modifications:                                                      */  
/*                                                                          */  
/* Updates:                                                                 */  
/* Date        Author   Ver  Purposes                                       */  
/* 15-DEC-2021 SYChua   1.0  JSM-39991 - Add in checking for toloc = NULL   */
/*                           to display error message. (SY01)               */
/* 06-Sep-2021 NJOW01   1.1  WMS-17783 replenish extra qty for full case or */
/*                           zero balance after picked.                     */
/* 24-Sep-2021 NJOW     1.2  DEPVOP Script Combine                          */
/* 08-Mar-2023 NJOW02   1.3  WMS-21920 Replen one carton to zero pick loc   */
/* 13-Sep-2023 NJOW03   1.4  Fix top up partial carton not working          */
/****************************************************************************/   

CREATE   PROCEDURE [dbo].[ispRLWAV39]      
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

    DECLARE  @c_Storerkey            NVARCHAR(15)
            ,@c_Sku                  NVARCHAR(20)
            ,@c_Facility             NVARCHAR(5)
            ,@c_SourceType           NVARCHAR(30)
            ,@c_WaveType             NVARCHAR(10)
            ,@c_Userdefine01         NVARCHAR(20)
            ,@n_NoofLoadPerBatch     INT
            ,@c_Loadkey              NVARCHAR(10)
            ,@c_LoadBatchNo          NVARCHAR(10)
            ,@n_LoadSeq              INT
            ,@n_BatchSeq             INT
            ,@n_Loadcnt              INT
            ,@n_Loccnt               INT
            ,@n_QtyReplen            INT
            ,@n_QtyFinal             INT           
            ,@c_Lot                  NVARCHAR(10)
            ,@c_FromLoc              NVARCHAR(10)
            ,@c_FromLoc2             NVARCHAR(10)
            ,@c_ToLoc                NVARCHAR(10)
            ,@c_ID                   NVARCHAR(18)
            ,@c_ToID                 NVARCHAR(18)
            ,@c_Packkey              NVARCHAR(10) 
            ,@c_PackUOM              NVARCHAR(10)
            ,@c_UOM                  NVARCHAR(10)
            ,@n_Qty                  INT 
            ,@c_ReplenishmentKey     NVARCHAR(10)
            ,@n_QtyAvailable         INT         
            ,@n_Casecnt              INT
            ,@c_Lottable01           NVARCHAR(18)      
            ,@c_FondReplenishmentkey NVARCHAR(10) 
            ,@n_TopUpQty             INT
            ,@c_LotPick              NVARCHAR(10) --NJOW01
            ,@c_Prev_Toloc           NVARCHAR(10)='' --NJOW02
                                         
    SET @c_SourceType = 'ispRLWAV39'    

    -----Get Storerkey, facility
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey     = O.Storerkey, 
                     @c_Facility      = O.Facility,
                     @c_WaveType      = W.WaveType,
                     @c_Userdefine01  = W.Userdefine01
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey          
    END

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 
                   FROM REPLENISHMENT RP (NOLOCK)
                   WHERE RP.Wavekey = @c_Wavekey    
                   ) 
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV39)'       
        END                 
    END

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 
                   FROM WAVEDETAIL WD (NOLOCK)
                   JOIN LOADPLANDETAIL LPD (NOLOCK) ON WD.Orderkey = LPD.Orderkey
                   JOIN LOADPLAN LP (NOLOCK) ON LPD.Loadkey = LP.Loadkey
                   WHERE WD.Wavekey = @c_Wavekey    
                   AND ISNULL(LP.Userdefine09,'') <> ''
                   AND ISNULL(LP.Userdefine10,'') <> ''
                   ) 
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV39)'       
        END                 
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

 	  BEGIN TRAN
    
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
    
    -----Generate batch for load plan
    IF (@n_continue = 1 OR @n_continue = 2)   
    BEGIN
      IF ISNUMERIC(@c_Userdefine01) = 1
         SET @n_NoofLoadPerBatch = CAST(@c_Userdefine01 AS INT)
      ELSE
         SET @n_NoofLoadPerBatch = 1   
    
      DECLARE cur_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LPD.Loadkey
         FROM WAVEDETAIL WD (NOLOCK) 
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
         LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'CONVSHIP' AND O.C_City = CL.Notes 
         WHERE WD.Wavekey = @c_Wavekey
         GROUP BY LPD.Loadkey
         ORDER BY CASE WHEN ISNUMERIC(MAX(CL.Short)) = 1 THEN CAST(MAX(ISNULL(CL.Short,'0')) AS INT) ELSE 0 END

       OPEN cur_LOAD
       
       FETCH FROM cur_LOAD INTO @c_Loadkey
       
       SET @n_Loadseq = 0
       SET @n_Batchseq = 0
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
       	  SET @n_Loadcnt = @n_Loadcnt + 1
       	  SET @n_Loadseq = @n_Loadseq + 1
       	  
       	  IF @n_Loadcnt > @n_NoofLoadPerBatch OR @n_Batchseq = 0
       	  BEGIN
       	  	 SET @c_LoadBatchNo = ''
             EXECUTE nspg_getkey
                'CONVLPBTH'
                , 8
                , @c_LoadBatchNo OUTPUT
                , @b_success OUTPUT
                , @n_err OUTPUT
                , @c_errmsg OUTPUT
                
             IF NOT @b_success = 1
             BEGIN
                SELECT @n_continue = 3
             END
             
             SET @c_LoadBatchNo = 'CV' + @c_LoadBatchNo 
       	  	 
       	  	 SET @n_batchseq = @n_batchseq + 1 
       	  	 SET @n_Loadcnt = 1
       	  END
       	  
       	  UPDATE LOADPLAN WITH(ROWLOCK)
       	  SET Userdefine09 = @c_LoadBatchNo,
       	      Userdefine10 = RTRIM(CAST(@n_Batchseq AS NVARCHAR)) + '-' + RTRIM(CAST(@n_Loadseq AS NVARCHAR)), 
       	      TrafficCop = NULL
       	  WHERE Loadkey = @c_Loadkey       	  
       	  
       	  SET @n_err = @@ERROR 

          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Loadplan Table. (ispRLWAV39)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END                                
       	
          FETCH FROM cur_LOAD INTO @c_Loadkey
       END
       CLOSE cur_LOAD
       DEALLOCATE cur_LOAD              	
    END    	                                    
    
    -----Create replenishment task for strategy 1 (pick by load)
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveType = '1'   
    BEGIN    	                            
    	 --Retreive UCC pick 
       DECLARE cur_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.Id, SUM(PD.Qty), PACK.Packkey, PACK.PackUOM3, PD.Uom, PACK.Casecnt, ISNULL(INV.QtyAvailable,0), LA.Lottable01
          FROM WAVEDETAIL WD (NOLOCK) 
          JOIN #PickDetail_WIP PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc          
          JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          CROSS APPLY (SELECT LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen AS QtyAvailable FROM LOTXLOCXID LLI (NOLOCK) WHERE LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.ID = PD.ID) AS INV           
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.UOM = '6'
          AND LOC.LocationType = 'OTHER'  --NJOW01
       	  AND LOC.LocationCategory = 'BULK' --NJOW01                	     
       	  AND LA.Lottable01 IN('10','20','30')
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.Id, PACK.Packkey, PACK.PackUOM3, PD.UOM, PACK.Casecnt, ISNULL(INV.QtyAvailable,0), LA.Lottable01
          ORDER BY PD.Sku, PD.Loc

       OPEN cur_Pick
       
       FETCH FROM cur_Pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Packkey, @c_PackUOM, @c_UOM, @n_Casecnt, @n_QtyAvailable, @c_Lottable01
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN       	       	
       	  SET @c_ToID =  @c_ID
       	  SET @c_ToLoc = ''
       	         	  
       	  SET @n_QtyFinal = @n_Qty --NJOW01  Top up full carton at next step
       	  /*
       	  SET @n_QtyFinal =  CEILING(@n_Qty / (@n_Casecnt * 1.00)) * @n_CaseCnt --by full case  
       	  
       	  IF (@n_QtyFinal - @n_Qty) > @n_QtyAvailable  --if no more full case take all
       	     SET @n_QtyFinal = @n_Qty + @n_QtyAvailable       	     
       	  */

          SELECT @c_ToLoc = MAX(SL.Loc), 
                 @n_Loccnt = COUNT(1)         
          FROM SKUXLOC SL (NOLOCK)
          JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc
          WHERE SL.Storerkey = @c_Storerkey
          AND SL.Sku = @c_Sku
          AND SL.LocationType = 'PICK'
          AND LOC.LocationRoom = @c_Lottable01
          
          IF @n_Loccnt > 1 
          BEGIN
             SELECT @n_continue = 3  
             SELECT @n_err = 83040    
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow multiple destination loc for Sku' + RTRIM(@c_Sku) + ' Lottable01: ' + RTRIM(@c_Lottable01)  + '. (ispRLWAV39)'        
             BREAK      	     	
          END
       	         	            	    
          IF ISNULL(@c_ToLoc,'') = '' --@c_ToLoc = ''          --SY01
       	  BEGIN
             SELECT @n_continue = 3  
             SELECT @n_err = 83050    
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable find destination loc for Sku' + RTRIM(@c_Sku) + ' Lottable01: ' + RTRIM(@c_Lottable01)  + '. (ispRLWAV39)'        
             BREAK      	     	
          END     
          
          IF @n_Qty = @n_QtyFinal  	            	     
       	  
       	  SET @c_ReplenishmentKey = ''   
          EXECUTE nspg_getkey
             'REPLENISHKEY'
             , 10
             , @c_ReplenishmentKey OUTPUT
             , @b_success OUTPUT
             , @n_err OUTPUT
             , @c_errmsg OUTPUT
             
          IF NOT @b_success = 1
          BEGIN
             SELECT @n_continue = 3
          END
          
          SET @n_QtyReplen = @n_QtyFinal - @n_Qty

          INSERT INTO REPLENISHMENT(
                   Replenishmentgroup,  ReplenishmentKey,    StorerKey,
                   Sku,                 FromLoc,             ToLoc,
                   Lot,                 Id,                  Qty,
                   UOM,                 PackKey,             Confirmed, 
                   MoveRefKey,          ToID,                PendingMoveIn, 
                   QtyReplen,           QtyInPickLoc,        RefNo, 
                   Wavekey,						  Remark,					     ReplenNo,
                   OriginalQty,				  OriginalFromLoc)
          VALUES ('', 								  @c_ReplenishmentKey, @c_StorerKey, 
                   @c_SKU,              @c_FromLOC,          @c_ToLOC, 
                   @c_LOT,              @c_ID,               @n_QtyFinal, 
                   @c_PackUOM,          @c_PackKey,          'N', 
                   @c_ReplenishmentKey, @c_ToID,             0, 
                   @n_QtyReplen,			  0, 									 '',
                   @c_Wavekey,				  '',									 '', 
                   @n_Qty,						  @c_SourceType)  

          IF @@ERROR <> 0
          BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLWAV39)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END                         
          
          UPDATE #PickDetail_WIP
          SET MoveRefkey = @c_ReplenishmentKey
          WHERE UOM = '6'
          AND Storerkey = @c_Storerkey
          AND Sku = @c_Sku        
          AND Lot = @c_Lot
          AND Loc = @c_FromLoc
          AND ID = @c_ID
                           	         	  
          FETCH FROM cur_Pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Packkey, @c_PackUOM, @c_UOM, @n_Casecnt, @n_QtyAvailable, @c_Lottable01
       END
       CLOSE cur_Pick
       DEALLOCATE cur_Pick
    END
    
     --NJOW01
    -----Create extra replenishment task if zero qty after picked for strategy 1 (pick by load)
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveType = '1'   
    BEGIN    	                            
    	 --Retreive replenishment with zero balance after picked
       DECLARE cur_replen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT RP.Storerkey, RP.Sku, RP.FromLoc, RP.Toloc, PACK.CaseCnt, PACK.Casecnt, PACK.Packkey, PACK.PackUOM3, LA.Lottable01
          FROM REPLENISHMENT RP (NOLOCK)        
    	    JOIN LOTATTRIBUTE LA (NOLOCK) ON RP.Lot = LA.Lot             
          JOIN SKU (NOLOCK) ON RP.Storerkey = SKU.Storerkey AND RP.Sku = SKU.Sku 
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          WHERE RP.Wavekey = @c_Wavekey
          AND RP.Confirmed = 'N'
          AND RP.OriginalFromLoc = @c_SourceType
          AND PACK.Casecnt > 0
          AND NOT EXISTS(SELECT 1 FROM LOTXLOCXID LLI (NOLOCK) 
                         WHERE LLI.Storerkey = RP.Storerkey 
                         AND LLI.Sku = RP.Sku
                         AND LLI.Loc = RP.ToLoc
                         AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0)
          GROUP BY RP.Storerkey, RP.Sku, RP.FromLoc, RP.Toloc, PACK.Casecnt, PACK.Packkey,  PACK.PackUOM3, LA.Lottable01
          HAVING SUM(RP.Qty) % CAST(PACK.Casecnt AS INT) = 0   --full case only. if partial case will have extra replen for full case at next step
                 AND SUM(RP.Qty) = SUM(RP.OriginalQty)   --picked all
          ORDER BY RP.ToLoc --NJOW02
                  
       OPEN cur_replen
       
       FETCH FROM cur_replen INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ToLOC, @n_Qty, @n_Casecnt, @c_PackKey, @c_PackUOM, @c_Lottable01
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN       	    
       	  --NJOW02 S   	     
       	  IF @c_ToLoc = @c_Prev_ToLoc  -- one pick only replen extra one case
       	     GOTO NEXT_REP
       	            	     
       	  IF EXISTS(SELECT 1 
       	            FROM REPLENISHMENT RP (NOLOCK)        
                    JOIN SKU (NOLOCK) ON RP.Storerkey = SKU.Storerkey AND RP.Sku = SKU.Sku 
                    JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
                    WHERE RP.Wavekey = @c_Wavekey
                    AND RP.Confirmed = 'N'
                    AND RP.OriginalFromLoc = @c_SourceType
                    AND PACK.Casecnt > 0
                    AND RP.ToLoc = @c_ToLoc
                    AND RP.Qty % CAST(PACK.Casecnt AS INT) > 0)  --replen carton have remain qty after picked
       	     GOTO NEXT_REP      
       	  --NJOW02 E    	     
                              	         	
       	  DECLARE cur_LocQtyAvai CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       	     SELECT LLI.Lot, LLI.Id, LLI.Loc, 
       	            LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen AS QtyAvailable 
       	     FROM LOTXLOCXID LLI (NOLOCK)
       	     JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
       	     JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
       	     JOIN ID (NOLOCK) ON LLI.Id = ID.Id
       	     JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot 
       	     WHERE LLI.Storerkey = @c_Storerkey 
       	     AND LLI.Sku = @c_Sku
       	     --AND LLI.Loc = @c_FromLoc 
       	     AND LOC.LocationType = 'OTHER'
       	     AND LOC.LocationCategory = 'BULK'
       	     AND LOC.LocationFlag = 'NONE' 
       	     AND LOC.Status = 'OK'
       	     AND LOT.Status = 'OK'
       	     AND ID.Status = 'OK'
       	     AND LA.Lottable01 IN('10','20','30')
       	     AND LA.Lottable01 = @c_Lottable01
       	     AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0
       	     ORDER BY CASE WHEN LLI.Loc = @c_FromLoc THEN 1 ELSE 2 END,  --find from same loc first 
       	              LA.Lottable05, LA.Lot, LOC.Logicallocation, LOC.Loc
           	                 	                    	
          OPEN cur_LocQtyAvai
       
          FETCH FROM cur_LocQtyAvai INTO  @c_Lot, @c_ID, @c_FromLoc2, @n_QtyAvailable
       
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_Qty > 0
          BEGIN                                                            
          	 SET @c_ToID =  @c_ID
          	 
          	 IF @n_QtyAvailable >= @n_Qty
          	    SET @n_QtyFinal = @n_Qty
          	 ELSE
          	    SET @n_QtyFinal = @n_QtyAvailable   

          	 SET @n_Qty = @n_Qty - @n_QtyFinal   

             SET @c_FondReplenishmentkey = ''
             
          	 SELECT @c_FondReplenishmentkey = Replenishmentkey
          	 FROM REPLENISHMENT (NOLOCK)
          	 WHERE Storerkey = @c_Storerkey
          	 AND Sku = @c_Sku
          	 AND Lot = @c_Lot
          	 AND FromLoc = @c_FromLoc2
          	 AND Id = @c_ID
          	 AND Toloc = @c_Toloc
          	 AND Confirmed = 'N'
          	 AND Wavekey = @c_Wavekey
             AND OriginalFromLoc = @c_SourceType
          	 
          	 IF ISNULL(@c_FondReplenishmentkey,'') <> '' 
          	 BEGIN
          	 	  UPDATE REPLENISHMENT WITH (ROWLOCK)
          	 	  SET Qty = Qty + @n_QtyFinal,
          	 	      ArchiveCop = NULL
          	 	  WHERE Replenishmentkey = @c_FondReplenishmentkey              		           	 	      

          	 	  UPDATE REPLENISHMENT WITH (ROWLOCK)
          	 	  SET QtyReplen = QtyReplen + @n_QtyFinal
          	 	  WHERE Replenishmentkey = @c_FondReplenishmentkey        
          	 	                  
                IF @@ERROR <> 0
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Replenishment Table. (ispRLWAV39)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                END                	 	  
          	 END
          	 ELSE
          	 BEGIN          	 	  
                SET @c_ReplenishmentKey = ''          	 	
                EXECUTE nspg_getkey
                   'REPLENISHKEY'
                   , 10
                   , @c_ReplenishmentKey OUTPUT
                   , @b_success OUTPUT
                   , @n_err OUTPUT
                   , @c_errmsg OUTPUT
                   
                IF NOT @b_success = 1
                BEGIN
                   SELECT @n_continue = 3
                END          	                 
           	              	 
                INSERT INTO REPLENISHMENT(
                         Replenishmentgroup,  ReplenishmentKey,    StorerKey,
                         Sku,                 FromLoc,             ToLoc,
                         Lot,                 Id,                  Qty,
                         UOM,                 PackKey,             Confirmed, 
                         MoveRefKey,          ToID,                PendingMoveIn, 
                         QtyReplen,           QtyInPickLoc,        RefNo, 
                         Wavekey,						 Remark,					    ReplenNo,
                         OriginalQty,				 OriginalFromLoc)
                VALUES ('', 								   @c_ReplenishmentKey, @c_StorerKey, 
                         @c_SKU,              @c_FromLOC2,          @c_ToLOC, 
                         @c_LOT,              @c_ID,               @n_QtyFinal, 
                         @c_PackUOM,          @c_PackKey,          'N', 
                         @c_ReplenishmentKey, @c_ToID,             0, 
                         @n_QtyFinal,			   0, 									  'EXTRACTN',
                         @c_Wavekey,				   '',									  '', 
                         0,								   @c_SourceType)  
                
                IF @@ERROR <> 0
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLWAV39)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                END      
             END                                	    
          	 
             FETCH FROM cur_LocQtyAvai INTO  @c_Lot, @c_ID, @c_FromLoc2, @n_QtyAvailable
          END       	
          CLOSE cur_LocQtyAvai
          DEALLOCATE cur_LocQtyAvai
          
          NEXT_REP:
          
          SET @c_Prev_ToLoc = @c_ToLoc  --NJOW02
          
          FETCH FROM cur_replen INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ToLOC, @n_Qty, @n_Casecnt, @c_PackKey, @c_PackUOM, @c_Lottable01          
       END        
       CLOSE cur_replen
       DEALLOCATE cur_replen  	
    END

    --NJOW01
    -----Create replenishment task for pick loc with zero qty and without any current repleniment for strategy 1 (pick by load)
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveType = '1'   
    BEGIN    	                            
    	 --Retreive replenishment with zero balance after allocated
       DECLARE cur_pickreplen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT SL.Storerkey, SL.SKU, SL.Loc, PACK.CaseCnt, PACK.Packkey, PACK.PackUOM3, MAX(LA.Lottable01), MAX(PD.Lot)
          FROM SKUXLOC SL(NOLOCK)
          JOIN #PickDetail_WIP PD (NOLOCK) ON SL.Storerkey = PD.Storerkey AND SL.Sku = PD.Sku AND SL.Loc = PD.Loc 
          JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
          JOIN SKU (NOLOCK) ON SL.Storerkey = SKU.Storerkey AND SL.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          WHERE SL.Qty - SL.QtyAllocated - SL.QtyPicked = 0
          AND SL.LocationType IN('PICK','CASE')          
          AND NOT EXISTS(SELECT 1 
                         FROM REPLENISHMENT RP (NOLOCK) 
                         WHERE RP.Storerkey = SL.Storerkey
                         AND RP.Sku = SL.Sku
                         AND RP.ToLoc = SL.Loc
                         AND RP.Confirmed = 'N')
          GROUP BY SL.Storerkey, SL.SKU, SL.Loc, PACK.CaseCnt, PACK.Packkey, PACK.PackUOM3               
                                                           
       OPEN cur_pickreplen
       
       FETCH FROM cur_pickreplen INTO @c_Storerkey, @c_Sku, @c_ToLoc, @n_Casecnt, @c_PackKey, @c_PackUOM, @c_Lottable01, @c_LotPick
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN       	       	         	
       	  DECLARE cur_LocQtyAvai CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       	     SELECT LLI.Lot, LLI.Id, LLI.Loc, 
       	            LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen AS QtyAvailable 
       	     FROM LOTXLOCXID LLI (NOLOCK)
       	     JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
       	     JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
       	     JOIN ID (NOLOCK) ON LLI.Id = ID.Id
       	     JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot 
       	     WHERE LLI.Storerkey = @c_Storerkey 
       	     AND LLI.Sku = @c_Sku
       	     AND LOC.LocationType = 'OTHER'
       	     AND LOC.LocationCategory = 'BULK'
       	     AND LOC.LocationFlag = 'NONE' 
       	     AND LOC.Status = 'OK'
       	     AND LOT.Status = 'OK'
       	     AND ID.Status = 'OK'
       	     AND LA.Lottable01 IN('10','20','30')
       	     AND LA.Lottable01 = @c_Lottable01
       	     AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0
       	     ORDER BY CASE WHEN LA.Lot = @c_LotPick THEN 1 ELSE 2 END,  --find same lot frist
       	              CASE WHEN LA.Lottable01 = @c_Lottable01 THEN 1 ELSE 2 END,  --find from same lottable first 
       	              LA.Lottable05, LA.Lot, LOC.Logicallocation, LOC.Loc
       	
          OPEN cur_LocQtyAvai
       
          FETCH FROM cur_LocQtyAvai INTO  @c_Lot, @c_ID, @c_FromLoc, @n_QtyAvailable
          
          SET @n_Qty = @n_CaseCnt
          
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_Qty > 0
          BEGIN                                                            
          	 SET @c_ToID =  @c_ID
          	 
          	 IF @n_QtyAvailable >= @n_Qty
          	    SET @n_QtyFinal = @n_Qty
          	 ELSE
          	    SET @n_QtyFinal = @n_QtyAvailable   

          	 SET @n_Qty = @n_Qty - @n_QtyFinal   

             SET @c_ReplenishmentKey = ''          	 	
             EXECUTE nspg_getkey
                'REPLENISHKEY'
                , 10
                , @c_ReplenishmentKey OUTPUT
                , @b_success OUTPUT
                , @n_err OUTPUT
                , @c_errmsg OUTPUT
                
             IF NOT @b_success = 1
             BEGIN
                SELECT @n_continue = 3
             END          	                 
           	           	 
             INSERT INTO REPLENISHMENT(
                      Replenishmentgroup,  ReplenishmentKey,    StorerKey,
                      Sku,                 FromLoc,             ToLoc,
                      Lot,                 Id,                  Qty,
                      UOM,                 PackKey,             Confirmed, 
                      MoveRefKey,          ToID,                PendingMoveIn, 
                      QtyReplen,           QtyInPickLoc,        RefNo, 
                      Wavekey,						 Remark,					    ReplenNo,
                      OriginalQty,				 OriginalFromLoc)
             VALUES ('', 								   @c_ReplenishmentKey, @c_StorerKey, 
                      @c_SKU,              @c_FromLoc,          @c_ToLoc, 
                      @c_LOT,              @c_ID,               @n_QtyFinal, 
                      @c_PackUOM,          @c_PackKey,          'N', 
                      @c_ReplenishmentKey, @c_ToID,             0, 
                      @n_QtyFinal,			   0, 									  'EXTRAPKCTN',
                      @c_Wavekey,				   '',									  '', 
                      0,								   @c_SourceType)  
             
             IF @@ERROR <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83085     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLWAV39)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END      
          	 
             FETCH FROM cur_LocQtyAvai INTO  @c_Lot, @c_ID, @c_FromLoc, @n_QtyAvailable
          END       	
          CLOSE cur_LocQtyAvai
          DEALLOCATE cur_LocQtyAvai
          
          FETCH FROM cur_pickreplen INTO @c_Storerkey, @c_Sku, @c_ToLoc, @n_Casecnt, @c_PackKey, @c_PackUOM, @c_Lottable01, @c_LotPick
       END        
       CLOSE cur_pickreplen
       DEALLOCATE cur_pickreplen  	
    END

    --NJOW01
    -----Create extra replenishment task to top up partial carton from different lot for strategy 1 (pick by load)
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveType = '1'   
    BEGIN    	                            
    	 --Retreive replenishment with loose carton
       DECLARE cur_replen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT RP.Storerkey, RP.Sku, RP.FromLoc, RP.Toloc, SUM(RP.Qty) % CAST(PACK.Casecnt AS INT), PACK.Casecnt, PACK.Packkey, PACK.PackUOM3, LA.Lottable01
          FROM REPLENISHMENT RP (NOLOCK)        
    	    JOIN LOTATTRIBUTE LA (NOLOCK) ON RP.Lot = LA.Lot             
          JOIN SKU (NOLOCK) ON RP.Storerkey = SKU.Storerkey AND RP.Sku = SKU.Sku 
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          WHERE RP.Wavekey = @c_Wavekey
          AND RP.Confirmed = 'N'
          AND RP.OriginalFromLoc = @c_SourceType
          AND PACK.Casecnt > 0
          GROUP BY RP.Storerkey, RP.Sku, RP.FromLoc, RP.Toloc, PACK.Casecnt, PACK.Packkey,  PACK.PackUOM3, LA.Lottable01
          HAVING  SUM(RP.Qty) % CAST(PACK.Casecnt AS INT) > 0  --NJOW03
                           
       OPEN cur_replen
       
       FETCH FROM cur_replen INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ToLOC, @n_Qty, @n_Casecnt, @c_PackKey, @c_PackUOM, @c_Lottable01
              
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
       	  SET @n_TopUpQty = @n_Casecnt - @n_Qty 
       	  
       	  DECLARE cur_LocQtyAvai CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       	     SELECT LLI.Lot, LLI.Id, 
       	            LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen AS QtyAvailable 
       	     FROM LOTXLOCXID LLI (NOLOCK)       	     
       	     JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
       	     OUTER APPLY (SELECT TOP 1 R.Lot FROM REPLENISHMENT R (NOLOCK) WHERE R.Lot = LLI.Lot AND R.FromLoc = LLI.Loc AND R.Toloc = @c_ToLoc 
       	                  AND R.Wavekey = @c_Wavekey AND R.OriginalFromLoc = @c_SourceType AND R.Confirmed = 'N') AS RP
       	     WHERE LLI.Storerkey = @c_Storerkey 
       	     AND LLI.Sku = @c_Sku
       	     AND LLI.Loc = @c_FromLoc 
       	     AND LA.Lottable01 IN('10','20','30')
       	     AND LA.Lottable01 = @c_Lottable01
       	     AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0
       	     ORDER BY CASE WHEN RP.Lot IS NOT NULL THEN 1 ELSE 2 END, LA.Lottable05, LA.Lot       	            	
       	
          OPEN cur_LocQtyAvai
       
          FETCH FROM cur_LocQtyAvai INTO  @c_Lot, @c_ID, @n_QtyAvailable
       
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_TopUpQty  > 0
          BEGIN                                                            
          	 SET @c_ToID =  @c_ID
          	 
          	 IF @n_QtyAvailable >= @n_TopUpQty
          	    SET @n_QtyFinal = @n_TopUpQty
          	 ELSE
          	    SET @n_QtyFinal = @n_QtyAvailable   
          	    
          	 SET @n_TopUpQty = @n_TopUpQty - @n_QtyFinal   
          	    
             SET @c_FondReplenishmentkey = ''
    	       
    	       SELECT @c_FondReplenishmentkey = Replenishmentkey
          	 FROM REPLENISHMENT (NOLOCK)
          	 WHERE Storerkey = @c_Storerkey
          	 AND Sku = @c_Sku
          	 AND Lot = @c_Lot
          	 AND FromLoc = @c_FromLoc
          	 AND Id = @c_ID
          	 AND Toloc = @c_Toloc
          	 AND Confirmed = 'N'
          	 AND Wavekey = @c_Wavekey
             AND OriginalFromLoc = @c_SourceType
                       	           	 
          	 IF ISNULL(@c_FondReplenishmentkey,'') <> '' 
          	 BEGIN
          	 	  UPDATE REPLENISHMENT WITH (ROWLOCK)
          	 	  SET Qty = Qty + @n_QtyFinal,
          	 	      ArchiveCop = NULL
          	 	  WHERE Replenishmentkey = @c_FondReplenishmentkey              		           	 	      

          	 	  UPDATE REPLENISHMENT WITH (ROWLOCK)
          	 	  SET QtyReplen = QtyReplen + @n_QtyFinal
          	 	  WHERE Replenishmentkey = @c_FondReplenishmentkey              		           	 	      
                
                IF @@ERROR <> 0
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Replenishment Table. (ispRLWAV39)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                END
             END
             ELSE
             BEGIN                                      
                SET @c_ReplenishmentKey = ''
                EXECUTE nspg_getkey
                   'REPLENISHKEY'
                   , 10
                   , @c_ReplenishmentKey OUTPUT
                   , @b_success OUTPUT
                   , @n_err OUTPUT
                   , @c_errmsg OUTPUT
                   
                IF NOT @b_success = 1
                BEGIN
                   SELECT @n_continue = 3
                END          	    
                                          	    
                INSERT INTO REPLENISHMENT(
                         Replenishmentgroup,  ReplenishmentKey,    StorerKey,
                         Sku,                 FromLoc,             ToLoc,
                         Lot,                 Id,                  Qty,
                         UOM,                 PackKey,             Confirmed, 
                         MoveRefKey,          ToID,                PendingMoveIn, 
                         QtyReplen,           QtyInPickLoc,        RefNo, 
                         Wavekey,						 Remark,					    ReplenNo,
                         OriginalQty,				 OriginalFromLoc)
                VALUES ('', 								   @c_ReplenishmentKey, @c_StorerKey, 
                         @c_SKU,              @c_FromLOC,          @c_ToLOC, 
                         @c_LOT,              @c_ID,               @n_QtyFinal, 
                         @c_PackUOM,          @c_PackKey,          'N', 
                         @c_ReplenishmentKey, @c_ToID,             0, 
                         @n_QtyFinal,			   0, 									  'FULLCTN',
                         @c_Wavekey,				   '',									  '', 
                         0,								   @c_SourceType)  
                
                IF @@ERROR <> 0
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83100     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLWAV39)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                END        
             END                           	    
          	 
             FETCH FROM cur_LocQtyAvai INTO  @c_Lot, @c_ID, @n_QtyAvailable
          END       	
          CLOSE cur_LocQtyAvai
          DEALLOCATE cur_LocQtyAvai
          
          FETCH FROM cur_replen INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ToLOC, @n_Qty, @n_Casecnt, @c_PackKey, @c_PackUOM, @c_Lottable01          
       END        
       CLOSE cur_replen
       DEALLOCATE cur_replen  	
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

    -----Generate Pickslip No------    
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       EXEC isp_CreatePickSlip
            @c_Wavekey = @c_Wavekey
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@c_ConsolidateByLoad = 'Y'
           ,@c_AutoScanIn = 'Y'
           --,@c_Refkeylookup = 'Y'
           --,@c_PickslipType = 'LB'  --Discrete('8', '3', 'D')  Conso('5','6','7','9','C')  Xdock ('XD','LB','LP')
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
          SET TMReleaseFlag = 'Y'
           ,  TrafficCop = NULL  
           ,  EditWho = SUSER_SNAME() 
           ,  EditDate= GETDATE()     
       WHERE WAVEKEY = @c_wavekey    
              
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV39)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

    -----Delete pickdetail_WIP work in progress staging table
    /*
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV39"  
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