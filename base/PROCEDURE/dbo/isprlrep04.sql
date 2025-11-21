SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: ispRLREP04                                         */      
/* Creation Date: 13/05/2020                                            */      
/* Copyright: LFL                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: WMS-13197 CN Sephora replenishment task(RPF) from           */
/*          replenishment screen by UCC                                 */      
/*          RDT must enable with QtyReplen and PendingMoveIn control    */
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* Version: 7.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/************************************************************************/      
CREATE PROC [dbo].[ispRLREP04]     
   @c_Facility NVARCHAR(10)='',
   @c_zone02 NVARCHAR(10)='',
   @c_zone03 NVARCHAR(10)='',
   @c_zone04 NVARCHAR(10)='',
   @c_zone05 NVARCHAR(10)='',
   @c_zone06 NVARCHAR(10)='',
   @c_zone07 NVARCHAR(10)='',
   @c_zone08 NVARCHAR(10)='',
   @c_zone09 NVARCHAR(10)='',
   @c_zone10 NVARCHAR(10)='',
   @c_zone11 NVARCHAR(10)='',
   @c_zone12 NVARCHAR(10)='',
   @c_Storerkey NVARCHAR(15)='',
   @n_err       INT OUTPUT,    
   @c_ErrMsg    NVARCHAR(250) OUTPUT    
