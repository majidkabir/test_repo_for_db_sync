SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PostPackAudit_EndScan                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: normal receipt                                              */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2006-01-19 1.0  UngDH    Created                                     */
/* 2007-02-28 1.1  jwong    SOS67554 link CSAudit to PickDetail table   */
/* 2007-03-19 1.2  UngDH    Performance tuning                          */
/* 2007-03-20 1.3  UngDH    SOS58012 add storer config                  */
/*                          'PPP/PPA_NotCheck_A_B_Variance'             */
/* 2008-01-18 1.4  UngDH    SOS93437  PickDetail splitted incorrect     */
/* 2009-06-03 1.5  MaryVong SOS139575                                   */
/*                          1) Add Batch to narrow down the range of    */
/*                             data retrieval                           */
/*                          2) Filter by Order Type - Tote Only         */
/* 2009-08-19 1.6  Leong    SOS# 145425 - Fix GroupId = 0 when Same Tote*/
/*                          or Pallet with multiple batch Id.           */
/* 2009-09-03 1.7  James    Bug Fix. When perform endscan thru          */
/*                          correction module, no need to filter        */
/*                          CSAudit status to get the correct GroupID   */
/*                          (james01)                                   */
/* 2010-09-02 1.7  TLTING   Insert into RefKeyLookup for newly added    */      
/*                            Pickdetail Record.                        */      
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_PostPackAudit_EndScan] (
   @nFunc         INT, 
   @cStorerKey    NVARCHAR( 18), 
   @cConsigneeKey NVARCHAR( 18), 
   @cType         NVARCHAR( 1),  -- P=Pallet, C=Case
   @cID           NVARCHAR( 18), -- Pallet ID / Case ID
   @cWorkstation  NVARCHAR( 15), 
   @cRefNo1       NVARCHAR( 20), 
   @cRefNo2       NVARCHAR( 20), 
   @cRefNo3       NVARCHAR( 20), 
   @cRefNo4       NVARCHAR( 20), 
   @cRefNo5       NVARCHAR( 20), 
   @nErrNo        INT OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max
   @cLangCode     NVARCHAR( 18),
   @cSKU          NVARCHAR( 20) = NULL -- Tote correction, reclose only 1 SKU
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @nCount      INT,
      @cStatus     NVARCHAR( 1),
      @nDiff       INT,
      @nMinRowRef  INT,
      @nTranCount  INT,
                        
      @nRowRef     INT,
      @cCaseID     NVARCHAR( 18),
      @cDropID     NVARCHAR( 18),
      @nQTY        INT,
     
      @cCA_SKU     NVARCHAR( 20),
      @nCA_QTY     INT,
      @nCA_Bal     INT,  -- Balance
      @nCA_RowRef  INT,
     
      @cPD_SKU     NVARCHAR( 20),
      @cPD_QTY     INT,
      @nPD_Bal     INT,  -- Balance
     
      @cPickDetailKey   NVARCHAR( 18),
      @cOrderKey        NVARCHAR( 10),
      @cOrderLineNumber NVARCHAR( 5)   
   
   -- SOS139575
   DECLARE 
      @nBatchID      INT,
      @cBatch        NVARCHAR( 15),
      @cPalletID     NVARCHAR( 18),
      @cPrevPalletID NVARCHAR( 18),
      @cCA_CaseID    NVARCHAR( 18),
      @cCA_Consignee NVARCHAR( 18),
      @cSKU_C        NVARCHAR( 20), -- For Order Type 'C' - Cross Dock
      @cSKU_S        NVARCHAR( 20) -- For Order Type 'S' - Storage/Indent

   SET @nErrNo = 0
   SET @nTranCount = @@TRANCOUNT

   SET @cCaseID       = ''
   SET @cPalletID     = ''
   SET @cPrevPalletID = ''
   SET @cDropID       = ''
   SET @nQTY          = 0
   SET @nBatchID      = 0
   SET @cBatch        = ''
   SET @cSKU_C        = ''
   SET @cSKU_S        = ''
   SET @cCA_CaseID    = ''
   SET @cCA_Consignee = ''

   -- Validate parameter
   IF (@cType <> 'P' AND @cType <> 'C')
   BEGIN
      SET @nErrNo = 60810
      SET @cErrMsg = rdt.rdtgetmessage( 60810, @cLangCode, 'DSP') --'Invalid type'
      GOTO Fail
   END

   /*-------------------------------------------------------------------------------

                                     PALLET SECTION 

   -------------------------------------------------------------------------------*/
   IF @cType = 'P'
   BEGIN
      SELECT 
         @nCount = COUNT( DISTINCT PalletID), 
         @cStatus = MIN( Status)
      FROM rdt.rdtCSAudit (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND Workstation = @cWorkstation
         AND PalletID = @cID

      -- Validate pallet ID
      IF @nCount = 0
      BEGIN
         SET @nErrNo = 60811
         SET @cErrMsg = rdt.rdtgetmessage( 60811, @cLangCode, 'DSP') --'Invalid pallet ID'
         GOTO Fail
      END

      -- Validate open pallet
      IF @cStatus <> '0'
      BEGIN
         SET @nErrNo = 60812
         SET @cErrMsg = rdt.rdtgetmessage( 60812, @cLangCode, 'DSP') --'No open pallet'
         GOTO Fail
      END

      -- Check if 1 or 2 scanners configuration
      IF rdt.RDTGetConfig( 0, 'PPP/PPA_NotCheck_A_B_Variance', @cStorerKey) <> '1'  -- 1=Not checking
      BEGIN
         -- Validate result of scanner A and scanner B (for all cases belong to that pallet)
         IF EXISTS( SELECT 1 FROM rdt.rdtCSAudit (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND Workstation = @cWorkstation
               AND PalletID = @cID
               AND CountQTY_A <> CountQTY_B
               AND Status = '0')
         BEGIN
            SET @nErrNo = 60813
            SET @cErrMsg = rdt.rdtgetmessage( 60813, @cLangCode, 'DSP') --'Differences found'
            GOTO Fail
         END
      END

      -- SOS139575
      -- Get Unique Batch
      SELECT TOP 1 
         @nBatchID = A.BatchID
      FROM rdt.rdtCSAudit A WITH (NOLOCK) 
      INNER JOIN rdt.rdtCSAudit_Batch B WITH (NOLOCK)
         ON (A.StorerKey = B.StorerKey AND A.BatchID = B.BatchID)
      WHERE A.StorerKey = @cStorerKey
         AND A.Workstation = @cWorkstation
         AND A.PalletID = @cID
         AND ISNULL(RTRIM(B.CloseWho),'') = ''-- SOS# 145425
         
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PostPackAudit_EndScan -- For rollback or commit only our own transaction
     
      -- Get CSAudit
      DECLARE curPallet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT RowRef, PalletID, CaseID, CountQTY_B
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Workstation = @cWorkstation
            --AND PalletID = @cID
            AND PalletID <> ''
            AND BatchID = @nBatchID
            AND Status = '0' -- Open
         ORDER BY RowRef

      -- Loop CSAudit
      --SET @nMinRowRef = NULL
      OPEN curPallet
      FETCH NEXT FROM curPallet INTO @nRowRef, @cPalletID, @cCaseID, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get GroupID
         --IF @nMinRowRef IS NULL
         --   SET @nMinRowRef = @nRowRef
         IF @cPalletID <> @cPrevPalletID
            SET @nMinRowRef = @nRowRef

         -- Close pallet
         UPDATE rdt.rdtCSAudit SET
            GroupID = @nMinRowRef, 
            OriginalQTY = @nQTY, 
            Status = '5' -- Close
         WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60814
            SET @cErrMsg = rdt.rdtgetmessage( 60814, @cLangCode, 'DSP') --'Close pallet fail'
            GOTO RollbackTran
         END

         -- Insert to load
         INSERT INTO RDT.rdtCSAudit_Load (GroupID, StorerKey, Vehicle, ConsigneeKey, CaseID, Status, Seal, RefNo1, RefNo2, RefNo3, RefNo4, RefNo5)
         SELECT GroupID, StorerKey, '', ConsigneeKey, CaseID, '0', '', '', '', '', '', ''
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60808
            SET @cErrMsg = rdt.rdtgetmessage( 60808, @cLangCode, 'DSP') --'Insert CSAudit_Load fail'
            GOTO RollbackTran
         END
         
         -- SOS67554 link CSAudit to PickDetail table
         -- Update PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @nRowRef, 
            TrafficCop = NULL 
         WHERE StorerKey = @cStorerKey
            AND CaseID = @cCaseID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60806
            SET @cErrMsg = rdt.rdtgetmessage( 60806, @cLangCode, 'DSP') --'UPD PKDtl fail'
            GOTO RollbackTran
         END
         
         -- Assign pallet id 
         SET @cPrevPalletID = @cPalletID
         
         FETCH NEXT FROM curPallet INTO @nRowRef, @cPalletID, @cCaseID, @nQTY
      END
      CLOSE curPallet
      DEALLOCATE curPallet

      COMMIT TRAN rdtfnc_PostPackAudit_EndScan -- Only commit change made in here

   END -- IF @cType = 'P'

   /*-------------------------------------------------------------------------------

                                     CASE SECTION 

   -------------------------------------------------------------------------------*/
   IF @cType = 'C'
   BEGIN
      SELECT 
         @nCount = COUNT( DISTINCT CaseID), 
         @cStatus = MIN( Status)
      FROM rdt.rdtCSAudit (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND Workstation = @cWorkstation
         AND PalletID = ''
         AND CaseID = @cID

      -- Validate case ID
      IF @nCount = 0
      BEGIN
         SET @nErrNo = 60815
         SET @cErrMsg = rdt.rdtgetmessage( 60815, @cLangCode, 'DSP') --'Invalid case ID'
         GOTO Fail
      END

      -- Validate open case
      IF @cStatus <> '0'
      BEGIN
         SET @nErrNo = 60816
         SET @cErrMsg = rdt.rdtgetmessage( 60816, @cLangCode, 'DSP') --'No open case'
         GOTO Fail
      END

      -- Check if 1 or 2 scanners configuration
      IF rdt.RDTGetConfig( 0, 'PPP/PPA_NotCheck_A_B_Variance', @cStorerKey) <> '1' -- 1=Not checking
      BEGIN
         -- Validate result of scanner A and scanner B (for all cases belong to that pallet)
         IF EXISTS( SELECT 1 FROM rdt.rdtCSAudit (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND Workstation = @cWorkstation
               AND PalletID = ''
               AND CaseID = @cID
               AND RefNo1 = @cRefNo1
               AND RefNo2 = @cRefNo2
               AND RefNo3 = @cRefNo3
               AND RefNo4 = @cRefNo4
               AND RefNo5 = @cRefNo5
               AND CountQTY_A <> CountQTY_B
               AND Status = '0' )
         BEGIN
            SET @nErrNo = 60813
            SET @cErrMsg = rdt.rdtgetmessage( 60817, @cLangCode, 'DSP') --'Differences found'
            GOTO Fail
         END
      END

      -- SOS139575
      -- Get Unique Batch
      SELECT TOP 1 
         @nBatchID = A.BatchID,
         @cBatch   = B.Batch
      FROM rdt.rdtCSAudit A WITH (NOLOCK) 
      INNER JOIN rdt.rdtCSAudit_Batch B WITH (NOLOCK)
         ON (A.StorerKey = B.StorerKey AND A.BatchID = B.BatchID)
      WHERE A.StorerKey = @cStorerKey
         AND A.Workstation = @cWorkstation
         AND A.PalletID = ''
         AND A.CaseID = @cID
         AND ISNULL(RTRIM(B.CloseWho),'') = ''-- SOS# 145425
         
      /* Update PickDetail
         Stamp case ID on PickDetail.CaseID. The purpose is to link CSAudit back to PickDetail, 
         to compare and produce a differential report

         Note:
         - Concurrency issue. It is possible multiple end scan runs at the same time. For e.g.:
           2 case belong to same store, close by different workstation at the same time
         - Do not use dynamic cursor as the underlying PickDetail record might get changed
         - Didnt use static cursor on PickDetail directly coz it uses tempdb (hdd)
           Use static cursor on PickDetail table variable instead (memory)
      */

      -- SKU in CSAudit
      DECLARE @tCA TABLE
      (
         SKU              NVARCHAR( 20) NOT NULL, 
         QTY              INT       NOT NULL DEFAULT (0),
         RowRef           INT       NOT NULL    --added by James on 14 Feb 07 SOS67554
      )

      -- PickDetail candidate
      DECLARE @tPD TABLE
      (
         RowID            INT       NOT NULL IDENTITY( 1, 1), -- SOS139575
         PickDetailKey    NVARCHAR( 18) NOT NULL, 
         OrderKey         NVARCHAR( 10) NOT NULL, 
         OrderLineNumber  NVARCHAR( 5)  NOT NULL, 
         SKU              NVARCHAR( 20) NOT NULL, 
         QTY              INT       NOT NULL DEFAULT (0)
      )
      
      -- Final result use to update PickDetail in one go
      DECLARE @tFinal TABLE
      (
         [ID]             INT NOT NULL IDENTITY( 1, 1), 
         PickDetailKey    NVARCHAR( 18) NULL, 
         RefPickDetailKey NVARCHAR( 18) NULL, -- for reference back to original PickDetail line. Use for split line
         OrderKey         NVARCHAR( 10) NOT NULL, 
         OrderLineNumber  NVARCHAR( 5)  NOT NULL, 
         CaseID           NVARCHAR( 10) NOT NULL, 
         SKU              NVARCHAR( 20) NOT NULL, 
         QTY              INT       NOT NULL DEFAULT (0),
         DropID           NVARCHAR( 18) NOT NULL    --added by James on 14 Feb 07 SOS67554
      )      

      DECLARE @curCaseID CURSOR
      SET @curCaseID = CURSOR FOR
         SELECT DISTINCT CaseID, ConsigneeKey
         FROM rdt.rdtCSAudit WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Workstation = @cWorkstation
            AND PalletID = ''
            AND BatchID = @nBatchID
            AND Status = '0'
         ORDER BY CaseID
         
      OPEN @curCaseID
      FETCH NEXT FROM @curCaseID INTO @cCA_CaseID, @cCA_Consignee
      WHILE @@FETCH_STATUS = 0
      BEGIN
         /******************************************************/
         /* Loop by CaseID (Tote#) - Start                     */
         /******************************************************/
         -- Get GroupID
         SELECT @nMinRowRef = MIN( RowRef)
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Workstation = @cWorkstation
            AND PalletID = ''
            AND CaseID = @cCA_CaseID
            AND BatchID = @nBatchID
--            AND Status = '0'  (james01)
            AND Status = CASE WHEN ISNULL(@cSKU, '') = '' THEN '0'
                        ELSE Status END
         
         -- Get CSAudit
         INSERT INTO @tCA (SKU, QTY, RowRef)
         SELECT SKU, CountQTY_B, RowRef
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Workstation = @cWorkstation
            AND PalletID = ''
            AND CaseID = @cCA_CaseID
            AND BatchID = @nBatchID
            AND Status = '0'
         ORDER BY SKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60818
            SET @cErrMsg = rdt.rdtgetmessage( 60818, @cLangCode, 'DSP') --'Get CSAudit fail'
            GOTO Fail
         END
   
         ---- Get PickDetail candidate to offset
         ---- Note: Do not remove join from OrderDetail table. Do that will force SQL perform
         ----       a clustered index SCAN (not SEEK. Scan whole index) to get PD.SKU, causing huge I/O
         --INSERT INTO @tPD (PickDetailKey, OrderKey, OrderLineNumber, SKU, QTY)
         --SELECT PD.PickDetailKey, OD.OrderKey, OD.OrderLineNumber, OD.SKU, PD.QTY
         --FROM dbo.Orders O (NOLOCK) 
         --   INNER JOIN dbo.OrderDetail OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)
         --   INNER JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
         --   --   INNER JOIN @tCA tCA ON (OD.SKU = tCA.SKU)
         --WHERE O.StorerKey = @cStorerKey
         --   AND O.ConsigneeKey = @cConsigneeKey
         --   AND O.Status < '9'
         --   AND PD.Status = 5 -- picked
         --   AND PD.UOM = 6 -- piece only
         --   -- Blank   case ID = created from XDOCK allocation
         --   -- Numeric case ID = created by user in show pick tab
         --   AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1) 
         --   AND OD.SKU IN (SELECT SKU FROM @tCA)
         --ORDER BY OD.SKU, OD.OrderKey, PD.QTY
   
         -- SOS139575 - Start
         /******************************************************************************************    
           Get PickDetail candidate to offset
           Note: 
           1) Do not remove join from OrderDetail table. Do that will force SQL perform
              a clustered index SCAN (not SEEK. Scan whole index) to get PD.SKU, causing huge I/O
           2) Offset PickDetail by Order Type 'S'(Storage/Indent), follow by 'C'(Cross Dock)      
         *******************************************************************************************/
         -- Order Type = 'S'
         DECLARE @curSKU_S CURSOR
         SET @curSKU_S = CURSOR FOR
            SELECT DISTINCT SKU FROM @tCA
            ORDER BY SKU
         OPEN @curSKU_S
         FETCH NEXT FROM @curSKU_S INTO @cSKU_S
         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT INTO @tPD (PickDetailKey, OrderKey, OrderLineNumber, SKU, QTY)
            SELECT PD.PickDetailKey, OD.OrderKey, OD.OrderLineNumber, OD.SKU, PD.QTY
            FROM dbo.Orders O (NOLOCK) 
               INNER JOIN dbo.OrderDetail OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)
               INNER JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
            WHERE O.StorerKey = @cStorerKey
               AND O.ConsigneeKey = @cCA_Consignee
               AND O.Status < '9'
               AND O.Type = 'S'
               AND PD.Status = '5' -- picked
               AND PD.UOM = '6' -- piece only
               -- Blank   case ID = created from XDOCK allocation
               -- Numeric case ID = created by user in show pick tab
               AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1) 
               AND OD.LoadKey = @cBatch
               AND OD.SKU = @cSKU_S
            ORDER BY OD.OrderKey, PD.QTY
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 60819
               SET @cErrMsg = rdt.rdtgetmessage( 60819, @cLangCode, 'DSP') --'Get PickDetail fail'
               GOTO Fail
            END
            FETCH NEXT FROM @curSKU_S INTO @cSKU_S
         END
         CLOSE @curSKU_S
         DEALLOCATE @curSKU_S
         
         -- Order Type = 'C'
         DECLARE @curSKU_C CURSOR
         SET @curSKU_C = CURSOR FOR
            SELECT DISTINCT SKU FROM @tCA
            ORDER BY SKU
         OPEN @curSKU_C
         FETCH NEXT FROM @curSKU_C INTO @cSKU_C
         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT INTO @tPD (PickDetailKey, OrderKey, OrderLineNumber, SKU, QTY)
            SELECT PD.PickDetailKey, OD.OrderKey, OD.OrderLineNumber, OD.SKU, PD.QTY
            FROM dbo.Orders O (NOLOCK) 
               INNER JOIN rdt.RDTCSAudit_BatchPO BPO WITH (NOLOCK) ON (BPO.OrderKey = O.OrderKey)         
               INNER JOIN dbo.OrderDetail OD (NOLOCK) ON (O.OrderKey = OD.OrderKey AND OD.Lottable03 = BPO.PO_No)
               INNER JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
            WHERE O.StorerKey = @cStorerKey
               AND O.ConsigneeKey = @cCA_Consignee
               AND O.Status < '9'
               AND O.Type = 'C'
               AND PD.Status = '5' -- picked
               AND PD.UOM = '6' -- piece only
               -- Blank   case ID = created from XDOCK allocation
               -- Numeric case ID = created by user in show pick tab
               AND (PD.CaseID = '' OR IsNumeric( PD.CaseID) = 1) 
               AND BPO.Batch = @cBatch
               AND OD.SKU = @cSKU_C
            ORDER BY OD.OrderKey, PD.QTY
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 67051
               SET @cErrMsg = rdt.rdtgetmessage( 67051, @cLangCode, 'DSP') --'Get PickDetail fail'
               GOTO Fail
            END
            FETCH NEXT FROM @curSKU_C INTO @cSKU_C
         END
         CLOSE @curSKU_C
         DEALLOCATE @curSKU_C
         
         -- SOS139575 - End
   
         SET @cCA_SKU     = ''
         SET @nCA_QTY     = 0
         SET @nCA_Bal     = 0 -- Balance
         SET @nCA_RowRef  = 0

         SET @cPD_SKU     = ''
         SET @cPD_QTY     = 0
         SET @nPD_Bal     = 0 -- Balance

         SET @cPickDetailKey   = ''
         SET @cOrderKey        = ''
         SET @cOrderLineNumber = ''
  
         -- Prepare cursor
         DECLARE @curCA CURSOR
         DECLARE @curPD CURSOR
         SET @curCA = CURSOR FOR
            SELECT SKU, QTY, RowRef
            FROM @tCA
            ORDER BY SKU -- SOS139575
         SET @curPD = CURSOR SCROLL DYNAMIC FOR 
            SELECT PickDetailKey, OrderKey, OrderLineNumber, SKU, QTY 
            FROM @tPD
            -- SKU comes first, follow by Order Type 'S', then 'C'
            ORDER BY SKU, RowID 
         OPEN @curCA
         OPEN @curPD
   
         -- Loop CSAudit
         FETCH NEXT FROM @curCA INTO @cCA_SKU, @nCA_QTY, @nCA_RowRef
         SET @nCA_Bal = @nCA_QTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Loop PickDetail to offset
            FETCH FIRST FROM @curPD INTO @cPickDetailKey, @cOrderKey, @cOrderLineNumber, @cPD_SKU, @cPD_QTY
            SET @nPD_Bal = @cPD_QTY
            WHILE @@FETCH_STATUS = 0
            BEGIN  
               IF @cCA_SKU = @cPD_SKU
               BEGIN
                  -- Exact match
                  IF @nCA_Bal = @nPD_Bal
                  BEGIN
                     INSERT INTO @tFinal (PickDetailKey, RefPickDetailKey, OrderKey, OrderLineNumber, CaseID, SKU, QTY, DropID)
                     VALUES (@cPickDetailKey, '', @cOrderKey, @cOrderLineNumber, @cCA_CaseID, @cPD_SKU, @nPD_Bal, @nCA_RowRef)
   
                     DELETE @tPD WHERE PickDetailKey = @cPickDetailKey
                     SET @nCA_Bal = 0
                     BREAK  -- Loop CSAudit again
                  END
   
                  -- Over match
                  ELSE IF @nCA_Bal > @nPD_Bal
                  BEGIN
                     INSERT INTO @tFinal (PickDetailKey, RefPickDetailKey, OrderKey, OrderLineNumber, CaseID, SKU, QTY, DropID)
                     VALUES (@cPickDetailKey, '', @cOrderKey, @cOrderLineNumber, @cCA_CaseID, @cPD_SKU, @nPD_Bal, @nCA_RowRef)
   
                     DELETE @tPD WHERE PickDetailKey = @cPickDetailKey
                     SET @nCA_Bal = @nCA_Bal - @nPD_Bal  -- Reduce CSAudit balance, get next PD to offset
                  END
   
                  -- Under match
                  ELSE IF @nCA_Bal < @nPD_Bal
                  BEGIN
                     INSERT INTO @tFinal (PickDetailKey, RefPickDetailKey, OrderKey, OrderLineNumber, CaseID, SKU, QTY, DropID)
                     VALUES (@cPickDetailKey, '', @cOrderKey, @cOrderLineNumber, @cCA_CaseID, @cPD_SKU, @nCA_Bal, @nCA_RowRef)
                                          
                     -- Split PickDetail line
                     -- Note: CaseID is blank so that it can be offset by others
                     INSERT INTO @tFinal (PickDetailKey, RefPickDetailKey, OrderKey, OrderLineNumber, CaseID, SKU, QTY, DropID)
                     VALUES ('', @cPickDetailKey, @cOrderKey, @cOrderLineNumber, '', @cPD_SKU, (@nPD_Bal - @nCA_Bal), '')
    
                     -- Reduce PD balance
                     UPDATE @tPD SET 
                        QTY = @nPD_Bal - @nCA_Bal
                     WHERE PickDetailKey = @cPickDetailKey
                     
                     SET @nCA_Bal = 0
                     BREAK  -- Loop CSAudit again
                  END
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cOrderKey, @cOrderLineNumber, @cPD_SKU, @cPD_QTY
               SET @nPD_Bal = @cPD_QTY
            END  -- Loop PickDetail
   
            -- CSAudit still have balance, means no PickDetail to offset
            IF @nCA_Bal <> 0
            BEGIN
               SET @nErrNo = 60820
               SET @cErrMsg = rdt.rdtgetmessage( 60820, @cLangCode, 'DSP') --'No PickDetail to offset'
               CLOSE @curCA
               CLOSE @curPD
               DEALLOCATE @curCA
               DEALLOCATE @curPD
               GOTO Fail
            END
   
            FETCH NEXT FROM @curCA INTO @cCA_SKU, @nCA_QTY, @nCA_RowRef
            SET @nCA_Bal = @nCA_QTY
         END
   
         CLOSE @curCA
         CLOSE @curPD
         DEALLOCATE @curCA
         DEALLOCATE @curPD
   
         -- Get new PickDetailKey for splited line
         DECLARE @nSuccess INT
         -- SOS139575 - to avoid ambiguity
         -- DECLARE @nBatch INT
         DECLARE @nKeyBatch INT
         DECLARE @nID INT
   
         SET @nKeyBatch = 0
         SELECT @nKeyBatch = COUNT( 1) FROM @tFinal WHERE PickDetailKey = ''
         IF @nKeyBatch > 0
         BEGIN
      		SET @nSuccess = 1
      		EXECUTE dbo.nspg_getkey
         		'PICKDETAILKEY'
         		, 10
         		, @cPickDetailKey OUTPUT
         		, @nSuccess       OUTPUT
         		, @nErrNo         OUTPUT
         		, @cErrMsg        OUTPUT
               , 0  -- Debug
               , @nKeyBatch  -- Key range
            IF @nSuccess <> 1
            BEGIN
               SET @nErrNo = 60821
               SET @cErrMsg = rdt.rdtgetmessage( 60821, @cLangCode, 'DSP') --'nspg_getkey fail'
               GOTO Fail
            END
   
            -- Stamp new PickDetailKey
            SET @nID = 0
            WHILE 1=1
            BEGIN
               SELECT TOP 1
                  @nID = [ID]
               FROM @tFinal
               WHERE PickDetailKey = ''
   
               IF @@ROWCOUNT = 0 BREAK
   
               UPDATE @tFinal SET PickDetailKey = @cPickDetailKey 
               WHERE [ID] = @nID
               SET @cPickDetailKey = RIGHT( REPLICATE( '0', 10) + CAST( CAST( @cPickDetailKey AS INT) + 1 AS NVARCHAR( 10)), 10)
            END
         END
   
         -- Check if other process had updated PickDetail
         IF EXISTS( SELECT 1 
            FROM dbo.PickDetail PD (NOLOCK)
            INNER JOIN @tFinal T ON (PD.PickDetailKey = T.PickDetailKey)
            WHERE PD.CaseID <> '' 
            AND IsNumeric( PD.CaseID) <> 1) -- CaseID updated by others
         BEGIN
            SET @nErrNo = 60822
            SET @cErrMsg = rdt.rdtgetmessage( 60822, @cLangCode, 'DSP') --'Retry again. PickDetail changed by other process'
            GOTO Fail
         END
   
         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_PostPackAudit_EndScan -- For rollback or commit only our own transaction
    
         -- Update PickDetail
         DECLARE @cRefPickDetailKey NVARCHAR( 18)
         DECLARE @curFinal CURSOR
         SET @curFinal = CURSOR FOR
            SELECT PickDetailKey, RefPickDetailKey, CaseID, DropID, QTY
            FROM @tFinal
            
         OPEN @curFinal
         FETCH NEXT FROM @curFinal INTO @cPickDetailKey, @cRefPickDetailKey, @cCaseID, @cDropID, @nQty
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @cRefPickDetailKey = ''
            BEGIN
               -- Stamp PickDetail.CaseID (using TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  CaseID = @cCaseID, 
                  QTY = @nQty, 
                  DropID = @cDropID, -- SOS67554 link CSAudit to PickDetail table
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 60823
                  SET @cErrMsg = rdt.rdtgetmessage( 60823, @cLangCode, 'DSP') --'Update PickDetail.CaseID fail'
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               -- Insert splitted PickDetail (using OptimizeCop)
               INSERT INTO dbo.PickDetail (PickDetailKey, CaseID, DropID, Qty, OptimizeCop, 
                  PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku, UOM, UOMQty, QtyMoved, Status, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, 
                  EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, ShipFlag, PickSlipNo)
               SELECT @cPickDetailKey, @cCaseID, @cDropID, @nQty, '1', 
                  PD.PickHeaderKey, PD.OrderKey, PD.OrderLineNumber, PD.Lot, PD.Storerkey, PD.Sku, PD.AltSku, PD.UOM, PD.UOMQty, PD.QtyMoved, PD.Status, PD.Loc, PD.ID, PD.PackKey, PD.UpdateSource, PD.CartonGroup, PD.CartonType, PD.ToLoc, PD.DoReplenish, 
                  PD.ReplenishZone, PD.DoCartonize, PD.PickMethod, PD.WaveKey, PD.EffectiveDate, PD.AddDate, PD.AddWho, PD.EditDate, PD.EditWho, PD.TrafficCop, PD.ArchiveCop, PD.ShipFlag, PD.PickSlipNo
               FROM dbo.PickDetail PD (NOLOCK)
               WHERE PD.PickDetailKey = @cRefPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 60824
                  SET @cErrMsg = rdt.rdtgetmessage( 60824, @cLangCode, 'DSP') --'Insert PickDetail fail'
                  GOTO RollBackTran
               END

               -- 23-06-2010 (Shong) Insert into RefKeyLookup for newly added Pickdetail Record.   
               IF EXISTS(SELECT 1 FROM dbo.RefKeyLookup rkl WITH (NOLOCK) WHERE rkl.PickDetailkey = @cRefPickDetailKey)      
               BEGIN      
                  INSERT INTO dbo.RefKeyLookup      
                  (      
                     PickDetailkey,      
                     Pickslipno,      
                     OrderKey,      
                     OrderLineNumber,      
                     Loadkey      
                  )      
                  SELECT @cPickDetailKey,       
                         rkl.Pickslipno,       
                         rkl.OrderKey,      
                         rkl.OrderLineNumber,       
                         rkl.Loadkey      
                    FROM dbo.RefKeyLookup rkl (NOLOCK)     
                  WHERE rkl.PickDetailkey = @cRefPickDetailKey       
                  IF @@ERROR <> 0      
                  BEGIN      
                     SET @nErrNo = 60824      
                     SET @cErrMsg = rdt.rdtgetmessage( 60824, @cLangCode, 'DSP') --'Insert PickDetail fail'      
                    GOTO RollBackTran      
                  END    
               END   

            END
            
            FETCH NEXT FROM @curFinal INTO @cPickDetailKey, @cRefPickDetailKey, @cCaseID, @cDropID, @nQty
         END
         CLOSE @curFinal
         DEALLOCATE @curFinal
         
         -- Insert to load
         INSERT INTO RDT.rdtCSAudit_Load (GroupID, StorerKey, Vehicle, ConsigneeKey, CaseID, Status, Seal, RefNo1, RefNo2, RefNo3, RefNo4, RefNo5)
         VALUES (@nMinRowRef, @cStorerKey, '', @cCA_Consignee, @cCA_CaseID, '0', '', '', '', '', '', '')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60807
            SET @cErrMsg = rdt.rdtgetmessage( 60807, @cLangCode, 'DSP') --'INS CALoad fail'
            GOTO RollBackTran
         END
   
         -- Close whole case
         UPDATE rdt.rdtCSAudit SET
            GroupID = @nMinRowRef, 
            OriginalQTY = CountQTY_B, 
            Status = '5'
         WHERE StorerKey = @cStorerKey
            AND Workstation = @cWorkstation
            AND ConsigneeKey = @cCA_Consignee
            AND PalletID = ''
            AND CaseID = @cCA_CaseID
            AND BatchID = @nBatchID -- SOS139575 
            AND Status = '0'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60825
            SET @cErrMsg = rdt.rdtgetmessage( 60825, @cLangCode, 'DSP') --'Close case fail'
            GOTO RollBackTran
         END         
         
         -- Delete DATA
         DELETE @tCA
         DELETE @tPD
         DELETE @tFinal
                 
         FETCH NEXT FROM @curCaseID INTO @cCA_CaseID, @cCA_Consignee
         /******************************************************/
         /* Loop by CaseID (Tote#) - End                       */
         /******************************************************/
      END
      CLOSE @curCaseID
      DEALLOCATE @curCaseID   

      -- Commented: Changed to update every case ID
      ---- Close case
      --IF @cSKU IS NULL -- Close whole case
      --BEGIN
      --   -- Insert to load
      --   INSERT INTO RDT.rdtCSAudit_Load (GroupID, StorerKey, Vehicle, ConsigneeKey, CaseID, Status, Seal, RefNo1, RefNo2, RefNo3, RefNo4, RefNo5)
      --   VALUES (@nMinRowRef, @cStorerKey, '', @cConsigneeKey, @cID, '0', '', '', '', '', '', '')
      --   IF @@ERROR <> 0
      --   BEGIN
      --      SET @nErrNo = 60807
      --      SET @cErrMsg = rdt.rdtgetmessage( 60807, @cLangCode, 'DSP') --'INS CALoad fail'
      --      GOTO RollBackTran
      --   END
      --
      --   -- Close whole case
      --   UPDATE rdt.rdtCSAudit SET
      --      GroupID = @nMinRowRef, 
      --      OriginalQTY = CountQTY_B, 
      --      Status = '5'
      --   WHERE StorerKey = @cStorerKey
      --      AND Workstation = @cWorkstation
      --      AND PalletID = ''
      --      AND CaseID = @cID
      --      AND Status = '0'
      --   IF @@ERROR <> 0
      --   BEGIN
      --      SET @nErrNo = 60825
      --      SET @cErrMsg = rdt.rdtgetmessage( 60825, @cLangCode, 'DSP') --'Close case fail'
      --      GOTO RollBackTran
      --   END
      --END
      --ELSE
      
      -- Tote correction, adjustment 1 SKU only
      IF ISNULL(@cSKU, '') <> ''
      BEGIN
         -- Get GroupID
         DECLARE @nGroupID INT
         SELECT @nGroupID  = GroupID
         FROM rdt.rdtCSAudit (NOLOCK)
         WHERE RowRef = @nMinRowRef -- Can get GroupID from any RowRef of that case

         -- Reset the whole case status to be 5-Closed, to avoid after adjustment record become 5-Closed and 
         -- others remain as 9-Printed. (before adjustment status can be either 5-Closed or 9-Printed)
         UPDATE rdt.rdtCSAudit SET
            Status = '5', 
            TrafficCop = NULL -- So that EditWho, EditDate won't get overwritten (for measuring performance)
         WHERE GroupID = @nGroupID
         AND BatchID = @nBatchID -- SOS139575
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 60826
            SET @cErrMsg = rdt.rdtgetmessage( 60826, @cLangCode, 'DSP') --'Close case fail'
            GOTO RollBackTran
         END
      END

      COMMIT TRAN rdtfnc_PostPackAudit_EndScan -- Only commit change made in here

   END --IF @cType = 'C'
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtfnc_PostPackAudit_EndScan
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
      

GO