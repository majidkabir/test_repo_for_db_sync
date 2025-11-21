SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_JWExtendedUpd02                                 */
/* Purpose: To update orderuserdefine09 with alpha characters           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-18 1.0  James      SOS#318417. Created                       */
/* 2015-07-31 1.1  James      SOS#348965. Insert sack id into SerialNo  */
/*                            table (james01)                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_JWExtendedUpd02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),   
   @cCaseID          NVARCHAR( 18), 
   @cLOC             NVARCHAR( 10), 
   @cSKU             NVARCHAR( 20), 
   @cConsigneekey    NVARCHAR( 15), 
   @nQTY             INT, 
   @cToToteNo        NVARCHAR( 18), 
   @cSuggPTSLOC      NVARCHAR( 10), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nTranCount        INT, 
           @cOrderKey         NVARCHAR( 10), 
           @cOrderLineNumber  NVARCHAR( 5), 
           @cProductInfo      NVARCHAR( 18), 
           @cPattern          NVARCHAR( 50)  
           

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_JWExtendedUpd02

   IF NOT EXISTS ( SELECT 1 FROM dbo.SerialNo WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   SerialNo = @cToToteNo)
   BEGIN
      INSERT INTO dbo.SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty) VALUES
      (@cToToteNo, '', '', @cStorerKey, '', @cToToteNo, 0)

      IF @@ERROR <> 0
         GOTO RollBackTran
   END

   SET @cProductInfo = @cSuggPTSLOC
   SET @cPattern  = '%[^a-z]%'
   WHILE PATINDEX(@cPattern, @cProductInfo) > 0
      SET @cProductInfo = STUFF(@cProductInfo, PATINDEX(@cPattern, @cProductInfo), 1, '')

   IF ISNULL( @cProductInfo, '') = ''
      GOTO Quit

   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT PD.OrderKey, PD.OrderLineNumber 
   FROM dbo.PickDetail PD WITH (NOLOCK) 
   JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
   JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = PD.AltSKU AND D.LoadKey = O.LoadKey)
   WHERE D.DropID = @cToToteNo
   AND   PD.StorerKey = @cStorerKey
   AND   PD.Status = '5'
   ORDER BY 2
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cOrderLineNumber
   BEGIN
      -- INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3) VALUES ('PTS', GETDATE(), @cProductInfo, @cOrderKey, @cOrderLineNumber)

      UPDATE dbo.OrderDetail WITH (ROWLOCK) SET 
          UserDefine09 = CASE WHEN ISNULL( UserDefine09, '') = '' THEN @cProductInfo ELSE UserDefine09 END, 
          TRAFFICCOP = NULL
      WHERE OrderKey = @cOrderKey 
      AND   OrderLineNumber = @cOrderLineNumber
      
      IF @@ERROR <> 0
         GOTO RollBackTran
      
      FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cOrderLineNumber
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   GOTO Quit
   

   RollBackTran:
   ROLLBACK TRAN rdt_JWExtendedUpd02
   
QUIT:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_JWExtendedUpd02

GO