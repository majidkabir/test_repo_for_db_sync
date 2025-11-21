SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtIsInteger                                        */
/* Creation Date  : 2006-05-21                                          */
/* Copyright      : IDS                                                 */
/* Written By     : dhung                                               */
/*                                                                      */
/* Purpose: Validate string passed in is an integer. Return:            */
/*          0 = no                                                      */
/*          1 = yes                                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2006-06-21   1.0  Ung        Created                                 */
/* 2015-02-10   1.1  Ung        Expand to 10 chars                      */
/************************************************************************/

CREATE FUNCTION [RDT].[rdtIsInteger]( 
   @cValue NVARCHAR( 10) -- expression to be checked
) RETURNS INT AS -- 0 = no, 1 = yes
BEGIN
   -- Validate is numeric
   IF IsNumeric( @cValue) = 0
      GOTO Fail

   -- Validate is integer including negative (just in case we have '-0')
   DECLARE @i INT
   DECLARE @c NVARCHAR(1)
   SET @i = 1
   WHILE @i <= LEN( RTRIM( @cValue))
   BEGIN
      SET @c = SUBSTRING( @cValue, @i, 1)
      IF NOT ((@c >= '0' AND @c <= '9') OR @c = '-')
         GOTO Fail
      SET @i = @i + 1
   END   

   RETURN 1 -- yes
Fail:
   RETURN 0 -- no
END

GO