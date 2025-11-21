SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1666ExtPltCfm02                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdt_PackByCartonID_Confirm                              */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 2021-11-09   1.0  Chermaine   WMS-18206. Created                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_1666ExtPltCfm02] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5), 
   @tScanPalletToMBOL   VariableTable READONLY, 
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cMbolKey       NVARCHAR( 10)
   DECLARE @cPalletID      NVARCHAR( 30)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cCreateMbol    NVARCHAR( 10)
   DECLARE @cUserdefine01  NVARCHAR( 30)

   SET @nErrNo = 0
   
   SELECT 
      @cCreateMbol = V_String8 
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE mobile = @nMobile

   -- Variable mapping
   SELECT @cMbolKey = Value FROM @tScanPalletToMBOL WHERE Variable = '@cMbolKey'
   SELECT @cPalletID = Value FROM @tScanPalletToMBOL WHERE Variable = '@cPalletID'
   
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1666ExtPltCfm02   
   
   DECLARE @curORD CURSOR  
   SET @curORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT UserDefine02
   FROM dbo.PalletDetail WITH (NOLOCK)
   WHERE PalletKey = @cPalletID
   AND   Status = '9'
   OPEN @curORD
   FETCH NEXT FROM @curORD INTO @cOrderKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
   	IF @cCreateMbol = 'Y'
   	BEGIN
   		SELECT 
            @cUserdefine01 = UserDefine01
         FROM PalletDetail
         WHERE PalletKey = @cPalletID 
         
   		IF EXISTS (SELECT 1 FROM Mbol WITH (NOLOCK) WHERE MbolKey = @cMbolKey AND faciliTy = @cFacility AND DestinationCountry = '' AND TransMethod = '')    
   		BEGIN
   			UPDATE Mbol WITH (ROWLOCK) SET
   			   DestinationCountry = Left(@cUserdefine01,2),
   			   TransMethod = SubString(@cUserdefine01,3, 30) 
   			WHERE MbolKey = @cMbolKey
   			AND Facility = @cFacility
   			
   			IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 178651  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail  
               GOTO RollbackTran  
            END  
   		END
   	END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
      BEGIN
         SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

         INSERT INTO dbo.MBOLDetail   
            (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate)
         VALUES   
            (@cMBOLKey, '00000', @cOrderKey, @cLoadKey, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 178652  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtlFail  
            GOTO RollbackTran  
         END  
      END

      FETCH NEXT FROM @curORD INTO @cOrderKey
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1666ExtPltCfm02

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1666ExtPltCfm02

   Fail:
END

GO