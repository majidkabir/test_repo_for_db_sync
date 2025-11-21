SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_LottableProcess_UNIGenL4L13ByL2                   */
/* Copyright      : LF                                                    */
/*                                                                        */
/* Purpose: Key-in value, generate batch # (L2), expriry date (L4) and    */
/*          production date (L13)                                         */
/*                                                                        */
/* Date        Rev  Author      Purposes                                  */
/* 2019-06-10  1.0  James       WMS9219. Created                          */
/* 2019-09-20  1.1  James       WMS-10500 Add new validation (james01)    */
/* 2019-12-02  1.2  James       WMS-11315 Clear lottable value when       */
/*                              type = PRE (james02)                      */
/* 2021-04-23  1.3  BeeTin      INC1475895-@cErrMessage=Errmsg(Uncomment) */  
/* 2021-04-30  1.4  Chermaine   WMS-16598 Add @barcode len checking (cc01)*/
/**************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_UNIGenL4L13ByL2]
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
   DECLARE @cTempLottable02   NVARCHAR( 60)
   DECLARE @cTempLottable04   NVARCHAR( 60)
   DECLARE @cTempLottable13   NVARCHAR( 60)
   DECLARE @cSUSR2            NVARCHAR( 18)
   DECLARE @cErrMessage       NVARCHAR( 20)
   DECLARE @cBarcode          NVARCHAR(MAX) --(cc01)
   DECLARE @nMaxLen           INT --(cc01)

   SET @nErrNo = 0

   SELECT @cTempLottable02 = I_Field04,
          @cTempLottable04 = I_Field06,
          @cTempLottable13 = I_Field08,
          @cErrMessage = ErrMsg,
          @cBarcode = V_max     --(cc01)     
   FROM rdt.RDTMOBREC WITH (NOLOCK)     ----INC1475895 
   WHERE Mobile = @nMobile
   
   --(cc01)
   SELECT @nMaxLen = SUM(MaxLength) 
   FROM BarcodeConfigDetail WITH (NOLOCK) 
   WHERE decodeCode = 'UNILEVER_IB01'
   
   IF LEN(@cBarcode) < @nMaxLen  --(cc01)
   BEGIN
   	IF @cType = 'PRE'
      BEGIN
         SET @cLottable02 = ''
         SET @dLottable04 = ''
         SET @dLottable13 = ''
      
         GOTO Quit
      END
   
      -- Get SKU info
      SELECT @nShelfLife = ShelfLife,
             @cSUSR2 = SUSR2
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   SKU = @cSKU

      --IF ISNULL( @cTempLottable02, '') <> '' AND ISNULL( @cTempLottable04, '') <> '' AND ISNULL( @cTempLottable13, '') <> ''
      IF @cLottable02Value <> '' AND ISNULL( @dLottable04Value , 0) <> 0 AND ISNULL( @dLottable13Value , 0) <> 0
      BEGIN
         SET @cLottable02 = @cLottable02Value
         SET @dLottable04 = @dLottable04Value
         SET @dLottable13 = @dLottable13Value

         GOTO Validate_Lottable
      END

      -- Check valid shelf life
      IF ISNULL( @nShelfLife, 0) = 0
      BEGIN
         SET @nErrNo = 146601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv ShelfLife
         GOTO Quit
      END

      IF @nLottableNo = 2 AND ISNULL( @cLottable02Value, '') <> ''
      BEGIN
         -- Check valid batch number
         IF RDT.rdtIsValidQTY( @cLottable, 0) = 0
         BEGIN
            SET @nErrNo = 146602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
            GOTO Quit
         END

         SET @cYearCode = SUBSTRING( @cLottable, 1, 2)
         SET @cWeekCode = SUBSTRING( @cLottable, 3, 2)
         SET @cDayCode = SUBSTRING( @cLottable, 5, 1)

         -- Get production date
         /*
            e.g. Lottle02 input is 190921
            YY = 19 (or 2019)
            WW = 09 (Week 9 of 2019 is between February 25, 2019 to March 3, 2019)
            D = 2 (The 2nd day would then be February 26, 2019)
            1 =1 (this can be ignored)
            SELECT DATEADD(wk, DATEDIFF(wk, 6, '1/1/' + @YearNum) + (@WeekNum-1), 7) AS StartOfWeek;
            SELECT DATEADD(wk, DATEDIFF(wk, 5, '1/1/' + @YearNum) + (@WeekNum-1), 6) AS EndOfWeek;
         */
         SET @cYear = '20' + @cYearCode
         SET @nWeekNum = CAST( @cWeekCode AS INT)
         SET @nDayNum = CAST( @cDayCode AS INT)

         -- Check valid year number
         IF @cYearCode NOT BETWEEN '0' AND '9'
         BEGIN
            SET @nErrNo = 146603
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Year #
            GOTO Quit
         END
   
         DECLARE @cDate NVARCHAR( 10), @dDate DATETIME
         SET @cDate =  @cYear + '-12-31'
         set @dDate = CAST( @cDate AS DATETIME)

         -- Check valid week number
         IF DATEPART( WEEK, DATEADD(yy, DATEDIFF(yy, 0, @dDate) + 1, -1)) < @nWeekNum
         BEGIN
            SET @nErrNo = 146604
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Week #
            GOTO Quit
         END

         -- Check valid day number
         IF @nDayNum > 7   
         BEGIN
            SET @nErrNo = 146605
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day #
            GOTO Quit
         END

         -- Get production date
         SELECT @cProdDate = CONVERT( NVARCHAR( 10), 
                             DATEADD(WEEK, @nWeekNum - 1,DATEADD(dd, 1 - DATEPART(dw, '1/1/' + 
                             CONVERT(VARCHAR(4),cast(@cYear as int))), '1/1/' + CONVERT(VARCHAR(4),cast(@cYear as int))) + 
                             @nDayNum), 126)
   
         SET @dLottable13 = CONVERT( datetime, @cProdDate, 120)   

         -- Get expiry date
         SET @dLottable04 = DATEADD( DAY, @nShelfLife, @dLottable13) 
      
         SET @cLottable02 =  @cLottable

         SET @nErrNo = -1  -- Make it display value on screen. next ENTER will proceed next screen
      END

      Validate_Lottable:
      IF DATEDIFF( D, @dLottable13, @dLottable04) < 0
      BEGIN
         SET @nErrNo = 146606
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv Prod Date
         GOTO Quit
      END

      IF DATEDIFF( D, GETDATE(), @dLottable04) < CAST( @cSUSR2 AS INT)
      BEGIN
         -- This error only need prompt once, user press enter again can proceed
         IF CHARINDEX( 'MRSL', @cErrMessage) = 0 
         BEGIN
            SET @nErrNo = 146607
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU below MRSL
            GOTO Quit
         END
      END

      IF DATEDIFF( D, @dLottable13, GETDATE()) < 0
      BEGIN
         SET @nErrNo = 146608
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv Prod Date
         GOTO Quit
      END
   END
   Quit:
END -- End Procedure




GO