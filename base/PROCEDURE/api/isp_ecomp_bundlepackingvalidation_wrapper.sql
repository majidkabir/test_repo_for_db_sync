SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_BundlePackingValidation_Wrapper]   */              
/* Creation Date: 4-Sep-2024                                            */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose: For  Bundle Packing Validation Wrapper                      */
/*                                                                      */
/* Called By: SCEAPI                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes	                                    */
/* 9-Jul-2024     Alex     #PAC-353                                     */
/************************************************************************/ 

CREATE   PROC [API].[isp_ECOMP_BundlePackingValidation_Wrapper]
   @b_Debug          INT            = 0
,  @c_PickSlipNo     NVARCHAR(10)
,  @n_CartonNo       INT
,  @c_OrderKey       NVARCHAR(10)
,  @c_Storerkey      NVARCHAR(15) 
,  @c_Sku            NVARCHAR(60)
,  @c_Type           NVARCHAR(15)   = ''
,  @b_Success        INT            OUTPUT  
,  @n_Err            INT            OUTPUT  
,  @c_ErrMsg         NVARCHAR(255)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT                      ON  
   SET ANSI_NULLS                   OFF  
   SET QUOTED_IDENTIFIER            OFF  
   SET CONCAT_NULL_YIELDS_NULL      OFF  
  
   DECLARE @n_StartTCnt             INT                  = @@TRANCOUNT  
         , @n_Continue              INT                  = 1      
         , @c_SPCode                NVARCHAR(30)         = ''
         , @c_SQLQuery              NVARCHAR(4000)       = ''

   SET @n_Err                       = 0  
   SET @c_ErrMsg                    = ''  

   SELECT @c_SPCode = ISNULL(RTRIM(SValue), '')
   FROM   StorerConfig WITH (NOLOCK)   
   WHERE  StorerKey = @c_StorerKey  
   AND    ConfigKey = 'ECOMP_BundlePackValidate'    
  
   IF @c_SPCode = ''  
   BEGIN  
       SET @n_continue = 4    
       GOTO QUIT_SP  
   END  
     
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')  
   BEGIN  
       SET @n_continue = 3    
       SET @n_Err = 51240
       SET  @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Storerconfig ECOMP_BundlePackValidate - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_ECOMP_BundlePackingValidation_Wrapper)'    
       GOTO QUIT_SP  
   END  


   SET @c_SQLQuery = 'EXEC [API].[' + @c_SPCode + '] '
                   + '   @b_Debug          = @b_Debug              '
                   + ',  @c_PickSlipNo     = @c_PickSlipNo         '
                   + ',  @n_CartonNo       = @n_CartonNo           '
                   + ',  @c_OrderKey       = @c_OrderKey           '
                   + ',  @c_Storerkey      = @c_Storerkey          '
                   + ',  @c_Sku            = @c_Sku                '
                   + ',  @c_Type           = @c_Type               '
                   + ',  @b_Success        = @b_Success     OUTPUT ' 
                   + ',  @n_Err            = @n_Err         OUTPUT ' 
                   + ',  @c_ErrMsg         = @c_ErrMsg      OUTPUT '

   
   EXEC sp_executesql 
      @c_SQLQuery  
    , N'@b_Debug INT, @c_PickSlipNo NVARCHAR(10),  @n_CartonNo INT, @c_OrderKey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(60), @c_Type NVARCHAR(15), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT'
    , @b_Debug             
    , @c_PickSlipNo        
    , @n_CartonNo          
    , @c_OrderKey          
    , @c_Storerkey         
    , @c_Sku                
    , @c_Type                                      
    , @b_Success     OUTPUT
    , @n_Err         OUTPUT
    , @c_ErrMsg      OUTPUT     
     
   IF @b_Success <> 1  
   BEGIN  
       SET @n_continue = 3    
       GOTO QUIT_SP  
   END  

QUIT_SP:  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOMP_BundlePackingValidation_Wrapper'  
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