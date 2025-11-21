SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_Pick_SwapLot                                    */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Swap LOT                                                    */  
/*                                                                      */  
/* Called from: rdtfnc_Pick_SwapLot                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 30-Dec-2008 1.0  James       Created                                 */  
/* 07-May-2009 1.1  Shong       Bug Fixed                               */
/* 20-Jul-2009 1.2  Shong       Bug Fixed                               */
/* 10-Aug-2009 1.3  James       Bug Fixed (james01)                     */
/* 03-Apr-2014 1.4  Ung         SOS306868. Change status 4->3           */
/************************************************************************/  

CREATE PROC [RDT].[rdt_Pick_SwapLot] (  
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cUserName     NVARCHAR( 15),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cPickSlipNo   NVARCHAR( 10),  
   @cSKU          NVARCHAR( 20),  
   @cLOC          NVARCHAR( 10),   
   @cID           NVARCHAR( 18),  
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),  
   @cLottable02   NVARCHAR( 18),  
   @cLottable03   NVARCHAR( 18),  
   @dLottable04   DATETIME,     
   @cDropID       NVARCHAR( 20), 
   @nErrNo        INT           OUTPUT,   
   @cErrMsg       NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max   
)  
AS  
BEGIN  
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
     
   DECLARE @nTranCount INT,  
   @cNewLot            NVARCHAR( 10),
   @cLOT               NVARCHAR( 10),
   @cNewID             NVARCHAR( 18),
   @cNewPickDetailKey  NVARCHAR( 10),
   @cPickDetailKey     NVARCHAR( 10),
   @nNewQTY            INT,
   @nLLI_QTY           INT,
   @nPD_QTY            INT,
   @nLotQty            INT,
   @b_success          INT,
   @n_err              INT,
   @c_errmsg           NVARCHAR( 250),
   @cNewPDetailKey     NVARCHAR( 10),
   @cOrderKey          NVARCHAR( 10),
   @cOrderLineNumber   NVARCHAR( 5),
   @cLoadKey           NVARCHAR( 10), 
   @cGetPickDetailKey  NVARCHAR( 10), 
   @cGetLOT            NVARCHAR( 10),
   @cGetLOC            NVARCHAR( 10),
   @cGetID             NVARCHAR( 18), 
   @cSwapLot           NVARCHAR( 10),
   @cSwapPickSlipNo    NVARCHAR( 10),
   @nSwapQty           INT, 
   @cGetPickSlipNo     NVARCHAR( 10), 
   @cTargetPickDetKey  NVARCHAR( 10),
   @cTargetLot         NVARCHAR( 10), 
   @cTargetID          NVARCHAR( 18),
   @nTargetQty         INT, 
   @cSwapPickDetKey    NVARCHAR( 10),
   @nQtyToTake         INT


   -- TraceInfo
   DECLARE    @c_starttime    datetime,
              @c_endtime      datetime,
              @c_step1        datetime,
              @c_step2        datetime,
              @c_step3        datetime,
              @c_step4        datetime,
              @c_step5        datetime, 
              @c_Col5         NVARCHAR(20)

   SET @c_starttime = GETDATE()   
   SET @c_Col5 = Convert(varchar(20), @nQTY) 

