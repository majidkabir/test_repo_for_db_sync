SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_Message]     
  ( @c_LanguageCode NVARCHAR(10),    
    @c_MessageID    NVARCHAR(50),    
    @c_MessageText  NVARCHAR(255),    
    @c_Variable01   NVARCHAR(50) = N'',    
    @c_Variable02   NVARCHAR(50) = N'',    
    @c_Variable03   NVARCHAR(50) = N'',    
    @c_Variable04   NVARCHAR(50) = N'',    
    @c_Variable05   NVARCHAR(50) = N''    
  )    
RETURNS NVARCHAR(255)    
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
      IF NOT EXISTS(SELECT 1 FROM MESSAGE_TEXT MT WITH (NOLOCK)    
                     WHERE MT.MsgId = @c_MessageID   
                     AND   MT.MsgLangId = @n_MsgLangId )    
      BEGIN     
         SET @c_RtnMessage = @c_MessageText    
      END  
      ELSE  
      BEGIN  
         SELECT @c_RtnMessage = MT.MsgText    
         FROM MESSAGE_TEXT MT WITH (NOLOCK)    
         WHERE MT.MsgId = @c_MessageID   
         AND   MT.MsgLangId = @n_MsgLangId  
                               
      END    
   END    
   ELSE    
      SET @c_RtnMessage = @c_MessageText    
       
   DECLARE @n_Position     INT,     
           @n_VariableIdx  INT    
               
   SET @n_Position     = 0    
   SET @n_VariableIdx  = 0     
  
   IF CHARINDEX('%s', @c_RtnMessage, 1) > 0   
   BEGIN  
      SET @n_Position = CHARINDEX('%s', @c_RtnMessage, 1)    
      WHILE @n_Position > 0     
      BEGIN    
         SET @n_VariableIdx = @n_VariableIdx + 1    
             
         SELECT @c_RtnMessage = SUBSTRING(@c_RtnMessage, 1, @n_Position - 1) +     
                                CASE @n_VariableIdx    
                                    WHEN 1 THEN @c_Variable01    
                                    WHEN 2 THEN @c_Variable02    
                                    WHEN 3 THEN @c_Variable03    
                                    WHEN 4 THEN @c_Variable04    
                                    WHEN 5 THEN @c_Variable05    
                                    ELSE ''    
                                END +     
                                SUBSTRING(@c_RtnMessage, @n_Position + 2, LEN(@c_RtnMessage) - @n_Position + 1 )      
                                    
         SET @n_Position = CHARINDEX('%s', @c_RtnMessage, 1)    
      END          
   END    
        
   RETURN @c_RtnMessage    
END

GO