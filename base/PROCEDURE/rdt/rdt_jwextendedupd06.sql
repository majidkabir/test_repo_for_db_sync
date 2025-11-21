SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_JWExtendedUpd06                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Add TNTSHPREQ into TL3 once truck is sealed                 */
/*                                                                      */
/* Called from: rdtfnc_ScanToTruck_Pallet                               */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-01-2015  1.0  James       SOS331117 - Created                     */
/* 14-07-2015  1.1  James       Only inc Store Mbol only (james01)      */
/************************************************************************/

CREATE PROC [RDT].[rdt_JWExtendedUpd06] (
   @nMobile                   INT, 
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3), 
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerKey                NVARCHAR( 15), 
   @cTruckID                  NVARCHAR( 20), 
   @cPalletID                 NVARCHAR( 20), 
   @cSealNo                   NVARCHAR( 20), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT    
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_TranCount    INT, 
           @b_success      INT, 
           @n_err          INT,  
           @c_errmsg       NVARCHAR( 250)  

   DECLARE @cMBOLKey  NVARCHAR (10),        
           @cSackID  NVARCHAR( 20)        
           
   SET @n_TranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_JWExtendedUpd06

   SELECT TOP 1 @cMBOLKey = Userdefine03 
   FROM dbo.PalletDetail PLD WITH (NOLOCK) 
   JOIN dbo.Pallet P WITH (NOLOCK) ON (PLD.PalletKey = P.PalletKey)
   WHERE P.PalletKey = @cPalletID
   AND   P.Status = '9'
   AND   PLD.UserDefine04 <> 'ECOMM'   -- (james01)

   IF EXISTS ( SELECT 1 FROM rdt.rdtScanToTruck R WITH (NOLOCK) 
               WHERE R.MbolKey = @cMBOLKey
               AND   R.Status < '9'
               AND   R.CartonType = 'STORE'
               AND   EXISTS ( SELECT 1 FROM dbo.Container C WITH (NOLOCK) 
                              JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON C.ContainerKey = CD.ContainerKey 
                              WHERE C.MbolKey = R.MbolKey
                              AND   R.URNNo   = CD.PalletKey 
                              AND   C.Vessel  = @cTruckID
                              AND   C.Seal01  = @cSealNo
                              AND   C.Status  = '9')) 
   BEGIN
      SET @nErrNo = 92701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet ID
      GOTO Quit
   END

   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT DISTINCT REFNO FROM rdt.rdtScanToTruck R WITH (NOLOCK) 
   WHERE MBOLKey = @cMBOLKey
   AND   [Status] = '9'
   AND   CartonType = 'STORE'
   AND   NOT EXISTS ( SELECT 1 FROM dbo.TransmitLog2 TL2 WITH (NOLOCK) WHERE R.REFNO = TL2.KEY1 AND KEY3 = @cStorerKey)
   AND   EXISTS ( SELECT 1 FROM dbo.Container C WITH (NOLOCK) 
                  JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON C.ContainerKey = CD.ContainerKey 
                  WHERE C.MbolKey = R.MbolKey
                  AND R.URNNo = CD.PalletKey                  
                  AND C.Vessel = @cTruckID
                  AND C.Seal01 = @cSealNo
                  AND C.Status = '9')   
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cSackID
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Insert transmitlog3 here
      EXEC ispGenTransmitLog2 'TNTSHPREQ', @cSackID, '', @cStorerkey, '' 
      , @b_success OUTPUT    
      , @n_err OUTPUT    
      , @c_errmsg OUTPUT    

      IF @b_success <> 1    
      BEGIN    
         SET @nErrNo = @n_err   
         SET @cErrMsg = @c_errmsg 
         GOTO RollBackTran
      END    

      FETCH NEXT FROM CUR_LOOP INTO @cSackID
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_JWExtendedUpd06  
   Quit:  
      WHILE @@TRANCOUNT > @n_TranCount  
         COMMIT TRAN  
END

GO