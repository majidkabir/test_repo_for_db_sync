SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
 /* Store Procedure:  isp_TCP_VC_prTaskLUTForkGetPutAway                 */  
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
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTForkGetPutAway] (  
    @c_TranDate     NVARCHAR(20)  
   ,@c_DevSerialNo  NVARCHAR(20)  
   ,@c_OperatorID   NVARCHAR(20)  
   ,@n_SerialNo     INT  
   ,@c_RtnMessage   NVARCHAR(500) OUTPUT      
   ,@b_Success      INT = 1 OUTPUT  
   ,@n_Error        INT = 0 OUTPUT  
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE   
           @c_AreaKey            NVARCHAR(10)  
  
         , @c_PickAndDropLoc     NVARCHAR(20)  
         , @c_FromLOC            NVARCHAR(10)  
         , @c_ID                 NVARCHAR(20)  
         , @c_StorerKey          NVARCHAR(20)  
         , @c_UOM                NVARCHAR(10)     
         , @c_PackKey            NVARCHAR(10)          
         , @c_AssignMntID        NVARCHAR(10)  
         , @c_AssignMntDesc      NVARCHAR(100)    
         , @n_Qty                INT   
                   
  
         -- Output Columns  
         , @c_LPNumber           NVARCHAR(18)  
         , @c_RegionNo           NVARCHAR(5)  
         , @c_SuggToLoc          NVARCHAR(10)           
         , @c_ScannedValidation  NVARCHAR(100)           
         , @c_ToPreAisleDrtn     NVARCHAR(50)  
         , @c_ToAisle            NVARCHAR(100)  
         , @c_ToPostAisleDrtn    NVARCHAR(50)  
         , @c_ToSlot             NVARCHAR(100)  
         , @c_ToCheckDigit       NVARCHAR(2)  
         , @c_SKU                NVARCHAR(20)     
         , @c_SKUDesc            NVARCHAR(60)  
         , @c_QtyPutaway         NVARCHAR(10)  
         , @c_GoalTime           NVARCHAR(10)  
         , @c_ErrorCode          NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                            -- 98: Critical error. If this error is received,   
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                            --     but does not force the operator to sign off.  
         , @c_Message            NVARCHAR(400)  
           
           
            
   SET @c_RtnMessage = ''  
   SET @c_LPNumber          = ''  
   SET @c_RegionNo          = ''  
   SET @c_SKU               = ''  
   SET @c_SKUDesc           = ''  
   SET @c_QtyPutaway        = ''  
   SET @c_ToPreAisleDrtn    = ''  
   SET @c_ToAisle           = ''  
   SET @c_ToPostAisleDrtn   = ''  
   SET @c_ToSlot            = ''  
   SET @c_ToCheckDigit      = ''  
   SET @c_ScannedValidation = ''  
   SET @c_SuggToLoc         = ''  
   SET @c_GoalTime          = ''     
     
   SELECT @c_RegionNo   = r.V_String1,   
          @c_FromLOC    = r.V_Loc,  
          @c_ID         = r.V_ID    
   FROM RDT.RDTMOBREC r WITH (NOLOCK)  
   WHERE r.UserName = @c_OperatorID   
   AND   r.DeviceID = @c_DevSerialNo  
     
   SELECT TOP 1   
              @c_StorerKey = lli.StorerKey   
            , @c_LPNumber = ID                  
            , @c_SKU = lli.Sku                  
            , @c_SKUDesc = s.DESCR             
            , @n_Qty = lli.Qty    
            , @c_GoalTime = '0'                   
      FROM LOTxLOCxID lli WITH (NOLOCK)   
      JOIN SKU s WITH (NOLOCK) ON s.Storerkey = lli.Storerkey AND s.Sku = lli.Sku   
      JOIN LOC WITH (NOLOCK) ON LOC.Loc = lli.Loc    
   WHERE lli.Loc = @c_FromLOC   
   AND   lli.Id = @c_ID  
      
        
   SELECT @c_ErrMsg = ''  
   
   EXEC @n_Error = [dbo].[nspRDTPASTD]      
                       @c_userid        = @c_OperatorID    
                     , @c_storerkey     = @c_Storerkey     
                     , @c_lot           = ''               
                     , @c_sku           = ''               
                     , @c_id            = @c_ID            
                     , @c_fromloc       = @c_FromLOC       
                     , @n_qty           = @n_QTY           
                     , @c_uom           = @c_UOM           
                     , @c_packkey       = @c_PackKey       
                     , @n_putawaycapacity = 0      
                     , @c_final_toloc     = @c_SuggToLoc OUTPUT      
                     , @c_PickAndDropLoc  = @c_PickAndDropLoc OUTPUT       
  
   SET @c_ErrorCode = 0   
   SET @c_Message = ''  
     
   IF ISNULL(RTRIM(@c_SuggToLoc),'') <> ''  
   BEGIN  
        
      SELECT  @c_ToPreAisleDrtn = 'Say ready to put away'       
            , @c_ToAisle = L.LocAisle              
            , @c_ToPostAisleDrtn = ''     
            , @c_ToSlot = 'Bay ' + L.LocBay               
            , @c_ToCheckDigit = CASE WHEN ISNUMERIC(L.LocCheckDigit) = 1 THEN RIGHT('0'+ RTRIM(L.LocCheckDigit), 2) ELSE '' END        
      FROM LOC L WITH (NOLOCK)  
      WHERE L.LOC = @c_SuggToLoc  
        
      UPDATE MR  
         SET MR.V_SKU = @c_SKU,   
             MR.V_ID = @c_LPNumber,   
             MR.V_SKUDescr = @c_SKUDesc,   
             MR.V_Qty = @n_Qty   
      FROM RDT.RDTMOBREC MR    
      WHERE UserName = @c_OperatorID   
      AND   DeviceID = @c_DevSerialNo         
   END  
   ELSE  
   BEGIN  
      SET @c_ErrorCode = '89'  
      SET @c_Message   = 'Problem Finding Put away Location, check with Supervisor'  
        
   END  
     
   SET @c_RegionNo = @c_AreaKey  
     
   SET @c_RtnMessage =   
      ISNULL(RTRIM(@c_LPNumber         ),'') + ',' +     
      ISNULL(RTRIM(@c_RegionNo         ),'') + ',' +     
      ISNULL(RTRIM(@c_SuggToLoc        ),'') + ',' +             
      ISNULL(RTRIM(@c_ScannedValidation),'') + ',' +              
      ISNULL(RTRIM(@c_ToPreAisleDrtn   ),'') + ',' +     
      ISNULL(RTRIM(@c_ToAisle          ),'') + ',' +     
      ISNULL(RTRIM(@c_ToPostAisleDrtn  ),'') + ',' +     
      ISNULL(RTRIM(@c_ToSlot           ),'') + ',' +     
      ISNULL(RTRIM(@c_ToCheckDigit     ),'') + ',' +     
      ISNULL(RTRIM(@c_SKU              ),'') + ',' +       
      ISNULL(RTRIM(@c_SKUDesc          ),'') + ',' +     
      ISNULL(RTRIM(@c_QtyPutaway       ),'') + ',' +     
      ISNULL(RTRIM(@c_GoalTime         ),'') + ',' +  
      @c_ErrorCode         + ',' +  
      @c_Message             
     
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = '12345,1,67890,67890656521,Building 1,23,Bay 33,890,53,9998741,Coca-Cola 12-pack,000000010,15,0,'   
   END  
     
  
  
END

GO