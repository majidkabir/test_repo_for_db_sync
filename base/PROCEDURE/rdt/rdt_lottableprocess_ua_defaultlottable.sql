SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_UA_DefaultLottable                    */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 06-Mar-2019  James     1.0   WMS8158 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_UA_DefaultLottable]
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCountryOfOrigin     NVARCHAR( 30)
   DECLARE @nStep                INT,
           @cDataType            NVARCHAR( 30),
           @cNewSKU              NVARCHAR( 1)

   DECLARE @cExecStatements      NVARCHAR( MAX),
           @cExecArguments       NVARCHAR( MAX)

   DECLARE @cRDLottable01        NVARCHAR( 18),
           @cRDLottable02        NVARCHAR( 18) ,
           @cRDLottable03        NVARCHAR( 18),
           @dRDLottable04        DATETIME,
           @dRDLottable05        DATETIME,
           @cRDLottable06        NVARCHAR( 30),
           @cRDLottable07        NVARCHAR( 30),
           @cRDLottable08        NVARCHAR( 30),
           @cRDLottable09        NVARCHAR( 30),
           @cRDLottable10        NVARCHAR( 30),
           @cRDLottable11        NVARCHAR( 30),
           @cRDLottable12        NVARCHAR( 30),
           @dRDLottable13        DATETIME,
           @dRDLottable14        DATETIME,
           @dRDLottable15        DATETIME

   SELECT @nStep = Step
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cCountryOfOrigin = CountryOfOrigin
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   SET @cNewSKU = '0'

   IF NOT EXISTS ( SELECT 1 
                     FROM dbo.ReceiptDetail WITH (NOLOCK) 
                     WHERE ReceiptKey = SUBSTRING( @cSourceKey, 1, 10)
                     AND   SKU = @cSKU)
   BEGIN
      SET @cNewSKU = '1'
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                  WHERE ReceiptKey = SUBSTRING( @cSourceKey, 1, 10)
                  AND   SKU = @cSKU
                  AND   UserDefine10 = 'NEWSKU')
         SET @cNewSKU = '1'
   END

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cNewSKU = '0'
         BEGIN
            SELECT TOP 1
               @cRDLottable01 = Lottable01,
               @cRDLottable02 = Lottable02,
               @cRDLottable03 = Lottable03,
               @dRDLottable04 = Lottable04,
               @dRDLottable05 = Lottable05,
               @cRDLottable06 = Lottable06,
               @cRDLottable07 = Lottable07,
               @cRDLottable08 = Lottable08,
               @cRDLottable09 = Lottable09,
               @cRDLottable10 = Lottable10,
               @cRDLottable11 = Lottable11,
               @cRDLottable12 = Lottable12,
               @dRDLottable13 = Lottable13,
               @dRDLottable14 = Lottable14,
               @dRDLottable15 = Lottable15
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = SUBSTRING( @cSourceKey, 1, 10)
            AND   SKU = @cSKU
            ORDER BY ReceiptLineNumber
            --insert into TraceInfo (tracename, TimeIn, Col1) values ('607', getdate(), @cRDLottable08)
            --IF @cCountryOfOrigin <> '99'
            --BEGIN
            IF @nLottableNo = 1  SET @cLottable01 = @cRDLottable01
            IF @nLottableNo = 2  SET @cLottable02 = @cRDLottable02
            IF @nLottableNo = 3  SET @cLottable03 = @cRDLottable03
            IF @nLottableNo = 4  SET @dLottable04 = @dRDLottable04
            IF @nLottableNo = 5  SET @dLottable05 = @dRDLottable05
            IF @nLottableNo = 6  SET @cLottable06 = @cRDLottable06
            IF @nLottableNo = 7  SET @cLottable07 = @cRDLottable07
            IF @nLottableNo = 8  SET @cLottable08 = @cRDLottable08
            IF @nLottableNo = 9  SET @cLottable09 = @cRDLottable09
            IF @nLottableNo = 10  SET @cLottable10 = @cRDLottable10
            IF @nLottableNo = 11  SET @cLottable11 = @cRDLottable11
            IF @nLottableNo = 12  SET @cLottable12 = @cRDLottable12
            IF @nLottableNo = 13  SET @dLottable13 = @dRDLottable13
            IF @nLottableNo = 14  SET @dLottable14 = @dRDLottable14
            IF @nLottableNo = 15  SET @dLottable15 = @dRDLottable15
            --END
         END
         ELSE
         BEGIN
            IF @nLottableNo = 1  SET @cLottable01 = ''
            IF @nLottableNo = 2  SET @cLottable02 = ''
            IF @nLottableNo = 3  SET @cLottable03 = ''
            IF @nLottableNo = 4  SET @dLottable04 = ''
            IF @nLottableNo = 5  SET @dLottable05 = ''
            IF @nLottableNo = 6  SET @cLottable06 = ''
            IF @nLottableNo = 7  SET @cLottable07 = ''
            IF @nLottableNo = 8  SET @cLottable08 = ''
            IF @nLottableNo = 9  SET @cLottable09 = ''
            IF @nLottableNo = 10  SET @cLottable10 = ''
            IF @nLottableNo = 11  SET @cLottable11 = ''
            IF @nLottableNo = 12  SET @cLottable12 = ''
            IF @nLottableNo = 13  SET @dLottable13 = ''
            IF @nLottableNo = 14  SET @dLottable14 = ''
            IF @nLottableNo = 15  SET @dLottable15 = ''
         END
      END
   END


   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
            SELECT TOP 1
               @cRDLottable01 = Lottable01,
               @cRDLottable02 = Lottable02,
               @cRDLottable03 = Lottable03,
               @dRDLottable04 = Lottable04,
               @dRDLottable05 = Lottable05,
               @cRDLottable06 = Lottable06,
               @cRDLottable07 = Lottable07,
               @cRDLottable08 = Lottable08,
               @cRDLottable09 = Lottable09,
               @cRDLottable10 = Lottable10,
               @cRDLottable11 = Lottable11,
               @cRDLottable12 = Lottable12,
               @dRDLottable13 = Lottable13,
               @dRDLottable14 = Lottable14,
               @dRDLottable15 = Lottable15
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = SUBSTRING( @cSourceKey, 1, 10)
            AND   SKU = @cSKU
            AND   ( ( @cNewSKU = '1' AND 1 = 0) OR ( @cNewSKU = '0'))
            ORDER BY ReceiptLineNumber

            SET @cRDLottable01 = ISNULL( @cRDLottable01, '')
            SET @cRDLottable02 = ISNULL( @cRDLottable02, '')
            SET @cRDLottable03 = ISNULL( @cRDLottable03, '')
            SET @dRDLottable04 = ISNULL( @dRDLottable04, 0)
            SET @dRDLottable05 = ISNULL( @dRDLottable05, 0)
            SET @cRDLottable06 = ISNULL( @cRDLottable06, '')
            SET @cRDLottable07 = ISNULL( @cRDLottable07, '')
            SET @cRDLottable08 = ISNULL( @cRDLottable08, '')
            SET @cRDLottable09 = ISNULL( @cRDLottable09, '')
            SET @cRDLottable10 = ISNULL( @cRDLottable10, '')
            SET @cRDLottable11 = ISNULL( @cRDLottable11, '')
            SET @cRDLottable12 = ISNULL( @cRDLottable12, '')
            SET @dRDLottable13 = ISNULL( @dRDLottable13, 0)
            SET @dRDLottable14 = ISNULL( @dRDLottable14, 0)
            SET @dRDLottable15 = ISNULL( @dRDLottable15, 0)

            IF @nLottableNo IN (1, 2, 3)
               SET @cDataType = 'AS NVARCHAR( 18)'

            IF @nLottableNo IN (6, 7, 8,9, 10)
               SET @cDataType = 'AS NVARCHAR( 30)'

            IF @nLottableNo IN (4, 5, 13, 14, 15)
               SET @cDataType = 'AS DATETIME'

            SET @cExecStatements = '
               DECLARE @cLottable' + REPLICATE( '0', 2 - LEN( @nLottableNo)) +  CAST( @nLottableNo AS NVARCHAR( 2)) + ' ' + @cDataType + ' 

               SET @cLottable' + REPLICATE( '0', 2 - LEN( @nLottableNo)) +  CAST( @nLottableNo AS NVARCHAR( 2)) + ' = @cLottable' + '

               IF @nLottableNo = ' + CAST( @nLottableNo AS NVARCHAR( 2)) + '
               BEGIN
                  IF ISNULL( @cLottable' + REPLICATE( '0', 2 - LEN( @nLottableNo)) +  CAST( @nLottableNo AS NVARCHAR( 2)) + ' , '''') = ''''
                  BEGIN
                     SET @nErrNo = 135551
                     GOTO Fail
                  END

                  IF @nLottableNo = 8
                  BEGIN
                     IF @cRDLottable' + REPLICATE( '0', 2 - LEN( @nLottableNo)) + CAST( @nLottableNo AS NVARCHAR( 2)) + ' <> '''' AND @cLottable' + REPLICATE( '0', 2 - LEN( @nLottableNo)) + CAST( @nLottableNo AS NVARCHAR( 2)) + ' <> @cRDLottable' + REPLICATE( '0', 2 - LEN( @nLottableNo)) + CAST( @nLottableNo AS NVARCHAR( 2)) + '
                     BEGIN
                        SET @nErrNo = 135552
                        GOTO Fail
                     END
                  END

                  IF NOT EXISTS ( SELECT 1 FROM CODELKUP WITH (NOLOCK) 
                              WHERE LISTNAME = ''UALOTTABLE''
                              AND   Short = '''  + CAST( @nLottableNo AS NVARCHAR( 2)) + '''
                              AND   Storerkey = @cStorerKey
                              AND   Long = @cLottable' + REPLICATE( '0', 2 - LEN( @nLottableNo)) +  CAST( @nLottableNo AS NVARCHAR( 2)) + '
                              AND   code2 = @nFunc)
                  BEGIN
                     SET @nErrNo = 135553
                     GOTO Fail
                  END
               END
               
               Fail:'

            SET @cExecArguments =  N'@nFunc           INT,
                                     @nLottableNo     INT, 
                                     @cStorerKey      NVARCHAR( 15),
                                     @cLottable       NVARCHAR( 30),
                                     @cRDLottable01   NVARCHAR( 15),
                                     @cRDLottable02   NVARCHAR( 15),
                                     @cRDLottable03   NVARCHAR( 15),
                                     @dRDLottable04   DATETIME,
                                     @dRDLottable05   DATETIME,
                                     @cRDLottable06   NVARCHAR( 30),
                                     @cRDLottable07   NVARCHAR( 30),
                                     @cRDLottable08   NVARCHAR( 30),
                                     @cRDLottable09   NVARCHAR( 30),
                                     @cRDLottable10   NVARCHAR( 30),
                                     @cRDLottable11   NVARCHAR( 30),
                                     @cRDLottable12   NVARCHAR( 30),
                                     @dRDLottable13   DATETIME,
                                     @dRDLottable14   DATETIME,
                                     @dRDLottable15   DATETIME,
                                     @nErrNo          INT   OUTPUT'
      
            EXEC sp_ExecuteSql @cExecStatements
                              ,@cExecArguments
                              ,@nFunc
                              ,@nLottableNo
                              ,@cStorerKey
                              ,@cLottable
                              ,@cRDLottable01
                              ,@cRDLottable02
                              ,@cRDLottable03
                              ,@dRDLottable04
                              ,@dRDLottable05
                              ,@cRDLottable06
                              ,@cRDLottable07
                              ,@cRDLottable08
                              ,@cRDLottable09
                              ,@cRDLottable10
                              ,@cRDLottable11
                              ,@cRDLottable12
                              ,@dRDLottable13
                              ,@dRDLottable14
                              ,@dRDLottable15
                              ,@nErrNo       OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               --delete from TraceInfo where TraceName = 'ualot'
               --insert into TraceInfo (TraceName, timein, Col1, Col2, Col3) values ('ualot', getdate(), @nLottableNo, @cLottable08, @cRDLottable08)
               IF @nLottableNo = 1  SET @cLottable01 = @cRDLottable01
               IF @nLottableNo = 2  SET @cLottable02 = @cRDLottable02
               IF @nLottableNo = 3  SET @cLottable03 = @cRDLottable03
               IF @nLottableNo = 4  SET @dLottable04 = @dRDLottable04
               IF @nLottableNo = 5  SET @dLottable05 = @dRDLottable05
               IF @nLottableNo = 6  SET @cLottable06 = @cRDLottable06
               IF @nLottableNo = 7  SET @cLottable07 = @cRDLottable07
               IF @nLottableNo = 8  SET @cLottable08 = @cRDLottable08
               IF @nLottableNo = 9  SET @cLottable09 = @cRDLottable09
               IF @nLottableNo = 10  SET @cLottable10 = @cRDLottable10
               IF @nLottableNo = 11  SET @cLottable11 = @cRDLottable11
               IF @nLottableNo = 12  SET @cLottable12 = @cRDLottable12
               IF @nLottableNo = 13  SET @dLottable13 = @dRDLottable13
               IF @nLottableNo = 14  SET @dLottable14 = @dRDLottable14
               IF @nLottableNo = 15  SET @dLottable15 = @dRDLottable15
            END
         END
      END
   END
   

GO