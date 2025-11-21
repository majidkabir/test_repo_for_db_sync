SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_955FlowThru01                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Decide whether need flow thru next screen/step              */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-09-22  1.0  James       WMS-20758.Created                       */
/************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_955FlowThru01]
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nScn         INT,
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5) ,
   @cStorerKey   NVARCHAR( 15),
   @cPickSlipNo  NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 10),
   @cSKU         NVARCHAR( 20),
   @cUOM         NVARCHAR( 10),
   @nQTY         INT,
   @cDropID      NVARCHAR( 20),
   @cInField01   NVARCHAR( 60) OUTPUT,
   @cInField02   NVARCHAR( 60) OUTPUT,
   @cInField03   NVARCHAR( 60) OUTPUT,
   @cInField04   NVARCHAR( 60) OUTPUT,
   @cInField05   NVARCHAR( 60) OUTPUT,
   @cInField06   NVARCHAR( 60) OUTPUT,
   @cInField07   NVARCHAR( 60) OUTPUT,
   @cInField08   NVARCHAR( 60) OUTPUT,
   @cInField09   NVARCHAR( 60) OUTPUT,
   @cInField10   NVARCHAR( 60) OUTPUT,
   @cInField11   NVARCHAR( 60) OUTPUT,
   @cInField12   NVARCHAR( 60) OUTPUT,
   @cInField13   NVARCHAR( 60) OUTPUT,
   @cInField14   NVARCHAR( 60) OUTPUT,
   @cInField15   NVARCHAR( 60) OUTPUT,
   @nToScn       INT           OUTPUT,
   @nToStep      INT           OUTPUT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR(250) OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	IF NOT EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)
      	                WHERE StorerKey = @cStorerKey
      	                AND   Sku = @cSKU
      	                AND   LOTTABLE09LABEL = 'SSCC')
         	SET @cInField02 = 'NA'
         ELSE
         BEGIN
         	SET @cInField02 = ''
         	SET @nErrNo = -1
         END
         	
         SET @nToScn = 5054
         SET @nToStep = 5
      END
   END

QUIT:

END -- End Procedure

GO