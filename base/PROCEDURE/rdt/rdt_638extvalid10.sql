SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_638ExtValid10                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-06-26 1.0  Ung        WMS-22781 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtValid10] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60), 
   @cID           NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @cData1        NVARCHAR( 60),
   @cData2        NVARCHAR( 60),
   @cData3        NVARCHAR( 60),
   @cData4        NVARCHAR( 60),
   @cData5        NVARCHAR( 60),
   @cOption       NVARCHAR( 1),
   @dArriveDate   DATETIME,
   @tExtUpdateVar VariableTable READONLY,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nStep = 8 -- Finalize ASN
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOption = '1' -- YES
            BEGIN
               DECLARE @cSQL         NVARCHAR( MAX)
               DECLARE @cSQLParam    NVARCHAR( MAX)
               DECLARE @cColumnName  NVARCHAR( 20)
               DECLARE @nQTYExpected INT
               DECLARE @nQTYReceived INT
               
               DECLARE @curSearch CURSOR
               SET @curSearch = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT Code
                  FROM CodeLKUP WITH (NOLOCK)
                  WHERE ListName = 'REFNOLKUP'
                     AND StorerKey = @cStorerKey
                     AND Code2 = @cFacility
                  ORDER BY Short
               OPEN @curSearch
               FETCH NEXT FROM @curSearch INTO @cColumnName
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SET @cSQL = 
                     ' SELECT ' + 
                        ' @nQTYExpected = ISNULL( SUM( QTYExpected), 0), ' + 
                        ' @nQTYReceived = ISNULL( SUM( BeforeReceivedQTY), 0) ' + 
                     ' FROM dbo.Receipt R WITH (NOLOCK) ' + 
                        ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' + 
                     ' WHERE R.Facility = @cFacility ' + 
                        ' AND R.StorerKey = @cStorerKey ' + 
                        ' AND R.Status <> ''9'' ' + 
                        ' AND R.ASNStatus <> ''CANC'' ' + 
                        ' AND R.' + @cColumnName + ' = @cRefNo ' 
                  SET @cSQLParam = 
                     ' @cFacility    NVARCHAR( 5),  ' + 
                     ' @cStorerKey   NVARCHAR( 20), ' + 
                     ' @cRefNo       NVARCHAR( 20), ' + 
                     ' @nQTYExpected INT OUTPUT,    ' + 
                     ' @nQTYReceived INT OUTPUT     '  
               
                  EXEC sp_executeSQL @cSQL, @cSQLParam, 
                      @cFacility    = @cFacility   
                     ,@cStorerKey   = @cStorerKey  
                     ,@cRefNo       = @cRefNo      
                     ,@nQTYExpected = @nQTYExpected OUTPUT
                     ,@nQTYReceived = @nQTYReceived OUTPUT

                  -- Found the RefNo
                  IF @nQTYExpected > 0 OR @nQTYReceived > 0
                  BEGIN
                     -- Under receive
                     IF @nQTYExpected > @nQTYReceived
                     BEGIN
                        SET @nErrNo = 203051
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Under received
                        GOTO Quit
                     END
                     
                     BREAK
                  END
                  
                  FETCH NEXT FROM @curSearch INTO @cColumnName
               END
            END
         END
      END
   END

Quit:


GO