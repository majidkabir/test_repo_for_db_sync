SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
 /* Store Procedure:  isp_TCP_VC_prTaskLUTForkReplenishmentLicense       */  
 /* Creation Date: 26-Feb-2013                                           */  
 /* Copyright: IDS                                                       */  
 /* Written by: Shong                                                    */  
 /*                                                                      */  
 /* Purposes: The message returns the regions where the operator is      */  
 /*           allowed to perform the selection function.                 */  
 /*                                                                      */  
 /* Updates:                                                             */  
 /* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTForkReplenishmentLicense] (  
    @c_TranDate      NVARCHAR(20)  
   ,@c_DevSerialNo   NVARCHAR(20)  
   ,@c_OperatorID    NVARCHAR(20)  
   ,@c_TaskDetailKey NVARCHAR(10)  
   ,@n_QtyPut        INT  
   ,@c_ToLocation    NVARCHAR(10)  
   ,@c_ReplenStatus  NVARCHAR(1) -- 0 = partial replenish, 1 = complete replenish, 2 = canceled replenish  
   ,@c_ReasonCode    NVARCHAR(10)  
   ,@c_StartTime     NVARCHAR(20)  
   ,@n_SerialNo      INT  
   ,@c_RtnMessage    NVARCHAR(500) OUTPUT      
   ,@b_Success       INT = 1 OUTPUT  
   ,@n_Error         INT = 0 OUTPUT  
   ,@c_ErrMsg        NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                            -- 98: Critical error. If this error is received,   
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                            --     but does not force the operator to sign off.  
         , @c_Message            NVARCHAR(400)  
         , @c_RegionNo           NVARCHAR(5)  -- Operator+├┤+├º++s response to picking region prompt.           
         , @c_RegionName         NVARCHAR(100)  
         , @c_ReplenishmentKey   NVARCHAR(10)   
         , @c_SuggestLOC         NVARCHAR(10)   
         , @n_SuggestQty         INT   
         , @c_FromLoc            NVARCHAR(10)  
     
   DECLARE CUR_Replenishment CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT r.ReplenishmentKey,  
          r.ToLoc,   
          r.Qty,  
          r.FromLoc   
   FROM REPLENISHMENT r WITH (NOLOCK)  
   WHERE r.RefNo = @c_TaskDetailKey   
   AND   r.Confirmed = 'S'  
     
   OPEN CUR_Replenishment    
     
   FETCH NEXT FROM CUR_Replenishment INTO @c_ReplenishmentKey, @c_SuggestLOC, @n_SuggestQty, @c_FromLoc  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF  @c_ReplenStatus = '1'  
      BEGIN  
         UPDATE REPLENISHMENT   
            SET Confirmed = 'Y'  
         WHERE ReplenishmentKey = @c_ReplenishmentKey   
      END  
      ELSE IF @c_ReplenStatus = '2'         
      BEGIN  
         UPDATE REPLENISHMENT   
            SET Confirmed = 'X'  
         WHERE ReplenishmentKey = @c_ReplenishmentKey   
      END  
      ELSE IF @c_ReplenStatus = '0'  
      BEGIN  
         IF @n_QtyPut < @n_SuggestQty   
         BEGIN  
            UPDATE REPLENISHMENT   
               SET Confirmed = 'Y', Qty = @n_QtyPut, QtyMoved = @n_QtyPut   
            WHERE ReplenishmentKey = @c_ReplenishmentKey   
              
            BREAK   
         END  
         ELSE  
         BEGIN  
            UPDATE REPLENISHMENT   
               SET Confirmed = 'Y'  
            WHERE ReplenishmentKey = @c_ReplenishmentKey                        
         END  
           
         SET @n_QtyPut = @n_QtyPut - @n_SuggestQty  
           
         IF @n_QtyPut <= 0   
            BREAK  
 END      
      FETCH NEXT FROM CUR_Replenishment INTO @c_ReplenishmentKey, @c_SuggestLOC, @n_SuggestQty, @c_FromLoc    
   END  
   CLOSE CUR_Replenishment  
   DEALLOCATE CUR_Replenishment  
  
      
   UPDATE TASKDETAIL   
      SET [Status] = '9'  
   WHERE TaskDetailKey = @c_TaskDetailKey   
   AND   UserKey = @c_OperatorID   
   AND   [Status] = '3'    
              
  
   SET @c_RtnMessage = ''  
     
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = "0,"   
   END  
     
  
  
END

GO