/*
swap
1. look thru pd in the pickslip scanned initially 
   if got same sku + loc + qty + status < '3'
      just swap the LOT + ID

*/
   SET @nTranCount = @@TRANCOUNT  


   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_Pick_SwapLot -- For rollback or commit only our own transaction  

   SELECT TOP 1 @cLOT = LOT 
   FROM dbo.LotxLocxID LLI WITH (NOLOCK)
   WHERE LOC = @cLOC
   AND   ID  = @cID 
   AND   StorerKey = @cStorerKey
   AND   SKU = @cSKU 
   AND   QTY > 0

   SET @c_step1 = GETDATE()

   DECLARE @t_PickDetail  
      TABLE (PickDetailKey NVARCHAR(10), 
             LOT           NVARCHAR(10),
             LOC           NVARCHAR(10),
             ID            NVARCHAR(18),
             Qty           int, 
             PickSlipNo    NVARCHAR(10), 
             Section       NVARCHAR(1))

   -- Insert all the exact matched pickdetail into temp table
   -- Retrieve all the pickdetail records that have same lot, loc & id 
   INSERT INTO @t_PickDetail 
   (PickDetailKey, LOT, LOC, ID, Qty, PickSlipNo, Section)
   SELECT PickDetailKey, LOT, LOC, ID, Qty, PickSlipNo, 'I' 
   FROM  dbo.PickDetail PD WITH (NOLOCK) 
   WHERE PD.StorerKey = @cStorerKey
     AND PD.SKU = @cSKU  
     AND PD.ID  = @cID  
     AND PD.LOC = @cLOC  
     AND PD.LOT = @cLOT -- SHONG001
     AND PD.PickSlipNo = @cPickSlipNo
     AND PD.Status < '3'  

   DECLARE PickCursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT PickDetailKey, Qty
      FROM   @t_PickDetail 
      
   OPEN PickCursor
   
   FETCH NEXT FROM PickCursor INTO @cPickDetailKey, @nPD_Qty 
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- If Picked Qty less then the qty allocated 
      IF @nPD_Qty <= @nQty 
      BEGIN
         UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
            Status = '3', 
            DropID = @cDropID, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66101
            SET @cErrMsg = rdt.rdtgetmessage( 66101, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END
         
         SET @nQty = @nQty - @nPD_Qty
      END
      ELSE
      BEGIN 
         -- if Qty Allocated > Picked Qty, need to split the pickdetail into 2 records
         -- one for the picked qty another for qty allocated
         -- Create new pickdetail line with allocated qty 
         EXECUTE dbo.nspg_GetKey
            'PICKDETAILKEY', 
            10 ,
            @cNewPDetailKey OUTPUT,
            @b_success         OUTPUT,
            @n_err             OUTPUT,
            @c_errmsg          OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 66102
            SET @cErrMsg = rdt.rdtgetmessage( 66102, @cLangCode, 'DSP') -- 'GetDetKey Fail'
            GOTO RollBackTran
         END

         -- Create new a PickDetail to hold the balance
         INSERT INTO dbo.PICKDETAIL (
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, 
            QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, 
            DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
            ShipFlag, PickSlipNo, PickDetailKey, QTY, TrafficCop, OptimizeCop, AddWho)
         SELECT 
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, 
            QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 'SwpLotAdd', ToLoc, 
            DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
            ShipFlag, PickSlipNo, @cNewPDetailKey, @nPD_QTY - @nQty, NULL, '1', SUSER_SNAME()
         FROM dbo.PickDetail WITH (NOLOCK) 
		      WHERE PickDetailKey = @cPickDetailKey
			   
         IF @@ERROR <> 0
         BEGIN
			   SET @nErrNo = 66103
            SET @cErrMsg = rdt.rdtgetmessage( 66103, @cLangCode, 'DSP') --'Ins PDtl Fail'
            GOTO RollBackTran
         END

         IF EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo) 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickdetailkey = @cNewPDetailKey)  
            BEGIN
               SELECT @cOrderKey = OrderKey, @cOrderLineNumber = OrderLineNumber 
              FROM dbo.PickDetail WITH (NOLOCK) 
	               WHERE PickDetailKey = @cPickDetailKey

               SELECT @cLoadKey = ExternOrderKey
               FROM dbo.PickHeader WITH (NOLOCK) 
	               WHERE PickHeaderKey = @cPickSlipNo

               INSERT INTO dbo.RefkeyLookup (Pickdetailkey, Pickslipno, Orderkey, OrderLineNumber, Loadkey)  
               VALUES (@cNewPDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)  

               IF @@ERROR <> 0
               BEGIN
		            SET @nErrNo = 66104
                  SET @cErrMsg = rdt.rdtgetmessage( 66104, @cLangCode, 'DSP') --'InsRefKLupFail'
                  GOTO RollBackTran
               END
            END
         END
         
         -- update the picked qty and status
         UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
            Status = '3',
            Qty = @nQty, 
            DropID = @cDropID, 
            CartonType = 'SwpLotUpd', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey     
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66105
            SET @cErrMsg = rdt.rdtgetmessage( 66105, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END     
         
         SET @nQty = 0
         BREAK                
      END

      FETCH NEXT FROM PickCursor INTO @cPickDetailKey, @nPD_Qty 
   END
   CLOSE PickCursor
   DEALLOCATE PickCursor
   
   SET @c_step1 = GETDATE() - @c_step1 

   -- if the exact match qty >= entered pick qty then no process needed
   IF @nQTY = 0  
      GOTO Quit

   SET @c_step2 = GETDATE()

   -- If Can't find the pickdetail with same ID and LOT. Looks for the available LOT's qty 
   -- and used that to swap with the pickdetail belong to this pick slip.
   WHILE @nQTY > 0 
   BEGIN 
      -- Lookup candidate
      SET @cNewLOT = ''
      SET @nLLI_QTY = 0 
      SELECT @cNewLOT  = LLI.LOT, 
             @nLLI_QTY = LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked  
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      WHERE LLI.LOT = @cLOT
        AND LLI.LOC = @cLOC      
        AND LLI.ID  = @cID
        AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0

      IF ISNULL(@cNewLOT, '') <> '' 
      BEGIN
         WHILE @nLLI_QTY >= 0
         BEGIN
            SET @cPickDetailKey = ''

            -- Searching PickDetail with same lottables with different pallet id
            SELECT TOP 1 
                   @cPickDetailKey = PD.PickDetailKey, 
                   @nPD_QTY = PD.QTY 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT AND PD.SKU = LA.SKU)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.LOC = @cLOC
               AND PD.ID  <> @cID            
               AND PD.Status < '3'
               AND PD.Qty > 0 
               AND LA.Lottable01 = CASE WHEN ISNULL(@cLottable01, '') = '' THEN LA.Lottable01 ELSE @cLottable01 END
               AND LA.Lottable02 = CASE WHEN ISNULL(@cLottable02, '') = '' THEN LA.Lottable02 ELSE @cLottable02 END
               AND LA.Lottable03 = CASE WHEN ISNULL(@cLottable03, '') = '' THEN LA.Lottable03 ELSE @cLottable03 END
               -- AND LA.Lottable04 = CASE WHEN ISNULL(@dLottable04, '') = '' THEN LA.Lottable04 ELSE @dLottable04 END
               AND IsNULL( LA.Lottable04, 0) = IsNULL( @dLottable04, 0)

            IF ISNULL(RTRIM(@cPickDetailKey), '') = ''
               GOTO SWAP_ALLOCATE
            
            SET @nQtyToTake = @nLLI_QTY
            
            IF @nQty < @nQtyToTake
               SET @nQtyToTake = @nQty
               
            IF @nPD_QTY < @nQtyToTake
               SET @nQtyToTake = @nPD_QTY
      
            -- If PickDetail Qty > Available Qty    
            IF @nPD_QTY > @nQtyToTake
            BEGIN 
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY', 
                  10 ,
                  @cNewPDetailKey OUTPUT,
                  @b_success         OUTPUT,
                  @n_err             OUTPUT,
                  @c_errmsg          OUTPUT
               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 66106
                  SET @cErrMsg = rdt.rdtgetmessage( 66106, @cLangCode, 'DSP') -- 'GetDetKey Fail'
                  GOTO RollBackTran
               END

               -- Create new a PickDetail to hold the balance
               INSERT INTO dbo.PICKDETAIL (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, 
                  QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, 
                  DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
                  ShipFlag, PickSlipNo, PickDetailKey, QTY, TrafficCop, OptimizeCop, AddWho)
               SELECT 
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, 
                  QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 'SwpLotAdd', ToLoc, 
                  DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
                  ShipFlag, PickSlipNo, @cNewPDetailKey, @nPD_QTY - @nQtyToTake, NULL, '1', SUSER_SNAME()
               FROM dbo.PickDetail WITH (NOLOCK) 
			      WHERE PickDetailKey = @cPickDetailKey
      			   
               IF @@ERROR <> 0
               BEGIN
				      SET @nErrNo = 66107
                  SET @cErrMsg = rdt.rdtgetmessage( 66107, @cLangCode, 'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
               END

               IF EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo) 
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickdetailkey = @cNewPDetailKey)  
                  BEGIN
                     SELECT @cOrderKey = OrderKey, @cOrderLineNumber = OrderLineNumber 
                     FROM dbo.PickDetail WITH (NOLOCK) 
   			            WHERE PickDetailKey = @cPickDetailKey
      
                     SELECT @cLoadKey = ExternOrderKey
                     FROM dbo.PickHeader WITH (NOLOCK) 
   			            WHERE PickHeaderKey = @cPickSlipNo

                     INSERT INTO dbo.RefkeyLookup (Pickdetailkey, Pickslipno, Orderkey, OrderLineNumber, Loadkey)  
                     VALUES (@cNewPDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)  

                     IF @@ERROR <> 0
                     BEGIN
   				         SET @nErrNo = 66108
                        SET @cErrMsg = rdt.rdtgetmessage( 66108, @cLangCode, 'DSP') --'InsRefKLupFail'
                        GOTO RollBackTran
                     END
                  END
               END

               -- Change orginal PickDetail QTY
               UPDATE dbo.PickDetail WITH (ROWLOCK)   
                  SET QTY = @nQtyToTake, TrafficCop = NULL, CartonType = 'SwpLotUpd'  
                      , EditDate=GetDate(), EditWho=sUser_sName()    
               WHERE PickDetailKey = @cPickDetailKey  
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66109
                  SET @cErrMsg = rdt.rdtgetmessage( 66109, @cLangCode, 'DSP') --'UpdPickDtlFail'
                  GOTO RollBackTran
               END
            END

            UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
               ID = @cID, 
               LOT = @cLOT, 
               Status = '3', 
               DropID = @cDropID,
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66110
               SET @cErrMsg = rdt.rdtgetmessage( 66110, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO RollBackTran
            END
   
            INSERT INTO @t_PickDetail 
               (PickDetailKey, LOT, LOC, ID, Qty, PickSlipNo, Section)
            VALUES (@cPickDetailKey, @cLOT, @cLOC, @cID, @nPD_QTY, @cPickSlipNo, 'A')

            SET @nQTY     = @nQTY - @nQtyToTake
            SET @nLLI_QTY = @nLLI_QTY - @nQtyToTake

            IF @nQTY <= 0 OR @nLLI_QTY <= 0
            BEGIN
               BREAK
            END
         END -- While @nLLI_QTY >= 0
      END -- Cursor Loop 1 
      --ELSE
      --BEGIN
         -- Not Available LOT, Stop here
      --   BREAK
      --END 


      SWAP_ALLOCATE:

      IF @nQTY <= 0
         GOTO Quit

      SET @c_step2 = GETDATE() - @c_step2

      SET @c_step3 = GETDATE()
      
   -- If still got balance left to swap, look for other pickdetail with different pickslip#
      WHILE 1=1
      BEGIN
         SET @cTargetPickDetKey = ''
         
         SELECT TOP 1 
                @cTargetPickDetKey = PD.PickDetailKey, 
                @cTargetLot = PD.LOT, 
                @nTargetQty = PD.QTY, 
                @cTargetID  = PD.ID
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU 
            AND PD.LOC = @cLOC
            AND PD.Status < '3'

         IF ISNULL(RTRIM(@cTargetPickDetKey), '') = ''
         BEGIN
            
            IF @nQty > 0 
            BEGIN
               SET @nErrNo = 66111
               SET @cErrMsg = rdt.rdtgetmessage( 66111, @cLangCode, 'DSP') --'No Rec Found'
               GOTO Quit
            END
         END 
         
         SET @cSwapPickDetKey = ''         
         SELECT TOP 1 
                @cSwapPickDetKey = PD.PickDetailKey, 
                @cSwapLot = PD.LOT, 
                @nSwapQty = PD.QTY, 
                @cSwapPickSlipNo  = PD.PickSlipNo 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.LOC = @cLOC
            AND PD.ID  = @cID            
            AND PD.Status < '3'
            AND PD.Qty > 0 
            -- AND PD.PickSlipNo <> @cPickSlipNo
            AND LA.Lottable01 = CASE WHEN ISNULL(@cLottable01, '') = '' THEN LA.Lottable01 ELSE @cLottable01 END
            AND LA.Lottable02 = CASE WHEN ISNULL(@cLottable02, '') = '' THEN LA.Lottable02 ELSE @cLottable02 END
            AND LA.Lottable03 = CASE WHEN ISNULL(@cLottable03, '') = '' THEN LA.Lottable03 ELSE @cLottable03 END
            -- AND LA.Lottable04 = CASE WHEN ISNULL(@dLottable04, '') = '' THEN LA.Lottable04 ELSE @dLottable04 END
            AND IsNULL( LA.Lottable04, 0) = IsNULL( @dLottable04, 0)

         IF ISNULL(RTRIM(@cSwapPickDetKey), '') = ''
         BEGIN

            IF @nQty > 0 
            BEGIN
               SET @nErrNo = 66112
               SET @cErrMsg = rdt.rdtgetmessage( 66112, @cLangCode, 'DSP') --'Swap Fail'
               GOTO Quit
            END
         END 

         -- If Swap Qty = Remaining Qty    
         SET @nQtyToTake = @nQty 
         

         IF @nSwapQty < @nQtyToTake
            SET @nQtyToTake = @nSwapQty
         
         IF @nTargetQty < @nQtyToTake
            SET @nQtyToTake = @nTargetQty

         IF @nTargetQty > @nQtyToTake
         BEGIN
            -- Split PickDetail Line 
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY', 
               10,
               @cNewPDetailKey OUTPUT,
               @b_success         OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 66113
               SET @cErrMsg = rdt.rdtgetmessage( 66113, @cLangCode, 'DSP') --'GetDetKey Fail'
               GOTO RollBackTran
            END            

            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PICKDETAIL (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, 
               QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, 
               DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
               ShipFlag, PickSlipNo, PickDetailKey, QTY, TrafficCop, OptimizeCop, AddWho)
            SELECT 
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, 
               QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 'SwpLotAdd', ToLoc, 
               DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
               ShipFlag, PickSlipNo, @cNewPDetailKey, QTY - @nQtyToTake, NULL, '1', SUSER_SNAME()
            FROM dbo.PickDetail WITH (NOLOCK) 
		      WHERE PickDetailKey = @cTargetPickDetKey
			   
            IF @@ERROR <> 0
            BEGIN
			      SET @nErrNo = 66114
               SET @cErrMsg = rdt.rdtgetmessage( 66114, @cLangCode, 'DSP') --'Ins PDtl Fail'
               GOTO RollBackTran
            END

            IF EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo) 
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickdetailkey = @cNewPDetailKey)  
               BEGIN
                  SELECT @cOrderKey = OrderKey, @cOrderLineNumber = OrderLineNumber 
                  FROM dbo.PickDetail WITH (NOLOCK) 
			            WHERE PickDetailKey = @cTargetPickDetKey
   
                  SELECT @cLoadKey = ExternOrderKey
                  FROM dbo.PickHeader WITH (NOLOCK) 
			            WHERE PickHeaderKey = @cPickSlipNo

                  INSERT INTO dbo.RefkeyLookup (Pickdetailkey, Pickslipno, Orderkey, OrderLineNumber, Loadkey)  
                  VALUES (@cNewPDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)  

                  IF @@ERROR <> 0
                  BEGIN
				         SET @nErrNo = 66115
                     SET @cErrMsg = rdt.rdtgetmessage( 66115, @cLangCode, 'DSP') --'InsRefKLupFail'
                     GOTO RollBackTran
                  END
               END
            END

            -- Change target PickDetail with exact QTY 
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               QTY = @nQtyToTake, TrafficCop = NULL, CartonType = 'SwpLotUpd', 
               EditDate=GETDATE(), EditWho=SUSER_SNAME()
            WHERE PickDetailKey = @cTargetPickDetKey
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66116
               SET @cErrMsg = rdt.rdtgetmessage( 66116, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO RollBackTran
            END
            
         END -- IF @nTargetQty > @nQtyToTake
--         ELSE --(james02)
         IF @nSwapQty > @nQtyToTake
         BEGIN
            -- Split the Swap pick detail line 
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY', 
               10,
               @cNewPDetailKey OUTPUT,
               @b_success         OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 66117
               SET @cErrMsg = rdt.rdtgetmessage( 66117, @cLangCode, 'DSP') -- 'GetDetKey Fail'
               GOTO RollBackTran
            END

            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PICKDETAIL (
             CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, 
               QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, 
               DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
               ShipFlag, PickSlipNo, PickDetailKey, QTY, TrafficCop, OptimizeCop, AddWho)
            SELECT 
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, 
               QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 'SwpLotAdd', ToLoc, 
               DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
               ShipFlag, PickSlipNo, @cNewPDetailKey, Qty - @nQtyToTake, NULL, '1', SUSER_SNAME()
            FROM dbo.PickDetail WITH (NOLOCK) 
		         WHERE PickDetailKey = @cSwapPickDetKey
   			   
            IF @@ERROR <> 0
            BEGIN
			      SET @nErrNo = 66118
               SET @cErrMsg = rdt.rdtgetmessage( 66118, @cLangCode, 'DSP') --'Ins PDtl Fail'
               GOTO RollBackTran
            END

            IF EXISTS (SELECT TOP 1 RK.PickSlipNo  
                       FROM dbo.RefKeyLookup RK WITH (NOLOCK) 
          		        WHERE RK.PickSlipNo = @cSwapPickSlipNo) 
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickdetailkey = @cNewPDetailKey)  
               BEGIN
                  SELECT @cOrderKey = OrderKey, 
                         @cOrderLineNumber = OrderLineNumber
                  FROM dbo.PickDetail WITH (NOLOCK) 
			            WHERE PickDetailKey = @cSwapPickDetKey
   
                 SELECT @cLoadKey = ExternOrderKey
                 FROM dbo.PickHeader WITH (NOLOCK) 
			        WHERE PickHeaderKey = @cSwapPickSlipNo

                  INSERT INTO dbo.RefkeyLookup (Pickdetailkey, Pickslipno, Orderkey, OrderLineNumber, Loadkey)  
                  VALUES (@cNewPDetailKey, @cSwapPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)  

                  IF @@ERROR <> 0
                  BEGIN
				         SET @nErrNo = 66119
                     SET @cErrMsg = rdt.rdtgetmessage( 66119, @cLangCode, 'DSP') --'InsRefKLupFail'
                     GOTO RollBackTran
                  END
               END
            END
            -- Change target PickDetail with exact QTY 
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               QTY = @nQtyToTake, TrafficCop = NULL, CartonType = 'SwpLotUpd', 
               EditDate=GETDATE(), EditWho=SUSER_SNAME()
            WHERE PickDetailKey = @cSwapPickDetKey
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66120
               SET @cErrMsg = rdt.rdtgetmessage( 66120, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO RollBackTran
            END            
         END -- IF @nSwapQty > @nQtyToTake
               
         -- Change the original pickdetail qty 
         UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
            LOT = @cSwapLot, 
            ID = @cID, 
            Status = '3', 
            DropID = @cDropID, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cTargetPickDetKey 

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66121
            SET @cErrMsg = rdt.rdtgetmessage( 66121, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END


         INSERT INTO @t_PickDetail 
            (PickDetailKey, LOT, LOC, ID, Qty, PickSlipNo, Section)
         VALUES (@cTargetPickDetKey, @cSwapLot, @cLOC, @cID, @nQTYToTake, @cPickSlipNo, 'S')

         -- Change the target pickdetail qty
         UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET
            LOT = @cTargetLOT, ID = @cTargetID, TrafficCop=NULL, 
            EditDate=GETDATE(), EditWho=SUSER_SNAME() 
         WHERE PickDetailKey = @cSwapPickDetKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66123
            SET @cErrMsg = rdt.rdtgetmessage( 66123, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END

         SET @nQTY = @nQTY - @nQtyToTake

         IF @nQTY <= 0
         BEGIN
            BREAK
         END
      END -- While 1=1
   END -- @nQTY > 0

   SET @c_step3 = GETDATE() - @c_step3 

--GOTO RollBackTran
   GOTO QUIT
  
RollBackTran:  
   If CURSOR_STATUS('LOCAL','CUR_LLI') IN (0 , 1) 
   BEGIN
      CLOSE CUR_LLI
      DEALLOCATE CUR_LLI
   END

   ROLLBACK TRAN rdt_Pick_SwapLot  
Fail:  
Quit:  
   SET @c_endtime = GETDATE()

   INSERT INTO TraceInfo 
     ([TraceName]     ,[TimeIn]     ,[TimeOut]
     ,[TotalTime]     ,[Step1]      ,[Step2]
     ,[Step3]         ,[Step4]      ,[Step5]
     ,[Col1]          ,[Col2]       ,[Col3]
     ,[Col4]          ,[Col5])

   VALUES
      ('rdt_Pick_SwapLot PickSlip No = ' + @cPickSlipNo 
        , @c_starttime, @c_endtime 
      ,CONVERT(CHAR(12),@c_endtime-@c_starttime ,114) 
      ,ISNULL(CONVERT(CHAR(12),@c_step1,114), '00:00:00:000') 
      ,ISNULL(CONVERT(CHAR(12),@c_step2,114), '00:00:00:000')  
      ,ISNULL(CONVERT(CHAR(12),@c_step3,114), '00:00:00:000')  
      ,ISNULL(CONVERT(CHAR(12),@c_step4,114), '00:00:00:000')  
      ,ISNULL(CONVERT(CHAR(12),@c_step5,114), '00:00:00:000')
      , @cSKU
      , @cLOT 
      , @cLOC 
      , @cID
      , @c_Col5)

   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END 

GO