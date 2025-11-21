SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE FUNCTION [dbo].[fnc_GetVC_Number] 
  ( 
    @n_number        INT, 
    @c_LanguageCode  NVARCHAR(10)
  )
RETURNS NVARCHAR(100)
AS
BEGIN
   DECLARE @n_Position   INT
          ,@c_NumberString NVARCHAR(100)
          ,@c_Number       VARCHAR(10)
          ,@c_Char         CHAR(1)
   
   SET @c_NumberString = ''
   SET @c_Number = CAST(@n_Number AS VARCHAR(10))
   SET @n_Position = 0
     
   WHILE LEN(@c_Number) > 0
   BEGIN
      SET @n_Position = @n_Position + 1
      SET @c_Char = RTRIM(RIGHT(@c_Number, 1))
      
      IF @c_Char <> '0'
      BEGIN
         SET @c_NumberString = @c_Char + 
                               CASE @n_Position
                                 WHEN 1 	THEN N''	           
                                 WHEN 2 	THEN N'σìü'     
                                 WHEN 3 	THEN N'τÖ╛'       
                                 WHEN 4 	THEN N'σìâ'       
                                 WHEN 5 	THEN N'ΦÉ¼'       
                                 WHEN 6 	THEN N'σìüΦÉ¼'    
                                 WHEN 7 	THEN N'τÖ╛ΦÉ¼'    
                                 WHEN 8 	THEN N'σìâΦÉ¼'    
                                 WHEN 9 	THEN N'σää'       
                                 WHEN 10  THEN N'σìüσää'      
                               END  +        
                               @c_NumberString
      END
      ELSE
        SET @c_NumberString = N'Θ¢╢' +  @c_NumberString

      
      SET @c_Number = SUBSTRING(@c_Number, 1, LEN(@c_Number) - 1)
      
   END
   
   
       
   RETURN @c_NumberString
END

GO