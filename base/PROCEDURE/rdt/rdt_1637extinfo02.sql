SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1637ExtInfo02                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Display remining pallet to scan                             */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2018-12-05 1.0  ChewKP   WMS-7072 Created                            */   
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1637ExtInfo02]    
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cStorerkey                NVARCHAR( 15), 
   @cContainerKey             NVARCHAR( 10), 
   @cContainerNo              NVARCHAR( 20), 
   @cMBOLKey                  NVARCHAR( 10), 
   @cSSCCNo                   NVARCHAR( 20), 
   @cPalletKey                NVARCHAR( 30), 
   @cTrackNo                  NVARCHAR( 20), 
   @cOption                   NVARCHAR( 1), 
   @cExtendedInfo1            NVARCHAR( 20) OUTPUT   

AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @nScanCnt    INT
          ,@nTotalCnt   INT
          ,@cUserName   NVARCHAR(18) 
   
   SELECT @cUserName = UserName 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
             

   SELECT @nScanCnt = COUNT (DISTINCT PalletKey)
   FROM dbo.ContainerDetail WITH (NOLOCK) 
   WHERE ContainerKey = @cContainerKey
   AND AddWho = @cUserName 
   
   SELECT @nTotalCnt = COUNT(DISTINCT PalletKey) 
   FROM dbo.CONTAINERDETAIL WITH (NOLOCK)
   WHERE ContainerKey = @cContainerKey

--
--   IF rdt.rdtIsValidQty( @cScanCnt, 1) = 0
--      SET @nScanCnt = 0
--   ELSE
--      SET @nScanCnt = CAST( @nScanCnt AS INT)

   --SET @cExtendedInfo1 = 'TTL/REMAIN: ' + CAST( @nSeal02 AS NVARCHAR( 5)) + '/' + CAST( ( @nSeal02 - @nScanCnt) AS NVARCHAR( 5))
   SET @cExtendedInfo1 = 'TTL:' + CAST( ( @nTotalCnt) AS NVARCHAR( 5) ) -- + '/' +  CAST( ( @nScanCnt) AS NVARCHAR( 5) ) 
   
QUIT:    
END -- End Procedure  

GO