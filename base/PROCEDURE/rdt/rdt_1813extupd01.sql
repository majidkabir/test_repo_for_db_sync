SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1813ExtUpd01                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 14-06-2017  1.0  ChewKP   WMS-2180 Created                           */
/* 12-04-2019  1.1  James    WMS-8638 Delete container record for from  */
/*                           id (james01)                               */
/************************************************************************/

CREATE PROC [RDT].[rdt_1813ExtUpd01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFromID          NVARCHAR( 20), 
   @cOption          NVARCHAR( 1), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @cToID            NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cContainerKey        NVARCHAR( 10)
   DECLARE @cContainerLineNumber NVARCHAR( 5)

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1813ExtUpd01   
   
   DECLARE @cPalletLineNumber NVARCHAR(5) 
          ,@cCaseID           NVARCHAR(20)
          ,@cPalletSKU        NVARCHAR(20)
          ,@cLoc              NVARCHAR(10)
          ,@cStatus           NVARCHAR(10) 
          ,@cUserDefine01     NVARCHAR(30)
          ,@cUserDefine02     NVARCHAR(30)
          ,@nEmptyPallet      INT

          
   SET @nEmptyPallet = 0 

   IF @nFunc = 1813 -- Scan to pallet
   BEGIN
      
      IF @nStep IN ( 5 , 7 )  -- Merge entire Pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            
            UPDATE dbo.Pallet WITH (ROWLOCK) 
            SET Status = '0' , TrafficCop = NULL
            WHERE StorerKey = @cStorerKey
            AND PalletKey = @cFromID 

            IF @@ERROR <> 0 
            BEGIN 
                SET @nErrNo = 111004
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPalletFail
                GOTO RollbackTran
            END

            UPDATE dbo.PalletDetail WITH (ROWLOCK) 
            SET Status = '0' , TrafficCop = NULL
            WHERE StorerKey = @cStorerKey
            AND PalletKey = @cFromID 

            IF @@ERROR <> 0 
            BEGIN 
                SET @nErrNo = 111006
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPalletFail
                GOTO RollbackTran
            END

            IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND PalletKey = @cToID )
            BEGIN 
               UPDATE dbo.Pallet WITH (ROWLOCK) 
               SET Status = '0' , TrafficCop = NULL
               WHERE StorerKey = @cStorerKey
               AND PalletKey = @cToID 

               IF @@ERROR <> 0 
               BEGIN 
                   SET @nErrNo = 111007
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPalletFail
                   GOTO RollbackTran
               END
            END
            ELSE
            BEGIN
               SET @nEmptyPallet = 1 
               INSERT INTO Pallet ( PalletKey, StorerKey, Status) 
               VALUES ( @cToID, @cStorerKey, '0')
               
               IF @@ERROR <> 0 
               BEGIN 
                   SET @nErrNo = 111010
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPalletFail
                   GOTO RollbackTran
               END 
            END

            UPDATE dbo.PalletDetail WITH (ROWLOCK) 
            SET Status = '0' , TrafficCop = NULL
            WHERE StorerKey = @cStorerKey
            AND PalletKey = @cToID 

            IF @@ERROR <> 0 
            BEGIN 
                SET @nErrNo = 111008
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPalletFail
                GOTO RollbackTran
            END

            DECLARE CUR_PALLET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PalletLineNumber, CaseID, SKU, Loc, Qty, Status, UserDefine01, UserDefine02 
            FROM dbo.PalletDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND PalletKey = @cFromID
            --AND Status <> '9'
            
            OPEN CUR_PALLET 
            FETCH NEXT FROM CUR_PALLET INTO @cPalletLineNumber, @cCaseID, @cPalletSKU, @cLoc, @nQty, @cStatus, @cUserDefine01, @cUserDefine02              
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               

               UPDATE dbo.PalletDetail WITH (ROWLOCK) 
               SET Status = '0' , TrafficCop = NULL
               WHERE StorerKey      = @cStorerKey
               AND PalletKey        = @cFromID
               AND PalletLineNumber = @cPalletLineNumber
               AND CaseID           = @cCaseID
               AND SKU              = @cPalletSKU
               AND Loc              = @cLoc
               
               IF @@ERROR <> 0 
               BEGIN 
                   SET @nErrNo = 111005
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelPalletDetFail
                   GOTO RollbackTran
               END

               
               
               INSERT INTO PalletDetail ( PalletKey, PalletLineNumber, CaseID, StorerKey, SKU, Loc, Qty, Status, UserDefine01, UserDefine02 ) 
               VALUES ( @cToID, '0', @cCaseID, @cStorerKey, @cPalletSKU, @cLoc, @nQty, '0', @cUserDefine01, @cUserDefine02) 
               
               IF @@ERROR <> 0 
               BEGIN 
                   SET @nErrNo = 111001
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPalletDetFail
                   GOTO RollbackTran
               END


               

               DELETE FROM dbo.PalletDetail WITH (ROWLOCK) 
               WHERE StorerKey      = @cStorerKey
               AND PalletKey        = @cFromID
               AND PalletLineNumber = @cPalletLineNumber
               AND CaseID           = @cCaseID
               AND SKU              = @cPalletSKU
               AND Loc              = @cLoc
               
               IF @@ERROR <> 0 
               BEGIN 
                   SET @nErrNo = 111002
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelPalletDetFail
                   GOTO RollbackTran
               END
               
               FETCH NEXT FROM CUR_PALLET INTO @cPalletLineNumber, @cCaseID, @cPalletSKU, @cLoc, @nQty, @cStatus, @cUserDefine01, @cUserDefine02 
            END
            CLOSE CUR_PALLET
            DEALLOCATE CUR_PALLET 

            

            DELETE FROM dbo.Pallet WITH (ROWLOCK) 
            WHERE StorerKey = @cStorerKey
            AND PalletKey = @cFromID 
            
            IF @@ERROR <> 0 
            BEGIN 
                SET @nErrNo = 111003
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelPalletFail
                GOTO RollbackTran
            END
            
            IF @nEmptyPallet = 0 
            BEGIN
               UPDATE dbo.Pallet WITH (ROWLOCK) 
               SET Status = '9'
               WHERE PalletKey = @cToID
               
               IF @@ERROR <> 0 
               BEGIN 
                   SET @nErrNo = 111009
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPalletFail
                   GOTO RollbackTran
               END
            END
            
            -- (james01)
            SELECT @cContainerKey = ContainerKey, 
                   @cContainerLineNumber = ContainerLineNumber
            FROM dbo.CONTAINERDETAIL WITH (NOLOCK) 
            WHERE PalletKey = @cFromID
            ORDER BY 1 DESC

            IF ISNULL( @cContainerKey, '') <> ''
            BEGIN
               DELETE FROM dbo.CONTAINERDETAIL 
               WHERE ContainerKey = @cContainerKey 
               AND   ContainerLineNumber = @cContainerLineNumber

               IF @@ERROR <> 0 
               BEGIN 
                   SET @nErrNo = 111011
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelContainFail
                   GOTO RollbackTran
               END
            END
         END
      END

   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1813ExtUpd01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END


GO