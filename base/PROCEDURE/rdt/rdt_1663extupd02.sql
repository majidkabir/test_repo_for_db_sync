SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd02                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-07-31 1.0  Ung      WMS-2016 Created                                  */
/* 2017-08-16 1.1  Ung      WMS-2692 Add MoveCarton. Change param             */
/* 2017-10-16 1.2  Ung      Performance tuning (remove @tVar)                 */
/* 2017-09-26 1.3  James    WMS-3098 Change insert transmilog2 tablename      */
/*                          based on setup in codelkup table (james01)        */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtUpd02](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPalletKey    NVARCHAR( 20), 
   @cPalletLOC    NVARCHAR( 10), 
   @cMBOLKey      NVARCHAR( 10), 
   @cTrackNo      NVARCHAR( 20), 
   @cOrderKey     NVARCHAR( 10), 
   @cShipperKey   NVARCHAR( 15),  
   @cCartonType   NVARCHAR( 10),  
   @cWeight       NVARCHAR( 10), 
   @cOption       NVARCHAR( 1),  
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess   INT
   DECLARE @nTranCount INT
   DECLARE @cTableName  NVARCHAR( 30)

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 3 OR -- Track no
         @nStep = 4 OR -- Weight
         @nStep = 5    -- Carton type
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- MBOLDetail created
            IF EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
            BEGIN
               -- Check pack confirm
               IF EXISTS( SELECT TOP 1 1 
                  FROM PackInfo PInf WITH (NOLOCK) 
                     JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PInf.PickSlipNo)
                  WHERE PInf.RefNo = @cTrackNo
                     AND PH.OrderKey = @cOrderKey
                     AND PH.Status = '9')
               BEGIN
                  -- Send order confirm to carrier
                  SELECT @cTableName = Long
                  FROM   dbo.Codelkup WITH (NOLOCK)
                  WHERE ListName = 'RDTINSTL2' 
                  AND   StorerKey = @cStorerKey
                  AND   Code = @cFacility
                  AND   Code2 = @nFunc
                  AND   Short = 'TrackNo2Pl'

                  -- Send order confirm to carrier
                  EXEC dbo.ispGenTransmitLog2 
                     @c_TableName      = @cTableName, 
                     @c_Key1           = @cOrderKey, 
                     @c_Key2           = '', 
                     @c_Key3           = @cStorerKey, 
                     @c_TransmitBatch  = '', 
                     @b_success        = @bSuccess    OUTPUT, 
                     @n_err            = @nErrNo      OUTPUT, 
                     @c_errmsg         = @cErrMsg     OUTPUT

                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 112951
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG3 Fail
                     GOTO Quit
                  END
               END
            END
         END
      END
      
      IF @nStep = 6 -- Close pallet
      BEGIN
         IF rdt.rdtGetConfig( @nFunc, 'MoveCarton', @cStorerKey) = '1'
         BEGIN
            DECLARE @cFromLOT       NVARCHAR(10)
            DECLARE @cFromLOC       NVARCHAR(10)
            DECLARE @cFromID        NVARCHAR(18)
            DECLARE @cSKU           NVARCHAR(20)
            DECLARE @nQTY           INT   
            DECLARE @cCaseID        NVARCHAR(20)
            DECLARE @cLabelNo       NVARCHAR(20)
            DECLARE @nCartonNo      INT
            DECLARE @cPickSlipNo    NVARCHAR(20)
            DECLARE @cPickDetailKey NVARCHAR(10)
            
            DECLARE @curPL CURSOR
            DECLARE @curPD CURSOR
            
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_1663ExtUpd02 -- For rollback or commit only our own transaction

            -- Loop pallet detail
            SET @curPL = CURSOR FOR
               SELECT CaseID
               FROM PalletDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND PalletKey = @cPalletKey
               ORDER BY PalletLineNumber
            OPEN @curPL
            FETCH NEXT FROM @curPL INTO @cCaseID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get PickSlipNo
               SELECT 
                  @cPickSlipNo = PH.PickSlipNo, 
                  @nCartonNo = CartonNo
               FROM PackInfo PINF WITH (NOLOCK)
                  JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PINF.PickSlipNo)
               WHERE PH.StorerKey = @cStorerKey
                  AND PINF.RefNo = @cCaseID

               -- Get LabelNo
               SELECT TOP 1 @cLabelNo = LabelNo FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo

               -- Move carton
               SET @curPD = CURSOR FOR
                  SELECT LOT, LOC, ID, SKU, SUM( QTY)
                  FROM PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND CaseID = @cLabelNo
                     AND Status = '5'
                     AND QTY > 0
                     AND (LOC <> @cPalletLOC OR ID <> @cPalletKey) -- Change LOC / ID
                  GROUP BY LOT, LOC, ID, SKU
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- EXEC move
                  EXECUTE rdt.rdt_Move
                     @nMobile     = @nMobile,
                     @cLangCode   = @cLangCode,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT, 
                     @cSourceType = 'rdt_1663ExtUpd02',
                     @cStorerKey  = @cStorerKey,
                     @cFacility   = @cFacility,
                     @cFromLOC    = @cFromLOC,
                     @cToLOC      = @cPalletLOC,
                     @cFromID     = @cFromID,     
                     @cToID       = @cPalletKey,      
                     @cFromLOT    = @cFromLOT,  
                     @cSKU        = @cSKU,
                     @nQTY        = @nQTY,
                     @nQTYAlloc   = 0,
                     @nQTYPick    = @nQTY, 
                     @nFunc       = @nFunc, 
                     @cCaseID     = @cLabelNo
                  IF @nErrNo <> 0
                     GOTO RollbackTran
                  
                  FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY
               END
               
               FETCH NEXT FROM @curPL INTO @cCaseID
            END
            
            COMMIT TRAN rdt_1663ExtUpd02
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1663ExtUpd02
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO