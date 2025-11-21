SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtUpd01                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 06-01-2016  1.0  Ung      SOS360339. Created                         */
/* 27-10-2016  1.1  Ung      Performance tuning                         */
/* 07-01-2019  1.2  Ung      Reduce deadlock                            */
/* 13-05-2020  1.3  Ung      WMS-13218 Add CapturePackInfo (after)      */
/* 07-12-2020  1.4  James    WMS-15810 Add update cube (james01)        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtUpd01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nAfterStep   INT,        
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cSP_Cube    SYSNAME
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cPickSlipNo NVARCHAR( 10)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @nCartonNo   INT
   DECLARE @nTotalCube  FLOAT
   DECLARE @nWeight     FLOAT
   DECLARE @nCurrentTotalCube FLOAT
   DECLARE @nCtnCnt1    INT
   DECLARE @nCtnCnt2    INT
   DECLARE @nCtnCnt3    INT
   DECLARE @nCtnCnt4    INT
   DECLARE @nCtnCnt5    INT
   
   
   SELECT @cPickSlipNo = V_PickSlipNo, 
          @nCartonNo   = V_CartonNo,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1638ExtUpd01   
   
   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3 OR -- CaseID
         @nStep = 6    -- Capture pack info (after)
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cFromLOT  NVARCHAR(10)
            DECLARE @cFromLOC  NVARCHAR(10)
            DECLARE @cFromID   NVARCHAR(18)
            DECLARE @cPickDetailKey NVARCHAR(10)
            
            -- Pick confirm carton
            DECLARE @curPD CURSOR
            SET @curPD = CURSOR FOR
               SELECT PD.PickDetailKey
               FROM PickDetail PD WITH (NOLOCK)
                  JOIN LOT WITH (NOLOCK) ON (PD.LOT = LOT.LOT)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cCaseID
                  AND PD.Status <= '3'
                  AND PD.QTY > 0
               ORDER BY PD.OrderKey, PD.StorerKey, PD.SKU, PD.LOT -- To reduce deadlock, for conso carton
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE PickDetail SET 
                  Status = '5', 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               SET @nErrNo = @@ERROR 
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollbackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END
            
            -- Move carton
            SET @curPD = CURSOR FOR
               SELECT PD.LOT, PD.LOC, PD.ID, PD.SKU, SUM( PD.QTY)
               FROM PickDetail PD WITH (NOLOCK)
                  JOIN LOT WITH (NOLOCK) ON (PD.LOT = LOT.LOT)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cCaseID
                  AND PD.Status = '5'
                  AND PD.QTY > 0
                  AND (PD.LOC <> @cLOC OR PD.ID <> @cPalletKey) -- Change LOC / ID
               GROUP BY PD.OrderKey, PD.StorerKey, PD.SKU, PD.LOT, PD.LOC, PD.ID
               ORDER BY PD.OrderKey, PD.StorerKey, PD.SKU, PD.LOT, PD.LOC, PD.ID -- To reduce deadlock, for conso carton
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
                  @cSourceType = 'rdt_1638ExtUpd01',
                  @cStorerKey  = @cStorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cLOC,
                  @cFromID     = @cFromID,     
                  @cToID       = @cPalletKey,      
                  @cFromLOT    = @cFromLOT,  
                  @cSKU        = @cSKU,
                  @nQTY        = @nQTY,
                  @nQTYAlloc   = 0,
                  @nQTYPick    = @nQTY, 
                  @nFunc       = @nFunc, 
                  @cCaseID     = @cCaseID
               IF @nErrNo <> 0
                  GOTO RollbackTran
               
               FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY
            END
         END
      END

      IF @nStep = 4 -- Print label
      BEGIN
         DECLARE @cLoadKey NVARCHAR(10)
         DECLARE @nPickQTY    INT
         DECLARE @nPackQTY    INT
         
         -- Get LoadKey on pallet
         DECLARE @curLoad CURSOR
         SET @curLoad = CURSOR FOR
            SELECT DISTINCT LPD.LoadKey
            FROM PalletDetail WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.CaseID = PalletDetail.CaseID)
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            WHERE PalletDetail.PalletKey = @cPalletKey
         OPEN @curLoad
         FETCH NEXT FROM @curLoad INTO @cLoadKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Check not pick, short pick
            IF EXISTS( SELECT 1 
               FROM LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               WHERE LPD.LoadKey = @cLoadKey
                  AND PD.Status < '5'
                  AND PD.QTY > 0)
            BEGIN
               FETCH NEXT FROM @curLoad INTO @cLoadKey
               CONTINUE
            END

            -- Get PickSlipNo
            SELECT @cPickslipNo = PickslipNo FROM PackHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey
            
            -- Get Pick QTY
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey

            -- Get Pack QTY
            SELECT @nPackQTY = ISNULL( SUM( QTY), 0)
            FROM PackDetail WITH (NOLOCK) 
            WHERE PickslipNo = @cPickslipNo
            
            -- Check full packed
            IF @nPickQTY <> @nPackQTY
            BEGIN
               FETCH NEXT FROM @curLoad INTO @cLoadKey
               CONTINUE
            END
         
            -- Pack confirm
            UPDATE PackHeader SET
               Status = '9', 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE PickslipNo = @cPickslipNo
            SET @nErrNo = @@ERROR 
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollbackTran
            END
            FETCH NEXT FROM @curLoad INTO @cLoadKey
         END
      END

      -- (james01)
      IF @nStep = 6
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SET @nTotalCube = 0
            SET @nCurrentTotalCube = 0

            -- Get customize stored procedure  
            SELECT @cSP_Cube = Notes
            FROM dbo.CodeLkup WITH (NOLOCK)  
            WHERE ListName = 'CMSStrateg'  
            AND   Code = @cCartonType
            AND   Storerkey = @cStorerkey
            
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP_Cube AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC ' + RTRIM( @cSP_Cube) +
                  ' @cPickSlipNo, @cOrderKey, @nTotalCube OUTPUT, @nCurrentTotalCube, ' +
                  ' @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5, @nCartonNo, @cCartonType '  

               SET @cSQLParam =
                  ' @cPickSlipNo          NVARCHAR( 10), ' + 
                  ' @cOrderKey            NVARCHAR( 10), ' + 
                  ' @nTotalCube           FLOAT OUTPUT,  ' + 
                  ' @nCurrentTotalCube    FLOAT,  ' + 
                  ' @nCtnCnt1             INT,  ' + 
                  ' @nCtnCnt2             INT,  ' + 
                  ' @nCtnCnt3             INT,  ' +   
                  ' @nCtnCnt4             INT,  ' +   
                  ' @nCtnCnt5             INT,  ' +
                  ' @nCartonNo            INT,  ' +
                  ' @cCartonType          NVARCHAR( 10) ' 
            
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @cPickSlipNo, @cOrderKey, @nTotalCube OUTPUT, @nCurrentTotalCube, 
                  @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5, @nCartonNo, @cCartonType
            END
            ELSE
            BEGIN
               SELECT @nTotalCube = [Cube]
               FROM dbo.CARTONIZATION CZ WITH (NOLOCK) 
               JOIN dbo.STORER ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
               WHERE CZ.CartonType = @cCartonType
               AND   ST.StorerKey = @cStorerKey
            END
            
            IF EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                       WHERE PickSlipNo = @cPickSlipNo 
                       AND   CartonNo = @nCartonNo)
            BEGIN
               SELECT @nWeight = [Weight]
               FROM dbo.PackInfo WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 
               AND   CartonNo = @nCartonNo
               
               UPDATE dbo.PackInfo SET
                  [Cube] = CAST( ROUND(@nTotalCube, 3) AS NUMERIC( 10, 3)), 
                  [Weight] = CAST( ROUND(@nWeight, 3) AS NUMERIC( 10, 3)),
                  EditDate = GETDATE(), 
                  EditWho = @cUserName
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
               SET @nErrNo = @@ERROR 
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollbackTran
               END
            END 
         END
      END
   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1638ExtUpd01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END

GO