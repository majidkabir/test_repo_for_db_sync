SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[ispGetNextStorerRefCnt] ( 
   @cLastRefNo NVARCHAR(2),  
   @cNextRefNo NVARCHAR(2) OUTPUT
) 
AS 
BEGIN
   DECLARE @c1stChar NVARCHAR(1), 
           @c2ndChar NVARCHAR(1) 

   IF LEN(ISNULL(@cLastRefNo, '')) = 0 
   BEGIN
      SET @cNextRefNo = '11'
   END
   ELSE
   BEGIN
      SET @c1stChar = LEFT(@cLastRefNo, 1) 
      SET @c2ndChar = RIGHT(@cLastRefNo, 1)
   
      IF @c2ndChar = 'Z' OR @c2ndChar = '9'
      BEGIN
         IF @c2ndChar = 'Z' 
            SET @c2ndChar = '1'   
         ELSE 
            SET @c2ndChar = 'A'
   
         IF @c1stChar = 'Z'
            SET @c1stChar = '1' 
         ELSE IF @c1stChar = '9' 
            SET @c1stChar = 'A'
         ELSE
            SET @c1stChar = master.dbo.fnc_GetCharASCII( ASCII(@c1stChar) + 1 )
      END 
      ELSE
      BEGIN
         SET @c2ndChar = master.dbo.fnc_GetCharASCII( ASCII(@c2ndChar) + 1 )
      END 

      SET @cNextRefNo = @c1stChar + @c2ndChar
   END 
END

GO