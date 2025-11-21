SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_GetSKUPackingRules]                */              
/* Creation Date: 13-FEB-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose:                                                             */
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
/* Date           Author   Purposes                                     */
/* 15-Feb-2023    Alex     #JIRA PAC-4 Initial                          */
/* 12-AUG-2024    Alex01   #JIRA PAC-351 Regular exp to validate Serial#*/
/************************************************************************/
CREATE   PROC [API].[isp_ECOMP_GetSKUPackingRules](
     @b_Debug                    INT            = 1
   , @c_PickSlipNo               NVARCHAR(10)   = ''
   , @c_TaskBatchID              NVARCHAR(10)   = ''
   , @c_DropID                   NVARCHAR(20)   = ''
   , @c_OrderKey                 NVARCHAR(10)   = '' 
   , @c_StorerKey                NVARCHAR(15)   = ''
   , @c_Facility                 NVARCHAR(15)   = ''
   , @c_SKU                      NVARCHAR(20)   = ''
   , @c_PackMode                 NVARCHAR(1)    = 'S'          --#PAC-7 added new flag to support Multi Mode
   , @b_Success                  INT            = 0   OUTPUT
   , @n_ErrNo                    INT            = 0   OUTPUT
   , @c_ErrMsg                   NVARCHAR(250)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT            = 1
         , @n_StartCnt                    INT            = @@TRANCOUNT
         
         , @c_UR_StorerKey                NVARCHAR(15)   = ''
         , @c_UR_Facility                 NVARCHAR(15)   = ''
         , @c_ScanField                   NVARCHAR(30)   = ''
         , @c_ComputerName                NVARCHAR(30)   = ''
         , @n_IsExists                    INT            = 0

         , @n_sc_Success                  INT
         , @n_sc_err                      INT
         , @c_sc_errmsg                   NVARCHAR(250)  = ''
         , @c_sc_SValue                   NVARCHAR(30)   = ''
         , @c_sc_Option1                  NVARCHAR(50)   = ''
         , @c_sc_Option2                  NVARCHAR(50)   = ''
         , @c_sc_Option3                  NVARCHAR(50)   = ''
         , @c_sc_Option4                  NVARCHAR(50)   = ''
         , @c_sc_Option5                  NVARCHAR(50)   = ''

         , @c_sc_ToOption1                NVARCHAR(50)   = ''
         , @c_sc_ToOption2                NVARCHAR(50)   = ''
         , @c_sc_ToOption3                NVARCHAR(50)   = ''
         , @c_sc_ToOption4                NVARCHAR(50)   = ''
         , @c_sc_ToOption5                NVARCHAR(50)   = ''


         , @c_SQLQuery                    NVARCHAR(MAX)  = ''
         , @c_SQLParams                   NVARCHAR(2000) = ''

         , @b_IsWhereClauseExists         INT            = 0


   DECLARE @c_IsSerialNoMandatory         NVARCHAR(1)    = '0'
         , @c_IsLottableMandatory         NVARCHAR(1)    = '0'
         , @c_LottableFieldLabel          NVARCHAR(60)   = ''

         , @c_SerialNo_Regex              NVARCHAR(200)  = ''  --Alex01

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''

   SET @c_IsSerialNoMandatory    = 0
   SET @n_sc_Success             = 0
   SET @n_sc_err                 = 0
   SET @c_sc_errmsg              = ''
   
   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>>>>>>>>>>>> [API].[isp_ECOMP_GetSKUPackingRules]'
   END

   IF @c_PackMode NOT IN ('S', 'M') 
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 52000
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Invalid PackMode - ' + @c_PackMode
      GOTO QUIT
   END

   IF @c_PackMode = 'M'
   BEGIN
      --check if SerialNumber is mandatory
      SELECT @c_IsSerialNoMandatory = CASE 
            WHEN ISNULL(RTRIM([SerialNoCapture]), '') IN ('1','3')  THEN '1' ELSE '0' END
            ,@c_LottableFieldLabel = ISNULL(RTRIM(Lottable03Label), '')
      FROM [dbo].[SKU] WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
      AND SKU = @c_SKU

      IF @c_IsSerialNoMandatory <> '1'
      BEGIN
         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         SET @c_sc_ToOption1 = ''

         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'PACKBYLOTTABLE'
               ,  @b_Success           = @n_sc_Success          OUTPUT     
               ,  @c_authority         = @c_sc_SValue           OUTPUT    
               ,  @n_err               = @n_sc_err              OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg           OUTPUT  
               ,  @c_Option1           = @c_sc_ToOption1        OUTPUT

         IF @n_sc_Success <> 1   
         BEGIN   
            SET @n_Continue = 3 
            SET @n_ErrNo = 52051
            SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(ValidateTrackNo). '  
            GOTO QUIT
         END

         IF @c_sc_SValue = '2' 
         BEGIN
            EXEC [dbo].[isp_PackLAPreCheck_Wrapper]
               @c_PickSlipNo  = @c_PickSlipNo
              ,@c_Storerkey   = @c_Storerkey
              ,@c_Sku         = @c_Sku
              ,@c_TaskBatchNo = @c_TaskBatchID
              ,@b_Success     = @n_sc_Success   OUTPUT
              ,@n_Err         = @n_sc_err       OUTPUT
              ,@c_ErrMsg      = @c_sc_errmsg    OUTPUT

            IF @n_sc_Success = 1
            BEGIN   
               SET @c_SQLQuery = 'SELECT @c_LottableFieldLabel = ' + CASE WHEN @c_sc_ToOption1 IN ('01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13', '14', '15')
                                                                     THEN 'ISNULL(RTRIM(Lottable' + @c_sc_ToOption1 + 'Label), '''')' ELSE '''''' END + CHAR(13)
                            + 'FROM [dbo].[SKU] WITH (NOLOCK)' + CHAR(13) 
                            + 'WHERE StorerKey = @c_StorerKey' + CHAR(13) 
                            + 'AND SKU = @c_SKU'

               SET @c_SQLParams = '@c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), @c_IsSerialNoMandatory NVARCHAR(1) OUTPUT, @c_LottableFieldLabel NVARCHAR(60) OUTPUT'

               EXECUTE sp_ExecuteSql 
                       @c_SQLQuery
                      ,@c_SQLParams
                      ,@c_StorerKey
                      ,@c_SKU
                      ,@c_IsSerialNoMandatory   OUTPUT
                      ,@c_LottableFieldLabel    OUTPUT

               SET @c_IsLottableMandatory = '1'
            END
         END
      END
      --Alex01 Begin
      ELSE
      BEGIN
         SET @c_SerialNo_Regex = ''

         SELECT @c_SerialNo_Regex = ISNULL(CL.Long,'')   
         FROM CODELKUP CL(NOLOCK)  
         WHERE CL.Listname = 'REQEXP'  
         AND CL.Storerkey = @c_Storerkey  
         AND CL.Code = 'SerialNo'  
      END
      --Alex01 End

      SELECT 'IsSerialNoMandatory'     , @c_IsSerialNoMandatory         UNION ALL
      SELECT 'IsLottableMandatory'     , @c_IsLottableMandatory         UNION ALL
      SELECT 'LottableFieldLabel'      , @c_LottableFieldLabel          UNION ALL
      SELECT 'SerialNo_RegEx'          , @c_SerialNo_Regex                             --Alex01
   END

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