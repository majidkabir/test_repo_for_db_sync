SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: [isp_GTLSvc_PrintNApply_MsgValidation]              */
/* Creation Date: 06-Jul-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17432 MY Nike LabelApplicator Process Inbound Msg to    */ 
/*          Generic TCPSocket Listener Service                          */
/*                                                                      */
/* Input Parameters:  @c_Application      -                             */
/*                    @c_LocalEndPoint    -                             */
/*                    @c_RemoteEndPoint   -                             */
/*                    @c_MessageType      -                             */
/*                    @c_Data             -                             */
/*                    @c_StorerKey        -                             */
/*                    @c_StartTime        -                             */
/*                    @b_Debug            -                             */
/*                                                                      */
/* Output Parameters: @b_Success          - Success Flag    = 0         */
/*                    @n_Err              - Error No        = 0         */
/*                    @c_ErrMsg           - Error Message   = ''        */
/*                    @c_ResponseString   - ResponseString  = ''        */
/*                                                                      */
/* Called By: Generic TCPSocket Listener Service (GTLSvc)               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver  Purposes                                    */
/* 17-Jan-2022 NJOW    1.0  DEVOPS combine script                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_GTLSvc_PrintNApply_MsgValidation] (
      @c_Application       NVARCHAR(50)
    , @c_LocalEndPoint     NVARCHAR(50)
    , @c_RemoteEndPoint    NVARCHAR(50)
    , @c_MessageType       NVARCHAR(10)
    , @c_Data              NVARCHAR(MAX)
    , @c_StorerKey         NVARCHAR(15)
    , @c_StartTime         NVARCHAR(30)
    , @b_Debug             INT      
    , @c_RespondMsg        NVARCHAR(MAX)   OUTPUT  
    , @b_Success           INT             OUTPUT  
    , @n_Err               INT             OUTPUT  
    , @c_ErrMsg            NVARCHAR(250)   OUTPUT  
 )  
AS   
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @c_ExecStatements     NVARCHAR(4000)       
         , @c_ExecArguments      NVARCHAR(4000)   
         , @n_continue           INT                  
   
   DECLARE @c_MessageNum         NVARCHAR(10) 
         , @c_SprocName          NVARCHAR(100)
         , @c_Status             NVARCHAR(1)  
         , @n_SerialNo           INT
        
   DECLARE @c_MessageID          NVARCHAR(10)
         , @c_MessageName        NVARCHAR(50)
         , @c_MessageGroup       NVARCHAR(20)
         , @c_MsgStatus          NVARCHAR(10)
         , @c_MsgReasonCode      NVARCHAR(10)
         , @c_MsgErrMsg          NVARCHAR(100)
         , @c_EndTime            NVARCHAR(50)
         , @b_AddSTX             INT
         , @c_CartonID           NVARCHAR(30)
         , @c_ConveyorLaneNo     NVARCHAR(20)         

   SET @c_MessageNum             = ''              -- Not used here, shall be ''
   SET @c_SprocName              = ''              -- Not used here, shall be ''
   SET @c_Status                 = '9'             -- shall be 9
   SET @c_RespondMsg             = ''              -- shall be ''
   SET @b_Success                = 1               -- shall be 1
   SET @n_Err                    = 0               -- shall be 0
   SET @c_ErrMsg                 = ''              -- shall be ''

   SET @c_ExecStatements         = ''
   SET @c_ExecArguments          = ''
   SET @n_continue               = '1'

   SET @c_MessageID              = ''
   SET @c_MessageName            = ''
   SET @c_MessageGroup           = ''
   SET @c_MsgStatus              = ''
   SET @c_MsgReasonCode          = ''
   SET @c_MsgErrMsg              = ''
   SET @c_EndTime                = ''      
   SET @b_AddSTX                 = 0       
   SET @c_CartonID               = ''
   SET @c_ConveyorLaneNo         = '' 
         
   DECLARE @tbl_Serial TABLE ( SerialNo INT )

   /*********************************************/  
   /* INSERT INTO TCPSOCKET_INLOG - START       */  
   /*********************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
   
      INSERT INTO dbo.TCPSOCKET_INLOG (Application, LocalEndPoint , RemoteEndPoint, MessageType, Data, StorerKey, StartTime)
      OUTPUT INSERTED.SerialNo INTO @tbl_Serial
      VALUES (@c_Application, @c_LocalEndPoint, @c_RemoteEndPoint, @c_MessageType, @c_Data, @c_StorerKey, @c_StartTime)

      IF @@ERROR <> 0  
      BEGIN  
         SET @c_Status = '5'  
         SET @n_continue = 3  
         SET @n_err = 68010     
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': Error Inserting into TCPSOCKET_INLOG. (isp_GTLSvc_PrintNApply_MsgValidation)'
      END  

      --Retrieve Inserted SerialNo
      SELECT @n_SerialNo = SerialNo FROM @tbl_Serial
      
      IF CHARINDEX(@c_Data, '<STX>',0) > -1
      BEGIN
         SET @b_AddSTX = 1
         SET @c_Data = REPLACE(REPLACE(@c_Data,'<STX>',''),'<ETX>','')
      END
   END

   /*********************************************/  
   /* VALIDATION                                */  
   /*********************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      SELECT @c_MessageName   = ColValue FROM dbo.fnc_DelimSplit(';',@c_Data) WHERE SeqNo = 1    
      SELECT @c_CartonID   = ColValue FROM dbo.fnc_DelimSplit(';',@c_Data) WHERE SeqNo = 2    
      SELECT @c_ConveyorLaneNo   = ColValue FROM dbo.fnc_DelimSplit(';',@c_Data) WHERE SeqNo = 3    
      
      IF @c_MessageName = ''
      BEGIN
         SET @c_Status = '5'  
         SET @n_continue = 3  
         SET @n_Err = 68020  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': Message Name cannot be blank. (isp_GTLSvc_PrintNApply_MsgValidation)'  
         GOTO QUIT  
      END

      IF @c_CartonID = ''
      BEGIN
         SET @c_Status = '5'  
         SET @n_continue = 3  
         SET @n_Err = 68030 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': Carton ID cannot be blank. (isp_GTLSvc_PrintNApply_MsgValidation)'  
         GOTO QUIT  
      END

      IF @c_ConveyorLaneNo = ''
      BEGIN
         SET @c_Status = '5'  
         SET @n_continue = 3  
         SET @n_Err = 68040  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': Conveyor Lane No cannot be blank. (isp_GTLSvc_PrintNApply_MsgValidation)'  
         GOTO QUIT  
      END
   END
     
   /*********************************************/  
   /* EXECUTE SUB-SP                            */      
   /*********************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
  
      -- Get SProcName based on MessageGroup and MessageName  
      SELECT @c_SProcName = ISNULL(RTRIM(SProcName),'')   
      FROM TCPSocket_Process WITH (NOLOCK)  
      WHERE MessageGroup = ISNULL(RTRIM(@c_MessageGroup),'')  
      AND MessageName = ISNULL(RTRIM(@c_MessageName),'')  
        
      IF ISNULL(RTRIM(@c_SProcName),'') = ''  
      BEGIN  
         SET @c_Status = '5'  
         SET @n_continue = 3  
         SET @n_Err = 68050  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': SProcName cannot be blank. (isp_GTLSvc_PrintNApply_MsgValidation)'  
         GOTO QUIT  
      END        

      --Get SP Execution StartTime
      SET @c_StartTime = CONVERT(VARCHAR(19), GETDATE(), 120)

      SET @c_ExecStatements = 'EXEC ' + @c_SProcName 
                            + '  @n_SerialNo = @n_SerialNo'
                            + ', @c_MessageID = @c_MessageID'
                            + ', @c_MessageName = @c_MessageName'
                            + ', @c_RespondMsg = @c_RespondMsg OUTPUT'
                            + ', @b_Success = @b_Success OUTPUT '
                            + ', @n_Err = @n_Err OUTPUT '
                            + ', @c_ErrMsg = @c_ErrMsg OUTPUT '

      SET @c_ExecArguments  = N'  @n_SerialNo     INT'         
                            + N', @c_MessageID    NVARCHAR(10)'
                            + N', @c_MessageName  NVARCHAR(15)'
                            + N', @c_RespondMsg   NVARCHAR(MAX) OUTPUT'
                            + N', @b_Success      INT OUTPUT'
                            + N', @n_Err          INT OUTPUT'
                            + N', @c_ErrMsg       NVARCHAR(250) OUTPUT'

      EXECUTE sp_ExecuteSql  @c_ExecStatements  
                           , @c_ExecArguments 
                           , @n_SerialNo    
                           , @c_MessageID 
                           , @c_MessageName 
                           , @c_RespondMsg   OUTPUT
                           , @b_Success      OUTPUT
                           , @n_Err          OUTPUT
                           , @c_ErrMsg       OUTPUT                       

      IF @@ERROR <> 0  
      BEGIN  
         SET @c_Status = '5'  
         SET @n_continue = 3  
         SET @n_err=68060     
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': Error Executing ' + @c_SProcName + ' (isp_GTLSvc_PrintNApply_MsgValidation)'  
      END
      ELSE IF @b_Success <> 1
      BEGIN
         SET @c_Status = '5'  
         SET @n_continue = 3  
      END  

      IF @b_debug = 1  
      BEGIN
         SELECT 'Data:'             [Data]  
              , @n_SerialNo         [@n_SerialNo]  
              , @c_MessageID        [@c_MessageID]  
              , @c_MessageName      [@c_MessageName]  
              , @c_RespondMsg       [@c_RespondMsg]        
      END  
     
      --Get SP Execution EndTime
      SET @c_EndTime = CONVERT(VARCHAR(19), GETDATE(), 120)
   END  
  
   --Send respond with Error or ACK for HeartBeat Message.  
   SEND_RESPOND:  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'SEND_RESPOND:'     [SEND_RESPOND]  
            , @c_Status          [@c_Status]  
            , @c_ErrMsg          [@c_ErrMsg]  
  
   END  
  

   /*********************************************/  
   /* Construct Respond Message                 */  
   /*********************************************/  
   --IF @n_continue = 1 OR @n_continue = 2  
   --BEGIN  
     
   --   --SET @c_AckMessageID = RIGHT(REPLICATE('0', 10) + LTRIM(RTRIM(@c_AckMessageID)),10)  
   --   --SET @c_MessageID = RIGHT(REPLICATE('0', 10) + LTRIM(RTRIM(@c_MessageID)),10)  
  
   --   --SET @c_RespondMsg = @c_AckMessageID                                              --[MessageID]  
   --   --                  + LEFT(LTRIM('ACK')              + REPLICATE(' ', 15) , 15)    --[MessageName]  
   --   --                  + @c_MessageID                                              --[OrigMessageID]  
   --   --                  + LEFT(LTRIM(@c_Status)          + REPLICATE(' ', 10) , 10)    --[Status]  
   --   --                  + LEFT(LTRIM(@c_ReasonCode)      + REPLICATE(' ', 10) , 10)    --[ReasonCode]  
   --   --                  + LEFT(LTRIM(@c_ErrMsg)          + REPLICATE(' ',100) ,100)    --[ErrMsg]  
  
   --END  
     
   QUIT:  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'QUIT:'             [QUIT]  
            , @c_Status          [@c_Status]  
            , @n_continue        [@n_continue]  
            , @n_err             [@n_err]  
            , @c_ErrMsg          [@c_ErrMsg]  
   END  
  
   /*********************************************/  
   /* Construct Default Error Respond Message   */  
   /*********************************************/  
   IF @n_continue = '3' AND ISNULL(@c_RespondMsg,'') = ''
   BEGIN
      SET @c_MsgStatus = 'ER'                                                
      SET @c_RespondMsg = RTRIM(LTRIM(@c_MessageName)) + ';' + RTRIM(LTRIM(@c_CartonID)) + ';' + RTRIM(LTRIM(@c_ConveyorLaneNo)) + ';' + RTRIM(LTRIM(@c_MsgStatus))
   END
   ELSE 
   BEGIN
      SET @c_MsgStatus = 'OK'                                                
      SET @c_RespondMsg = RTRIM(LTRIM(@c_MessageName)) + ';' + RTRIM(LTRIM(@c_CartonID)) + ';' + RTRIM(LTRIM(@c_ConveyorLaneNo)) + ';' + RTRIM(LTRIM(@c_MsgStatus))
   END

   IF @b_AddSTX = 1
   BEGIN
      SET @c_RespondMsg = '<STX>' + @c_RespondMsg + '<ETX>'
   END

   UPDATE TCPSocket_INLog WITH (ROWLOCK)  
   SET    MessageNum = @c_MessageID
         ,ACKData = @c_RespondMsg
         ,STATUS = @c_Status  
         ,ErrMsg = @c_Errmsg
         ,StartTime = @c_StartTime  
         ,EndTime = @c_EndTime      
         ,EditDate  = GETDATE()     
   WHERE  SerialNo = @n_SerialNo  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err=68070     
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                     + ': Update TCPSocket_INLog fail. (isp_GTLSvc_PrintNApply_MsgValidation)'  
   END     
   
   IF @b_debug = 1  
   BEGIN  
      SELECT 'Respond:'          [Respond]  
            , @c_RespondMsg      [@c_RespondMsg]  
   END     
END  

GO