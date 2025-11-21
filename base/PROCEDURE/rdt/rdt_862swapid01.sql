SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_862SwapID01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2014-08-28 1.0  Ung     SOS307606 Created                            */
/* 2016-11-16 1.1  Ung     WMS-515 Add check L03                        */
/* 2019-07-12 1.2  SPChin  INC0771998 - Bug Fixed                       */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdt_862SwapID01] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR(  3)
   ,@cStorer      NVARCHAR( 15)
   ,@cFacility    NVARCHAR(  5)
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@cLOC         NVARCHAR( 10)
   ,@cDropID      NVARCHAR( 20)
   ,@cID          NVARCHAR( 18) OUTPUT --INC0771998 
   ,@cSKU         NVARCHAR( 20)
   ,@cUOM         NVARCHAR( 10)
   ,@cLottable01  NVARCHAR( 18)
   ,@cLottable02  NVARCHAR( 18)
   ,@cLottable03  NVARCHAR( 18)
   ,@dLottable04  DATETIME     
   ,@nTaskQTY     INT          
   ,@cActID       NVARCHAR( 18)
   ,@nErrNo       INT           OUTPUT   
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc <> 862 -- Pick by ID
   BEGIN
      SET @nErrNo = 105251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Wrong ID'
   END
   
   -- Check pallet or carton ID in QC status
   IF @cActID <> ''
   BEGIN
      DECLARE @cLottable03_Act  NVARCHAR( 18)
      DECLARE @cBUSR2 NVARCHAR( 30)

      SET @cLottable03_Act = ''

      -- Get SKU info
      SELECT @cBUSR2 = BUSR2 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU       

      IF @cBUSR2 = 'PALLET'
      BEGIN
         -- Get L03 of actual pallet ID
         SELECT @cLottable03_Act = Lottable03
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.ID = @cActID
            AND LLI.QTY-LLI.QTYPicked > 0
            AND LLI.SKU = @cSKU
            AND LLI.LOC = @cLOC
      END
      
      IF @cBUSR2 = 'CRTID'
      BEGIN
         -- Get L03 of actual carton
         SELECT @cLottable03_Act = Lottable03
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LA.Lottable01 = @cActID
            AND LLI.QTY-LLI.QTYPicked > 0
            AND LLI.SKU = @cSKU
            AND LLI.LOC = @cLOC
      END
      
      -- Check QC status
      IF @cLottable03_Act <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'QCStatus' AND Code = @cLottable03_Act AND StorerKey = @cStorer AND Code2 = @nFunc)
         BEGIN
            SET @nErrNo = 105252
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QC ID CantPick'
         END
      END
   END

GO