SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1854SwapID01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-07-09 1.0  Chermane   WMS-17140 Created (dup rdt_862SwapID02)   */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1854SwapID01] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR(  3)
   ,@cStorer      NVARCHAR( 15)
   ,@cFacility    NVARCHAR(  5)
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@cLOC         NVARCHAR( 10)
   ,@cDropID      NVARCHAR( 20)
   ,@cID          NVARCHAR( 18)  OUTPUT
   ,@cInID        NVARCHAR( 18) --scanID
   ,@cSKU         NVARCHAR( 20)
   ,@cUOM         NVARCHAR( 10)
   ,@cLottable01  NVARCHAR( 18)
   ,@cLottable02  NVARCHAR( 18)
   ,@cLottable03  NVARCHAR( 18)
   ,@dLottable04  DATETIME
   ,@dLottable05  DATETIME
   ,@cLottable06  NVARCHAR( 30)
   ,@cLottable07  NVARCHAR( 30)
   ,@cLottable08  NVARCHAR( 30)
   ,@cLottable09  NVARCHAR( 30)
   ,@cLottable10  NVARCHAR( 30)
   ,@cLottable11  NVARCHAR( 30)
   ,@cLottable12  NVARCHAR( 30)
   ,@dLottable13  DATETIME
   ,@dLottable14  DATETIME
   ,@dLottable15  DATETIME
   ,@nTaskQTY     INT          
   ,@cActID       NVARCHAR( 18) --suggestID
   ,@nErrNo       INT           OUTPUT   
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   SET @cID = @cActID

   DECLARE @nRowCount      INT

   DECLARE @cOtherPickDetailKey NVARCHAR(10)
   
   DECLARE @cLot           NVARCHAR( 10),
           @cNewSKU        NVARCHAR( 20),
           @cNewLOT        NVARCHAR( 10),
           @cCurLOT        NVARCHAR( 10),
           @cNewLOC        NVARCHAR( 10),
           @cNewID         NVARCHAR( 18),
           @cCurID         NVARCHAR( 18),
           @cPickDetailKey NVARCHAR( 10),
           @cTaskKey       NVARCHAR( 10),
           @cPH_LoadKey    NVARCHAR( 10),
           @cTaskSKU       NVARCHAR( 20),
           @cPH_OrderKey   NVARCHAR( 10),
           @cOrderKey      NVARCHAR( 10),
           @cSwapOrderKey  NVARCHAR( 10),
           @cZone          NVARCHAR( 10),     
           @nNewQTY        INT,    
           @nQTY           INT,
           @nLotNum        INT,
           @nTranCount     INT,
           @curPD          CURSOR,
           @curPDOth       CURSOR

   DECLARE     
      @cNewLottable01   NVARCHAR( 18),    @cNewLottable02   NVARCHAR( 18),    
      @cNewLottable03   NVARCHAR( 18),    @dNewLottable04   DATETIME,         
      @dNewLottable05   DATETIME,         @cNewLottable06   NVARCHAR( 30),    
      @cNewLottable07   NVARCHAR( 30),    @cNewLottable08   NVARCHAR( 30),    
      @cNewLottable09   NVARCHAR( 30),    @cNewLottable10   NVARCHAR( 30),    
      @cNewLottable11   NVARCHAR( 30),    @cNewLottable12   NVARCHAR( 30),    
      @dNewLottable13   DATETIME,         @dNewLottable14   DATETIME,         
      @dNewLottable15   DATETIME
      
   DECLARE @cClass      NVARCHAR(10)
   DECLARE @cColor      NVARCHAR(10)
   DECLARE @cPalletType NVARCHAR(5)
   DECLARE @nSwapByID   INT
   
   -- lottable to Swap   
   DECLARE @tNewLot TABLE    
   (    
      Num               INT IDENTITY(1,1) NOT NULL,  
      NewLot            NVARCHAR( 10),
      NewPickDetialKey  NVARCHAR(10),
      NewQty            INT
   )    
   
   -- Current lottable to Swap   
   DECLARE @tCurLot TABLE    
   (    
      Num               INT IDENTITY(1,1) NOT NULL,  
      CurLot            NVARCHAR( 10),
      CurPickDetialKey  NVARCHAR(10),
      CurQty            INT
   )    
   
   SELECT 
      @cClass = Class,
      @cColor = Color
   FROM SKU WITH (NOLOCK)
   WHERE SKU = @cSKU
   AND storerKey = @cStorer
   
   SELECT 
      @cPalletType = V_String5
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE mobile = @nMobile
      
   SET @cNewID = ''
   SET @cNewLottable02 = ''
   

   --INSERT INTO traceInfo (TraceName,col1,col2,col3,col4,col5,step1,timein)
   --VALUES('1854swap01',@cPickSlipNo,@cLOC,@cInID,@cID,@nTaskQTY,@cLottable02,GETDATE())
   
   --checking swap by lot02 (uniq seriesNo, or ID)
   IF @cClass = 'R' -- no swap, fixed series No (lot02)
   BEGIN
   	IF NOT EXISTS (SELECT TOP 1 1
                     FROM pickdetail PD
                     JOIN pickHeader PH ON (PD.orderKey = PH.orderKey)
                     JOIN Loc L on (L.Loc = PD.Loc)
                     JOIN dbo.LOTATTRIBUTE LA on (LA.lot = PD.lot)
                     WHERE PH.PickHeaderKey = @cPickSlipNo
                     AND PD.loc = @cLOC
   	               AND LA.Lottable02 = @cInID)
      BEGIN
      	SET @nErrNo = 174601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidID/Lot02
         RETURN
      END
      
      SET @cNewLottable02 = @cInID  
      -- only can swap within Same OrderKey 	
      IF @cLottable02 <> @cNewLottable02
      BEGIN
         SELECT 
            @cOrderKey = PD.OrderKey
         FROM pickdetail PD
         JOIN pickHeader PH ON (PD.orderKey = PH.orderKey)
         JOIN Loc L on (L.Loc = PD.Loc)
         JOIN dbo.LOTATTRIBUTE LA on (LA.lot = PD.lot)
         WHERE PH.PickHeaderKey = @cPickSlipNo
         AND PD.loc = @cLOC
   	   AND LA.Lottable02 = @cLottable02
   	   
   	   SELECT 
            @cSwapOrderKey = PD.OrderKey
         FROM pickdetail PD
         JOIN pickHeader PH ON (PD.orderKey = PH.orderKey)
         JOIN Loc L on (L.Loc = PD.Loc)
         JOIN dbo.LOTATTRIBUTE LA on (LA.lot = PD.lot)
         WHERE PH.PickHeaderKey = @cPickSlipNo
         AND PD.loc = @cLOC
   	   AND LA.Lottable02 = @cNewLottable02
   	   
   	   IF @cOrderKey <> @cSwapOrderKey
   	   BEGIN
   	   	SET @nErrNo = 174618
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L02 Not Match
            RETURN
   	   END
   	   ELSE
   	   BEGIN
   	   	SET @nSwapByID = 0
   	   END
      END
      ELSE
      	--No Need Swap
      BEGIN
   		SET @cID = @cInID
   		RETURN -- no swap
      END
      
   END
   ELSE IF @cClass = 'N' AND @cColor IN ('GA','RACK') AND @cPalletType = 'FP' -- no swap, 1 Loc 1 ID
   BEGIN
      IF @cInID <> @cID
      BEGIN
      	SET @nErrNo = 174616
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidID
      END
   	RETURN
   END
   ELSE IF @cClass = 'N' AND @cColor IN ('GA','RACK') AND @cPalletType = 'PP'
   BEGIN
   	SET @cNewLottable02 = @cInID
   	IF @cLottable02 = @cNewLottable02
   	BEGIN
   		SET @cID = @cInID
   		RETURN -- no swap
   	END
   	SET @nSwapByID = 0
   END
   ELSE IF @cClass = 'N' AND @cColor NOT IN ('GA','RACK') AND @cPalletType = 'FP'
   BEGIN
   	IF @cInID = @cID
      BEGIN
      	RETURN --no swap
      END
   	
   	SET @cNewID = @cInID
   	SET @nSwapByID = 1

   END
   ELSE IF @cClass = 'N' AND @cColor NOT IN ('GA','RACK') AND @cPalletType = 'PP'
   BEGIN
   	SET @cNewLottable02 = @cInID
   	IF @cLottable02 = @cNewLottable02
   	BEGIN
   		SET @cID = @cInID
   		RETURN -- no swap
   	END
   	SET @nSwapByID = 0
   END
   
   --Get New ID Info
   IF @nSwapByID = 1
   BEGIN
   	-- Check ID picked
      IF EXISTS( SELECT TOP 1 1
         FROM PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorer
            AND SKU = @cNewSKU
            AND ID = @cNewID
            AND Status <> '0'
            AND QTY > 0)
      BEGIN
         SET @nErrNo = 174607
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID picked
         RETURN
      END
      
   	--Get current designated id Info
      SELECT @cLOT = LOT
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   ID = @cID
      AND   QTY-QTYPicked > 0
   
   	SELECT
         @cNewSKU = SKU,
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
         SET @nErrNo = 174602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lottable02
         RETURN
      END
      
      -- Check ID multi LOC/LOT, Full Paleet can be multi Lot
      IF @nRowCount > 1 AND @cPalletType <> 'FP'
      BEGIN
         SET @nErrNo = 174603
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID multi rec
         RETURN
      END
      
      SELECT
         @nNewQTY = SUM(QTY-QTYPicked)
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   ID = @cNewID
      AND   QTY-QTYPicked > 0
      
   END
   ELSE IF @nSwapByID = 0
   BEGIN
      -- Check lottable picked
      IF EXISTS( SELECT TOP 1 1
         FROM PickDetail PD WITH (NOLOCK)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)
         WHERE PD.StorerKey = @cStorer
            AND PD.SKU = @cNewSKU
            AND LA.Lottable02 = @cNewLottable02
            AND PD.Status <> '0'
            AND PD.QTY > 0)
      BEGIN
         SET @nErrNo = 174617
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID picked
         RETURN
      END
      
   	--Get current designated id Info
      SELECT @cLOT = LLI.LOT,
      @cCurID = LLI.ID
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
      WHERE LLI.StorerKey = @cStorer
      AND   LA.Lottable02 = @cLottable02
      AND   LLI.QTY-LLI.QTYPicked > 0
   	
   	SELECT
         @cNewSKU = LLI.SKU,
         @nNewQTY = SUM(LLI.QTY-LLI.QTYPicked),
         @cNewLOT = LLI.LOT,
         @cNewLOC = LLI.LOC,
         @cNewID  = LLI.ID
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
      WHERE LLI.StorerKey = @cStorer
      --AND LLI.ID = @cID
      AND LA.Lottable02 = @cNewLottable02
      AND LLI.QTY-LLI.QTYPicked > 0
   	GROUP BY LLI.SKU, LLI.LOT, LLI.LOC,LLI.ID 
   	
   	SET @nRowCount = @@ROWCOUNT 

      -- Check ID valid
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 174602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lottable02
         RETURN
      END
      
      -- Check ID multi LOC/LOT, Full Paleet can be multi Lot
      IF @nRowCount > 1 AND @cPalletType <> 'FP'
      BEGIN
         SET @nErrNo = 174603
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID multi rec
         RETURN
      END
   	
   	--IF NOT EXISTS (SELECT LLI.*
    --                 FROM dbo.LOTxLOCxID LLI 
    --                 JOIN dbo.LOTATTRIBUTE LA on (LA.lot = LLI.lot)
    --                 WHERE LLI.loc = @cLOC
    --                 AND LA.Lottable02 = @cLottable02
    --                 AND LLI.ID = @cNewID)
    --  BEGIN
    --  	SET @nErrNo = 174623
    --     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ID
    --     RETURN
    --  END
   	
   END

  
   -- Check LOC match
   IF @cNewLOC <> @cLOC
   BEGIN
      SET @nErrNo = 174604
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
      RETURN
   END

   -- Check SKU match
   IF @cNewSKU <> @cSKU
   BEGIN
      SET @nErrNo = 174605
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not match
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
   
   -- Check QTY match
   IF @nNewQTY <> @nTaskQTY
   BEGIN
      SET @nErrNo = 174606
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match
      RETURN
   END
      
   IF @cNewLottable01 <> @cLottable01 OR @cNewLottable01 IS NULL OR @cLottable01 IS NULL
   BEGIN
      SET @nErrNo = 174608
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L01 Not Match
      RETURN
   END

   IF DATEDIFF( DD, @dLottable05, @dNewLottable05) >= 90 OR @dNewLottable05 IS NULL OR @dLottable05 IS NULL
   BEGIN
      SET @nErrNo = 174609
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L05 Not Match
      RETURN
   END

   IF @cNewLottable06 <> @cLottable06 OR @cNewLottable06 IS NULL OR @cLottable06 IS NULL
   BEGIN
      SET @nErrNo = 174610
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L06 Not Match
      RETURN
   END

   IF @cNewLottable07 <> @cLottable07 OR @cNewLottable07 IS NULL OR @cLottable07 IS NULL
   BEGIN
      SET @nErrNo = 174611
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L07 Not Match
      RETURN
   END

   IF @cNewLottable08 <> @cLottable08 OR @cNewLottable08 IS NULL OR @cLottable08 IS NULL
   BEGIN
      SET @nErrNo = 174612
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L08 Not Match
      RETURN
   END

   IF @cNewLottable12 <> @cLottable12 OR @cNewLottable12 IS NULL OR @cLottable12 IS NULL
   BEGIN
      SET @nErrNo = 174613
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
   IF @nSwapByID = '1'
   BEGIN
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
      
      INSERT INTO @tCurLot (CurLot,CurPickDetialKey,CurQty)
      SELECT LLI.Lot, PD.pickdetailKey, PD.Qty 
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN pickDetail PD  WITH (NOLOCK) ON (PD.Lot = LLI.Lot AND PD.ID = LLI.ID AND PD.Loc = LLI.Loc) 
      WHERE LLI.StorerKey = @cStorer
      AND   LLI.ID = @cID
      AND   LLI.Loc = @cLoc
      AND   LLI.QTY-LLI.QTYPicked > 0 
      
      
      --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4)
      --SELECT '1854swap01CurLot',getdate(), num,curLot,CurPickDetialKey,CurQty FROM @tCurLot
      

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_1854SwapID01
      
      -- 1.ID is not alloc 
      -- update current pickdetail with newLot
      SET @nLotNum = 1
      IF @cOtherPickDetailKey = ''
      BEGIN
      	INSERT INTO @tNewLot (NewLot,NewPickDetialKey,NewQty)
         SELECT LLI.Lot, '', LLI.Qty 
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.Lot = LA.Lot) 
         WHERE LLI.StorerKey = @cStorer
         AND   LLI.ID = @cNewID
         AND   LLI.Loc = @cNewLoc
         AND   LLI.QTY-LLI.QTYPicked > 0 
         
         --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4)
         --SELECT '1854swap01NewLot',getdate(), num,newLot,NewPickDetialKey,NewQty FROM @tNewLot
         
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
            SELECT @cNewLOT = newLot FROM @tNewLot WHERE Num = @nLotNum                             
         
            --Update current task PickDetail
            UPDATE PickDetail SET
               LOT = @cNewLOT, 
               ID = @cNewID, 
               EditDate = GETDATE(), 
               EditWho = 'rdt.' + SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            
            IF @@ERROR <> 0
               GOTO RollBackTran
            
            --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3)
            --SELECT '1854swap01updateCur',getdate(), @cNewLOT,@cNewID,@cPickDetailKey
               
            SET @nNewQTY = @nNewQTY - @nQTY
            SET @nLotNum = @nLotNum + 1
         
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
         
         -- Check balance
         IF @nNewQTY <> 0
         BEGIN
            SET @nErrNo = 174619
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr
            GOTO RollBackTran
         END
         GOTO Quit
      END
      
      SET @nLotNum = 1
      -- 2. ID in on others pickDetail
      -- update oth pickdetail with curLot
      IF @cOtherPickDetailKey <> ''
      BEGIN
      	INSERT INTO @tNewLot (NewLot,NewPickDetialKey,NewQty)
         SELECT LLI.Lot, PD.pickdetailKey, PD.Qty 
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN pickDetail PD  WITH (NOLOCK) ON (PD.Lot = LLI.Lot AND PD.ID = LLI.ID AND PD.Loc = LLI.Loc) 
         WHERE LLI.StorerKey = @cStorer
         AND   LLI.ID = @cNewID
         AND   LLI.Loc = @cNewLoc
         AND   LLI.QTY-LLI.QTYPicked > 0 
         
         --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4)
         --SELECT '1854swap01NewLot',getdate(), num,newLot,NewPickDetialKey,NewQty FROM @tNewLot
         
         --loop current others tack pickdetail
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
            SELECT @cNewLOT = newLot FROM @tNewLot WHERE Num = @nLotNum                             
         
            --Update current task PickDetail -> newlot
            UPDATE PickDetail SET
               LOT = @cNewLOT, 
               ID = @cNewID, 
               EditDate = GETDATE(), 
               EditWho = 'rdt.' + SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            
            IF @@ERROR <> 0
               GOTO RollBackTran
            
            --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3)
            --SELECT '1854swap01updateCurx',getdate(), @cNewLOT,@cNewID,@cPickDetailKey
            
            SET @nNewQTY = @nNewQTY - @nQTY
            SET @nLotNum = @nLotNum + 1
            
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
         
         SET @nLotNum = 1
         -- Loop Other PickDetail
         SET @curPDOth = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT NewPickDetialKey, NewQTY
            FROM @tNewLot
         OPEN @curPDOth
         FETCH NEXT FROM @curPDOth INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN                     
         	SELECT @cCurLOT = CurLot FROM @tCurLot WHERE Num = @nLotNum   
             --Update other task PickDetail -> currentLot
            UPDATE PickDetail SET
               LOT = @cCurLOT, 
               ID = @cID, 
               EditDate = GETDATE(), 
               EditWho = 'rdt.' + SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
                       
            IF @@ERROR <> 0
               GOTO RollBackTran
               
            --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3)
            --SELECT '1854swap01updateOthx',getdate(), @cCurLOT,@cID,@cPickDetailKey
               
            SET @nTaskQTY = @nTaskQTY - @nQTY
            SET @nLotNum = @nLotNum + 1
            FETCH NEXT FROM @curPDOth INTO @cPickDetailKey, @nQTY
         END
         -- Check balance
         IF @nTaskQTY <> 0 AND @nNewQTY <> 0
         BEGIN
            SET @nErrNo = 174620
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr
            GOTO RollBackTran
         END
         GOTO Quit  
      END             
           
      --Check not swap
      SET @nErrNo = 174615
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NothingSwapped
      GOTO RollBackTran

   END
   ELSE
