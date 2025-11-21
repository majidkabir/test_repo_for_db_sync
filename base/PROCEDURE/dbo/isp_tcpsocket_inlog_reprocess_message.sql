SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/              
/* Store procedure: isp_TCPSocket_InLog_Reprocess_Message               */              
/* Creation Date: 15-Feb-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Reprocess aging and error messages in TCPSocket_InLog       */
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
/* 2012-05-16   Ung        Remove transaction (ung01)                   */
/************************************************************************/    
CREATE PROC [dbo].[isp_TCPSocket_InLog_Reprocess_Message](
  @nMinute       INT = 0
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE 
      @c_SprocName         NVARCHAR(30) ,
      @c_MessageNum        NVARCHAR(8) ,
      --@nTranCount          INT , --(ung01)
      @c_ExecStatements    NVARCHAR(4000) ,
      @c_ExecArguments     NVARCHAR(4000) , 
      @b_Success           INT ,
      @n_Err               INT ,   
      @c_ErrMsg            NVARCHAR(400),
      @n_Err_Out           INT,        
      @c_ErrMsg_Out        CHAR(250),
      @n_SerialNo          INT

   -- SET @nTranCount = @@TRANCOUNT  --(ung01)
   SET @n_Err = 0
   SET @c_ErrMsg = ''

   -- BEGIN TRAN  --(ung01)

   IF OBJECT_ID('tempdb..#InLog_MessageTemp','u') IS NULL
   BEGIN
      CREATE TABLE #InLog_MessageTemp
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
        SprocName    NVARCHAR(30)  NULL
      )
   END

   -- insert Aging and error Message
   INSERT INTO #InLog_MessageTemp
   SELECT 
      i.SerialNo, 
      --CASE WHEN i.MessageType = 'ERROR' THEN 'MISC' ELSE SUBSTRING(i.Data, 1, 15) END,
      SUBSTRING(i.Data, 1, 15),
      i.MessageNum,
      i.Status,  
      i.AddDate, 
      p.Recipient1, 
      p.Recipient2, 
      p.Recipient3, 
      p.Recipient4, 
      p.Recipient5, 
      p.SprocName
   FROM TCPSOCKET_INLOG i WITH (NOLOCK)
   JOIN TCPSOCKET_PROCESS p ON (SUBSTRING(i.Data, 1, 15) = p.MessageName)--((CASE WHEN i.MessageType = 'ERROR' THEN 'MISC' ELSE SUBSTRING(i.Data, 1, 15) END) = p.MessageName)
   WHERE (Status = '0' OR Status = '5') 
     AND i.MessageType = 'RECEIVE'
     AND i.NoOfTry < 3
     AND DATEDIFF(minute, i.AddDate ,GETDATE()) > @nMinute
   ORDER BY i.MessageNum

   SET @n_Err = @@ERROR
   IF @n_Err <> 0
   BEGIN
      SELECT @n_Err = 70000
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Insert into #InLog_MessageTemp Table. (isp_TCPSocket_InLog_Reprocess_Message)'
                       + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
      GOTO ROLLBACKTRAN
   END

   DECLARE cur_Reprocess_Msg CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SerialNo, SprocName, MessageNum
   FROM #InLog_MessageTemp WITH (NOLOCK)
   WHERE ISNULL(SprocName,'') <> ''

   -- Open Cursor
   OPEN cur_Reprocess_Msg 

   FETCH NEXT FROM cur_Reprocess_Msg INTO 
     @n_SerialNo
   , @c_SprocName
   , @c_MessageNum

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @c_ExecStatements =  N'EXEC ' + @c_SprocName + ' '
                             + '''' + @c_MessageNum + ''', '    
                             + '0, '    
                             + '@b_Success     OUTPUT, '    
                             + '@n_Err_Out     OUTPUT, '
                             + '@c_ErrMsg_Out  OUTPUT'
                     
      SET @c_ExecArguments = N' @b_Success    INT        OUTPUT
                              , @n_Err_Out    INT        OUTPUT
                              , @c_ErrMsg_Out CHAR(250)  OUTPUT'
             
      EXEC sp_ExecuteSql  @c_ExecStatements
                        , @c_ExecArguments
                        , @b_Success         OUTPUT 
                        , @n_Err_Out         OUTPUT 
                        , @c_ErrMsg_Out      OUTPUT 

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Err = 70001
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error executing sp_ExecuteSql. (isp_TCPSocket_InLog_Reprocess_Message)'
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
         GOTO ROLLBACKTRAN
      END
      
      -- NoOfTry + 1
      UPDATE TCPSocket_Inlog WITH (ROWLOCK)
      SET NoOfTry = NoOfTry + 1
      WHERE SerialNo = @n_SerialNo

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Err = 70002
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error updating TCPSocket_Inlog Table. (isp_TCPSocket_InLog_Reprocess_Message)'
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
         GOTO ROLLBACKTRAN
      END

     -- Fetch Next From Cursor
		FETCH NEXT FROM cur_Reprocess_Msg INTO 
		  @n_SerialNo
		, @c_SprocName
		, @c_MessageNum

   END
   -- Close Cursor
   CLOSE cur_Reprocess_Msg 
   DEALLOCATE cur_Reprocess_Msg

   GOTO Quit  

RollBackTran:  
   IF (SELECT CURSOR_STATUS('local','cur_Reprocess_Msg')) >=0 
   BEGIN
      CLOSE cur_Reprocess_Msg              
      DEALLOCATE cur_Reprocess_Msg      
   END

   -- ROLLBACK TRAN --(ung01)
   EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCPSocket_InLog_Reprocess_Message'    
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
       
Quit:  
   --WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
   --   COMMIT TRAN  --(ung01)
END -- Procedure

GO