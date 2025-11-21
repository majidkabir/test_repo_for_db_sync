SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLBLP06                                          */  
/* Creation Date: 24-Aug-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-14842 NIKE ECOM Replenishment generation on Build Load   */
/*                                                                       */  
/* Config Key = 'BuildLoadReleaseTask_SP'                                */  
/*                                                                       */  
/* Called By: isp_BuildLoadReleaseTask_Wrapper                           */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLBLP06]      
  @c_Loadkey      NVARCHAR(10)  
 ,@b_Success      INT        OUTPUT  
 ,@n_err          INT        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT
 ,@c_Storerkey    NVARCHAR(15) = '' 

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

   DECLARE  @c_Sku NVARCHAR(20)
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
           ,@n_CaseCnt INT
           ,@n_QtyAllocated INT
           ,@n_TotalCarton INT
           ,@n_ReplenQty INT
           ,@n_QtyAvailable INT

   SELECT @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE Loadkey = @c_Loadkey

   --Temp table for Codelkup
   CREATE TABLE #TMP_PZone (
      Putawayzone   NVARCHAR(10)
   )

   INSERT INTO #TMP_PZone (Putawayzone)
   SELECT CL.Code
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Listname = 'NKERPLZONE' AND (CL.Storerkey = @c_Storerkey OR ISNULL(CL.Storerkey,'') = '')
   ORDER BY CASE WHEN ISNULL(CL.Storerkey,'') = '' THEN 2 ELSE 1 END

   --Only replen where LOC.Putawayzone exists in Codelkup
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, MIN(PD.UOM) AS PICKUOM, MAX(F.UserDefine12) AS ToLoc, SUM(PD.Qty) AS QtyAllocated
      INTO #TMP_REPLEN
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      JOIN LOADPLAN LP (NOLOCK) ON LP.Loadkey = LPD.Loadkey
      JOIN Facility F (NOLOCK) ON F.Facility = LP.Facility
      JOIN #TMP_PZone PZ (NOLOCK) ON PZ.Putawayzone = LOC.Putawayzone
      WHERE LPD.Loadkey = @c_Loadkey
      AND PD.Status = '0'
      GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID

      IF EXISTS (SELECT 1 FROM #TMP_REPLEN WHERE ISNULL(ToLoc,'') = '')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81000     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ToLoc (Facility.Userdefine12) is NULL/Blank. (ispRLBLP06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
         GOTO RETURN_SP
      END
   END

   -----Wave Validation-----                    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      IF NOT EXISTS (SELECT 1 FROM #TMP_REPLEN)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 81005 
   
         IF EXISTS(SELECT 1 FROM REPLENISHMENT (NOLOCK) WHERE ReplenishmentGroup = @c_Loadkey AND OriginalFromLoc = 'ispRLBLP06')
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLBLP06)'           
         ELSE           
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLBLP06)'           
      END      
   END
    
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      --Get all qty of the sku, loc, id to replen
      DECLARE CUR_PICKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, LLI.Qty, t.ToLoc, SKU.Packkey
           , PACK.PackUOM3, t.PickUOM, PACK.CaseCnt, t.QtyAllocated
           , (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen)
      FROM LOTXLOCXID LLI (NOLOCK)
      JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      JOIN #TMP_REPLEN t ON LLI.Storerkey = t.Storerkey AND LLI.Sku = t.Sku AND LLI.Loc = t.Loc AND LLI.Id = t.Id
                        AND LLI.LOT = t.Lot
      WHERE LLI.QtyAllocated > 0
      ORDER BY LLI.Sku, LLI.Loc                    
       
      OPEN CUR_PICKDET

      FETCH NEXT FROM CUR_PICKDET INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_ToLoc
                                     , @c_Packkey, @c_UOM, @c_PickUOM, @n_CaseCnt, @n_QtyAllocated, @n_QtyAvailable
       
      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)
      BEGIN         
         SELECT @n_TotalCarton = CEILING(CAST(@n_QtyAllocated AS float)/CAST(@n_CaseCnt AS float))

         SELECT @n_ReplenQty = (@n_TotalCarton * @n_CaseCnt) - @n_QtyAllocated

         IF @n_ReplenQty <= 0 OR @n_QtyAvailable = 0
            GOTO NEXT

         IF @n_QtyAvailable < @n_ReplenQty
            SET @n_ReplenQty = @n_QtyAvailable

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

         INSERT INTO REPLENISHMENT (ReplenishmentKey,      ReplenishmentGroup,
                         StorerKey,      SKU,              FromLOC,         ToLOC,
                         Lot,            Id,               Qty,             UOM,
                         PackKey,        Priority,         QtyMoved,        QtyInPickLOC,
                         RefNo,          Confirmed,        ReplenNo,        Wavekey,
                         Remark,         OriginalQty,      OriginalFromLoc, ToID,
                         QtyReplen,      PendingMoveIN)
         VALUES (                                          
                         @c_ReplenishmentKey,              @c_Loadkey,
                         @c_StorerKey,   @c_Sku,           @c_FromLoc,      @c_ToLoc,
                         @c_Lot,         @c_Id,            @n_ReplenQty,    'EA',--@c_UOM,
                         @c_Packkey,     '99999',          0,               0,
                         '',             'N',              '',              '',
                         '',             @n_QtyAllocated,  'ispRLBLP06',    '',
                         @n_ReplenQty,   @n_ReplenQty
                )
          
         SET @n_err = @@ERROR
          
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81010     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLBLP06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END      
NEXT:
         FETCH NEXT FROM CUR_PICKDET INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_ToLoc
                                        , @c_Packkey, @c_UOM, @c_PickUOM, @n_CaseCnt, @n_QtyAllocated, @n_QtyAvailable                
      END                     
      CLOSE CUR_PICKDET
      DEALLOCATE CUR_PICKDET
   END
                   
    -----Update LoadPlan Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE LoadPlan 
      SET Status = '3'   
       ,  TrafficCop = NULL               
       ,  EditWho = SUSER_SNAME()      
       ,  EditDate= GETDATE()           
      WHERE Loadkey = @c_Loadkey

      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on Load Failed (ispRLBLP06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  
   
RETURN_SP:
    
   IF OBJECT_ID('tempdb..#TMP_REPLEN') IS NOT NULL
      DROP TABLE #TMP_REPLEN

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
      execute nsp_logerror @n_err, @c_errmsg, "ispRLBLP06"  
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