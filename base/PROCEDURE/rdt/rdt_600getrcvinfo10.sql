SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/
/* Store procedure: rdt_600GetRcvInfo10                                       */
/* Copyright: Maersk                                                          */
/* Client   : Indietx                                                         */
/* ConfigKey: GetReceiveInfoSP (rdt.StorerConfig)                             */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2024-10-18  YYS027    1.0   FCR-840 Conditional Default of Lottable        */
/******************************************************************************/

CREATE   PROC rdt.rdt_600GetRcvInfo10 (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18)  OUTPUT, 
   @cSKU         NVARCHAR( 20)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @cLottable01  NVARCHAR( 18)  OUTPUT, 
   @cLottable02  NVARCHAR( 18)  OUTPUT, 
   @cLottable03  NVARCHAR( 18)  OUTPUT, 
   @dLottable04  DATETIME       OUTPUT, 
   @dLottable05  DATETIME       OUTPUT, 
   @cLottable06  NVARCHAR( 30)  OUTPUT, 
   @cLottable07  NVARCHAR( 30)  OUTPUT, 
   @cLottable08  NVARCHAR( 30)  OUTPUT, 
   @cLottable09  NVARCHAR( 30)  OUTPUT, 
   @cLottable10  NVARCHAR( 30)  OUTPUT, 
   @cLottable11  NVARCHAR( 30)  OUTPUT, 
   @cLottable12  NVARCHAR( 30)  OUTPUT, 
   @dLottable13  DATETIME       OUTPUT, 
   @dLottable14  DATETIME       OUTPUT, 
   @dLottable15  DATETIME       OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @cDistinctLottableDefault VARCHAR(200)
   DECLARE @tLots TABLE(LottableNo VARCHAR(50), RowID INT)
   DECLARE @nCfgCount      INT,
           @nCfgIdx        INT,
           @nLotNo         INT,
           @nDistinctCount INT,
           @cSQL           NVARCHAR(max),
           @cField         NVARCHAR(1000),
           @cAssign        NVARCHAR(1000),
           @cAssignEmpty   NVARCHAR(1000),
           @cNotEmpty      NVARCHAR(1000),
           @cSQLParam      NVARCHAR(1000)
   DECLARE @nDebugFlag     INT = 0

   IF @nDebugFlag > 0 
      PRINT 'Enter rdt_600GetRcvInfo10'

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- default action, query all lottable to get values if lottable no is not defined in DistinctLottableDefault
            SELECT TOP 1
               @cLottable01 = Lottable01,
               @cLottable02 = Lottable02,
               @cLottable03 = Lottable03,
               @dLottable04 = Lottable04,
               @dLottable05 = Lottable05,
               @cLottable06 = Lottable06,
               @cLottable07 = Lottable07,
               @cLottable08 = Lottable08,
               @cLottable09 = Lottable09,
               @cLottable10 = Lottable10,
               @cLottable11 = Lottable11,
               @cLottable12 = Lottable12,
               @dLottable13 = Lottable13,
               @dLottable14 = Lottable14,
               @dLottable15 = Lottable15
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
               AND SKU = @cSKU
            ORDER BY
               CASE WHEN @cID = ToID THEN 0 ELSE 1 END,
               CASE WHEN QTYExpected > 0 AND QTYExpected > BeforeReceivedQTY THEN 0 ELSE 1 END,
               ReceiptLineNumber
            SET @cDistinctLottableDefault = rdt.RDTGetConfig( @nFunc, 'DistinctLottableDefault', @cStorerKey)
            IF isnull(@cDistinctLottableDefault,'') IN ('','0')         --default action, copy from rdtfnc_NormalReceipt_V7 
            BEGIN
               GOTO Quit
            END
            --handle distinct
            --        if count(distinct)=1, requery, 
            --        otherwise, clear variable @lottablexx
            INSERT INTO @tLots(LottableNo,RowID) 
               SELECT value,ROW_NUMBER() OVER(ORDER BY value) AS RowID 
               FROM STRING_SPLIT(@cDistinctLottableDefault,',') WHERE ISNUMERIC(value)=1 ORDER BY CONVERT(INT,value)
            SELECT @nCfgCount = COUNT(1) FROM @tLots
            SELECT @nCfgIdx=0, @nCfgCount = ISNULL(@nCfgCount,0)
            IF @nCfgCount<=0
            BEGIN
               SET @nErrNo = 226601;
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- invalid config
               GOTO Quit
            END 
            WHILE(@nCfgIdx<@nCfgCount)
            BEGIN
               SELECT @nCfgIdx = @nCfgIdx + 1
               SELECT @nLotNo = CONVERT(INT, LottableNo) FROM @tLots WHERE RowID = @nCfgIdx
               SELECT @cField='', @cAssign='', @cAssignEmpty='', @cNotEmpty=''
               IF @nLotNo =1  SELECT @cField = 'Lottable01',@cAssign='@cLottable01=Lottable01',@cAssignEmpty='@cLottable01=''''',@cNotEmpty='ISNULL(Lottable01,'''')<>'''''            ELSE
               IF @nLotNo =2  SELECT @cField = 'Lottable02',@cAssign='@cLottable02=Lottable02',@cAssignEmpty='@cLottable02=''''',@cNotEmpty='ISNULL(Lottable02,'''')<>'''''            ELSE
               IF @nLotNo =3  SELECT @cField = 'Lottable03',@cAssign='@cLottable03=Lottable03',@cAssignEmpty='@cLottable03=''''',@cNotEmpty='ISNULL(Lottable03,'''')<>'''''            ELSE
               IF @nLotNo =4  SELECT @cField = 'Lottable04',@cAssign='@dLottable04=Lottable04',@cAssignEmpty='@cLottable04=NULL',@cNotEmpty='NOT(Lottable04 IS NULL OR Lottable04=0)'  ELSE
               IF @nLotNo =5  SELECT @cField = 'Lottable05',@cAssign='@dLottable05=Lottable05',@cAssignEmpty='@cLottable05=NULL',@cNotEmpty='NOT(Lottable05 IS NULL OR Lottable05=0)'  ELSE
               IF @nLotNo =6  SELECT @cField = 'Lottable06',@cAssign='@cLottable06=Lottable06',@cAssignEmpty='@cLottable06=''''',@cNotEmpty='ISNULL(Lottable06,'''')<>'''''            ELSE
               IF @nLotNo =7  SELECT @cField = 'Lottable07',@cAssign='@cLottable07=Lottable07',@cAssignEmpty='@cLottable07=''''',@cNotEmpty='ISNULL(Lottable07,'''')<>'''''            ELSE
               IF @nLotNo =8  SELECT @cField = 'Lottable08',@cAssign='@cLottable08=Lottable08',@cAssignEmpty='@cLottable08=''''',@cNotEmpty='ISNULL(Lottable08,'''')<>'''''            ELSE
               IF @nLotNo =9  SELECT @cField = 'Lottable09',@cAssign='@cLottable09=Lottable09',@cAssignEmpty='@cLottable09=''''',@cNotEmpty='ISNULL(Lottable09,'''')<>'''''            ELSE
               IF @nLotNo =10 SELECT @cField = 'Lottable10',@cAssign='@cLottable10=Lottable10',@cAssignEmpty='@cLottable10=''''',@cNotEmpty='ISNULL(Lottable10,'''')<>'''''            ELSE
               IF @nLotNo =11 SELECT @cField = 'Lottable11',@cAssign='@cLottable11=Lottable11',@cAssignEmpty='@cLottable11=''''',@cNotEmpty='ISNULL(Lottable11,'''')<>'''''            ELSE
               IF @nLotNo =12 SELECT @cField = 'Lottable12',@cAssign='@cLottable12=Lottable12',@cAssignEmpty='@cLottable12=''''',@cNotEmpty='ISNULL(Lottable12,'''')<>'''''            ELSE
               IF @nLotNo =13 SELECT @cField = 'Lottable13',@cAssign='@dLottable13=Lottable13',@cAssignEmpty='@cLottable13=NULL',@cNotEmpty='NOT(Lottable13 IS NULL OR Lottable13=0)'  ELSE
               IF @nLotNo =14 SELECT @cField = 'Lottable14',@cAssign='@dLottable14=Lottable14',@cAssignEmpty='@cLottable14=NULL',@cNotEmpty='NOT(Lottable14 IS NULL OR Lottable14=0)'  ELSE
               IF @nLotNo =15 SELECT @cField = 'Lottable15',@cAssign='@dLottable15=Lottable15',@cAssignEmpty='@cLottable15=NULL',@cNotEmpty='NOT(Lottable15 IS NULL OR Lottable15=0)' 
               IF @cField <>''
               BEGIN
                  SET @cSQLParam = N'@cReceiptKey NVARCHAR( 10),@cPOKey NVARCHAR( 10),@cSKU NVARCHAR( 20), ' + 
                     ' @cLottable01  NVARCHAR( 18)   OUTPUT, ' +
                     ' @cLottable02  NVARCHAR( 18)   OUTPUT, ' +
                     ' @cLottable03  NVARCHAR( 18)   OUTPUT, ' +
                     ' @dLottable04  DATETIME        OUTPUT, ' +
                     ' @dLottable05  DATETIME        OUTPUT, ' +
                     ' @cLottable06  NVARCHAR( 30)   OUTPUT, ' +
                     ' @cLottable07  NVARCHAR( 30)   OUTPUT, ' +
                     ' @cLottable08  NVARCHAR( 30)   OUTPUT, ' +
                     ' @cLottable09  NVARCHAR( 30)   OUTPUT, ' +
                     ' @cLottable10  NVARCHAR( 30)   OUTPUT, ' +
                     ' @cLottable11  NVARCHAR( 30)   OUTPUT, ' +
                     ' @cLottable12  NVARCHAR( 30)   OUTPUT, ' +
                     ' @dLottable13  DATETIME        OUTPUT, ' +
                     ' @dLottable14  DATETIME        OUTPUT, ' +
                     ' @dLottable15  DATETIME        OUTPUT  '
                  SELECT @cSQL = 'SELECT @nDistinctCount = COUNT(1) FROM (
                     SELECT DISTINCT ' + @cField +' FROM ReceiptDetail WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     AND POKey = CASE WHEN @cPOKey = ''NOPO'' THEN POKey ELSE @cPOKey END
                        AND SKU = @cSKU AND ' +@cNotEmpty + '
                     ) x'
                  EXEC sp_ExecuteSQL @cSQL,N'@cReceiptKey NVARCHAR( 10),@cPOKey NVARCHAR( 10),@cSKU NVARCHAR( 20),@nDistinctCount INT OUTPUT',
                     @cReceiptKey = @cReceiptKey, @cPOKey = @cPOKey, @cSKU = @cSKU, @nDistinctCount = @nDistinctCount OUTPUT

                  IF ISNULL(@nDistinctCount,0)=1
                  BEGIN
                     SELECT @cSQL = 'SELECT ' + @cAssign + ' FROM ReceiptDetail WITH (NOLOCK)
                        WHERE ReceiptKey = @cReceiptKey
                        AND POKey = CASE WHEN @cPOKey = ''NOPO'' THEN POKey ELSE @cPOKey END
                           AND SKU = @cSKU AND ' +@cNotEmpty 
                  END
                  ELSE
                  BEGIN
                     SELECT @cSQL = 'SELECT ' + @cAssignEmpty
                  END
                  IF @nDebugFlag > 0 
                  BEGIN
                     PRINT @cSQL
                     PRINT @cSQLParam
                  END
                  EXEC sp_ExecuteSQL @cSQL,@cSQLParam,
                     @cReceiptKey = @cReceiptKey, @cPOKey = @cPOKey, 
                     @cSKU = @cSKU, 
                     @cLottable01 = @cLottable01 OUTPUT, 
                     @cLottable02 = @cLottable02 OUTPUT, 
                     @cLottable03 = @cLottable03 OUTPUT, 
                     @dLottable04 = @dLottable04 OUTPUT, 
                     @dLottable05 = @dLottable05 OUTPUT,
                     @cLottable06 = @cLottable06 OUTPUT, 
                     @cLottable07 = @cLottable07 OUTPUT, 
                     @cLottable08 = @cLottable08 OUTPUT, 
                     @cLottable09 = @cLottable09 OUTPUT, 
                     @cLottable10 = @cLottable10 OUTPUT,
                     @cLottable11 = @cLottable11 OUTPUT, 
                     @cLottable12 = @cLottable12 OUTPUT, 
                     @dLottable13 = @dLottable13 OUTPUT, 
                     @dLottable14 = @dLottable14 OUTPUT, 
                     @dLottable15 = @dLottable15 OUTPUT
               END  --end of  IF @cField <>''
            END  --end of while
         END --end of inputkey=1
      END  --end of step 4
   END
Quit:
   IF @nDebugFlag > 0 
   BEGIN
      PRINT 'Exit rdt_600GetRcvInfo10'
      SELECT 'Exit rdt_600GetRcvInfo10' AS  TITLE, 
         @cLottable01,@cLottable02,@cLottable03,@dLottable04,@dLottable05,@cLottable06,
         @cLottable07,@cLottable08,@cLottable09,@cLottable10,@cLottable11,@cLottable12,
         @dLottable13,@dLottable14,@dLottable15
   END
END

GO