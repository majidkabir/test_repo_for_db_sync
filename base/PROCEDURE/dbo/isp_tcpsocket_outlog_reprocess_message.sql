SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/              
/* Store procedure: isp_TCPSocket_OutLog_Reprocess_Message              */              
/* Creation Date: 23-Feb-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Reprocess aging and error messages in TCPSocket_OutLog      */
/*                                                                      */
/*                                                                      */
/* Called By: ??                                                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 2012-04-30   Ung        Surpress NAK for GS1LLABEL send multi times  */
/* 2012-05-02   Ung        Fix commit / roll back without begin tran    */
/************************************************************************/    
CREATE PROC [dbo].[isp_TCPSocket_OutLog_Reprocess_Message](
  @nMinute       INT = 0
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE 
      @c_SprocName         NVARCHAR(30) ,
      @c_MessageNum        NVARCHAR(8) ,
      @c_MessageName       NVARCHAR(15), 
      @c_ExecStatements    NVARCHAR(4000) ,
      @c_ExecArguments     NVARCHAR(4000) , 
      @n_SerialNo          INT,
      @c_BatchNo           NVARCHAR(50),
      @c_GS1IniFilePath    NVARCHAR(100),
      @c_CarConIniFilePath NVARCHAR(100),
      @n_Status            INT,
      @n_Err               INT,
      @c_ErrMsg            NVARCHAR(400),
      @n_Err_Out           INT,        
      @c_ErrMsg_Out        NVARCHAR(250), 
      @c_LabelNo           NVARCHAR(20)

   SET @n_Err = 0
   SET @c_ErrMsg = ''

   IF OBJECT_ID('tempdb..#OutLog_MessageTemp','u') IS NULL
   BEGIN
      CREATE TABLE #OutLog_MessageTemp
      ( SerialNo     INT, 
        MessageName  NVARCHAR(15), 
        MessageNum   NVARCHAR(8),
        Status       NVARCHAR(1),
        AddDate      DATETIME,
        Recipient1   NVARCHAR(125) NULL,
        Recipient2   NVARCHAR(125) NULL,
        Recipient3   NVARCHAR(125) NULL,
        Recipient4   NVARCHAR(125) NULL,
        Recipient5   NVARCHAR(125) NULL,
        BatchNo      NVARCHAR(50)  NULL
      )
   END

   INSERT INTO #OutLog_MessageTemp
   SELECT 
      o.SerialNo, 
		CASE WHEN CHARINDEX('GS1LABEL', o.Data) > 0 THEN 'GS1LABEL' ELSE 'CARTONCONSOL' END, 
		o.MessageNum, 
      o.Status,
		o.AddDate, 
      p.Recipient1, 
		p.Recipient2, 
		p.Recipient3, 
		p.Recipient4, 
		p.Recipient5, 
		o.BatchNo
   FROM TCPSOCKET_OUTLOG o WITH (NOLOCK)
   JOIN TCPSOCKET_PROCESS p ON ((CASE WHEN CHARINDEX('GS1LABEL', o.Data) > 0 THEN 'GS1LABEL' ELSE 'CARTONCONSOL' END) = p.MessageName)
   WHERE (Status = '0' OR Status = '5') 
		AND o.MessageType = 'SEND' 
		AND o.NoOfTry < 3
		AND DATEDIFF(minute, o.AddDate ,GETDATE()) > @nMinute
		
  ORDER BY o.MessageNum

   SET @n_Err = @@ERROR
   IF @n_Err <> 0
   BEGIN
      SELECT @n_Err = 70000
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Insert into #OutLog_MessageTemp Table. (isp_TCPSocket_OutLog_Reprocess_Message)'
                       + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
      GOTO Error
   END

   -- Insert those that receive NAK
   WHILE EXISTS (SELECT 1 
                 FROM TCPSOCKET_OUTLOG o WITH (NOLOCK) 
                 WHERE o.MessageType = 'RECEIVE' 
                   AND CHARINDEX('NAK', o.DATA) > 0  
                   AND o.EmailSent = '0' 
                   AND DATEDIFF(minute, o.AddDate ,GETDATE()) > @nMinute) 
   BEGIN
      -- Get Receive Message
      SELECT TOP 1 
         @n_SerialNo = SerialNo, 
         @c_MessageNum = MessageNum 
      FROM TCPSOCKET_OUTLOG o WITH (NOLOCK) 
      WHERE o.MessageType = 'RECEIVE' 
        AND CHARINDEX('NAK', o.DATA) > 0
        AND o.EmailSent = '0' 
        AND DATEDIFF(minute, o.AddDate ,GETDATE()) > @nMinute

      -- Surpress NAK for GS1LLABEL send multi times, except the 1st one
      IF EXISTS( SELECT TOP 1 1
         FROM TCPSOCKET_OUTLOG WITH (NOLOCK) 
         WHERE MessageType = 'SEND'
           AND LEFT( Data, 8) = 'GS1LABEL'
           AND MessageNum < @c_MessageNum
           AND LabelNo = (
               SELECT ISNULL( LabelNo, '') 
               FROM TCPSOCKET_OUTLOG WITH (NOLOCK) 
               WHERE MessageNum = @c_MessageNum 
                  AND LEFT( Data, 8) = 'GS1LABEL'
                  AND MessageType = 'SEND'))
      BEGIN
         -- Mark this NAK as email sent, but not actually sent it
         UPDATE TCPSOCKET_OUTLOG WITH (ROWLOCK) SET 
            EmailSent = '1'
         WHERE SerialNo = @n_SerialNo
         
         CONTINUE
      END

      -- Get Original message and insert into #OutLog_MessageTemp 
      INSERT INTO #OutLog_MessageTemp 
      SELECT 
         o.SerialNo, 
			CASE WHEN CHARINDEX('GS1LABEL', o.Data) > 0 THEN 'GS1LABEL' ELSE 'CARTONCONSOL' END, 
			o.MessageNum, 
         o.Status,
			o.AddDate, 
			p.Recipient1,
			p.Recipient2, 
			p.Recipient3, 
			p.Recipient4, 
			p.Recipient5, 
			o.BatchNo
      FROM TCPSOCKET_OUTLOG o WITH (NOLOCK) 
      JOIN TCPSOCKET_PROCESS p ON ((CASE WHEN CHARINDEX('GS1LABEL', o.Data) > 0 THEN 'GS1LABEL' ELSE 'CARTONCONSOL' END) = p.MessageName)
      WHERE o.MessageType = 'SEND'
        AND o.NoOfTry < 3  
        AND MessageNum = @c_MessageNum

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Err = 70001
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Insert into #OutLog_MessageTemp Table. (isp_TCPSocket_OutLog_Reprocess_Message)'
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
         GOTO Error
      END

      -- Update Receive Message's EmailSent to 1
      UPDATE TCPSOCKET_OUTLOG WITH (ROWLOCK)
      SET EmailSent = '1'
      WHERE SerialNo = @n_SerialNo

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Err = 70002
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Updating TCPSOCKET_OUTLOG Table. (isp_TCPSocket_OutLog_Reprocess_Message)'
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
         GOTO Error
      END
   END

   -- GET FilePath of config.ini
   SELECT @c_GS1IniFilePath = Long     
   FROM CODELKUP WITH (NOLOCK)     
   WHERE LISTNAME = 'TCPSOCKET'     
   AND Code = 'GS1LABEL'  

   -- GS1IniFilePath is empty
   IF ISNULL(@c_GS1IniFilePath,'') = ''
   BEGIN
      SELECT @n_Err = 70003
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': GS1 IniFilePath is empty. (isp_TCPSocket_OutLog_Reprocess_Message)'
                       + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
      GOTO Error
   END

   SELECT @c_CarConIniFilePath = Long     
   FROM CODELKUP WITH (NOLOCK)     
   WHERE LISTNAME = 'TCPSOCKET'     
   AND Code = 'CARTONCONSOL'   

   -- CarConIniFilePath is empty
   IF ISNULL(@c_CarConIniFilePath,'') = ''
   BEGIN
      SELECT @n_Err = 70004
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': CartonConsol IniFilePath is empty. (isp_TCPSocket_OutLog_Reprocess_Message)'
                       + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
      GOTO Error
   END  

   DECLARE cur_Reprocess_Msg CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SerialNo, MessageNum, MessageName, BatchNo
   FROM #OutLog_MessageTemp WITH (NOLOCK)

   -- Open Cursor
   OPEN cur_Reprocess_Msg 

   FETCH NEXT FROM cur_Reprocess_Msg INTO 
     @n_SerialNo
   , @c_MessageNum
   , @c_MessageName
   , @c_BatchNo

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @n_Status = 0 
      SET @c_ErrMsg = NULL

      -- SET status to 0, if not client socket SP cant select
      UPDATE TCPSOCKET_OUTLOG WITH (ROWLOCK)
      SET status = '0', errmsg = ''
      WHERE MessageType = 'SEND' 
        AND MessageNum = @c_MessageNum

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Err = 70005
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Updating TCPSOCKET_OUTLOG Table. (isp_TCPSocket_OutLog_Reprocess_Message)'
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
         GOTO Error
      END

      -- SET status to 0
      UPDATE XML_MESSAGE WITH (ROWLOCK)
      SET status = '0'
      WHERE BatchNo = @c_BatchNo

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Err = 70006
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Updating XML_MESSAGE Table. (isp_TCPSocket_OutLog_Reprocess_Message)'
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
         GOTO Error
      END

      IF @c_MessageName = 'GS1LABEL'
      BEGIN

         EXEC [master].[dbo].[isp_TCPSocket_GS1LabelClientSocket] 
         @c_GS1IniFilePath,
         @c_MessageNum,
         @c_BatchNo,
         @n_Status OUTPUT,
         @c_ErrMsg OUTPUT

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Err = 70007
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error executing isp_TCPSocket_GS1LabelClientSocket. (isp_TCPSocket_OutLog_Reprocess_Message)'
                             + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
            GOTO Error
         END

         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)   
         SET STATUS = CONVERT(VARCHAR(1), @n_Status)   
           , ErrMsg = CASE ISNULL(@c_ErrMsg, '') WHEN '' THEN ''  
                      ELSE @c_ErrMsg + ' <Xml_Message.BatchNo = ' + @c_BatchNo + '>'  END  
         WHERE  SerialNo = @n_SerialNo 

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Err = 70008
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Updating TCPSocket_OUTLog Table. (isp_TCPSocket_OutLog_Reprocess_Message)'
                             + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
            GOTO Error
         END
      END
      ELSE IF @c_MessageName = 'CARTONCONSOL'
      BEGIN

         EXEC [master].[dbo].[isp_TCPSocket_ClientSocketOut] 
         @c_CarConIniFilePath,
         @c_MessageNum,
         @n_Status OUTPUT,
         @c_ErrMsg OUTPUT

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Err = 70009
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error executing isp_TCPSocket_ClientSocketOut. (isp_TCPSocket_OutLog_Reprocess_Message)'
                             + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
            GOTO Error
         END

         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)   
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status)   
              , ErrMsg = ISNULL(@c_ErrMsg, '')   
         WHERE  SerialNo = @n_SerialNo  

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Err = 70010
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Updating TCPSocket_OUTLog Table. (isp_TCPSocket_OutLog_Reprocess_Message)'
                             + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
            GOTO Error
         END
      END

      -- NoOfTry + 1
      UPDATE TCPSocket_Outlog WITH (ROWLOCK)
      SET NoOfTry = NoOfTry + 1
      WHERE SerialNo = @n_SerialNo

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Err = 70011
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error updating TCPSocket_Outlog Table. (isp_TCPSocket_OutLog_Reprocess_Message)'
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
         GOTO Error
      END

     -- Fetch Next From Cursor
     FETCH NEXT FROM cur_Reprocess_Msg INTO 
        @n_SerialNo
      , @c_MessageNum
      , @c_MessageName
      , @c_BatchNo

   END
   -- Close Cursor
   CLOSE cur_Reprocess_Msg 
   DEALLOCATE cur_Reprocess_Msg

   GOTO Quit

Error:  
   IF (SELECT CURSOR_STATUS('local','cur_Reprocess_Msg')) >=0 
   BEGIN
      CLOSE cur_Reprocess_Msg              
      DEALLOCATE cur_Reprocess_Msg      
   END

   EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCPSocket_OutLog_Reprocess_Message'    
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    

Quit:
   RETURN; 

END -- Procedure

GO