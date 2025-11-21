SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_Confirm                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close working batch                                         */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 15-05-2015 1.0  Ung         SOS336312 Created                        */
/* 04-01-2018 1.1  Ung         WMS-3549 Add lottables                   */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Confirm] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR(5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10) -- LOC = confirm LOC, CLOSETOTE/SHORTTOTE = confirm tote
   ,@cDPLKey         NVARCHAR( 10)
   ,@cMethod         NVARCHAR( 1) 
   ,@cCartID         NVARCHAR( 10)
   ,@cToteID         NVARCHAR( 20) -- Required for confirm tote
   ,@cLOC            NVARCHAR( 10)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cNewToteID      NVARCHAR( 20) -- For close tote with balance
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
   ,@cLottableCode   NVARCHAR( 30) 
   ,@cLottable01     NVARCHAR( 18)  
   ,@cLottable02     NVARCHAR( 18)  
   ,@cLottable03     NVARCHAR( 18)  
   ,@dLottable04     DATETIME  
   ,@dLottable05     DATETIME  
   ,@cLottable06     NVARCHAR( 30) 
   ,@cLottable07     NVARCHAR( 30) 
   ,@cLottable08     NVARCHAR( 30) 
   ,@cLottable09     NVARCHAR( 30) 
   ,@cLottable10     NVARCHAR( 30) 
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME
   ,@dLottable14     DATETIME
   ,@dLottable15     DATETIME
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   
   -- Get method info
   DECLARE @cConfirmSP SYSNAME
   SET @cConfirmSP = ''
   SELECT @cConfirmSP = ISNULL( UDF03, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'CartMethod'
      AND Code = @cMethod
      AND StorerKey = @cStorerKey

   -- Check confirm SP blank
   IF @cConfirmSP = ''
   BEGIN
      SET @nErrNo = 54651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupConfirmSP
      GOTO Quit
   END

   -- Check confirm SP valid
   IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
   BEGIN
      SET @nErrNo = 54652
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Confirm SP
      GOTO Quit
   END

   -- Detect lottables
   IF EXISTS( SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID( 'rdt.' + @cConfirmSP) AND name = '@cLottableCode')
   BEGIN
      -- Confirm SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cType, @cDPLKey, @cCartID, @cToteID, @cLOC, @cSKU, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cLottableCode, ' + 
         ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
         ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
         ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15  '
   
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5),  ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cType          NVARCHAR( 10), ' +
         ' @cDPLKey        NVARCHAR( 10), ' +
         ' @cCartID        NVARCHAR( 10), ' +
         ' @cToteID        NVARCHAR( 20), ' +
         ' @cLOC           NVARCHAR( 10), ' +
         ' @cSKU           NVARCHAR( 20), ' +
         ' @nQTY           INT,           ' +
         ' @cNewToteID     NVARCHAR( 20), ' +
         ' @nErrNo         INT            OUTPUT, ' +
         ' @cErrMsg        NVARCHAR( 20)  OUTPUT, ' +
         ' @cLottableCode  NVARCHAR( 30), ' + 
         ' @cLottable01    NVARCHAR( 18), ' +  
         ' @cLottable02    NVARCHAR( 18), ' +  
         ' @cLottable03    NVARCHAR( 18), ' +  
         ' @dLottable04    DATETIME,      ' + 
         ' @dLottable05    DATETIME,      ' + 
         ' @cLottable06    NVARCHAR( 30), ' + 
         ' @cLottable07    NVARCHAR( 30), ' + 
         ' @cLottable08    NVARCHAR( 30), ' + 
         ' @cLottable09    NVARCHAR( 30), ' + 
         ' @cLottable10    NVARCHAR( 30), ' + 
         ' @cLottable11    NVARCHAR( 30), ' + 
         ' @cLottable12    NVARCHAR( 30), ' + 
         ' @dLottable13    DATETIME,      ' + 
         ' @dLottable14    DATETIME,      ' + 
         ' @dLottable15    DATETIME       '
   
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cType, @cDPLKey, @cCartID, @cToteID, @cLOC, @cSKU, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cLottableCode, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
   END
   ELSE
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cType, @cDPLKey, @cCartID, @cToteID, @cLOC, @cSKU, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
      SET @cSQLParam =
         ' @nMobile    INT,           ' +
         ' @nFunc      INT,           ' +
         ' @cLangCode  NVARCHAR( 3),  ' +
         ' @nStep      INT,           ' +
         ' @nInputKey  INT,           ' +
         ' @cFacility  NVARCHAR( 5),  ' +
         ' @cStorerKey NVARCHAR( 15), ' +
         ' @cType      NVARCHAR( 10), ' +
         ' @cDPLKey    NVARCHAR( 10), ' +
         ' @cCartID    NVARCHAR( 10), ' +
         ' @cToteID    NVARCHAR( 20), ' +
         ' @cLOC       NVARCHAR( 10), ' +
         ' @cSKU       NVARCHAR( 20), ' +
         ' @nQTY       INT,           ' +
         ' @cNewToteID NVARCHAR( 20), ' +
         ' @nErrNo     INT            OUTPUT, ' +
         ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
   
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cType, @cDPLKey, @cCartID, @cToteID, @cLOC, @cSKU, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   END
   
Quit:

END

GO