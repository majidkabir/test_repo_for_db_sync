SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_852ExtUpd01                                        */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author      Purposes                                   */
/* 01-Oct-2018 1.0  Ung         WMS-6510 Created                           */
/* 08-Nov-2018 1.1  Ung         WMS-6914 Add pallet label                  */
/* 19-Nov-2018 1.2  Ung         WMS-6932 Add ID param                      */
/* 29-Mar-2019 1.3  James       WMS-8002 Add TaskDetailKey param (james01) */
/***************************************************************************/

CREATE PROC [RDT].[rdt_852ExtUpd01] (
   @nMobile      INT, 
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT, 
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR( 15),  
   @cRefNo       NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cLoadKey     NVARCHAR( 10), 
   @cOrderKey    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20),  
   @nQty         INT,  
   @cOption      NVARCHAR( 1),  
   @nErrNo       INT OUTPUT,  
   @cErrMsg      NVARCHAR( 20) OUTPUT, 
   @cID          NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT

   IF @nFunc = 852 -- PPA by PickSlipNo 
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cZone          NVARCHAR( 18)
            DECLARE @cFacility      NVARCHAR( 5)
            DECLARE @cLabelPrinter  NVARCHAR( 10)
            DECLARE @cPaperPrinter  NVARCHAR( 10)
            DECLARE @cPickConfirmStatus NVARCHAR( 1)
            DECLARE @nPalletCNT     INT
            DECLARE @nPallet        INT
            DECLARE @nCaseCNT       INT
            DECLARE @nCase          INT
            DECLARE @nPiece         INT
            DECLARE @nPQTY          INT
            DECLARE @nPPallet       INT
            DECLARE @nPCase         INT
            DECLARE @nPPiece        INT
            DECLARE @nRowRef        INT
            DECLARE @cShipLabel     NVARCHAR( 20)
            DECLARE @tShipLabel AS VariableTable
            
            DECLARE @tLabel TABLE
            (
               RowRef     INT          NOT NULL IDENTITY( 1, 1), 
               PickSlipNo NVARCHAR(10) NOT NULL, 
               OrderKey   NVARCHAR(10) NOT NULL, 
               SKU        NVARCHAR(20) NOT NULL, 
               QTY        INT          NOT NULL, 
               PRIMARY KEY CLUSTERED (RowRef)
            )

            SET @nTranCount = @@TRANCOUNT

            -- Get storer configure
            SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
            IF @cShipLabel = '0'
               SET @cShipLabel = ''

            -- Ship label
            IF @cShipLabel = '' 
               GOTO Quit

            -- Get session info
            SELECT 
               @cFacility = Facility, 
               @cLabelPrinter = Printer, 
               @cPaperPrinter = Printer_Paper 
            FROM rdt.rdtMobRec WITH (NOLOCK) 
            WHERE Mobile = @nMobile

            -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cLoadKey = ExternOrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo
            
            -- Get SKU info
            SELECT 
               @nPalletCNT = CAST( Pallet AS INT), 
               @nCaseCNT = CAST( CaseCNT AS INT)
            FROM SKU WITH (NOLOCK)
               JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU
            
            SET @nPallet = 0
            SET @nCase = 0
            SET @nPiece = 0

            -- Calc cases and pieces
            IF @nPalletCNT > 0
            BEGIN
               SET @nPallet = @nQTY / @nPalletCNT
               IF @nPallet > 0
                  SET @nQTY = @nQTY - (@nPallet * @nPalletCNT)
            END
            
            IF @nCaseCNT > 0
            BEGIN
               SET @nCase = @nQTY / @nCaseCnt
               SET @nPiece = @nQTY % @nCaseCnt
            END
            ELSE
               SET @nPiece = @nQTY 
                     
            -- Discrete pick slip
            IF @cOrderKey <> ''
            BEGIN
               IF @nPallet > 0
               BEGIN
                  -- Common params
                  INSERT INTO @tShipLabel (Variable, Value) VALUES 
                     ( '@cPickSlipNo', @cPickSlipNo), 
                     ( '@cOrderKey',   @cOrderKey), 
                     ( '@cStorerKey',  @cStorerKey), 
                     ( '@cSKU',        @cSKU), 
                     ( '@nQTY',        CAST( @nPalletCnt AS NVARCHAR(10)))

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cShipLabel, -- Report type
                     @tShipLabel, -- Report params
                     'rdt_852ExtUpd01', 
                     @nErrNo      OUTPUT,
                     @cErrMsg     OUTPUT, 
                     @nNoOfCopy = @nCase
                  IF @nErrNo <> 0
                     GOTO Quit
               END
               
               IF @nCase > 0
               BEGIN
                  -- Common params
                  INSERT INTO @tShipLabel (Variable, Value) VALUES 
                     ( '@cPickSlipNo', @cPickSlipNo), 
                     ( '@cOrderKey',   @cOrderKey), 
                     ( '@cStorerKey',  @cStorerKey), 
                     ( '@cSKU',        @cSKU), 
                     ( '@nQTY',        CAST( @nCaseCnt AS NVARCHAR(10)))

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cShipLabel, -- Report type
                     @tShipLabel, -- Report params
                     'rdt_852ExtUpd01', 
                     @nErrNo      OUTPUT,
                     @cErrMsg     OUTPUT, 
                     @nNoOfCopy = @nCase
                  IF @nErrNo <> 0
                     GOTO Quit
               END

               IF @nPiece > 0
               BEGIN
                  -- Common params
                  DELETE @tShipLabel 
                  INSERT INTO @tShipLabel (Variable, Value) VALUES 
                     ( '@cPickSlipNo', @cPickSlipNo), 
                     ( '@cOrderKey',   @cOrderKey), 
                     ( '@cStorerKey',  @cStorerKey), 
                     ( '@cSKU',        @cSKU), 
                     ( '@nQTY',        CAST( @nPiece AS NVARCHAR(10)))

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cShipLabel, -- Report type
                     @tShipLabel, -- Report params
                     'rdt_852ExtUpd01', 
                     @nErrNo      OUTPUT,
                     @cErrMsg     OUTPUT
                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
            
            -- Conso pick slip
            ELSE IF @cLoadKey <> '' 
            BEGIN
               -- Handling transaction
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_852ExtUpd01 -- For rollback or commit only our own transaction

               -- Check log noet yet populated
               IF NOT EXISTS( SELECT TOP 1 1 
                  FROM rdt.rdtPPALog WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo 
                     AND StorerKey = @cStorerKey 
                     AND SKU = @cSKU)
               BEGIN
                  -- Get storer configure
                  SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
                  
                  DECLARE @curPD CURSOR
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT O.OrderKey, ISNULL( SUM( QTY), 0)
                     FROM dbo.Orders O WITH (NOLOCK)
                        JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                     WHERE O.LoadKey = @cLoadKey
                        AND PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cSKU
                        AND PD.QTY > 0
                        AND PD.Status >= @cPickConfirmStatus   
                     GROUP BY O.OrderKey         
                  OPEN @curPD
                  FETCH NEXT FROM @curPD INTO @cOrderKey, @nPQTY
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Calc pallets, cases and pieces
                     SET @nPPallet = 0
                     SET @nPCase = 0
                     SET @nPPiece = 0

                     IF @nPalletCNT > 0
                     BEGIN
                        SET @nPPallet = @nPQTY / @nPalletCnt
                        IF @nPPallet > 0
                           SET @nPQTY = @nPQTY - (@nPPallet * @nPalletCnt)
                     END

                     IF @nCaseCNT > 0
                     BEGIN
                        SET @nPCase = @nPQTY / @nCaseCnt
                        SET @nPPiece = @nPQTY % @nCaseCnt
                     END
                     ELSE
                        SET @nPPiece = @nPQTY 

                     -- Insert pallets
                     WHILE @nPPallet > 0
                     BEGIN
                        INSERT INTO rdt.rdtPPALog (Mobile, PickSlipNo, OrderKey, StorerKey, SKU, PQTY, CQTY)
                        VALUES (@nMobile, @cPickSlipNo, @cOrderKey, @cStorerKey, @cSKU, @nPalletCNT, 0)
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 129551
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PPALogFail
                           GOTO RollBackTran
                        END

                        SET @nPPallet = @nPPallet - 1
                     END
                  
                     -- Insert cases
                     WHILE @nPCase > 0
                     BEGIN
                        INSERT INTO rdt.rdtPPALog (Mobile, PickSlipNo, OrderKey, StorerKey, SKU, PQTY, CQTY)
                        VALUES (@nMobile, @cPickSlipNo, @cOrderKey, @cStorerKey, @cSKU, @nCaseCNT, 0)
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 129551
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PPALogFail
                           GOTO RollBackTran
                        END

                        SET @nPCase = @nPCase - 1
                     END
                     
                     -- Insert piece
                     IF @nPPiece > 0
                     BEGIN
                        INSERT INTO rdt.rdtPPALog (Mobile, PickSlipNo, OrderKey, StorerKey, SKU, PQTY, CQTY)
                        VALUES (@nMobile, @cPickSlipNo, @cOrderKey, @cStorerKey, @cSKU, @nPPiece, 0)
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 129552
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PPALogFail
                           GOTO RollBackTran
                        END
                     END

                     FETCH NEXT FROM @curPD INTO @cOrderKey, @nPQTY
                  END
               END
               
               -- Cases
               WHILE @nCase > 0
               BEGIN
                  -- Find case not yet print
                  SET @nRowRef = 0
                  SELECT TOP 1 
                     @nRowRef = RowRef, 
                     @cOrderKey = OrderKey
                  FROM rdt.rdtPPALog WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND PQTY = @nCaseCNT
                     AND CQTY = 0 -- Not yet print
                  
                  -- Case not found
                  IF @nRowRef = 0
                  BEGIN
                     SET @nErrNo = 129553
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Case NotFound
                     GOTO RollBackTran
                  END
                  
                  -- Mark as taken
                  UPDATE rdt.rdtPPALog SET
                     CQTY = @nCaseCNT, -- Mark as printed
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME()
                  WHERE RowRef = @nRowRef
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 129554
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PPALogFail
                     GOTO RollBackTran
                  END
                  
                  INSERT INTO @tLabel (PickSlipNo, OrderKey, SKU, QTY)
                  VALUES (@cPickSlipNo, @cOrderKey, @cSKU, @nCaseCNT)
                  
                  SET @nCase = @nCase - 1
               END
               
               -- Piece
               WHILE @nPiece > 0
               BEGIN
                  -- Find piece not yet print
                  SET @nRowRef = 0
                  SELECT TOP 1 
                     @nRowRef = RowRef, 
                     @cOrderKey = OrderKey, 
                     @nPQTY = PQTY
                  FROM rdt.rdtPPALog WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND PQTY <> @nCaseCNT
                     AND CQTY = 0 -- Not yet print
                  
                  -- Case not found
                  IF @nRowRef = 0
                  BEGIN
                     SET @nErrNo = 129555
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Piece NotFound
                     GOTO RollBackTran
                  END

                  DECLARE @nCQTY INT
                  IF @nPQTY <= @nPiece
                     SET @nCQTY = @nPQTY
                  ELSE
                     SET @nCQTY = @nPiece
                  
                  -- IF @nPQTY <= @nPiece
                  BEGIN
                     -- Mark as taken
                     UPDATE rdt.rdtPPALog SET
                        CQTY = @nCQTY, -- Mark as printed
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME()
                     WHERE RowRef = @nRowRef
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 129556
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PPALogFail
                        GOTO RollBackTran
                     END
                     
                     -- Insert print label
                     INSERT INTO @tLabel (PickSlipNo, OrderKey, SKU, QTY)
                     VALUES (@cPickSlipNo, @cOrderKey, @cSKU, @nCQTY)

                     -- Reduce balance
                     SET @nPiece = @nPiece - @nPQTY
                  END
