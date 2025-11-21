SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_L4MinExpDate                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 26-Oct-2015  Ung       1.0   SOS352968 Created                             */
/* 27-nOV-2018  James     1.1   WMS-7077. Check lot04 validity based on       */
/*                              storer.susr3 (james01)                        */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_L4MinExpDate]
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
   
   IF @nFunc = 903 -- PPA lottable
   BEGIN
      IF @cType = 'POST'
      BEGIN
         DECLARE @cDropID     NVARCHAR(20)
         DECLARE @cPPAType    NVARCHAR(1)
         DECLARE @cOrderKey   NVARCHAR(10)
         DECLARE @dMinExpDate DATETIME
         DECLARE @cSUSR3      NVARCHAR( 20)
         
         -- Get session info
         SELECT @cDropID = V_CaseID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
         
         -- PPA by carton ID
         IF @cDropID <> ''  
         BEGIN
            -- Get order
            SELECT TOP 1 
               @cOrderKey = OrderKey 
            FROM PickDetail WITH (NOLOCK) 
            WHERE DropID = @cDropID
               AND StorerKey = @cStorerKey 
               AND SKU = @cSKU

            SELECT TOP 1 @cSUSR3 = ST.SUSR3
            FROM dbo.Storer ST WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON ST.StorerKey = O.ConsigneeKey
            WHERE O.OrderKey = @cOrderKey
            AND   O.StorerKey = @cStorerKey

            -- Get min L4 in order
            SELECT @dMinExpDate = MIN( LA.Lottable04)
            FROM PickDetail PD WITH (NOLOCK) 
               JOIN LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.SKU = @cSKU
               AND PD.DropID = @cDropID
               AND PD.QTY > 0
               AND PD.Status <> '4' -- Short
            
            IF @cSUSR3 <> '7-11'
            BEGIN
               -- Check expire too soon (for that order)
               IF @dLottable04Value < @dMinExpDate
               BEGIN
                  SET @nErrNo = 121001
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExpiredTooSoon
               END
            END
            ELSE
            BEGIN
               -- Check expire must same as input date (for that order)
               IF @dLottable04Value <> @dMinExpDate
               BEGIN
                  SET @nErrNo = 121002
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExpiryNotMatch
               END
            END

         END
      END
   END
END

GO