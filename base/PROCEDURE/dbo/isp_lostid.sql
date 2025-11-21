SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* S Proc: isp_LostID                                                   */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Input Parameters:                                                    */    
/*                                                                      */    
/* Output Parameters:                                                   */    
/*                                                                      */    
/* Return Status:                                                       */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: Backend Scheduler Job                                     */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/* 15Feb2012    TLTING        Performance Tune                          */    
/* 02-01-2014   SHONG         Added 2 new parameters                    */    
/* 02-01-2014   SHONG         Added 2 new parameters                    */ 
/* 26-04-2015   TLTING01      Add Lottable06-15                         */    
/************************************************************************/     
CREATE PROC [dbo].[isp_LostID] (  
   @b_success int OUTPUT,   
   @c_StorerKey NVARCHAR(15) = '',  
   @c_Facility  NVARCHAR(5) = '')    
AS    
BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
    DECLARE @c_sku       NVARCHAR(20)  
           ,@c_FromID    NVARCHAR(18)  
           ,@c_TOID      NVARCHAR(18)  
           ,@c_FromLoc   NVARCHAR(10)  
           ,@c_ToLoc     NVARCHAR(10)  
           ,@n_Qty       INT  
           ,@d_Today     DATETIME  
           ,@c_PackKey   NVARCHAR(10)  
           ,@c_UOM       NVARCHAR(10)  
           ,@c_TempLoc   NVARCHAR(10)  
           ,@c_TempSKU   NVARCHAR(20)  
           ,@n_Continue  INT  
           ,@c_LOT       NVARCHAR(10)  
           ,@c_ErrMsg    NVARCHAR(255)  
           ,@n_Err       INT                     
    
   SELECT @d_Today = GetDate(), @n_Continue = 1    
    
   WHILE @@TranCount > 0    
      COMMIT TRAN     
          
   DECLARE INV_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.SKU, LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.LOC,     
          LOTxLOCxID.ID, '' as ToID, (LOTxLOCxID.Qty - (LOTxLOCxID.QtyPicked + LOTxLOCxID.QtyAllocated)) as MoveQty    
   FROM LOTxLOCxID (NOLOCK)    
   JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)     
   WHERE LOC.LoseID = '1'    
   AND   (RTRIM(LOTxLOCxID.ID) IS NOT NULL AND RTRIM(LOTxLOCxID.ID) <> '')    
   AND   (LOTxLOCxID.Qty - (LOTxLOCxID.QtyPicked + LOTxLOCxID.QtyAllocated)) > 0  
   AND   LOTxLOCxID.StorerKey = CASE WHEN ISNULL(RTRIM(@c_StorerKey),'') <> '' THEN @c_StorerKey ELSE LOTxLOCxID.StorerKey END      
   AND   LOC.Facility = CASE WHEN ISNULL(RTRIM(@c_Facility),'') <> '' THEN @c_Facility ELSE LOC.Facility END  
   AND   ( SELECT ((SKUxLOC.Qty + SKUxLOC.QtyExpected) - (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked)) -     
           (LOTxLOCxID.Qty - (LOTxLOCxID.QtyPicked + LOTxLOCxID.QtyAllocated))    
           FROM SKUxLOC (NOLOCK)    
           WHERE SKUxLOC.StorerKey = LOTxLOCxID.StorerKey    
           AND   SKUxLOC.SKU = LOTxLOCxID.SKU    
           AND   SKUxLOC.LOC = LOTxLOCxID.LOC ) >= 0     
  -- ORDER BY LOTxLOCxID.LOC, LOTxLOCxID.LOT, LOTxLOCxID.ID     
       
        
   OPEN INV_CUR    
   FETCH NEXT FROM INV_CUR INTO @c_StorerKey, @c_SKU, @c_LOT, @c_FromLOC, @c_ToLOC, @c_FromID,     
   @c_ToID, @n_Qty    
     
   WHILE (@@FETCH_STATUS <> -1)    
    
   BEGIN    
      SELECT @c_StorerKey  
            ,@c_SKU  
            ,@c_LOT  
            ,@c_FromLOC  
            ,@c_ToLOC  
            ,@c_FromID  
            ,@c_ToID  
            ,@n_Qty     
          
      SELECT @n_Continue = 1     
      IF @c_FromID IS NULL  
          SELECT @c_FromID = ''  
          
      IF @c_TOID IS NULL  
          SELECT @c_ToID = ''    
          
      SELECT @c_PackKey = ''  
            ,@c_UOM = ''    
          
      SELECT @c_PackKey = SKU.packkey  
            ,@c_UOM = packuom3  
      FROM   SKU(NOLOCK)  
            ,PACK(NOLOCK)  
      WHERE  SKU.Packkey = PACK.Packkey  
      AND    SKU.STORERKEY = @C_STORERKEY  
      AND    SKU.SKU = @c_SKU    
          
      IF @c_PackKey = ''  
      OR @c_PackKey IS NULL  
      BEGIN  
          SELECT @n_Continue = 3  
      END     
           
      IF @n_Continue = 1  
      BEGIN  
          SELECT @c_TempSKU = ''    
            
          IF NOT EXISTS (  
                 SELECT SKU  
                 FROM   SKU(NOLOCK)  
                 WHERE  SKU.STORERKEY = @C_STORERKEY  
                 AND    SKU = @c_sku  
             )  
          BEGIN  
              SELECT @n_Continue = 3  
          END  
      END    
          
      IF @n_Continue = 1  
      BEGIN  
          IF NOT EXISTS(  
                 SELECT LOC  
                 FROM   LOC(NOLOCK)  
                 WHERE  Loc = @c_FromLoc  
             )  
          BEGIN  
              SELECT @n_Continue = 3  
          END  
            
          IF NOT EXISTS(  
                 SELECT LOC  
                 FROM   LOC(NOLOCK)  
                 WHERE  Loc = @c_ToLoc  
             )  
          BEGIN  
              SELECT @n_Continue = 3  
          END  
      END    
          
      IF @n_Continue <> 3  
      BEGIN  
          IF NOT EXISTS (  
                 SELECT Qty  
                 FROM   LOTxLOCxID(NOLOCK)  
                 WHERE  LOT = @c_LOT  
                 AND    LOC = @c_FromLOC  
                 AND    ID = @c_FromID  
                 AND    Qty -(QtyPicked + QtyAllocated) < @n_Qty  
             )  
          BEGIN  
              BEGIN TRAN    
              SELECT @b_success = 1    
    
              EXEC nspItrnAddMove NULL  
                  ,@c_StorerKey  
                  ,@c_Sku  
                  ,@c_Lot  
                  ,@c_FromLoc  
                  ,@c_FromID  
                  ,@c_ToLoc  
                  ,@c_ToID  
                  ,''  
                  ,''  
                  ,''  
                  ,''  
                  ,''  
                  ,''
                  ,''  
                  ,''  
                  ,''  
                  ,''  
                  ,''  
                  ,''  
                  ,''  
                  ,''  
                  ,''  
                  ,''  
                  ,0  
                  ,0  
                  ,@n_Qty  
                  ,0  
                  ,0  
                  ,0  
                  ,0  
                  ,0  
                  ,0  
                  ,''  
                  ,'isp_LostID'  
                  ,@c_PackKey  
                  ,@c_UOM  
                  ,1  
                  ,@d_Today  
                  ,''  
                  ,@b_Success OUTPUT  
                  ,@n_Err OUTPUT  
                  ,@c_ErrMsg OUTPUT     
    
            IF NOT @b_success = 1     
            BEGIN    
               SELECT @n_Continue = 3    
               ROLLBACK TRAN    
               BREAK    
            END    
            ELSE    
            BEGIN    
               COMMIT TRAN    
            END     
         END    
         ELSE    
         BEGIN    
            SELECT 'NOT ENOUGH STOCK TO Move'    
         END -- if overallocated    
      END -- continue = 1    
      FETCH NEXT FROM INV_CUR INTO @c_StorerKey, @c_SKU, @c_LOT, @c_FromLOC, @c_ToLOC, @c_FromID,     
                      @c_ToID, @n_Qty    
   END    
   CLOSE INV_CUR     
   DEALLOCATE INV_CUR    
END -- Procedure  


GO