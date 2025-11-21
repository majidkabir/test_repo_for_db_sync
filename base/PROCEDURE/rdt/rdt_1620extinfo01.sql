SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1620ExtInfo01                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Under Armour Extended info to show COO (Lottable08)         */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2015-06-29 1.0  James    SOS342111 Created                           */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1620ExtInfo01]    
   @nMobile       INT, 
   @nFunc         INT,       
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,
   @nInputKey     INT,
   @cWaveKey      NVARCHAR( 10), 
   @cLoadKey      NVARCHAR( 10), 
   @cOrderKey     NVARCHAR( 10), 
   @cDropID       NVARCHAR( 15), 
   @cStorerKey    NVARCHAR( 15), 
   @cSKU          NVARCHAR( 20), 
   @cLOC          NVARCHAR( 10), 
   @cExtendedInfo NVARCHAR( 20) OUTPUT 

AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE 
           
           @cCOO           NVARCHAR( 30),
           @cLOT           NVARCHAR( 10),
           @cUserName      NVARCHAR( 18)

   SET @cExtendedInfo = ''

   IF ISNULL( @cOrderKey, '') = ''
      SELECT @cOrderKey = V_OrderKey, 
             @cUserName = UserName 
      FROM rdt.rdtMobrec WITH (NOLOCK) 
      WHERE Mobile = @nMobile
   ELSE
      SELECT @cUserName = UserName 
      FROM rdt.rdtMobrec WITH (NOLOCK) 
      WHERE Mobile = @nMobile

   SELECT TOP 1 @cLOT = LOT
   FROM RDT.RDTPICKLOCK WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
      AND StorerKey = @cStorerKey 
      AND SKU = @cSKU
      AND LOC = @cLOC
      AND Status = '1'
      AND AddWho = @cUserName

   IF ISNULL( @cLOT, '') <> ''
   BEGIN
      SELECT @cCOO = Lottable08 
      FROM dbo.LotAttribute WITH (NOLOCK) 
      WHERE LOT = @cLOT

      SET @cExtendedInfo = 'COO: ' + SUBSTRING( @cCOO, 1, 16)
   END

   --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5, step1, step2) VALUES 
   --('UA', GETDATE(), @cOrderKey, @cStorerKey, @cSKU, @cLOC, @cUserName, @cLOT, @cCOO)
QUIT:    
END -- End Procedure  

GO