SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_862SwapID02                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2018-03-15 1.0  James   WMS3621. Created                             */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_862SwapID02] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR(  3)
   ,@cStorer      NVARCHAR( 15)
   ,@cFacility    NVARCHAR(  5)
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@cLOC         NVARCHAR( 10)
   ,@cDropID      NVARCHAR( 20)
   ,@cID          NVARCHAR( 18)  OUTPUT
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

   SET @nErrNo = 0

   DECLARE @nRowCount      INT

   DECLARE @cOtherPickDetailKey NVARCHAR(10),
           @cOtherTaskDetailKey NVARCHAR(10)
   
   DECLARE @cLot           NVARCHAR( 10),
           @cNewSKU        NVARCHAR( 20),
           @cNewLOT        NVARCHAR( 10),
           @cNewLOC        NVARCHAR( 10),
           @cNewID         NVARCHAR( 18),
           @cPickDetailKey NVARCHAR( 10),
           @cTaskKey       NVARCHAR( 10),
           @cPH_LoadKey    NVARCHAR( 10),
           @cTaskSKU       NVARCHAR( 20),
           @cPH_OrderKey   NVARCHAR( 10),
           @cZone          NVARCHAR( 10),
           @dLottable05    DATETIME,         
           @cLottable06    NVARCHAR( 30),    
           @cLottable07    NVARCHAR( 30),    
           @cLottable08    NVARCHAR( 30),    
           @cLottable09    NVARCHAR( 30),    
           @cLottable10    NVARCHAR( 30),    
           @cLottable11    NVARCHAR( 30),    
           @cLottable12    NVARCHAR( 30),    
           @dLottable13    DATETIME,         
           @dLottable14    DATETIME,         
           @dLottable15    DATETIME,     
           @nNewQTY        INT,    
           @nQTY           INT

   DECLARE     
      @cNewLottable01   NVARCHAR( 18),    @cNewLottable02   NVARCHAR( 18),    
      @cNewLottable03   NVARCHAR( 18),    @dNewLottable04   DATETIME,         
      @dNewLottable05   DATETIME,         @cNewLottable06   NVARCHAR( 30),    
      @cNewLottable07   NVARCHAR( 30),    @cNewLottable08   NVARCHAR( 30),    
      @cNewLottable09   NVARCHAR( 30),    @cNewLottable10   NVARCHAR( 30),    
      @cNewLottable11   NVARCHAR( 30),    @cNewLottable12   NVARCHAR( 30),    
      @dNewLottable13   DATETIME,         @dNewLottable14   DATETIME,         
      @dNewLottable15   DATETIME

   IF @nFunc <> 862 -- Pick by ID
   BEGIN
      SET @nErrNo = 122551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Wrong ID'
   END
   
   SET @cNewID = @cActID

   -- Check blank
   IF @cNewID = ''
   BEGIN
      SET @nErrNo = 122552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID
      RETURN
   END

   SELECT @cLOT = LOT
   FROM dbo.LOTxLOCxID WITH (NOLOCK)
   WHERE StorerKey = @cStorer
   AND   ID = @cID
   AND   QTY-QTYPicked > 0

   -- Get new ID info
   SELECT
      @cNewSKU = SKU,
      @nNewQTY = QTY-QTYPicked,
      @cNewLOT = LOT,
      @cNewLOC = LOC
   FROM dbo.LOTxLOCxID WITH (NOLOCK)
   WHERE StorerKey = @cStorer
   AND   ID = @cNewID
   AND   QTY-QTYPicked > 0

   SET @nRowCount = @@ROWCOUNT 

   -- Check ID valid
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 122553
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
      RETURN
   END

   -- Check ID multi LOC/LOT
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 122554
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID multi rec
      RETURN
   END

   -- Check LOC match
   IF @cNewLOC <> @cLOC
   BEGIN
      SET @nErrNo = 122555
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
      RETURN
   END

   -- Check SKU match
   IF @cNewSKU <> @cSKU
   BEGIN
      SET @nErrNo = 122556
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not match
      RETURN
   END

   -- Check QTY match
   IF @nNewQTY <> @nTaskQTY
   BEGIN
      SET @nErrNo = 122557
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match
      RETURN
   END

   -- Check ID picked
   IF EXISTS( SELECT TOP 1 1
      FROM PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorer
         AND SKU = @cNewSKU
         AND ID = @cNewID
         AND Status <> '0'
         AND QTY > 0)
   BEGIN
      SET @nErrNo = 122558
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID picked
      RETURN
   END

   -- Get new id lottable info
   SELECT @cNewLottable01 = Lottable01,
          @dNewLottable05 = Lottable05,
          @cNewLottable06 = Lottable06,
          @cNewLottable07 = Lottable07,
          @cNewLottable08 = Lottable08,
          @cNewLottable12 = Lottable12
   FROM dbo.LotAttribute WITH (NOLOCK)
   WHERE LOT = @cNewLOT

   -- Get current designated id lottable info
   SELECT @cLottable01 = Lottable01,
          @dLottable05 = Lottable05,
          @cLottable06 = Lottable06,
          @cLottable07 = Lottable07,
          @cLottable08 = Lottable08,
          @cLottable12 = Lottable12
   FROM dbo.LotAttribute WITH (NOLOCK)
   WHERE LOT = @cLOT

   IF @cNewLottable01 <> @cLottable01 OR @cNewLottable01 IS NULL OR @cLottable01 IS NULL
   BEGIN
      SET @nErrNo = 122559
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L01 Not Match
      RETURN
   END

   IF DATEDIFF( DD, @dLottable05, @dNewLottable05) > 90 OR @dNewLottable05 IS NULL OR @dLottable05 IS NULL
   BEGIN
      SET @nErrNo = 122560
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L05 Not Match
      RETURN
   END

   IF @cNewLottable06 <> @cLottable06 OR @cNewLottable06 IS NULL OR @cLottable06 IS NULL
   BEGIN
      SET @nErrNo = 122561
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L06 Not Match
      RETURN
   END

   IF @cNewLottable07 <> @cLottable07 OR @cNewLottable07 IS NULL OR @cLottable07 IS NULL
   BEGIN
      SET @nErrNo = 122562
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L07 Not Match
      RETURN
   END

   IF @cNewLottable08 <> @cLottable08 OR @cNewLottable08 IS NULL OR @cLottable08 IS NULL
   BEGIN
      SET @nErrNo = 122563
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L08 Not Match
      RETURN
   END

   IF @cNewLottable12 <> @cLottable12 OR @cNewLottable12 IS NULL OR @cLottable12 IS NULL
   BEGIN
      SET @nErrNo = 122564
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L12 Not Match
      RETURN
   END

