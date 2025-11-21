SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_GeekPlusRBT_SendEmailAlert                     */
/* Creation Date: 14-Jun-2018                                           */
/* Copyright: LF                                                        */
/* Written by: Alex                                                     */
/*                                                                      */
/* Purpose: Generic Email Alert for GEEK+ robot itf system.             */
/*                                                                      */
/* Input Parameters:  @n_LogAttachmentID - Generate by system           */
/*                    @c_DataStream      - Interface Code (Eg.0018)     */
/*                    @c_InterfaceType   - I = Import / E = Export      */
/*                    @c_Subject         - Title of email               */
/*                    @c_EmailBody       - Content of email             */
/*                    @n_EmailType       - 1                            */
/*                    @c_Status          - W                            */
/*                    @c_Attachment1     - ''                           */
/*                    @c_Attachment2     - ''                           */
/*                    @c_Attachment3     - ''                           */
/*                    @c_Attachment4     - ''                           */
/*                    @c_DynamixEmail1   - ''                           */
/*                    @c_DynamixEmail2   - ''                           */
/*                                                                      */
/* Output Parameters: @b_Success      - Success Flag  = 0               */
/*                                                                      */
/* Usage:  To send email alert based on the records trigger into table  */
/*         EmailAlert of IML processes.                                 */
/*                                                                      */
/* Called By: Store Procedure                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_GeekPlusRBT_SendEmailAlert]
         @c_DTSITF_DBName     nvarchar(10), 
         --@n_LogAttachmentID   int,
         @n_EmailTo           int,
         --@c_EmailToType       char(1),
         --@c_DataStream        varchar(10),
         --@c_InterfaceType     char(1), --  I = Import, E = Export
         @c_Subject           varchar(256),
         @c_EmailBody         varchar(256),
         @b_Success           int OUTPUT
         --@n_EmailType         int = 1,
         --@c_Status            char(1) = 'W',
         --@c_Attachment1       varchar(125) = '',
         --@c_Attachment2       varchar(125) = '',
         --@c_Attachment3       varchar(125) = '',
         --@c_Attachment4       varchar(125) = '',
         --@c_Attachment5       varchar(125) = '',
         --@c_DynamixEmail1     varchar(125) = '',
         --@c_DynamixEmail2     varchar(125) = '',
         --@c_StorerKey         nvarchar(15) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @c_SQLStatement       nvarchar(512)
         , @b_debug              int
         , @n_RowFound           int
         --, @c_Recipient1         varchar(125)
         --, @c_Recipient2         varchar(125)
         --, @c_Recipient3         varchar(125)
         --, @c_Recipient4         varchar(125)
         --, @c_Recipient5         varchar(125)
         , @c_Recipients         NVARCHAR(MAX)
         , @c_EmailAlert         char(1)
         --, @n_EmailTo      int
         --, @c_EmailToType  char(1) --  I = Individual, G = Group
         , @c_EmailAdd           varchar(60)
         , @n_OperatorID         int
         , @n_CountOp            int
         , @c_ExecStatement      nvarchar(4000)
         , @c_ExecArguments      nvarchar(1000)
         , @n_Exist              int
         , @c_KeyName            nvarchar(20)
         , @n_LogAttachmentID    int
         , @n_Err                int
         , @c_ErrMsg             nvarchar(200)

   SELECT @b_Success = 1, @b_debug = 0, @n_RowFound = '0'
   SELECT @c_Recipients = '',
          --@c_Recipient1 = '',
          --@c_Recipient2 = '',
          --@c_Recipient3 = '',
          --@c_Recipient4 = '',
          --@c_Recipient5 = '',
          --@n_EmailTo = 0,
          --@c_EmailToType = '',
          @c_ExecStatement = '', 
          @c_ExecArguments = '',
          @c_KeyName = 'InterfaceLogID',
          @n_Err = 0,
          @c_ErrMsg = ''

   --SET @c_ExecStatement = N'SELECT @n_Exist = COUNT(1)'
   --                     + ' FROM ' + ISNULL(RTRIM(@c_DTSITF_DBName), '') + '.dbo.EmailAlert WITH (NOLOCK)'
   --                     + ' WHERE AttachmentID = @n_LogAttachmentID'
   
   --SET @c_ExecArguments = N'@n_LogAttachmentID INT, @n_Exist INT OUT'
   
   --EXEC sp_ExecuteSql @c_ExecStatement, @c_ExecArguments, @n_LogAttachmentID, @n_Exist OUTPUT

   --IF @n_Exist >= 1 OR (ISNULL(RTRIM(LTRIM(@n_LogAttachmentID)),0) = 0)
   --BEGIN
   --   SET @b_Success = 0
   --   GOTO QUIT
   --END

 --  SET @c_ExecStatement = N'EXECUTE ' + ISNULL(RTRIM(@c_DTSITF_DBName), '') + '.dbo.nspg_getkey '
 --                       + ' @c_KeyName, 10, @n_LogAttachmentID OUTPUT, '
 --                       + ' @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
   
 --  SET @c_ExecArguments = N'@c_KeyName nvarchar(20), @n_LogAttachmentID INT OUTPUT , @b_Success INT OUT, @n_Err INT OUT, @c_ErrMsg INT OUT'
   
 --  EXEC sp_ExecuteSql @c_ExecStatement, @c_ExecArguments, @c_KeyName, @n_LogAttachmentID OUTPUT, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 
  
	--IF @b_Success <> 1
	--BEGIN
	--   GOTO QUIT
	--END

   SET @c_ExecStatement = N'SELECT @n_CountOp = COUNT(OperatorID)'
                        + ' FROM ' + ISNULL(RTRIM(@c_DTSITF_DBName), '') + '.dbo.itfGroupMember WITH (NOLOCK)'
                        + ' WHERE GroupID = @n_EmailTo'
   
   SET @c_ExecArguments = N'@n_EmailTo INT, @n_CountOp INT OUT'
   
   EXEC sp_ExecuteSql @c_ExecStatement, @c_ExecArguments, @n_EmailTo, @n_CountOp OUTPUT
   
   --SELECT @n_CountOp = COUNT(OperatorID)
   --FROM itfGroupMember WITH (NOLOCK)
   --WHERE GroupID = @n_EmailTo
   --PRINT '@n_EmailTo : ' + CONVERT(NVARCHAR,@n_EmailTo)

   IF @n_CountOp > 0
   BEGIN
      SET @c_ExecStatement = N'DECLARE C_InsertEmailAlert CURSOR FAST_FORWARD READ_ONLY FOR'
                           + ' SELECT itfGroupMember.OperatorID, itfOperator.Email'
                           + ' FROM ' + ISNULL(RTRIM(@c_DTSITF_DBName), '') + '.dbo.itfGroupMember WITH (NOLOCK)'
                           + ' JOIN ' + ISNULL(RTRIM(@c_DTSITF_DBName), '') + '.dbo.itfOperator WITH (NOLOCK)'
                           + ' ON itfOperator.OperatorID = itfGroupMember.OperatorID'
                           + ' WHERE itfGroupMember.GroupID = @n_EmailTo'
                           + ' ORDER BY itfGroupMember.OperatorID'
   
      SET @c_ExecArguments = N'@n_EmailTo INT'
   
      EXEC sp_ExecuteSql @c_ExecStatement, @c_ExecArguments, @n_EmailTo
      
      --DECLARE C_InsertEmailAlert CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --SELECT itfGroupMember.OperatorID, itfOperator.Email
      --FROM itfGroupMember WITH (NOLOCK)
      --JOIN itfOperator WITH (NOLOCK) ON itfOperator.OperatorID = itfGroupMember.OperatorID
      --WHERE itfGroupMember.GroupID = @n_EmailTo
      --ORDER BY itfGroupMember.OperatorID
   
      OPEN C_InsertEmailAlert
      FETCH NEXT FROM C_InsertEmailAlert INTO @n_OperatorID
                                            , @c_EmailAdd
   
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN -- while header
         --PRINT '@c_EmailAdd : ' + @c_EmailAdd
         --IF (ISNULL(RTRIM(@c_Recipient1),'') = '')
         --BEGIN
         --   SELECT @c_Recipient1 = @c_EmailAdd
         --END
         --ELSE
         --IF (ISNULL(RTRIM(@c_Recipient1),'') <> '') AND (ISNULL(RTRIM(@c_Recipient2),'') = '')
         --BEGIN
         --   SELECT @c_Recipient2 = @c_EmailAdd
         --END
         --ELSE
         --IF (ISNULL(RTRIM(@c_Recipient2),'') <> '') AND (ISNULL(RTRIM(@c_Recipient3),'') = '')
         --BEGIN
         --   SELECT @c_Recipient3 = @c_EmailAdd
         --END
         --ELSE
         --IF (ISNULL(RTRIM(@c_Recipient3),'') <> '') AND (ISNULL(RTRIM(@c_Recipient4),'') = '')
         --BEGIN
         --   SELECT @c_Recipient4 = @c_EmailAdd
         --END
         --ELSE
         --IF (ISNULL(RTRIM(@c_Recipient4),'') <> '') AND (ISNULL(RTRIM(@c_Recipient5),'') = '')
         --BEGIN
         --   SELECT @c_Recipient5 = @c_EmailAdd
         --END
         SET @c_Recipients = IIF(ISNULL(RTRIM(@c_Recipients), '') <> '', (@c_Recipients + ';' + @c_EmailAdd), (@c_Recipients + @c_EmailAdd) )

         FETCH NEXT FROM C_InsertEmailAlert INTO @n_OperatorID
                                               , @c_EmailAdd
      END -- While detail
      CLOSE C_InsertEmailAlert
      DEALLOCATE C_InsertEmailAlert
   END -- @n_CountOp > 1

   --PRINT '@c_Recipient1 : ' + @c_Recipient1
   --BEGIN TRAN

   --INSERT INTO EmailAlert (AttachmentID, [Subject], Recipient1, Recipient2, Recipient3,
   --                        Recipient4, Recipient5, EmailBody, DataStream, [Status], 
   --                        Attachment1, Attachment2, Attachment3, Attachment4, Attachment5)
   --VALUES (ISNULL(RTRIM(LTRIM(@n_LogAttachmentID)),0), @c_Subject, @c_Recipient1, @c_Recipient2, @c_Recipient3,
   --        @c_Recipient4, @c_Recipient5, @c_EmailBody, @c_DataStream, @c_Status,
   --        @c_Attachment1, @c_Attachment2, @c_Attachment3, @c_Attachment4, @c_Attachment5)

   --SET @c_ExecStatement = N'INSERT INTO ' + ISNULL(RTRIM(@c_DTSITF_DBName), '') + '.dbo.EmailAlert '
   --                     + ' (AttachmentID, [Subject], Recipient1, Recipient2, Recipient3,'
   --                     + ' Recipient4, Recipient5, EmailBody, DataStream, [Status], '
   --                     + ' Attachment1, Attachment2, Attachment3, Attachment4, Attachment5)'
   --                     + ' VALUES (ISNULL(RTRIM(LTRIM(@n_LogAttachmentID)),0), @c_Subject, @c_Recipient1, @c_Recipient2, @c_Recipient3,'
   --                     + ' @c_Recipient4, @c_Recipient5, @c_EmailBody, @c_DataStream, @c_Status,'
   --                     + ' @c_Attachment1, @c_Attachment2, @c_Attachment3, @c_Attachment4, @c_Attachment5)'

   --SET @c_ExecArguments = N'@n_LogAttachmentID INT, @c_Subject varchar(256), @c_Recipient1 varchar(125), '
   --                     + ' @c_Recipient2 varchar(125), @c_Recipient3 varchar(125), '
   --                     + ' @c_Recipient4 varchar(125), @c_Recipient5 varchar(125), '
   --                     + ' @c_EmailBody varchar(256), @c_DataStream varchar(10), @c_Status char(1), '
   --                     + ' @c_Attachment1 varchar(125), @c_Attachment2 varchar(125), @c_Attachment3 varchar(125), '
   --                     + ' @c_Attachment4 varchar(125), @c_Attachment5 varchar(125)'
   
   --EXEC sp_ExecuteSql @c_ExecStatement, @c_ExecArguments, 
   --                   @n_LogAttachmentID, @c_Subject, @c_Recipient1, @c_Recipient2, @c_Recipient3,
   --                   @c_Recipient4, @c_Recipient5, @c_EmailBody, @c_DataStream, @c_Status,
   --                   @c_Attachment1, @c_Attachment2, @c_Attachment3, @c_Attachment4, @c_Attachment5


   EXEC [msdb].[dbo].[sp_send_dbmail] 
     @recipients = @c_Recipients
   , @blind_copy_recipients = ''
   , @subject = @c_Subject
   , @importance = 'NORMAL'
   , @body = @c_EmailBody
   , @body_format = 'HTML'

   --COMMIT TRAN

   QUIT:
   IF CURSOR_STATUS('GLOBAL' , 'C_InsertEmailAlert') in (0 , 1)
   BEGIN
      CLOSE C_InsertEmailAlert
      DEALLOCATE C_InsertEmailAlert
   END
END -- procedure

GO