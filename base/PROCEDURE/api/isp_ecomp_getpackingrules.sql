SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_GetPackingRules]                   */              
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
/* Date           Author   Purposes	                                    */
/* 15-Feb-2023    Alex     #JIRA PAC-4 Initial                          */
/* 02-OCT-2023    Alex01   #JIRA PAC-142 Single - Lottable Function     */
/* 02-APR-2023    Alex02   #JIRA PAC-182 Display SKU Images             */
/* 12-AUG-2024    Alex03   #JIRA PAC-351 Regular exp to validate Serial#*/
/* 14-NOV-2024    Alex04   #JIRA PAC-363 New Rules for IsSysSuggCtnType */
/************************************************************************/
CREATE   PROC [API].[isp_ECOMP_GetPackingRules](
     @c_StorerKey                NVARCHAR(15)   = ''
   , @c_Facility                 NVARCHAR(15)   = ''
   , @c_SKU                      NVARCHAR(20)   = ''
   , @c_PackMode                 NVARCHAR(1)    = 'S'          --#PAC-7 added new flag to support Multi Mode
   , @c_PickSlipNo               NVARCHAR(10)   = ''
   , @c_TaskBatchID              NVARCHAR(10)   = ''
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
         --, @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(20)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_ComputerName                NVARCHAR(30)   = ''
         , @n_IsExists                    INT            = 0

         , @c_OrderMode                   NVARCHAR(1)    = ''
         , @c_PackNotes                   NVARCHAR(4000) = ''
         
         , @c_sc_EPackTakeOver            NVARCHAR(5)    = ''
         , @c_sc_MultiPackMode            NVARCHAR(5)    = ''

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

   DECLARE 
           --@c_PickSlipNo                  NVARCHAR(10)   = ''
           @c_PackOrderKey                NVARCHAR(10)   = ''
         , @c_PackAddWho                  NVARCHAR(128)  = ''
         , @c_PackComputerName            NVARCHAR(30)   = ''
         , @c_PackIsExists                INT            = 0

         , @c_sc_ValidateTrackNo          NVARCHAR(1)    = '0'
         , @c_sc_EPackSkipTracknoCheck    NVARCHAR(1)    = '0'
         , @c_sc_CtnTypeInput             NVARCHAR(1)    = '0'
         , @c_sc_CtnTypeConvert           NVARCHAR(1)    = '0'
         , @c_sc_WeightInput              NVARCHAR(1)    = '0'
         , @c_sc_AutoCalcWeight           NVARCHAR(1)    = '0'
         , @c_sc_EPACKQRF                 NVARCHAR(1)    = '0'
         , @c_sc_ECOMAutoPackConfirm      NVARCHAR(1)    = '0'


   DECLARE @c_IsSerialNoMandatory         NVARCHAR(1)    = '0'
         , @c_IsLottableMandatory         NVARCHAR(1)    = '0'
         , @c_LottableFieldLabel          NVARCHAR(60)    = ''

         , @c_EpackForceMultiPackByOrd    NVARCHAR(1)    = '0'
         , @c_EPACKCloseCartonPrint       NVARCHAR(1)    = '0'
         , @c_EPACKNewCartonSkipPrint     NVARCHAR(1)    = '0'
         , @c_PackUpdateEstTotalCtn       NVARCHAR(1)    = '0'
         , @c_IsPackQRFMandatory          NVARCHAR(1)    = '0'
         , @c_PackQRF_RegEx               NVARCHAR(200)  = ''
         , @c_IsTrackingNoMandatory       NVARCHAR(1)    = '0' 
         , @c_IsCartonTypeMandatory       NVARCHAR(1)    = '0' 
         , @c_IsCtnTypeConvert            NVARCHAR(1)    = '0' 
         , @c_IsWeightMandatory           NVARCHAR(1)    = '0' 
         , @c_IsAutoWeightCalc            NVARCHAR(1)    = '0' 
         , @c_IsAutoPackConfirm           NVARCHAR(1)    = '0' 
         , @c_IsCaptureLabelNo            NVARCHAR(1)    = '0'
         , @c_CaptureLabelNoFunc          NVARCHAR(50)   = ''

         , @c_PackChkCartonWeightValue    NVARCHAR(30)   = '0'
         , @c_PackChkCartonWeight         NVARCHAR(1)    = '0'
         , @c_IsVASMandatory              NVARCHAR(1)    = '0' 
         , @c_ECOMPShowSKUIMG             NVARCHAR(1)    = ''
         , @c_ECOMPNoOfIMG                NVARCHAR(3)    = ''

         , @c_SerialNo_Regex              NVARCHAR(200)  = ''  --Alex03
         , @c_IsSystemSugCartonType       NVARCHAR(1)    = ''  --Alex04

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''

   SET @c_IsSerialNoMandatory    = 0
   SET @c_IsPackQRFMandatory     = 0
   SET @c_IsTrackingNoMandatory  = 0
   SET @c_IsCartonTypeMandatory  = 0
   SET @c_IsWeightMandatory      = 0
   SET @c_IsAutoWeightCalc       = 0
   SET @c_IsAutoPackConfirm      = 0
   SET @c_PackQRF_RegEx          = ''
   SET @n_sc_Success             = 0
   SET @n_sc_err                 = 0
   SET @c_sc_errmsg              = ''
   
   IF @c_PackMode NOT IN ('S', 'M') 
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 52000
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Invalid PackMode - ' + @c_PackMode
      GOTO QUIT
   END

   EXEC [dbo].[nspGetRight]
            @c_Facility          = @c_Facility
         ,  @c_StorerKey         = @c_StorerKey
         ,  @c_sku               = ''
         ,  @c_ConfigKey         = 'ECOMPShowSKUIMAGE'
         ,  @b_Success           = @n_sc_Success               OUTPUT     
         ,  @c_authority         = @c_ECOMPShowSKUIMG          OUTPUT    
         ,  @n_err               = @n_sc_err                   OUTPUT    
         ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
         ,  @c_Option1           = @c_ECOMPNoOfIMG             OUTPUT
   
   IF @n_sc_Success <> 1   
   BEGIN   
      SET @n_Continue = 3 
      SET @n_ErrNo = 52000
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(ECOMPShowSKUIMAGE). '  
      GOTO QUIT
   END

   IF @c_PackMode = 'S'
   BEGIN
      EXEC [dbo].[nspGetRight]
              @c_Facility          = @c_Facility
           ,  @c_StorerKey         = @c_StorerKey
           ,  @c_sku               = ''
           ,  @c_ConfigKey         = 'EPACKQRF'
           ,  @b_Success           = @n_sc_Success          OUTPUT     
           ,  @c_authority         = @c_sc_EPACKQRF         OUTPUT    
           ,  @n_err               = @n_sc_err              OUTPUT    
           ,  @c_errmsg            = @c_sc_errmsg           OUTPUT  
      
      IF @n_sc_Success <> 1   
      BEGIN   
        SET @n_Continue = 3 
        SET @n_ErrNo = 52001
        SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(EPACKQRF). '  
        GOTO QUIT
      END
      
      SET @c_IsPackQRFMandatory = CASE WHEN @c_sc_EPACKQRF IN ('1', '3') THEN '1' ELSE '0' END
      
      IF @c_sc_EPACKQRF IN ('1', '3')
      BEGIN
         SET @c_PackQRF_RegEx = '^\d{13}?$'  

         SELECT @c_PackQRF_RegEx = ISNULL(CL.Long,'')   
         FROM CODELKUP CL(NOLOCK)  
         WHERE CL.Listname = 'REQEXP'  
         AND CL.Storerkey = @c_Storerkey  
         AND CL.Code = 'QRCode'  
      END
      
      IF ISNULL(RTRIM(@c_SKU), '') <> ''
      BEGIN
         --check if SerialNumber is mandatory
         SELECT @c_IsSerialNoMandatory = CASE 
               WHEN ISNULL(RTRIM([SerialNoCapture]), '') IN ('1','3')  THEN '1' ELSE '0' END
         FROM [dbo].[SKU] WITH (NOLOCK) 
         WHERE StorerKey = @c_StorerKey
         AND SKU = @c_SKU
         
         --Alex01 Begin
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
         --Alex01 End
         --Alex03 Begin
         ELSE
         BEGIN
            SET @c_SerialNo_Regex = ''
            SELECT @c_SerialNo_Regex = ISNULL(CL.Long,'')   
            FROM CODELKUP CL(NOLOCK)  
            WHERE CL.Listname = 'REQEXP'  
            AND CL.Storerkey = @c_Storerkey  
            AND CL.Code = 'SerialNo'  
         END
         --Alex03 End
      END

      SET @c_sc_ValidateTrackNo = ''
      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      
      EXEC [dbo].[nspGetRight]
               @c_Facility          = @c_Facility
            ,  @c_StorerKey         = @c_StorerKey
            ,  @c_sku               = ''
            ,  @c_ConfigKey         = 'ValidateTrackNo'
            ,  @b_Success           = @n_sc_Success          OUTPUT     
            ,  @c_authority         = @c_sc_ValidateTrackNo  OUTPUT    
            ,  @n_err               = @n_sc_err              OUTPUT    
            ,  @c_errmsg            = @c_sc_errmsg           OUTPUT  
      
      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 52003
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(ValidateTrackNo). '  
         GOTO QUIT
      END
      
      SET @c_sc_EPackSkipTracknoCheck = ''
      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      
      EXEC [dbo].[nspGetRight]
               @c_Facility          = @c_Facility
            ,  @c_StorerKey         = @c_StorerKey
            ,  @c_sku               = ''
            ,  @c_ConfigKey         = 'EPackSkipTracknoCheck'
            ,  @b_Success           = @n_sc_Success                  OUTPUT     
            ,  @c_authority         = @c_sc_EPackSkipTracknoCheck    OUTPUT    
            ,  @n_err               = @n_sc_err                      OUTPUT    
            ,  @c_errmsg            = @c_sc_errmsg                   OUTPUT  
      
      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 52004
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(ValidateTrackNo). '  
         GOTO QUIT
      END
      
      SET @c_IsTrackingNoMandatory = CASE WHEN @c_sc_ValidateTrackNo = '1' OR @c_sc_EPackSkipTracknoCheck = '0' THEN '1' ELSE '0' END
      
      SET @c_sc_CtnTypeInput = ''
      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      
      EXEC [dbo].[nspGetRight]
               @c_Facility          = @c_Facility
            ,  @c_StorerKey         = @c_StorerKey
            ,  @c_sku               = ''
            ,  @c_ConfigKey         = 'CtnTypeInput'
            ,  @b_Success           = @n_sc_Success      OUTPUT     
            ,  @c_authority         = @c_sc_CtnTypeInput OUTPUT    
            ,  @n_err               = @n_sc_err          OUTPUT    
            ,  @c_errmsg            = @c_sc_errmsg       OUTPUT  
      
      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 52005
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(CtnInputType). '  
         GOTO QUIT
      END
      
      SET @c_IsCartonTypeMandatory = CASE WHEN @c_sc_CtnTypeInput = '1' THEN '1' ELSE '0' END
      
      
      SET @c_sc_WeightInput = ''
      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      
      EXEC [dbo].[nspGetRight]
               @c_Facility          = @c_Facility
            ,  @c_StorerKey         = @c_StorerKey
            ,  @c_sku               = ''
            ,  @c_ConfigKey         = 'WeightInput'
            ,  @b_Success           = @n_sc_Success      OUTPUT     
            ,  @c_authority         = @c_sc_WeightInput  OUTPUT    
            ,  @n_err               = @n_sc_err          OUTPUT    
            ,  @c_errmsg            = @c_sc_errmsg       OUTPUT  
      
      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 52006
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(WeightInput). '  
         GOTO QUIT
      END
      
      SET @c_IsWeightMandatory = CASE WHEN @c_sc_WeightInput = '1' THEN '1' ELSE '0' END
      
      SET @c_sc_AutoCalcWeight = ''
      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      
      EXEC [dbo].[nspGetRight]
               @c_Facility          = @c_Facility
            ,  @c_StorerKey         = @c_StorerKey
            ,  @c_sku               = ''
            ,  @c_ConfigKey         = 'AutoCalcWeight'
            ,  @b_Success           = @n_sc_Success         OUTPUT     
            ,  @c_authority         = @c_sc_AutoCalcWeight  OUTPUT    
            ,  @n_err               = @n_sc_err             OUTPUT    
            ,  @c_errmsg            = @c_sc_errmsg          OUTPUT  
      
      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 52006
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(AutoCalcWeight). '  
         GOTO QUIT
      END
      
      SET @c_IsAutoWeightCalc = CASE WHEN @c_sc_AutoCalcWeight = '1' THEN '1' ELSE '0' END

      SET @c_sc_ECOMAutoPackConfirm = ''
      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      
      EXEC [dbo].[nspGetRight]
               @c_Facility          = @c_Facility
            ,  @c_StorerKey         = @c_StorerKey
            ,  @c_sku               = ''
            ,  @c_ConfigKey         = 'ECOMAutoPackConfirm'
            ,  @b_Success           = @n_sc_Success               OUTPUT     
            ,  @c_authority         = @c_sc_ECOMAutoPackConfirm   OUTPUT    
            ,  @n_err               = @n_sc_err                   OUTPUT    
            ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
      
      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 52007
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(AutoPackConfirm). '  
         GOTO QUIT
      END
      
      SET @c_IsAutoPackConfirm = CASE WHEN @c_sc_ECOMAutoPackConfirm IN ('1', '3') THEN '1' ELSE '0' END

      SET @c_sc_CtnTypeConvert = ''
      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      
      EXEC [dbo].[nspGetRight]
               @c_Facility          = @c_Facility
            ,  @c_StorerKey         = @c_StorerKey
            ,  @c_sku               = ''
            ,  @c_ConfigKey         = 'CtnTypeConvert'
            ,  @b_Success           = @n_sc_Success               OUTPUT     
            ,  @c_authority         = @c_sc_CtnTypeConvert        OUTPUT    
            ,  @n_err               = @n_sc_err                   OUTPUT    
            ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
      
      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 52008
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(AutoPackConfirm). '  
         GOTO QUIT
      END

      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      SET @c_IsCaptureLabelNo = ''
      SET @c_CaptureLabelNoFunc = ''

      EXEC [dbo].[nspGetRight]
               @c_Facility          = @c_Facility
            ,  @c_StorerKey         = @c_StorerKey
            ,  @c_sku               = ''
            ,  @c_ConfigKey         = 'EPACKSINGLECAPTURELABELNO'
            ,  @b_Success           = @n_sc_Success               OUTPUT     
            ,  @c_authority         = @c_IsCaptureLabelNo         OUTPUT    
            ,  @n_err               = @n_sc_err                   OUTPUT    
            ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
            ,  @c_Option5           = @c_CaptureLabelNoFunc       OUTPUT 
      
      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 52008
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(EPACKSINGLECAPTURELABELNO). '  
         GOTO QUIT
      END

      SET @n_sc_Success = 0
      SET @n_sc_err = 0
      SET @c_sc_errmsg = ''
      SET @c_IsVASMandatory = ''

      EXEC [dbo].[nspGetRight]
               @c_Facility          = @c_Facility
            ,  @c_StorerKey         = @c_StorerKey
            ,  @c_sku               = ''
            ,  @c_ConfigKey         = 'EPACKVASActivity'
            ,  @b_Success           = @n_sc_Success               OUTPUT     
            ,  @c_authority         = @c_IsVASMandatory           OUTPUT    
            ,  @n_err               = @n_sc_err                   OUTPUT    
            ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
      
      IF @n_sc_Success <> 1   
      BEGIN   
         SET @n_Continue = 3 
         SET @n_ErrNo = 52009
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(EPACKVASActivity). '  
         GOTO QUIT
      END

      SET @c_IsSystemSugCartonType = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKSuggestCartonType') -- Alex04

      SELECT 'IsSerialNoMandatory'     , @c_IsSerialNoMandatory         UNION ALL
      SELECT 'IsPackQRFMandatory'      , @c_IsPackQRFMandatory          UNION ALL
      SELECT 'PackQRF_RegEx'           , @c_PackQRF_RegEx               UNION ALL
      SELECT 'IsTrackingNoMandatory'   , @c_IsTrackingNoMandatory       UNION ALL
      SELECT 'IsCartonTypeMandatory'   , @c_IsCartonTypeMandatory       UNION ALL
      SELECT 'IsConvertCartonType'     , @c_sc_CtnTypeConvert           UNION ALL
      SELECT 'IsWeightMandatory'       , @c_IsWeightMandatory           UNION ALL
      SELECT 'IsAutoWeightCalc'        , @c_IsAutoWeightCalc            UNION ALL
      SELECT 'IsAutoPackConfirm'       , @c_IsAutoPackConfirm           UNION ALL
      SELECT 'IsCaptureLabelNo'        , @c_IsCaptureLabelNo            UNION ALL
      SELECT 'CaptureLabelNoFunc'      , @c_CaptureLabelNoFunc          UNION ALL
      SELECT 'IsVASMandatory'          , @c_IsVASMandatory              UNION ALL
      --Alex01 Begin
      SELECT 'IsLottableMandatory'     , @c_IsLottableMandatory         UNION ALL
      SELECT 'LottableFieldLabel'      , @c_LottableFieldLabel          UNION ALL
      --Alex01 End
      SELECT 'ECOMPShowSKUIMG'         , @c_ECOMPShowSKUIMG             UNION ALL
      SELECT 'ECOMPNoOfIMG'            , @c_ECOMPNoOfIMG                UNION ALL
      SELECT 'SerialNo_RegEx'          , @c_SerialNo_Regex              UNION ALL      --Alex03 
      SELECT 'IsSystemSugCartonType'   , @c_IsSystemSugCartonType                      --Alex04


   END
   IF @c_PackMode = 'M'
   BEGIN
      --PAC-7 Packing Rules for Order level
      IF @c_SKU = ''
      BEGIN
         SET @n_sc_Success = 0
         SET @c_EpackForceMultiPackByOrd = ''
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''

         EXEC [dbo].[nspGetRight]
              @c_Facility          = @c_Facility
           ,  @c_StorerKey         = @c_StorerKey
           ,  @c_sku               = ''
           ,  @c_ConfigKey         = 'EpackForceMultiPackByOrd'
           ,  @b_Success           = @n_sc_Success                   OUTPUT     
           ,  @c_authority         = @c_EpackForceMultiPackByOrd     OUTPUT    
           ,  @n_err               = @n_sc_err                       OUTPUT    
           ,  @c_errmsg            = @c_sc_errmsg                    OUTPUT  
      
         IF @n_sc_Success <> 1   
         BEGIN   
           SET @n_Continue = 3 
           SET @n_ErrNo = 52021
           SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(EpackForceMultiPackByOrd). '  
           GOTO QUIT
         END

         SET @n_sc_Success = 0
         SET @c_EPACKCloseCartonPrint = ''
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''

         EXEC [dbo].[nspGetRight]
              @c_Facility          = @c_Facility
           ,  @c_StorerKey         = @c_StorerKey
           ,  @c_sku               = ''
           ,  @c_ConfigKey         = 'EPACKCloseCartonPrint'
           ,  @b_Success           = @n_sc_Success                   OUTPUT     
           ,  @c_authority         = @c_EPACKCloseCartonPrint        OUTPUT    
           ,  @n_err               = @n_sc_err                       OUTPUT    
           ,  @c_errmsg            = @c_sc_errmsg                    OUTPUT  
      
         IF @n_sc_Success <> 1   
         BEGIN   
           SET @n_Continue = 3 
           SET @n_ErrNo = 52023
           SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(EPACKCloseCartonPrint). '  
           GOTO QUIT
         END

         --EPACKNewCartonSkipPrint
         SET @c_EPACKNewCartonSkipPrint = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKNewCartonSkipPrint')

         SET @n_sc_Success = 0
         SET @c_PackUpdateEstTotalCtn = ''
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''

         EXEC [dbo].[nspGetRight]
              @c_Facility          = @c_Facility
           ,  @c_StorerKey         = @c_StorerKey
           ,  @c_sku               = ''
           ,  @c_ConfigKey         = 'PackUpdateEstTotalCtn'
           ,  @b_Success           = @n_sc_Success                   OUTPUT     
           ,  @c_authority         = @c_PackUpdateEstTotalCtn        OUTPUT    
           ,  @n_err               = @n_sc_err                       OUTPUT    
           ,  @c_errmsg            = @c_sc_errmsg                    OUTPUT  
      
         IF @n_sc_Success <> 1   
         BEGIN   
           SET @n_Continue = 3 
           SET @n_ErrNo = 52023
           SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(PackUpdateEstTotalCtn). '  
           GOTO QUIT
         END
         
         SET @c_sc_EPACKQRF = ''
         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''

         EXEC [dbo].[nspGetRight]
              @c_Facility          = @c_Facility
           ,  @c_StorerKey         = @c_StorerKey
           ,  @c_sku               = ''
           ,  @c_ConfigKey         = 'EPACKQRF'
           ,  @b_Success           = @n_sc_Success          OUTPUT     
           ,  @c_authority         = @c_sc_EPACKQRF         OUTPUT    
           ,  @n_err               = @n_sc_err              OUTPUT    
           ,  @c_errmsg            = @c_sc_errmsg           OUTPUT  
      
         IF @n_sc_Success <> 1   
         BEGIN   
           SET @n_Continue = 3 
           SET @n_ErrNo = 52024
           SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(EPACKQRF). '  
           GOTO QUIT
         END
         
         SET @c_IsPackQRFMandatory = CASE WHEN @c_sc_EPACKQRF IN ('1', '3') THEN '1' ELSE '0' END
         
         IF @c_sc_EPACKQRF IN ('1', '3')
         BEGIN
            SET @c_PackQRF_RegEx = '^\d{13}?$'  

            SELECT @c_PackQRF_RegEx = ISNULL(CL.Long,'')   
            FROM CODELKUP CL(NOLOCK)  
            WHERE CL.Listname = 'REQEXP'  
            AND CL.Storerkey = @c_Storerkey  
            AND CL.Code = 'QRCode'  
         END

         SET @c_sc_ValidateTrackNo = ''
         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         
         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'ValidateTrackNo'
               ,  @b_Success           = @n_sc_Success          OUTPUT     
               ,  @c_authority         = @c_sc_ValidateTrackNo  OUTPUT    
               ,  @n_err               = @n_sc_err              OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg           OUTPUT  
         
         IF @n_sc_Success <> 1   
         BEGIN   
            SET @n_Continue = 3 
            SET @n_ErrNo = 52025
            SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(ValidateTrackNo). '  
            GOTO QUIT
         END
         
         SET @c_sc_EPackSkipTracknoCheck = ''
         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         
         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'EPackSkipTracknoCheck'
               ,  @b_Success           = @n_sc_Success                  OUTPUT     
               ,  @c_authority         = @c_sc_EPackSkipTracknoCheck    OUTPUT    
               ,  @n_err               = @n_sc_err                      OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg                   OUTPUT  
         
         IF @n_sc_Success <> 1   
         BEGIN   
            SET @n_Continue = 3 
            SET @n_ErrNo = 52026
            SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(ValidateTrackNo). '  
            GOTO QUIT
         END
         
         SET @c_IsTrackingNoMandatory = CASE WHEN @c_sc_ValidateTrackNo = '1' OR @c_sc_EPackSkipTracknoCheck = '0' THEN '1' ELSE '0' END
         
         SET @c_sc_CtnTypeInput = ''
         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         
         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'CtnTypeInput'
               ,  @b_Success           = @n_sc_Success      OUTPUT     
               ,  @c_authority         = @c_sc_CtnTypeInput OUTPUT    
               ,  @n_err               = @n_sc_err          OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg       OUTPUT  
         
         IF @n_sc_Success <> 1   
         BEGIN   
            SET @n_Continue = 3 
            SET @n_ErrNo = 52027
            SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(CtnInputType). '  
            GOTO QUIT
         END
         
         SET @c_IsCartonTypeMandatory = CASE WHEN @c_sc_CtnTypeInput = '1' THEN '1' ELSE '0' END
         
         
         SET @c_sc_WeightInput = ''
         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         
         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'WeightInput'
               ,  @b_Success           = @n_sc_Success      OUTPUT     
               ,  @c_authority         = @c_sc_WeightInput  OUTPUT    
               ,  @n_err               = @n_sc_err          OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg       OUTPUT  
         
         IF @n_sc_Success <> 1   
         BEGIN   
            SET @n_Continue = 3 
            SET @n_ErrNo = 52028
            SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(WeightInput). '  
            GOTO QUIT
         END
         
         SET @c_IsWeightMandatory = CASE WHEN @c_sc_WeightInput = '1' THEN '1' ELSE '0' END
         
         SET @c_sc_AutoCalcWeight = ''
         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         
         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'AutoCalcWeight'
               ,  @b_Success           = @n_sc_Success         OUTPUT     
               ,  @c_authority         = @c_sc_AutoCalcWeight  OUTPUT    
               ,  @n_err               = @n_sc_err             OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg          OUTPUT  
         
         IF @n_sc_Success <> 1   
         BEGIN   
            SET @n_Continue = 3 
            SET @n_ErrNo = 52029
            SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(AutoCalcWeight). '  
            GOTO QUIT
         END
         
         SET @c_IsAutoWeightCalc = CASE WHEN @c_sc_AutoCalcWeight = '1' THEN '1' ELSE '0' END

         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         SET @c_PackChkCartonWeight = ''
         SET @c_PackChkCartonWeightValue = ''

         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'PackChkCartonWeight'
               ,  @b_Success           = @n_sc_Success               OUTPUT     
               ,  @c_authority         = @c_PackChkCartonWeight      OUTPUT    
               ,  @n_err               = @n_sc_err                   OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
               ,  @c_Option1           = @c_PackChkCartonWeightValue OUTPUT 

         SET @c_PackChkCartonWeightValue = CASE WHEN @c_PackChkCartonWeight = '2' THEN @c_PackChkCartonWeightValue ELSE '' END

         SET @c_sc_ECOMAutoPackConfirm = ''
         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         
         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'ECOMAutoPackConfirm'
               ,  @b_Success           = @n_sc_Success               OUTPUT     
               ,  @c_authority         = @c_sc_ECOMAutoPackConfirm   OUTPUT    
               ,  @n_err               = @n_sc_err                   OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
         
         IF @n_sc_Success <> 1   
         BEGIN   
            SET @n_Continue = 3 
            SET @n_ErrNo = 52030
            SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(AutoPackConfirm). '  
            GOTO QUIT
         END

         SET @c_IsAutoPackConfirm = CASE WHEN @c_sc_ECOMAutoPackConfirm IN ('1', '3') THEN '1' ELSE '0' END

         SET @c_sc_CtnTypeConvert = ''
         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         
         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'CtnTypeConvert'
               ,  @b_Success           = @n_sc_Success               OUTPUT     
               ,  @c_authority         = @c_sc_CtnTypeConvert        OUTPUT    
               ,  @n_err               = @n_sc_err                   OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
         
         IF @n_sc_Success <> 1   
         BEGIN   
            SET @n_Continue = 3 
            SET @n_ErrNo = 52031
            SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(AutoPackConfirm). '  
            GOTO QUIT
         END

         SET @n_sc_Success = 0
         SET @n_sc_err = 0
         SET @c_sc_errmsg = ''
         SET @c_IsVASMandatory = ''

         EXEC [dbo].[nspGetRight]
                  @c_Facility          = @c_Facility
               ,  @c_StorerKey         = @c_StorerKey
               ,  @c_sku               = ''
               ,  @c_ConfigKey         = 'EPACKVASActivity'
               ,  @b_Success           = @n_sc_Success               OUTPUT     
               ,  @c_authority         = @c_IsVASMandatory           OUTPUT    
               ,  @n_err               = @n_sc_err                   OUTPUT    
               ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
         
         IF @n_sc_Success <> 1   
         BEGIN   
            SET @n_Continue = 3 
            SET @n_ErrNo = 52032
            SET @c_ErrMsg = CONVERT(CHAR(5),@n_sc_err) + '. Error Executing nspGetRight(EPACKVASActivity). '  
            GOTO QUIT
         END         

         SET @c_IsSystemSugCartonType = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKSuggestCartonType') -- Alex04

         SELECT 'EpackForceMultiPackByOrd', @c_EpackForceMultiPackByOrd    UNION ALL
         SELECT 'EPACKCloseCartonPrint '  , @c_EPACKCloseCartonPrint       UNION ALL
         SELECT 'EPACKNewCartonSkipPrint' , @c_EPACKNewCartonSkipPrint     UNION ALL
         SELECT 'PackUpdateEstTotalCtn'   , @c_PackUpdateEstTotalCtn       UNION ALL
         SELECT 'IsPackQRFMandatory'      , @c_IsPackQRFMandatory          UNION ALL
         SELECT 'PackQRF_RegEx'           , @c_PackQRF_RegEx               UNION ALL
         SELECT 'IsTrackingNoMandatory'   , @c_IsTrackingNoMandatory       UNION ALL
         SELECT 'IsCartonTypeMandatory'   , @c_IsCartonTypeMandatory       UNION ALL
         SELECT 'IsConvertCartonType'     , @c_sc_CtnTypeConvert           UNION ALL
         SELECT 'IsWeightMandatory'       , @c_IsWeightMandatory           UNION ALL
         SELECT 'IsAutoWeightCalc'        , @c_IsAutoWeightCalc            UNION ALL
         SELECT 'IsAutoPackConfirm'       , @c_IsAutoPackConfirm           UNION ALL
         SELECT 'IsVASMandatory'          , @c_IsVASMandatory              UNION ALL 
         SELECT 'PackChkCartonWeight'     , @c_PackChkCartonWeightValue    UNION ALL
         SELECT 'ECOMPShowSKUIMG'         , @c_ECOMPShowSKUIMG             UNION ALL
         SELECT 'ECOMPNoOfIMG'            , @c_ECOMPNoOfIMG                UNION ALL
         SELECT 'IsSystemSugCartonType'   , @c_IsSystemSugCartonType                      --Alex04
      END
      --PAC-7 Get Packing Rules After SKU Validation
      ELSE
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

         --check if SerialNumber is mandatory
         SELECT @c_IsSerialNoMandatory = CASE 
               WHEN ISNULL(RTRIM([SerialNoCapture]), '') IN ('1','3')  THEN '1' ELSE '0' END
               ,@c_LottableFieldLabel = ISNULL(RTRIM(Lottable03Label), '')
         FROM [dbo].[SKU] WITH (NOLOCK) 
         WHERE StorerKey = @c_StorerKey
         AND SKU = @c_SKU

         SET @c_SQLQuery = 'SELECT @c_IsSerialNoMandatory = CASE' + CHAR(13) 
                         + '                                      WHEN ISNULL(RTRIM([SerialNoCapture]), '''') IN (''1'',''3'')  THEN ''1'' ELSE ''0'' END' + CHAR(13) 
                         + '      ,@c_LottableFieldLabel = ' + CASE WHEN @c_sc_ToOption1 IN ('01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13', '14', '15')
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

         SET @c_IsLottableMandatory = CASE WHEN @c_sc_SValue IN ('1', '2', '3') AND @c_IsSerialNoMandatory <> '1' THEN '1' ELSE '0' END

         SELECT 'IsSerialNoMandatory'     , @c_IsSerialNoMandatory         UNION ALL
         SELECT 'IsLottableMandatory'     , @c_IsLottableMandatory         UNION ALL
         SELECT 'LottableFieldLabel'      , @c_LottableFieldLabel
      END
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