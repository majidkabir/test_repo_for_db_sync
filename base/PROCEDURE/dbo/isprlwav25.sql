SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV25                                          */  
/* Creation Date: 28-Mar-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-8405 - KR JUUL Wave Release replenishment by pallet      */
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.2                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 26-Jul-2019 NJOW01   1.0   WMS-9845 Full pallet order replen to       */
/*                            different location                         */
/* 17-Jan-2020 CHEEMUN  1.1   INC0968280 - Filter Qty>0 for Replenishment*/
/* 01-04-2020  Wan01    1.2   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV25]      
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
            ,@c_Toloc NVARCHAR(10)
            ,@c_ID NVARCHAR(18)
            ,@n_Qty INT
            ,@c_UOM NVARCHAR(10)
            ,@c_Packkey NVARCHAR(10)
            ,@c_ReplenishmentKey NVARCHAR(10)
            ,@c_PickUOM NVARCHAR(10)
            ,@c_ReplenishmentGroup NVARCHAR(10)
            ,@c_PLTToloc NVARCHAR(10)
           
    --Get sku,loc,id of the wave not in replenishment
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       SELECT PD.Storerkey, PD.Sku, PD.Loc, PD.ID, MIN(PD.UOM) AS PICKUOM
       INTO #TMP_PLTREPLEN
       FROM WAVEDETAIL WD (NOLOCK)
       JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
       JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
       LEFT JOIN REPLENISHMENT RP (NOLOCK) ON PD.storerkey = RP.Storerkey AND PD.Sku = RP.Sku AND PD.Loc = RP.FromLoc AND PD.ID = RP.ID 
                                           AND RP.confirmed = 'N' 
       WHERE WD.Wavekey = @c_Wavekey
       AND PD.Status = '0'
       AND RP.Replenishmentkey IS NULL
       --AND LOC.LocationType <> 'PICK'
       AND LOC.LocationType IN('BULK','OTHER')
       GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID
    END   

    --NJOW01
    IF @n_continue IN(1,2)
    BEGIN
       EXEC isp_CreatePickSlip
            @c_Wavekey = @c_Wavekey
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@c_ConsolidateByLoad = 'N'
           ,@b_Success = @b_Success OUTPUT
           ,@n_Err = @n_err OUTPUT 
           ,@c_ErrMsg = @c_errmsg OUTPUT        
       
       IF @b_Success = 0
          SELECT @n_continue = 3    
    END

    -----Wave Validation-----                    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 FROM #TMP_PLTREPLEN)
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  

          IF EXISTS(SELECT 1 FROM REPLENISHMENT (NOLOCK) WHERE Wavekey = @c_Wavekey AND OriginalFromLoc = 'ispRLWAV25')
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV25)'           
          ELSE           
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV25)'           
       END      
    END
    
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
       --Get all qty of the sku, loc, id to replen
       DECLARE CUR_PICKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, LLI.Qty, SKU.PutawayLoc, SKU.Packkey, PACK.PackUOM3, PRP.PickUOM
          FROM LOTXLOCXID LLI (NOLOCK)
          JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          JOIN #TMP_PLTREPLEN PRP ON LLI.Storerkey = PRP.Storerkey AND LLI.Sku = PRP.Sku AND LLI.Loc = PRP.Loc AND LLI.Id = PRP.Id
          WHERE LLI.Qty > 0   --INC0968280
          ORDER BY LLI.Sku, LLI.Loc                    
       
       OPEN CUR_PICKDET

       FETCH NEXT FROM CUR_PICKDET INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_ToLoc, @c_Packkey, @c_UOM, @c_PickUOM
       
       WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)
       BEGIN   
           IF @c_PickUOM = '1'
           BEGIN
             SET @c_PLTToloc = ''
             SELECT TOP 1 @c_PLTToloc = Long 
             FROM CODELKUP (NOLOCK)
             WHERE ListName = 'RDTREPLEN'
             AND Short = 'RPLTMP'
             AND Storerkey = @c_Storerkey
             
             IF ISNULL(@c_PLTToLoc,'') <> ''
                SET @c_ToLoc = @c_PLTToLoc
             
              SET @c_ReplenishmentGroup = 'RPLTMP'
           END   
           ELSE
              SET @c_ReplenishmentGroup = 'RPL'                
         
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
                 
          INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                         StorerKey,      SKU,         FromLOC,         ToLOC,
                         Lot,            Id,          Qty,             UOM,
                         PackKey,        Priority,    QtyMoved,        QtyInPickLOC,
                         RefNo,          Confirmed,   ReplenNo,        Wavekey,
                         Remark,         OriginalQty, OriginalFromLoc, ToID)
                     VALUES (
                         @c_ReplenishmentKey,         @c_ReplenishmentGroup,
                         @c_StorerKey,   @c_Sku,      @c_FromLoc,      @c_ToLoc,
                         @c_Lot,         @c_Id,       @n_Qty,          @c_UOM,
                         @c_Packkey,     '5',               0,               0,
                         '',                'N',          '',                  @c_WaveKey,
                         '',               @n_Qty,      'ispRLWAV25',    '')
          
          SET @n_err = @@ERROR
          
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83010     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLWAV25)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END      
   
          FETCH NEXT FROM CUR_PICKDET INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_ToLoc, @c_Packkey, @c_UOM, @c_PickUOM                     
       END                     
       CLOSE CUR_PICKDET
       DEALLOCATE CUR_PICKDET
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV25)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:
    
    IF OBJECT_ID('tempdb..#TMP_PLTREPLEN') IS NOT NULL
       DROP TABLE #TMP_PLTREPLEN

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV25"  
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