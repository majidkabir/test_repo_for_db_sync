SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_CPC_UpdateCPCConfig                            */
/* Creation Date: 20-May-2023                                           */
/* Copyright: Maersk FbM WMS                                            */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose: Update CurrentVersion & IP on Cloud Print Client Start      */
/*                                                                      */
/* Input Parameters:  @b_Debug            - 0                           */
/*                    @c_Format           - 'XML/JSON'                  */
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
/* Called By: IntranetAPIServer - isp_Generic_WebAPI_Request            */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 20-May-2023  TKLim    1.0  Initial Development                       */
/* 14-Aug-2023  TKLim    1.0  Fix incorrect @b_Success status           */
/************************************************************************/
CREATE PROC [dbo].[isp_CPC_UpdateCPCConfig] (
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
         , @c_PrintClientID               NVARCHAR(100)  
         , @c_CurrVersion                 NVARCHAR(30)  
         , @c_LastRunIP                   NVARCHAR(50)  
         , @c_JSON                        NVARCHAR(MAX)  
   SET @n_Continue                        = 1  
   SET @n_StartCnt                        = @@TRANCOUNT  
   SET @b_Success                         = 1  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''  
   SET @c_PrintClientID                   = ''  
   SET @c_CurrVersion                     = ''  
   SET @c_LastRunIP                       = ''  
   SET @c_JSON                            = ''  
  --Validations
   IF ISNULL(RTRIM(@c_RequestString), '') = ''  
   BEGIN  
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98991  
      SET @c_ErrMsg = 'Content Body cannot be blank.'  
      GOTO QUIT  
   END
   IF ISNULL(RTRIM(UPPER(@c_Format)), '') <> 'JSON' 
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98992  
      SET @c_ErrMsg = 'Content body type must be JSON'  
      GOTO QUIT  
   END
   IF ISJSON(@c_RequestString) = 0
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98993  
      SET @c_ErrMsg = 'Content body is not valid JSON'  
      GOTO QUIT  
   END
   --Get PrintClientID from Request String JSON
   SELECT @c_PrintClientID = ISNULL(RTRIM(PrintClientID),'')
        , @c_CurrVersion   = ISNULL(RTRIM(CurrVersion),'')
        , @c_LastRunIP     = ISNULL(RTRIM(LastRunIP  ),'')
   FROM OPENJSON (@c_RequestString)  
   WITH (   
         PrintClientID  NVARCHAR(100)  '$.Request.PrintClientID',
         CurrVersion    NVARCHAR(30)   '$.Request.CurrVersion',
         LastRunIP      NVARCHAR(50)   '$.Request.LastRunIP'
   )
   IF @c_PrintClientID = ''
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98994  
      SET @c_ErrMsg = 'Invalid PrintClientID'  
      GOTO QUIT  
   END
   IF @c_CurrVersion = ''
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98995  
      SET @c_ErrMsg = 'Invalid CurrVersion'  
      GOTO QUIT  
   END
   IF @c_LastRunIP = ''
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98996  
      SET @c_ErrMsg = 'Invalid LastRunIP'  
      GOTO QUIT  
   END
   /*******************************************
   * Update Config Table
   *******************************************/
   UPDATE CloudPrintConfig WITH (ROWLOCK)
   SET CurrVersion = @c_CurrVersion
     , LastRunIP = @c_LastRunIP
     , LastRunDate = GETDATE()
     , LastSeenDate = GETDATE()
   WHERE PrintClientID = @c_PrintClientID
   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98996
      SET @c_ErrMsg = 'Failed to Update CloudPrintConfig!'
      GOTO QUIT  
   END
   QUIT:
   SET @c_ResponseString = '{"Success":"' + CONVERT(NVARCHAR(10),@b_Success) + '", "ErrNo":"' + CONVERT(NVARCHAR(10),@n_ErrNo)  + '", "ErrMsg":"' + @c_ErrMsg + '"}'
END -- procedure

GO