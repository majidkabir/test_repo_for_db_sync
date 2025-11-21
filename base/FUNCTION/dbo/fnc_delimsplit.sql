SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function       : fnc_DelimSplit                                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: To Split the Value in the String And Return as Column       */
/*          From Table.                                                 */
/*                                                                      */
/* Usage: SELECT * from dbo.fnc_DelimSplit ('|','A|B|C')                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2010-04-29   1.0  SHONG    Created                                   */
/* 2014-03-21   1.1  TLTING   SQL2012 Bug fix                           */
/* 2017-08-08   1.2  MLAM(HK) Fix Maximum recursion limit 100 error     */
/* 2020-08-13   1.3  WLChooi  Set to NVARCHAR(MAX) (WL01)               */
/* 2020-08-25   1.4  WLChooi  Grant SELECT Permission (WL02)            */
/* 2020-08-25   1.5  WLChooi  Grant SELECT Permission for JReport (WL03)*/
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_DelimSplit]
(
    @c_Delim   NVARCHAR(1)
   ,@c_String  NVARCHAR(MAX)   --WL01
)
RETURNS @result TABLE (
    SeqNo    INT IDENTITY (1, 1) NOT NULL
  , ColValue NVARCHAR(MAX)   --WL01
)
AS
BEGIN
   DECLARE @I    INT
         , @J    INT
         , @LenD INT
         , @LenS INT

   SELECT @LenD = LEN( REPLACE(@c_Delim,' ','.') )
        , @LenS = LEN( @c_String )
        , @I   = 1

   WHILE @I <= @LenS
   BEGIN
      SET @J = CHARINDEX( @c_Delim, @c_String, @I)
      SET @J = CASE WHEN @J>0 AND @J>=@I THEN @J - @I ELSE @LenS - @I + 1 END

      INSERT INTO @result (ColValue)
      VALUES( SUBSTRING( @c_String, @I, @J) )

      SET @I = @I + @J + @LenD
   END

   RETURN
/*
RETURNS table
AS
RETURN (
    WITH Result1(SeqNo, StartPosition, StopPosition) AS (
      SELECT 1, 1, CHARINDEX(@c_Delim, @c_String)
      UNION ALL
      SELECT SeqNo + 1, StopPosition + 1, CHARINDEX(@c_Delim, @c_String, StopPosition + 1)
      FROM Result1
      WHERE StopPosition > 0
    )
    SELECT SeqNo,
      SUBSTRING(@c_String, StartPosition, CASE WHEN StopPosition > 0 THEN StopPosition-StartPosition ELSE 512 END) AS [ColValue]
    FROM Result1
)
*/
END
--WL02 START

GO