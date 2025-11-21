SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*returns 1 if input string is OK, 0 otherwise*/
CREATE   FUNCTION [dbo].[fnc_Check_String] (@string VARCHAR(MAX))
RETURNS INT
AS
BEGIN
   DECLARE @ret_val INT;
   SET @ret_val = 1;
   IF (@string LIKE '%''%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%--%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%/*%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%*/%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%@')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%@@%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%char%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%nchar%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%varchar%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%nvarchar%')
      SET @ret_val = 0;

   ELSE IF (@string LIKE '%select%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%insert%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%update%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%delete%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%from%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%table%')
      SET @ret_val = 0;

   ELSE IF (@string LIKE '%drop%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%create%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%alter%')
      SET @ret_val = 0;

   ELSE IF (@string LIKE '%begin%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%end%')
      SET @ret_val = 0;

   ELSE IF (@string LIKE '%grant%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%deny%')
      SET @ret_val = 0;

   ELSE IF (@string LIKE '%exec%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%sp_%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%xp_%')
      SET @ret_val = 0;

   ELSE IF (@string LIKE '%cursor%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%fetch%')
      SET @ret_val = 0;

   ELSE IF (@string LIKE '%kill%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%open%')
      SET @ret_val = 0;

   ELSE IF (@string LIKE '%sysobjects%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%syscolumns%')
      SET @ret_val = 0;
   ELSE IF (@string LIKE '%sys%')
      SET @ret_val = 0;

   RETURN (@ret_val);
END;

GO