SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_860DropIDDecod01                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Decode SSCC no using the prefix setup in CODELKUP           */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 05-05-2015  1.0  James       SOS335929 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_860DropIDDecod01]
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR(15),
   @cPickSlipNo      NVARCHAR(10),
   @cDropID          NVARCHAR(20)   OUTPUT,
   @cLOC             NVARCHAR(10)   OUTPUT,
   @cID              NVARCHAR(18)   OUTPUT,
   @cSKU             NVARCHAR(20)   OUTPUT,
   @nQty             INT            OUTPUT, 
   @cLottable01      NVARCHAR( 18)  OUTPUT, 
   @cLottable02      NVARCHAR( 18)  OUTPUT, 
   @cLottable03      NVARCHAR( 18)  OUTPUT, 
   @dLottable04      DATETIME       OUTPUT,  
   @dLottable05      DATETIME       OUTPUT,  
   @cLottable06      NVARCHAR( 30)  OUTPUT,  
   @cLottable07      NVARCHAR( 30)  OUTPUT,  
   @cLottable08      NVARCHAR( 30)  OUTPUT,  
   @cLottable09      NVARCHAR( 30)  OUTPUT,  
   @cLottable10      NVARCHAR( 30)  OUTPUT,  
   @cLottable11      NVARCHAR( 30)  OUTPUT,  
   @cLottable12      NVARCHAR( 30)  OUTPUT,  
   @dLottable13      DATETIME       OUTPUT,   
   @dLottable14      DATETIME       OUTPUT,   
   @dLottable15      DATETIME       OUTPUT,   
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @nFirst     INT,
            @nMiddle    INT,
            @nLast      INT,
            @nStart     INT,
            @bdebug    INT, 
            @cCode      NVARCHAR( 10)
             
   DECLARE  @c_oFieled01 NVARCHAR( 20)

   SET @bdebug = 0

   IF ISNULL( @cDropID, '') = ''
      GOTO Quit

      SET @c_oFieled01 = ''

      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT CODE FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE ListName = 'RMVCTNPRFX'
      AND   StorerKey =  @cStorerkey
      ORDER BY Short
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cCode
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --1. Check if the pattern match
         IF CHARINDEX(RTRIM( @cCode), @cDropID) > 0
         BEGIN
            SELECT @nStart = CHARINDEX(RTRIM( @cCode), @cDropID)

            SELECT @nFirst  = CHARINDEX( LEFT( @cCode, 1), @cDropID, @nStart)

            SELECT @nMiddle  = CHARINDEX( RIGHT( @cCode, 1), @cDropID, @nStart)

            SELECT @nLast = CHARINDEX( LEFT( @cCode, 1), @cDropID, @nMiddle)

            IF @bdebug = 1
               SELECT '@nStart', @nStart, '@nFirst', @nFirst, '@nMiddle', @nMiddle, '@nLast', @nLast

            IF @nLast > 0
               SELECT @c_oFieled01 = SUBSTRING( @cDropID, @nMiddle + 1, @nLast - (@nMiddle + 1))
            ELSE
               SELECT @c_oFieled01 = SUBSTRING( @cDropID, @nMiddle + 1, LEN( @cDropID) - @nMiddle)

            IF ISNULL( @c_oFieled01, '') <> ''
               BREAK
         END
         FETCH NEXT FROM CUR_LOOP INTO @cCode
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      SET @cDropID = @c_oFieled01
QUIT:

END -- End Procedure


GO