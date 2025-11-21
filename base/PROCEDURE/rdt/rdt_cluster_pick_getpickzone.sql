SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_GetPickZone                        */
/* Purpose: Cluster Pick get pickzone                                   */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 06-Jul-2018 1.0  James      INC0295949 - Created                     */
/* 06-Dec-2018 1.1  James      Bug fix                                  */
/* 20-Jun-2019 1.2  James      Change @nMultiStorer retrieving (james01)*/
/* 05-Oct-2023 1.3  Weikin     JSM-181012 - Change @cUserName           */
/*                             NVARCHAR( 5) to NVARCHAR( 18) (wk01)     */
/************************************************************************/

CREATE   PROC [RDT].[rdt_Cluster_Pick_GetPickZone] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cWaveKey         NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cPickSlipNo      NVARCHAR( 10), 
   @cPutawayZone     NVARCHAR( 10),
   @cFacility        NVARCHAR( 5),
   @cUserName        NVARCHAR( 18),                             --wk01
   @cPickZone        NVARCHAR( 10)  OUTPUT
)
AS

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nMultiStorer     INT

   -- (james01)
   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   IF ISNULL( @cWaveKey, '') <> '' AND ISNULL( @cLoadKey, '') <> ''
   BEGIN
      SELECT TOP 1 @cPickZone = LOC.PickZone
      FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
      JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
      WHERE (( @nMultiStorer = 1) OR ( O.StorerKey = @cStorerKey))
      AND   (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
      AND   (( ISNULL( @cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey)) 
      AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
      AND   LOC.Facility = @cFacility
      AND   PD.Status = '0'
      -- look for pickzone in the same wave+load+orders+putawayzone defined by users
      AND   EXISTS ( SELECT 1 FROM RDT.RDTPickLock RPL1 WITH (NOLOCK) 
                     WHERE RPL1.StorerKey = PD.StorerKey
                     AND   (( ISNULL( @cWaveKey, '') = '') OR ( RPL1.WaveKey = O.UserDefine09))
                     AND   (( ISNULL( @cLoadKey, '') = '') OR ( RPL1.LoadKey = O.LoadKey)) 
                     AND   RPL1.OrderKey = PD.OrderKey
                     AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL1.PutAwayZone = LOC.PutAwayZone))
                     AND   RPL1.Status = '1'
                     AND   RPL1.AddWho = @cUserName)
      -- exclude those pickzone locked by other user in same orderkey (different orderkey allow)
      AND   NOT EXISTS ( SELECT 1 FROM RDT.RDTPickLock RPL2 WITH (NOLOCK)
                           WHERE PD.OrderKey = RPL2.OrderKey
                           AND   LOC.PickZone = RPL2.PickZone
                           AND   RPL2.AddWho <> @cUserName
                           AND   RPL2.StorerKey = PD.Storerkey
                           AND   RPL2.Status = '1' )
      ORDER BY LOC.PickZone
   END
   ELSE IF ISNULL( @cWaveKey, '') <> '' AND ISNULL( @cLoadKey, '') = ''
   BEGIN
      SELECT TOP 1 @cPickZone = LOC.PickZone
      FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
      JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
      WHERE (( @nMultiStorer = 1) OR ( PD.StorerKey = @cStorerKey))
      AND   WD.WaveKey = @cWaveKey
      AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
      AND   LOC.Facility = @cFacility
      AND   PD.Status = '0'
      -- look for pickzone in the same wave+load+orders+putawayzone defined by users
      AND   EXISTS ( SELECT 1 FROM RDT.RDTPickLock RPL1 WITH (NOLOCK) 
                     WHERE RPL1.StorerKey = PD.StorerKey
                     AND   RPL1.WaveKey = WD.WaveKey
                     AND   RPL1.OrderKey = PD.OrderKey
                     AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL1.PutAwayZone = LOC.PutAwayZone))
                     AND   RPL1.Status = '1'
                     AND   RPL1.AddWho = @cUserName)
      -- exclude those pickzone locked by other user in same orderkey (different orderkey allow)
      AND   NOT EXISTS ( SELECT 1 FROM RDT.RDTPickLock RPL2 WITH (NOLOCK)
                           WHERE RPL2.WaveKey = WD.WaveKey
                           AND   LOC.PickZone = RPL2.PickZone
                           AND   RPL2.AddWho <> @cUserName
                           AND   RPL2.StorerKey = PD.Storerkey
                           AND   RPL2.Status = '1' )
      ORDER BY LOC.PickZone
   END
   ELSE IF ISNULL( @cWaveKey, '') = '' AND ISNULL( @cLoadKey, '') <> ''
   BEGIN
      SELECT TOP 1 @cPickZone = LOC.PickZone
      FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
      WHERE (( @nMultiStorer = 1) OR ( PD.StorerKey = @cStorerKey))
      AND   LPD.LoadKey = @cLoadKey
      AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
      AND   LOC.Facility = @cFacility
      AND   PD.Status = '0'
      -- look for pickzone in the same wave+load+orders+putawayzone defined by users
      AND   EXISTS ( SELECT 1 FROM RDT.RDTPickLock RPL1 WITH (NOLOCK) 
                     WHERE RPL1.StorerKey = PD.StorerKey
                     AND   RPL1.LoadKey = LPD.LoadKey
                     AND   RPL1.OrderKey = PD.OrderKey
                     AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL1.PutAwayZone = LOC.PutAwayZone))
                     AND   RPL1.Status = '1'
                     AND   RPL1.AddWho = @cUserName)
      -- exclude those pickzone locked by other user in same orderkey (different orderkey allow)
      AND   NOT EXISTS ( SELECT 1 FROM RDT.RDTPickLock RPL2 WITH (NOLOCK)
                           WHERE PD.OrderKey = RPL2.OrderKey
                           AND   LOC.PickZone = RPL2.PickZone
                           AND   RPL2.AddWho <> @cUserName
                           AND   RPL2.StorerKey = PD.Storerkey
                           AND   RPL2.Status = '1' )
      ORDER BY LOC.PickZone
   END
   ELSE
   BEGIN
      SELECT TOP 1 @cPickZone = LOC.PickZone
      FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
      JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
      WHERE (( @nMultiStorer = 1) OR ( O.StorerKey = @cStorerKey))
      AND   (( ISNULL( @cOrderKey, '') = '') OR ( O.OrderKey = @cOrderKey)) 
      AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
      AND   LOC.Facility = @cFacility
      AND   PD.Status = '0'
      -- look for pickzone in the same wave+load+orders+putawayzone defined by users
      AND   EXISTS ( SELECT 1 FROM RDT.RDTPickLock RPL1 WITH (NOLOCK) 
                     WHERE RPL1.StorerKey = PD.StorerKey
                     AND   RPL1.OrderKey = PD.OrderKey
                     AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL1.PutAwayZone = LOC.PutAwayZone))
                     AND   RPL1.Status = '1'
                     AND   RPL1.AddWho = @cUserName)
      -- exclude those pickzone locked by other user in same orderkey (different orderkey allow)
      AND   NOT EXISTS ( SELECT 1 FROM RDT.RDTPickLock RPL2 WITH (NOLOCK)
                           WHERE PD.OrderKey = RPL2.OrderKey
                           AND   LOC.PickZone = RPL2.PickZone
                           AND   RPL2.AddWho <> @cUserName
                           AND   RPL2.StorerKey = PD.Storerkey
                           AND   RPL2.Status = '1' )
      ORDER BY LOC.PickZone
   END

QUIT:

GO