/*
                  ELSE
                  BEGIN
                     -- Split line (new line carry balance)
                     INSERT INTO rdt.rdtPPALog (Mobile, PickSlipNo, OrderKey, StorerKey, SKU, PQTY, CQTY)
                     SELECT Mobile, PickSlipNo, OrderKey, StorerKey, SKU, @nPQTY - @nPiece, 0
                     FROM rdt.rdtPPALog WITH (NOLOCK)
                     WHERE RowRef = @nRowRef
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 129557
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PPALogFail
                        GOTO RollBackTran
                     END
                     
                     -- Current line mark as taken
                     UPDATE rdt.rdtPPALog SET
                        PQTY = @nPiece, 
                        CQTY = @nPiece, -- Mark as printed
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME()
                     WHERE RowRef = @nRowRef
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 129557
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PPALogFail
                        GOTO RollBackTran
                     END
                     
                     -- Insert print label
                     INSERT INTO @tLabel (PickSlipNo, OrderKey, SKU, QTY)
                     VALUES (@cPickSlipNo, @cOrderKey, @cSKU, @nPiece)

                     -- Reduce balance
                     SET @nPiece = 0
                  END
*/
               END

               COMMIT TRAN rdt_852ExtUpd01

               -- Get first label
               SET @nRowRef = 0
               SELECT TOP 1
                  @nRowRef = RowRef, 
                  @cOrderKey = OrderKey, 
                  @nQTY = QTY
               FROM @tLabel
               WHERE RowRef > @nRowRef
               ORDER BY RowRef
               
               -- Loop label
               WHILE @nRowRef > 0
               BEGIN
                  -- Common params
                  DELETE @tShipLabel 
                  INSERT INTO @tShipLabel (Variable, Value) VALUES 
                     ( '@cPickSlipNo', @cPickSlipNo), 
                     ( '@cOrderKey',   @cOrderKey), 
                     ( '@cStorerKey',  @cStorerKey), 
                     ( '@cSKU',        @cSKU), 
                     ( '@nQTY',        CAST( @nQTY AS NVARCHAR(10)))

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cShipLabel, -- Report type
                     @tShipLabel, -- Report params
                     'rdt_852ExtUpd01', 
                     @nErrNo      OUTPUT,
                     @cErrMsg     OUTPUT
                  IF @nErrNo <> 0
                     GOTO Quit

                  -- Get next label
                  SELECT TOP 1
                     @nRowRef = RowRef, 
                     @cOrderKey = OrderKey, 
                     @nQTY = QTY
                  FROM @tLabel
                  WHERE RowRef > @nRowRef
                  ORDER BY RowRef
                  
                  IF @@ROWCOUNT = 0
                     BREAK
               END
            END
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_852ExtUpd01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO