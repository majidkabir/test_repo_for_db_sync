SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1666ExtPltCfm01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdt_PackByCartonID_Confirm                              */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-05-29   1.0  James    WMS9064. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1666ExtPltCfm01] (
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


   SET @nErrNo = 0

   -- Variable mapping
   SELECT @cMbolKey = Value FROM @tScanPalletToMBOL WHERE Variable = '@cMbolKey'
   SELECT @cPalletID = Value FROM @tScanPalletToMBOL WHERE Variable = '@cPalletID'

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1666ExtPltCfm01   

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
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
      BEGIN
         SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

         INSERT INTO dbo.MBOLDetail   
            (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate)
         VALUES   
            (@cMBOLKey, '00000', @cOrderKey, @cLoadKey, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 141651  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtl Fail  
            GOTO RollbackTran  
         END  
      END

      FETCH NEXT FROM @curORD INTO @cOrderKey
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1666ExtPltCfm01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1666ExtPltCfm01

   Fail:
END

GO