SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_LocFormat_US] (@cLoc varchar(10))  
RETURNS varchar(20) AS  
BEGIN
   DECLARE @cReturnLoc VARCHAR(20)
   
   IF LEN(@cLoc) = 10 
   BEGIN
      SET @cReturnLoc =  SUBSTRING(@cLoc, 1, 3) + '-' + 
                SUBSTRING(@cLoc, 4, 2) + '-' + 
                SUBSTRING(@cLoc, 6, 2) + '-' + 
                SUBSTRING(@cLoc, 8, 1) + '-' + 
                SUBSTRING(@cLoc, 9, 2)      
   END
   ELSE
      SET @cReturnLoc = @cLoc
  
   RETURN @cReturnLoc 
END

GO