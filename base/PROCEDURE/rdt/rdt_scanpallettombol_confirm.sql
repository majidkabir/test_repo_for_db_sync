SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ScanPalletToMBOL_Confirm                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert Mboldetail                                           */
/*                                                                      */
/* Called from: rdtfnc_Scan_Pallet_To_Mbol                              */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-07-02   1.0  James    WMS9541. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_ScanPalletToMBOL_Confirm] (
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
   DECLARE @cCaseID        NVARCHAR( 20)
   DECLARE @cLoadKey       NVARCHAR( 10)

   SET @nErrNo = 0

   -- Variable mapping
   SELECT @cMbolKey = Value FROM @tScanPalletToMBOL WHERE Variable = '@cMbolKey'
   SELECT @cPalletID = Value FROM @tScanPalletToMBOL WHERE Variable = '@cPalletID'


   -- Get extended ExtendedPltBuildCfmSP
   DECLARE @cScanPalletToMBOLCfmSP NVARCHAR(20)
   SET @cScanPalletToMBOLCfmSP = rdt.rdtGetConfig( @nFunc, 'ScanPalletToMBOLCfmSP', @cStorerKey)
   IF @cScanPalletToMBOLCfmSP = '0'
      SET @cScanPalletToMBOLCfmSP = ''  

   -- Extended putaway
   IF @cScanPalletToMBOLCfmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cScanPalletToMBOLCfmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cScanPalletToMBOLCfmSP) +
            ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @tScanPalletToMBOL, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile            INT,                  ' +
            '@nFunc              INT,                  ' +
            '@cLangCode          NVARCHAR( 3),         ' +
            '@cStorerKey         NVARCHAR( 15),        ' +
            '@cFacility          NVARCHAR( 5),         ' + 
            '@tScanPalletToMBOL  VariableTable READONLY, ' +
            '@nErrNo             INT           OUTPUT, ' +
            '@cErrMsg            NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @tScanPalletToMBOL, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Fail
      END
   END
   ELSE
   BEGIN
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_ScanPalletToMBOL_Confirm   

      DECLARE @curORD CURSOR  
      SET @curORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT CaseID
      FROM dbo.PalletDetail WITH (NOLOCK)
      WHERE PalletKey = @cPalletID
      OPEN @curORD
      FETCH NEXT FROM @curORD INTO @cCaseID
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT TOP 1 @cOrderKey = PH.OrderKey
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         WHERE PH.StorerKey = @cStorerKey
         AND   PD.LabelNo = @cCaseID
         ORDER BY 1

         IF NOT EXISTS ( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
         BEGIN
            SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

            INSERT INTO dbo.MBOLDetail   
               (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate)
            VALUES   
               (@cMBOLKey, '00000', @cOrderKey, @cLoadKey, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 141701  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtl Fail  
               GOTO RollbackTran  
            END  
         END

         FETCH NEXT FROM @curORD INTO @cCaseID
      END

      GOTO QUIT

      RollBackTran:
         ROLLBACK TRAN rdt_ScanPalletToMBOL_Confirm -- Only rollback change made here

      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN rdt_ScanPalletToMBOL_Confirm  
   END
   Fail:
END

GO