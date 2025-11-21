SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PickByCartonID_GetNextTask                            */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-03-18  1.0  Ung      WMS-8284 Created                                 */
/* 2019-10-24  1.1  Ung      WMS-10821 Add PickDetail filter                  */
/* 2022-04-04  1.2  Ung      WMS-18892 Wave optional                          */
/*                           Add PickConfirmStatus                            */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PickByCartonID_GetNextTask] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cWaveKey      NVARCHAR( 10),
   @cPWZone       NVARCHAR( 10),
   @cCartonID1    NVARCHAR( 20),
   @cCartonID2    NVARCHAR( 20),
   @cCartonID3    NVARCHAR( 20),
   @cCartonID4    NVARCHAR( 20),
   @cCartonID5    NVARCHAR( 20),
   @cCartonID6    NVARCHAR( 20),
   @cCartonID7    NVARCHAR( 20),
   @cCartonID8    NVARCHAR( 20),
   @cCartonID9    NVARCHAR( 20),
   @cLOC          NVARCHAR( 10), 
   @cID           NVARCHAR( 18)  OUTPUT, 
   @cPosition     NVARCHAR( 10)  OUTPUT, 
   @cCartonID     NVARCHAR( 20)  OUTPUT,
   @cSKU          NVARCHAR( 20)  OUTPUT,
   @cSKUDescr     NVARCHAR( 60)  OUTPUT,
   @cLottable01   NCHAR( 18)     OUTPUT,
   @cLottable02   NCHAR( 18)     OUTPUT,
   @cLottable03   NCHAR( 18)     OUTPUT,
   @dLottable04   DATETIME       OUTPUT,
   @nQTY          INT            OUTPUT, 
   @nTotal        INT            OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @nRowCount INT
   
   DECLARE @cCurrCartonID NVARCHAR(20)
   DECLARE @cCurrID  NVARCHAR(18)
   DECLARE @cCurrSKU NVARCHAR(20)
   DECLARE @cCurrL01 NVARCHAR(18)
   DECLARE @cCurrL02 NVARCHAR(18)
   DECLARE @cCurrL03 NVARCHAR(18)
   DECLARE @dCurrL04 DATETIME
   DECLARE @cPickFilter NVARCHAR( MAX) = ''
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @tCartonID VariableTable

   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
      
   -- Save current task
   SET @cCurrCartonID = @cCartonID
   SET @cCurrID = @cID
   SET @cCurrSKU = @cSKU
   SET @cCurrL01 = @cLottable01
   SET @cCurrL02 = @cLottable02
   SET @cCurrL03 = @cLottable03
   SET @dCurrL04 = @dLottable04

   -- Get pick filter
   SELECT @cPickFilter = ISNULL( Long, '')
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'PickFilter'
      AND Code = @nFunc 
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility

   IF @cCartonID1 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID1) 
   IF @cCartonID2 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID2) 
   IF @cCartonID3 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID3) 
   IF @cCartonID4 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID4) 
   IF @cCartonID5 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID5) 
   IF @cCartonID6 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID6) 
   IF @cCartonID7 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID7) 
   IF @cCartonID8 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID8) 
   IF @cCartonID9 <> '' INSERT INTO @tCartonID (Value) VALUES (@cCartonID9)

   -- Get 1st task in LOC
   /*
   SELECT TOP 1
      @cCartonID   = PD.CaseID,
      @cID         = PD.ID,
      @cSKU        = PD.SKU,
      @cLottable01 = LA.Lottable01,
      @cLottable02 = LA.Lottable02,
      @cLottable03 = LA.Lottable03,
      @dLottable04 = LA.Lottable04, 
      @nQTY        = SUM( PD.QTY)
   FROM WaveDetail WD WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
      JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      JOIN @tCartonID t ON (PD.CaseID = t.CartonID)
   WHERE WD.WaveKey = @cWaveKey
      AND PD.LOC = @cLOC
      AND PD.Status < '5'
      AND PD.Status <> '4'
      AND PD.QTY > 0
   GROUP BY PD.ID, PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.CaseID
   ORDER BY PD.ID, PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.CaseID
   */
   SET @cSQL = 
      ' SELECT TOP 1 ' + 
         ' @cCartonID   = PD.CaseID,     ' + 
         ' @cID         = PD.ID,         ' + 
         ' @cSKU        = PD.SKU,        ' + 
         ' @cLottable01 = LA.Lottable01, ' + 
         ' @cLottable02 = LA.Lottable02, ' + 
         ' @cLottable03 = LA.Lottable03, ' + 
         ' @dLottable04 = LA.Lottable04, ' + 
         ' @nQTY        = SUM( PD.QTY)   ' + 
      ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
         ' JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT) ' + 
         ' JOIN @tCartonID t ON (PD.CaseID = t.Value) ' + 
         CASE WHEN @cWaveKey <> '' THEN ' JOIN WaveDetail WD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey) ' ELSE '' END + 
      ' WHERE PD.LOC = @cLOC ' + 
         ' AND PD.Status < @cPickConfirmStatus ' + 
         ' AND PD.Status <> ''4'' ' + 
         ' AND PD.QTY > 0 ' + 
         CASE WHEN @cWaveKey <> '' THEN ' AND WD.WaveKey = @cWaveKey ' ELSE '' END + 
         CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 
      ' GROUP BY PD.ID, PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.CaseID ' + 
      ' ORDER BY PD.ID, PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.CaseID ' +
      ' SET @nRowCount = @@ROWCOUNT '
   
   SET @cSQLParam = 
      ' @cWaveKey    NVARCHAR( 10), ' + 
      ' @cLOC        NVARCHAR( 10), ' +
      ' @cPickConfirmStatus NVARCHAR( 1), ' + 
      ' @tCartonID   VariableTable READONLY, ' + 
      ' @cCartonID   NVARCHAR( 20) OUTPUT, ' + 
      ' @cID         NVARCHAR( 18) OUTPUT, ' + 
      ' @cSKU        NVARCHAR( 20) OUTPUT, ' + 
      ' @cLottable01 NVARCHAR( 18) OUTPUT, ' + 
      ' @cLottable02 NVARCHAR( 18) OUTPUT, ' + 
      ' @cLottable03 NVARCHAR( 18) OUTPUT, ' + 
      ' @dLottable04 DATETIME      OUTPUT, ' + 
      ' @nQTY        INT           OUTPUT, ' + 
      ' @nRowCount   INT           OUTPUT    ' 

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cWaveKey, @cLOC, @cPickConfirmStatus, @tCartonID, 
      @cCartonID   OUTPUT, 
      @cID         OUTPUT,
      @cSKU        OUTPUT,
      @cLottable01 OUTPUT, 
      @cLottable02 OUTPUT, 
      @cLottable03 OUTPUT, 
      @dLottable04 OUTPUT, 
      @nQTY        OUTPUT,
      @nRowCount   OUTPUT
   
   -- Check if any task
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 136451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more TASK
      GOTO Quit
   END

   -- Different carton ID
   IF @cCurrCartonID <> @cCartonID
   BEGIN
      IF @cCartonID = @cCartonID1 SET @cPosition = '1' ELSE
      IF @cCartonID = @cCartonID2 SET @cPosition = '2' ELSE
      IF @cCartonID = @cCartonID3 SET @cPosition = '3' ELSE
      IF @cCartonID = @cCartonID4 SET @cPosition = '4' ELSE
      IF @cCartonID = @cCartonID5 SET @cPosition = '5' ELSE
      IF @cCartonID = @cCartonID6 SET @cPosition = '6' ELSE
      IF @cCartonID = @cCartonID7 SET @cPosition = '7' ELSE
      IF @cCartonID = @cCartonID8 SET @cPosition = '8' ELSE
      IF @cCartonID = @cCartonID9 SET @cPosition = '9' 
   END

   -- Different SKU
   IF @cCurrSKU <> @cSKU
      -- Get SKU info
      SELECT @cSKUDescr = Descr 
      FROM dbo.SKU SKU WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
         AND SKU = @cSKU

   -- Different SKU or lottables
   IF @cCurrID  <> @cID OR
      @cCurrSKU <> @cSKU OR
      @cCurrL01 <> @cLottable01 OR
      @cCurrL02 <> @cLottable02 OR
      @cCurrL03 <> @cLottable03 OR
      @dCurrL04 <> @dLottable04
   BEGIN
      -- Get total of next tasks (across carton ID)
      /*
      SELECT TOP 1
         @nTotal = SUM( PD.QTY)
      FROM WaveDetail WD WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         JOIN @tCartonID t ON (PD.CaseID = t.CartonID)
      WHERE WD.WaveKey = @cWaveKey
         AND PD.LOC = @cLOC
         AND PD.ID = @cID
         AND PD.SKU = @cSKU
         AND LA.Lottable01 = @cLottable01
         AND LA.Lottable02 = @cLottable02
         AND LA.Lottable03 = @cLottable03
         AND LA.Lottable04 = @dLottable04
         AND PD.Status < '5'
         AND PD.Status <> '4'
         AND PD.QTY > 0
      */
      SET @cSQL = 
         ' SELECT TOP 1 ' + 
            ' @nTotal = SUM( PD.QTY) ' + 
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
            ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT) ' + 
            ' JOIN @tCartonID t ON (PD.CaseID = t.Value) ' + 
            CASE WHEN @cWaveKey <> '' THEN ' JOIN WaveDetail WD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey) ' ELSE '' END + 
         ' WHERE PD.LOC = @cLOC ' + 
            ' AND PD.ID = @cID ' + 
            ' AND PD.SKU = @cSKU ' + 
            ' AND LA.Lottable01 = @cLottable01 ' + 
            ' AND LA.Lottable02 = @cLottable02 ' + 
            ' AND LA.Lottable03 = @cLottable03 ' + 
            ' AND LA.Lottable04 = @dLottable04 ' + 
            ' AND PD.Status < @cPickConfirmStatus ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.QTY > 0 ' + 
            CASE WHEN @cWaveKey <> '' THEN ' AND WD.WaveKey = @cWaveKey ' ELSE '' END + 
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
   
      SET @cSQLParam = 
         ' @cWaveKey    NVARCHAR( 10), ' + 
         ' @cLOC        NVARCHAR( 10), ' +
         ' @cID         NVARCHAR( 18), ' + 
         ' @cSKU        NVARCHAR( 20), ' + 
         ' @cLottable01 NVARCHAR( 18), ' + 
         ' @cLottable02 NVARCHAR( 18), ' + 
         ' @cLottable03 NVARCHAR( 18), ' + 
         ' @dLottable04 DATETIME,      ' + 
         ' @cPickConfirmStatus NVARCHAR( 1), ' + 
         ' @tCartonID   VariableTable READONLY, ' + 
         ' @nTotal      INT           OUTPUT    ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cWaveKey, @cLOC, @cID, @cSKU, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cPickConfirmStatus, @tCartonID, 
         @nTotal OUTPUT
   END
   
Quit:

END

GO