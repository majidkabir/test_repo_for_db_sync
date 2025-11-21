SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812DecodeSP02                                  */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Decode UCC No                                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2024-09-18  1.0  James       WMS-26122 Created                       */
/* 2024-10-27  1.1  James       Change DropID->CaseID mapping (james01) */
/* 2024-11-11  1.2  PXL009      FCR-1125 Merged 1.0, 1.1 from v0 branch */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_1812DecodeSP02
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTaskdetailKey NVARCHAR( 10),
   @cBarcode       NVARCHAR( MAX),
   @cFromID        NVARCHAR( 18)  OUTPUT,
   @cSKU           NVARCHAR( 20)  OUTPUT,
   @nQTY           INT            OUTPUT,
   @cUCC           NVARCHAR( 20)  OUTPUT,
   @cDropID        NVARCHAR( 20)  OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nUCCQty     INT = 0
   DECLARE @nTaksQty    INT = 0
   DECLARE @nRowCnt     INT = 0
   DECLARE @cTempUCC    NVARCHAR( MAX) = ''

   SET @nErrNo = 0
   SET @cErrMsg = 0

   EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
      @cUCCNo  = @cTempUCC    OUTPUT,
      @nErrNo  = @nErrNo      OUTPUT,
      @cErrMsg = @cErrMsg     OUTPUT,
      @cType   = 'UCCNO'

   IF @nErrNo <> 0
      GOTO Quit

   SELECT @nUCCQty = ISNULL( SUM( Qty), 0)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND   UCCNo = @cTempUCC
   AND   [Status] >= '1'
   AND   [Status] < '6'

   IF @nUCCQty = 0
   BEGIN
      SET @nErrNo = 223651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCCNo
      GOTO Quit
   END

   SELECT
      @cSKU = SKU,
      @nTaksQTY = ISNULL( SUM( Qty), 0)
   FROM dbo.TASKDETAIL WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskdetailKey
   AND   CaseID = @cTempUCC   -- Not support swap ucc
   AND   [Status] = '3'
   GROUP BY SKU
   SET @nRowCnt = @@ROWCOUNT

   IF @nRowCnt = 0
   BEGIN
      SET @nErrNo = 223652
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCCNo
      GOTO Quit
   END

   IF ISNULL( @cSKU, '') = ''
   BEGIN
      SET @nErrNo = 223653
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Sku
      GOTO Quit
   END

   IF @nUCCQty <> @nTaksQTY
   BEGIN
      SET @nErrNo = 223654
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
      GOTO Quit
   END

   SET @cUCC = @cTempUCC
   SET @nQTY = @nTaksQTY
END

Quit:

GO