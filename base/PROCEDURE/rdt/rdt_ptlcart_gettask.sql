SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_GetTask                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next SKU to Pick                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 25-May-2015 1.0  Ung         SOS336312 Created                       */
/* 16-May-2016 1.1  Ung         SOS361968 Expand ToteID 20 chars        */
/* 03-Jan-2018 1.2  Ung         WMS-3549 Add lottables                  */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_GetTask] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR(3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR(5)
   ,@cStorerKey      NVARCHAR(15)
   ,@cType           NVARCHAR(20)  -- LOC/CURRENTTOTE/NEXTTOTE
   ,@cLight          NVARCHAR(1)   -- 0 = no light, 1 = use light
   ,@cCartID         NVARCHAR(10)
   ,@cPickZone       NVARCHAR(10)
   ,@cMethod         NVARCHAR(10)
   ,@cPickSeq        NVARCHAR(10)
   ,@cToteID         NVARCHAR(20)
   ,@cDPLKey         NVARCHAR(10)
   ,@nErrNo          INT                  OUTPUT
   ,@cErrMsg         NVARCHAR(20)         OUTPUT
   ,@cLOC            NVARCHAR(10)  = ''   OUTPUT
   ,@cSKU            NVARCHAR(20)  = ''   OUTPUT
   ,@cSKUDescr       NVARCHAR(60)  = ''   OUTPUT
   ,@nTotalPOS       INT           = 0    OUTPUT
   ,@nTotalQTY       INT           = 0    OUTPUT
   ,@nToteQTY        INT           = 0    OUTPUT
   ,@cLottableCode   NVARCHAR( 30) = ''   OUTPUT 
   ,@cLottable01     NVARCHAR( 18) = ''   OUTPUT  
   ,@cLottable02     NVARCHAR( 18) = ''   OUTPUT  
   ,@cLottable03     NVARCHAR( 18) = ''   OUTPUT  
   ,@dLottable04     DATETIME      = NULL OUTPUT  
   ,@dLottable05     DATETIME      = NULL OUTPUT  
   ,@cLottable06     NVARCHAR( 30) = ''   OUTPUT 
   ,@cLottable07     NVARCHAR( 30) = ''   OUTPUT 
   ,@cLottable08     NVARCHAR( 30) = ''   OUTPUT 
   ,@cLottable09     NVARCHAR( 30) = ''   OUTPUT 
   ,@cLottable10     NVARCHAR( 30) = ''   OUTPUT 
   ,@cLottable11     NVARCHAR( 30) = ''   OUTPUT
   ,@cLottable12     NVARCHAR( 30) = ''   OUTPUT
   ,@dLottable13     DATETIME      = NULL OUTPUT
   ,@dLottable14     DATETIME      = NULL OUTPUT
   ,@dLottable15     DATETIME      = NULL OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   
   DECLARE @bSuccess INT
   DECLARE @nQTY INT

   -- Get method info
   DECLARE @cGetTaskSP SYSNAME
   SET @cGetTaskSP = ''
   SELECT @cGetTaskSP = ISNULL( UDF02, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'CartMethod'
      AND Code = @cMethod
      AND StorerKey = @cStorerKey

   -- Check get task SP blank
   IF @cGetTaskSP = ''
   BEGIN
      SET @nErrNo = 54701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupGetTaskSP
      GOTO Quit
   END

   -- Check get task SP valid
   IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetTaskSP AND type = 'P')
   BEGIN
      SET @nErrNo = 54702
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad GetTask SP
      GOTO Quit
   END

   -- Detect lottables
   IF EXISTS( SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID( 'rdt.' + @cGetTaskSP) AND name = '@cLottableCode')
   BEGIN
      -- Get task SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetTaskSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cType, @cLight, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cToteID, @cDPLKey, ' + 
         ' @nErrNo       OUTPUT, @cErrMsg      OUTPUT, @cLOC         OUTPUT, @cSKU          OUTPUT, @cSKUDescr    OUTPUT, ' + 
         ' @nTotalPOS    OUTPUT, @nTotalQTY    OUTPUT, @nToteQTY     OUTPUT, @cLottableCode OUTPUT, ' + 
         ' @cLottable01  OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04   OUTPUT, @dLottable05  OUTPUT, ' + 
         ' @cLottable06  OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09   OUTPUT, @cLottable10  OUTPUT, ' + 
         ' @cLottable11  OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14   OUTPUT, @dLottable15  OUTPUT '
   
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5),  ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cType          NVARCHAR(20),  ' +
         ' @cLight         NVARCHAR(1),   ' +
         ' @cCartID        NVARCHAR(10),  ' +
         ' @cPickZone      NVARCHAR(10),  ' +
         ' @cMethod        NVARCHAR(10),  ' +
         ' @cPickSeq       NVARCHAR(10),  ' +
         ' @cToteID        NVARCHAR(20),  ' +
         ' @cDPLKey        NVARCHAR(10),  ' +
         ' @nErrNo         INT           OUTPUT, ' +
         ' @cErrMsg        NVARCHAR(20)  OUTPUT, ' +
         ' @cLOC           NVARCHAR(10)  OUTPUT, ' +
         ' @cSKU           NVARCHAR(20)  OUTPUT, ' +
         ' @cSKUDescr      NVARCHAR(60)  OUTPUT, ' +
         ' @nTotalPOS      INT           OUTPUT, ' +
         ' @nTotalQTY      INT           OUTPUT, ' +
         ' @nToteQTY       INT           OUTPUT, ' + 
         ' @cLottableCode  NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable01    NVARCHAR( 18) OUTPUT, ' +
         ' @cLottable02    NVARCHAR( 18) OUTPUT, ' +
         ' @cLottable03    NVARCHAR( 18) OUTPUT, ' +
         ' @dLottable04    DATETIME      OUTPUT, ' +
         ' @dLottable05    DATETIME      OUTPUT, ' +
         ' @cLottable06    NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable07    NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable08    NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable09    NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable10    NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable11    NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable12    NVARCHAR( 30) OUTPUT, ' +
         ' @dLottable13    DATETIME      OUTPUT, ' +
         ' @dLottable14    DATETIME      OUTPUT, ' +
         ' @dLottable15    DATETIME      OUTPUT  '
   
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cType, @cLight, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cToteID, @cDPLKey, 
         @nErrNo       OUTPUT, @cErrMsg      OUTPUT, @cLOC         OUTPUT, @cSKU          OUTPUT, @cSKUDescr    OUTPUT, 
         @nTotalPOS    OUTPUT, @nTotalQTY    OUTPUT, @nToteQTY     OUTPUT, @cLottableCode OUTPUT, 
         @cLottable01  OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04   OUTPUT, @dLottable05  OUTPUT, 
         @cLottable06  OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09   OUTPUT, @cLottable10  OUTPUT, 
         @cLottable11  OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14   OUTPUT, @dLottable15  OUTPUT
   END
   ELSE
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetTaskSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cType, @cLight, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cToteID, @cDPLKey, @nErrNo OUTPUT, @cErrMsg OUTPUT, ' +
         ' @cLOC OUTPUT, @cSKU OUTPUT, @cSKUDescr OUTPUT, @nTotalPOS OUTPUT, @nTotalQTY OUTPUT, @nToteQTY OUTPUT '
      SET @cSQLParam =
         ' @nMobile    INT,           ' +
         ' @nFunc      INT,           ' +
         ' @cLangCode  NVARCHAR( 3),  ' +
         ' @nStep      INT,           ' +
         ' @nInputKey  INT,           ' +
         ' @cFacility  NVARCHAR( 5),  ' +
         ' @cStorerKey NVARCHAR( 15), ' +
         ' @cType      NVARCHAR(20),  ' +
         ' @cLight     NVARCHAR(1),   ' +
         ' @cCartID    NVARCHAR(10),  ' +
         ' @cPickZone  NVARCHAR(10),  ' +
         ' @cMethod    NVARCHAR(10),  ' +
         ' @cPickSeq   NVARCHAR(10),  ' +
         ' @cToteID    NVARCHAR(20),  ' +
         ' @cDPLKey    NVARCHAR(10),  ' +
         ' @nErrNo     INT          OUTPUT, ' +
         ' @cErrMsg    NVARCHAR(20) OUTPUT, ' +
         ' @cLOC       NVARCHAR(10) OUTPUT, ' +
         ' @cSKU       NVARCHAR(20) OUTPUT, ' +
         ' @cSKUDescr  NVARCHAR(60) OUTPUT, ' +
         ' @nTotalPOS  INT          OUTPUT, ' +
         ' @nTotalQTY  INT          OUTPUT, ' +
         ' @nToteQTY   INT          OUTPUT  '
   
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cType, @cLight, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cToteID, @cDPLKey, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
         @cLOC OUTPUT, @cSKU OUTPUT, @cSKUDescr OUTPUT, @nTotalPOS OUTPUT, @nTotalQTY OUTPUT, @nToteQTY OUTPUT 
   END

Quit:

END

GO