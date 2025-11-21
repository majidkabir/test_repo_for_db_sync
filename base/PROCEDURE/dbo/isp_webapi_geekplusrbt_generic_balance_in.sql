SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: isp_WebAPI_GEEKPLUSRBT_GENERIC_BALANCE_IN           */              
/* Creation Date: 09-JUN-2020                                           */
/* Copyright: IDS                                                       */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose: Pass Incoming Request String For Interface                  */
/*                                                                      */
/* Input Parameters:  @b_Debug            - 0                           */
/*                    @c_Format           - 'JSON'                      */
/*                    @c_UserID           - 'UserName'                  */
/*                    @c_OperationType    - 'Operation'                 */
/*                    @c_RequestString    - ''                          */
/*                    @b_Debug            - 0                           */
/*                                                                      */
/* Output Parameters: @b_Success          - Success Flag    = 0         */
/*                    @c_ErrNo            - Error No        = 0         */
/*                    @c_ErrMsg           - Error Message   = ''        */
/*                    @c_ResponseString   - ResponseString  = ''        */
/*                                                                      */
/* Called By: LeafAPIServer - isp_Generic_WebAPI_Request                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes														*/
/* 2020-06-09  Alex     Initial - Jira Ticket #WMS-13311                */
/************************************************************************/    
CREATE PROC [dbo].[isp_WebAPI_GEEKPLUSRBT_GENERIC_BALANCE_IN](
     @b_Debug           INT            = 0
   , @c_Format          VARCHAR(10)    = ''
   , @c_UserID          NVARCHAR(256)  = ''
   , @c_OperationType   NVARCHAR(60)   = ''
   , @c_RequestString   NVARCHAR(MAX)  = ''
   , @b_Success         INT            = 0   OUTPUT
   , @n_ErrNo           INT            = 0   OUTPUT
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT
         , @n_StartCnt                    INT
         , @c_ExecStatements              NVARCHAR(MAX)
         , @c_ExecArguments               NVARCHAR(2000)

         , @c_Application                 NVARCHAR(50)
         , @c_MessageType                 NVARCHAR(10)

         , @c_Facility                    NVARCHAR(5)
         , @c_StorerKey                   NVARCHAR(15)

         , @c_WarehouseCode               NVARCHAR(16)
         , @c_OwnerCode                   NVARCHAR(32)

         , @n_IsExists                    INT

         , @c_ReservedSQLQuery1             NVARCHAR(MAX)
         , @c_SQLQuery                    NVARCHAR(MAX)
         , @c_SQLParams                   NVARCHAR(2000)

         , @c_TargetDB                    NVARCHAR(30)

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT
   SET @b_Success                         = 1
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   
   SET @c_Application                     = 'GEEK+_BALANCE_IN'
   SET @c_MessageType                     = 'WS_IN'

   SET @n_IsExists                        = 0
   SET @c_WarehouseCode                   = ''
   SET @c_OwnerCode                       = ''

   SET @c_ReservedSQLQuery1                 = ''
   SET @c_SQLQuery                        = ''
   SET @c_SQLParams                       = ''

   IF OBJECT_ID('tempdb..#TEMP_RBT_BALANCE_IN') IS NOT NULL
   DROP TABLE #TEMP_RBT_BALANCE_IN

   CREATE TABLE #TEMP_RBT_BALANCE_IN (
      warehouse_code       NVARCHAR(16)   NULL,
      owner_code           NVARCHAR(32)   NULL
   )

   IF NOT ISJSON(@c_RequestString) > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo = 217200
      SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - invalid JSON request..'
      GOTO QUIT
   END   
   
   INSERT INTO #TEMP_RBT_BALANCE_IN ( warehouse_code, owner_code )
   SELECT
      ISNULL(RTRIM(sku_list.warehouse_code), ''),
      ISNULL(RTRIM(sku_list.owner_code), '')
   FROM OPENJSON(@c_RequestString, '$.body.sku_list')  
   WITH (  
      warehouse_code       NVARCHAR(16)   '$.warehouse_code',
      owner_code           NVARCHAR(32)   '$.owner_code'
   ) As sku_list  

   SET @n_IsExists = 0
   SET @c_WarehouseCode = ''

   SELECT @n_IsExists = 1
         ,@c_WarehouseCode = warehouse_code
   FROM #TEMP_RBT_BALANCE_IN T
   WHERE 
      NOT EXISTS ( 
         SELECT 1 FROM dbo.Codelkup WITH (NOLOCK)
         WHERE ListName = 'ROBOTFAC' 
         AND [Short] = T.warehouse_code )

   IF @n_IsExists = 1 
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo = 217201
      SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - warehousecode(' + @c_WarehouseCode + ') is not setup..'
      GOTO QUIT
   END

   SET @n_IsExists = 0
   SET @c_OwnerCode = ''

   SELECT @n_IsExists = 1
         ,@c_OwnerCode = owner_code
   FROM #TEMP_RBT_BALANCE_IN T
   WHERE 
      NOT EXISTS ( 
         SELECT 1 FROM dbo.Codelkup WITH (NOLOCK)
         WHERE ListName = 'ROBOTSTR' 
         AND [Short] = T.owner_code )

   IF @n_IsExists = 1 
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo = 217201
      SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - ownercode(' + @c_OwnerCode + ') is not setup..'
      GOTO QUIT
   END

   SELECT @c_StorerKey = [StorerKey] 
   FROM dbo.Codelkup CDLKUP WITH (NOLOCK) 
   WHERE ListName = 'ROBOTSTR' 
   AND EXISTS ( SELECT 1 
      FROM #TEMP_RBT_BALANCE_IN 
      WHERE owner_code = CDLKUP.[Short] )

   SET @n_IsExists = 0

   SELECT @n_IsExists = (1)
         ,@c_ReservedSQLQuery1 = ISNULL(RTRIM(ReservedSQLQuery1), '')
   FROM [dbo].[GEEKPBOT_INTEG_CONFIG] WITH (NOLOCK)
   WHERE InterfaceName = 'BALANCE_INBOUND' 
   AND StorerKey = @c_StorerKey

   IF @n_IsExists = 0 OR @c_ReservedSQLQuery1 = ''
   BEGIN
       SET @n_Continue = 3
       SET @n_ErrNo = 217202
       SET @c_ErrMsg = 'NSQL' 
                     + CONVERT(NVARCHAR(6),@n_ErrNo) 
                     + ': [dbo].[GEEKPBOT_INTEG_CONFIG](InterfaceName=BALANCE_INBOUND, StorerKey='
                     + @c_StorerKey + ') is not setup.(isp_WebAPI_GEEKPLUSRBT_GENERIC_BALANCE_IN)'
       GOTO QUIT
   END

   --GET DTSITF DBName
   SET @n_IsExists = 0

   SELECT @n_IsExists = (1)
         ,@c_TargetDB = ISNULL(RTRIM(UDF01), '')
   FROM dbo.Codelkup WITH (NOLOCK)
   WHERE ListName = 'GEEK+ALERT'
   AND StorerKey = @c_StorerKey

   IF @n_IsExists = 0 OR @c_TargetDB = ''
   BEGIN
       SET @n_Continue = 3
       SET @n_ErrNo = 217203
       SET @c_ErrMsg = 'NSQL' 
                     + CONVERT(NVARCHAR(6),@n_ErrNo) 
                     + ': Codelkup(Listname=Geek+Alert,StorerKey='+ @c_StorerKey + ') is not setup.(isp_WebAPI_GEEKPLUSRBT_GENERIC_BALANCE_IN)'
       GOTO QUIT
   END

   BEGIN TRY
      --Replace {DTSITF}
      SET @c_SQLQuery = REPLACE(@c_ReservedSQLQuery1, '{DTSITF}', @c_TargetDB)
      SET @c_SQLParams = '@c_RequestString NVARCHAR(MAX)'

      IF @b_Debug = 1
      BEGIN
         PRINT '>==================================================>'
         PRINT '>>>> Full ReservedSQLQuery1 (BEGIN)'
         PRINT @c_SQLQuery
         PRINT '>>>> Full ReservedSQLQuery1 (END)'
         PRINT '>==================================================>'
      END
   
      EXEC sp_ExecuteSql @c_SQLQuery, @c_SQLParams, @c_RequestString
   
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @n_ErrNo = 217204
   	SET @c_ErrMsg = CONVERT(NVARCHAR(6),@n_ErrNo) + ' - ReservedSQLQuery1 Error - ' + ERROR_MESSAGE()
   
      IF @b_Debug = 1
      BEGIN
         PRINT '>>> GEN REQUEST QUERY CATCH EXCEPTION - ' + @c_ErrMsg
      END
   END CATCH

   QUIT:
   IF @n_Continue = 3 AND @n_ErrNo <> 0
   BEGIN    
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1 
      BEGIN               
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END   
   END      
   ELSE      
   BEGIN         
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
   END

   SET @c_ResponseString = ISNULL(RTRIM(
      (
         SELECT 
            CASE WHEN @n_ErrNo > 0 THEN '400' ELSE '200' END As 'header.msgCode'
          , CASE WHEN @n_ErrNo > 0 THEN 'Error : ' + @c_ErrMsg 
               ELSE N'Process with Success' END As 'header.message'
          , CONVERT(BIT, CASE WHEN @n_ErrNo > 0 THEN 0 ELSE 1 END) As 'body.success'
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      )
   ), '')

   --Insert log to TCPSocket_INLog
   INSERT INTO dbo.TCPSOCKET_INLOG ( [Application], MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
   VALUES ( @c_Application, @c_MessageType, @c_MessageType, @c_RequestString, '', @c_StorerKey, @c_ResponseString, '9' )

   --Build Custom Response
   SELECT @n_ErrNo = 0, @b_Success = 1, @c_ErrMsg = ''
   RETURN
END -- Procedure  

GO