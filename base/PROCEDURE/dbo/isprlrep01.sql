SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Stored Procedure: ispRLREP01                                            */      
/* Creation Date: 02/06/2017                                               */      
/* Copyright: LFL                                                          */      
/* Written by:                                                             */      
/*                                                                         */      
/* Purpose: WMS-1986 CN Dyson - Release replenishment task from            */
/*          replenishment screen                                           */      
/*                                                                         */      
/* Called By:                                                              */
/*                                                                         */
/* GitLab Version: 1.1                                                     */  
/*                                                                         */      
/* Version: 5.5                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author   Ver  Purposes                                     */     
/* 01-Jun-2020  WLChooi  1.1  WMS-13541 - Change ToLoc logic (WL01)        */
/***************************************************************************/      
CREATE PROC [dbo].[ispRLREP01]     
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
           ,@n_Qty                    INT
           ,@c_Replenishmentkey       NVARCHAR(10) 
           ,@c_ReplenishmentGroup     NVARCHAR(10)
           ,@c_PrevReplenishmentGroup NVARCHAR(10)
           ,@c_ReplenGroupList        NVARCHAR(250)
           ,@c_LocGroup               NVARCHAR(10)   --WL01
           ,@c_Message03              NVARCHAR(30)   --WL01

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
    	 
       DECLARE cur_Replen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT R.StorerKey, R.Sku, R.FromLoc, R.Id, R.ToLoc, R.Qty, R.Lot,
                 R.ReplenishmentKey, ISNULL(ReplenishmentGroup,''),
                 ISNULL(LOC.LocationGroup,'')   --WL01
          From  REPLENISHMENT R (NOLOCK)   
          JOIN  LOC (NOLOCK) ON (LOC.Loc = R.ToLoc)  
          WHERE (LOC.putawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)
                 OR @c_Zone02 = 'ALL'
                )
          AND (LOC.Facility = @c_Facility OR ISNULL(@c_Facility,'') = '') 
          AND R.Confirmed = 'N'  
          AND R.StorerKey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                   R.StorerKey ELSE @c_StorerKey END              
          ORDER BY R.ReplenishmentGroup, R.Replenishmentkey

       OPEN cur_Replen
       
       FETCH FROM cur_Replen INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ID, @c_ToLoc, @n_Qty, @c_Lot, @c_Replenishmentkey, @c_ReplenishmentGroup
                                , @c_LocGroup   --WL01
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN       	      
           IF @c_ReplenishmentGroup <> @c_PrevReplenishmentGroup
       	  BEGIN 
       	  	 SET @c_ReplenGroupList = RTRIM(@c_ReplenGroupList) + RTRIM(@c_ReplenishmentGroup) +','
       	  END

           --WL01 START
           SET @c_Message03 = @c_ToLoc

           IF @c_LocGroup = 'E'
           BEGIN
              SET @c_ToLoc = 'RYRP'
           END
           --WL01 END

          EXEC isp_InsertTaskDetail   
              @c_TaskType              = 'RPF'             
             ,@c_Storerkey             = @c_Storerkey
             ,@c_Sku                   = @c_Sku
             ,@c_Lot                   = @c_Lot 
             ,@c_UOM                   = '1'      
             ,@n_UOMQty                = 1      
             ,@n_Qty                   = @n_Qty      
             ,@c_FromLoc               = @c_Fromloc      
             ,@c_FromID                = @c_ID     
             ,@c_ToLoc                 = @c_ToLoc
             ,@c_ToID                  = @c_ID       
             ,@c_PickMethod            = 'FP'
             ,@c_Priority              = '9'     
             ,@c_SourcePriority        = '9'      
             ,@c_SourceType            = 'ispRLREP01'     
             ,@c_SourceKey             = @c_Replenishmentkey      
             ,@c_WaveKey               = ''
             ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
             ,@c_Groupkey              = @c_ReplenishmentGroup
             ,@c_CallSource            = 'REPLENISHMENT'
             ,@n_QtyReplen             = @n_Qty
             ,@n_PendingMoveIn         = @n_Qty
             ,@c_LinkTaskToReplen      = 'Y'
             ,@c_Message03             = @c_Message03   --WL01
             ,@b_Success               = @b_Success OUTPUT
             ,@n_Err                   = @n_err OUTPUT 
             ,@c_ErrMsg                = @c_errmsg OUTPUT       	
          
          IF @b_Success <> 1 
          BEGIN
             SELECT @n_continue = 3  
          END
          
          SET @c_PrevReplenishmentGroup = @c_ReplenishmentGroup
       	
          FETCH FROM cur_Replen INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ID, @c_ToLoc, @n_Qty, @c_Lot, @c_Replenishmentkey, @c_ReplenishmentGroup
                                   , @c_LocGroup   --WL01
       END
       CLOSE cur_Replen
       DEALLOCATE cur_Replen       
       
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLREP01"  
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