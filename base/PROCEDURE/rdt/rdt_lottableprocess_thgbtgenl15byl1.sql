SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_LottableProcess_THGBTGenL15ByL1                   */
/* Copyright      : LF                                                    */
/*                                                                        */
/* Purpose: Key-in batch # (L1), generate manufacturer date (L15)         */
/*                                                                        */
/* Date        Rev  Author      Purposes                                  */
/* 2021-08-12  1.0  James       WMS-17612. Created                        */
/**************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_THGBTGenL15ByL1]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cYearCode   NVARCHAR(2)
   DECLARE @cWeekCode   NVARCHAR(2)
   DECLARE @cDayCode    NVARCHAR(1)
   DECLARE @nShelfLife  INT
   DECLARE @nYearNum    INT
   DECLARE @nWeekNum    INT
   DECLARE @nDayNum     INT
   DECLARE @cYear       NVARCHAR(4)
   DECLARE @cMonth      NVARCHAR(2)
   DECLARE @cProdDate   NVARCHAR(30)
   DECLARE @dProdDate   DATETIME
   DECLARE @cTempLottable15   NVARCHAR( 60)
   DECLARE @cSUSR2            NVARCHAR( 18)
   DECLARE @cErrMessage       NVARCHAR( 20)

   SET @nErrNo = 0

   --IF @cType = 'PRE'
   --BEGIN
   --   SET @dLottable15 = ''
      
   --   GOTO Quit
   --END

   IF NOT EXISTS ( SELECT 1 FROM dbo.SKU (NOLOCK)
                   WHERE StorerKey = @cStorerKey
                   AND   SKU = @cSKU
                   AND   BUSR4 = 'ELEMIS')
      GOTO Quit
      --INSERT INTO traceinfo (TraceName, timein, Col1, Col2) VALUES ('123', GETDATE(), @cLottable01, @cLottable01Value)
   IF LEN( RTRIM( @cLottable01Value)) = 9 AND ISNUMERIC( SUBSTRING( @cLottable01Value, 1, 7)) = 1 AND SUBSTRING( @cLottable01Value, 8, 2) LIKE '[a-zA-Z][a-zA-Z]%'
   BEGIN
      SELECT @cMonth = Short
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'THGDECODE'
      AND   Code = '9CHARM'
      AND   code2 = SUBSTRING( @cLottable01Value, 4, 2)
      AND   Storerkey = @cStorerKey

      SELECT @cYear = Short
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'THGDECODE'
      AND   Code = '9CHARY'
      AND   code2 = SUBSTRING( @cLottable01Value, 6, 2)
      AND   Storerkey = @cStorerKey
      
      SET @cTempLottable15 = '01/' + @cMonth + '/' + @cYear
      SET @dLottable15 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @cTempLottable15, 103), 103)
      GOTO Quit
   END

   IF LEN( RTRIM( @cLottable01Value)) = 4 
   BEGIN
      DECLARE @n INT = 4, @c NVARCHAR( 1), @nNum INT = 0, @nChar INT = 0
      WHILE @n > 0
      BEGIN
         SET @c = SUBSTRING( @cLottable01Value, @n, 1)
         IF ISNUMERIC( @c) = 1 SET @nNum = @nNum + 1 ELSE SET @nChar = @nChar + 1
         SET @n = @n - 1
      END

      IF @nNum = 3 AND @nChar = 1
      BEGIN
         SELECT @cMonth = Short
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'THGDECODE'
         AND   Code = '4CHARM'
         AND   code2 = SUBSTRING( @cLottable01Value, 3, 1)
         AND   Storerkey = @cStorerKey

         SELECT @cYear = Short
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'THGDECODE'
         AND   Code = '4CHARY'
         AND   code2 = SUBSTRING( @cLottable01Value, 4, 1)
         AND   Storerkey = @cStorerKey
      
         SET @cTempLottable15 = '01/' + @cMonth + '/' + @cYear
         SET @dLottable15 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @cTempLottable15, 103), 103)
      END
      GOTO Quit
   END

   IF LEN( RTRIM( @cLottable01Value)) = 8 AND ISNUMERIC( SUBSTRING( @cLottable01Value, 1, 7)) = 1 AND SUBSTRING( @cLottable01Value, 8, 1) LIKE '[a-zA-Z]%'
   BEGIN
      SELECT @cMonth = Short
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'THGDECODE'
      AND   Code = '8CHARM'
      AND   code2 = SUBSTRING( @cLottable01Value, 4, 2)
      AND   Storerkey = @cStorerKey

      SELECT @cYear = Short
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'THGDECODE'
      AND   Code = '8CHARY'
      AND   code2 = SUBSTRING( @cLottable01Value, 6, 2)
      AND   Storerkey = @cStorerKey
      
      SET @cTempLottable15 = '01/' + @cMonth + '/' + @cYear
      SET @dLottable15 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @cTempLottable15, 103), 103)
      GOTO Quit
   END

   IF LEN( RTRIM( @cLottable01Value)) = 8 AND SUBSTRING( @cLottable01Value, 4, 1) = '-'
   BEGIN
      SELECT @cMonth = Short
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'THGDECODE'
      AND   Code = '8-CHARM'
      AND   code2 = SUBSTRING( @cLottable01Value, 5, 2)
      AND   Storerkey = @cStorerKey

      SELECT @cYear = Short
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'THGDECODE'
      AND   Code = '8-CHARY'
      AND   code2 = SUBSTRING( @cLottable01Value, 7, 2)
      AND   Storerkey = @cStorerKey
      
      SET @cTempLottable15 = '01/' + @cMonth + '/' + @cYear
      SET @dLottable15 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @cTempLottable15, 103), 103)
      GOTO Quit
   END

   Quit:

END -- End Procedure


GO