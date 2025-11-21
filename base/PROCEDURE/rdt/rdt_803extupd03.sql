SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_803ExtUpd03                                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-02-24 1.0  James    WMS-18979. Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_803ExtUpd03] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),   
   @cStorerKey   NVARCHAR( 15), 
   @cStation     NVARCHAR( 10), 
   @cMethod      NVARCHAR( 1),  
   @cSKU         NVARCHAR( 20), 
   @cLastPos     NVARCHAR( 10), 
   @cOption      NVARCHAR( 1),  
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 803 -- PTLPiece
   BEGIN
      IF @nStep = 3 -- Matrix
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            DECLARE @i         INT
            DECLARE @cPosition NVARCHAR(10)
            DECLARE @cOrderKey NVARCHAR(10)
            DECLARE @nTotal    INT
            DECLARE @nSorted   INT
            DECLARE @cMsg      NVARCHAR(20)
            DECLARE @cMsg01    NVARCHAR(20)
            DECLARE @cMsg02    NVARCHAR(20)
            DECLARE @cMsg03    NVARCHAR(20)
            DECLARE @cMsg04    NVARCHAR(20)
            DECLARE @cMsg05    NVARCHAR(20)
            DECLARE @cMsg06    NVARCHAR(20)
            DECLARE @cMsg07    NVARCHAR(20)
            DECLARE @cMsg08    NVARCHAR(20)
            DECLARE @cMsg09    NVARCHAR(20)
            DECLARE @cMsg10    NVARCHAR(20)
            DECLARE @cPickDetailKey NVARCHAR( 10)
            DECLARE @nTranCount     INT

            SET @nErrNo = 0
            
            -- Handling transaction    
            SET @nTranCount = @@TRANCOUNT    
            BEGIN TRAN  -- Begin our own transaction    
            SAVE TRAN rdt_803ExtUpd03 -- For rollback or commit only our own transaction    
         
            DECLARE @curUpdPD CURSOR
            SET @curUpdPD = CURSOR FOR
               SELECT PD.PickDetailKey
               FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = L.OrderKey)
                  JOIN dbo.SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku)
               WHERE Station = @cStation
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.CaseID <> 'SORTED'
                  AND SKU.SKUGROUP = 'POP'
            OPEN @curUpdPD
            FETCH NEXT FROM @curUpdPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN                  
               -- Confirm PickDetail    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  CaseID = 'SORTED',    
                  EditDate = GETDATE(),    
                  EditWho  = SUSER_SNAME()    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 183601    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
                  GOTO RollBackTran_St3    
               END    

               FETCH NEXT FROM @curUpdPD INTO @cPickDetailKey
            END

            COMMIT TRAN rdt_803ExtUpd03    

            GOTO Commit_St3    
    
            RollBackTran_St3:    
               ROLLBACK TRAN rdt_803ExtUpd03 -- Only rollback change made here    
            Commit_St3:    
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                  COMMIT TRAN    

            IF @nErrNo <> 0
               GOTO Quit

            SET @i = 1
            SET @cMsg = ''
            SET @cMsg01 = ''
            SET @cMsg02 = ''
            SET @cMsg03 = ''
            SET @cMsg04 = ''
            SET @cMsg05 = ''
            SET @cMsg06 = ''
            SET @cMsg07 = ''
            SET @cMsg08 = ''
            SET @cMsg09 = ''
            SET @cMsg10 = ''
                         
            DECLARE @curPos CURSOR
            SET @curPos = CURSOR FOR
               SELECT L.Position, L.OrderKey, 
                  SUM( PD.QTY), 
                  SUM( CASE WHEN PD.CaseID = 'SORTED' THEN PD.QTY ELSE 0 END)
               FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = L.OrderKey)
               WHERE Station = @cStation
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
               GROUP BY L.Position, L.OrderKey
               HAVING SUM( PD.QTY) <> 
                  SUM( CASE WHEN PD.CaseID = 'SORTED' THEN PD.QTY ELSE 0 END)
               ORDER BY L.Position
               
            OPEN @curPos
            FETCH NEXT FROM @curPos INTO @cPosition, @cOrderKey, @nTotal, @nSorted
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @cMsg = 
                  RTRIM( @cPosition) + '-' + 
                  @cOrderKey + '=' + 
                  CAST( ISNULL( @nSorted, 0) AS NVARCHAR(5)) + '/' + 
                  CAST( ISNULL( @nTotal, 0) AS NVARCHAR(5))
               
               IF @i = 1  SET @cMsg01 = @cMsg ELSE
               IF @i = 2  SET @cMsg02 = @cMsg ELSE
               IF @i = 3  SET @cMsg03 = @cMsg ELSE
               IF @i = 4  SET @cMsg04 = @cMsg ELSE
               IF @i = 5  SET @cMsg05 = @cMsg ELSE
               IF @i = 6  SET @cMsg06 = @cMsg ELSE
               IF @i = 7  SET @cMsg07 = @cMsg ELSE
               IF @i = 8  SET @cMsg08 = @cMsg ELSE
               IF @i = 9  SET @cMsg09 = @cMsg ELSE
               IF @i = 10 SET @cMsg10 = @cMsg
               
               SET @i = @i + 1
               IF @i > 10
                  BREAK
                  
               FETCH NEXT FROM @curPos INTO @cPosition, @cOrderKey, @nTotal, @nSorted
            END
            
            -- Prompt outstanding
            IF @cMsg01 <> ''
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg, 
                  @cMsg01, 
                  @cMsg02, 
                  @cMsg03, 
                  @cMsg04, 
                  @cMsg05, 
                  @cMsg06, 
                  @cMsg07, 
                  @cMsg08, 
                  @cMsg09, 
                  @cMsg10
         END
      END
   END
   
   Quit:
END

GO