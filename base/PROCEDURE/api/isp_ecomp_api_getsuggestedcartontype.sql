SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*********************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_GetSuggestedCartonType]                 */              
/* Creation Date: 14-NOV-2024                                                    */
/* Copyright: Maersk                                                             */
/* Written by: Alex Keoh                                                         */
/*                                                                               */
/* Purpose:                                                                      */
/*                                                                               */
/* Called By: SCEAPI                                                             */
/*                                                                               */
/* PVCS Version: 1.0                                                             */
/*                                                                               */
/* Version: 1.0                                                                  */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date           Author   Purposes                                              */
/* 14-NOV-2024    Alex     #PAC-363 - Initial                                    */
/*********************************************************************************/

CREATE   PROC [API].[isp_ECOMP_API_GetSuggestedCartonType](
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
   
   DECLARE @n_Continue                    INT            = 1
         , @n_StartCnt                    INT            = @@TRANCOUNT
         , @c_SQLQuery                    NVARCHAR(500)  = ''
         , @c_Facility                    NVARCHAR(10)   = ''
         , @c_StorerKey                   NVARCHAR(15)   = ''

         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_PickSlipNo                  NVARCHAR(10)   = ''
         
         , @c_EPACKSuggestCartonType      NVARCHAR(1)    = ''
         , @c_EPACKSuggestCartonTypeSP    NVARCHAR(200)  = ''

         , @n_sc_Success                  INT            = 0
         , @n_sc_err                      INT            = 0
         , @c_sc_errmsg                   NVARCHAR(250)  = ''

         , @c_CTS_Response                NVARCHAR(500)  = '[]'
         , @c_IsCartonTypeRequired        NVARCHAR(1)    = '0'

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   
   SELECT @c_Facility       = ISNULL(RTRIM(Facility     ), '')
         ,@c_StorerKey      = ISNULL(RTRIM(Storer       ), '')
         ,@c_OrderKey       = ISNULL(RTRIM(OrderKey     ), '')
         ,@c_PickSlipNo     = ISNULL(RTRIM(PickSlipNo   ), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      Facility          NVARCHAR(10)         '$.Facility',
      Storer            NVARCHAR(15)         '$.StorerKey',
      OrderKey          NVARCHAR(60)         '$.OrderKey',
      PickSlipNo        NVARCHAR(10)         '$.PickSlipNo'
   )
   

   SET @c_IsCartonTypeRequired = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'CtnTypeInput')

   IF @b_Debug = 1 
   BEGIN
      PRINT '@c_OrderKey = ' + @c_OrderKey
      PRINT '@c_IsCartonTypeRequired = ' + @c_IsCartonTypeRequired
   END

   --Alex01 Begin
   IF @c_OrderKey = '' OR NOT @c_IsCartonTypeRequired = '1'
   BEGIN
      GOTO GEN_RESPONSE
   END

   EXEC [dbo].[nspGetRight]
         @c_Facility          = @c_Facility
      ,  @c_StorerKey         = @c_StorerKey
      ,  @c_sku               = ''
      ,  @c_ConfigKey         = 'EPACKSuggestCartonType'
      ,  @b_Success           = @n_sc_Success               OUTPUT     
      ,  @c_authority         = @c_EPACKSuggestCartonType   OUTPUT    
      ,  @n_err               = @n_sc_err                   OUTPUT    
      ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
      ,  @c_Option1           = @c_EPACKSuggestCartonTypeSP OUTPUT 

   IF @c_OrderKey = '' 
      OR  @c_EPACKSuggestCartonType <> '1' OR ISNULL(RTRIM(@c_EPACKSuggestCartonTypeSP), '') = '' 
   BEGIN
      GOTO GEN_RESPONSE
   END

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_EPACKSuggestCartonTypeSP) AND type = 'P')  
   BEGIN  
       SET @n_continue = 3    
       SET @n_ErrNo = 51601
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_ErrNo) +   
              ': Storerconfig EPACKSuggestCartonType - Stored Proc name invalid ('+RTRIM(ISNULL(@c_EPACKSuggestCartonTypeSP,''))+') (isp_ECOMP_CtnTypeSugg_Wrapper)'    
       GOTO QUIT  
   END 

    SET @c_SQLQuery = 'EXEC [API].[' + @c_EPACKSuggestCartonTypeSP + '] '
                   + '   @b_Debug          = @b_Debug                 '
                   + ',  @c_PickSlipNo     = @c_PickSlipNo            '
                   + ',  @c_OrderKey       = @c_OrderKey              '
                   + ',  @c_Storerkey      = @c_Storerkey             '
                   + ',  @c_Facility       = @c_Facility              '
                   + ',  @b_Success        = @b_Success        OUTPUT ' 
                   + ',  @n_Err            = @n_ErrNo          OUTPUT ' 
                   + ',  @c_ErrMsg         = @c_ErrMsg         OUTPUT '
                   + ',  @c_CTS_Response   = @c_CTS_Response   OUTPUT '
   
   EXEC sp_executesql 
      @c_SQLQuery  
    , N'@b_Debug INT, @c_PickSlipNo NVARCHAR(10), @c_OrderKey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Facility NVARCHAR(5), @b_Success INT OUTPUT, @n_ErrNo INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT, @c_CTS_Response NVARCHAR(500) OUTPUT'
    , @b_Debug             
    , @c_PickSlipNo           
    , @c_OrderKey          
    , @c_Storerkey         
    , @c_Facility                                                   
    , @b_Success        OUTPUT
    , @n_ErrNo          OUTPUT
    , @c_ErrMsg         OUTPUT     
    , @c_CTS_Response   OUTPUT
     

   SET @c_CTS_Response = CASE WHEN ISNULL(RTRIM(@c_CTS_Response), '') = '' THEN '[]' ELSE @c_CTS_Response END


   GEN_RESPONSE:
   SET @c_ResponseString = ISNULL(( 
                              SELECT (
                                 JSON_QUERY(@c_CTS_Response)
                              ) As 'SuggestedCartonType'
                              FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                           ), '')

   QUIT:
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