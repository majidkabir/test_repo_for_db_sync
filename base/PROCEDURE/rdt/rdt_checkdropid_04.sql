SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CheckDropID_04                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check Drop ID scanned (SOS300405)                           */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick/rdtfnc_PickAndPack                  */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 20-Jan-2014 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_CheckDropID_04] (
   @cFacility                 NVARCHAR( 5),
   @cStorerKey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cDropID                   NVARCHAR( 18),
   @nValid                    INT          OUTPUT, 
   @nErrNo                    INT          OUTPUT, 
   @cErrMsg     				 NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success INT
   DECLARE @n_err		 INT
   DECLARE @c_errmsg  NVARCHAR( 250)
   
   DECLARE @cLoadKey    NVARCHAR( 10)
   
   SET @nValid = 1
   
   IF ISNULL( @cFacility, '') = ''
   BEGIN
      SET @nValid = 0
      GOTO Quit
   END
   
   SELECT @cLoadKey = LoadKey FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   
   IF ISNULL( @cLoadKey, '') = ''
   BEGIN
      SET @nValid = 0
      GOTO Quit
   END
   
   -- 1.	Check existing Drop ID in other Loadkey found.
   IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD (NOLOCK) 
               JOIN dbo.LoadPlanDetail LPD (NOLOCK) ON PD.OrderKey = LPD.OrderKey 
               WHERE PD.DropID = @cDropID 
               AND   PD.StorerKey = @cStorerKey
               AND   LPD.LoadKey <> @cLoadKey)
   BEGIN
      SET @nValid = 0
      GOTO Quit
   END

   -- 3.	Check Entire length of the DROP ID 10 size
   IF LEN( LTRIM( RTRIM( @cDropID))) <> 10
   BEGIN
      SET @nValid = 0
      GOTO Quit
   END
   
   -- 4.	Check position 3 to 10 [ substring (DROP ID, 3, 8)] all digit
   IF ISNUMERIC ( SUBSTRING( LTRIM( RTRIM( @cDropID)), 3, 8)) <> 1 
   BEGIN
      SET @nValid = 0
      GOTO Quit
   END

   /*
   5.	Storerkey & Facility checking [Since there is multiple facility for single storer] 
   Existing setup with live example
   a)	Bonded-Facility = KV,  
   i.	Storerkey =NIKEMY [ eg  Drop ID MY14078804]
   ii.	Storerkey =NIKESG  [ eg  Drop ID SG13076539]
   b)	Non Bond
   i.	Facility = SKEE , Storerkey =NIKESG [ eg  Drop ID SK13919103]
   ii.	Facility = KVNB , Storerkey =NIKEMY [ eg  Drop ID MY13919103]
   */

   IF @cFacility = 'KV' 
   BEGIN
      IF @cStorerKey = 'NIKEMY' AND SUBSTRING( LTRIM( RTRIM( @cDropID)), 1, 2) <> 'MY'
      BEGIN
         SET @nValid = 0
         GOTO Quit
      END

      IF @cStorerKey = 'NIKESG' AND SUBSTRING( LTRIM( RTRIM( @cDropID)), 1, 2) <> 'SG'
      BEGIN
         SET @nValid = 0
         GOTO Quit
      END
   END

   IF @cFacility = 'SKEE' 
   BEGIN
      IF @cStorerKey = 'NIKESG' AND SUBSTRING( LTRIM( RTRIM( @cDropID)), 1, 2) <> 'SK'
      BEGIN
         SET @nValid = 0
         GOTO Quit
      END
   END

   IF @cFacility = 'KVNB' 
   BEGIN
      IF @cStorerKey = 'NIKEMY' AND SUBSTRING( LTRIM( RTRIM( @cDropID)), 1, 2) <> 'MY'
      BEGIN
         SET @nValid = 0
         GOTO Quit
      END
   END

   Quit:
END

GO