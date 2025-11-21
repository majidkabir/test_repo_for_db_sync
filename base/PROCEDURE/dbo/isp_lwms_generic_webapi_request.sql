SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: isp_LWMS_Generic_WebAPI_Request                     */  
/* Creation Date: 27-JUL-2017                                           */  
/* Copyright: IDS                                                       */  
/* Written by: AlexKeoh                                                 */  
/*                                                                      */  
/* Purpose: Pass Incoming Request String For Interface                  */  
/*                                                                      */  
/* Input Parameters:  @b_Debug            - 0                           */  
/*                    @c_Format           - 'XML/JSON'                  */  
/*                    @c_UserID           - 'UserName'                  */  
/*                    @c_OperationType    - 'Operation'                 */  
/*                    @c_RequestString    - ''                          */  
/*                    @b_Debug            - 0                           */  
/*                                                                      */  
/* Output Parameters: @b_Success          - Success Flag  = 0           */  
/*                    @c_ErrNo            - Error No      = 0           */  
/*                    @c_ErrMsg           - Error Message = ''          */  
/*                    @c_ResponseString   - Error Message = ''          */  
/*                                                                      */  
/* Called By: LeafAPIServer - WMSAPI                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Purposes                                        */  
/* 2018-04-27  Alex01   [API]Add new flag to response original content  */  
/************************************************************************/  
CREATE  PROC [dbo].[isp_LWMS_Generic_WebAPI_Request](  
     @c_Format                VARCHAR(10)    = ''  
   , @c_UserID                NVARCHAR(256)  = ''  
   , @c_OperationType         NVARCHAR(60)   = ''  
   , @c_RequestString         NVARCHAR(MAX)  = ''  
   , @b_Debug                 INT            = 0  
   , @b_Success               INT            = 0   OUTPUT  
   , @n_ErrNo                 INT            = 0   OUTPUT  
   , @c_ErrMsg                NVARCHAR(250)  = ''  OUTPUT  
   , @c_ResponseString        NVARCHAR(MAX)  = ''  OUTPUT  
   , @b_RespOriContent        INT            = 0   OUTPUT --(Alex01)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue                    INT  
         , @n_StartCnt                    INT  
         , @c_WAPICONF_WSPostingSP01      NVARCHAR(100)  
         , @c_WAPICONF_SPTJSON            NVARCHAR(1)  
         , @c_WAPICONF_SPTXML             NVARCHAR(1)  
         , @c_WAPICONF_TargetDB           NVARCHAR(20)  
         , @c_WAPICONF_TargetSchema       NVARCHAR(10)  
         , @c_ExecStatements              NVARCHAR(MAX)  
         , @c_ExecArguments               NVARCHAR(2000)  
  
   SET @n_Continue                        = 1  
   SET @n_StartCnt                        = @@TRANCOUNT  
   SET @b_Success                         = 0  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''  
   SET @c_WAPICONF_WSPostingSP01          = ''  
   SET @c_WAPICONF_SPTJSON                = ''  
   SET @c_WAPICONF_SPTXML                 = ''  
   SET @c_WAPICONF_TargetDB               = ''  
   SET @c_WAPICONF_TargetSchema           = ''  
   SET @c_OperationType                   = ISNULL(RTRIM(LTRIM(@c_OperationType)), '')  
  
   IF @c_OperationType = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_ErrNo = 10000  
      --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_ErrNo,0)) +   
      --                ': Invalid operation type: ' + ISNULL(RTRIM(@c_OperationType), '')  
      SET @c_ErrMsg = 'Invalid operation type.'   
      GOTO QUIT  
   END  
  
   SELECT   
      @c_WAPICONF_WSPostingSP01 = ISNULL(RTRIM([WSPostingSP01]), '')  
     ,@c_WAPICONF_SPTJSON = ISNULL(RTRIM([SPTJSON]), 'N')  
     ,@c_WAPICONF_SPTXML = ISNULL(RTRIM([SPTXML]), 'N')  
     ,@c_WAPICONF_TargetDB = ISNULL(RTRIM([TargetDB]), '')   
     ,@c_WAPICONF_TargetSchema = ISNULL(RTRIM([TargetSchema]), '')  
     ,@b_RespOriContent = ISNULL([ResponseOriContent], 0)            --(Alex01)  
   FROM [dbo].[LWMS_WebApiConfig] WITH (NOLOCK)  
   WHERE [OperationType] = @c_OperationType  
  
   IF @b_Debug = 1  
 BEGIN  
      PRINT '[isp_LWMS_Generic_WebAPI_Request]: @c_WAPICONF_WSPostingSP01 = ' + @c_WAPICONF_WSPostingSP01 + CHAR(13) +  
            ', @c_WAPICONF_SPTJSON = ' + @c_WAPICONF_SPTJSON +  
      ', @c_WAPICONF_SPTXML = ' + @c_WAPICONF_SPTXML + CHAR(13) +  
            '@c_WAPICONF_TargetDB = ' + @c_WAPICONF_TargetDB + '@c_WAPICONF_TargetSchema = ' + @c_WAPICONF_TargetSchema  
   END  
  
   IF ISNULL(RTRIM(@c_WAPICONF_WSPostingSP01), '') = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_ErrNo = 10001  
      --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_ErrNo,0))   
      --              + ': WSPostingSP01 not setup: ' + ISNULL(RTRIM(@c_OperationType), '')  
      SET @c_ErrMsg = 'WSPostingSP01 not setup.'   
      GOTO QUIT  
   END  
  
   IF ISNULL(RTRIM(@c_WAPICONF_TargetDB), '') = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_ErrNo = 10002  
      --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_ErrNo,0))   
      --              + ': Target Database not setup: ' + ISNULL(RTRIM(@c_OperationType), '')  
      SET @c_ErrMsg = 'Target Database not setup.'  
      GOTO QUIT  
   END  
  
   IF ISNULL(RTRIM(@c_WAPICONF_TargetSchema), '') = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_ErrNo = 10003  
      --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_ErrNo,0))   
      --              + ': Target schema not setup: ' + ISNULL(RTRIM(@c_OperationType), '')  
      SET @c_ErrMsg = 'Target schema not setup.'  
      GOTO QUIT  
   END  
  
   IF @c_Format = 'JSON' AND @c_WAPICONF_SPTJSON <> 'Y'  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_ErrNo = 10004  
      --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_ErrNo,0))   
      --              + ': JSON format not support: ' + ISNULL(RTRIM(@c_OperationType), '')  
      SET @c_ErrMsg = 'JSON format not support.'  
      GOTO QUIT  
   END  
  
   IF @c_Format = 'XML' AND @c_WAPICONF_SPTXML <> 'Y'  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_ErrNo = 10005  
      --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_ErrNo,0))   
      --              + ': XML format not support: ' + ISNULL(RTRIM(@c_OperationType), '')  
      SET @c_ErrMsg = 'XML format not support.'  
      GOTO QUIT  
   END  
  
   IF @n_Continue = 1  
   BEGIN  
      SET @c_ExecStatements = N'EXEC ' + @c_WAPICONF_TargetDB + '.' + @c_WAPICONF_TargetSchema + '.' + @c_WAPICONF_WSPostingSP01  
                            + '  @c_Format         = @c_Format'  
                            + ', @c_UserID         = @c_UserID'  
                            + ', @c_OperationType  = @c_OperationType'  
                            + ', @c_RequestString  = @c_RequestString'  
                            + ', @b_Debug          = @b_Debug'  
                            + ', @b_Success        = @b_Success         OUTPUT'  
                            + ', @n_ErrNo          = @n_ErrNo      OUTPUT'  
                            + ', @c_ErrMsg         = @c_ErrMsg          OUTPUT'  
                            + ', @c_ResponseString = @c_ResponseString  OUTPUT'  
        
      SET @c_ExecArguments = N' @c_Format          VARCHAR(10)'  
                           + ', @c_UserID          NVARCHAR(256)'  
                           + ', @c_OperationType   NVARCHAR(60)'  
                           + ', @c_RequestString   NVARCHAR(MAX)'  
                           + ', @b_Debug           INT'  
                           + ', @b_Success         INT            OUTPUT'  
                           + ', @n_ErrNo           INT            OUTPUT'  
                           + ', @c_ErrMsg          NVARCHAR(250)  OUTPUT'  
         + ', @c_ResponseString  NVARCHAR(MAX)  OUTPUT'  
  
      BEGIN TRY  
   EXEC sp_ExecuteSql @c_ExecStatements  
                          , @c_ExecArguments  
                          , @c_Format  
                          , @c_UserID  
                          , @c_OperationType  
                          , @c_RequestString  
                          , @b_Debug  
          , @b_Success          OUTPUT  
          , @n_ErrNo            OUTPUT  
          , @c_ErrMsg           OUTPUT  
                          , @c_ResponseString   OUTPUT  
        
   IF @b_Debug = 1  
   BEGIN  
    PRINT '[isp_LWMS_Generic_WebAPI_Request]: @c_OperationType = ' + @c_OperationType  
             + ', @b_Success = ' + CAST(CAST(@b_Success AS INT)AS NVARCHAR) +  
     ', @n_Err = ' + CAST(CAST(@n_ErrNo AS INT)AS NVARCHAR) + ', @c_ErrMsg = ' + @c_ErrMsg  
   END  
  
         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue = 3  
            IF @n_ErrNo = 0  
            BEGIN  
               SET @n_ErrNo = 10006  
               --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_ErrNo,0))   
               --              + ': Fail to Execute SP = ' + @c_WAPICONF_WSPostingSP01 + '. (isp_LWMS_Generic_WebAPI_Request)'  
               SET @c_ErrMsg = 'Fail to Execute SP.'  
            END   
            GOTO QUIT  
         END --IF @@ERROR <> 0  
  
  END TRY  
  BEGIN CATCH  
         --Need to rollback the transaction in the SP before proceed to next setup  
         --As those error been catched here are the SQL exception error which do not handled the remaining transaction  
         WHILE @@TRANCOUNT > 0  
            ROLLBACK TRAN  
        
   SELECT @n_ErrNo = ERROR_NUMBER(), @c_ErrMsg = ERROR_MESSAGE(), @n_Continue = 3  
  
         IF @b_Debug = 1  
   BEGIN  
            PRINT '[isp_LWMS_Generic_WebAPI_Request]: @c_OperationType = ' + @c_OperationType  
                + ', @b_Success = ' + CAST(CAST(@b_Success AS INT)AS NVARCHAR) +  
        ', @n_Err = ' + CAST(CAST(@n_ErrNo AS INT)AS NVARCHAR) + ', @c_ErrMsg = ' + @c_ErrMsg  
         END  
  
         GOTO QUIT  
  END CATCH  
   END  
  
   QUIT:  
   WHILE @@TRANCOUNT < @n_StartCnt        
      BEGIN TRAN  
  
   IF @n_Continue= 3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_Success = 0        
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
      RETURN        
   END        
   ELSE        
   BEGIN        
      SELECT @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END  
  
END -- Procedure    

GO