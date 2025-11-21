SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/    
/* Stored Procedure: ispRLWAV44                                             */    
/* Creation Date: 22-JUL-2021                                               */    
/* Copyright: LFL                                                           */    
/* Written by: WLChooi                                                      */    
/*                                                                          */    
/* Purpose: WMS-17548 - CN LULULEMON Release Wave to Replenishment          */  
/*                                                                          */    
/* Called By: Wave                                                          */    
/*                                                                          */    
/* GitLab Version: 1.0                                                      */    
/*                                                                          */    
/* Version: 7.0                                                             */    
/*                                                                          */    
/* Data Modifications:                                                      */    
/*                                                                          */    
/* Updates:                                                                 */    
/* Date        Author   Ver  Purposes                                       */    
/****************************************************************************/     
  
CREATE PROCEDURE [dbo].[ispRLWAV44]        
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
  
   DECLARE  @c_Storerkey          NVARCHAR(15)  
           ,@c_Sku                NVARCHAR(20)  
           ,@c_Facility           NVARCHAR(5)  
           ,@c_SourceType         NVARCHAR(30)  
           ,@c_WaveType           NVARCHAR(10)  
           ,@c_Userdefine01       NVARCHAR(20)  
           ,@n_NoofLoadPerBatch   INT  
           ,@c_Loadkey            NVARCHAR(10)  
           ,@c_LoadBatchNo        NVARCHAR(10)  
           ,@n_LoadSeq            INT  
           ,@n_BatchSeq           INT  
           ,@n_Loadcnt            INT  
           ,@n_Loccnt             INT  
           ,@n_QtyReplen          INT  
           ,@n_QtyFinal           INT             
           ,@c_Lot                NVARCHAR(10)  
           ,@c_FromLoc            NVARCHAR(10)  
           ,@c_ToLoc              NVARCHAR(10)  
           ,@c_ID                 NVARCHAR(18)  
           ,@c_ToID               NVARCHAR(18)  
           ,@c_Packkey            NVARCHAR(10)   
           ,@c_PackUOM            NVARCHAR(10)  
           ,@c_UOM                NVARCHAR(10)  
           ,@n_Qty                INT   
           ,@c_ReplenishmentKey   NVARCHAR(10)  
           ,@n_QtyAvailable       INT           
           ,@n_Casecnt            INT   
           ,@c_ItemClass          NVARCHAR(50)
           ,@c_Style              NVARCHAR(50)
           ,@c_Color              NVARCHAR(50)
           ,@c_Size               NVARCHAR(50)
                                          
   SET @c_SourceType = 'ispRLWAV44'      
  
   -----Get Storerkey, facility  
   IF  (@n_continue = 1 OR @n_continue = 2)  
   BEGIN  
       SELECT TOP 1 @c_Storerkey     = O.Storerkey,   
                    @c_Facility      = O.Facility,  
                    @c_WaveType      = W.WaveType,  
                    @c_Loadkey       = O.LoadKey
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released, please check former replenishment. (ispRLWAV44)'         
       END                   
   END  

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
       IF EXISTS (SELECT 1   
                  FROM REPLENISHMENT RP (NOLOCK)  
                  WHERE RP.Storerkey = @c_Storerkey
                  AND RP.Confirmed <> 'Y'    
                  )   
       BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 83015      
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable to Release this Wave. Please check former replenishment. (ispRLWAV44)'         
       END                   
   END  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
       IF EXISTS (SELECT 1   
                  FROM WAVEDETAIL WD (NOLOCK)  
                  JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = WD.Orderkey  
                  WHERE WD.Wavekey = @c_Wavekey      
                  AND OH.[Status] = '0'
                  )   
       BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 83020      
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave is partially allocated. (ispRLWAV44)'         
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
  
   --BEGIN TRAN  
     
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
     
   -----Create replenishment task
   IF (@n_continue = 1 OR @n_continue = 2)    
   BEGIN                                   
     --Retreive Pickdetail   
      DECLARE cur_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT SKU.SKU, SKU.itemclass, SKU.Style, SKU.Color, SKU.Size, PD.Storerkey, PD.Lot, PD.Loc, PD.Id, SUM(PD.Qty), PACK.Packkey, PACK.PackUOM3, PD.Uom, PACK.Casecnt
              , DENSE_RANK() OVER (ORDER BY SKU.itemclass, SKU.Style, SKU.Color, SKU.Size ) AS TOLOC
              , ISNULL(INV.QtyAvailable,0)
         FROM WAVEDETAIL WD (NOLOCK)   
         JOIN #PickDetail_WIP PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey             
         CROSS APPLY (SELECT LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen AS QtyAvailable 
                      FROM LOTXLOCXID LLI (NOLOCK)
                      WHERE LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.ID = PD.ID) AS INV
         WHERE WD.Wavekey = @c_Wavekey  
         GROUP BY SKU.SKU, SKU.itemclass, SKU.Style, SKU.Color, SKU.Size, PD.Storerkey, PD.Lot, PD.Loc, PD.Id, PACK.Packkey, PACK.PackUOM3, PD.UOM, PACK.Casecnt, ISNULL(INV.QtyAvailable,0)
         --ORDER BY PD.Sku, PD.Loc  
  
      OPEN cur_Pick  
        
      FETCH FROM cur_Pick INTO @c_Sku, @c_ItemClass, @c_Style, @c_Color, @c_Size, @c_Storerkey, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Packkey, @c_PackUOM, @c_UOM, @n_Casecnt, @c_ToLoc, @n_QtyAvailable
        
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN  
         SET @c_ToID =  @c_ID  

         SELECT @c_ToLoc = LOC.Loc
         FROM LOC (NOLOCK)
         WHERE LOC.Descr = @c_ToLoc
         AND LOC.DESCR <> ''
         AND LOC.Facility = @c_Facility
         AND LOC.PickZone = 'FAST'

         IF @c_ToLoc = ''  
         BEGIN  
            SELECT @n_continue = 3    
            SELECT @n_err = 83010      
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable find destination loc for Sku: ' + RTRIM(@c_Sku) + '. (ispRLWAV44)'          
            BREAK               
         END       

         IF @c_ID = ''
         BEGIN
            SET @n_QtyFinal = @n_Qty
         END
         ELSE
         BEGIN
            --Move whole ID, QtyAllocated + Inventory Qty
            SET @n_QtyFinal = @n_Qty + @n_QtyAvailable

            IF EXISTS (SELECT 1 FROM REPLENISHMENT R
                       WHERE R.Lot = @c_Lot
                       AND R.FromLoc = @c_FromLoc
                       AND R.ID = @c_ID
                       AND R.Confirmed = 'N')
            BEGIN
               SELECT @n_continue = 3    
               SELECT @n_err = 83020      
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The Carton ID# ' + @c_ID + 'is found in Replenishment table. (ispRLWAV44)'          
               BREAK  
            END
         END
                             
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
                  Wavekey,             Remark,              ReplenNo,  
                  OriginalQty,         OriginalFromLoc,     LoadKey)  
         VALUES ( '',                  @c_ReplenishmentKey, @c_StorerKey,   
                  @c_SKU,              @c_FromLOC,          @c_ToLOC,   
                  @c_LOT,              @c_ID,               @n_QtyFinal,   
                  @c_PackUOM,          @c_PackKey,          'N',   
                  @c_ReplenishmentKey, @c_ToID,             0,   
                  @n_QtyReplen,        0,                   '',  
                  @c_Wavekey,          '',                  '',   
                  @n_Qty,              @c_SourceType,       @c_Loadkey)    
  
         IF @@ERROR <> 0  
         BEGIN  
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060     -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLWAV44)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END                           
           
         UPDATE #PickDetail_WIP  
         SET MoveRefkey = @c_ReplenishmentKey  
         WHERE Storerkey = @c_Storerkey  
         AND Sku = @c_Sku          
         AND Lot = @c_Lot  
         AND Loc = @c_FromLoc  
         AND ID = @c_ID  
                                         
         FETCH FROM cur_Pick INTO @c_Sku, @c_ItemClass, @c_Style, @c_Color, @c_Size, @c_Storerkey, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Packkey, @c_PackUOM, @c_UOM, @n_Casecnt, @c_ToLoc, @n_QtyAvailable 
      END  
      CLOSE cur_Pick  
      DEALLOCATE cur_Pick  
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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV44)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV44"    
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