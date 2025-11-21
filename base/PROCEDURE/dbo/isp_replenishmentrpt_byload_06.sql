SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/  
/* Stored Procedure: isp_ReplenishmentRpt_ByLoad_06                         */  
/* Creation Date: 13-AUG-2020                                               */  
/* Copyright: LFL                                                           */  
/* Written by:                                                              */  
/*                                                                          */  
/* Purpose: WMS-14662 - Korea Allbirds Replenishment by load                */
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
/****************************************************************************/   

CREATE PROCEDURE [dbo].[isp_ReplenishmentRpt_ByLoad_06]      
  @c_Storerkey    NVARCHAR(10)
 ,@c_FromLoadkey  NVARCHAR(10)  
 ,@c_ToLoadkey    NVARCHAR(10)
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
        
    DECLARE @n_continue INT,
            @b_success  INT,
            @n_err      INT,
            @c_errmsg   NVARCHAR(255)                   
            
    SELECT  @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''

    DECLARE  @c_Sku                NVARCHAR(20)
            ,@c_SourceType         NVARCHAR(30)
            ,@c_Lot                NVARCHAR(10)
            ,@c_FromLoc            NVARCHAR(10)
            ,@c_ToLoc              NVARCHAR(10)
            ,@c_ID                 NVARCHAR(18)
            ,@c_ToID               NVARCHAR(18)
            ,@n_CaseCnt            INT
            ,@c_Packkey            NVARCHAR(10) 
            ,@c_UOM                NVARCHAR(10)
            ,@n_Qty                INT 
            ,@c_ReplenishmentKey   NVARCHAR(10)    
            ,@c_ReplenishmentGroup NVARCHAR(10)
            ,@n_ReplenQty          INT
            ,@n_ReplenQtyFinal     INT
            ,@n_QtyAvailable       INT
            ,@n_QtyShort           INT 
            ,@n_LoadQtyAllocated   INT
            ,@c_ReplenNo           NVARCHAR(10)                          
            ,@c_Remark             NVARCHAR(255)
            ,@c_Loadkey            NVARCHAR(10)
    
    SET @c_SourceType = 'RepRptByLP'    
    SET @c_Remark = 'Load# ' + @c_FromLoadkey + ' To ' + @c_ToLoadkey
    
    IF (@n_continue = 1 OR @n_continue = 2)
    BEGIN   
       IF EXISTS(SELECT 1 
                 FROM REPLENISHMENT REP (NOLOCK) 
                 WHERE REP.Remark <> @c_Remark
                 AND REP.Storerkey = @c_Storerkey
                 AND REP.confirmed = 'N'
                 AND REP.OriginalFromLoc = @c_SourceType)
       BEGIN
       	 SET @n_continue = 3
       	 SET @n_err = 83200
       	 SET @c_Errmsg = 'Reject, Other replen not complete'
       END
    END         

    IF (@n_continue = 1 OR @n_continue = 2)
    BEGIN   
       SELECT DISTINCT REP.Loadkey
       INTO #TMP_EXCLLOAD
       FROM REPLENISHMENT REP (NOLOCK) 
       WHERE REP.Loadkey BETWEEN @c_FromLoadkey AND @c_ToLoadkey
       AND REP.Storerkey = @c_Storerkey
       AND REP.confirmed = 'Y'
       AND REP.OriginalFromLoc = @c_SourceType    	 
       
       /*
       IF EXISTS(SELECT 1 
                 FROM REPLENISHMENT REP (NOLOCK) 
                 WHERE REP.Loadkey BETWEEN @c_FromLoadkey AND @c_ToLoadkey
                 AND REP.Storerkey = @c_Storerkey
                 AND REP.confirmed = 'Y'
                 AND REP.OriginalFromLoc = @c_SourceType)
       BEGIN
       	 SET @n_continue = 3
       	 SET @n_err = 83210
       	 SET @c_Errmsg = 'Reject, Some Load in the range already replen'
       END
       */
    END      
    
    IF (@n_continue = 1 OR @n_continue = 2)
    BEGIN
       IF EXISTS(SELECT 1 
                 FROM REPLENISHMENT REP (NOLOCK) 
                 WHERE REP.Remark = @c_Remark
                 AND REP.Storerkey = @c_Storerkey
                 AND REP.confirmed = 'N'
                 AND REP.OriginalFromLoc = @c_SourceType)
       BEGIN
       	 SET @n_continue = 4 --Reprint
       END
    END
    
    IF (@n_continue = 1 OR @n_continue = 2)   
    BEGIN    	     	 
       EXECUTE nspg_getkey
              'ReplenNo'
              , 10
              , @c_ReplenNo OUTPUT
              , @b_success OUTPUT
              , @n_err OUTPUT
              , @c_errmsg OUTPUT
    
    	 --Retrieve all lot of the load from pick loc
	     SELECT PD.Lot, PD.Loc, L.QtyExpected, SUM(PD.Qty) AS LoadQtyAllocated     	  
       INTO #TMP_LOADPICKLOT
       FROM PICKDETAIL PD (NOLOCK)
       JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
       JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
       JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
       CROSS APPLY (SELECT QtyExpected FROM LOTXLOCXID LLI (NOLOCK) WHERE LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.ID = PD.ID) L
       WHERE LPD.Loadkey BETWEEN @c_FromLoadkey AND @c_ToLoadkey
       AND PD.Storerkey = @c_Storerkey
       AND SXL.LocationType IN('PICK','CASE')
       AND PD.Status = '0'
       AND LPD.Loadkey NOT IN (SELECT Loadkey FROM #TMP_EXCLLOAD) 
  	   GROUP BY PD.Lot, PD.Loc, L.QtyExpected

    	 /*
       SELECT LLI.Lot, LLI.Loc, SUM(LLI.QtyExpected) AS QtyExpected, SUM(PD.Qty) AS LoadQtyAllocated             
       INTO #TMP_LOADPICKLOT
       FROM PICKDETAIL PD (NOLOCK)
       JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
       JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
       JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
       JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
       WHERE LPD.Loadkey BETWEEN @c_FromLoadkey AND @c_ToLoadkey
       AND PD.Storerkey = @c_Storerkey
       AND SXL.LocationType IN('PICK','CASE')
       AND PD.Status = '0'
       AND LPD.Loadkey NOT IN (SELECT Loadkey FROM #TMP_EXCLLOAD) 
       GROUP BY LLI.Lot, LLI.Loc    	
       */ 
                       
    	 --Retreive pick loc with overallocated by the load
       DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty,              
                 PACK.CaseCnt, PACK.Packkey, PACK.PACKUOM3, #TMP_LOADPICKLOT.LoadQtyAllocated
          FROM LOTXLOCXID LLI (NOLOCK)          
          JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
          JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
          JOIN #TMP_LOADPICKLOT ON LLI.Lot = #TMP_LOADPICKLOT.Lot AND LLI.Loc = #TMP_LOADPICKLOT.Loc AND #TMP_LOADPICKLOT.QtyExpected > 0  --only overallocted lot
          WHERE SL.LocationType IN('PICK','CASE')
          AND LLI.Storerkey = @c_Storerkey
          GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, PACK.CaseCnt, PACK.Packkey, PACK.PACKUOM3, #TMP_LOADPICKLOT.LoadQtyAllocated

       OPEN cur_PickLoc
       
       FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt, @c_Packkey, @c_UOM, @n_LoadQtyAllocated
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN       	  
       	  IF @n_QtyShort < 0
       	     SET @n_QtyShort = @n_QtyShort * -1
       	     
       	  SET @n_ReplenQty = @n_QtyShort          	     
       	  
       	  IF @n_LoadQtyAllocated < @n_ReplenQty
       	     SET @n_ReplenQty = @n_LoadQtyAllocated  --exclude over allocated qty from other load not in current replen
       	  
       	  --if multiple load, use the first loadkey of same LLI for replen record    
       	  SET @c_Loadkey = ''
       	  SELECT TOP 1 @c_Loadkey = LPD.Loadkey
       	  FROM LOADPLANDETAIL LPD (NOLOCK)
       	  JOIN PICKDETAIL PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey
       	  WHERE LPD.Loadkey BETWEEN @c_FromLoadkey AND @c_ToLoadkey
       	  AND PD.Storerkey = @c_Storerkey
       	  AND PD.Lot = @c_Lot
       	  AND PD.Loc = @c_ToLoc
       	  AND PD.Id = @c_ToID
       	  AND PD.Status = '0'
          AND LPD.Loadkey NOT IN (SELECT Loadkey FROM #TMP_EXCLLOAD)        	  
       	  ORDER BY LPD.Loadkey
       	         	         	     
          SET @c_replenishmentGroup = @c_Loadkey       	     
         
       	  --retrieve stock from bulk 
          DECLARE cur_Bulk CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
             SELECT LLI.Lot, LLI.Loc, LLI.Id, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) AS QtyAvailable
             FROM LOTXLOCXID LLI (NOLOCK)          
             JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
             JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
             JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
             JOIN ID (NOLOCK) ON LLI.Id = ID.Id
             WHERE SL.LocationType NOT IN('PICK','CASE')
             AND LOT.STATUS = 'OK' 
             AND LOC.STATUS = 'OK' 
             AND ID.STATUS = 'OK'  
             AND LOC.LocationFlag = 'NONE' 
             AND LOC.LocationType = 'OTHER' 
             AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
             AND LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
             AND LLI.Lot = @c_Lot         
             ORDER BY LOC.Logicallocation, LOC.Loc
             
          OPEN cur_Bulk
          
          FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable
          
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_ReplenQty > 0          	 
          BEGIN          
          	 SELECT @c_Replenishmentkey= ''
          	 
             IF @n_QtyAvailable >= @n_ReplenQty       
             BEGIN  
                SET @n_ReplenQtyFinal = CEILING(@n_ReplenQty / (@n_CaseCnt * 1.00)) * @n_CaseCnt  --Try to replenish full case
                
                IF @n_ReplenQtyFinal > @n_QtyAvailable  --remove the loose case
                   SET @n_ReplenQtyFinal = FLOOR(@n_ReplenQty / (@n_CaseCnt * 1.00)) * @n_CaseCnt 
             END
             ELSE
                SET @n_ReplenQtyFinal = FLOOR(@n_QtyAvailable / (@n_CaseCnt * 1.00)) * @n_CaseCnt 
                    	     	 	         	  	 	     
       	  	 	SET @n_ReplenQty = @n_ReplenQty - @n_ReplenQtyFinal
       	  	 	
       	  	 IF @n_ReplenQtyFinal > 0 
       	  	 BEGIN       	  	 	
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
                      Replenishmentgroup, ReplenishmentKey, StorerKey,
                      Sku,                FromLoc,          ToLoc,
                      Lot,                Id,               Qty,
                      UOM,                PackKey,          Confirmed, 
                      MoveRefKey,         ToID,             PendingMoveIn, 
                      QtyReplen,          QtyInPickLoc,     RefNo, 
                      Loadkey,						Remark,						ReplenNo,
                      OriginalQty,				OriginalFromLoc)
                VALUES (@c_ReplenishmentGroup, @c_ReplenishmentKey, @c_StorerKey, 
                         @c_SKU,                 @c_FromLOC,          @c_ToLOC, 
                         @c_LOT,           		  @c_ID,               @n_ReplenQtyFinal, 
                         @c_UOM,                 @c_PackKey,          'N', 
                         '',     						    @c_ToID,             @n_ReplenQtyFinal, 
                         @n_ReplenQtyFinal,      0, 							     '',
                         @c_Loadkey,		          @c_Remark,				   @c_ReplenNo, 
                         0,										  @c_SourceType)  
                
                IF @@ERROR <> 0
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83220     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (isp_ReplenishmentRpt_ByLoad_06)' 
                END         
             END                       
             
             NEXT_STOCK:
                                                                                    
             FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable
          END
          CLOSE cur_Bulk
          DEALLOCATE cur_Bulk
          
          FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt, @c_Packkey, @c_UOM, @n_LoadQtyAllocated
       END
       CLOSE cur_PickLoc
       DEALLOCATE cur_PickLoc          
    END                            
    
    IF @n_continue = 3
    BEGIN 
       SELECT '', @c_Errmsg, '', '', 0, '', ''
       execute nsp_logerror @n_err, @c_errmsg, "isp_ReplenishmentRpt_ByLoad_06"  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
    END
    ELSE
    BEGIN    
       SELECT REP.SKU, LEFT(SKU.Descr, 40) AS Descr, 
              REP.FromLoc, REP.ToLoc, REP.Qty, LEFT(SKU.Notes1,50), REP.ReplenishmentGroup
       FROM REPLENISHMENT REP (NOLOCK)
       JOIN SKU (NOLOCK) ON REP.Storerkey = SKU.Storerkey AND REP.Sku = SKU.Sku
       JOIN LOC (NOLOCK) ON REP.FromLoc = LOC.Loc
       WHERE REP.Loadkey BETWEEN @c_FromLoadkey AND @c_ToLoadkey
       AND REP.Storerkey = @c_Storerkey
       AND REP.OriginalFromLoc = @c_SourceType
       AND REP.Loadkey NOT IN (SELECT Loadkey FROM #TMP_EXCLLOAD)        
       ORDER BY LOC.LogicalLocation, LOC.Loc, REP.Sku, REP.Replenishmentkey
    END       
 END --sp end

GO