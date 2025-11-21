SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1637ExtInfo01                                   */    
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
/* 2016-05-26 1.0  James    SOS365910 Created                           */   
/* 2017-10-02 1.1  Ung      WMS-3128 Fix PalletKey to 30 chars          */ 
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1637ExtInfo01]    
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
       
   DECLARE @nScanCnt    INT,
           @nSeal02     INT,
           @cSeal02     NVARCHAR( 30),
           @cScanCnt    NVARCHAR( 5)

   SELECT @cSeal02 = Seal02
   FROM dbo.CONTAINER WITH (NOLOCK)
   WHERE ContainerKey = @cContainerKey

   SELECT @cScanCnt = COUNT(DISTINCT PalletKey) 
   FROM dbo.CONTAINERDETAIL WITH (NOLOCK)
   WHERE ContainerKey = @cContainerKey

   IF rdt.rdtIsValidQty( @cSeal02, 1) = 0
      SET @nSeal02 = 0
   ELSE
      SET @nSeal02 = CAST( @cSeal02 AS INT)

   IF rdt.rdtIsValidQty( @cScanCnt, 1) = 0
      SET @nScanCnt = 0
   ELSE
      SET @nScanCnt = CAST( @cScanCnt AS INT)

   SET @cExtendedInfo1 = 'TTL/REMAIN: ' + CAST( @nSeal02 AS NVARCHAR( 5)) + '/' + CAST( ( @nSeal02 - @nScanCnt) AS NVARCHAR( 5))

QUIT:    
END -- End Procedure  

GO