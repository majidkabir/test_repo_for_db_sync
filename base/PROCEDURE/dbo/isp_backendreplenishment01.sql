SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_BackEndReplenishment01                         */
/* Creation Date: 10-Nov-2017                                           */
/* Copyright: LFL                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: WMS-3178 PH-Backend Create Replenishment Task               */       
/*      All parameters are optional. Should execute by parameter        */
/*          name.                                                       */
/* e.g EXEC isp_BackEndReplenishment01 @c_Storerkey='LFL'               */
/*                                                                      */
/*                                                                      */
/* Called By: SQL Job                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/
CREATE PROC [dbo].[isp_BackEndReplenishment01]  
    @c_Storerkey                NVARCHAR(15) = ''    --if empty storerkey replenish for all storer
   ,@c_Facility                 NVARCHAR(5) = ''     --if empty facility replenish for all facilities
   ,@c_PutawayZones             NVARCHAR(1000) = ''  --putawayzone list to filter delimited by comma e.g. Zone1, Zone3, Bulkarea, Pickarea
   ,@c_SQLCondition             NVARCHAR(3000) = ''  --additional condition to filter the pick/dynamic loc. e.g. LOC.locationhandling = '1' AND SKUXLOC.Locationtype = 'PICK'
   ,@c_CaseLocRoundUpQty        NVARCHAR(10) = 'FC'  --case pick loc round up qty replen from bulk. FC=Round up to full case  FP=Round up to full pallet  FL=Round up to full location qty
   ,@c_PickLocRoundUpQty        NVARCHAR(10) = 'FC'  --pick/dynamic loc round up qty replen from bulk. FC=Round up to full case  FP=Round up to full pallet  FL=Round up to full location qty
   ,@c_CaseLocReplenPickCode    NVARCHAR(10) = ''    --custom replen pickcode for case loc lot sorting. the sp name must start from 'nspRP'. Put 'NOPICKCODE' to use standard lot sorting. put empty to use pickcode from sku table.
   ,@c_PickLocReplenPickCode    NVARCHAR(10) = ''    --custom replen pickcode for pick/dynamic loc lot sorting. the sp name must start from 'nspRP'. Put 'NOPICKCODE' to use standard lot sorting. put empty to use pickcode from sku table.
   ,@c_QtyReplenFormula         NVARCHAR(2000) = ''  --custom formula to calculate the qty to replenish. e.g. (@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) - @n_PendingMoveIn 
                                                     --the formula is a stadard sql statement and can apply below variables to calculate. the above example is the default.                                                    
                                                     --@n_Qty, @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit, @n_CaseCnt, @n_Pallet, n_QtyExpected, @n_PendingMoveIn, @c_LocationType, @c_LocLocationType
                                                     --it can pass in preset formula code. QtyExpectedFitLocLimit=try fit the overallocaton qty to location limit. usually apply when @c_BalanceExclQtyAllocated = 'Y' and do not want to replen overallocate qty exceed limit
   ,@c_Priority                 NVARCHAR(10) = ''    --task priority default is ?STOCK ?LOC=get the priority from skuxloc.ReplenishmentPriority  ?STOCK=calculate priority by on hand stock level against limit. if empty default is 5.
   ,@c_SplitTaskByCarton        NVARCHAR(5)  = 'N'   --Y=Slplit the task by carton. Casecnt must set and not applicable if roundupqty is FP,FL. 
   ,@c_OverAllocateOnly         NVARCHAR(5)  = 'N'   --Y=Only replenish pick/dynamic loc with overallocated qty  N=replen loc with overallocated qty and below minimum qty.
                                                     --Dynamic loc only replenish when overallocated.
   ,@c_BalanceExclQtyAllocated  NVARCHAR(5)  = 'N'   --Y=the qtyallocated is deducted when calculate loc balance. N=the qtyallocated is not deducated.
   ,@c_TaskType                 NVARCHAR(10) = 'RPF' 
AS   
BEGIN      
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE  @n_Continue    INT,      
            @n_StartTCnt   INT,
            @b_Success     INT, 
            @n_Err         INT,
            @c_ErrMsg      NVARCHAR(250)      
                            
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''    
                                                                                  
   IF ISNULL(@c_Priority,'') = ''
      SET @c_Priority = '?STOCK'
                                               
   EXEC isp_CreateReplenishTask
        @c_Storerkey               = @c_Storerkey                           
       ,@c_Facility                = @c_Facility                            
       ,@c_PutawayZones            = @c_PutawayZones                        
       ,@c_SQLCondition            = @c_SQLCondition                        
       ,@c_CaseLocRoundUpQty       = @c_CaseLocRoundUpQty                   
       ,@c_PickLocRoundUpQty       = @c_PickLocRoundUpQty                   
       ,@c_CaseLocReplenPickCode   = @c_CaseLocReplenPickCode               
       ,@c_PickLocReplenPickCode   = @c_PickLocReplenPickCode               
       ,@c_QtyReplenFormula        = @c_QtyReplenFormula                                                                                                                                
       ,@c_Priority                = @c_Priority                            
       ,@c_SplitTaskByCarton       = @c_SplitTaskByCarton                   
       ,@c_OverAllocateOnly        = @c_OverAllocateOnly                                                       
       ,@c_BalanceExclQtyAllocated = @c_BalanceExclQtyAllocated             
       ,@c_TaskType                = @c_TaskType         
       ,@c_SourceType              = 'isp_BackEndReplenishment01'                          
       ,@b_Success                 = @b_Success OUTPUT                             
       ,@n_Err                     = @n_Err     OUTPUT                            
       ,@c_ErrMsg                  = @c_ErrMsg  OUTPUT                         

    IF @b_Success  <> 1
    BEGIN
       SET @n_continue = 3
    END                                                                              
           
EXIT_SP:  
      
   IF @n_Continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_Success = 0      
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartTCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_BackEndReplenishment01'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR          
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END           
END -- Procedure    

GO