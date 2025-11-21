SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_CldPrt_Generic_SendRequest                      */  
/* Creation Date: 2023-04-10                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose:                                                              */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date       Author   Ver   Purposes                                    */ 
/* 2023-04-10 Wan      1.0   Created & DevOps Combine Script             */
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[isp_CldPrt_Generic_SendRequest] 
   @c_DataProcess    NVARCHAR(10)    
,  @c_StorerKey      NVARCHAR(30)
,  @c_Facility       NVARCHAR(5)  = ''
,  @b_debug          INT          = 0 
,  @n_JobID          INT          
,  @b_Success        INT          = 1  OUTPUT  
,  @n_Err            INT          = 0  OUTPUT  
,  @c_ErrMsg         NVARCHAR(255)= '' OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
           @n_StartTCnt                   INT            = @@TRANCOUNT
         , @n_Continue                    INT            = 1
     
         , @n_ActiveFlag                  INT            = 0
         , @n_WebRequestTimeout           INT            = 12000   
                                                 
         , @c_CmdType                     NVARCHAR(10)   = ''
         , @c_PostingSP                   NVARCHAR(1000) = ''  
         , @c_PostingSPName               NVARCHAR(200)  = '' 
         , @c_ReqBodyEncodeFormat         NVARCHAR(30)   = ''
         , @c_RespBodyDecodeFormat        NVARCHAR(30)   = ''
         , @c_ReqBodyEncodeDataOnly       NVARCHAR(20)   = ''
         , @c_RespBodyDecodeDataOnly      NVARCHAR(20)   = ''
    
         , @c_Data_Base64                 NVARCHAR(MAX)  = '' 
         , @c_RequestString               NVARCHAR(MAX)  = '' 
         , @c_ResponseString              NVARCHAR(MAX)  = ''  
         , @c_WebRequestURL               NVARCHAR(500)  = ''  
         , @c_WebRequestMethod            NVARCHAR(10)   = 'POST'  
         , @c_WebRequestContentType       NVARCHAR(100)  = 'application/json'  
         , @c_WebRequestEncoding          NVARCHAR(30)   = 'UTF-8'
         , @c_WebRequestHeaders           NVARCHAR(500)  = ''
         , @c_NetworkCredentialUserName   NVARCHAR(100)  = '' 
         , @c_NetworkCredentialPassword   NVARCHAR(100)  = ''
         , @c_EPServerType                NVARCHAR(100)  = ''
           
         , @c_vbErrMsg                    NVARCHAR(MAX)  = ''   
         , @c_vbHttpStatusCode            NVARCHAR(20)   = ''   
         , @c_vbHttpStatusDesc            NVARCHAR(1000) = '' 
         
         , @c_PrintBy                     NVARCHAR(128)  = ''
           
   SET @b_Success = 1   
   SET @n_Err     = 0   
   SET @c_ErrMsg  = ''  
     
   SELECT @c_RequestString = rpj.PrintData 
         ,@c_PrintBy       = rpj.AddWho 
   FROM rdt.RDTPrintJob AS rpj WITH (NOLOCK)  
   WHERE rpj.JobID = @n_JobID 
   
   IF @@ROWCOUNT = 0  
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 90100
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': JobID Not Found.'
                    + ' (isp_CldPrt_Generic_SendRequest)'
      GOTO QUIT_SP
   END
   
   IF @c_Facility = ''
   BEGIN
      SELECT @c_Facility = ru.DefaultFacility
      FROM rdt.RDTUser AS ru WITH (NOLOCK)
      WHERE ru.UserName = @c_PrintBy
   END
      
   IF @c_Facility = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 90120
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Facility is required.'
                    + ' (isp_CldPrt_Generic_SendRequest)'
      GOTO QUIT_SP              
   END 
        
   IF NOT EXISTS (SELECT 1 
                  FROM dbo.QCmd_TransmitlogConfig AS qctc WITH (NOLOCK)  
                  WHERE qctc.DataStream = @c_DataProcess 
                  AND qctc.Storerkey IN ( @c_Storerkey, 'ALL' ) 
                  AND qctc.Facility  IN ( @c_Facility, 'ALL', '' )
                  AND qctc.CmdType = 'WSC'
                  ) 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 90130
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Not A Web Service data process.'
                    + ' (isp_CldPrt_Generic_SendRequest)'
      GOTO QUIT_SP
   END
       
   SELECT   @c_WebRequestURL         = wsc.WebRequestURL
         ,  @c_WebRequestContentType = wsc.WebRequestContentType 
         ,  @c_WebRequestMethod      = wsc.WebRequestMethod  
         ,  @c_WebRequestEncoding    = wsc.WebRequestEncoding  
         ,  @n_WebRequestTimeout     = wsc.WebRequestTimeout  
         ,  @c_ReqBodyEncodeFormat   = wsc.ReqBodyEncodeFormat 
         ,  @c_RespBodyDecodeFormat  = wsc.RespBodyDecodeFormat  
         ,  @c_ReqBodyEncodeDataOnly = wsc.ReqBodyEncodeDataOnly  
         ,  @c_RespBodyDecodeDataOnly= wsc.RespBodyDecodeDataOnly
         ,  @c_PostingSPName         = wsc.PostingSPName  
         ,  @n_ActiveFlag            = wsc.ActiveFlag 
         ,  @c_NetworkCredentialUserName = wsc.NetworkCredentialUserName
         ,  @c_NetworkCredentialPassword = wsc.NetworkCredentialPassword    
   FROM WebServiceCfg wsc WITH (NOLOCK)  
   WHERE wsc.DataProcess = @c_DataProcess 
     
   IF @@ROWCOUNT = 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 90140
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Web Service Configuration has not setup.'
                    + ' (isp_CldPrt_Generic_SendRequest)'
      GOTO QUIT_SP
   END
     
   IF @n_ActiveFlag = 0 
   BEGIN  
      SET @n_Continue = 3
      SET @n_Err = 90150
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Inactive Web Service.'
                    + ' (isp_CldPrt_Generic_SendRequest)'
      GOTO QUIT_SP                    
   END
     
   IF @c_PostingSPName = ''   
   BEGIN  
      SET @n_Continue = 3
      SET @n_Err = 90160
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Posting Stored Proceudure is required.'
                    + ' (isp_CldPrt_Generic_SendRequest)'
      GOTO QUIT_SP  
   END 
   
   SET @c_PostingSP  = 'EXEC ' + @c_PostingSPName 
                     +  ' @c_DataProcess = ''' + @c_DataProcess + ''' '  
                     + ', @c_Storerkey = ''' + @c_StorerKey + ''' '
                     + ', @n_JobID = ' + CONVERT(NVARCHAR(10),@n_JobID)  
                     + ', @c_BatchNo = ''<BatchNo>'''   
                     + ', @c_ProcessType = ''APG'' '  
                     + ', @c_ResponseString = N''<RespondMsg>'' '  
                     + ', @c_ResponseHeader = N''<ResponseHeader>'' ' 
                     + ', @c_HttpStatusCode = ''<HttpStatusCode>'' '  
                     + ', @c_VBErrMsg = N''<VBErrMsg>'' '  
                     + ', @c_ExecSP4Dur = ''<ExecSP4Dur>'''     
                     + ', @c_APGProcDur = ''<APGProcDur>'''     
                     + ', @c_EPProcDur = ''<EPProcDur>'''       
                     + ', @b_debug = 0'  
                     + ', @b_Success = 0, @n_Err = 0, @c_ErrMsg = '''' '  

   SELECT   
        @c_WebRequestURL                [WebRequestURL]  
      , @c_WebRequestMethod             [WebRequestMethod]  
      , @c_WebRequestContentType        [WebRequestContentType]  
      , @c_WebRequestEncoding           [WebRequestEncoding]  
      , @c_RequestString                [RequestString]   
      , @n_WebRequestTimeout            [WebRequestTimeout]  
      , @c_NetworkCredentialUserName    [NetworkCredentialUserName]  
      , @c_NetworkCredentialPassword    [NetworkCredentialPassword]  
      , 0                               [IsSoapRequest]  
      , ''                              [RequestHeaderSoapAction]  
      , ''                              [HeaderAuthorization]  
      , '1'                             [ProxyByPass]  
      , @c_WebRequestHeaders            [WebRequestHeaders]  
      , @c_PostingSP                    [PostingSP]  
      , @c_EPServerType                 [EPServerType]  
      , ''                              [WSDTKey]  
      , @n_JobID                        [SeqNo]  
      , @c_DataProcess                  [Datastream]  
      , @c_ReqBodyEncodeFormat          [ReqBodyEncodeFormat]  
      , @c_RespBodyDecodeFormat         [RespBodyDecodeFormat]  
      , @c_ReqBodyEncodeDataOnly        [ReqBodyEncodeDataOnly]  
      , @c_RespBodyDecodeDataOnly       [RespBodyDecodeDataOnly]  
      , ''                              [FormDatas] 
      , ''                              [FileUploadKeyAndSourcePath]  
      , ''                              [FileUploadKeyAndContent]  
      , ''                              [ClientCertPath]  
      , ''                              [ClientCertPassword]  

   QUIT_SP:  
   IF @n_Continue = 3
   BEGIN
      EXEC [dbo].[isp_UpdateRDTPrintJobStatus]
         @n_JobID     = @n_JobID    
      ,  @c_JobStatus = '5'
      ,  @c_JobErrMsg = @c_ErrMsg
      ,  @b_Success   = @b_Success    OUTPUT
      ,  @n_Err       = @n_Err        OUTPUT
      ,  @c_ErrMsg    = @c_ErrMsg     OUTPUT
      ,  @c_PrintData = ''  
   END
      
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, '[isp_CldPrt_Generic_SendRequest]'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

END

GO