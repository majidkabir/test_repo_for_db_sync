SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VAP_Palletize_Confirm                           */
/* Purpose: VAP Palletize module, insert pallet detail from             */
/*          workorder_uncasing table.                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-12-04 1.0  James      SOS315942. Created                        */
/* 2016-01-27 1.1  James      Add insert PalletLabel (james01)          */
/************************************************************************/

CREATE PROC [RDT].[rdt_VAP_Palletize_Confirm] (
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @nInputKey        INT, 
   @cLangCode        NVARCHAR( 3),  
   @cStorerkey       NVARCHAR( 15), 
   @cToID            NVARCHAR( 18),
   @cJobKey          NVARCHAR( 10),
   @cWorkOrderKey    NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @cLottable01      NVARCHAR( 18), 
   @cLottable02      NVARCHAR( 18), 
   @cLottable03      NVARCHAR( 18), 
   @dLottable04      DATETIME, 
   @dLottable05      DATETIME, 
   @cLottable06      NVARCHAR( 30), 
   @cLottable07      NVARCHAR( 40), 
   @cLottable08      NVARCHAR( 50), 
   @cLottable09      NVARCHAR( 60), 
   @cLottable10      NVARCHAR( 30), 
   @cLottable11      NVARCHAR( 30), 
   @cLottable12      NVARCHAR( 30), 
   @dLottable13      DATETIME, 
   @dLottable14      DATETIME, 
   @dLottable15      DATETIME, 
   @nQtyToComplete   INT, 
   @cPrintLabel      NVARCHAR( 10), 
   @cEndPallet       NVARCHAR( 10), 
   @dStartDate       DATETIME, 
   @cType            NVARCHAR( 1),          
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cUserName            NVARCHAR( 18), 
           @cWorkOrderUdf01      NVARCHAR( 18),
           @cWorkStation         NVARCHAR( 20),
           @cFacility            NVARCHAR( 5),
           @cJobLine             NVARCHAR( 5),
           @cLot                 NVARCHAR( 10),
           @cLoc                 NVARCHAR( 10),
           @cID                  NVARCHAR( 10),
           @cPackKey             NVARCHAR( 10),
           @cPackUOM3            NVARCHAR( 10),
           @cPackUOM1            NVARCHAR( 10),
           @cOutLoc              NVARCHAR( 10),
           @cReportType          NVARCHAR( 10),
           @cPrintJobName        NVARCHAR( 50),
           @cDataWindow          NVARCHAR( 50),
           @cTargetDB            NVARCHAR( 20),
           @cLabelPrinter        NVARCHAR( 10),
           @cPrev_SKU            NVARCHAR( 20),
           @cOutputUOM           NVARCHAR( 10),
           @cPopPalletLabel      NVARCHAR( 30),
           @cSSCC                NVARCHAR( 20),
           @nPUOM_Div            INT,
           @nStartTCnt           INT,
           @nRowRef              INT,
           @nPalletizeQty        INT,
           @nID_Qty              INT,
           @nQty                 INT,
           @bSuccess             INT,
           @nQty2Withdraw        INT,
           @nQty2Deposit         INT,
           @nQtyRemaining        INT,
           @nInputBOMQty         INT,
           @nOutputBOMQty        INT,
           @nBOMQty              INT,
           @nTtl_Uncased         INT,
           @dToday               DATETIME

   DECLARE @cErrMsg1            NVARCHAR( 20),
           @cErrMsg2            NVARCHAR( 20),
           @cErrMsg3            NVARCHAR( 20),
           @cErrMsg4            NVARCHAR( 20),
           @cErrMsg5            NVARCHAR( 20), 
           @cPrimarySKU         NVARCHAR( 20), 
           @cLottable01Rules    NVARCHAR( 20), 
           @cLottable02Rules    NVARCHAR( 20), 
           @cLottable03Rules    NVARCHAR( 20), 
           @cLottable04Rules    NVARCHAR( 20), 
           @cLottable05Rules    NVARCHAR( 20), 
           @cLottable06Rules    NVARCHAR( 20), 
           @cLottable07Rules    NVARCHAR( 20), 
           @cLottable08Rules    NVARCHAR( 20), 
           @cLottable09Rules    NVARCHAR( 20), 
           @cLottable10Rules    NVARCHAR( 20), 
           @cLottable11Rules    NVARCHAR( 20), 
           @cLottable12Rules    NVARCHAR( 20), 
           @cLottable13Rules    NVARCHAR( 20), 
           @cLottable14Rules    NVARCHAR( 20), 
           @cLottable15Rules    NVARCHAR( 20) 

   SELECT @cUserName = UserName, 
          @cFacility = Facility 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE MOBILE = @nMobile

   SET @nStartTCnt = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_VAP_Palletize_Confirm  
   
   SET @nErrNo = 0

   -- Insert palletize detail here
   IF @cType = 'I'
   BEGIN
      -- Populate lottable values from input primary sku based on setup
      SELECT @cLottable01Rules = Lottable01Rules, 
             @cLottable02Rules = Lottable02Rules, 
             @cLottable03Rules = Lottable03Rules, 
             @cLottable04Rules = Lottable04Rules, 
             @cLottable05Rules = Lottable05Rules, 
             @cLottable06Rules = Lottable06Rules, 
             @cLottable07Rules = Lottable07Rules, 
             @cLottable08Rules = Lottable08Rules, 
             @cLottable09Rules = Lottable09Rules, 
             @cLottable10Rules = Lottable10Rules, 
             @cLottable11Rules = Lottable11Rules, 
             @cLottable12Rules = Lottable12Rules, 
             @cLottable13Rules = Lottable13Rules, 
             @cLottable14Rules = Lottable14Rules, 
             @cLottable15Rules = Lottable15Rules, 
             @cPrimarySKU = PrimarySKU, 
             @cPackKey = PackKey, 
             @cOutputUOM = UOM
      FROM dbo.WorkOrderRequestOutputs WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderKey

      SELECT TOP 1 @cLOT = LOT
      FROM dbo.WorkOrder_UnCasing U WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( U.SKU = SKU.SKU AND U.StorerKey = SKU.StorerKey)
      WHERE U.JobKey = @cJobKey
      AND   U.WorkOrderKey = @cWorkOrderKey
      AND   U.Status = '3'
      AND   ISNULL( Qty - QtyCompleted, 0) > 0
      AND   SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = CASE WHEN ISNULL( @cPrimarySKU, '') = '' THEN SKU.SKU ELSE @cPrimarySKU END
      AND   SKU.BUSR3 = 'DGE-GEN'

      SELECT @cLottable01 = CASE WHEN ISNULL( @cLottable01Rules, '') <> '' THEN Lottable01 ELSE '' END, 
             @cLottable02 = CASE WHEN ISNULL( @cLottable02Rules, '') <> '' THEN Lottable02 ELSE '' END, 
             @cLottable03 = CASE WHEN ISNULL( @cLottable03Rules, '') <> '' THEN Lottable03 ELSE '' END, 
             @dLottable04 = CASE WHEN ISNULL( @cLottable04Rules, '') <> '' THEN Lottable04 ELSE '' END, 
             @dLottable05 = CASE WHEN ISNULL( @cLottable05Rules, '') <> '' THEN Lottable05 ELSE '' END, 
             @cLottable06 = CASE WHEN ISNULL( @cLottable06Rules, '') <> '' THEN Lottable06 ELSE '' END, 
             @cLottable07 = CASE WHEN ISNULL( @cLottable07Rules, '') <> '' THEN Lottable07 ELSE '' END, 
             @cLottable08 = CASE WHEN ISNULL( @cLottable08Rules, '') <> '' THEN Lottable08 ELSE '' END, 
             @cLottable09 = CASE WHEN ISNULL( @cLottable09Rules, '') <> '' THEN Lottable09 ELSE '' END, 
             @cLottable10 = CASE WHEN ISNULL( @cLottable10Rules, '') <> '' THEN Lottable10 ELSE '' END, 
             @cLottable11 = CASE WHEN ISNULL( @cLottable11Rules, '') <> '' THEN Lottable11 ELSE '' END, 
             @cLottable12 = CASE WHEN ISNULL( @cLottable12Rules, '') <> '' THEN Lottable12 ELSE '' END, 
             @dLottable13 = CASE WHEN ISNULL( @cLottable13Rules, '') <> '' THEN Lottable13 ELSE '' END, 
             @dLottable14 = CASE WHEN ISNULL( @cLottable14Rules, '') <> '' THEN Lottable14 ELSE '' END, 
             @dLottable15 = CASE WHEN ISNULL( @cLottable15Rules, '') <> '' THEN Lottable15 ELSE '' END 
      FROM dbo.LotAttribute WITH (NOLOCK)
      WHERE LOT = @cLOT

      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
                        WHERE ID = @cToID
                        AND   JobKey = @cJobKey
                        AND   WorkOrderKey = @cWorkOrderKey
                        AND   [Status] = '3')
      BEGIN
         SELECT TOP 1 @cWorkStation = WorkStation
         FROM dbo.WorkOrder_UnCasing WITH (NOLOCK)
         WHERE JobKey = @cJobKey
         AND   WorkOrderKey = @cWorkOrderKey
         AND   [Status] = '3'

         SET @dStartDate = GETDATE()

         INSERT INTO dbo.WorkOrder_Palletize (
            WorkStation, JobKey, WorkOrderKey, StorerKey, SKU, PackKey, UOM,
            Qty, QtyCompleted, QtyRemaining, ID, SSCC, InLOC, OutLoc, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, 
            Status, StartDate, EndDate, AddDate, EditDate, AddWho, EditWho, LabelPrinted)  
         VALUES (
            @cWorkStation, @cJobKey, @cWorkOrderKey, @cStorerKey, @cSKU, @cPackKey, @cOutputUOM,
            @nQtyToComplete, 0, 0, @cToID, '', '', '',
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            '3', GETDATE(), NULL, GETDATE(), GETDATE(), @cUserName, @cUserName, 'N')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 58901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins plt fail'
            GOTO RollbackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.WorkOrder_Palletize WITH (ROWLOCK) SET 
            Qty = Qty + @nQtyToComplete,
            EditWho = @cUserName, 
            EditDate = GETDATE()
         WHERE ID = @cToID
         AND   JobKey = @cJobKey
         AND   WorkOrderKey = @cWorkOrderKey
         AND   [Status] = '3'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 58902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Upd plt fail'
            GOTO RollbackTran
         END
      END
   END

   -- End palletize here
   IF @cType = 'E'
   BEGIN
      SELECT @nPalletizeQty = Qty
      FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
      WHERE ID = @cToID
      AND   JobKey = @cJobKey
      AND   WorkOrderKey = @cWorkOrderKey
      AND   [Status] = '3'

      -- Get the output bom qty
      SELECT @nOutputBOMQty = WOO.Qty
      FROM dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK) 
      JOIN WorkOrderOutputs WOO WITH (NOLOCK) ON ( WRO.WkOrdOutputskey = WOO.WkOrdOutputskey)
      WHERE WRO.WorkOrderKey = @cWorkOrderKey
      /*
      -- Check each sku uncased is enough to fullfill the qty to palletize
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT SKU 
      FROM dbo.WorkOrderRequestInputs WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderKey
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cSKU
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Get the input bom qty
         SELECT @nInputBOMQty = WOI.Qty
         FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
         JOIN WorkOrderInputs WOI WITH (NOLOCK) 
            ON ( WRI.WkOrdInputskey = WOI.WkOrdInputskey AND WRI.SKU = WOI.SKU)
         WHERE WRI.WorkOrderKey = @cWorkOrderKey
         AND   WRI.SKU = @cSKU

         SET @nBOMQty = @nInputBOMQty / @nOutputBOMQty

         IF @nBOMQty <= 0
            SET @nBOMQty = 1

         SELECT @nTtl_Uncased = ISNULL( SUM( QtyRemaining), 0)
         FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
         WHERE JobKey = @cJobKey
         AND   WorkOrderKey = @cWorkOrderKey
         AND   [Status] = '3'
         AND   SKU = @cSKU

         IF ( @nTtl_Uncased / @nBOMQty) < @nPalletizeQty
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58903 THE QTY'
            SET @cErrMsg2 = 'UNCASED NOT ENOUGH'
            SET @cErrMsg3 = 'TO DO PALLETIZING.'
            SET @cErrMsg4 = 'SKU:'
            SET @cErrMsg5 = @cSKU
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END

            SET @nErrNo = 58903
            GOTO RollbackTran
         END

         FETCH NEXT FROM CUR_LOOP INTO @cSKU
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
      */

      EXEC rdt.rdt_1153GenSSCC01
         @nMobile       = @nMobile,         
         @nFunc         = @nFunc,           
         @nStep         = @nStep,           
         @nInputKey     = @nInputKey,       
         @cLangCode     = @cLangCode,        
         @cStorerkey    = @cStorerkey,       
         @cToID         = @cToID,           
         @cJobKey       = @cJobKey,         
         @cWorkOrderKey = @cWorkOrderKey,   
         @cSKU          = @cSKU,            
         @cLottable01   = @cLottable01,      
         @cLottable02   = @cLottable02,      
         @cLottable03   = @cLottable03,      
         @dLottable04   = @dLottable04,     
         @dLottable05   = @dLottable05,     
         @cLottable06   = @cLottable06,      
         @cLottable07   = @cLottable07,      
         @cLottable08   = @cLottable08,      
         @cLottable09   = @cLottable09,      
         @cLottable10   = @cLottable10,      
         @cLottable11   = @cLottable11,      
         @cLottable12   = @cLottable12,      
         @dLottable13   = @dLottable13,     
         @dLottable14   = @dLottable14,     
         @dLottable15   = @dLottable15,     
         @cSSCC         = @cSSCC           OUTPUT,
         @nErrNo        = @nErrNo          OUTPUT, 
         @cErrMsg       = @cErrMsg         OUTPUT  

      SET @cLottable03 = @cSSCC

      SELECT @cOutputUOM = UOM,
             @cPackKey = PackKey
      FROM dbo.WorkOrderRequestOutputs WITH (NOLOCK)
      WHERE WorkOrderKey = @cWorkOrderKey
      
      SELECT @nPUOM_Div = CAST( IsNULL( CASE
            WHEN PACKUOM1 = @cOutputUOM THEN CaseCNT 
            WHEN PACKUOM2 = @cOutputUOM THEN InnerPack 
            WHEN PACKUOM3 = @cOutputUOM THEN QTY 
            WHEN PACKUOM4 = @cOutputUOM THEN Pallet 
            WHEN PACKUOM8 = @cOutputUOM THEN OtherUnit1 
            WHEN PACKUOM9 = @cOutputUOM THEN OtherUnit2
            ELSE 0 END, 1) AS INT) 
      FROM dbo.Pack WITH (NOLOCK) 
      WHERE PackKey = @cPackKey 

      UPDATE dbo.WorkOrder_Palletize WITH (ROWLOCK) SET 
         Lottable01 = @cLottable01,
         Lottable02 = @cLottable02,
         Lottable03 = @cLottable03,
         Lottable04 = @dLottable04,
         Lottable07 = @cLottable07,
         Lottable08 = @cLottable08
      WHERE ID = @cToID
      AND   JobKey = @cJobKey
      AND   WorkOrderKey = @cWorkOrderKey
      AND   [Status] = '3'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58914
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'End pallet fail'  
         GOTO RollbackTran
      END

      SELECT @cJobLine = SUBSTRING( SourceKey, 11, 5), 
             @cWorkStation  = WorkStation
      FROM dbo.TaskDetail TD WITH (NOLOCK) 
      INNER JOIN dbo.WorkOrderJOB WJ WITH (NOLOCK) ON LEFT(RTRIM(TD.SOURCEKEY),10) = WJ.JobKey
      INNER JOIN dbo.WorkOrderJobDetail WJD WITH (NOLOCK) ON WJD.JobKey = WJ.JobKey 
      WHERE TD.TaskType = 'FG'
      AND   TD.Status NOT IN ('0', '9')
      AND   WJ.Facility = @cFacility
      AND   WJ.JobKey = @cJobKey
      AND   WJ.WorkOrderKey = @cWorkOrderKey

      -- update workorderjoboperation
      UPDATE dbo.WorkOrderJobOperation WITH (ROWLOCK) SET 
         QtyCompleted = QtyCompleted + @nPalletizeQty
      WHERE JobKey = @cJobKey
      AND   JobLine = @cJobLine
      AND   JobStatus < '9'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58906
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd wjops fail'  
         GOTO RollbackTran
      END
      
      -- update workorderjob
      UPDATE dbo.WorkOrderJob WITH (ROWLOCK) SET 
         QtyCompleted = QtyCompleted + @nPalletizeQty
      WHERE JobKey = @cJobKey
      AND   WorkOrderKey = @cWorkOrderKey
      AND   JobStatus < '9'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd wojob fail'  
         GOTO RollbackTran
      END
 
      -- update workorderjobdetail
      UPDATE dbo.WorkOrderJobDetail WITH (ROWLOCK) SET 
         QtyCompleted = QtyCompleted + @nPalletizeQty,
         JobStatus = CASE WHEN ( QtyCompleted + @nPalletizeQty) = QtyJob THEN '9' ELSE JobStatus END, 
         TrafficCop = NULL
      WHERE JobKey = @cJobKey
      AND   JobStatus < '9'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58904
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd jobdt fail'  
         GOTO RollbackTran
      END

      -- update workorderinputs
      UPDATE dbo.WorkOrderRequestInputs WITH (ROWLOCK) SET 
         QtyCompleted = QtyCompleted + @nPalletizeQty
      WHERE WorkOrderKey = @cWorkOrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58912
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd wori fail'  
         GOTO RollbackTran
      END

      -- update workorderoutputs
      UPDATE dbo.WorkOrderRequestOutputs WITH (ROWLOCK) SET 
         QtyCompleted = QtyCompleted + @nPalletizeQty
      WHERE WorkOrderKey = @cWorkOrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58912
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd woro fail'  
         GOTO RollbackTran
      END

      -- update workorderjoboperation
      UPDATE dbo.WorkOrderRequest WITH (ROWLOCK) SET 
         QtyCompleted = QtyCompleted + @nPalletizeQty,
         WOSTATUS = CASE WHEN ( QtyCompleted + @nPalletizeQty) = Qty THEN '9' ELSE WOSTATUS END, 
         TrafficCop = NULL
      WHERE WorkOrderKey = @cWorkOrderKey
      AND   WOSTATUS < '9'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58907
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd wjr fail'  
         GOTO RollbackTran
      END
      
      SET @cPrev_SKU = ''

      -- withdraw stock
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT SKU 
      FROM dbo.WorkOrderRequestInputs WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderKey
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cSKU
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --SET @nQty2Withdraw = @nPalletizeQty

         -- Get the input bom qty
         SELECT @nInputBOMQty = WOI.Qty
         FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
         JOIN WorkOrderInputs WOI WITH (NOLOCK) 
            ON ( WRI.WkOrdInputskey = WOI.WkOrdInputskey AND WRI.SKU = WOI.SKU)
         WHERE WRI.WorkOrderKey = @cWorkOrderKey
         AND   WRI.SKU = @cSKU

         IF @nInputBOMQty = 1
            SET @nBOMQty = 1
         ELSE 
            SET @nBOMQty = @nInputBOMQty / @nOutputBOMQty

         -- Convert to BOM Qty
         SET @nQty2Withdraw = ( @nInputBOMQty * @nPalletizeQty) / @nOutputBOMQty

         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT RowRef, Lot, OutLoc, ID, QtyRemaining
         FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
         WHERE JobKey = @cJobKey
         AND   WorkOrderKey = @cWorkOrderKey
         AND   [Status] = '3'
         AND   SKU = @cSKU
         AND   QtyRemaining > 0
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @nRowRef, @cLot, @cLoc, @cID, @nQtyRemaining
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @nID_Qty = 0
            SET @nQty = 0

            SELECT @nID_Qty = ISNULL( SUM( QTY - QTYPicked), 0)
            FROM dbo.LotxLocxID WITH (NOLOCK)
            WHERE Lot = @cLot
            AND   Loc = @cLoc
            AND   ID = @cID
            
            -- Check if the inventory enough to do withdraw stock
            -- Need multiply the qty with the BomQty to get the actual qty needed
            IF @nID_Qty <= 0 OR ( @nID_Qty < @nQtyRemaining)
            BEGIN
               SET @nErrNo = 58908
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv bal x enuf'  
               GOTO RollbackTran
            END

            -- Convert to BOM Qty
            --SET @nQty2Withdraw = @nQty2Withdraw * @nBOMQty

            IF @nQty2Withdraw > @nQtyRemaining
               SET @nQty = @nQtyRemaining 
            ELSE
               SET @nQty = @nQty2Withdraw 
               --if @@spid = 130
               --select '@cSKU', @cSKU, '@nQty', @nQty, '@nQty2Withdraw', @nQty2Withdraw, '@nBOMQty', @nBOMQty, '@nQtyRemaining', @nQtyRemaining, 
               --'@nInputBOMQty', @nInputBOMQty, '@nOutputBOMQty', @nOutputBOMQty
            IF @nQty > 0 
            BEGIN
               SELECT @cSKU = SKU,
                  @cLottable01 = Lottable01,
                  @cLottable02 = Lottable02,
                  @cLottable03 = Lottable03,
                  @dLottable04 = Lottable04,
                  @dLottable05 = Lottable05,
                  @cLottable06 = Lottable06,
                  @cLottable07 = Lottable07,
                  @cLottable08 = Lottable08,
                  @cLottable09 = Lottable09,
                  @cLottable10 = Lottable10,
                  @cLottable11 = Lottable11,
                  @cLottable12 = Lottable12,
                  @dLottable13 = Lottable13,
                  @dLottable14 = Lottable14,
                  @dLottable15 = Lottable15 
               FROM dbo.LotAttribute WITH (NOLOCK) 
               WHERE Lot = @cLot

               SELECT @cPackKey = P.PackKey,
                      @cPackUOM3 = P.PackUOM3
               FROM dbo.Pack P WITH (NOLOCK) 
               JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
               WHERE S.SKU = @cSKU
               AND   S.StorerKey = @cStorerKey

               SET @dToday = GETDATE()

               EXECUTE nspItrnAddWithdrawal
                  NULL,
                  @cStorerKey,
                  @cSKU,
                  @cLot,
                  @cLoc,
                  @cID,
                  'OK',
                  @cLottable01,
                  @cLottable02,
                  @cLottable03,
                  @dLottable04,
                  @dLottable05,
                  @cLottable06,
                  @cLottable07,
                  @cLottable08,
                  @cLottable09,
                  @cLottable10,
                  @cLottable11,
                  @cLottable12,
                  @dLottable13,
                  @dLottable14,
                  @dLottable15,
                  0,
                  0,
                  @nQty,
                  0,
                  0,
                  0,
                  0,
                  0,
                  0,
                  @nRowRef,     
                  'rdt_VAP_Palletize_Confirm',    
                  @cPackKey,
                  @cPackUOM3,
                  0,
                  @dToday,
                  '',
                  @bSuccess OUTPUT,
                  0,
                  ''

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 58909
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Withdraw fail'  
                  GOTO RollbackTran
               END

               -- Reduce the bal qty
               SET @nQty2Withdraw = @nQty2Withdraw - @nQty

               UPDATE dbo.WorkOrder_UnCasing WITH (ROWLOCK) SET 
                  QtyRemaining = QtyRemaining - @nQty,
                  QtyCompleted = QtyCompleted + @nQty,
                  EditWho = @cUserName,
                  EditDate = GETDATE()
               WHERE RowRef = @nRowRef

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 58915
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Withdraw fail'  
                  GOTO RollbackTran
               END
            END

            IF @nQty2Withdraw <= 0
               BREAK

            FETCH NEXT FROM CUR_UPD INTO @nRowRef, @cLot, @cLoc, @cID, @nQtyRemaining
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD

         FETCH NEXT FROM CUR_LOOP INTO @cSKU
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      IF ISNULL( @cWorkStation, '') = ''
         SELECT TOP 1 @cWorkStation = WorkStation
         FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
         WHERE JobKey = @cJobKey
         AND   WorkOrderKey = @cWorkOrderKey

      SET @cOutLoc = ''
      SELECT @cOutLoc = Location 
      FROM dbo.WorkStationLoc WITH (NOLOCK) 
      WHERE LocType = 'OutLOC'
      AND WorkStation = @cWorkStation

      IF ISNULL( @cOutLoc, '') = ''
         SELECT @cOutLoc = OutLoc
         FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
         WHERE JobKey = @cJobKey

      -- deposit stock
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT SKU
      FROM dbo.WorkOrderRequestOutputs WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderKey
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cSKU
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @nQty2Deposit = @nPalletizeQty

         IF ISNULL( @cOutLoc, '') <> '' AND @nQty2Deposit > 0
         BEGIN

            SELECT @nRowRef = RowRef,
               @cLottable01 = Lottable01,
               @cLottable02 = Lottable02,
               @cLottable03 = Lottable03,
               @dLottable04 = Lottable04,
               @dLottable05 = Lottable05,
               @cLottable06 = Lottable06,
               @cLottable07 = Lottable07,
               @cLottable08 = Lottable08,
               @cLottable09 = Lottable09,
               @cLottable10 = Lottable10,
               @cLottable11 = Lottable11,
               @cLottable12 = Lottable12,
               @dLottable13 = Lottable13,
               @dLottable14 = Lottable14,
               @dLottable15 = Lottable15 
            FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
            WHERE ID = @cToID
            AND   StorerKey = @cStorerKey
            AND   [Status] = '3'
            AND   JobKey = @cJobKey
            AND   WorkOrderKey = @cWorkOrderKey

            SELECT @cPackKey = P.PackKey,
                     @cPackUOM3 = P.PackUOM3
            FROM dbo.Pack P WITH (NOLOCK) 
            JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
            WHERE S.SKU = @cSKU
            AND   S.StorerKey = @cStorerKey

            SET @dToday = GETDATE()

            SELECT @bSuccess = 1
            EXECUTE nspItrnAddDeposit
               NULL,
               @cStorerKey,
               @cSKU,
               '',
               @cOutLoc,
               @cToID,
               'OK',
               @cLottable01,
               @cLottable02,
               @cLottable03,
               @dLottable04,
               @dLottable05,
               @cLottable06,
               @cLottable07,
               @cLottable08,
               @cLottable09,
               @cLottable10,
               @cLottable11,
               @cLottable12,
               @dLottable13,
               @dLottable14,
               @dLottable15,
               0,
               0,
               @nQty2Deposit,
               0,
               0,
               0,
               0,
               0,
               0,
               @nRowRef,     
               'rdt_VAP_Palletize_Confirm',    
               @cPackKey,
               @cPackUOM3,
               0,   
               @dToday,
               '',  
               @bSuccess OUTPUT,
               0,
               ''

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 58910
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Deposit fail'  
               GOTO RollbackTran
            END

            SET @nQty2Deposit = 0
         END

         IF @nQty2Deposit = 0
            BREAK

         FETCH NEXT FROM CUR_LOOP INTO @cSKU
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
      /*
      -- After full FG output qty has been finalized, need to add a record into PalletLabel table 
      -- to activate Label Applicator to print pallet label. If record with status æ0Æ already exist, 
      -- skip record insertion (james01)
      SELECT @bSuccess = 0
      Execute nspGetRight null,
         @cStorerKey,
         '',
         'PopulatePalletLabel',
         @bSuccess              OUTPUT,
         @cPopPalletLabel       OUTPUT,
         @nErrNo                OUTPUT,
         @cErrMsg               OUTPUT
         
      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 58916
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getconfig fail'  
         GOTO RollbackTran
      END
      ELSE IF @cPopPalletLabel = '1'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PalletLabel WITH (NOLOCK) 
                        WHERE ID = @cToID 
                        AND   [Status] IN ('X', '0', '9'))
         BEGIN
            --Insert the required pallet label data for later putaway and print processing.
            INSERT INTO dbo.PalletLabel (ID, Tablename, HDKey, DTKey, 
                                    Parm1, Parm2, Parm3, Parm4, Parm5, 
                                    Parm6, Parm7, Parm8, Parm9, Parm10) 
            VALUES (@cToID, 'JOBORDER', @cJobKey, @cJobLine, 
                                    '','','','','',  
                                    '','','','','')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 58917
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins pltlbl err'  
               GOTO RollbackTran
            END
         END
      END
      */
      UPDATE dbo.WorkOrder_Palletize WITH (ROWLOCK) SET 
         QtyCompleted = Qty,
         [Status] = '9',
         EditWho = @cUserName,
         EditDate = GETDATE()
      WHERE ID = @cToID
      AND   JobKey = @cJobKey
      AND   WorkOrderKey = @cWorkOrderKey
      AND   [Status] = '3'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58911
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'End plt fail'  
         GOTO RollbackTran
      END
   END

   IF ISNULL( @cPrintLabel, '') = 'Y'
   BEGIN
      SET @cReportType = 'FGPLTLABEL'
      SET @cPrintJobName = 'PRINT_FG_PALLETLABEL'
   
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
               @cTargetDB = ISNULL(RTRIM(TargetDB), '')
      FROM RDT.RDTReport WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReportType = @cReportType
   
      SET @nErrNo = 0
      EXEC RDT.rdt_BuiltPrintJob
         @nMobile,
         @cStorerKey,
         @cReportType,
         @cPrintJobName,
         @cDataWindow,
         @cLabelPrinter,
         @cTargetDB,
         @cLangCode,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @cWorkOrderKey,
         @cToID
   
      IF @nErrNo <> 0
         GOTO RollBackTran                  
   END

   GOTO Quit

   RollbackTran:
      ROLLBACK TRAN rdt_VAP_Palletize_Confirm  
  
   Quit:
   WHILE @@TRANCOUNT > @nStartTCnt -- Commit until the level we started  
      COMMIT TRAN rdt_VAP_Palletize_Confirm  
--            insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5, step1, step2) values 
--            ('vap', getdate(), @cLot, @cLoc, @cID, @nID_Qty, @nQtyRemaining, @cSKU, @nRowRef)

GO