--/*--------------------------------------------------------------------------------------------------

--                                                Swap lot02 (serialNo)

----------------------------------------------------------------------------------------------------*/
   BEGIN --swap by lot02
      SELECT @cZone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey     
      FROM dbo.PickHeader WITH (NOLOCK)     
      WHERE PickHeaderKey = @cPickSlipNo   

      -- Get other PickDetail info
      SET @cOtherPickDetailKey = ''
      SELECT @cOtherPickDetailKey = PD.PickDetailKey
      FROM PickDetail PD WITH (NOLOCK)
      JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.lot = PD.Lot)
      WHERE PD.StorerKey = @cStorer
         AND PD.SKU = @cNewSKU
         AND LA.Lottable02 = @cNewLottable02
         AND Status = '0'
         AND QTY > 0
         
      INSERT INTO @tCurLot (CurLot,CurPickDetialKey,CurQty)
      SELECT LLI.Lot, PD.pickdetailKey, PD.Qty 
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN pickDetail PD  WITH (NOLOCK) ON (PD.Lot = LLI.Lot AND PD.ID = LLI.ID AND PD.Loc = LLI.Loc) 
      JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.lot = LLI.Lot)
      WHERE LLI.StorerKey = @cStorer
      AND   LA.Lottable02 = @cLottable02
      AND   LLI.Loc = @cLoc
      AND   LLI.QTY-LLI.QTYPicked > 0 

      --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4)
      --SELECT '1854swap01CurLot02',getdate(), num,curLot,CurPickDetialKey,CurQty FROM @tCurLot
      
     
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_1854SwapID01
     
      -- 1.ID is not alloc  or ID on other PickDetail
      -- update current pickdetail with newLot
      SET @nLotNum = 1
      IF @cOtherPickDetailKey = ''
      BEGIN
      	INSERT INTO @tNewLot (NewLot,NewPickDetialKey,NewQty)
         SELECT LLI.Lot, '', LLI.Qty 
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.Lot = LA.Lot) 
         WHERE LLI.StorerKey = @cStorer
         AND   LA.Lottable02 = @cNewLottable02
         AND   LLI.Loc = @cNewLoc
         AND   LLI.ID = @cNewID
         AND   LLI.QTY-LLI.QTYPicked > 0 
         
         --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4)
         --SELECT '1854swap01NewLot02',getdate(), num,newLot,NewPickDetialKey,NewQty FROM @tNewLot
      	
      	SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey, PD.QTY
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.lot = PD.Lot)
            WHERE PD.Loc = @cLoc
            AND PD.SKU = @cSKU
            AND LA.Lottable02 = @cLottable02
               AND Status = '0'
               AND QTY > 0
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
      	   SELECT @cNewLOT = newLot FROM @tNewLot WHERE Num = @nLotNum                             
         
            --Update current task PickDetail
            UPDATE PickDetail SET
               LOT = @cNewLOT, 
               ID = @cNewID, 
               EditDate = GETDATE(), 
               EditWho = 'rdt.' + SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            
            IF @@ERROR <> 0
               GOTO RollBackTran
            
            --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3)
            --SELECT '1854swap01updateCurLot02',getdate(), @cNewLOT,@cNewID,@cPickDetailKey
               
            SET @nNewQTY = @nNewQTY - @nQTY
            SET @nLotNum = @nLotNum + 1
         
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
         -- Check balance
         IF @nNewQTY <> 0
         BEGIN
            SET @nErrNo = 174621
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr
            GOTO RollBackTran
         END
         GOTO QUIT
      END

      SET @nLotNum = 1
      -- 2. ID in on others pickDetail
      -- update oth pickdetail with curLot
      IF @cOtherPickDetailKey <> ''
      BEGIN
      	INSERT INTO @tNewLot (NewLot,NewPickDetialKey,NewQty)
         SELECT LLI.Lot, PD.pickdetailKey, PD.Qty 
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN pickDetail PD  WITH (NOLOCK) ON (PD.Lot = LLI.Lot AND PD.ID = LLI.ID AND PD.Loc = LLI.Loc) 
         JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.lot = LLI.Lot)
         WHERE LLI.StorerKey = @cStorer
         AND   LLI.Loc = @cNewLoc
         AND   LA.Lottable02 = @cNewLottable02
         AND   LLI.QTY-LLI.QTYPicked > 0 
         
         --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4)
         --SELECT '1854swap01NewLot02',getdate(), num,newLot,NewPickDetialKey,NewQty FROM @tNewLot
         
         --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4,col5,step5)
         --SELECT '1854swap01NewLot02A',GETDATE(),@cLoc,@cSKU,@cLottable02,@cNewID,@cInID,@cCurID
   

         -- Loop current PickDetail
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey, PD.QTY
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.lot = PD.Lot)
            WHERE PD.Loc = @cLoc
            AND PD.SKU = @cSKU
            AND LA.Lottable02 = @cLottable02
               AND Status = '0'
               AND QTY > 0
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
      	   SELECT @cNewLOT = newLot FROM @tNewLot WHERE Num = @nLotNum                
      	   
      	   --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4,col5)
          --  SELECT '1854swap01updateCurLot02',getdate(), @cNewLOT,@cNewID,@cPickDetailKey,@cInID,@cLottable02             
         
            --Update Other task PickDetail-> New Lot
            UPDATE PickDetail SET
               LOT = @cNewLOT, 
               ID = @cNewID, 
               EditDate = GETDATE(), 
               EditWho = 'rdt.' + SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            
            IF @@ERROR <> 0
               GOTO RollBackTran
               
            SET @nNewQTY = @nNewQTY - @nQTY
            SET @nLotNum = @nLotNum + 1
         
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
         
         SET @nLotNum = 1
         -- Loop Other PickDetail
         SET @curPDOth = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT NewPickDetialKey, NewQTY
            FROM @tNewLot
         OPEN @curPDOth
         FETCH NEXT FROM @curPDOth INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN                     
         	--INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4,col5)
          --  SELECT '1854swap01updateOthlot02',getdate(), @cCurLOT,@cNewID,@cPickDetailKey,@cInID,@cLottable02
            
         	SELECT @cCurLOT = CurLot FROM @tCurLot WHERE Num = @nLotNum   
             --Update Other task PickDetail-> current Lot
            UPDATE PickDetail SET
               LOT = @cCurLOT, 
               ID = @cCurID, 
               EditDate = GETDATE(), 
               EditWho = 'rdt.' + SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
                       
            IF @@ERROR <> 0
               GOTO RollBackTran
               
               
            SET @nTaskQTY = @nTaskQTY - @nQTY
            SET @nLotNum = @nLotNum + 1
            FETCH NEXT FROM @curPDOth INTO @cPickDetailKey, @nQTY
         END
         -- Check balance
         IF @nTaskQTY <> 0 AND @nNewQTY <> 0
         BEGIN
            SET @nErrNo = 174622
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr
            GOTO RollBackTran
         END
         
         GOTO QUIT
      END             
      --Check not swap
      SET @nErrNo = 174615
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NothingSwapped
      GOTO RollBackTran      

      
   END
   
   RollBackTran:
      ROLLBACK TRAN rdt_1854SwapID01
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN   

   IF @nErrNo = 0
      SET @cID = @cInID
   

GO