SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  fn_Encode_IDA_Code128                              */
/* Creation Date: 04-Nov-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: Michael Lam                                              */
/*                                                                      */
/* Purpose:  To encode string for IDAutomation Code128 fonts            */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/
CREATE FUNCTION [dbo].[fn_Encode_IDA_Code128] (
   @c_DataToFormat NVARCHAR(100)
)
RETURNS NVARCHAR(100)
AS
BEGIN
   DECLARE @c_DataToEncode      NVARCHAR(100)
         , @c_PrintableString   NVARCHAR(100)
         , @c_CurrentChar       NVARCHAR(10)
         , @n_CurrentCharNum    INT
         , @n_StringLength      INT
         , @c_C128Start         NVARCHAR(10)
         , @c_CurrentEncoding   NVARCHAR(10)
         , @I                   INT
         , @J                   INT
         , @n_Factor            INT
         , @n_CurrentValue      INT
         , @n_WeightedTotal     INT
         , @n_CheckDigitValue   INT
         , @c_C128CheckDigit    NCHAR(1)


   SET @c_PrintableString = ''
   SET @c_DataToEncode = ''

   -- Select the character set A, B OR C for the START character
   SET @c_CurrentChar = LEFT(@c_DataToFormat, 1)
   SET @n_CurrentCharNum = UNICODE(@c_CurrentChar)
   SET @n_StringLength = LEN(@c_DataToFormat)
   IF @n_CurrentCharNum < 32 SET @c_C128Start = NCHAR(203)
   IF @n_CurrentCharNum > 31 AND @n_CurrentCharNum < 127 SET @c_C128Start = NCHAR(204)
   IF ((@n_StringLength > 3) AND SUBSTRING(@c_DataToFormat, 1, 4) LIKE '[0-9][0-9][0-9][0-9]') SET @c_C128Start = NCHAR(205)

   -- 202 & 212-215 is for the FNC1, with this Start C is mandatory
   IF @n_CurrentCharNum = 197 SET @c_C128Start = NCHAR(204)
   IF @n_CurrentCharNum > 201 SET @c_C128Start = NCHAR(205)
   IF @c_C128Start = NCHAR(203) SET @c_CurrentEncoding = 'A'
   IF @c_C128Start = NCHAR(204) SET @c_CurrentEncoding = 'B'
   IF @c_C128Start = NCHAR(205) SET @c_CurrentEncoding = 'C'
   SET @I = 1

   WHILE @I <= @n_StringLength
   BEGIN
      -- Check for FNC1 in any set which is ASCII 202 AND ASCII 212-215
      SET @n_CurrentCharNum = UNICODE(SUBSTRING(@c_DataToFormat, @I, 1))
      IF @n_CurrentCharNum > 201
      BEGIN
         SET @c_DataToEncode = @c_DataToEncode + NCHAR(202)
      END
      -- Check for switching to character set C
      ELSE IF @n_CurrentCharNum = 197
      BEGIN
         IF @c_CurrentEncoding = 'C'
         BEGIN
            SET @c_DataToEncode = @c_DataToEncode + NCHAR(200)
            SET @c_CurrentEncoding = 'B'
         END
         SET @c_DataToEncode = @c_DataToEncode + NCHAR(197)
      END
      ELSE IF ((@I < @n_StringLength - 2) AND (SUBSTRING(@c_DataToFormat, @I, 4) LIKE '[0-9][0-9][0-9][0-9]'))
           OR ((@I < @n_StringLength) AND (SUBSTRING(@c_DataToFormat, @I, 2) LIKE '[0-9][0-9]') AND (@c_CurrentEncoding = 'C'))
      BEGIN
         -- check to see IF we have an odd number of numbers to encode,
         -- IF so stay in current set for 1 number AND then switch to save space
         IF @c_CurrentEncoding <> 'C'
         BEGIN
             SET @J = @I
             SET @n_Factor = 3
             WHILE @J <= @n_StringLength AND SUBSTRING(@c_DataToFormat, @J, 1) LIKE '[0-9]'
             BEGIN
                 SET @n_Factor = 4 - @n_Factor
                 SET @J = @J + 1
             END
             IF @n_Factor = 1
             BEGIN
                -- IF so stay in current set for 1 character to save space
                SET @c_DataToEncode = @c_DataToEncode + NCHAR(@n_CurrentCharNum)
                SET @I = @I + 1
             END
         END

         -- Switch to set C IF not already in it
         IF @c_CurrentEncoding <> 'C' SET @c_DataToEncode = @c_DataToEncode + NCHAR(199)
         SET @c_CurrentEncoding = 'C'
         SET @c_CurrentChar = (SUBSTRING(@c_DataToFormat, @I, 2))
         SET @n_CurrentValue = CASE WHEN @c_CurrentChar LIKE '[0-9][0-9]' THEN CONVERT(INT,@c_CurrentChar) ELSE 0 END
         -- Set the @n_CurrentValue to the number of String @c_CurrentChar
         IF (@n_CurrentValue < 95 AND @n_CurrentValue > 0) SET @c_DataToEncode = @c_DataToEncode + NCHAR(@n_CurrentValue + 32)
         IF @n_CurrentValue > 94 SET @c_DataToEncode = @c_DataToEncode + NCHAR(@n_CurrentValue + 100)
         IF @n_CurrentValue = 0 SET @c_DataToEncode = @c_DataToEncode + NCHAR(194)
         SET @I = @I + 1
      END
      -- Check for switching to character set A
      ELSE IF (@I <= @n_StringLength) AND ((UNICODE(SUBSTRING(@c_DataToFormat, @I, 1)) < 31) OR
              ((@c_CurrentEncoding = 'A') AND (UNICODE(SUBSTRING(@c_DataToFormat, @I, 1)) > 32 AND
               (UNICODE(SUBSTRING(@c_DataToFormat, @I, 1))) < 96)))
      BEGIN
      -- Switch to set A IF not already in it
          IF @c_CurrentEncoding <> 'A' SET @c_DataToEncode = @c_DataToEncode + NCHAR(201)
          SET @c_CurrentEncoding = 'A'
          -- Get the ASCII value of the next character
          SET @n_CurrentCharNum = UNICODE(SUBSTRING(@c_DataToFormat, @I, 1))
          IF @n_CurrentCharNum = 32
              SET @c_DataToEncode = @c_DataToEncode + NCHAR(194)
          ELSE IF @n_CurrentCharNum < 32
              SET @c_DataToEncode = @c_DataToEncode + NCHAR(@n_CurrentCharNum + 96)
          ELSE IF @n_CurrentCharNum > 32
              SET @c_DataToEncode = @c_DataToEncode + NCHAR(@n_CurrentCharNum)
      END
      -- Check for switching to character set B
      ELSE IF (@I <= @n_StringLength) AND ((UNICODE(SUBSTRING(@c_DataToFormat, @I, 1))) > 31 AND
              (UNICODE(SUBSTRING(@c_DataToFormat, @I, 1))) < 127)
      BEGIN
         -- Switch to set B IF not already in it
         IF @c_CurrentEncoding <> 'B' SET @c_DataToEncode = @c_DataToEncode + NCHAR(200)
         SET @c_CurrentEncoding = 'B'
         -- Get the ASCII value of the next character
         SET @n_CurrentCharNum = UNICODE(SUBSTRING(@c_DataToFormat, @I, 1))
         IF @n_CurrentCharNum = 32
             SET @c_DataToEncode = @c_DataToEncode + NCHAR(194)
         Else
             SET @c_DataToEncode = @c_DataToEncode + NCHAR(@n_CurrentCharNum)
      END
      SET @I = @I + 1
   END

   -- Calculate Modulo 103 Check Digit
   SET @n_WeightedTotal = UNICODE(@c_C128Start) - 100
   SET @n_StringLength = LEN(@c_DataToEncode)
   SET @I = 1
   WHILE @I <= @n_StringLength
   BEGIN
      SET @n_CurrentCharNum = UNICODE(SUBSTRING(@c_DataToEncode, @I, 1))
      IF @n_CurrentCharNum < 135 SET @n_CurrentValue = @n_CurrentCharNum - 32
      IF @n_CurrentCharNum > 134 SET @n_CurrentValue = @n_CurrentCharNum - 100
      IF @n_CurrentCharNum = 194 SET @n_CurrentValue = 0
      SET @n_CurrentValue = @n_CurrentValue * @I
      SET @n_WeightedTotal = @n_WeightedTotal + @n_CurrentValue
      IF @n_CurrentCharNum = 32 SET @n_CurrentCharNum = 194
      SET @c_PrintableString = @c_PrintableString + NCHAR(@n_CurrentCharNum)
      SET @I = @I + 1
   END
   SET @n_CheckDigitValue = (@n_WeightedTotal % 103)
   IF @n_CheckDigitValue < 95 AND @n_CheckDigitValue > 0 SET @c_C128CheckDigit = NCHAR(@n_CheckDigitValue + 32)
   IF @n_CheckDigitValue > 94 SET @c_C128CheckDigit = NCHAR(@n_CheckDigitValue + 100)
   IF @n_CheckDigitValue = 0 SET @c_C128CheckDigit = NCHAR(194)

   RETURN @c_C128Start + @c_PrintableString + @c_C128CheckDigit + NCHAR(206)
END

GO