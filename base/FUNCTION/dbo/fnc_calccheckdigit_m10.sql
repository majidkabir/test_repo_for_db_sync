SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  fnc_CalcCheckDigit_M10                             */
/* Creation Date: 27-Jan-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: Michael Lam                                              */
/*                                                                      */
/* Purpose:  To calculate Modulus 10 Check Digits of a string           */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 01/03/2011   MLam      Change to calc digit from right to left       */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_CalcCheckDigit_M10] (
   @c_String     NVARCHAR(100),
   @b_RtnFullStr INT = 1
)
RETURNS NVARCHAR(100)
AS
BEGIN
   DECLARE @c_Digit             NVARCHAR(1)
         , @c_CheckDigit        NVARCHAR(1)
         , @n_OddDigitSum       INT
         , @n_EvenDigitSum      INT
         , @n_Len               INT
         , @n_Pos               INT
         , @b_Error             INT

   SET @c_String       = LTRIM(RTRIM(@c_String))
   SET @c_CheckDigit   = ''
   SET @n_OddDigitSum  = 0
   SET @n_EvenDigitSum = 0
   SET @n_Len          = LEN(@c_String)
   SET @n_Pos          = 0
   SET @b_Error        = 0

   WHILE @b_Error = 0 AND @n_Pos < @n_Len
   BEGIN
   	SET @n_Pos = @n_Pos + 1
   	SET @c_Digit = SUBSTRING(@c_String, @n_Len - @n_Pos + 1, 1)

      IF @c_Digit < '0' OR @c_Digit > '9'
      BEGIN
         SET @b_Error = 1
      END
      ELSE
      BEGIN
      	IF @n_Pos % 2 = 0
            SET @n_EvenDigitSum = @n_EvenDigitSum + CONVERT(INT, @c_Digit)
         ELSE
            SET @n_OddDigitSum  = @n_OddDigitSum  + CONVERT(INT, @c_Digit)
   	END
   END

   IF @b_Error = 0
   	SET @c_CheckDigit = CONVERT(NVARCHAR(1), (10 - (@n_OddDigitSum * 3 + @n_EvenDigitSum) % 10) % 10)
   
   RETURN CASE WHEN @b_RtnFullStr=1 THEN @c_String + @c_CheckDigit ELSE @c_CheckDigit END
END

GO