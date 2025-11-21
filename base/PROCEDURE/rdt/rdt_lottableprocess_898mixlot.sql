SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************************************/
/* Store procedure: rdt_LottableProcess_898MixLot                                                      */
/* Copyright      : Maersk                                                                             */
/*                                                                                                     */
/* Purpose: Disallow Mixing of Attribute                                                               */
/*                                                                                                     */
/* Date         Author    Ver.  Purposes                                                               */
/* 2024-09-24   PXL009    1.0   FCR-875    Created                                                     */
/*******************************************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_898MixLot]
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
   ,@cErrMsg          NVARCHAR( 50) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE
   @nStep        INT,           
   @cFacility    NVARCHAR( 5), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @nRowCount            INT,
   @cexternReceiptKey    NVARCHAR( 30), 
   @cexternLineNo        NVARCHAR( 30),    
   @nLotNum              INT,
   @cListName            NVARCHAR( 30),
   @cLotValue            NVARCHAR( 30),     
   @cStorerConfig        NVARCHAR( 50),  
   @cSQLHead             NVARCHAR( MAX),
   @cSQLBody             NVARCHAR( MAX),
   @cSQLFoot             NVARCHAR( MAX),
   @cSQLParam            NVARCHAR( MAX),
   @cUserDefine08        NVARCHAR( 30),  
   @nSQLResult           INT,
   @cLott10              NVARCHAR( 30),
   @dLotDate             DATETIME,
   @cColumn              NVARCHAR( 30),
   @cLastLot             NVARCHAR( 20)='',
   @cSQL                 NVARCHAR( MAX)

   print '[RDT].[rdt_LottableProcess_898MixLot] enter'
   SELECT
   @nFunc      = Func,
   @nStep      = Step,
   @nInputKey  = InputKey,

   @cFacility  = Facility,
   @cReceiptKey = V_Receiptkey,
   @cPOKey      = V_POKey,
   @cLOC        = V_Loc,
   @cID         = V_ID
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cStorerConfig = ISNULL(rdt.RDTGetConfig( @nFunc, 'DisAllowMixPallet', @cStorerKey), '')
   SET @cSQLHead='SELECT TOP 1 @cLastLot = ISNULL(RD.'
   SET @cSQLBody = ','''')
               FROM dbo.Receipt R WITH (NOLOCK)
                  INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
               WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                  AND R.ReceiptKey = @cReceiptKey AND (@cPOKey=''NOPO'' or RD.POKey = @cPOKey)
                  AND RD.ToId = @cID AND RD.Sku = @cSKU 
               ORDER BY RD.ReceiptLineNumber

               IF @@ROWCOUNT <> 0 AND @cLastLot <> ISNULL('
   SET @cSQLFoot = '
               ,'''')
               BEGIN
                  SET @nErrNo = 224751
                  SET @cErrMsg = rdt.rdtgetmessageLong( @nErrNo, ''ENG'', ''DSP'') 
               END
               '
   SET @cSQLParam =
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cPOKey       NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLottable01  NVARCHAR( 18), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@cLottable03  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,      ' +
               '@dLottable05  DATETIME,      ' +
               '@cLottable06  NVARCHAR( 30), ' +
               '@cLottable07  NVARCHAR( 30), ' +
               '@cLottable08  NVARCHAR( 30), ' +
               '@cLottable09  NVARCHAR( 30), ' +
               '@cLottable10  NVARCHAR( 30), ' +
               '@cLottable11  NVARCHAR( 30), ' +
               '@cLottable12  NVARCHAR( 30), ' +
               '@dLottable13  DATETIME,      ' +
               '@dLottable14  DATETIME,      ' +
               '@dLottable15  DATETIME,      ' +
               '@cLastLot     NVARCHAR( 20) OUTPUT,'+
               '@nErrNo       INT         OUTPUT, 
                @cErrMsg      NVARCHAR(20)  OUTPUT'

   IF @nFunc = 898 -- UCC Receive
   BEGIN
      IF @nStep = 5 OR  @nStep = 8
      BEGIN
      	IF @nInputKey = 1
      	BEGIN
            select 1
               IF @cStorerConfig != ''
               BEGIN
                  DECLARE LIST CURSOR FOR 
                  SELECT Code2 FROM codelkup (NOLOCK) WHERE Listname = @cStorerConfig 
                  AND Storerkey = @cStorerKey AND Code = '898'                  
                  OPEN LIST
                  FETCH NEXT FROM LIST INTO @cColumn
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     DECLARE @cTempLotLabel NVARCHAR(20)
                     SET @cTempLotLabel = CONCAT('Lottable',CASE WHEN @nLottableNo < 10 THEN '0' ELSE '' END, @nLottableNo)
                     IF  @cTempLotLabel = @cColumn
                        OR 'LOT' = @cColumn
                     BEGIN
                        SET @cSQL = @cSQLHead + @cTempLotLabel + @cSQLBody
                        IF @cTempLotLabel IN ('Lottable04','Lottable05','Lottable13','Lottable14','Lottable15' )
                           SET  @cSQL = @cSQL + '@d' + @cTempLotLabel
                        ELSE 
                           SET  @cSQL = @cSQL + '@c' + @cTempLotLabel
                        SET @cSQL = @cSQL + @cSQLFoot

                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                           @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cID, @cSKU,
                           @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                           @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                           @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                           @cLastLot OUTPUT,@nErrNo OUTPUT,@cErrMsg OUTPUT
                        IF @nErrNo <> 0
                        BEGIN
                           DECLARE @clotLabel NVARCHAR(200)=''
                           SELECT @clotLabel = [Description]
                           FROM RDT.rdtLottableCode (NOLOCK)
                           WHERE Function_ID = @nFunc AND LottableNo = @nLottableNo
                           AND LottableCode = @cLottableCode AND StorerKey = @cStorerKey

                           EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg,
                           'Mix',
                           @clotLabel,
                           'Not Allowed On ID'
                        END
                        GOTO CLOSELIST
                     END
                     SET @cSQL = ''
                     FETCH NEXT FROM LIST INTO @cColumn
                  END
                  GOTO CLOSELIST
               END
      	END
      END
   END              

CLOSELIST:
   CLOSE LIST
   DEALLOCATE LIST
   GOTO Fail
 
Fail:

END


GO