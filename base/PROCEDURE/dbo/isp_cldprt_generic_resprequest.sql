SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_CldPrt_Generic_RespRequest                      */  
/* Creation Date: 2023-04-10                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose:                                                              */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date       Author   Ver   Purposes                                    */ 
/* 2023-04-10 Wan      1.0   Created & DevOps Combine Script             */
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[isp_CldPrt_Generic_RespRequest] 
   @c_DataProcess       NVARCHAR(10)    
,  @c_Storerkey         NVARCHAR(15)   = ''
,  @n_JobID             INT    
,  @c_BatchNo           NVARCHAR(50)     
,  @c_ProcessType       NVARCHAR(20)    
,  @c_ResponseString    NVARCHAR(MAX)  
,  @c_ResponseHeader    NVARCHAR(4000) = ''  
,  @c_HttpStatusCode    NVARCHAR(10)   = ''  
,  @c_VBErrMsg          NVARCHAR(500)  = ''  
,  @c_ExecSP4Dur        NVARCHAR(20)   = '0'  
,  @c_APGProcDur        NVARCHAR(20)   = '0'  
,  @c_EPProcDur         NVARCHAR(20)   = '0'  
,  @b_debug             INT            = 0
,  @b_Success           INT            = 0      OUTPUT    
,  @n_Err               INT            = ''     OUTPUT    
,  @c_ErrMsg            NVARCHAR(250)  = NULL   OUTPUT    
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
           @n_StartTCnt                   INT            = @@TRANCOUNT
         , @n_Continue                    INT            = 1
     
         --, @n_ExecSP4Dur                  INT            = 0
         --, @n_APGProcDur                  INT            = 0
         --, @n_EPProcDur                   INT            = 0
         
         , @c_G_ErrCode                   NVARCHAR(10)   = ''
         
         , @n_ActiveFlag                  INT            = 0
         , @n_WebRequestTimeout           INT            = 12000   
                                                 
         , @c_ReqBodyEncodeFormat         NVARCHAR(30)   = ''
         , @c_RespBodyDecodeFormat        NVARCHAR(30)   = ''
         , @c_ReqBodyEncodeDataOnly       NVARCHAR(20)   = ''
         , @c_RespBodyDecodeDataOnly      NVARCHAR(20)   = ''
    
         , @c_Data                        NVARCHAR(MAX)  = '' 
         , @c_RequestString               NVARCHAR(MAX)  = '' 

         , @c_WebRequestURL               NVARCHAR(500)  = ''  
         , @c_WebRequestMethod            NVARCHAR(10)   = 'POST'  
         , @c_WebRequestContentType       NVARCHAR(100)  = 'application/json'  
         , @c_WebRequestEncoding          NVARCHAR(30)   = 'UTF-8'
         , @c_WebRequestHeaders           NVARCHAR(500)  = ''
         , @c_IniFilePath                 NVARCHAR(225)  = '' 
         , @c_NetworkCredentialUserName   NVARCHAR(100)  = '' 
         , @c_NetworkCredentialPassword   NVARCHAR(100)  = ''
         , @c_EPServerType                NVARCHAR(100)  = ''
            
         , @c_vbHttpStatusCode            NVARCHAR(20)   = ''   
         , @c_vbHttpStatusDesc            NVARCHAR(1000) = '' 
         
         --, @c_ReqeustID                   NVARCHAR(30)   = ''  
         --, @c_Version                     NVARCHAR(10)   = ''
         , @c_JobStatus                   NVARCHAR(10)   = '9'
           
   SET @b_Success = 1   
   SET @n_Err     = 0   
   SET @c_ErrMsg  = '' 

    
   --SET @c_BatchNo   = IIF(@c_BatchNo='<BatchNo>','',@c_BatchNo)
   --SET @n_ExecSP4Dur= IIF(ISNUMERIC(@c_ExecSP4Dur)=1,@c_ExecSP4Dur,0)
   --SET @n_APGProcDur= IIF(ISNUMERIC(@c_APGProcDur)=1,@c_APGProcDur,0)  
   --SET @n_EPProcDur = IIF(ISNUMERIC(@c_EPProcDur) =1,@c_EPProcDur,0)  
   
   SET @c_G_ErrCode = ''
   IF ISNUMERIC(@c_HttpStatusCode) = '1' AND @c_HttpStatusCode > '300'
   BEGIN
      SET @c_G_ErrCode = CASE WHEN @c_HttpStatusCode IN ('503')   
                              THEN 'G01'  
                              WHEN @c_HttpStatusCode IN ('404')   
                              THEN 'G02'  
                              WHEN @c_HttpStatusCode IN ('504')   
                              THEN 'G03'  
                              WHEN @c_HttpStatusCode IN ('400','401','403','413','500','502')   
                              THEN 'G04'  
                              ELSE 'G99'  
                              END  
   END                         
                        
   IF @c_HttpStatusCode <> '' AND @c_HttpStatusCode > '300'  
   BEGIN  
      SET @n_Continue = 3
      SET @n_Err = 90210    
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))     
                     + ': ' + RTRIM(LTRIM(@c_ResponseString)) + '. (isp_CldPrt_Generic_RespRequest)'  
                           
      SET @c_ResponseString = '<?xml version="1.0" encoding="UTF-8" ?>'  
                              + '<ExceptionError>'  
                              + '<Reason>' + @c_G_ErrCode + '</Reason>'     
                              + '<Description>' + @c_HttpStatusCode + ' - ' + @c_VBErrMsg + '</Description>'          
                              + '</ExceptionError>'  
   END  
   ELSE  
   BEGIN 
      SELECT @c_ResponseString'@c_ResponseString' , @c_VBErrMsg '@c_VBErrMsg' 
      IF @c_VBErrMsg <> ''  
      BEGIN  
         SET @n_Continue = 3
         SET @n_Err = 90220    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))     
                        + ': ' + @c_VBErrMsg + ' (isp_CldPrt_Generic_RespRequest)'    
  
         SET @c_ResponseString = '<?xml version="1.0" encoding="UTF-8" ?>'  
                                 + '<ExceptionError>'  
                                 + '<Reason>G99</Reason>'  
                                 + '<Description>' + @c_VBErrMsg + '</Description>'  
                                 + '</ExceptionError>'  
  
      END     
      IF ISNULL(RTRIM(@c_ResponseString),'') = '' AND ISNULL(RTRIM(@c_HttpStatusCode),'') = '' --(KH02)  
      BEGIN  
         SET @n_Continue = 3
         SET @n_Err = 90230    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))     
                       + ': ResponseString Is Empty. (isp_CldPrt_Generic_RespRequest)'    
  
         SET @c_ResponseString = '<?xml version="1.0" encoding="UTF-8" ?>'  
                               + '<ExceptionError>'  
                               + '<Reason>G05</Reason>'  
                               + '<Description>' + @c_ErrMsg + '</Description>'  
                               + '</ExceptionError>'  
  
      END  
      ELSE IF ISNULL(RTRIM(@c_ResponseString),'') = '' AND ISNULL(RTRIM(@c_HttpStatusCode),'') <> ''  
      BEGIN  
         SET @c_ResponseString = @c_HttpStatusCode  
      END   
   END
   
   SET @c_JobStatus = '9'
   SET @c_Data = @c_ResponseString
   IF @n_Continue = 3
   BEGIN
      SET @c_JobStatus = '5'
      SET @c_Data = ''
   END
   
   INSERT INTO dbo.WebSocket_OUTLog
             (
               [Application]
             , LocalEndPoint
             , RemoteEndPoint
             , MessageType
             , [Data]
             , MessageNum
             , StorerKey
             , BatchNo
             , LabelNo
             , RefNo
             , ErrMsg
             , [Status]
             , ACKData
             )
         VALUES
             (
               @c_DataProcess
             , N''      
             , N''      
             , 'RECEIVE'
             , @c_ResponseString
             , N''    
             , @c_StorerKey
             , N''
             , N''       
             , @n_JobID 
             , @c_ErrMsg
             , '9'
             , ''
             )
            
   EXEC [dbo].[isp_UpdateRDTPrintJobStatus]                
                @n_JobID      = @n_JobID                
               ,@c_JobStatus  = @c_JobStatus                
               ,@c_JobErrMsg  = @c_ErrMsg               
               ,@b_Success    = @b_Success OUTPUT                
               ,@n_Err        = @n_Err     OUTPUT                
               ,@c_ErrMsg     = @c_ErrMsg  OUTPUT 
               ,@c_PrintData  = @c_Data        
         
   QUIT_SP:  
   
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, '[isp_CldPrt_Generic_RespRequest]'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO