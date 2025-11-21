SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_VC_prTaskLUTCoreConfiguration              */
/* Creation Date: 26-Feb-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* When Sent? Before beginning any dialog, the device requests          */
/*            configuration information where the data follows the      */
/*            format below.                                             */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTCoreConfiguration] (
    @c_TranDate     NVARCHAR(20)
   ,@c_DevSerialNo  NVARCHAR(20)
   ,@c_OperatorID   NVARCHAR(20)
   ,@c_LanguageCd   NVARCHAR(20)
   ,@c_Site         NVARCHAR(20)
   ,@c_Version      NVARCHAR(20)
   ,@n_SerialNo     INT
   ,@c_RtnMessage   NVARCHAR(500) =''  OUTPUT    
   ,@b_Success      INT = 1 OUTPUT
   ,@n_Error        INT = 0 OUTPUT
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT    
)
AS
BEGIN
   SET NOCOUNT ON
   
   DECLARE @c_VoiceSystemName      NVARCHAR(60)
         , @c_ConfirmPasswd     NVARCHAR(60)
         , @c_ErrorCode         NVARCHAR(20)
         , @c_Message           NVARCHAR(400)
         , @n_MobileNo          INT
         , @c_DefaultStorer     NVARCHAR(15)
         , @c_DefaultFacility   NVARCHAR(5)
         , @c_DefaultPrinter    NVARCHAR(200)
         , @c_DefaultPrinter_Paper NVARCHAR(200)
         , @c_CurrDevSerialNo      NVARCHAR(20)
         , @cLangCode              NVARCHAR(10)
         
         
DECLARE @n_Function    INT
       ,@n_Scn         INT
       ,@n_Step        INT
       ,@n_MsgQueueNo  INT
       ,@n_Menu        INT 
       ,@n_Key         INT
         

--  Language Code          
--      de_DE = German
--      en_US = English, United States
--      es_ES = Spanish
--      fr_FR = French
--      it_IT = Italian
--      pt_BR = Portuguese, Brazilian
--      nl_NL = Dutch
--      es_MX = Latin American Spanish
--      fr_CA = Canadian French
--      fi_FI = Finnish
--      sv_SE = Swedish
--      da_DK = Danish
--      pt_PT = Iberian Portuguese
--      en_GB = English, Great Britain
--      cs_CZ = Czech
--      el_GR = Greek
--      hu_HU = Hungarian
--      ja_JA = Japanese
--      ko_KR = Korean
--      no_NO = Norwegian
--      pl_PL = Polish
--      zh_TW = Mandarin Chinese
--      ru_RU = Russian
   
   
      
   SET @c_RtnMessage = ''
   SET @c_VoiceSystemName = ''
   SELECT @c_ConfirmPasswd = r.[Password], 
          @c_DefaultStorer    = r.DefaultStorer,
          @c_DefaultFacility  = r.DefaultFacility,
          @c_DefaultPrinter   = r.DefaultPrinter,
          @c_DefaultPrinter_Paper = r.DefaultPrinter_Paper,
          @cLangCode              = r.DefaultLangCode           
   FROM rdt.RDTUser r WITH (NOLOCK) 
   LEFT OUTER JOIN STORER s WITH (NOLOCK) ON r.DefaultStorer = s.StorerKey
   WHERE r.UserName = @c_OperatorID  
   
   

   SET @c_VoiceSystemName =
      CASE @cLangCode  
         WHEN 'CHN' THEN  N'利豐物流語音解決方案'
         ELSE N'LF Logistics Voice Solution'
      END 
        
   SET @c_ConfirmPasswd = '1'
   SET @c_ErrorCode = 0 
   SET @c_Message = ''

--   SET @n_MobileNo = 0
--   SET @c_CurrDevSerialNo = ''
--   
--   SELECT @n_MobileNo = r.Mobile, 
--          @c_CurrDevSerialNo = r.DeviceID
--   FROM rdt.RDTMOBREC r WITH (NOLOCK)
--   WHERE r.UserName=@c_OperatorID 
--   
--   IF ISNULL(@n_MobileNo,0) = 0 
--   BEGIN 
--      SELECT @n_MobileNo = MAX(Mobile)
--      FROM   RDT.RDTMOBREC (NOLOCK)
--
--      SELECT @n_Menu = 0,
--             @n_Function = 5,
--             @n_Scn      = 0,
--             @n_Step     = 0,
--             @n_Key      = 1      
--   
--      IF @n_MobileNo IS NULL OR @n_MobileNo = 0
--         SELECT @n_MobileNo = 1
--      ELSE
--         SELECT @n_MobileNo = @n_MobileNo + 1
--         
--      INSERT INTO rdt.RDTMOBREC(
--         Mobile, Func,      Scn,      Step,     Menu,           Lang_Code, 
--         ErrMsg, StorerKey, Facility, UserName, DeviceID, Printer,
--         Printer_Paper, InputKey)
--      VALUES(
--         @n_MobileNo, @n_Function,      @n_Scn,             @n_Step,       0, @cLangCode, 
--         '',          @c_DefaultStorer, @c_DefaultFacility, @c_OperatorID, @c_DevSerialNo, 
--         @c_DefaultPrinter, @c_DefaultPrinter_Paper, @n_Key)
--                           
--      IF @@ERROR <> 0 
--      BEGIN
--         SET @c_ErrorCode = '98'
--         SET @c_Message   = [dbo].[fnc_GetVC_Message](@cLangCode, 'vc_prTaskLUTCoreConfiguration_01', N'Insert Into Mobile Record Failed','','','','','')                  
--      END                  
--   END
--   ELSE
--   BEGIN
--      IF ISNULL(@c_DevSerialNo,'') <> ISNULL(@c_CurrDevSerialNo,'')
--      BEGIN
--         SET @c_ErrorCode = '98'
--         -- SET @c_Message   = 'This User Name already logon to another Device'   
--         SET @c_Message   = [dbo].[fnc_GetVC_Message](@cLangCode, 'vc_prTaskLUTCoreConfiguration_02', N'This User Name already logon to another Device','','','','','')       
--      END
--      ELSE
--      BEGIN
--         UPDATE RDT.RDTMOBREC 
--            SET EditDate = GETDATE(), 
--                Func = 5 ,
--                ErrMSg = ''
--         WHERE UserName=@c_OperatorID
--         AND DeviceID = @c_DevSerialNo 
--         IF @@ERROR <> 0 
--         BEGIN
--            SET @c_ErrorCode = '98'
--            --SET @c_Message   = 'Update Mobile Record Failed'      
--            SET @c_Message   = [dbo].[fnc_GetVC_Message](@cLangCode, 'vc_prTaskLUTCoreConfiguration_03', N'Update Mobile Record Failed','','','','','') 
--         END            
--      END
--   END
       
   SET @c_RtnMessage = @c_VoiceSystemName + N',' + @c_OperatorID + N',' + @c_ConfirmPasswd + N',' +  CAST(@c_ErrorCode AS NVARCHAR(10)) + N',' + @c_Message 
   
   
   
   
END

GO