SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_GENCCTVFileName]               */              
/* Creation Date: 11-OCT-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: Alex Keoh                                                */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: SCEAPI                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes                                     */
/* 11-OCT-2024    Alex     #JIRA PAC-354 Initial                        */
/************************************************************************/

CREATE   PROC [API].[isp_ECOMP_API_GENCCTVFileName] (
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

         , @c_ComputerName                NVARCHAR(30)   = ''
         , @c_Facility                    NVARCHAR(10)   = ''
         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_PickSlipNo                  NVARCHAR(10)   = '' 
         , @c_FuncName                    NVARCHAR(20)   = ''

         , @c_FileName                    NVARCHAR(120)  = ''
         , @c_CurrentTimeStamp            NVARCHAR(12)   = (CONVERT(VARCHAR, GETDATE(), 112) + REPLACE(convert(varchar, getdate(), 108), ':', ''))

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)  = ''

         , @c_sc_SValue                   NVARCHAR(30)   = ''
         , @c_sc_Option1                  NVARCHAR(50)   = ''
         , @c_sc_Option2                  NVARCHAR(50)   = ''
         , @c_sc_Option3                  NVARCHAR(50)   = ''
         , @c_sc_Option4                  NVARCHAR(50)   = ''
         , @c_sc_Option5                  NVARCHAR(4000) = ''
         , @c_SQLQuery                    NVARCHAR(4000) = ''
         , @c_SQLParams                   NVARCHAR(1000) = ''

         , @c_TempValue1                  NVARCHAR(400)  = ''
         , @c_TempValue2                  NVARCHAR(400)  = ''
         , @c_TempValue3                  NVARCHAR(400)  = ''
         , @c_TempValue4                  NVARCHAR(400)  = ''
         , @c_TempValue5                  NVARCHAR(400)  = ''

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''

   SELECT @c_Facility       = ISNULL(RTRIM(Facility     ), '')
         ,@c_StorerKey      = ISNULL(RTRIM(Storer       ), '')
         ,@c_PickSlipNo     = ISNULL(RTRIM(PickSlipNo   ), '')
         ,@c_FuncName       = ISNULL(RTRIM(FuncName     ), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      Facility          NVARCHAR(10)       '$.Facility',
      Storer            NVARCHAR(15)       '$.Storer',
      PickSlipNo        NVARCHAR(10)       '$.PickSlipNo',
      [FuncName]        NVARCHAR(20)       '$.FuncName'
   )

   IF @c_FuncName NOT IN ('REDO', 'PACKCONFIRM', 'PENDPACKEXIT')
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 81300      
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_ErrNo) + ' - Invalid FuncName : ' + @c_FuncName
      GOTO QUIT 
   END

   IF @c_FuncName IN ('REDO', 'PENDPACKEXIT')
   BEGIN
      SELECT @c_FileName = @c_FuncName + '_' + ISNULL(RTRIM(TaskBatchNo), '') + '_' + @c_CurrentTimeStamp + '.mp4'
      FROM [dbo].[PackHeader] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
   END

   IF @c_FuncName = 'PACKCONFIRM'
   BEGIN 
      SELECT @c_FileName = ISNULL(RTRIM(TaskBatchNo), '') + '_' + @c_CurrentTimeStamp + '.mp4'
      FROM [dbo].[PackHeader] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      EXEC [dbo].[nspGetRight]
         @c_Facility          = @c_Facility
      ,  @c_StorerKey         = @c_StorerKey
      ,  @c_sku               = ''
      ,  @c_ConfigKey         = 'EPACKCCTVFILENAME'
      ,  @b_Success           = @b_sp_Success          OUTPUT   
      ,  @c_authority         = @c_sc_SValue           OUTPUT
      ,  @n_err               = @n_sp_err              OUTPUT    
      ,  @c_errmsg            = @c_sp_errmsg           OUTPUT  
      ,  @c_Option1           = @c_sc_Option1          OUTPUT
      ,  @c_Option2           = @c_sc_Option2          OUTPUT
      ,  @c_Option3           = @c_sc_Option3          OUTPUT
      ,  @c_Option4           = @c_sc_Option4          OUTPUT
      ,  @c_Option5           = @c_sc_Option5          OUTPUT

      SET @c_sc_Option1 = ISNULL(RTRIM(@c_sc_Option1), '')
      SET @c_sc_Option2 = ISNULL(RTRIM(@c_sc_Option2), '')
      SET @c_sc_Option3 = ISNULL(RTRIM(@c_sc_Option3), '')
      SET @c_sc_Option4 = ISNULL(RTRIM(@c_sc_Option4), '')
      SET @c_sc_Option5 = ISNULL(RTRIM(@c_sc_Option5), '')
      
      IF @c_sc_Option1 = '' AND @c_sc_Option2 = '' AND @c_sc_Option3 = '' AND @c_sc_Option4 = '' AND @c_sc_Option5 = ''
      BEGIN
         SET @n_Continue = 3      
         SET @n_ErrNo = 81301      
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_ErrNo) + ' - No column configure in StorerConfig (ConfigKey=EPACKCCTVFILENAME)'
         GOTO QUIT 
      END

      SET @c_SQLQuery = 'SELECT '
                      + '  @c_TempValue1 = ' + CASE WHEN @c_sc_Option1 <> '' AND @c_sc_Option1 LIKE 'ORDERS.%' THEN @c_sc_Option1 ELSE ''''' ' END 
                      + ', @c_TempValue2 = ' + CASE WHEN @c_sc_Option2 <> '' AND @c_sc_Option2 LIKE 'ORDERS.%' THEN @c_sc_Option2 ELSE ''''' ' END 
                      + ', @c_TempValue3 = ' + CASE WHEN @c_sc_Option3 <> '' AND @c_sc_Option3 LIKE 'ORDERS.%' THEN @c_sc_Option3 ELSE ''''' ' END 
                      + ', @c_TempValue4 = ' + CASE WHEN @c_sc_Option4 <> '' AND @c_sc_Option4 LIKE 'ORDERS.%' THEN @c_sc_Option4 ELSE ''''' ' END 
                      + ', @c_TempValue5 = ' + CASE WHEN @c_sc_Option5 <> '' AND @c_sc_Option5 LIKE 'ORDERS.%' THEN @c_sc_Option5 ELSE ''''' ' END 
                      + 'FROM [dbo].[ORDERS] WITH (NOLOCK) '
                      + 'WHERE OrderKey = ( SELECT TOP 1 OrderKey FROM [dbo].[PackHeader] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo ) '
      
      IF @b_Debug = 1
      BEGIN
         PRINT @c_SQLQuery
      END

      SET @c_SQLParams = '@c_PickSlipNo NVARCHAR(10), '
                       + '@c_TempValue1 NVARCHAR(400) OUTPUT, '
                       + '@c_TempValue2 NVARCHAR(400) OUTPUT, '
                       + '@c_TempValue3 NVARCHAR(400) OUTPUT, '
                       + '@c_TempValue4 NVARCHAR(400) OUTPUT, ' 
                       + '@c_TempValue5 NVARCHAR(400) OUTPUT  '

      EXEC sp_executesql @c_SQLQuery, @c_SQLParams, @c_PickSlipNo, @c_TempValue1 OUTPUT, @c_TempValue2 OUTPUT, @c_TempValue3 OUTPUT, @c_TempValue4 OUTPUT, @c_TempValue5 OUTPUT
      
      IF @b_Debug = 1
      BEGIN
         PRINT '@c_TempValue1 = ' + @c_TempValue1
         PRINT '@c_TempValue2 = ' + @c_TempValue2
         PRINT '@c_TempValue3 = ' + @c_TempValue3
         PRINT '@c_TempValue4 = ' + @c_TempValue4
         PRINT '@c_TempValue5 = ' + @c_TempValue5
      END

      SET @c_FileName = CONCAT(
                            NULLIF(@c_TempValue1, ''),
                            CASE WHEN @c_TempValue1 IS NOT NULL AND @c_TempValue1 <> '' AND (@c_TempValue2 IS NOT NULL AND @c_TempValue2 <> '' OR @c_TempValue3 IS NOT NULL AND @c_TempValue3 <> '' OR @c_TempValue4 IS NOT NULL AND @c_TempValue4 <> '' OR @c_TempValue5 IS NOT NULL AND @c_TempValue5 <> '') THEN '_' ELSE '' END,
                            NULLIF(@c_TempValue2, ''),
                            CASE WHEN @c_TempValue2 IS NOT NULL AND @c_TempValue2 <> '' AND (@c_TempValue3 IS NOT NULL AND @c_TempValue3 <> '' OR @c_TempValue4 IS NOT NULL AND @c_TempValue4 <> '' OR @c_TempValue5 IS NOT NULL AND @c_TempValue5 <> '') THEN '_' ELSE '' END,
                            NULLIF(@c_TempValue3, ''),
                            CASE WHEN @c_TempValue3 IS NOT NULL AND @c_TempValue3 <> '' AND (@c_TempValue4 IS NOT NULL AND @c_TempValue4 <> '' OR @c_TempValue5 IS NOT NULL AND @c_TempValue5 <> '') THEN '_' ELSE '' END,
                            NULLIF(@c_TempValue4, ''),
                            CASE WHEN @c_TempValue4 IS NOT NULL AND @c_TempValue4 <> '' AND (@c_TempValue5 IS NOT NULL AND @c_TempValue5 <> '') THEN '_' ELSE '' END,
                            NULLIF(@c_TempValue5, '')
                        )

      SET @c_FileName = @c_FileName + CASE WHEN @c_FileName <> '' THEN '_' ELSE '' END + @c_CurrentTimeStamp + '.mp4'
   END

   SET @c_ResponseString = ISNULL(( 
                              SELECT @c_FileName  As 'NewFileName'
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