SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_Zotos                                  */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Generate expiry date base on code                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-11-2015  Ung       1.0   SOS356691 Created                              */
/* 09-09-2017  Ung       1.1   WMS-2963 New decode logic                      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_Zotos]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @cLottableCode    NVARCHAR( 30), 
   @nLottableNo      INT,
   @cFormatSP        NVARCHAR( 50), 
   @cLottableValue   NVARCHAR( 60), 
   @cLottable        NVARCHAR( 60) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cMonthYearCode NVARCHAR(2)
   DECLARE @nLen INT

   /*
      Format: 999MY
         999 = Julian date
         MY = month and year encoding, in below   

               Year 20XX
      Month    11 12 13 14 15 16 17 18 19 20 21 22
      Jan      MJ NL ON PP QR RT SV TX OB PD QF RH 
      Feb      NK OM PO QQ RS SU TW UY PC QE RG SI
      Mar      OL PN QP RR ST TV UX VZ QD RF SH TJ
      Apr      PM QO RQ SS TU UW VY WA RE SG TI UK
      May      QN RP SR TT UV VX WZ XB SF TH UJ VL
      Jun      RO SQ TS UU VW WY XA YC TG UI VK WM
      Jul      SP TR UT VV WX XZ YB ZD UH VJ WL XN
      Aug      TQ US VU WW XY YA ZC AE VI WK XM YO
      Sep      UR VT WV XX YZ ZB AD BF WJ XL YN ZP
      Oct      VS WU XW YY ZA AC BE CG XK YM ZO AQ
      Nov      WT XV YX ZZ AB BD CF DH YL ZN AP BR
      Dec      XU YW ZY AA BC CE DG EI ZM AO BQ CS
   */
   
   SET @nLen = LEN( @cLottableValue) 
   
   IF @nLen >= 5
   BEGIN
      SET @cMonthYearCode = SUBSTRING( @cLottableValue, 3, 2)
      EXEC rdt.rdt_LottableFormat_Zotos_Sub @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cMonthYearCode, 
         @cLottable OUTPUT,
         @nErrNo    OUTPUT,
         @cErrMsg   OUTPUT
      
      IF @cLottable = ''
      BEGIN
         SET @cMonthYearCode = LEFT( @cLottableValue, 2)
         EXEC rdt.rdt_LottableFormat_Zotos_Sub @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cMonthYearCode, 
            @cLottable OUTPUT,
            @nErrNo    OUTPUT,
            @cErrMsg   OUTPUT
      END
   END
   
   ELSE IF @nLen = 3 OR @nLen = 4
   BEGIN
      SET @cMonthYearCode = LEFT( @cLottableValue, 2)
      EXEC rdt.rdt_LottableFormat_Zotos_Sub @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cMonthYearCode, 
         @cLottable OUTPUT,
         @nErrNo    OUTPUT,
         @cErrMsg   OUTPUT
      
      IF @cLottable = ''
      BEGIN
         SET @cMonthYearCode = SUBSTRING( @cLottableValue, 2, 2)
         EXEC rdt.rdt_LottableFormat_Zotos_Sub @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cMonthYearCode, 
            @cLottable OUTPUT,
            @nErrNo    OUTPUT,
            @cErrMsg   OUTPUT
      END
   END
   
   ELSE IF @nLen = 2
   BEGIN
      SET @cMonthYearCode = LEFT( @cLottableValue, 2)
      EXEC rdt.rdt_LottableFormat_Zotos_Sub @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cMonthYearCode, 
         @cLottable OUTPUT,
         @nErrNo    OUTPUT,
         @cErrMsg   OUTPUT
   END

Quit:

END

GO