SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispGetDelimitedColumn         							        */
/* Creation Date: 10-Aug-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Update POD Status using SMS method                        	*/
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
CREATE PROC [dbo].[ispGetDelimitedColumn] (
   @cString    NVARCHAR(4000), 
   @cDelimited NVARCHAR(1), 
   @nColumnNo  int,
   @cValue     NVARCHAR(215) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON

   DECLARE 
   @nStartPosition int, 
   @nEndPosition   int,
   @nCol           int 
   
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
         
--         SELECT '@nEndPosition', @nStartPosition '@nStartPosition', @nEndPosition '@nEndPosition', 
--                SUBSTRING( @cString, @nStartPosition, @nEndPosition - @nStartPosition) 'Value', 
--                @nCol 

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
END -- procedure

GO