/*--------------------------------------------------------------------------------------------------

                                                Swap ID

--------------------------------------------------------------------------------------------------*/
/*
   Scenario:
   1. ID is not alloc           swap
   2. ID on other PickDetail    swap
*/

   SELECT @cZone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey     
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo   

   -- Get other PickDetail info
   SET @cOtherPickDetailKey = ''
   SELECT @cOtherPickDetailKey = PickDetailKey
   FROM PickDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorer
      AND SKU = @cNewSKU
      AND ID = @cNewID
      AND Status = '0'
      AND QTY > 0

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_862SwapID02
   
   -- 1. ID is not alloc
   IF @cOtherPickDetailKey = ''
   BEGIN
      -- Loop PickDetail
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey, QTY
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE Loc = @cLoc
         AND SKU = @cSKU
         AND ID = @cID
            AND Status = '0'
            AND QTY > 0
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update current task PickDetail
         UPDATE PickDetail SET
            LOT = @cNewLOT, 
            ID = @cNewID, 
            EditDate = GETDATE(), 
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
            GOTO RollBackTran

         SET @nNewQTY = @nNewQTY - @nQTY
         
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      END

      -- Check balance
      IF @nNewQTY <> 0
      BEGIN
         SET @nErrNo = 122565
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr
         GOTO RollBackTran
      END

      GOTO Quit
   END
   ELSE
   BEGIN
      IF ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'    
      BEGIN
         IF EXISTS ( SELECT 1    
                     FROM dbo.PickDetail PD (NOLOCK) 
                     JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
                      WHERE RPL.PickslipNo = @cPickSlipNo    
                      AND   PD.Status < '4'
                      AND   PD.QTY > 0
                      AND   PD.LOC = @cLOC
                      AND   PD.ID = @cNewID)
         BEGIN
            GOTO Quit
         END
      END
      ELSE
      IF ISNULL(@cPH_OrderKey, '') <> ''
      BEGIN
         IF EXISTS ( SELECT 1    
                     FROM dbo.PickHeader PH (NOLOCK)     
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
                     WHERE PH.PickHeaderKey = @cPickSlipNo    
                     AND   PD.Status < '4'
                     AND   PD.QTY > 0
                     AND   PD.LOC = @cLOC
                     AND   PD.ID = @cNewID)
         GOTO Quit
      END
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1 
                     FROM dbo.PickHeader PH (NOLOCK)     
                     JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
                     JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
                     WHERE PH.PickHeaderKey = @cPickSlipNo    
                     AND   PD.Status < '4'
                     AND   PD.QTY > 0
                     AND   PD.LOC = @cLOC
                     AND   PD.ID = @cNewID)   
            GOTO Quit
      END
   END

   --Check not swap
   SET @nErrNo = 122566
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NothingSwapped
   GOTO RollBackTran

   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_862SwapID02
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

   IF @nErrNo = 0
      SET @cID = @cActID

GO