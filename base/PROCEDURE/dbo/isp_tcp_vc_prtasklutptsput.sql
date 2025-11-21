SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
 /* Store Procedure:  isp_TCP_VC_prTaskLUTPtsPut                         */  
 /* Creation Date: 08-May-2013                                           */  
 /* Copyright: IDS                                                       */  
 /* Written by: Shong                                                    */  
 /*                                                                      */  
 /* Purposes: prTaskLUTPtsPut                                            */  
 /*                                                                      */  
 /*                                                                      */  
 /* Updates:                                                             */  
 /* Date         Author    Purposes                                      */  
 /************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPtsPut] (  
    @c_TranDate            NVARCHAR(20)  
   ,@c_DevSerialNo         NVARCHAR(20)  
   ,@c_OperatorID          NVARCHAR(20)  
   ,@c_GroupID             NVARCHAR(30)   
   ,@c_CustLoc             NVARCHAR(10)
   ,@c_SKU                 NVARCHAR(20)
   ,@c_PutID               NVARCHAR(20)
   ,@c_QtyPut              NVARCHAR(10)
   ,@c_ContainerID         NVARCHAR(20)
   ,@c_LPN                 NVARCHAR(20)
   ,@c_Partial             NVARCHAR(1)  -- 0 = Final amount put, 1 = Partial amount put
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
   
  
   
   SET @c_RtnMessage = ISNULL(@c_ErrorCode          ,'0') + ',' +  
                       ISNULL(@c_ErrMsg             ,'')  
                                                
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = '0,'   
   END  
   

END

GO