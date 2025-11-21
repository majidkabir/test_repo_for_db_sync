SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*****************************************************************************/
/* Store procedure: rdt_600ExtScn06                                          */
/* Copyright: Maersk                                                         */
/* CUSTOMER :   Indietx                                                      */
/* For ConfigKey: ExtendedScreenSP (rdt.StorerConfig)                        */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author     Purposes                                       */
/* 2024-10-18 1.0  YYS027     FCR-840. Lottable should be in receiptdetail   */
/*****************************************************************************/
  
CREATE     PROC [RDT].[rdt_600ExtScn06] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nScn         INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 

   @cSuggLOC     NVARCHAR( 10) OUTPUT, 
   @cLOC         NVARCHAR( 20) OUTPUT, 
   @cID          NVARCHAR( 20) OUTPUT, 
   @cSKU         NVARCHAR( 20) OUTPUT, 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10),
   @cReasonCode  NVARCHAR( 10),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cPalletType  NVARCHAR( 10),  

   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction      INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
   @nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @cDistinctLottableDefault VARCHAR(200)
   DECLARE @tLots TABLE(LottableNo VARCHAR(50), RowID INT)
   DECLARE @nCfgCount  INT,
           @nCfgIdx    INT,
           @nLotNo     INT,
           @nRowCount  INT,
           @cSQL       NVARCHAR(MAX),
           @cWhereSQL  NVARCHAR(1000),
           @cSQLParam  NVARCHAR(1000),
           @cLotVal    NVARCHAR(30),
           @dLotVal    DATETIME

   IF @nFunc = 600
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @nStep = 5 
         BEGIN
            SET @cDistinctLottableDefault = rdt.RDTGetConfig( @nFunc, 'DistinctLottableDefault', @cStorerKey)
            IF isnull(@cDistinctLottableDefault,'') IN ('','0')         --default action, copy from rdtfnc_NormalReceipt_V7 
            BEGIN
               GOTO Quit
            END
            INSERT INTO @tLots(LottableNo,RowID) 
               SELECT value,ROW_NUMBER() OVER(ORDER BY value) AS RowID 
               FROM STRING_SPLIT(@cDistinctLottableDefault,',') WHERE ISNUMERIC(value)=1 ORDER BY CONVERT(INT,value)
            SELECT @nCfgCount = COUNT(1) FROM @tLots
            SELECT @nCfgIdx=0, @nCfgCount = ISNULL(@nCfgCount,0)
            IF @nCfgCount<=0
            BEGIN
               GOTO Quit
            END 
            WHILE(@nCfgIdx<@nCfgCount)
            BEGIN
               SELECT @nCfgIdx = @nCfgIdx + 1
               SELECT @nLotNo = CONVERT(INT, LottableNo) FROM @tLots WHERE RowID = @nCfgIdx
               SELECT @cLotVal=NULL,@dLotVal=NULL
               IF @nLotNo =1  SELECT @cWhereSQL = 'Lottable01=@cLottable01',@cLotVal=@cLottable01 ELSE
               IF @nLotNo =2  SELECT @cWhereSQL = 'Lottable02=@cLottable02',@cLotVal=@cLottable02 ELSE
               IF @nLotNo =3  SELECT @cWhereSQL = 'Lottable03=@cLottable03',@cLotVal=@cLottable03 ELSE
               IF @nLotNo =4  SELECT @cWhereSQL = 'Lottable04=@dLottable04',@dLotVal=@dLottable04 ELSE
               IF @nLotNo =5  SELECT @cWhereSQL = 'Lottable05=@dLottable05',@dLotVal=@dLottable05 ELSE
               IF @nLotNo =6  SELECT @cWhereSQL = 'Lottable06=@cLottable06',@cLotVal=@cLottable06 ELSE
               IF @nLotNo =7  SELECT @cWhereSQL = 'Lottable07=@cLottable07',@cLotVal=@cLottable07 ELSE
               IF @nLotNo =8  SELECT @cWhereSQL = 'Lottable08=@cLottable08',@cLotVal=@cLottable08 ELSE
               IF @nLotNo =9  SELECT @cWhereSQL = 'Lottable09=@cLottable09',@cLotVal=@cLottable09 ELSE
               IF @nLotNo =10 SELECT @cWhereSQL = 'Lottable10=@cLottable10',@cLotVal=@cLottable10 ELSE
               IF @nLotNo =11 SELECT @cWhereSQL = 'Lottable11=@cLottable11',@cLotVal=@cLottable11 ELSE
               IF @nLotNo =12 SELECT @cWhereSQL = 'Lottable12=@cLottable12',@cLotVal=@cLottable12 ELSE
               IF @nLotNo =13 SELECT @cWhereSQL = 'Lottable13=@dLottable13',@dLotVal=@dLottable13 ELSE
               IF @nLotNo =14 SELECT @cWhereSQL = 'Lottable14=@dLottable14',@dLotVal=@dLottable14 ELSE
               IF @nLotNo =15 SELECT @cWhereSQL = 'Lottable15=@dLottable15',@dLotVal=@dLottable15

               IF ISNULL(@cLotVal,'')<>'' OR ( @dLotVal IS NOT NULL AND @dLotVal<>0 )        --NOT EMPTY, to CHECK VALUE
               BEGIN
                  SELECT @cSQL = 'SELECT @nRowCount = COUNT(1) FROM ReceiptDetail WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     AND POKey = CASE WHEN @cPOKey = ''NOPO'' THEN POKey ELSE @cPOKey END
                        AND SKU = @cSKU AND '+ @cWhereSQL
                  SET @cSQLParam = N'@cReceiptKey NVARCHAR( 10),@cPOKey NVARCHAR( 10),@cSKU NVARCHAR( 20),@nRowCount INT OUTPUT,' + 
                     ' @cLottable01  NVARCHAR( 18)  , ' +
                     ' @cLottable02  NVARCHAR( 18)  , ' +
                     ' @cLottable03  NVARCHAR( 18)  , ' +
                     ' @dLottable04  DATETIME       , ' +
                     ' @dLottable05  DATETIME       , ' +
                     ' @cLottable06  NVARCHAR( 30)  , ' +
                     ' @cLottable07  NVARCHAR( 30)  , ' +
                     ' @cLottable08  NVARCHAR( 30)  , ' +
                     ' @cLottable09  NVARCHAR( 30)  , ' +
                     ' @cLottable10  NVARCHAR( 30)  , ' +
                     ' @cLottable11  NVARCHAR( 30)  , ' +
                     ' @cLottable12  NVARCHAR( 30)  , ' +
                     ' @dLottable13  DATETIME       , ' +
                     ' @dLottable14  DATETIME       , ' +
                     ' @dLottable15  DATETIME  '
                  EXEC sp_ExecuteSQL @cSQL,@cSQLParam,
                     @cReceiptKey = @cReceiptKey, @cPOKey = @cPOKey, 
                     @cSKU = @cSKU, @nRowCount = @nRowCount OUTPUT,
                     @cLottable01 = @cLottable01, 
                     @cLottable02 = @cLottable02, 
                     @cLottable03 = @cLottable03, 
                     @dLottable04 = @dLottable04, 
                     @dLottable05 = @dLottable05,
                     @cLottable06 = @cLottable06, 
                     @cLottable07 = @cLottable07, 
                     @cLottable08 = @cLottable08, 
                     @cLottable09 = @cLottable09, 
                     @cLottable10 = @cLottable10,
                     @cLottable11 = @cLottable11, 
                     @cLottable12 = @cLottable12, 
                     @dLottable13 = @dLottable13, 
                     @dLottable14 = @dLottable14, 
                     @dLottable15 = @dLottable15 
                  IF ISNULL(@nRowCount,0) < 1
                  BEGIN
                     DECLARE @cErrMsg2 NVARCHAR(100)
                     DECLARE @cErrMsg3 NVARCHAR(100)
                     SET @nErrNo = 226651;
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Lottable
                     SET @cErrMsg2 = 'Lottable' + RIGHT('00' + CONVERT(VARCHAR(20), @nLotNo), 2)
                     SET @cErrMsg3 = CASE WHEN @cLotVal IS NULL THEN CONVERT(NVARCHAR(30),@dLotVal) ELSE @cLotVal END
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg, @cErrMsg2, @cErrMsg3
                     GOTO Quit
                  END
               END
            END
         END --end of step 5
      END
   END
Quit:
END

GO