AS      
BEGIN  
    SET NOCOUNT ON       
    SET ANSI_NULLS OFF       
    SET QUOTED_IDENTIFIER OFF       
    SET CONCAT_NULL_YIELDS_NULL OFF      
      
    DECLARE @n_continue               INT  
           ,@n_starttcnt              INT
           ,@b_Success                INT  
           ,@c_SKU                    NVARCHAR(20)             
           ,@c_ToLoc                  NVARCHAR(10)
           ,@c_Lot                    NVARCHAR(10)
           ,@c_FromLoc                NVARCHAR(10)
           ,@c_ID                     NVARCHAR(18)
           ,@c_ToID                   NVARCHAR(18)
           ,@n_Qty                    INT
           ,@c_Replenishmentkey       NVARCHAR(10) 
           ,@c_ReplenishmentGroup     NVARCHAR(10)
           ,@c_PrevReplenishmentGroup NVARCHAR(10)
           ,@c_ReplenGroupList        NVARCHAR(250)
           ,@c_UOM                    NVARCHAR(10)
           ,@c_Priority               NVARCHAR(10)
           ,@c_UCCNo                  NVARCHAR(20)
           ,@n_UCCQty                 INT
           ,@n_RemainQty              INT
           ,@c_InductionLoc           NVARCHAR(10)
           ,@c_LocationCategory       NVARCHAR(10)
           ,@c_LocationHandling       NVARCHAR(10)
           ,@c_PickMethod             NVARCHAR(10)

    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''     
    SELECT @c_PrevReplenishmentGroup = '', @c_ReplenGroupList = ''
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF NOT EXISTS (SELECT 1
                      From  REPLENISHMENT R (NOLOCK)   
                      JOIN  LOC (NOLOCK) ON (LOC.Loc = R.ToLoc)  
                      WHERE (LOC.putawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)
                             OR @c_Zone02 = 'ALL'
                            )
                      AND (LOC.Facility = @c_Facility OR ISNULL(@c_Facility,'') = '') 
                      AND R.Confirmed = 'N'  
                      AND R.StorerKey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                   R.StorerKey ELSE @c_StorerKey END)
        BEGIN
           SELECT @n_continue = 3  
           SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 71000  
           SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': No replenishment to release.' + ' ( '+  
                              ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '  
        END                                           	
    END
                    
   -----Create replenishment task
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       BEGIN TRAN    
    	 
       DECLARE CUR_REPLENISH CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT R.StorerKey, R.Sku, R.FromLoc, R.Id, R.ToLoc, R.ToID, R.UOM, R.Qty, R.Lot,
                 R.ReplenishmentKey, ISNULL(R.ReplenishmentGroup,''), R.Priority,
                 FLOC.LocationCategory, FLOC.LocationHandling
          From  REPLENISHMENT R (NOLOCK)   
          JOIN  LOC (NOLOCK) ON (LOC.Loc = R.ToLoc)  
          JOIN  LOC FLOC (NOLOCK) ON (R.FromLoc = FLOC.Loc)
          WHERE (LOC.putawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)
                 OR @c_Zone02 = 'ALL'
                )
          AND (LOC.Facility = @c_Facility OR ISNULL(@c_Facility,'') = '') 
          AND R.Confirmed = 'N'  
          AND R.StorerKey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                   R.StorerKey ELSE @c_StorerKey END              
          ORDER BY R.ReplenishmentGroup, R.Replenishmentkey

       OPEN CUR_REPLENISH
       
       FETCH FROM CUR_REPLENISH INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ID, @c_ToLoc, @c_ToID, @c_UOM, @n_Qty, @c_Lot, @c_Replenishmentkey, @c_ReplenishmentGroup, @c_Priority,
                                     @c_LocationCategory, @c_LocationHandling
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN       	      
       	  IF (@c_ReplenishmentGroup <> @c_PrevReplenishmentGroup) AND ISNULL(@c_ReplenishmentGroup,'') <> ''
       	  BEGIN 
       	  	 SET @c_ReplenGroupList = RTRIM(@c_ReplenGroupList) + RTRIM(@c_ReplenishmentGroup) +','
       	  END
       	  
       	  IF ISNULL(@c_ToId,'') = ''
       	     SET @c_ToID = @c_ID

       	  IF ISNULL(@c_Priority,'') = ''
       	     SET @c_Priority = '9'
       	     
       	  IF @c_LocationCategory = 'BULK' AND @c_LocationHandling = '2'       	   
       	     SET @c_PickMethod = 'PP'
       	  ELSE
       	     SET @c_PickMethod = '?TASKQTY'     
       	     
       	  SELECT TOP 1 @c_InductionLoc = PZ.InLoc
       	  FROM LOC (NOLOCK)
       	  JOIN PUTAWAYZONE PZ (NOLOCK) ON LOC.Putawayzone = PZ.Putawayzone
       	  WHERE LOC.Loc = @c_ToLoc 
       	
       	  DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       	    SELECT UCC.UCCNo, UCC.Qty
       	    FROM LOTXLOCXID LLI (NOLOCK)
       	    JOIN UCC (NOLOCK) ON LLI.Storerkey = UCC.Storerkey AND LLI.Sku = UCC.Sku AND LLI.Lot = UCC.Lot 
       	                         AND UCC.Loc = LLI.Loc AND LLI.ID = UCC.ID AND UCC.Status < 3
       	    WHERE LLI.Storerkey = @c_Storerkey
       	    AND LLI.Sku = @c_Sku
       	    AND LLI.Lot = @c_Lot
       	    AND LLI.Loc = @c_FromLoc
       	    AND LLI.ID = @c_ID
       	    AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0
       	    AND UCC.Qty > 0
       	    ORDER BY UCC.Qty                     

          OPEN CUR_UCC
       
          FETCH FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty
       
          SET @n_RemainQty = @n_Qty   
          
          WHILE @@FETCH_STATUS = 0 AND @n_RemainQty > 0 AND @n_continue IN(1,2)
          BEGIN       	             	
          	 IF @n_RemainQty < @n_UCCQty
          	    GOTO NEXT_UCC
          	    
             EXEC isp_InsertTaskDetail   
                 @c_TaskType              = 'RPF'             
                ,@c_Storerkey             = @c_Storerkey
                ,@c_Sku                   = @c_Sku
                ,@c_Lot                   = @c_Lot 
                ,@c_UOM                   = '2' --@c_UOM      
                ,@n_UOMQty                = @n_UCCQty   
                ,@n_Qty                   = @n_UCCQty      
                ,@c_FromLoc               = @c_Fromloc      
                ,@c_FromID                = @c_ID     
                ,@c_ToLoc                 = @c_InductionLoc       
                ,@c_ToID                  = @c_ToID       
                ,@c_CaseID                = @c_UCCNo
                ,@c_PickMethod            = @c_PickMethod --'?TASKQTY' --?TASKQTY=(Qty available - taskqty) 
                ,@c_Priority              = @c_Priority     
                ,@c_SourcePriority        = '9'      
                ,@c_SourceType            = 'ispRLREP04'     
                ,@c_SourceKey             = @c_Replenishmentkey      
                ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                ,@c_Groupkey              = @c_ReplenishmentGroup
                ,@c_CallSource            = 'REPLENISHMENT'
                ,@n_QtyReplen             = @n_UCCQty
                ,@n_PendingMoveIn         = @n_UCCQty
                ,@c_LinkTaskToReplen      = 'Y'
                ,@c_ZeroSystemQty         = 'Y'
                ,@c_FinalLOC              = @c_ToLoc
                ,@b_Success               = @b_Success OUTPUT
                ,@n_Err                   = @n_err OUTPUT 
                ,@c_ErrMsg                = @c_errmsg OUTPUT       	
             
             IF @b_Success <> 1 
             BEGIN
                SELECT @n_continue = 3  
             END
             
             UPDATE UCC WITH (ROWLOCK)
             SET Status = '3'
             WHERE UCCNo = @c_UccNo
             AND Storerkey = @c_Storerkey
             AND Sku = @c_Sku             

             SELECT @n_err = @@ERROR
             IF @n_err <> 0 
             BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 71010   
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispRLREP04)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             END
             
             SET @n_RemainQty = @n_RemainQty - @n_UCCQty
             
             NEXT_UCC:
             
             FETCH FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty             
          END
          CLOSE CUR_UCC
          DEALLOCATE CUR_UCC
          
          SET @c_PrevReplenishmentGroup = @c_ReplenishmentGroup
       	
          FETCH FROM CUR_REPLENISH INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ID, @c_ToLoc, @c_ToID, @c_UOM, @n_Qty, @c_Lot, @c_Replenishmentkey, @c_ReplenishmentGroup, @c_Priority,
                                        @c_LocationCategory, @c_LocationHandling          
       END
       CLOSE CUR_REPLENISH
       DEALLOCATE CUR_REPLENISH       
       
       IF @n_continue IN(1,2) AND @c_ReplenGroupList <> ''
       BEGIN
       	  SELECT @c_ReplenGroupList = LEFT(@c_ReplenGroupList, LEN(@c_ReplenGroupList) - 1)
       	  SELECT @c_ErrMsg = 'Release Replenishment Task Completed. Groupkey: ' + @c_ReplenGroupList
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLREP04"  
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
END   

GO