SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_WCS_GS1_Label_OUT                          */
/* Creation Date: 05-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: MCTang                                                   */
/*                                                                      */
/* Purpose: GS1 Label                                                   */
/*          WMS to RedWerks Exceed                                      */
/*                                                                      */
/* Input Parameters:  @c_MessageNum    - Unique no for Incoming data    */
/*                                                                      */
/* Output Parameters: @b_Success       - Success Flag  = 0              */
/*                    @n_Err           - Error Code    = 0              */
/*                    @c_ErrMsg        - Error Message = ''             */
/*                                                                      */
/* PVCS Version: 1.1                                                   	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 15-Feb-2012  Chee      1.1   Add FilePath parameter in isp_TCPSocket_*/
/*                              GS1LabelClientSocket (Chee01)           */  
/* 05-Mar-2012  ChewKP    1.2   Standardize GS1 Insertion to            */
/*                              TCPSocket_Ouglog (ChewKP01)             */
/* 13-Mar-2012  Shong     1.3   MessageNum Variable Length Should be 8  */
/*                              Redwerk do not accept space             */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_WCS_GS1_Label_OUT] 
                --@c_MessageNum_Out   NVARCHAR(10)
                @c_BatchNo          NVARCHAR(20)                  
              , @b_Debug            INT
              , @b_Success          INT            OUTPUT
              , @n_Err              INT            OUTPUT
              , @c_ErrMsg           NVARCHAR(250)      OUTPUT      
              , @c_DeleteGS1        NVARCHAR(1) = 'Y'
              , @c_StorerKey        NVARCHAR(15)
              , @c_Facility         NVARCHAR(5)
              , @c_LabelNo          NVARCHAR(20)
              , @c_DropID           NVARCHAR(20)   
