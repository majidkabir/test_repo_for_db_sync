SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtFormatFloat    					                  */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Format float to string                                      */
/*                                                                      */
/* Date       Author    Ver   Purposes                                  */
/* 2015-01-22 Ung       1.0   Created                                   */
/* 2015-08-23 Ung       1.1   SOS347636 limit to 6 decimal point        */
/************************************************************************/

CREATE FUNCTION [RDT].[rdtFormatFloat] (
   @f FLOAT
) RETURNS NVARCHAR( 10) AS
BEGIN
   DECLARE @c NVARCHAR( 309) -- Max lenght of float
   DECLARE @nPOS INT
   
   --SET @c = STR( @f, 309, 16) -- Max value and max decimal precision of float
   SET @c = STR( @f, 309, 6)    -- Max value and 6 decimal precision of float
   SET @c = LTRIM( @c)          -- Trim leading space

   -- Trim trailing zero
   WHILE RIGHT( @c, 1) = '0'
      SET @c = SUBSTRING( @c, 1, LEN( @c) - 1)

   -- Remove decimal if last digit
   IF RIGHT( @c, 1) = '.'
      SET @c = SUBSTRING( @c, 1, LEN( @c) - 1)

   -- Return 10 digits max
   RETURN LEFT( @c, 10)
END

GO