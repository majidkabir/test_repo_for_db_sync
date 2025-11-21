SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_EPack_Validate_RFIDValues                           */  
/* Creation Date: 2020-12-24                                            */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose:  WMS-15244 - [CN] NIKE_O2_Ecom_packing_RFID_CR              */  
/*        :                                                             */  
/* Called By:                                                           */  
/*          :                                                           */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2020-12-14  Wan      1.0   Created                                   */  
/* 2022-11-11  Wan01    1.1   WMS-21150 - [CN] Nike Ecom Packing        */  
/*                            Chinesization                             */  
/* 2022-11-11  Wan01    1.1   DevOps Combine Script                     */  
/* 2023-03-01  Wan02    1.2   WMS-21512 - [CN] NIKE_NFC_RFID_ECOMPACKING*/  
/*                            _CR_V1.0                                  */  
/************************************************************************/  
CREATE    PROC isp_EPack_Validate_RFIDValues  
           @c_PickSlipNo   NVARCHAR(10)  
         , @n_CartonNo     INT  
         , @c_LabelLine    NVARCHAR(5)         
         , @c_RFIDNos      NVARCHAR(1000)= ''   --Multiple RFIDNo seperate by '|'   
         , @c_TidNos       NVARCHAR(1000)= ''   --Multiple TIDNo  seperate by '|'   
         , @b_Success      INT          = 1  OUTPUT  
         , @n_Err          INT          = 0  OUTPUT  
         , @c_ErrMsg       NVARCHAR(255)= '' OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT = @@TRANCOUNT  
         , @n_Continue        INT = 1  
  
         , @c_Facility        NVARCHAR(5)  = ''  
         , @c_Storerkey       NVARCHAR(15) = ''  
           
         , @c_TagReader       NVARCHAR(10) = ''          --(Wan02) 
           
   DECLARE @TRFID TABLE   
         ( RowRef             INT      NOT NULL IDENTITY(1,1) PRIMARY KEY  
         , RFIDNo             NVARCHAR(100) NOT NULL DEFAULT('')  
         , TIDNo              NVARCHAR(100) NOT NULL DEFAULT('')  
         )  
     
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
   INSERT INTO @TRFID ( RFIDNo )  
   SELECT R.VALUE  
   FROM string_split (@c_RFIDNos, '|') R  
  
   INSERT INTO @TRFID ( TIDNo )  
   SELECT T.VALUE  
   FROM string_split (@c_TIDNos, '|') T  
     
   SET @c_Storerkey = ''  
   SELECT @c_Storerkey = PH.Storerkey                    --(Wan02)  
   FROM PACKHEADER PH WITH (NOLOCK)  
   WHERE PH.PickSlipNo = @c_PickSlipNo   

   SET @c_TagReader = 'RFID'                             --(Wan02) 
   IF @c_TIDNos = 'NFC' OR CHARINDEX('NFC|', @c_TIDNos,1) > 0
   BEGIN
      SET @c_TagReader = 'NFC' 
   END
           
   IF EXISTS ( SELECT 1  
               FROM PACKHEADER PH WITH (NOLOCK)   
               JOIN PACKQRF PQRF WITH (NOLOCK) ON PH.PickSlipNo = PQRF.PickSlipNo  
               JOIN @TRFID R ON R.RFIDNo = PQRF.RFIDNo AND R.RFIDNo <> ''  
               WHERE PH.Storerkey= @c_Storerkey  
               AND   PH.[Status] < '9'  
               )   
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 80010     
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ': '  
                   +dbo.fnc_GetLangMsgText(                 --(Wan01)  
                     'sp_EPack_RFID_VALD_UNIQ'                 
                   , 'Disallow to pack duplicate %s Tag'    --(Wan02)  
                   , @c_TagReader)                          --(Wan02)  
                   +'. (isp_EPack_Validate_RFIDValues)'     
      GOTO QUIT_SP    
   END   
                
   IF EXISTS ( SELECT 1  
               FROM ExternOrdersDetail EOD WITH (NOLOCK)  
               JOIN @TRFID R ON R.RFIDNo = EOD.RFIDNo AND R.RFIDNo <> ''  
               AND EOD.Storerkey = @c_Storerkey   
               AND EOD.[Status] <> '9'  
               )   
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 80020     
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ': '  
                   +dbo.fnc_GetLangMsgText(                 --(Wan01)  
                     'sp_EPack_RFID_VALD_Ship'  
                   , 'Disallow to pack unshipped %sTag.'    --(Wan02)  
                   , @c_TagReader)                          --(Wan02)  
                   +' (isp_EPack_Validate_RFIDValues)'     
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPack_Validate_RFIDValues'  
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