SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************************************************/
/* Function       : fnc_NumberToThai                                                                         */
/* Copyright      : LFL                                                                                      */
/*                                                                                                           */
/* Purpose: WMS-19983 - Return Number in Thai                                                                */
/*                                                                                                           */
/*                                                                                                           */
/* Usage: SELECT * from dbo.fnc_NumberToThai(number,number surfix, decimal surfix)                           */
/*                                                                                                           */
/* Modifications log:                                                                                        */
/*                                                                                                           */
/* Date         Rev  Author     Purposes                                                                     */
/* 23-Nov-2022  1.0  WLChooi    DevOps Combine Script                                                        */
/*************************************************************************************************************/
CREATE   FUNCTION [dbo].[fnc_NumberToThai]
(
   @n_Number        MONEY
 , @c_NumberSurfix  NVARCHAR(100) = N'บาท'
 , @c_DecimalSurfix NVARCHAR(100) = N'สตางค์'
)
RETURNS NVARCHAR(4000)
AS
BEGIN

   DECLARE @number NUMERIC(38, 0)
   DECLARE @decimal INT
   DECLARE @loops INT
   DECLARE @bigLoops INT
   DECLARE @counter INT
   DECLARE @bigCount INT
   DECLARE @mod INT
   DECLARE @numbersTable TABLE
   (
      number CHAR(1)
    , word   NVARCHAR(10)
   )
   DECLARE @numbersDigit TABLE
   (
      number CHAR(1)
    , word   NVARCHAR(10)
   )
   DECLARE @inputNumber NVARCHAR(38)
   DECLARE @inputNumber1 NVARCHAR(38)
   DECLARE @inputDecimal NVARCHAR(2)
   DECLARE @charNumber CHAR(1)
   DECLARE @outputString NVARCHAR(4000)
   DECLARE @outputString1 NVARCHAR(4000)
   DECLARE @outputChar NVARCHAR(10)
   DECLARE @outputChar1 NVARCHAR(10)
   DECLARE @nextNumber CHAR(1)

   IF @n_Number = 0
      RETURN N'ศูนย์' + @c_NumberSurfix

   -- insert data for the numbers and words
   INSERT INTO @numbersTable
   SELECT ' '
        , ''
   UNION ALL
   SELECT '0'
        , ''
   UNION ALL
   SELECT '1'
        , N'หนึ่ง'
   UNION ALL
   SELECT '2'
        , N'สอง'
   UNION ALL
   SELECT '3'
        , N'สาม'
   UNION ALL
   SELECT '4'
        , N'สี่'
   UNION ALL
   SELECT '5'
        , N'ห้า'
   UNION ALL
   SELECT '6'
        , N'หก'
   UNION ALL
   SELECT '7'
        , N'เจ็ด'
   UNION ALL
   SELECT '8'
        , N'แปด'
   UNION ALL
   SELECT '9'
        , N'เก้า'

   INSERT INTO @numbersDigit
   SELECT '1'
        , ''
   UNION ALL
   SELECT '2'
        , N'สิบ'
   UNION ALL
   SELECT '3'
        , N'ร้อย'
   UNION ALL
   SELECT '4'
        , N'พัน'
   UNION ALL
   SELECT '5'
        , N'หมื่น'
   UNION ALL
   SELECT '6'
        , N'แสน'

   SET @number = FLOOR(@n_Number)
   SET @decimal = FLOOR((@n_Number - FLOOR(@n_Number)) * 100)
   SET @inputNumber1 = CONVERT(NVARCHAR(38), @number)
   SET @inputDecimal = CONVERT(NVARCHAR(2), @decimal)
   SET @bigLoops = FLOOR(LEN(@inputNumber1) / 6) + 1
   SET @mod = LEN(@inputNumber1) % 6
   SET @bigCount = 1
   SET @outputString = N''

   WHILE @bigCount <= @bigLoops
   BEGIN
      IF @bigCount = 1
      BEGIN
         SET @inputNumber = LEFT(@inputNumber1, @mod)
         SET @inputNumber1 = RIGHT(@inputNumber1, LEN(@inputNumber1) - @mod)
      END
      ELSE
      BEGIN
         SET @inputNumber = LEFT(@inputNumber1, 6)
         IF @bigCount < @bigLoops
            SET @inputNumber1 = RIGHT(@inputNumber1, LEN(@inputNumber1) - 6)
      END

      SET @outputString1 = N''
      SET @counter = 1
      SET @loops = LEN(@inputNumber)
      SET @nextNumber = ''
      WHILE 1 <= @loops
      BEGIN
         SET @charNumber = SUBSTRING(@inputNumber, @loops, 1)
         SET @nextNumber = SUBSTRING(@inputNumber, @loops - 1, 1)
         SELECT @outputChar = word
         FROM @numbersTable
         WHERE @charNumber = number
         SELECT @outputChar1 = word
         FROM @numbersDigit
         WHERE CONVERT(CHAR(1), @counter) = number
         IF @charNumber = N'1' AND LEN(@inputNumber) > 1 AND @counter = 1 AND @nextNumber > '0'
            SET @outputChar = N'เอ็ด'
         IF @charNumber = N'1' AND LEN(@inputNumber) >= 2 AND @counter = 2
            SET @outputChar = N''
         IF @charNumber = N'2' AND LEN(@inputNumber) >= 2 AND @counter = 2
            SET @outputChar = N'ยี่'
         IF @charNumber = N'0'
            SET @outputChar1 = N''
         SELECT @outputString1 = @outputChar + @outputChar1 + @outputString1
              , @counter = @counter + 1
              , @loops = @loops - 1
      END

      IF @bigCount < @bigLoops
         IF @outputString1 <> ''
            SET @outputString = @outputString + @outputString1 + N'ล้าน'
      IF @bigCount >= @bigLoops
         SET @outputString = @outputString + @outputString1 + @c_NumberSurfix
      SET @bigCount = @bigCount + 1
   END
   -- Decimal
   IF LEN(@inputDecimal) = 1
      SET @inputDecimal = N'0' + @inputDecimal
   SET @inputNumber = @inputDecimal
   SET @counter = 1
   SET @loops = LEN(@inputNumber)
   SET @outputString1 = N''
   SET @nextNumber = SUBSTRING(@inputNumber, @loops - 1, 1)
   WHILE 1 <= @loops
   BEGIN
      SET @charNumber = SUBSTRING(@inputNumber, @loops, 1)
      SELECT @outputChar = word
      FROM @numbersTable
      WHERE @charNumber = number
      SELECT @outputChar1 = word
      FROM @numbersDigit
      WHERE CONVERT(CHAR(1), @counter) = number
      IF @charNumber = N'1' AND LEN(@inputNumber) > 1 AND @counter = 1 AND @nextNumber > N'0'
         SET @outputChar = N'เอ็ด'
      IF @charNumber = N'1' AND LEN(@inputNumber) >= 2 AND @counter = 2
         SET @outputChar = N''
      IF @charNumber = N'2' AND LEN(@inputNumber) >= 2 AND @counter = 2
         SET @outputChar = N'ยี่'
      IF @charNumber = N'0'
         SET @outputChar1 = N''
      SELECT @outputString1 = @outputChar + @outputChar1 + @outputString1
           , @counter = @counter + 1
           , @loops = @loops - 1
   END
   IF @inputDecimal = N'00'
      SET @outputString = @outputString + N'ถ้วน'
   ELSE
      SET @outputString = @outputString + @outputString1 + @c_DecimalSurfix

   RETURN @outputString -- return the result
END

GO