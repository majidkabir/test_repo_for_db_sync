SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_PTLCart_Confirm_PickSlip_LottableCursor               */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Open PickDetail or PTLTran cursor, with optional lottables filter */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 14-03-2018 1.0  Ung         WMS-4247 Created                               */
/* 02-08-2022 1.1  yeekung     WMS-18463 add lot (yeekung01)                  */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLCart_Confirm_PickSlip_LottableCursor] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR(5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cSQL            NVARCHAR( MAX)
   ,@cTableAlias     NVARCHAR( 20)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cOrderKey       NVARCHAR( 10)
   ,@cLoadKey        NVARCHAR( 10)
   ,@cPickConfirmStatus NVARCHAR( 1)
   ,@cDPLKey         NVARCHAR( 10)
   ,@cLOC            NVARCHAR( 10)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cPosition       NVARCHAR( 20)
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
   ,@cLot            NVARCHAR( 20)
   ,@curCursor       CURSOR VARYING OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cWhere      NVARCHAR( MAX)
   DECLARE @nErrNo      INT
   DECLARE @cErrMsg     NVARCHAR( 20)

   -- Get lottable filter
   EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 4, @cTableAlias,
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
      @cWhere   OUTPUT,
      @nErrNo   OUTPUT,
      @cErrMsg  OUTPUT

   -- Lottable filter
   IF @cWhere <> ''
      SET @cSQL = @cSQL + ' AND ' + @cWhere

   -- Open cursor
   SET @cSQL =
      ' SET @curCursor = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +
         @cSQL +
      ' OPEN @curCursor '

   SET @cSQLParam =
      ' @cPickSlipNo    NVARCHAR( 10), ' +
      ' @cOrderKey      NVARCHAR( 10), ' +
      ' @cLoadKey       NVARCHAR( 10), ' +
      ' @cPickConfirmStatus NVARCHAR( 1), ' +
      ' @cStorerKey     NVARCHAR( 15), ' +
      ' @cDPLKey        NVARCHAR( 10), ' +
      ' @cLOC           NVARCHAR( 10), ' +
      ' @cSKU           NVARCHAR( 15), ' +
      ' @nQTY           INT,           ' +
      ' @cPosition      NVARCHAR( 20), ' +
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
      ' @dLottable15    DATETIME,      ' +
      ' @cLot           NVARCHAR( 20), ' +
      ' @curCursor      CURSOR  OUTPUT '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickConfirmStatus, @cStorerKey, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode,
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,@cLot,
      @curCursor OUTPUT

END

GO