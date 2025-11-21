SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
  
/************************************************************************/        
/* Stored Proc: [API].[isp_ECOMP_PackSaveEnd]                           */        
/* Creation Date: 11-JUN-2019                                           */        
/* Copyright: Maersk                                                    */        
/* Written by: Wan                                                      */        
/*                                                                      */        
/* Purpose: Performance Tune                                            */        
/*        :                                                             */        
/* Called By: ECOM PackHeader - ue_saveend                              */        
/*          :                                                           */        
/* PVCS Version: 1.5                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date           Author      Purposes                                  */  
/* 11-Apr-2023    Allen       #JIRA PAC-4 Initial                       */ 
/************************************************************************/        
CREATE   PROC [API].[isp_ECOMP_PackSaveEnd]         
           @c_PickSlipNo         NVARCHAR(10)        
         , @c_Orderkey           NVARCHAR(10)          
         , @n_SaveResult         INT            = '0'                   
         , @c_SaveEndValidation  NCHAR(1)       = 'N'         
         , @b_Success            INT            OUTPUT        
         , @n_Err                INT            OUTPUT        
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT        
AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE          
           @n_StartTCnt       INT            = @@TRANCOUNT        
         , @n_Continue        INT            = 1        
        
         , @n_RowId           INT            = 1        
         , @n_CartonNo_PD     INT            = 0        
         , @n_CartonNo        INT            = 0        
         , @c_Storerkey       NVARCHAR(15)   = ''        
         , @c_TrackingNo      NVARCHAR(40)   = ''           --(Wan03) -- Change @c_TrackingNo to @c_TrackingNo     
         , @c_TrackingNo_ORD  NVARCHAR(40)   = ''           --(Wan03) -- Change @c_TrackingNo to @c_TrackingNo_ORD     
         , @c_WarningMsg      NVARCHAR(255)  = ''        
        
         , @c_ValidateTrackNo NVARCHAR(10)   = ''        
         , @CUR_PIF           CURSOR       
             
         , @c_EPackSkipTracknoCheck    NVARCHAR(10)   = ''   --WL01      
         , @c_Facility                 NVARCHAR(5)    = ''   --WL02   
  
         , @c_CartonType               NVARCHAR(30)   = ''   --KY01  
         , @n_Weight                   FLOAT          = 0.00 --KY01                                     
         , @c_CtnTypeInput             NVARCHAR(30)   = ''   --KY01  
         , @c_WeightInput              NVARCHAR(30)   = ''   --KY01    
        
        
   SET @n_err      = 0        
   SET @c_errmsg   = ''        
        
   --WHILE @@TRANCOUNT > 0         
   --BEGIN        
   --   COMMIT TRAN        
   --END        
        
   SELECT     
          @c_TrackingNo_ORD =CASE WHEN ISNULL(RTRIM(OH.TrackingNo),'') <> ''        --(Wan03)         
                                 THEN OH.TrackingNo         
  ELSE ISNULL(RTRIM(OH.UserDefine04),'')         
                                 END      
      ,   @c_Storerkey  = OH.Storerkey    
      ,   @c_Facility   = OH.Facility   --WL02        
   FROM ORDERS OH WITH (NOLOCK)        
   WHERE OH.Orderkey = @c_Orderkey        
           
   SELECT @c_ValidateTrackNo = dbo.fnc_GetRight('', @c_Storerkey, '', 'ValidateTrackNo')        
   SELECT @c_EPackSkipTracknoCheck = dbo.fnc_GetRight('', @c_Storerkey, '', 'EPackSkipTracknoCheck')   --WL01      
    
   --WL02 S    
   IF ISNULL(@c_ValidateTrackNo,'') IN ('','0')    
      SELECT @c_ValidateTrackNo = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateTrackNo')       
    
   IF ISNULL(@c_EPackSkipTracknoCheck,'') IN ('','0')    
      SELECT @c_EPackSkipTracknoCheck = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPackSkipTracknoCheck')      
   --WL02 E    
     
   SELECT @c_CtnTypeInput = dbo.fnc_GetRight (@c_Facility, @c_Storerkey, '', 'CtnTypeInput')               --KY01   
   SELECT @c_WeightInput  = dbo.fnc_GetRight (@c_Facility, @c_Storerkey, '', 'WeightInput')                --KY01   
  
    
   SET @CUR_PIF = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
   SELECT DISTINCT PD.CartonNo                  --(Wan01)        
         ,PIF.CartonNo        
         ,TrackingNo = CASE WHEN ISNULL(PIF.TrackingNo,'') <> '' THEN RTRIM(PIF.TrackingNo) ELSE ISNULL(RTRIM(PIF.RefNo),'') END --(Wan03)    
         ,CartonType = PIF.CartonType                                                                     --KY01                                                                                                                        --   
         ,WEIGHT     = PIF.[Weight]                                                                       --KY01    
   FROM PACKDETAIL PD WITH (NOLOCK)        
   LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON (PD.PickSlipNo = PIF.PickSlipNo)        
                                        AND(PD.CartonNo = PIF.CartonNo)        
   WHERE PD.PickSlipNo = @c_PickSlipNo        
   ORDER BY PD.CartonNo        
        
   OPEN @CUR_PIF        
   FETCH NEXT FROM @CUR_PIF INTO @n_CartonNo_PD        
                               , @n_CartonNo        
                               , @c_TrackingNo                    --(Wan03)   
                               , @c_CartonType                    -- KY01     
                               , @n_Weight                        -- KY01                                                                    --                                
                                            
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      -- Update TrackingNo if ECOM Packing successfully Saved, 0:NOWORK, 1:SUCCESS, 2:No Save When Prompt To Save and ResetData        
      IF @n_SaveResult = 1 AND @c_ValidateTrackNo= '0' AND @n_CartonNo IS NOT NULL        
      BEGIN        
         IF @c_TrackingNo = '' AND @c_TrackingNo_ORD <> ''        --(Wan03)     
         BEGIN        
            UPDATE PACKINFO         
            SET TrackingNo = @c_TrackingNo_ORD                    --(Wan03)      
               ,Trafficcop = NULL                                 --(Wan03)    
               ,EditWho   = SUSER_SNAME()                         --(Wan03)    
               ,EditDate   = GETDATE()                            --(Wan03)    
            WHERE PickSlipNo = @c_PickSlipNo        
            AND CartonNo = @n_CartonNo        
            AND (TrackingNo = '' OR TrackingNo IS NULL)      --(Wan03)    
        
            IF @@ERROR <> 0        
            BEGIN        
               SET @n_Continue = 3        
               SET @n_Err    = 67890        
               SET @c_ErrMsg = ERROR_MESSAGE()        
               SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + ': Error Update PACKINFO Table. (isp_ECOMP_PackSaveEnd) '        
                             + '(' + @c_ErrMsg + ')'        
        
               GOTO QUIT_SP        
            END        
        
            SET @c_TrackingNo = @c_TrackingNo_ORD                 --(Wan03)     
         END        
      END        
        
      IF @c_SaveEndValidation = 'Y' AND @n_Continue = 1        
      BEGIN        
         IF @n_CartonNo IS NULL        
         BEGIN        
            SET @n_Continue = 2        
            SET @c_WarningMsg = 'Missing Carton #: ' + CONVERT(NVARCHAR(10), @n_CartonNo_PD) + ' in PackInfo'        
         END        
        
         IF @n_Continue = 1 AND @n_RowId = 1 AND @c_TrackingNo <> @c_TrackingNo_ORD AND @c_TrackingNo_ORD <> ''   --(Wan01)  --(Wan03)        
         BEGIN        
            SET @n_Continue = 2        
            SET @c_WarningMsg = 'Tracking # not match on first CartonNo. Carton #: ' + CONVERT(NVARCHAR(10), @n_CartonNo)        
         END        
        
         IF @n_Continue = 1 AND @c_TrackingNo = '' AND ISNULL(@c_EPackSkipTracknoCheck,'') IN ('','0')   --WL01   --(Wan03)    
         BEGIN        
            SET @n_Continue = 2        
            SET @c_WarningMsg = 'Tracking # is required. Carton #: ' + CONVERT(NVARCHAR(10), @n_CartonNo)        
         END      
           
         ----KY01 - START  
         IF @n_Continue = 1 AND @c_CartonType = '' AND @c_CtnTypeInput = 1                        
         BEGIN        
            SET @n_Continue = 2        
            SET @c_WarningMsg = 'Carton Type is required. Carton #: ' + CONVERT(NVARCHAR(10), @n_CartonNo)        
         END  
  
         IF @n_Continue = 1 AND @n_Weight = 0.00 AND @c_WeightInput = 1                        
         BEGIN        
            SET @n_Continue = 2        
            SET @c_WarningMsg = 'Weight is required. Carton #: ' + CONVERT(NVARCHAR(10), @n_CartonNo)        
         END           
         ----KY01 - END    
        
         IF (@n_SaveResult IN (0,2) OR @c_ValidateTrackNo= '1') AND @n_Continue = 2        
         BEGIN        
            --GOTO QUIT_SP          --(Wan02)    
            GOTO POST_SAVEEND       --(Wan02)        
         END        
      END        
        
      NEXT_REC:        
      SET @n_RowId = @n_RowId + 1        
      FETCH NEXT FROM @CUR_PIF INTO @n_CartonNo_PD        
                                 ,  @n_CartonNo        
                                 ,  @c_TrackingNo                 --(Wan03)   
                                 ,  @c_CartonType                 -- KY01     
                                 ,  @n_Weight                     -- KY01                                                                    --         
   END        
   CLOSE @CUR_PIF        
   DEALLOCATE @CUR_PIF         
        
   --(Wan02) - START    
   POST_SAVEEND:    
   SET @b_Success = 0          
   EXECUTE dbo.isp_PostEPackSaveEnd_Wrapper         
           @c_PickSlipNo= @c_PickSlipNo        
         , @b_Success   = @b_Success      OUTPUT          
         , @n_Err       = @n_err          OUTPUT           
         , @c_ErrMsg    = @c_errmsg       OUTPUT     
         , @c_WarningMsg= @c_WarningMsg   OUTPUT         
        
   IF @n_err <> 0          
   BEGIN         
      SET @n_continue= 3         
      SET @n_err = 67900       
      SET @c_errmsg = CONVERT(char(5),@n_err)        
      SET @c_errmsg = 'NSQL'+CONVERT(char(6), @n_err)+ ': Execute isp_PostEPackSaveEnd_Wrapper Failed. (isp_ECOMP_PackSaveEnd) '         
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '        
      GOTO QUIT_SP                              
   END         
   --(Wan02) - END    
QUIT_SP:        
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_Success = 0        
      --IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt        
      --BEGIN        
      --   ROLLBACK TRAN        
      --END        
      --ELSE        
      --BEGIN        
      --   WHILE @@TRANCOUNT > @n_StartTCnt        
      --   BEGIN        
      --      COMMIT TRAN        
      --   END        
      --END        
        
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOMP_PackSaveEnd'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
   END        
   ELSE        
   BEGIN        
      SET @b_Success = 1        
      --WHILE @@TRANCOUNT > @n_StartTCnt        
      --BEGIN        
      --   COMMIT TRAN        
      --END        
        
      IF @c_WarningMsg <> ''        
      BEGIN        
         SET @b_Success = 2        
         SET @c_ErrMsg = @c_WarningMsg        
      END        
   END        
        
   --WHILE @@TRANCOUNT < @n_StartTCnt        
   --BEGIN        
   --   BEGIN TRAN        
   --END        
END -- procedure     
GO