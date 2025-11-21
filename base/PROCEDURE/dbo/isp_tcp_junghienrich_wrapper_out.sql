SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_TCP_Junghienrich_Wrapper_OUT                    */
/* Creation Date: 22 Feb 2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Build TCP socket message to send and receive from           */ 
/*          Junghienrich TCP Socket Listener                            */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 13-Nov-2013  Chee      1.1   Replace MessageNum with SerialNo to     */
/*                              avoid blocking [nspg_GetKey] (Chee01)   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_Junghienrich_Wrapper_OUT]
   @c_RemoteEndPoint NVARCHAR(50)
  ,@c_TruckAction    NVARCHAR(5)
  ,@c_Location       NVARCHAR(10)
  ,@c_ReplyMessage   NVARCHAR(225)
  ,@c_StorerKey      NVARCHAR(15)
  ,@b_Debug          INT 
  ,@b_Success        INT            OUTPUT
  ,@n_Err            INT            OUTPUT
  ,@c_ErrMsg         NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
      @c_IniFilePath          NVARCHAR(100),
      @c_SendMessage          NVARCHAR(MAX),
      @c_LocalEndPoint        NVARCHAR(50) ,
      @c_ReceiveMessage       NVARCHAR(MAX),
      @c_vbErrMsg             NVARCHAR(MAX)

   DECLARE  
      @n_SerialNo          INT,
      @c_Application       NVARCHAR(50),
      @c_MessageNum_Out    NVARCHAR(10),
      @c_Status            NVARCHAR(1),
      @n_NoOfTry           INT

   DECLARE @t_StoreSerialNo TABLE(SerialNo INT);  

   SET @c_Application = 'GenericTCPSocketClient_' + @c_StorerKey
   SET @c_Status = '9'
   SET @n_NoOfTry = 0

   SELECT @c_IniFilePath = Long
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'TCPClient'
     AND CODE     = 'FilePath'

   IF ISNULL(@c_RemoteEndPoint,'') = ''
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 10000  
      SET @c_ErrMsg = 'Remote End Point cannot be empty. (isp_TCP_Junghienrich_Wrapper_OUT)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ' )'  
      GOTO Quit 
   END

   IF ISNULL(@c_TruckAction,'') = ''
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 10001  
      SET @c_ErrMsg = 'Truck Action cannot be empty. (isp_TCP_Junghienrich_Wrapper_OUT)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ' )'  
      GOTO Quit 
   END

   SET @c_SendMessage = 'STX|' + @c_TruckAction + + '|' + RTRIM(@c_Location) + '|' + RTRIM(@c_ReplyMessage) + '|ETX'
   
   IF @b_Debug = 1  
   BEGIN  
      SELECT 
         @c_Application AS 'Application',
         @c_IniFilePath AS 'INIFilePath',
         @c_RemoteEndPoint AS 'RemoteEndPoint',
         @c_SendMessage AS '@c_Data_Out'
   END  

-- Chee01
/*
   -- Get new TCPSocket_OutLog.MessageNum
   EXECUTE nspg_GetKey
      'TCPOUTLog',
      8,
      @c_MessageNum_Out OUTPUT,
      @b_Success        OUTPUT,
      @n_Err            OUTPUT,
      @c_ErrMsg         OUTPUT

   IF @b_Success <> 1 OR @n_err <> 0
   BEGIN  
      SET @b_Success = 0
      SET @n_Err = 10002  
      SET @c_ErrMsg = 'nspGetRight TCPOUTLog Failed. (isp_TCP_Junghienrich_Wrapper_OUT)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ' )'  
      GOTO Quit  
   END  

   IF @b_Debug = 1  
   BEGIN  
      SELECT @c_MessageNum_Out AS 'MessageNumber'
   END  
*/

   -- Insert TCP SEND message
   INSERT INTO TCPSocket_OUTLog ([Application], RemoteEndPoint, MessageNum, MessageType, Data, Status, StorerKey)
   OUTPUT INSERTED.SerialNo INTO @t_StoreSerialNo  
   --VALUES (@c_Application, @c_RemoteEndPoint, @c_MessageNum_Out, 'SEND', @c_SendMessage, @c_Status, @c_StorerKey)
   VALUES (@c_Application, @c_RemoteEndPoint, '', 'SEND', @c_SendMessage, @c_Status, @c_StorerKey)

   IF @@ERROR <> 0  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = 10003  
      SET @c_ErrMsg = 'Error inserting into [dbo].[TCPSocket_OUTLog] Table. (isp_TCP_Junghienrich_Wrapper_OUT)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ' )'  
      GOTO Quit  
   END  

   -- Get SeqNo  
   SELECT @n_SerialNo = SerialNo  
   FROM @t_StoreSerialNo  

   -- Chee01
   SET @c_MessageNum_Out = CAST(@n_SerialNo AS NVARCHAR(10))

   EXEC [master].[dbo].[isp_GenericTCPSocketClient]
      @c_IniFilePath,
      @c_RemoteEndPoint,
      @c_SendMessage,
      @c_LocalEndPoint        OUTPUT,
      @c_ReceiveMessage       OUTPUT,
      @c_vbErrMsg             OUTPUT

   IF @@ERROR <> 0 OR ISNULL(@c_vbErrMsg,'') <> ''  
   BEGIN  
      SET @c_Status = '5'  
      SET @b_Success = 0  
      SET @n_Err = 10004 

      -- SET @cErrmsg  
      IF ISNULL(@c_VBErrMsg,'') <> ''  
      BEGIN  
         SET @c_Errmsg = CAST(@c_VBErrMsg AS NVARCHAR(250))  
      END  
      ELSE  
      BEGIN  
         SET @c_Errmsg = 'Error executing [master].[dbo].[isp_GenericTCPSocketClient]. (isp_TCP_Junghienrich_Wrapper_OUT)'  
                       + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ' )'  
      END  
   END  

   -- SET NoOfTry to 3 to avoid schedule job from reprocessing the message
   IF @c_Status = '5'
   BEGIN
      SET @n_NoOfTry = 3
   END
   ELSE
   BEGIN
      -- INSERT TCP RECEIVE message
      INSERT INTO TCPSocket_OUTLog ([Application], LocalEndPoint, RemoteEndPoint, MessageNum, MessageType, Data, Status, StorerKey)
      VALUES (@c_Application, @c_LocalEndPoint, @c_RemoteEndPoint, @c_MessageNum_Out, 'RECEIVE', @c_ReceiveMessage, '9', @c_StorerKey)

      IF @@ERROR <> 0  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 10005  
         SET @c_ErrMsg = 'Error inserting into [dbo].[TCPSocket_OUTLog] Table. (isp_TCP_Junghienrich_Wrapper_OUT)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ' )'  
         GOTO Quit  
      END  

      -- Receive error from Junghienrich
      IF @c_ReceiveMessage LIKE 'err:%'
      BEGIN
         SET @n_NoOfTry = 3

         SET @c_Status = '5'  
         SET @b_Success = 0  
         SET @n_Err = 10006
         SET @c_ErrMsg = 'Error from Junghienrich. (isp_TCP_Junghienrich_Wrapper_OUT)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ' )'  
      END
   END
   
   -- Update TCP SEND message
   UPDATE TCPSocket_OUTLog WITH (ROWLOCK)
   SET LocalEndPoint = @c_LocalEndPoint, Status = @c_Status, ErrMsg = @c_Errmsg, NoOfTry = @n_NoOfTry,
       MessageNum = @c_MessageNum_Out -- Chee01
   WHERE SerialNo = @n_SerialNo 

   IF @@ERROR <> 0  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = 10007
      SET @c_Errmsg = 'Error updating [dbo].[TCPSocket_OUTLog] Table. (isp_TCP_Junghienrich_Wrapper_OUT)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ' )'  
      GOTO Quit  
   END  

Quit:  

END

GO