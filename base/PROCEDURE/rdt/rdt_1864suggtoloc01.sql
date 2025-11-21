SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*********************************************************************************/
/* Store procedure: rdt_1864SuggToLOC01                                          */
/* Copyright      : Maersk                                                       */
/*                                                                               */
/* Purpose: Suggest To LOC                                                       */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 11-04-2024  1.0  Ung         WMS-25227 Created                                */
/*********************************************************************************/

CREATE   PROCEDURE rdt.rdt_1864SuggToLOC01
   @nMobile       INT,          
   @nFunc         INT,          
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT,          
   @nInputKey     INT,          
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nTaskQTY      INT,          
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
   @cSuggToLOC    NVARCHAR( 10) OUTPUT, 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Get PickHeader info
   DECLARE @cLoadKey NVARCHAR( 10)
   SELECT @cLoadKey = ExternOrderKey
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo
   
   SELECT @cSuggToLOC = ISNULL( TrfRoom, '')
   FROM dbo.LoadPlan WITH (NOLOCK)
   WHERE LoadKey = @cLoadKey

END

GRANT EXECUTE ON rdt.rdt_1864SuggToLOC01 TO NSQL 

GO