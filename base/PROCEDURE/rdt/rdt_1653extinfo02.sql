SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653ExtInfo02                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Display # of orders packed/not pack                         */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-10-05  1.0  James    WMS-20667. Created                         */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1653ExtInfo02] (    
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTrackNo       NVARCHAR( 40),
   @cOrderKey      NVARCHAR( 20),
   @cPalletKey     NVARCHAR( 20),
   @cMBOLKey       NVARCHAR( 10),
   @cLane          NVARCHAR( 20),
   @tExtInfoVar    VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cStatus           NVARCHAR( 10)
   DECLARE @cUDF03            NVARCHAR( 60)
   DECLARE @fMinHeight        FLOAT = 0
   DECLARE @fMaxHeight        FLOAT = 0
   DECLARE @nScannedCnt       INT = 0
   DECLARE @cPack             NVARCHAR( 10)
   
   IF @nAfterStep IN ( 2, 3, 4)
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	
         SELECT @cStatus = STATUS
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         IF @cStatus < '5'
            SET @cPack = 'X PACKED'
         ELSE
         	SET @cPack = 'PACKED'
         
         SELECT @nScannedCnt = COUNT(1) 
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   PalletKey = @cPalletKey
         AND   [STATUS] < '9'
         
         --CTN#:9999 | X PACKED
         SET @cExtendedInfo = 'CTN#:' + CAST( @nScannedCnt AS NVARCHAR( 4)) + ' | ' + @cPack
      END	
   END
   
   IF @nAfterStep = 6   -- Only go back step 1 need show ctn count
   BEGIN
      IF @nInputKey = 1 -- Enter
      BEGIN
         --UDF03 = empty pallet height
   	   SELECT 
   	      @cUDF03 = UDF03
   	   FROM dbo.CODELKUP WITH (NOLOCK) 
   	   WHERE LISTNAME = 'ADIPLTDM'
   	   AND   Storerkey = @cStorerkey
   	   AND   CHARINDEX( Code, @cPalletKey) > 0

         IF @@ROWCOUNT = 0
         BEGIN
   	      SELECT 
   	         @cUDF03 = UDF03
   	      FROM dbo.CODELKUP WITH (NOLOCK) 
   	      WHERE LISTNAME = 'ADIPLTDM'
   	      AND   Storerkey = @cStorerkey
   	      AND   CODE = 'DEFAULT'
         END
         
         SELECT 
            @fMinHeight =  CAST( @cUDF03 AS FLOAT) + CAST(MIN(Height) AS FLOAT) * (CASE WHEN CEILING(COUNT(1) / 4.0) > 0 THEN CEILING(COUNT(1) / 4.0) ELSE 1 END), --'Estimated Min Height (CM)'
            @fMaxHeight =  CAST( @cUDF03 AS FLOAT) + CAST(MAX(Height) AS FLOAT) * (CASE WHEN CEILING(COUNT(1) / 4.0) > 0 THEN CEILING(COUNT(1) / 4.0) ELSE 1 END)  --'Estimated Max Height (CM)'   
         FROM dbo.PALLETDETAIL PLD WITH (NOLOCK)
         CROSS APPLY (
         SELECT DISTINCT LABELNO, LENGTH, WIDTH, HEIGHT FROM dbo.PACKDETAIL PD WITH (NOLOCK) 
         JOIN dbo.PACKINFO PI WITH (NOLOCK) ON PI.PICKSLIPNO = PD.PICKSLIPNO AND PI.CartonNo = PD.CartonNo
         WHERE PD.LABELNO = PLD.CASEID 
         AND PLD.STORERKEY = PD.STORERKEY 
         ) PD
         WHERE PLD.STORERKEY = @cStorerKey
         AND PalletKey = @cPalletKey
         GROUP BY PALLETKEY
         
         SET @cExtendedInfo = '(MIN|MAX): ' + CAST( @fMinHeight AS NVARCHAR( 5)) + '|' + CAST( @fMaxHeight AS NVARCHAR( 5))
      END
   END
   GOTO Quit
   
   Quit:  
    
END    

GO