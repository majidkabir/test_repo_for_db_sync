SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_598ExtUpd06                                           */
/* Copyright: Maersk                                                          */
/* Customer:  Barry Callebaut                                                 */
/*                                                                            */
/* Date         Author    Ver.    Purposes                                    */
/* 2024-07-16   PYU015    1.0.0   UWP-26490 Created                           */
/* 2024-12-12   PYU015    1.1.0   UWP-28366 Merge code                        */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_598ExtUpd06] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cRefNo       NVARCHAR( 20),
   @cColumnName  NVARCHAR( 20),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   @nQTY         INT,
   @cReasonCode  NVARCHAR( 10),
   @cSuggToLOC   NVARCHAR( 10),
   @cFinalLOC    NVARCHAR( 10),
   @cReceiptKey  NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nStep = 6 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cOption           NVARCHAR(2)
            DECLARE @cBatchPrefixU     NVARCHAR(10)
            DECLARE @cBatchPrefixNotU  NVARCHAR(10)

            SELECT @cBatchPrefixNotU = Short
            FROM dbo.CODELKUP WITH(NOLOCK)
             WHERE LISTNAME = 'RPTREASON'
               AND Storerkey = @cStorerKey
               AND code = 'BatchPrefixNotU'

            SELECT @cBatchPrefixU = Short
            FROM dbo.CODELKUP WITH(NOLOCK)
             WHERE LISTNAME = 'RPTREASON'
               AND Storerkey = @cStorerKey
               AND code = 'BatchPrefixU'

            IF @cBatchPrefixNotU IS NULL
            BEGIN
               SET @cBatchPrefixNotU = 'OK'
            END

            IF @cBatchPrefixU IS NULL
            BEGIN
               SET @cBatchPrefixU = 'OK'
            END

            UPDATE dbo.RECEIPTDETAIL WITH(ROWLOCK)
               SET ConditionCode = CASE WHEN substring(Lottable01,1,1) = 'U' THEN @cBatchPrefixU ELSE @cBatchPrefixNotU END
             WHERE StorerKey = @cStorerKey
               AND ReceiptKey = @cReceiptKey
               AND ToId = @cID


            SELECT @cOption = Code 
            FROM dbo.CODELKUP WITH(NOLOCK)
             WHERE Storerkey = @cStorerKey
               AND LISTNAME = 'RDTLBLRPT'
               AND code2 = 'FULLLPWGT' 

            -- Print label
            EXEC RDT.rdt_593PrintHK01
                @nMobile    ,
                @nFunc      ,
                @nStep      ,
                @cLangCode  ,
                @cStorerKey ,
                @cOption    ,
                @cReceiptKey,
                @cID        ,
                ''          ,
                ''          ,
                ''          ,
                @nErrNo     OUTPUT,
                @cErrMsg    OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            /*
            IF ISNULL(@cLottable08,'0') != '0'  AND ISNULL(@cLottable09,'0') != '0'
            BEGIN
                SELECT @cOption = Code 
                  FROM CODELKUP with(nolock)
                 WHERE Storerkey = @cStorerKey
                   AND LISTNAME = 'RDTLBLRPT'
                   AND code2 = 'SWEEPINGBAG' 

               EXEC RDT.rdt_593PrintHK01
                    @nMobile    ,
                    @nFunc      ,
                    @nStep      ,
                    @cLangCode  ,
                    @cStorerKey ,
                    @cOption    ,
                    @cReceiptKey,
                    ''          ,
                    ''          ,
                    ''          ,
                    ''          ,
                    @nErrNo     OUTPUT,
                    @cErrMsg    OUTPUT
                IF @nErrNo <> 0
                   GOTO Quit
            END
            */
         END
      END
   END

Quit:
END


GO