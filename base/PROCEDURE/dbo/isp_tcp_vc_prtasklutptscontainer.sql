SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
 /* Store Procedure:  isp_TCP_VC_prTaskLUTPtsContainer                   */  
 /* Creation Date: 13-Mar-2013                                           */  
 /* Copyright: IDS                                                       */  
 /* Written by: ChewKP                                                   */  
 /*                                                                      */  
 /* Purposes: prTaskLUTPtsContainer                                      */  
 /*                                                                      */  
 /*                                                                      */  
 /* Updates:                                                             */  
 /* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPtsContainer] (  
    @c_TranDate            NVARCHAR(20)  
   ,@c_DevSerialNo         NVARCHAR(20)  
   ,@c_OperatorID          NVARCHAR(20)  
   ,@c_RequestType         NVARCHAR(1)   -- 0 = Review -- 1 = Close -- 2 = Open
   ,@c_Loc                 NVARCHAR(10) 
   ,@c_PickToDropID        NVARCHAR(20)
   ,@n_SerialNo            INT 
   ,@c_RtnMessage          NVARCHAR(500) OUTPUT      
   ,@b_Success             INT = 1 OUTPUT  
   ,@n_Error               INT = 0 OUTPUT  
   ,@c_ErrMsg              NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                            -- 98: Critical error. If this error is received,   
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                            --     but does not force the operator to sign off.  
         , @c_Message            NVARCHAR(400)  
         , @c_DropLoc            NVARCHAR(20)  
         , @c_DropID             NVARCHAR(20)
         
           
   SET @c_RtnMessage = ''  
   
   IF @c_RequestType  = '0'
   BEGIN
         SELECT @c_DropLoc = DropLoc
         FROM dbo.DropID 
         WHERE DropID = @c_PickToDropID
                  
         SET @c_ErrorCode = 0   
         SET @c_Message = ''        
   END      
   ELSE IF @c_RequestType  = '1'
   BEGIN
      
      Update dbo.DropID 
      SET Status = '9'
      Where DropID = @c_PickToDropID
      
   END
   ELSE IF @c_RequestType  = '2'
   BEGIN
      INSERT INTO dbo.DropID ( DropID, DropLoc, AdditionalLoc, DropIDType, LabelPrinted, ManifestPrinted, Status ) 
      VALUES ( @c_PickToDropID, @c_Loc, '', 'C', '0', '0', '0')          
   END
   
   
   SET @c_RtnMessage = ISNULL(@c_DropLoc            ,'') + ',' +  
                       ISNULL(@c_DropID             ,'') + ',' +  
                       ISNULL(@c_PickToDropID       ,'') + ',' +  
                       ISNULL(@c_ErrorCode          ,'0') + ',' +  
                       ISNULL(@c_ErrMsg             ,'')  
                                                
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = ',,,,,,,,0,'   
   END  
   

END

GO