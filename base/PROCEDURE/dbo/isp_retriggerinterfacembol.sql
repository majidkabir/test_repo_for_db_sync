SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_RetriggerInterfaceMBOL                         */
/* Creation Date: 22-MAY-2020                                           */
/* Copyright:                                                           */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  Re-Trigger records for interface wrapper                   */
/*                                                                      */
/* Input Parameters:      @c_TableName                                  */
/*                        @c_Key1                                       */
/*                        @c_Key2                                       */
/*                        @c_Key3                                       */
/*                        @c_Storerkey                                  */
/*                        @c_ARchiveDB                                  */
/*                        @c_SourceDB                                   */ 
/*                        @b_debug                                      */ 
/*                                                                      */
/* Usage:  Re-Trigger records into TransmitLog Table for interface.     */
/*                                                                      */
/* Called By:isp_ReTriggerTransmitLog_Wrapper                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.   Purposes                               */
/* DD-MMM-YYYY                                                          */
/************************************************************************/

CREATE PROC  [dbo].[isp_RetriggerInterfaceMBOL]
             @c_Key1           NVARCHAR(20)
           , @c_Key2           NVARCHAR(30)      = ''
           , @c_Key3           NVARCHAR(20)     = ''
           , @c_TableName      NVARCHAR(30)     = ''
           , @c_Storerkey      NVARCHAR(20)     = ''
           , @c_ARchiveDB      NVARCHAR(50)     = ''
           , @c_SourceDB       NVARCHAR(10)     = ''
           , @b_Success        int       OUTPUT
           , @n_err            int       OUTPUT
           , @c_errmsg         NVARCHAR(250) OUTPUT
           , @b_debug          int              = 0 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        int 
         , @c_SPCode          NVARCHAR(50)
       , @c_SQL             NVARCHAR(MAX)
      -- , @c_ARchiveDB       NVARCHAR(10)
       , @c_Country         NVARCHAR(10)
      -- , @c_SourceDB        NVARCHAR(10)
       , @c_TableSchema     NVARCHAR(50) 
       , @c_GetTableName    NVARCHAR(50)
       , @c_KeyColumn       NVARCHAR(50)
       , @c_DocKey          NVARCHAR(50)
       , @n_StartTCnt       INT  
       , @n_rowno          INT
       , @c_ColName        NVARCHAR(MAX)
       , @c_Exists         NVARCHAR(1)
       , @c_RecFound       NVARCHAR(1)
       , @c_ExecArguments  NVARCHAR(MAX)
       , @c_Transmitlogkey NVARCHAR(10)

   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT   

   SET @c_SPCode = ''
   SET @c_ARchiveDB = ''
   SET @c_Country = ''
   SET @c_SourceDB = ''

   WHILE @@TRANCOUNT > 0   
   BEGIN  
      COMMIT TRAN  
   END 

   SELECT @c_ARchiveDB = RTRIM(NSQLVALUE)
   FROM NSQLCONFIG (NOLOCK)
   WHERE CONFIGKEY = 'ArchiveDBName'
   

    --SELECT @c_country = RTRIM(NSQLVALUE)
    --FROM NSQLCONFIG (NOLOCK)
    --WHERE CONFIGKEY = 'Country'

   SET @c_SourceDB = DB_NAME() 
   
   --   SET @c_SourceDB = @c_country + 'WMS'

   if @b_debug = '1'
   BEGIN
     SELECT @c_ARchiveDB '@c_ARchiveDB',@c_country '@c_country', @c_SourceDB '@c_SourceDB'
   END
    

   DECLARE Cur_SPCode CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   --WL01
          SELECT DISTINCT C.Storerkey, C.Long,c.udf01,C.udf02,C.udf03,@c_Key1,CAST(short as int)
          FROM CODELKUP C WITH (NOLOCK)  
          WHERE C.listname = 'ITFRTriger'
          AND C.code = @c_tablename
          AND Code2 <> 'SP'
          AND C.storerkey = @c_Storerkey
          Order by CAST(short as int) 
   
    OPEN Cur_SPCode
   
    FETCH NEXT FROM Cur_SPCode INTO @c_StorerKey, @c_SPCode,@c_TableSchema,@c_GetTableName,@c_KeyColumn,@c_DocKey,@n_rowno

   BEGIN TRAN

    WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
    BEGIN

         IF @b_debug = '1'
         BEGIN
          SELECT @c_SPCode '@c_SPCode',@c_TableSchema '@c_TableSchema',@c_GetTableName '@c_GetTableName',@c_KeyColumn '@c_KeyColumn', @c_DocKey '@c_DocKey'
         END

         IF @c_GetTableName like 'TRANSMITLOG%' AND @c_KeyColumn = 'TRANSMITLOGKEY'   --For Transmitlog table
         BEGIN

          SET @c_Exists = '0'
            SET @c_SQL = ''
            SET @c_Transmitlogkey = ''
            SET @c_SQL = N'SELECT @c_Exists = ''1'' ' + CHAR(13) +
              'FROM ' +
                 QUOTENAME(@c_ARchiveDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_GetTableName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +
                 'WHERE key1 =  @c_DocKey '

                SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50) , @c_Exists NVARCHAR(1) OUTPUT'

              EXEC sp_executesql @c_SQL
                           , @c_ExecArguments
                           , @c_DocKey 
                           , @c_Exists OUTPUT

               IF @b_debug = '1'
               BEGIN
                SELECT @c_Exists '@c_Exists'
               END

               IF @c_Exists = '1' -- record found in Archive db
               BEGIN
                 SET @c_SQL = ''
                 SET @c_SQL = N'SELECT TOP 1  @c_Transmitlogkey = Transmitlogkey ' + CHAR(13) +
                 'FROM ' +
                   QUOTENAME(@c_ARchiveDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_GetTableName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +
                   'WHERE key1 =  @c_DocKey ' + CHAR(13) +
                   'And Tablename = @c_TableName ' + CHAR(13) +
                   ' ORDER BY 1 DESC'

                    SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50), @c_TableName NVARCHAR(30) , @c_Transmitlogkey NVARCHAR(10) OUTPUT'

                EXEC sp_executesql @c_SQL
                           , @c_ExecArguments
                           , @c_DocKey 
                           , @c_TableName 
                           , @c_Transmitlogkey OUTPUT

                           IF @b_debug = '1'
                           BEGIN
                               SELECT @c_SQL '@c_SQL'
                              SELECT @c_Transmitlogkey ' @c_Transmitlogkey'
                           END

                           IF ISNULL(@c_Transmitlogkey,'') <> ''
                           BEGIN

                             BEGIN TRAN
                             SET @c_DocKey = @c_Transmitlogkey

                              SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_ARchiveDB,@c_SourceDB,@c_TableSchema, @c_GetTableName,@c_KeyColumn,@c_DocKey'  
                                            + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
      
                                EXEC sp_executesql @c_SQL 
                                  , N'@c_ARchiveDB NVARCHAR(50),@c_SourceDB NVARCHAR(10),@c_TableSchema NVARCHAR(50),@c_GetTableName NVARCHAR(30),@c_KeyColumn NVARCHAR(50)
                                  , @c_DocKey NVARCHAR(50), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT' 
                                  , @c_ARchiveDB
                                  , @c_SourceDB
                                  , @c_TableSchema
                                  , @c_GetTableName
                                  , @c_KeyColumn
                                  , @c_DocKey
                                  , @b_Success         OUTPUT                       
                                  , @n_Err             OUTPUT  
                                  , @c_ErrMsg          OUTPUT

                                IF ISNULL(@n_Err,0) > 1
                                BEGIN
                                   SELECT @n_Continue = 3  
                                   SET @n_err = 700003
                                   SELECT @c_errmsg = @c_errmsg + '(isp_RetriggerInterfaceSO)'
                                   ROLLBACK TRAN
                                   GOTO QUIT_SP
                                END
                                ELSE
                                BEGIN

                                COMMIT TRAN

                                END

                           END
               END
         END

     ELSE
     BEGIN 
       BEGIN TRAN 
 
        SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_ARchiveDB,@c_SourceDB,@c_TableSchema, @c_GetTableName,@c_KeyColumn,@c_DocKey'  
                 + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
      
      EXEC sp_executesql @c_SQL 
         , N'@c_ARchiveDB NVARCHAR(50),@c_SourceDB NVARCHAR(10),@c_TableSchema NVARCHAR(50),@c_GetTableName NVARCHAR(30),@c_KeyColumn NVARCHAR(50)
         , @c_DocKey NVARCHAR(50), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT' 
         , @c_ARchiveDB
         , @c_SourceDB
         , @c_TableSchema
         , @c_GetTableName
         , @c_KeyColumn
         , @c_DocKey
         , @b_Success         OUTPUT                       
         , @n_Err             OUTPUT  
         , @c_ErrMsg          OUTPUT

        IF ISNULL(@n_Err,0) > 1
        BEGIN
           SELECT @n_Continue = 3  
           SET @n_err = 700002
           SELECT @c_errmsg = @c_errmsg + '(isp_RetriggerInterfaceMBOL)'
           ROLLBACK TRAN
           GOTO QUIT_SP
        END
        ELSE
        BEGIN
         COMMIT TRAN
        END
     END

    --WHILE @@TRANCOUNT > 0   
  --    BEGIN  
  --       COMMIT TRAN  
  --    END  

    FETCH NEXT FROM Cur_SPCode INTO @c_StorerKey, @c_SPCode,@c_TableSchema,@c_GetTableName,@c_KeyColumn,@c_DocKey,@n_rowno             
    END   
     CLOSE Cur_SPCode
     DEALLOCATE Cur_SPCode      

  QUIT_SP:

   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
   
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_RetriggerInterfaceMBOL'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      SET @n_err = 0
      SET @c_errmsg = ''
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
END -- procedure 

GO