SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_823ExtUpd01                                     */
/* Purpose: Insert SKUxLOCIntegrity with sku in the loc (system wise)   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-09-30 1.0  James      SOS375153. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_823ExtUpd01] (
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

   DECLARE @nTranCount     INT
   DECLARE @cSL_SKU        NVARCHAR( 20)
   DECLARE @nSL_Qty        INT
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cUserName      NVARCHAR( 18)
   
   SELECT @cFacility = Facility, @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @nTranCount = @@TRANCOUNT    

   BEGIN TRAN    
   SAVE TRAN rdt_823ExtUpd01    

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
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins err'
            GOTO RollbackTran
         END

         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SKU, ISNULL( SUM( Qty - QtyPicked), 0)
         FROM dbo.SKUxLOC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   LOC = @cLOC
         GROUP BY SKU
         HAVING ISNULL( SUM( Qty - QtyPicked), 0) > 0
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cSL_SKU, @nSL_Qty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, EntryValue, ID, QtyCount, EditWho, EditDate, Qty)
            VALUES(@cFacility, @cLOC, @cStorerKey, @cSL_SKU, @cCountNo, 0, @cUserName, GETDATE(), @nSL_Qty)
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 104652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Del err'
               GOTO RollbackTran
            END

            FETCH NEXT FROM CUR_LOOP INTO @cSL_SKU, @nSL_Qty
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
      END
   END


   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_823ExtUpd01  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

GO