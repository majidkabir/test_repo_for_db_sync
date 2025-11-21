SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_InsertMessage                           */  
/* Creation Date: 26-Feb-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */
/* 04-04-2013   ChewKP    Revise (ChewKP01)                             */    
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_InsertMessage] (  
    @c_LanguageCode NVARCHAR(10),  
    @c_MessageID    NVARCHAR(40),  
    @c_MessageText  NVARCHAR(255)  
)  
AS  
BEGIN  
   -- CODELKUP - ListName = 'LANGUAGE'  
   --   1 English  
   --   2 Espanol  
   --   3 Francais  
   --   4 Mandarin  
   --   5 Japanese (NIHONGO)  
   --   6 Malay  
   --   7 Thai  
   DECLARE @n_MsgLangId  INT  
          ,@c_RtnMessage NVARCHAR(255)  
     
   SET @c_RtnMessage = N''  
   -- Default to English  
   SET @n_MsgLangId =   
         CASE @c_LanguageCode  
            WHEN 'CHN' THEN 4  
            WHEN 'MYL' THEN 6  
            WHEN 'THL' THEN 7  
            ELSE 1  
         END  
     
   IF LEFT(@c_MessageID, 3) = 'vc_'  
   BEGIN  
      IF NOT EXISTS(SELECT 1 FROM MESSAGE_ID MI WITH (NOLOCK)  
                    WHERE MI.MsgId = @c_MessageID)  
      BEGIN   
         INSERT INTO MESSAGE_ID  
         (  
            MsgId,  
            MsgIcon,  
            MsgButton,  
            MsgDefaultButton,  
            MsgSeverity,  
            MsgPrint,  
            MsgUserInput  
         )  
         VALUES  
         (  
            @c_MessageID /* MsgId */,  
            ''  /* MsgIcon */,  
            ''  /* MsgButton */,  
            ''  /* MsgDefaultButton */,  
            '5' /* MsgSeverity */,  
            ''  /* MsgPrint */,  
            ''  /* MsgUserInput */  
         )  
      END  
        
      --SELECT @n_MsgLangId '@n_MsgLangId', @c_MessageID '@c_MessageID'  
        
      IF NOT EXISTS(SELECT 1 FROM MESSAGE_TEXT MT WITH (NOLOCK)  
                    WHERE MT.MsgId = @c_MessageID   
                      AND MT.MsgLangId = @n_MsgLangId)  
      BEGIN   
         INSERT INTO MESSAGE_TEXT (MsgId,MsgLangId, MsgTitle, MsgText)  
         VALUES (@c_MessageID, @n_MsgLangId, '', @c_MessageText)                    
      END
      ELSE -- (ChewKP01)
      BEGIN
         DELETE FROM MESSAGE_TEXT 
         WHERE MsgId = @c_MessageID   
           AND MsgLangId = @n_MsgLangId
           
           
         INSERT INTO MESSAGE_TEXT (MsgId,MsgLangId, MsgTitle, MsgText)  
         VALUES (@c_MessageID, @n_MsgLangId, '', @c_MessageText)                                          
         
      END  
   END  
     
END

GO