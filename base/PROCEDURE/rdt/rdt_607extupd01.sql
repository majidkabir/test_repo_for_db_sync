SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtUpd01                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Calc suggest location, booking, print label                       */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 25-Sep-2015  Ung       1.0   SOS350418 Created                             */
/* 29-Jan-2016  Ung       1.1   SOS362427 Remove Lottable6=B                  */
/* 14-Dec-2016  Ung       1.2   Fix rollback tran without check point         */
/* 13-Aug-2018  Ung       1.3   WMS-5956 Not print label if CPD brand         */
/* 06-Mar-2019  James     1.4   WMS-8220 Remove not print if CPD (james01)    */
/* 15-Mar-2019  YeeKung   1.5   WMS-8317 Remove @cBrand =’CPD’  (yeekung01)   */   
/* 21-Aug-2019  Ung       1.6   WMS-10277 rewrite due to process change       */ 
/* 14-Jan-2020  Chermaine 1.7   WMS-11672 Change Policy (cc01)                */
/* 29-May-2020  CheeMun   1.8   INC1154286-Check Printed from Printjob_Log    */ 
/* 22-Jun-2020  YeeKung   1.9   WMS-13814 Change Policy (yeekung02)           */    
/* 13-Oct-2022  YeeKung   2.0   WMS-20994 Upd ASNstatus   to 1  (yeekung02)   */                                                                                      
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_607ExtUpd01]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nAfterStep    INT,            
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cReceiptKey   NVARCHAR( 10), 
   @cPOKey        NVARCHAR( 10), 
   @cRefNo        NVARCHAR( 20), 
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT,           
   @cLottable01   NVARCHAR( 18), 
   @cLottable02   NVARCHAR( 18), 
   @cLottable03   NVARCHAR( 18), 
   @dLottable04   DATETIME,      
   @dLottable05   DATETIME,      
   @cLottable06   NVARCHAR( 30), 
   @cLottable07   NVARCHAR( 30), 
   @cLottable08   NVARCHAR( 30), 
   @cLottable09   NVARCHAR( 30), 
   @cLottable10   NVARCHAR( 30), 
   @cLottable11   NVARCHAR( 30), 
   @cLottable12   NVARCHAR( 30), 
   @dLottable13   DATETIME,      
   @dLottable14   DATETIME,      
   @dLottable15   DATETIME, 
   @cReasonCode   NVARCHAR( 5), 
   @cSuggID       NVARCHAR( 18), 
   @cSuggLOC      NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5), 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess INT
   DECLARE @nTranCount INT

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 607 -- Return V7
   BEGIN  
      IF @nStep = 5 -- ID, LOC
      BEGIN
      	/*-------------------------------------------------------------------------------

                          Update receipt asnstatus

         -------------------------------------------------------------------------------*/


                  
         IF EXISTS( SELECT 1 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ASNStatus = 'RCVD' AND StorerKey = @cStorerKey) --(yeekung02)
         BEGIN
         	Update Receipt SET 
         	   ASNStatus='1'
         	Where Receiptkey=@cReceiptkey 
         	AND ASNStatus='RCVD'
         	AND StorerKey = @cStorerKey

           IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO QUIT
            END
         END

         DECLARE @cSignatory  NVARCHAR( 18)  = ''
         DECLARE @cBrand      NVARCHAR( 250) = ''
         DECLARE @cSKUGroup   NVARCHAR( 10)  = ''

         -- Get receipt info
         SELECT @cSignatory = ISNULL( Signatory, '')
         FROM Receipt WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey

         -- Get SKU info
         SELECT @cBrand = ISNULL( Long, '')
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'ITEMCLASS' 
            AND StorerKey = @cStorerKey 
            AND Code = @cSignatory
         
         -- Get SKU info
         SELECT @cSKUGroup = SKUGroup
         FROM SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU
         
         /*
            L06 is 1 CHAR:
               U = Good stock
               Q = Second grade
               B = Bad stock
               EP = need to repackage, re-label
               L = need to take out label
         */

         /*-------------------------------------------------------------------------------
         
                                         Find suggested location
      
         -------------------------------------------------------------------------------*/         
         DECLARE @cSuggToID  NVARCHAR( 18)
         DECLARE @cSuggToLOC NVARCHAR( 10)
         SET @cSuggToID = ''
         SET @cSuggToLOC = ''
         
         IF @cBrand = 'LPD' AND @cSignatory = '19' AND @cSKUGroup = 'YFG' 
         BEGIN
            IF @cLottable06 = 'D' AND @cSKUGroup in ('PLV','YSM2')   --(cc01)
               SELECT TOP 1
                  @cSuggToLOC = LLI.LOC, 
                  @cSuggToID = LLI.ID
               FROM LOTxLOCxID LLI WITH (NOLOCK) 
                  JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  JOIN LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               WHERE LOC.Facility = @cFacility
                  AND LOC.HostWHCode = 'Q-SL98'
                  AND LOC.LocationGroup = 'LOR-CPD-NYX-D'
                  AND LOC.Floor = '1' 
                  AND LA.Lottable04 = @dLottable04
                  AND LLI.QTY - LLI.QTYPicked > 0
               GROUP BY LLI.LOC, LLI.ID
               ORDER BY SUM( LLI.QTY - LLI.QTYPicked), LLI.LOC, LLI.ID
            
            ELSE IF @cLottable06 = 'Q'
               SELECT TOP 1
                  @cSuggToLOC = LLI.LOC, 
                  @cSuggToID = LLI.ID
               FROM LOTxLOCxID LLI WITH (NOLOCK) 
                  JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND LLI.StorerKey = @cStorerKey
                  AND LLI.SKU = @cSKU
                  AND LOC.HostWHCode = 'U-SL95'
                  AND LOC.LocationGroup = 'LOR-Q'
                  AND LOC.Floor = '1' 
                  AND LLI.QTY - LLI.QTYPicked > 0
               GROUP BY LLI.LOC, LLI.ID
               ORDER BY SUM( LLI.QTY - LLI.QTYPicked), LLI.LOC, LLI.ID
         END

         ELSE IF @cBrand IN ('LPD', 'CPD') AND @cSKUGroup = 'YFG' AND @cLottable06 = 'D'  --(cc01)
         BEGIN
            IF @cBrand = 'LPD'
               SELECT TOP 1
                  @cSuggToLOC = LLI.LOC, 
                  @cSuggToID = LLI.ID
               FROM LOTxLOCxID LLI WITH (NOLOCK) 
                  JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND LLI.StorerKey = @cStorerKey
                  AND LLI.SKU = @cSKU
                  AND LOC.HostWHCode = 'Q-SL98'
                  AND LOC.LocationGroup = 'LOR-D'
                  AND LOC.Floor = '3' 
                  AND LLI.QTY - LLI.QTYPicked > 0
               GROUP BY LLI.LOC, LLI.ID
               ORDER BY SUM( LLI.QTY - LLI.QTYPicked), LLI.LOC, LLI.ID
            ELSE
               SELECT TOP 1
                  @cSuggToLOC = LLI.LOC, 
                  @cSuggToID = LLI.ID
               FROM LOTxLOCxID LLI WITH (NOLOCK) 
                  JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  JOIN LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               WHERE LOC.Facility = @cFacility
                  AND LOC.HostWHCode = 'Q-SL98'
                  AND LOC.LocationGroup = 'LOR-D'
                  AND LOC.Floor = '1' 
                  AND MONTH( LA.Lottable04) = MONTH( @dLottable04)
                  AND LLI.QTY - LLI.QTYPicked > 0
               GROUP BY LLI.LOC, LLI.ID
               ORDER BY SUM( LLI.QTY - LLI.QTYPicked), LLI.LOC, LLI.ID
         END

         ELSE IF @cLottable06 = 'Q' AND @cSKUGroup = 'YFG'
            SELECT TOP 1
               @cSuggToLOC = LLI.LOC, 
               @cSuggToID = LLI.ID
            FROM LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.StorerKey = @cStorerKey
               AND LLI.SKU = @cSKU
               AND LOC.HostWHCode = 'U-SL95'
               AND LOC.LocationGroup = 'LOR-Q'
               AND LOC.Floor = '1' 
               AND LLI.QTY - LLI.QTYPicked > 0
            GROUP BY LLI.LOC, LLI.ID
            ORDER BY SUM( LLI.QTY - LLI.QTYPicked), LLI.LOC, LLI.ID

         ELSE IF @cLottable06 = 'D' AND @cSKUGroup IN ( 'PLV','YSM2')   --(cc01)
            SELECT TOP 1
               @cSuggToLOC = LLI.LOC, 
               @cSuggToID = LLI.ID
            FROM LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.StorerKey = @cStorerKey
               AND LLI.SKU = @cSKU
               AND LOC.HostWHCode = 'Q-SL98'
               AND LOC.LocationGroup = 'LOR-D'
               AND LOC.Floor = '1' 
               AND LLI.QTY - LLI.QTYPicked > 0
            GROUP BY LLI.LOC, LLI.ID
            ORDER BY SUM( LLI.QTY - LLI.QTYPicked), LLI.LOC, LLI.ID

         ELSE IF @cLottable06 = 'U'
            SELECT TOP 1 
               @cSuggToLOC = LOC.LOC 
            FROM SKUxLOC SL WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND SL.LocationType = 'PICK'
               AND SL.QTY-SL.QTYPicked > 0
               AND SL.SKU = @cSKU   --(cc01)
            GROUP BY LOC.LOC
            ORDER BY SUM( SL.QTY - SL.QTYPicked), LOC.LOC

         --ELSE IF @cLottable06 = 'EP'  --(yeekung02)
         --   SET @cSuggToLOC = 'A1EP0008R'  
  
         ELSE IF @cLottable06 = 'L'  
            SET @cSuggToLOC = 'H1RR0001' --(cc01)  --(yeekung02)
            --SELECT TOP 1
            --   @cSuggToLOC = LOC.LOC
            --FROM LOC WITH (NOLOCK)
            --WHERE LOC.Facility = @cFacility
            --   AND LOC.HostWHCode = 'Q-SL98'
            --   AND LOC.LocationCategory = 'LOR-L'
            --   AND LOC.Floor = '1' 
            --ORDER BY LOC.LOC


         /*-------------------------------------------------------------------------------
         
                                    Create LOT if not yet receive
      
         -------------------------------------------------------------------------------*/
         IF @cSuggToLOC <> ''
         BEGIN
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_607ExtUpd01 -- For rollback or commit only our own transaction
            
            -- Stamp receiving date (to get LOT in below)
            IF ISNULL( @dLottable05, 0) = 0
            BEGIN
               -- NULL and 1900-01-01 generate different LOT, use NULL
               SET @dLottable05 = NULL
               
               -- Get SKU info
               IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND Lottable05Label = 'RCP_DATE')
               BEGIN
                  SET @dLottable05 = CAST( CONVERT( NVARCHAR( 10), GETDATE(), 120) AS DATETIME)
                  UPDATE ReceiptDetail SET
                     Lottable05 = @dLottable05, 
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME()
                  WHERE ReceiptKey = @cReceiptKey
                     AND ReceiptLineNumber = @cReceiptLineNumber
                  SET @nErrNo = @@ERROR
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollbackTran
                  END
               END
            END
            
            -- LOT lookup
            DECLARE @cLOT NVARCHAR( 10)
            SET @cLOT = ''
            EXECUTE dbo.nsp_LotLookUp @cStorerKey, @cSKU
              , @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
              , @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
              , @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
              , @cLOT      OUTPUT
              , @bSuccess  OUTPUT
              , @nErrNo    OUTPUT
              , @cErrMsg   OUTPUT
      
            -- Create LOT if not exist
            IF @cLOT IS NULL
            BEGIN
               EXECUTE dbo.nsp_LotGen @cStorerKey, @cSKU
                  , @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
                  , @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
                  , @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
                  , @cLOT     OUTPUT
                  , @bSuccess OUTPUT
                  , @nErrNo   OUTPUT
                  , @cErrMsg  OUTPUT
               IF @bSuccess <> 1
                  GOTO RollbackTran
      
               IF NOT EXISTS( SELECT 1 FROM LOT (NOLOCK) WHERE LOT = @cLOT)
               BEGIN
                  INSERT INTO LOT (LOT, StorerKey, SKU) VALUES (@cLOT, @cStorerKey, @cSKU)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 56901
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOT Fail
                     GOTO RollbackTran
                  END
               END
            END
      
            -- Create ToID if not exist
            IF @cID <> ''
            BEGIN
               IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cID)
               BEGIN
                  INSERT INTO ID (ID) VALUES (@cID)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 56902
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ID Fail
                     GOTO RollbackTran
                  END
               END
            END
   
   
            /*-------------------------------------------------------------------------------
            
                                          Book suggested location
         
            -------------------------------------------------------------------------------*/
            -- Book location in RFPutaway
            IF EXISTS( SELECT TOP 1 1 
               FROM RFPutaway WITH (NOLOCK) 
               WHERE LOT = @cLOT
                  AND FromLOC = @cLOC
                  AND FromID = @cID
                  AND SuggestedLOC = @cSuggToLOC
                  AND ID = @cSuggToID)
            BEGIN
               UPDATE RFPutaway SET
                  QTY = QTY + @nQTY
               WHERE LOT = @cLOT
                  AND FromLOC = @cLOC
                  AND FromID = @cID
                  AND SuggestedLOC = @cSuggToLOC
                  AND ID = @cSuggToID
               SET @nErrNo = @@ERROR
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollbackTran
               END
            END
            ELSE
            BEGIN
               -- Update RFPutaway
               INSERT INTO RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID)
               VALUES (@cStorerKey, @cSKU, @cLOT, @cLOC, @cID, @cSuggToLOC, @cSuggToID, SUSER_SNAME(), @nQTY, '')
               SET @nErrNo = @@ERROR
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollbackTran
               END
            END
               
            -- Book location in LOTxLOCxID
            IF EXISTS (SELECT 1 
               FROM dbo.LOTxLOCxID WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cSuggToLOC
                  AND ID = @cSuggToID)
            BEGIN
               UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET 
                  PendingMoveIn = CASE WHEN PendingMoveIn >= 0 THEN PendingMoveIn + @nQTY ELSE 0 END
               WHERE LOT = @cLOT
                  AND LOC = @cSuggToLOC
                  AND ID  = @cSuggToID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 56903
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
                  GOTO RollbackTran
               END
            END
            ELSE
            BEGIN
               INSERT dbo.LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, PendingMoveIn)
               VALUES (@cLOT, @cSuggToLOC, @cSuggToID, @cStorerKey, @cSKU, @nQTY)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 56904
                  SET @cErrMsg = @cSuggToLOC -- rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LLI Fail
                  GOTO RollbackTran
               END
            END
            
            COMMIT TRAN rdt_607ExtUpd01
         END
         
         /*-------------------------------------------------------------------------------
         
                                             Print label
      
         -------------------------------------------------------------------------------*/
         -- Print label if non CPD brand
         --IF @cLong <> 'CPD' 
         --BEGIN
         -- Get login info
         DECLARE @cPrinter NVARCHAR(10)
         SELECT @cPrinter = Printer FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
            
         -- Check printer
         IF @cPrinter = ''
         BEGIN
            SET @nErrNo = 56905
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLoginPrinter
            GOTO Quit
         END

         -- Get report info
         DECLARE @cDataWindow NVARCHAR(50)
         DECLARE @cTargetDB   NVARCHAR(10)
         SELECT
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ReportType ='IDLABEL'

         -- Check data window
         IF ISNULL(@cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 56906
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Quit
         END

         -- Check database
         IF ISNULL(@cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 56907
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Quit
         END

         -- INC1154286
         -- Check label printed      
         IF NOT EXISTS( SELECT 1 FROM rdt.rdtPrintJob_Log WITH (NOLOCK) WHERE ReportID = 'IDLABEL' AND Parm1 = @cReceiptKey AND Parm2 = @cID AND Storerkey = @cStorerKey)      
         BEGIN
            EXEC RDT.rdt_BuiltPrintJob
                  @nMobile
               ,@cStorerKey
               ,'IDLABEL'          -- ReportType 
               ,'PRINT_IDLABEL'  -- PrintJobName
               ,@cDataWindow
               ,@cPrinter
               ,@cTargetDB
               ,@cLangCode
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cReceiptKey
               ,@cID
            IF @nErrNo <> 0
               GOTO Quit
         END
         --END
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_607ExtUpd01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

SET QUOTED_IDENTIFIER OFF

GO