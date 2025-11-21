SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_701ExtValidSP02                                 */
/* Purpose: Validate Loc & User ID for rdtfnc_Clock_In_Out              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-09-23 1.0  James      WMS-20830. Created                        */
/* 2022-11-17 1.1  James      WMS-21172 Add new validation (james01)    */
/************************************************************************/

CREATE   PROC [RDT].[rdt_701ExtValidSP02] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cLocation   NVARCHAR( 10),
   @cUserID     NVARCHAR( 18),
   @cClickCnt   NVARCHAR( 1),
   @nErrNo      INT       OUTPUT,
   @cErrMsg     CHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cUDF05      NVARCHAR( 60)
   DECLARE @cStatus     NVARCHAR( 10) = ''
   
   IF @nFunc <> 701
      GOTO Quit

   IF @nInputKey = 1 
   BEGIN
   	IF @nStep = 1
   	BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                         WHERE ListName = 'WATLOC'
                         AND   Code = @cLocation)
         BEGIN
            SET @nErrNo = 191951  -- Invalid LOC
            GOTO Quit
         END
   	END
   	
   	IF @nStep = 2
   	BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                         WHERE ListName = 'WATUSER'
                         AND   Code = @cUserID)
         BEGIN
            SET @nErrNo = 191952  -- Invalid User
            GOTO Quit
         END

         SELECT TOP 1 @cUDF05 = UDF05 
         FROM dbo.CODELKUP WITH (NOLOCK) 
         WHERE ListName = 'WATLOC' 
         AND   Code = @cLocation 
         AND   Storerkey = @cStorerKey 
         ORDER BY 1
      
         IF @cUDF05 = 'HROF'
         BEGIN
            SELECT TOP 1 @cStatus = [Status] 
            FROM rdt.rdtWATLog WITH (NOLOCK) 
            WHERE Module = 'JOBCAPTURE' 
            AND   UserName = @cUserID 
            ORDER BY EditDate DESC
         
            IF ISNULL( @cStatus, '') NOT IN ('9','')
            BEGIN
               SET @nErrNo = 191953  -- Job Not Done
               GOTO Quit
            END

            -- (james01)
            SELECT TOP 1 @cStatus = WL.STATUS
            FROM RDT.rdtWATLog WL WITH (NOLOCK)   
            JOIN RDT.RDTWatTeamLog WRL WITH (NOLOCK) ON ( WL.ROWREF = WRL.UDF01)
            WHERE WRL.MEMBERUSER = @cUserID
            ORDER BY WL.EditDate DESC  

            IF ISNULL( @cStatus, '') NOT IN ('9','')
            BEGIN
               SET @nErrNo = 191954  -- 707 Job Not Done
               GOTO Quit
            END
         END
   	END
   END

QUIT:



GO