SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function: fnc_GetDelimitedColumn         							         */
/* Creation Date: 12-Oct-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Parsing Delimited String to return value for column number	*/
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetDelimitedColumn] 
(
   @cString    nvarchar(MAX), 
   @cDelimited NVARCHAR(1), 
   @nColumnNo  INT 
) 
RETURNS NVARCHAR(MAX) AS
BEGIN

   DECLARE 
   @nStartPosition int, 
   @nEndPosition   int,
   @nCol           INT,
   @cValue         NVARCHAR(MAX) 
   
   SET @nCol = 0 
   SET @nStartPosition = 1 
   SET @nEndPosition = 0 

   SET @cValue = ''

   WHILE 1=1
   BEGIN
      SET @nEndPosition = CHARINDEX(@cDelimited, @cString, @nStartPosition)

      IF @nEndPosition > 0 
      BEGIN
         SET @nCol = @nCol + 1 
         
         IF @nCol = @nColumnNo
         BEGIN
            SET @cValue = SUBSTRING( @cString, @nStartPosition, @nEndPosition - @nStartPosition) 
            BREAK
         END 

         SET @nStartPosition = @nEndPosition + 1 
         
         IF @nStartPosition > LEN(@cString)
            BREAK
         
      END 
      ELSE
         BREAK 
   END 
   IF (@nEndPosition < = 0 ) AND (@cValue = '') AND @nStartPosition <= LEN(@cString)
   BEGIN
   	SET @nCol = @nCol + 1
   	
      IF @nCol = @nColumnNo 
      BEGIN   	
         SET @cValue = SUBSTRING( @cString, @nStartPosition, ( LEN(@cString) - @nStartPosition) + 1 )
      END 
   END
   
   RETURN ISNULL(@cValue, '') 
END -- function

GO