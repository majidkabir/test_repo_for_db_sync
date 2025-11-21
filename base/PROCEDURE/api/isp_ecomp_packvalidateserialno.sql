SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Proc: [API].[isp_ECOMP_PackValidateSerialNo]                    */  
/* Creation Date: 01-JUNE-2017                                            */  
/* Copyright: Maersk                                                      */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose: WMS-1816 - CN_DYSON_Exceed_ECOM PACKING                       */  
/*        :                                                               */  
/* Called By: nep_n_cst_packcarton_ecom                                   */  
/*          : ue_serialno_rule                                            */  
/* PVCS Version: 1.0                                                      */  
/*                                                                        */  
/* Version: 7.0                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date        Author   Ver   Purposes                                    */  
/* 21-SEP-2017 Wan01    1.0   WMS-2934 - [CR] CN_DYSON_EXCEED_ECOM        */  
/*                            Packing_CR                                  */  
/* 18-May-2021 WLChooi  1.1   WMS-17004 SerialNo Support Outbound (WL01)  */
/* 05-May-2023 Alex     2.0   Clone from WMS EXCEED                       */
/* 30-Jan-2024 Alex01   2.1   PAC-324 Remove packserialno validation      */
/* 10-Jul-2024 Alex02   2.2   PAC-348 config to allow scan dummy serial#  */
/**************************************************************************/  
CREATE   PROC [API].[isp_ECOMP_PackValidateSerialNo]
           @c_PickSlipNo         NVARCHAR(30)  
         , @c_Storerkey          NVARCHAR(15)  
         , @c_Sku                NVARCHAR(20)   
         , @c_SerialNo           NVARCHAR(30)   
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
           @n_StartTCnt                INT  
         , @n_Continue                 INT   
  
         , @n_Cnt                      INT  
         , @c_Status                   NVARCHAR(10)         --(Wan01)  
         , @c_OtherPickSlipNo          NVARCHAR(10)      = ''

         --Alex02 S
         , @c_EPackAllowDummySerial    NVARCHAR(30)      = '' 
         , @c_Facility                 NVARCHAR(5)       = ''
         --Alex02 E

   DECLARE @c_SerialNoCapture    NVARCHAR(10)   --WL01  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
   SET @n_Cnt = 0  

   --Alex02 S
   SELECT @c_Facility = ISNULL(RTRIM([Facility]), '')
   FROM [dbo].[Orders] WITH (NOLOCK) 
   WHERE OrderKey IN ( SELECT TOP 1 OrderKey 
      FROM [dbo].[PackTaskDetail] WITH (NOLOCK) 
      WHERE TaskBatchNo = (SELECT TOP 1 TaskBatchNo FROM [dbo].[PackHeader] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo ) )

   SELECT @c_EPackAllowDummySerial = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPackAllowDummySerial')    

   IF ISNULL(@c_EPackAllowDummySerial,'') = @c_SerialNo  AND @c_SerialNo <> ''  
   BEGIN  
      GOTO QUIT_SP  
   END  
   --Alex02 E

   SELECT @n_Cnt = 1  
         ,@c_Status = Status           --(Wan01)  
   FROM SERIALNO WITH (NOLOCK)  
   WHERE SerialNo = @c_SerialNo  
   AND   Storerkey= @c_Storerkey  
   AND   Sku = @c_Sku  
   --AND   Status = '1'                --(Wan01)  
  
   --WL01 S  
   SELECT @c_SerialNoCapture = SerialNoCapture  
   FROM SKU (NOLOCK)  
   WHERE SKU = @c_Sku  
   AND StorerKey = @c_Storerkey  
  
   IF @c_SerialNoCapture = '3'   --For Outbound, there is no record in serialno table until we scan serialno in ECOM Packing  
   BEGIN  
      SET @n_Cnt    = 1  
      SET @c_Status = '1'  
   END  
   --WL01 E  
  
   --(Wan01) - START  
   IF @n_Cnt = 1 AND @c_Status = 'H'     
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 60005  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ':'    
                    + 'Sku Serial # is on Hold.(isp_ECOMP_PackValidateSerialNo)'  
      GOTO QUIT_SP  
   END  
   --(Wan01) - END  
  
   IF @n_Cnt = 0 OR (@n_Cnt = 1 AND @c_Status <> '1')  --(Wan01)  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 60010  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ':'    
                    + 'Sku Serial # not found.(isp_ECOMP_PackValidateSerialNo)'  
      GOTO QUIT_SP  
   END   
  
   SET @n_Cnt = 0  
   SELECT @n_Cnt = 1  
   FROM PACKSERIALNO WITH (NOLOCK)  
   WHERE PickSlipNo = @c_PickSlipNo  
   AND   SerialNo = @c_SerialNo  
   AND   Storerkey= @c_Storerkey  
   AND   Sku = @c_Sku  
  
   IF @n_Cnt = 1  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 60020  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ':'    
                    + 'Serial # found for PickSlip #: ' + RTRIM(@c_PickSlipNo) +   
                    + '.(isp_ECOMP_PackValidateSerialNo)'  
      GOTO QUIT_SP  
   END   
  
  --Alex01 Begin
   /*SET @n_Cnt = 0  
   SELECT @n_Cnt = 1  
         ,@c_OtherPickSlipNo = ISNULL(RTRIM(PickSlipNo), '')
   FROM PACKSERIALNO WITH (NOLOCK)  
   WHERE PickSlipNo <> @c_PickSlipNo
   AND   SerialNo = @c_SerialNo  
   AND   Storerkey= @c_Storerkey  
   AND   Sku = @c_Sku  
  
   IF @n_Cnt = 1  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 60021  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ':'    
                    + 'Serial # found for PickSlip #: ' + RTRIM(@c_OtherPickSlipNo) +   
                    + '.(isp_ECOMP_PackValidateSerialNo)'  
      GOTO QUIT_SP  
   END*/
   --Alex01 End
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOMP_PackValidateSerialNo'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
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