SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTCoreBreakTypes                 */  
/* Creation Date: 26-Feb-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: This message retrieves all the valid break types that can be*/  
/*          specified by the operator. If a host system does not want to*/  
/*          support break types, the host should return a response in   */  
/*          the format below, with all fields blank except Error Code,  */  
/*          which should be set to 0.                                   */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTCoreBreakTypes] (  
    @c_TranDate     NVARCHAR(20)  
   ,@c_DevSerialNo  NVARCHAR(20)  
   ,@c_OperatorID   NVARCHAR(20)  
   ,@n_SerialNo     INT  
   ,@c_RtnMessage   NVARCHAR(500) = '' OUTPUT      
   ,@b_Success      INT = 1 OUTPUT  
   ,@n_Error        INT = 0 OUTPUT  
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT      
)  
AS  
BEGIN  
   DECLARE @c_CustomerName      NVARCHAR(60)  
         , @c_ConfirmPasswd     NVARCHAR(60)  
         , @c_ErrorCode         NVARCHAR(20)  
         , @c_Message           NVARCHAR(400)  
         , @c_ReasonCode        NVARCHAR(10)
         , @c_Descr             NVARCHAR(60)
         , @n_Counter           INT
  
   -- Temporary Disable, Might need to setup the break type in the codelkup  
   
   SET @c_ConfirmPasswd = '1'  
   SET @c_ErrorCode = 0   
   SET @c_Message = ''  
   SET @n_Counter = 1
   
   -- Get From TaskManagerReason Tables
   DECLARE CursorBreak CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   
   SELECT  TaskManagerReasonKey
         , Descr
   FROM dbo.TaskManagerReason WITH (NOLOCK)
   WHERE IsNumeric(TaskManagerReasonKey) = 1
   Order by TaskManagerReasonKey
   
   OPEN CursorBreak            
   
   FETCH NEXT FROM CursorBreak INTO @c_ReasonCode, @c_Descr
   
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
      
      IF @n_Counter = '1'
      BEGIN      
          SET @c_RtnMessage = ISNULL(RTRIM(@c_ReasonCode)      ,'') + ',' +  
                              ISNULL(RTRIM(@c_Descr)           ,'') + ',' +  
                              ISNULL(@c_ErrorCode       ,'0') + ',' +  
                              ISNULL(@c_ErrMsg          ,'')  
      END
      ELSE
      BEGIN
          SET @c_RtnMessage = @c_RtnMessage + '<CR><LF>' + 
                              ISNULL(RTRIM(@c_ReasonCode)      ,'') + ',' +  
                              ISNULL(RTRIM(@c_Descr)           ,'') + ',' +  
                              ISNULL(@c_ErrorCode       ,'0') + ',' +  
                              ISNULL(@c_ErrMsg          ,'')  
         
      END
      
      SET @n_Counter = @n_Counter + 1 
      
      FETCH NEXT FROM CursorBreak INTO @c_ReasonCode, @c_Descr
      
   END
   CLOSE CursorBreak            
   DEALLOCATE CursorBreak   
   
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = ',,0,'  
   END    
   

     
END

GO