AS
BEGIN
   SET NOCOUNT ON		
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        
                    
   DECLARE @n_StartTCnt             INT
         , @c_Data_Out              NVARCHAR(1000)
         , @n_Status_Out            INT
         , @c_ErrMsg_Out            NVARCHAR(400)    
         , @n_SerialNo_Out          INT   
         , @n_Continue              INT
         , @c_IniFileDirectory      NVARCHAR(100)  -- Chee01 
         , @c_MessageNum_Out        NVARCHAR( 8)       -- (ChewKP01)
         , @n_IsRDT                 INT            -- (ChewKP01)
                  
   SELECT @n_Continue = 1, @b_success = 1, @n_Err = 0
   
   SET @n_StartTCnt = @@TRANCOUNT       
      
   SET @c_Data_Out = ''
   SET @n_Status_Out = 0
   SET @c_ErrMsg_Out = ''
   SET @n_SerialNo_Out = 0
   
   
   -- (ChewKP01) Start
    /***************************************************/     
   /* Insert TCPSocket_OUTLog                         */     
   /***************************************************/       
   
   UPDATE XML_MESSAGE     
          SET STATUS = '0'    
   WHERE BATCHNO = @c_BatchNo  
            
   SET @b_Success = 0      
   
   EXECUTE nspg_GetKey      
      'TCPOUTLog',      
      8,         
      @c_MessageNum_Out OUTPUT,      
      @b_Success        OUTPUT,      
      @n_Err            OUTPUT,      
      @c_ErrMsg         OUTPUT      
   
      
   SELECT @c_Data_Out = 'GS1LABEL|' + @c_MessageNum_Out + '|' + UPPER(ISNULL(RTRIM(@c_StorerKey),'')) + '|' + ISNULL(RTRIM(@c_Facility),'') + '|' 
   + UPPER(ISNULL(RTRIM(@c_DropID),'')) + '|' + UPPER(ISNULL(RTRIM(@c_LabelNo),'')) + '|'    
       
   
   INSERT INTO TCPSocket_OUTLog     
   (MessageNum, MessageType, Data, Status, StorerKey, LabelNo, BatchNo ,RefNo)     
   VALUES     
   (@c_MessageNum_Out, 'SEND', @c_Data_Out, '0', @c_StorerKey, @c_LabelNo, @c_BatchNo, @c_DropID)    
       

   -- Chee01 
   SELECT @c_IniFileDirectory = Long
   FROM Codelkup WITH (NOLOCK)
   WHERE LISTNAME = 'TCPSOCKET'
   AND Code = 'GS1LABEL'
  
   EXEC [master].[dbo].[isp_TCPSocket_GS1LabelClientSocket]
        @c_IniFileDirectory      -- Chee01  
      , @c_MessageNum_Out	
      , @c_BatchNo		 
      , @n_Status_Out OUTPUT
      , @c_ErrMsg_Out OUTPUT
      	        	      
   BEGIN TRAN  
         	      
   SELECT @n_SerialNo_Out = SerialNo 
   FROM   dbo.TCPSocket_OUTLog WITH (NOLOCK) 
   WHERE  MessageNum    = @c_MessageNum_Out
   AND    MessageType   = 'SEND' 
   AND    Status        = '0'
     
   UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK) 
   SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out) 
        , ErrMsg = CASE ISNULL(@c_ErrMsg_Out, '') WHEN '' THEN ''
                   ELSE @c_ErrMsg_Out + ' <Xml_Message.BatchNo = ' + @c_BatchNo + '>'  END
   WHERE  SerialNo = @n_SerialNo_Out
  
   SELECT @n_Err = @@ERROR        
   IF @n_Err <> 0
   BEGIN
      SET @n_Continue = 3     
      SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 75253
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update TCPSocket_OUTLog Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo_Out) + '. (isp_TCP_WCS_GS1_Label_OUT)'
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
      GOTO QUIT_GS1 
   END
  
   IF @b_Debug = 1
   BEGIN
      SELECT 'TCPSocket_OUTLog Update Successful. SerialNo : ' + CONVERT(VARCHAR, @n_SerialNo_Out)   
   END        
   
   IF @c_DeleteGS1 = 'Y' AND @n_Status_Out = '9'
   BEGIN
      DELETE FROM XML_Message 
      WHERE BatchNo = @c_BatchNo 
      
      SELECT @n_Err = @@ERROR        
      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3       
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 75254
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Delete XML_Message Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo_Out) + '. (isp_TCP_WCS_GS1_Label_OUT)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '                
         GOTO QUIT_GS1 
      END            
      
      IF @b_Debug = 1
      BEGIN
         SELECT 'Delete XML_Message Successful. BatchNo : ' + @c_BatchNo
      END   
   END
   
   IF @n_Status_Out <> '9'
   BEGIN
      UPDATE dbo.XML_Message  WITH (ROWLOCK) 
      SET Status = '5'
        , RefNo = 'WCSLog:' + @c_MessageNum_Out
      WHERE BatchNo = @c_BatchNo
      
      SELECT @n_Err = @@ERROR        
      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3  
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 75255
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update XML_Message Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo_Out) + '. (isp_TCP_WCS_GS1_Label_OUT)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '                
         GOTO QUIT_GS1 
      END        
      
      IF @b_Debug = 1
      BEGIN
         SELECT 'Update XML_Message Successful. BatchNo : ' + @c_BatchNo
      END      
   END     
         
   QUIT_GS1:
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
       --DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
      
      IF @n_IsRDT = 1 -- (ChewKP01)
      BEGIN
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
          -- Instead we commit and raise an error back to parent, let the parent decide
      
          -- Commit until the level we begin with
          WHILE @@TRANCOUNT > @n_StartTCnt
             COMMIT TRAN
      
          -- Raise error with severity = 10, instead of the default severity 16. 
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
          RAISERROR (@n_err, 10, 1) WITH SETERROR 
      
          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END   
      ELSE
      BEGIN
         ROLLBACK TRAN
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_WCS_GS1_Label_OUT'
         
         WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started  
         COMMIT TRAN
         
         RETURN
      END
      
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started  
         COMMIT TRAN
   
      RETURN
   END      
END

GO