SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_823ExtUpd02                                     */
/* Purpose: Insert SKUxLOCIntegrity with sku in the loc (system wise)   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-04-28 1.0  James      WMS-19359. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_823ExtUpd02] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nInputKey       INT, 
   @nStep           INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cCountNo        NVARCHAR( 18),  
   @cLOC            NVARCHAR( 10), 
   @cSKU            NVARCHAR( 20), 
   @nErrNo          INT            OUTPUT, 
   @cErrMsg         NVARCHAR( 20)  OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @cSL_SKU        NVARCHAR( 20)
   DECLARE @nSL_Qty        INT
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @nSkuxLoc       INT = 0
   DECLARE @cur_SKUxLOC    CURSOR
   DECLARE @nPicked_Qty    INT = 0
   
   SELECT @cFacility = Facility, @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @nTranCount = @@TRANCOUNT    

   BEGIN TRAN    
   SAVE TRAN rdt_823ExtUpd02    

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2  -- LOC
      BEGIN
         -- Clear existing record 1st
         DELETE FROM dbo.SKUxLOCIntegrity 
         WHERE StorerKey = @cStorerKey
         AND   LOC = @cLOC
         AND   ID = @cCountNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 104651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Delete fail'
            GOTO RollbackTran
         END

         SET @cur_SKUxLOC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SKU, ISNULL( SUM( Qty - QtyPicked), 0)
         FROM dbo.SKUxLOC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   LOC = @cLOC
         GROUP BY SKU
         HAVING ISNULL( SUM( Qty - QtyPicked), 0) > 0
         OPEN @cur_SKUxLOC
         FETCH NEXT FROM @cur_SKUxLOC INTO @cSL_SKU, @nSL_Qty
         WHILE @@FETCH_STATUS = 0
         BEGIN
         	SET @nPicked_Qty = 0
         	SELECT @nPicked_Qty = ISNULL( SUM( QTY), 0)
         	FROM dbo.PICKDETAIL WITH (NOLOCK)
         	WHERE Storerkey = @cStorerKey
         	AND   LOC = @cLOC
         	AND   Sku = @cSL_SKU
         	AND   [Status] = '3'
         	
         	SET @nSL_Qty = @nSL_Qty - @nPicked_Qty
         	
            INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, EntryValue, ID, QtyCount, EditWho, EditDate, Qty)
            VALUES(@cFacility, @cLOC, @cStorerKey, @cSL_SKU, @cCountNo, 0, @cUserName, GETDATE(), @nSL_Qty)
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 104652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Insert fail'
               GOTO RollbackTran
            END

            IF @nSkuxLoc = 0
               SET @nSkuxLoc = 1
            
            FETCH NEXT FROM @cur_SKUxLOC INTO @cSL_SKU, @nSL_Qty
         END
         
         IF @nSkuxLoc = 0
         BEGIN
            INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, EntryValue, ID, QtyCount, EditWho, EditDate, Qty)
            VALUES(@cFacility, @cLOC, @cStorerKey, '', @cCountNo, 0, @cUserName, GETDATE(), 0)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 104653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Insert fail'
               GOTO RollbackTran
            END
         END
      END
   END


   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_823ExtUpd02  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

GO