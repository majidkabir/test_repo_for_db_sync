SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
 /* Store Procedure:  isp_TCP_VC_prTaskLUTPtsGetFTLocation                 */
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
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPtsGetFTLocation] (
    @c_TranDate     NVARCHAR(20)
   ,@c_DevSerialNo  NVARCHAR(20)
   ,@c_OperatorID   NVARCHAR(20)
   ,@c_Region       NVARCHAR(10)
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
   

   
  -- SET @c_RegionNo = @c_AreaKey
   
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
      SET @c_RtnMessage = 'A B 1 4,0,' 
   END
   
   -- Update TCPSocket_Inlog 
   UPDATE dbo.TCPSocket_InLog
   SET Status = '9'
   WHERE SerialNo = @n_SerialNo  

END

GO