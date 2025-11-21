SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Store Procedure:  isp_RetriggerInterface                             */        
/* Creation Date: 10-MAR-2021                                           */        
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
/* 27-JAN-2022  CSCHONG   1.0    Devops Scripts Combine                 */   
/* 21-JUL-2021  CSCHONG   1.1    WMS-10009 add in key3 parameter (CS01) */     
/************************************************************************/        
        
CREATE PROC  [dbo].[isp_RetriggerInterface]      
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
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF         
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @n_continue        int         
   , @c_SPCode          NVARCHAR(50)        
   , @c_SQL             NVARCHAR(MAX)        
   , @c_Type            NVARCHAR(20)  
   , @c_Country         NVARCHAR(10)        
   -- , @c_SourceDB        NVARCHAR(10)        
   , @c_TableSchema     NVARCHAR(50)         
   , @c_TLName    NVARCHAR(50)        
   , @c_KeyColumn       NVARCHAR(50)        
   , @c_DocKey          NVARCHAR(50)        
   , @n_StartTCnt       INT          
   , @n_rowno          INT        
   , @c_ColName        NVARCHAR(MAX)        
   , @c_Exists         NVARCHAR(1)        
   , @c_RecFound       NVARCHAR(1)        
   , @c_ExecArguments  NVARCHAR(MAX)        
   , @c_Transmitlogkey NVARCHAR(10)      
   , @c_TransTBL       NVARCHAR(50)    
   , @c_TransDocKey    NVARCHAR(50)    
   , @c_MainTBL        NVARCHAR(50)     
   , @c_MainTBLDocKEY  NVARCHAR(50)
   , @c_GetStorerkey   NVARCHAR(20)          --CS01 
    
        
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT           
        
   SET @c_SPCode = ''        
   SET @c_ARchiveDB = ''        
   SET @c_Country = ''        
   SET @c_SourceDB = ''       
   SET @c_TransTBL = ''    
   SET @c_MainTBL = ''    
   SET @c_MainTBLDocKEY = ''    
        
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
        
   --SET @c_SourceDB = @c_country + 'WMS'        
     SET @c_SourceDB = DB_NAME()      
        
   if @b_debug = '1'        
   BEGIN        
     SELECT @c_ARchiveDB '@c_ARchiveDB',@c_country '@c_country'        
   END        
  
