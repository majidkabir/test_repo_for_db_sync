SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_638ExtInfo01                                       */
/* Purpose: Validate TO ID                                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2021-04-26 1.0  James      WMS-16668 Created                            */
/* 2021-07-02 1.1  James      WMS-17405 Add @nAfterStep param (james01)    */
/* 2022-09-23 1.2  YeeKung    WMS-20820 Extended refno length (yeekung01)  */
/* 2023-01-04 1.3  James      WMS-21408 Add item flag popup (james02)      */
/* 2023-05-11 1.4  Ung        WMS-22302 Fix ExtendedInfoSP AfterStep       */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtInfo01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT ,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60), --(yeekung01)
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
   @tExtInfoVar   VariableTable READONLY,
   @cExtendedInfo NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cColumnName    NVARCHAR( 20)
   DECLARE @nTtl_ASN       INT
   DECLARE @nTtl_Qty       INT
   DECLARE @curPM          CURSOR
   DECLARE @cPM            NVARCHAR( 30)
   DECLARE @cTempFlag      NVARCHAR( 20) = ''
   DECLARE @nErrNo         INT
   DECLARE @cErrMsg        NVARCHAR( 20)
   DECLARE @cErrMsg1       NVARCHAR( 20)
   
   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nAfterStep = 3 -- SKU, Qty
      BEGIN
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
            -- Check column valid
            IF NOT EXISTS( SELECT 1
               FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_NAME = 'Receipt'
                  AND COLUMN_NAME = @cColumnName
                  AND DATA_TYPE = 'nvarchar')
               GOTO Quit

            SET @cSQL =
               ' SELECT @nTtl_ASN = COUNT( DISTINCT R.ReceiptKey), @nTtl_Qty = SUM( RD.QtyExpected) ' +
               ' FROM dbo.Receipt R WITH (NOLOCK) ' +
               ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' +
               ' WHERE R.Facility = @cFacility ' +
                  ' AND R.StorerKey = @cStorerKey ' +
                  ' AND R.Status <> ''9'' ' +
                  ' AND R.ASNStatus NOT IN (''CANC'', ''9'') ' +
                  ' AND R.' + @cColumnName + ' = @cRefNo '
            SET @cSQLParam =
               ' @cFacility      NVARCHAR(5),  ' +
               ' @cStorerKey     NVARCHAR(15), ' +
               ' @cRefNo         NVARCHAR(20), ' +
               ' @nTtl_ASN       INT   OUTPUT, ' +
               ' @nTtl_Qty       INT   OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cFacility,
               @cStorerKey,
               @cRefNo,
               @nTtl_ASN    OUTPUT,
               @nTtl_Qty    OUTPUT

            SET @cExtendedInfo = 'ASN: ' + CAST( @nTtl_ASN AS NVARCHAR( 2)) + '   QTY: ' + CAST( @nTtl_Qty AS NVARCHAR( 5))

            IF @nTtl_ASN > 0
               BREAK

            FETCH NEXT FROM @curSearch INTO @cColumnName
         END
         CLOSE @curSearch
         DEALLOCATE @curSearch
      END
      
      IF @nStep = 1 AND  -- ASN
         @nAfterStep = 3 -- SKU, Qty
      BEGIN
         IF @nInputKey = 1
         BEGIN
            -- (james02)
            IF OBJECT_ID('tempdb..#ASN') IS NOT NULL
               DROP TABLE #ASN

            CREATE TABLE #ASN  (
               ReceiptKey     NVARCHAR( 10))

            IF OBJECT_ID('tempdb..#ProductModel') IS NOT NULL
               DROP TABLE #ProductModel

            CREATE TABLE #ProductModel  (
               ProductModel     NVARCHAR( 30))

            SET @cSQL = ''
            SET @cSQLParam = ''
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
               -- Check column valid
               IF NOT EXISTS( SELECT 1
                  FROM INFORMATION_SCHEMA.COLUMNS
                  WHERE TABLE_NAME = 'Receipt'
                     AND COLUMN_NAME = @cColumnName
                     AND DATA_TYPE = 'nvarchar')
                  GOTO Quit
                  
               SET @cSQL =
                  ' INSERT INTO #ASN (ReceiptKey) ' +
                  ' SELECT DISTINCT R.ReceiptKey ' +
                  ' FROM dbo.Receipt R WITH (NOLOCK) ' +
                  ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' +
                  ' WHERE R.Facility = @cFacility ' +
                     ' AND R.StorerKey = @cStorerKey ' +
                     ' AND R.Status <> ''9'' ' +
                     ' AND R.ASNStatus NOT IN (''CANC'', ''9'') ' +
                     ' AND R.' + @cColumnName + ' = @cRefNo '
               SET @cSQLParam =
                  ' @cFacility      NVARCHAR(5),  ' +
                  ' @cStorerKey     NVARCHAR(15), ' +
                  ' @cRefNo         NVARCHAR(20)  ' 
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @cFacility,
                  @cStorerKey,
                  @cRefNo
               
               FETCH NEXT FROM @curSearch INTO @cColumnName
            END
            
            INSERT INTO #ProductModel (ProductModel)
            SELECT DISTINCT ( RIGHT( SKU.AltSku, 5)) 
            FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( RD.StorerKey = SKU.StorerKey AND RD.Sku = SKU.Sku)
            WHERE EXISTS ( SELECT 1 FROM #ASN ASN WHERE ASN.ReceiptKey = RD.ReceiptKey)
            AND   SKU.ProductModel = 'TRI'

            IF @@ROWCOUNT > 0
            BEGIN
               SET @curPM = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT ProductModel FROM #ProductModel
               OPEN @curPM
               FETCH NEXT FROM @curPM INTO @cPM
               WHILE @@FETCH_STATUS = 0
               BEGIN
               	SET @cTempFlag = @cTempFlag + RTRIM( @cPM) + ','
               	
               	FETCH NEXT FROM @curPM INTO @cPM
               END
               
               SET @cTempFlag = REVERSE( STUFF( REVERSE( @cTempFlag), 1, 1, ''))
               
               SET @nErrNo = 0  
               SET @cErrMsg1 = @cTempFlag  
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1  
               IF @nErrNo = 1  
                  SET @cErrMsg1 = ''  
               SET @nErrNo = 0 
            END
         END
      END
   END

Quit:


GO