SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
  
/************************************************************************/    
/* Trigger: [API].[isp_ECOMP_GenLabelNo]                                */    
/* Creation Date: 13-DEC-2023                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: Alex                                                     */    
/*                                                                      */    
/* Purpose: PAC-301 - New ECOM Packing                                  */    
/*          :                                                           */    
/* Called By:                                                           */    
/*          :                                                           */    
/* PVCS Version: 1.8                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date           Author      Purposes                                  */
/* 22-May-2024    Alex01      #PAC-343 bug fixed - missing pick header  */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GenLabelNo] (  
     @b_Debug                    INT            = 0  
   , @c_PickSlipNo               NVARCHAR(10)   = ''  
   , @c_NewPickSlipNo            NVARCHAR(10)   = ''  
   , @b_PackConfirm              INT            = 0  
   , @b_Success                  INT            = 0   OUTPUT  
   , @n_ErrNo                    INT            = 0   OUTPUT  
   , @c_ErrMsg                   NVARCHAR(250)  = ''  OUTPUT  
)  
AS    
BEGIN    
   DECLARE @n_StartTCnt          INT = @@TRANCOUNT  
         , @n_Continue           INT = 1  
     
   DECLARE @n_EPD_CartonNo                INT            = 0  
         , @c_EPD_LabelNo                 NVARCHAR(20)   = ''  
         , @c_LabelLine                   NVARCHAR(5)    = ''  
         , @n_PackSerialNoKey             BIGINT         = 0  
  
         , @c_PHOrderKey                  NVARCHAR(15)   = ''  
  
         , @c_PickHeaderKey               NVARCHAR(18)   = ''  
         , @b_sp_Success                  INT  
         , @n_sp_err                      INT  
         , @c_sp_errmsg                   NVARCHAR(250)  = ''  
  
         , @c_GenUCCPickSlipNo            NVARCHAR(10)   = ''  
  
   SET @b_Success                = 1  
   SET @n_ErrNo                  = 0  
   SET @c_ErrMsg                 = ''  
     
   SET @c_PickSlipNo             = ISNULL(RTRIM(@c_PickSlipNo), '')  
   SET @c_NewPickSlipNo          = IIF(@b_PackConfirm = 1, ISNULL(RTRIM(@c_NewPickSlipNo), ''), '')  
   SET @c_GenUCCPickSlipNo       = IIF(@b_PackConfirm = 1, @c_NewPickSlipNo, @c_PickSlipNo)  
  
   IF @b_Debug = 1  
   BEGIN  
      PRINT '>>>>> [API].[isp_ECOMP_GenLabelNo] Start...'  
   END   
  
   IF @b_PackConfirm = 1 AND @c_NewPickSlipNo = ''  
   BEGIN  
      SET @n_continue = 3      
      SET @n_ErrNo = 66001       
      SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_sp_err)+': NewPickSlipNo cannot be blank. ([dbo].[isp_ECOM_GenPickHeader])'    
      GOTO QUIT     
   END  
  
   IF @c_PickSlipNo <> ''  
   BEGIN  
      SELECT @c_PHOrderKey       = ISNULL(RTRIM(OrderKey), '')  
      FROM [dbo].[PackHeader] WITH (NOLOCK)  
      WHERE PickSlipNo = @c_PickSlipNo  
  
      IF @c_PHOrderKey = ''  
      BEGIN  
         GOTO QUIT  
      END  
  
      IF @b_PackConfirm = 1  
         OR EXISTS ( SELECT 1 FROM [dbo].[PACKDETAIL] WITH (NOLOCK)  
         WHERE PickSlipNo = @c_PickSlipNo AND (LabelNo = '' OR LabelNo IS NULL) )  
      BEGIN  
         IF @b_Debug = 1  
         BEGIN  
            PRINT 'Found [PACKDETAIL].LabelNo with blank / is pack confirm..'  
         END  
  
         --Close carton, update temporary pickheaderkey if pickheader exists.  
         IF @b_PackConfirm = 0   
            AND EXISTS ( SELECT 1 FROM [dbo].[PICKHEADER] WITH (NOLOCK)   
               WHERE OrderKey = @c_PHOrderKey   
               And [Zone] = '3'  
               AND [PickHeaderKey] <> @c_PickSlipNo )  
         BEGIN  
            DECLARE CUR_EPICKH CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT TOP 1 PICKHEADERKEY  
            FROM [dbo].[PICKHEADER] WITH (NOLOCK)      
            WHERE OrderKey = @c_PHOrderKey   
            And [Zone] = '3'  
            AND [PickHeaderKey] <> @c_PickSlipNo    
                  
            OPEN CUR_EPICKH    
            FETCH NEXT FROM CUR_EPICKH INTO @c_PickHeaderKey  
            WHILE @@FETCH_STATUS <> -1      
            BEGIN      
               UPDATE [dbo].[PICKHEADER] WITH (ROWLOCK)  
               SET [PickHeaderKey] = @c_PickSlipNo  
               WHERE [PickHeaderKey] = @c_PickHeaderKey  
  
               FETCH NEXT FROM CUR_EPICKH INTO @c_PickHeaderKey  
            END      
            CLOSE CUR_EPICKH      
            DEALLOCATE CUR_EPICKH    
         END  
         ELSE   
         BEGIN
            EXEC [dbo].[isp_ECOM_GenPickHeader]  
                 @c_OrderKey       = @c_PHOrderKey  
               , @c_TempPickSlipNo = @c_PickSlipNo  
               , @c_NewPickSlipNo  = @c_NewPickSlipNo  
               , @b_success        =  @b_sp_Success   OUTPUT  
               , @n_err            =  @n_sp_err       OUTPUT  
               , @c_errmsg         =  @c_sp_errmsg    OUTPUT      
  
            IF @b_sp_Success <> 1      
            BEGIN      
               SET @n_continue = 3      
               SET @n_ErrNo = 66001       
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_sp_err)+': Unable to Generate Pick Header. ([dbo].[isp_ECOM_GenPickHeader])'       
                            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_sp_errmsg),'') + ' ) '       
               GOTO QUIT      
            END  
         END  
           
      END  

      --IF LEFT(@c_PickSlipNo,1) = 'P' GOTO SKIP_UPDATE_LABELNO  --PackDetail already updated to 'P' prefixed.

      -- Update LabelNo (Begin)  
      DECLARE CUR_EPACKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT DISTINCT CartonNo       
            ,LabelNo       
      FROM [dbo].[PACKDETAIL] WITH (NOLOCK)      
      WHERE PickSlipNo = @c_PickSlipNo      
      ORDER BY CartonNo      
            
      OPEN CUR_EPACKD      
            
      FETCH NEXT FROM CUR_EPACKD INTO @n_EPD_CartonNo      
                                    ,@c_EPD_LabelNo       
      WHILE @@FETCH_STATUS <> -1      
      BEGIN      
         IF RTRIM(@c_EPD_LabelNo) = '' OR @c_EPD_LabelNo IS NULL      
         BEGIN      
            EXEC isp_GenUCCLabelNo_Std        
                  @cPickslipNo   = @c_GenUCCPickSlipNo      
               ,  @nCartonNo     = @n_EPD_CartonNo      
               ,  @cLabelNo      = @c_EPD_LabelNo     OUTPUT      
               ,  @b_success     = @b_sp_Success      OUTPUT      
               ,  @n_err         = @n_sp_err          OUTPUT      
               ,  @c_errmsg      = @c_sp_errmsg       OUTPUT      
         
            IF @b_sp_Success <> 1      
            BEGIN      
               SET @n_continue = 3      
               SET @n_ErrNo = 66001       
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_sp_err)+': Error Executing isp_GenUCCLabelNo_Std. ([API].[isp_ECOMP_API_CloseCarton_M])'       
                            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_sp_errmsg),'') + ' ) '       
               GOTO QUIT      
            END      
         END  
           
         IF @c_EPD_LabelNo <> 'ERROR'  
         BEGIN  
            DECLARE CUR_EPACKL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT LabelLine       
            FROM   PACKDETAIL WITH (NOLOCK)      
            WHERE PickSlipNo = @c_PickSlipNo      
            AND   CartonNo = @n_EPD_CartonNo      
               
            OPEN CUR_EPACKL      
               
            FETCH NEXT FROM CUR_EPACKL INTO @c_LabelLine      
            WHILE @@FETCH_STATUS <> -1      
            BEGIN      
               UPDATE PACKDETAIL WITH (ROWLOCK)      
               SET PickSlipNo = CASE WHEN @b_PackConfirm = 1 THEN @c_NewPickSlipNo ELSE @c_PickSlipNo END  
                  ,LabelNo    = @c_EPD_LabelNo      
                  ,EditWho    = SUSER_NAME()      
                  ,EditDate   = GETDATE()  
               WHERE PickSlipNo = @c_PickSlipNo      
               AND   CartonNo   = @n_EPD_CartonNo      
               AND   LabelLine  = @c_LabelLine      
         
               SET @n_sp_err = @@ERROR      
               IF @n_sp_err <> 0      
               BEGIN      
                  SET @n_continue = 3      
                  SET @n_ErrNo = 66002       
                  SET @c_sp_errmsg = ERROR_MESSAGE()  
                  SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_sp_err)+': Error Update PACKDETAIL Table. (isp_ECOMP_PackConfirm)'       
                               + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_sp_errmsg),'') + ' ) '       
                  GOTO QUIT     
               END      
               FETCH NEXT FROM CUR_EPACKL INTO @c_LabelLine      
            END      
            CLOSE CUR_EPACKL      
            DEALLOCATE CUR_EPACKL      
         
            DECLARE CUR_EPACKSN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT PackSerialNoKey       
            FROM   PACKSERIALNO WITH (NOLOCK)      
            WHERE PickSlipNo = @c_PickSlipNo      
            AND   CartonNo   = @n_EPD_CartonNo      
               
            OPEN CUR_EPACKSN      
               
            FETCH NEXT FROM CUR_EPACKSN INTO @n_PackSerialNoKey      
            WHILE @@FETCH_STATUS <> -1      
            BEGIN      
               UPDATE PACKSERIALNO WITH (ROWLOCK)      
               SET PickSlipNo = CASE WHEN @b_PackConfirm = 1 THEN @c_NewPickSlipNo ELSE @c_PickSlipNo END      
                  ,LabelNo    = @c_EPD_LabelNo      
                  ,EditWho    = SUSER_NAME()      
                  ,EditDate   = GETDATE()      
                  ,ArchiveCop = NULL      
               WHERE PackSerialNoKey = @n_PackSerialNoKey      
         
               SET @n_sp_err = @@ERROR      
               IF @n_sp_err <> 0      
               BEGIN      
                  SET @n_continue = 3      
                  SET @n_ErrNo = 66003       
                  SET @c_sp_errmsg = ERROR_MESSAGE()  
                  SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_sp_err)+': Error Update PACKSERIALNO Table. (isp_ECOMP_PackConfirm)'       
                               + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_sp_errmsg),'') + ' ) '       
                  GOTO QUIT      
               END      
               FETCH NEXT FROM CUR_EPACKSN INTO @n_PackSerialNoKey      
            END      
            CLOSE CUR_EPACKSN      
            DEALLOCATE CUR_EPACKSN      
         END  
  
         FETCH NEXT FROM CUR_EPACKD INTO @n_EPD_CartonNo      
                                        ,@c_EPD_LabelNo       
      END      
      CLOSE CUR_EPACKD      
      DEALLOCATE CUR_EPACKD    
      -- Update LabelNo (End)  

      SKIP_UPDATE_LABELNO:
   END  
     
   QUIT:  
   IF @b_Debug = 1  
   BEGIN  
      PRINT '>>>>> [API].[isp_ECOMP_GenLabelNo] End...'  
   END   
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
      --EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOMP_GenUCCLabelNo'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure    
  

GO