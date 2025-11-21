SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_823DataCapture01                                */
/* Purpose: Called from rdtfnc_DataCapture8. Insert Skuxlocintegrity    */
/*          with qty from SKUxLOC table.                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-08-29 1.0  James      SOS375153. Created                        */
/* 2016-11-24 1.1  James      Add editdate, editwho when update(james01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_823DataCapture01] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nInputKey       INT, 
   @nStep           INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cCountNo        NVARCHAR( 5),  
   @cLOC            NVARCHAR( 10), 
   @cSKU            NVARCHAR( 20), 
   @nErrNo          INT            OUTPUT, 
   @cErrMsg         NVARCHAR( 20)  OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nStartTCnt     INT
   
   DECLARE @cFacility      NVARCHAR( 5),
           @cUserName      NVARCHAR( 18),
           @nQtyOnHand     INT
   
   SELECT @cFacility = Facility,
          @cUserName = UserName
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @nStartTCnt = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_823DataCapture01  
   
   SET @nErrNo = 0

   SET @nQtyOnHand=0  
   SELECT @nQtyOnHand = ISNULL(Qty - QtyPicked, 0)  
   FROM  dbo.SKUxLOC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey 
   AND   Sku = @cSKU
   AND   Loc = @cLOC 

   IF @cSKU <> 'EMPTYLOC'
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.SKUxLOCIntegrity WITH (NOLOCK) 
                  WHERE ID = @cCountNo
                  AND   LOC = @cLOC
                  AND   EntryValue = @cSKU)
      BEGIN
         INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, EntryValue, ID, QtyCount, EditWho, EditDate, Qty)
         VALUES(@cFacility, @cLOC, @cStorerKey, @cSKU, @cCountNo, 1, @cUserName, GETDATE(), @nQtyOnHand)
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 103351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins err'
            GOTO RollbackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.SKUxLOCIntegrity WITH (ROWLOCK)
            SET QtyCount = QtyCount + 1,
            Qty = @nQtyOnHand,
            EditWho = sUser_sName(),   -- (james01)
            EditDate = GETDATE()       -- (james01)
         WHERE ID = @cCountNo
         AND   LOC = @cLOC
         AND   EntryValue = @cSKU

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 103352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd err'
            GOTO RollbackTran
         END
      END
   END
   ELSE
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.SKUxLOCIntegrity WITH (NOLOCK) 
                  WHERE ID = @cCountNo
                  AND   LOC = @cLOC
                  AND   EntryValue = @cSKU)
      BEGIN
         INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, EntryValue, ID, QtyCount, EditWho, EditDate, Qty)
         VALUES(@cFacility, @cLOC, @cStorerKey, 'EMPTYLOC', @cCountNo, 0, @cUserName, GETDATE(), 0)
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 103353
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins err'
            GOTO RollbackTran
         END
      END
   END
   
   GOTO Quit

   RollbackTran:
      ROLLBACK TRAN rdt_823DataCapture01  
  
   Quit:
   WHILE @@TRANCOUNT > @nStartTCnt -- Commit until the level we started  
      COMMIT TRAN rdt_823DataCapture01  

GO