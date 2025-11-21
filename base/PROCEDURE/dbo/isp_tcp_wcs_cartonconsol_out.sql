SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_WCS_CARTONCONSOL_OUT                       */
/* Creation Date: 24-02-2012                                            */
/* Copyright: IDS                                                       */
/* Written by: ChewKP                                                   */
/*                                                                      */
/* Purpose: CARTONCONSOL                                                */
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
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_WCS_CARTONCONSOL_OUT] 
                @c_MessageNum_Out   NVARCHAR(10)
              , @b_Debug            INT
              , @b_Success          INT            OUTPUT
              , @n_Err              INT            OUTPUT
              , @c_ErrMsg           NVARCHAR(250)      OUTPUT      
              
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
         , @c_IniFileDirectory      NVARCHAR(100)      -- Chee01 
         
   SELECT @n_Continue = 1, @b_success = 1, @n_Err = 0
   
   SET @n_StartTCnt = @@TRANCOUNT       
      
   SET @c_Data_Out = ''
   SET @n_Status_Out = 0
   SET @c_ErrMsg_Out = ''
   SET @n_SerialNo_Out = 0

   --(Chee01)  
   SELECT @c_IniFileDirectory = Long   
   FROM CODELKUP WITH (NOLOCK)   
   WHERE LISTNAME = 'TCPSOCKET'   
   AND Code = 'CARTONCONSOL'   
     
   EXEC [master].[dbo].[isp_TCPSocket_ClientSocketOut]   
             @c_IniFileDirectory   
           , @c_MessageNum_Out            
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
        , ErrMsg = ISNULL(@c_ErrMsg_Out, '') 
   WHERE  SerialNo = @n_SerialNo_Out
  
   SELECT @n_Err = @@ERROR        
   IF @n_Err <> 0
   BEGIN
      SET @n_Continue = 3     
      SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 70458
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update TCPSocket_OUTLog Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo_Out) + '. (isp_TCP_WCS_CARTONCONSOL_OUT)'
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
      GOTO QUIT_CARTONCONSOL
   END
  
   IF @b_Debug = 1
   BEGIN
      SELECT 'TCPSocket_OUTLog Update Successful. SerialNo : ' + CONVERT(VARCHAR, @n_SerialNo_Out)   
   END        
   
     
--   IF @n_Status_Out <> '9'
--   BEGIN
--      UPDATE dbo.XML_Message  WITH (ROWLOCK) 
--      SET Status = '5'
--        , RefNo = 'WCSLog:' + @c_MessageNum_Out
--      WHERE BatchNo = @c_BatchNo
--      
--      SELECT @n_Err = @@ERROR        
--      IF @n_Err <> 0
--      BEGIN
--         SET @n_Continue = 3  
--         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 70458
--         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update XML_Message Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo_Out) + '. (isp_TCP_WCS_CARTONCONSOL_OUT)'
--                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '                
--         GOTO QUIT_CARTONCONSOL 
--      END        
--      
--      IF @b_Debug = 1
--      BEGIN
--         SELECT 'Update XML_Message Successful. BatchNo : ' + @c_BatchNo
--      END      
--   END     
         
   QUIT_CARTONCONSOL:
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      ROLLBACK TRAN
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_WCS_CARTONCONSOL_OUT'
   END

   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started  
      COMMIT TRAN

   RETURN
END

GO