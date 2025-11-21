SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
 /* Store Procedure:  isp_TCP_VC_prTaskLUTForkPutAwayLicense             */
 /* Creation Date: 26-Feb-2013                                           */
 /* Copyright: IDS                                                       */
 /* Written by: Shong                                                    */
 /*                                                                      */
 /* Purposes: This message is sent once the operator puts away either    */
 /*           (a) the entire quantity of a license plate or              */
 /*           (b) all the quantity an operator specifies can be put at a */
 /*               location for a license plate.                          */
 /*                                                                      */
 /* Updates:                                                             */
 /* Date         Author    Purposes                                      */
 /************************************************************************/
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTForkPutAwayLicense] (
    @c_TranDate      NVARCHAR(20)
   ,@c_DevSerialNo   NVARCHAR(20)
   ,@c_OperatorID    NVARCHAR(20)
   ,@c_License       NVARCHAR(18)
   ,@n_QtyPut        INT
   ,@c_ToLocation    NVARCHAR(10)
   ,@c_PutStatus     NVARCHAR(1) -- 0 = partial put, 1 = complete put, 2 = released put
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
         , @n_TranCount          INT 
         , @c_FromLoc            NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
         , @c_StorerKey          NVARCHAR(15)
         , @c_PackUOM3           NVARCHAR(10)
         , @c_SKU                NVARCHAR(20)
         , @n_PutAwayQty         INT 
         , @c_LOT                NVARCHAR(10)
         , @c_PackKey            NVARCHAR(10)
         , @c_OutString          NVARCHAR(215)
        
   SET @c_ErrorCode = '0'
   SET @c_Message   = ''
   
   SELECT @c_FromLoc   = V_LOC, 
          @c_StorerKey = r.StorerKey, 
          @c_ID        = r.V_ID 
   FROM RDT.RDTMOBREC r WITH (NOLOCK)
   WHERE r.UserName = @c_OperatorID
   AND   r.DeviceID = @c_DevSerialNo
   
   IF ISNULL(@c_ToLocation, '') <> ''    
   BEGIN    
      -- Handling transaction    
      SET @n_TranCount = @@TRANCOUNT    
      BEGIN TRAN  -- Begin our own transaction    
      SAVE TRAN rdtfnc_Pallet_Putaway -- For rollback or commit only our own transaction    
             
      DECLARE CUR_Putaway CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
      SELECT LOT, SKU, (QTY - QTYALLOCATED - QTYPICKED)    
      FROM dbo.LOTxLOCxID WITH (NOLOCK)    
      WHERE LOC = @c_FromLoc    
        AND ID  = @c_ID    
        AND (QTY - QTYALLOCATED - QTYPICKED) > 0    
    
      OPEN CUR_Putaway    
      FETCH NEXT FROM CUR_Putaway INTO @c_LOT, @n_PutAwayQty    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SELECT @c_PackUOM3 = PACKUOM3, 
                @c_PackKey   = PACK.PackKey    
         FROM   dbo.PACK PACK WITH (NOLOCK)  
         JOIN   dbo.SKU SKU WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey   
         WHERE SKU.StorerKey = @c_StorerKey 
         AND   SKU.Sku = @c_SKU  
                  
         -- Only putaway what is needed. For example, if I wanna putaway 10 qty to LOC A & 5 qty to LOC B from same LOC    
         -- So 1st time I key in 10 qty then 2nd time I key in 5 qty (james02)    
         IF @n_QtyPut < @n_PutAwayQty    
            SET @n_PutAwayQty = @n_QtyPut    
 
         -- NOTE: Not convert QTY as nspItrnAddMove will convert QTY based on pass-in UOM    
         EXEC dbo.nspRFPA02    
              @c_sendDelimiter = '`'           
            , @c_ptcid         = 'VOICE'         
            , @c_userid        = @c_OperatorID        
            , @c_taskId        = 'VOICE'         
            , @c_databasename  = NULL          
            , @c_appflag       = NULL        
            , @c_recordType    = NULL          
            , @c_server        = NULL          
            , @c_storerkey     = @c_Storerkey   
            , @c_lot           = @c_LOT          
            , @c_sku           = @c_SKU          
            , @c_fromloc       = @c_FromLoc      
            , @c_fromid        = @c_ID           
            , @c_toloc         = @c_ToLocation    
            , @c_toid          = @c_ID           
            , @n_qty           = @n_PutAwayQty   
            , @c_uom           = @c_PackUOM3     
            , @c_packkey       = @c_PackKey      
            , @c_reference     = ' '            
            , @c_OutString     = @c_OutString  OUTPUT   -- NVARCHAR(255)  OUTPUT    
            , @b_Success       = @b_Success    OUTPUT   -- int        OUTPUT    
            , @n_err           = @n_Error      OUTPUT   -- int        OUTPUT    
            , @c_errmsg        = @c_ErrMsg     OUTPUT   -- NVARCHAR(250)  OUTPUT    
 
         IF @n_Error <> 0    
         BEGIN        
            CLOSE CUR_Putaway    
            DEALLOCATE CUR_Putaway    
            --GOTO RollBackTran    
         END    
 
         SET @n_QtyPut = @n_QtyPut - @n_PutAwayQty  
          
         IF @n_QtyPut = 0    
            BREAK   
             
         FETCH NEXT FROM CUR_Putaway INTO @c_LOT, @n_PutAwayQty    
      END    
      CLOSE CUR_Putaway    
      DEALLOCATE CUR_Putaway    
                
      COMMIT TRAN rdtfnc_Pallet_Putaway -- Only commit change made here    
      WHILE @@TRANCOUNT > @n_TranCount -- Commit until the level we started    
         COMMIT TRAN    
   END    


   SET @c_RtnMessage = @c_ErrorCode + ',' + @c_Message 
   
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0 
   BEGIN
      SET @c_RtnMessage = '0,' 
   END
   


END

GO