--Move other table      
   DECLARE Cur_SPCode CURSOR LOCAL FAST_FORWARD READ_ONLY FOR         
   SELECT DISTINCT c.udf01, C.udf02, C.udf03, C.udf04, @c_Key1, Code2,@c_Key3              --CS01
          FROM CODELKUP C WITH (NOLOCK)          
          WHERE C.listname = 'ITFRTriger'        
    AND C.code = @c_tablename        
    AND C.Storerkey=''       
           
    OPEN Cur_SPCode        
         
  FETCH NEXT FROM Cur_SPCode INTO @c_SPCode, @c_TLName, @c_TransDocKey, @c_TableSchema,@c_DocKey,@c_Type,@c_GetStorerkey    --CS01   
        
 --  BEGIN TRAN        
        
  WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)        
  BEGIN        
        
     IF @b_debug = '1'        
     BEGIN        
        SELECT @c_Type '@c_Type', @c_SPCode '@c_SPCode',@c_TableSchema '@c_TableSchema',@c_TLName '@c_TLName',@c_DocKey '@c_DocKey'  , @c_GetStorerkey '@c_GetStorerkey',@c_TableName  '@c_TableName '
     END        
       
     BEGIN TRAN     
       
     -- Move Transmitlog (Start)  
     SET @c_Exists = '0'        
     SET @c_SQL = ''        
     SET @c_Transmitlogkey = ''        
     SET @c_SQL = N'SELECT @c_Exists = ''1'' ' + CHAR(13) +        
              'FROM ' +        
              QUOTENAME(@c_ARchiveDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TLName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +        
              'WHERE key1 =  @c_DocKey AND key3 = @c_GetStorerkey '           --CS01
       
     SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50) ,@c_GetStorerkey NVARCHAR(20), @c_Exists NVARCHAR(1) OUTPUT'        
       
     EXEC sp_executesql @c_SQL        
         , @c_ExecArguments        
         , @c_DocKey    
         , @c_GetStorerkey     
         , @c_Exists OUTPUT        
       
     IF @b_debug = '1'        
     BEGIN        
        SELECT @c_Exists '@c_Exists'        
     END        
        
     IF ISNULL(@c_TransDocKey, '') = ''  
        SET @c_TransDocKey = 'TransmitlogKey'    
  
     IF @c_Exists = '1' -- record found in Archive db        
     BEGIN        
        SET @c_SQL = ''        
        SET @c_SQL = N'SELECT TOP 1  @c_Transmitlogkey = ' + @c_TransDocKey + CHAR(13) +        
                   'FROM ' +        
                   QUOTENAME(@c_ARchiveDB, '[') + '.' + QUOTENAME(@c_TableSchema, '[') + '.' + QUOTENAME(@c_TLName, '[') + ' WITH (NOLOCK) ' + CHAR(13) +        
                   'WHERE key1 =  @c_DocKey AND key3 = @c_GetStorerkey ' + CHAR(13) +            --CS01
                   'And Tablename = @c_TableName ' + CHAR(13) +        
                   ' ORDER BY 1 DESC'        
       
        SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50), @c_GetStorerkey NVARCHAR(20),@c_TableName NVARCHAR(30) , @c_Transmitlogkey NVARCHAR(10) OUTPUT'  --CS01      
       
        EXEC sp_executesql @c_SQL        
            , @c_ExecArguments        
            , @c_DocKey    
            , @c_GetStorerkey              --CS01      
            , @c_TableName  
            , @c_Transmitlogkey OUTPUT        
       
         IF @b_debug = '1'        
         BEGIN        
            SELECT @c_SQL '@c_SQL'        
            SELECT @c_Transmitlogkey ' @c_Transmitlogkey'        
         END        
       
         IF ISNULL(@c_Transmitlogkey,'') <> ''        
         BEGIN  --(@c_Transmitlogkey,'') <> ''             
            BEGIN TRAN        
            EXEC isp_ReTriggerTransmitLog_MoveData @c_ARchiveDB, @c_SourceDB, 'dbo', @c_TLName, @c_TransDocKey, @c_Transmitlogkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
       
            IF ISNULL(@n_Err,0) > 1        
            BEGIN        
               SELECT @n_Continue = 3          
               SET @n_err = 700003        
               --SET @c_errmsg = 'Error move transmitlog table. '    
               SELECT @c_errmsg = @c_errmsg + '(isp_RetriggerInterface)'        
               ROLLBACK TRAN        
               GOTO QUIT_SP        
            END        
            ELSE        
            BEGIN        
               COMMIT TRAN        
            END          
         END    --(@c_Transmitlogkey,'') <> ''         
      END      --@c_Exists    
      -- Move Transmitlog (End)  
          
  
      -- Move tables based on predefined set (Start)  
      IF @b_debug = 1
      BEGIN
          SELECT 'MOTHTBL', @c_SPCode '@c_SPCode'
      END
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_ARchiveDB,@c_SourceDB,@c_TableSchema, @c_TLName,@c_KeyColumn,@c_DocKey, @c_Key3'          
              + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '        
           
      EXEC sp_executesql @c_SQL         
      , N'@c_ARchiveDB NVARCHAR(50),@c_SourceDB NVARCHAR(10),@c_TableSchema NVARCHAR(50),@c_TLName NVARCHAR(30),@c_KeyColumn NVARCHAR(50)        
      , @c_DocKey NVARCHAR(50), @c_Key3 NVARCHAR(20), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'      --CS01     
      , @c_ARchiveDB        
      , @c_SourceDB        
      , @c_TableSchema        
      , @c_TLName        
      , @c_KeyColumn        
      , @c_DocKey 
      , @c_Key3                                --CS01
      , @b_Success         OUTPUT                               
      , @n_Err             OUTPUT          
      , @c_ErrMsg          OUTPUT        
     -- Move tables based on predefined set (End)  
  
     IF ISNULL(@n_Err,0) > 1        
     BEGIN        
        SELECT @n_Continue = 3          
        SET @n_err = 700002        
        SELECT @c_errmsg = @c_errmsg + '(isp_RetriggerInterface)'        
        ROLLBACK TRAN        
        GOTO QUIT_SP        
     END        
     ELSE        
     BEGIN        
        COMMIT TRAN        
     END        
           
     FETCH NEXT FROM Cur_SPCode INTO @c_SPCode, @c_TLName, @c_TransDocKey, @c_TableSchema,@c_DocKey,@c_Type,@c_GetStorerkey        --CS01
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_RetriggerInterface'        
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