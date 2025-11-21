SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_955DecodeSP01                                         */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2022-10-13   1.0  yeekung    WMS-20985 Created                             */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_955DecodeSP01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cBarcode     NVARCHAR( 60), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cUPC         NVARCHAR( 30)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @cLottable01  NVARCHAR( 18)  OUTPUT, 
   @cLottable02  NVARCHAR( 18)  OUTPUT, 
   @cLottable03  NVARCHAR( 18)  OUTPUT, 
   @dLottable04  DATETIME       OUTPUT,  
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF EXISTS (SELECT 1 FROM SKU (NOLOCK)
              WHERE SKU=@cBarcode
              AND itemclass='MHD-FG'
              AND storerkey=@cStorerKey)
   BEGIN
      SET @nErrNo = 192801              
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --''Inv EAN code''              
      GOTO QUIT  
   END
QUIT:

END

GO