SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_SerialNoDecode01]                  */              
/* Creation Date: 9-Jul-2024                                            */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose: For Converse QRCode Decoding                                */
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
/* 9-Jul-2024     Alex     #PAC-344 & PAC-350                           */
/************************************************************************/ 

CREATE   PROC [API].[isp_ECOMP_SerialNoDecode01]
   @c_PickSlipNo     NVARCHAR(10)
,  @c_Storerkey      NVARCHAR(15) 
,  @c_Sku            NVARCHAR(60)  
,  @c_SerialNumber   NVARCHAR(500)  OUTPUT
,  @c_QRCode         NVARCHAR(500)  OUTPUT      
,  @b_Success        INT            OUTPUT  
,  @n_Err            INT            OUTPUT  
,  @c_ErrMsg         NVARCHAR(255)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT                   ON  
   SET ANSI_NULLS                OFF  
   SET QUOTED_IDENTIFIER         OFF  
   SET CONCAT_NULL_YIELDS_NULL   OFF  
  
   DECLARE @n_StartTCnt             INT  
         , @n_Continue              INT   
      
         , @c_BanTemplate           NVARCHAR(30) = ''

         , @c_ALTSKU                NVARCHAR(20) = ''
         , @c_RETAILSKU             NVARCHAR(20) = ''
         , @c_MANUFACTURERSKU       NVARCHAR(20) = ''
         , @c_TimeStampNow          NVARCHAR(17) = FORMAT(GETDATE(), 'yyyyMMddHHmmssfff')

   SET @n_StartTCnt           = @@TRANCOUNT  
   SET @n_Continue            = 1  
   SET @n_Err                 = 0  
   SET @c_ErrMsg              = ''  
   SET @c_QRCode              = ''

   IF LEN(@c_SerialNumber) = 0
   BEGIN
      SET @n_Continue = 3  
      SET @n_Err      = 61001  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ':'    
                    + 'Sku Serial # cannot be blank.(isp_ECOMP_SerialNoDecode01)'  
      GOTO QUIT_SP 
   END

   IF @c_SerialNumber = @c_Sku
   BEGIN
      SET @n_Continue = 3  
      SET @n_Err      = 61002
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ':'    
                    + 'SerialNumber cannot be equal to sku.(isp_ECOMP_SerialNoDecode01)'  
      GOTO QUIT_SP 
   END

   --Check if QRCode is in BAN list..
   DECLARE CUR_BANLIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT ISNULL(RTRIM(Long), '')
      FROM [dbo].[Codelkup] WITH (NOLOCK)  
      WHERE ListName = 'QRBanValid' 
      AND StorerKey = @c_Storerkey
         
   OPEN CUR_BANLIST    
   FETCH NEXT FROM CUR_BANLIST INTO @c_BanTemplate  
   WHILE @@FETCH_STATUS <> -1      
   BEGIN   
      IF @c_BanTemplate = ''
      BEGIN
         GOTO NEXT_BANLIST
      END

      IF @c_SerialNumber LIKE @c_BanTemplate
      BEGIN
         SET @n_Continue = 3  
         SET @n_Err      = 61003  
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ':'    
                       + 'Invalid QR Code. QR code contain ' + @c_BanTemplate + '.(isp_ECOMP_SerialNoDecode01)'  
         GOTO QUIT_SP 
      END
      NEXT_BANLIST:
      FETCH NEXT FROM CUR_BANLIST INTO @c_BanTemplate  
   END      
   CLOSE CUR_BANLIST      
   DEALLOCATE CUR_BANLIST

   -- QRCode starting with 69..
   IF @c_SerialNumber LIKE '69%'
   BEGIN
      SELECT @c_ALTSKU          = ISNULL(RTRIM(ALTSKU) ,'')
            ,@c_RETAILSKU       = ISNULL(RTRIM(RETAILSKU) ,'')
            ,@c_MANUFACTURERSKU = ISNULL(RTRIM(MANUFACTURERSKU) ,'')
      FROM [dbo].[SKU] WITH (NOLOCK) 
      WHERE [StorerKey] = @c_Storerkey
      AND [SKU] = @c_SKU

      IF @c_SerialNumber = @c_ALTSKU OR @c_SerialNumber = @c_RETAILSKU OR @c_SerialNumber = @c_MANUFACTURERSKU
      BEGIN
         SET @n_Continue = 3  
         SET @n_Err      = 61003  
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ':'    
                       + 'QRCode matched with ALTSKU, RETAILSKU, MANUFACTURERSKU.(isp_ECOMP_SerialNoDecode01)'  
         GOTO QUIT_SP 
      END
   END

   SET @c_QRCode = @c_SerialNumber
   SET @c_SerialNumber = RIGHT(RTRIM(@c_SerialNumber), 13) + @c_TimeStampNow
   
   IF EXISTS ( SELECT 1 FROM [dbo].[PackSerialNo] WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND Barcode = @c_QRCode )
   BEGIN
      SET @n_Continue = 3  
      SET @n_Err      = 61004  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ':'    
                    + 'Barcode (' + @c_SerialNumber + ') already existed.(isp_ECOMP_SerialNoDecode01)'  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOMP_SerialNoDecode01'  
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