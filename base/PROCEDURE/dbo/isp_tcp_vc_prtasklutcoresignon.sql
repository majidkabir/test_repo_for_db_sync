SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTCoreSignOn                     */  
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
/* 01-04-2013   ChewKP    Revise (ChewKP01)                             */      
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTCoreSignOn] (  
    @c_TranDate     NVARCHAR(20)  
   ,@c_DevSerialNo  NVARCHAR(20)  
   ,@c_OperatorID   NVARCHAR(20)  
   ,@c_Password     NVARCHAR(20)  
   ,@n_SerialNo     INT  
   ,@c_RtnMessage   NVARCHAR(500) = '' OUTPUT      
   ,@b_Success      INT = 1 OUTPUT  
   ,@n_Error        INT = 0 OUTPUT  
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_Interleave        NVARCHAR(5)  
         , @c_CheckPasswd       NVARCHAR(60)  
         , @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                            -- 98: Critical error. If this error is received,   
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                            --     but does not force the operator to sign off.  
         , @c_Message           NVARCHAR(400)  
         , @n_MobileNo          INT  
         , @c_DefaultStorer     NVARCHAR(15)  
         , @c_DefaultFacility   NVARCHAR(5)  
         , @c_DefaultPrinter    NVARCHAR(200)  
         , @c_DefaultPrinter_Paper NVARCHAR(200)  
         , @c_CurrDevSerialNo      NVARCHAR(20)  
         , @c_LangCode             NVARCHAR(3)  
         
   DECLARE @n_Function    INT
          ,@n_Scn         INT
          ,@n_Step        INT
          ,@n_MsgQueueNo  INT
          ,@n_Menu        INT 
          ,@n_Key         INT    
          ,@n_CurrFunction INT  
   
   SET @c_RtnMessage = ''  
   SET @c_Interleave = '0'  
   SET @c_Message = ''  
   SET @c_LangCode = ''
   
   
   

   
     
   IF ISNULL(@c_Password,'') = ''   
   BEGIN  
      SET @c_ErrorCode = '98'  
      SET @c_Message   = 'Password Not Provided'        
      GOTO QUIT_SP  
   END  
     
   SELECT @c_CheckPasswd      = r.[Password],   
          @c_DefaultStorer    = r.DefaultStorer,  
          @c_DefaultFacility  = r.DefaultFacility,  
          @c_DefaultPrinter   = r.DefaultPrinter,  
          @c_DefaultPrinter_Paper = r.DefaultPrinter_Paper,  
          @c_LangCode             = r.DefaultLangCode   
   FROM rdt.RDTUser r WITH (NOLOCK)   
   WHERE r.UserName = @c_OperatorID    
     
   IF ISNULL(@c_CheckPasswd,'') <> ISNULL(@c_Password, '')   
   BEGIN  
      SET @c_ErrorCode = '98'  
      --SET @c_Message   = 'Invalid Password'  
      SET @c_Message = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTCoreSignOn_01', N'Invalid Password','','','','','')
   END  
   ELSE  
   BEGIN  
      SET @n_MobileNo = 0
      SET @c_CurrDevSerialNo = ''
      SET @c_ErrorCode = '0'  
      
      SELECT @n_MobileNo = r.Mobile, 
             @c_CurrDevSerialNo = r.DeviceID,
             @n_CurrFunction    = r.Func
      FROM rdt.RDTMOBREC r WITH (NOLOCK)
      WHERE r.UserName=@c_OperatorID 
      
      IF ISNULL(@n_MobileNo,0) = 0 
      BEGIN 
         SELECT @n_MobileNo = MAX(Mobile)
         FROM   RDT.RDTMOBREC (NOLOCK)
   
         SELECT @n_Menu = 0,
                @n_Function = 5,
                @n_Scn      = 0,
                @n_Step     = 0,
                @n_Key      = 1      
      
         IF @n_MobileNo IS NULL OR @n_MobileNo = 0
            SELECT @n_MobileNo = 1
         ELSE
            SELECT @n_MobileNo = @n_MobileNo + 1
            
         INSERT INTO rdt.RDTMOBREC(
            Mobile, Func,      Scn,      Step,     Menu,           Lang_Code, 
            ErrMsg, StorerKey, Facility, UserName, DeviceID, Printer,
            Printer_Paper, InputKey)
         VALUES(
            @n_MobileNo, @n_Function,      @n_Scn,             @n_Step,       0, @c_LangCode, 
            '',          @c_DefaultStorer, @c_DefaultFacility, @c_OperatorID, @c_DevSerialNo, 
            @c_DefaultPrinter, @c_DefaultPrinter_Paper, @n_Key)
                              
         IF @@ERROR <> 0 
         BEGIN
            SET @c_ErrorCode = '98'
            SET @c_Message   = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTCoreConfiguration_01', N'Insert Into Mobile Record Failed','','','','','')                  
         END                  
      END
      ELSE
      BEGIN
         IF ISNULL(@n_CurrFunction,'0') <> 0 
         BEGIN
            SET @c_ErrorCode = '98'
            -- SET @c_Message   = 'This User Name already logon to another Device'   
            SET @c_Message   = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTCoreConfiguration_02', N'This User Name already logon to another Device','','','','','')       
         END
         ELSE
         BEGIN
            UPDATE RDT.RDTMOBREC 
               SET EditDate = GETDATE(), 
                   Func = 5 ,
                   ErrMSg = '',
                   DeviceID = @c_DevSerialNo 
            WHERE UserName=@c_OperatorID
            
            IF @@ERROR <> 0 
            BEGIN
               SET @c_ErrorCode = '98'
               --SET @c_Message   = 'Update Mobile Record Failed'      
               SET @c_Message   = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTCoreConfiguration_03', N'Update Mobile Record Failed','','','','','') 
            END            
         END
      END
   
     
   END  
   
   
          
  
QUIT_SP:  
      
   SET @c_RtnMessage = @c_Interleave + ',' + @c_ErrorCode + ',' + @c_Message    
   

   
END

GO