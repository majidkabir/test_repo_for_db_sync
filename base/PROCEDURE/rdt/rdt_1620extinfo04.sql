SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1620ExtInfo04                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: 1. PVH show # of loc locked by user                         */    
/*          2. Show qty picked/total + right(pickdetail.id, 12)         */
/*                                                                      */    
/* Called from: rdtfnc_Cluster_Pick                                     */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2018-10-29 1.0  James    WMS6843 Created                             */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1620ExtInfo04]    
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

   DECLARE @cFacility         NVARCHAR( 5),
           @cPutawayZone      NVARCHAR( 10),
           @cUserName         NVARCHAR( 18),
           @cID               NVARCHAR( 18),
           @cRPL_ID           NVARCHAR( 18),
           @cPickZone         NVARCHAR( 10),
           @cO_Field08        NVARCHAR( 20),
           @cO_Field12        NVARCHAR( 20),
           @nLocCount         INT,
           @nPD_QtyPicked     INT,
           @nPL_QtyPicked     INT,
           @nTTL_Qty2Pick     INT

   SELECT @cFacility = Facility,
          @cPutawayZone = V_String10,
          @cUserName = UserName,
          @cO_Field08 = O_Field08,
          @cO_Field12 = O_Field12
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cRPL_ID = ''

   IF @nStep = 5
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT TOP 1 @cPickZone = RPL.PickZone
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey) -- (Vicky01)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.Loc = L.Loc) -- (Vicky01)
         WHERE RPL.StorerKey = @cStorerKey
            AND RPL.Status = '1'
            AND RPL.AddWho = @cUserName
            AND PD.Status = '0'
            AND L.Facility = @cFacility
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
         ORDER BY RPL.PickZone DESC   -- Pickzone can be blank if not setup in loc table

         SET @nLocCount = 0
         SELECT @nLocCount = COUNT( DISTINCT LOC.LOC)
         FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
         JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
         WHERE WD.WaveKey = @cWaveKey
         AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
         AND   (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
         AND   LOC.Facility = @cFacility
         AND   PD.Status = '0'
         -- look for pickzone in the same wave+load+orders+putawayzone defined by users
         AND   EXISTS ( SELECT 1 FROM RDT.RDTPickLock RPL1 WITH (NOLOCK) 
                        WHERE RPL1.StorerKey = PD.StorerKey
                        AND   RPL1.WaveKey = WD.WaveKey
                        AND   RPL1.OrderKey = PD.OrderKey
                        AND   (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL1.PutAwayZone = LOC.PutAwayZone))
                        AND   (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
                        AND   RPL1.Status = '1'
                        AND   RPL1.AddWho = @cUserName)

         SET @cExtendedInfo = 'LOC COUNT: ' + CAST( @nLocCount AS NVARCHAR( 5))
      END
   END

   IF @nStep = 6
   BEGIN
      IF @nInputKey = 1
      BEGIN
--       Show Qty Picked + Scanned Qty in this session / TTL to pick group by LOC,SKU,ID + ' ' + right(Pickdetail.ID,12).
--       ie, æ999/999 123456789012Æ
         SELECT TOP 1 @cID = PD.ID
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.Status = '0'
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cSKU
         AND   WD.WaveKey = @cWaveKey
         AND   EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK) 
                        WHERE RPL.WaveKey = WD.WaveKey
                        AND   RPL.SKU = PD.SKU
                        AND   RPL.LOC = PD.LOC
                        AND   RPL.LOT = PD.LOT
                        AND   Status = '1')
         ORDER BY 1

         SELECT @nTTL_Qty2Pick = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.Status < '9'
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cSKU
         AND   PD.ID = @cID
         AND   WD.WaveKey = @cWaveKey

         SELECT @nPD_QtyPicked = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.Status >= '3'
         AND   PD.Status < '9'
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cSKU
         AND   PD.ID = @cID
         AND   WD.WaveKey = @cWaveKey

         SELECT @nPL_QtyPicked = ISNULL( SUM( PickQty), 0)
         FROM RDT.RDTPICKLOCK WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   Status = '1'
         AND   LOC = @cLOC
         AND   SKU = @cSKU
         AND   WaveKey = @cWaveKey
         AND   AddWho = @cUserName

         UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET 
            ID = @cID
         WHERE StorerKey = @cStorerKey
         AND   Status = '1'
         AND   LOC = @cLOC
         AND   SKU = @cSKU
         AND   WaveKey = @cWaveKey
         AND   AddWho = @cUserName
         AND   (( ISNULL( DropID, '') = '') OR ( DropID = @cDropID))
         AND   OrderKey = @cOrderKey

         SET @cExtendedInfo = CAST( ( @nPD_QtyPicked + @nPL_QtyPicked) AS NVARCHAR( 3)) + '/' + CAST( @nTTL_Qty2Pick AS NVARCHAR( 3)) + ' ' + RIGHT( @cID,12)
      END
   END

   IF @nStep IN ( 7, 8, 9, 11, 19)
   BEGIN
      IF @nInputKey = 1
      BEGIN
--       Show Qty Picked + Scanned Qty in this session / TTL to pick group by LOC,SKU,ID + ' ' + right(Pickdetail.ID,12).
--       ie, æ999/999 123456789012Æ
         DECLARE @nIDQty INT, @nRPLIDQty INT, @nLOCIDSKUQty INT
         SELECT TOP 1 @cID = ID, @nRPLIDQty = ISNULL( SUM( PICKQTY), 0)
         FROM RDT.RDTPICKLOCK WITH (NOLOCK)
         WHERE STORERKEY = @cStorerKey 
         AND LOC = @cLOC 
         AND SKU = @cSKU 
         AND WAVEKEY = @cWaveKey 
         AND ADDWHO = @cUserName 
         AND STATUS = '1'
         AND   (( ISNULL( DropID, '') = '') OR ( DropID = @cDropID))
         GROUP BY ID
         ORDER BY SUM( PICKQTY) DESC  -- with qty come 1st

         SET @cRPL_ID = @cID

         IF ISNULL( @cID, '') <> ''
         BEGIN
            SELECT @nIDQty = SUM( QTY)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            --AND   OrderKey = @cOrderKey
            AND   Loc = @cLOC
            AND   SKU = @cSKU
            AND   ID = @cID
            AND   STATUS = '0'

            insert into traceinfo (tracename, timein, col1, col2, col3) values ('789', getdate(), @cID, @nRPLIDQty, @nIDQty)
            IF @nIDQty>@nRPLIDQty
               SELECT TOP 1 @cID = PD.ID
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
               WHERE PD.StorerKey = @cStorerKey
               AND   PD.Status = '0'
               AND   PD.LOC = @cLOC
               AND   PD.SKU = @cSKU
               AND   PD.OrderKey = @cOrderKey
               AND   WD.WaveKey = @cWaveKey
               AND   PD.ID = @cID
               AND   EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK) 
                              WHERE RPL.WaveKey = WD.WaveKey
                              AND   RPL.SKU = PD.SKU
                              AND   RPL.LOC = PD.LOC
                              AND   RPL.LOT = PD.LOT
                              AND   Status = '1'
                              AND   Dropid = @cDropID)
               ORDER BY 1
            ELSE
               SELECT TOP 1 @cID = PD.ID
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
               WHERE PD.StorerKey = @cStorerKey
               AND   PD.Status = '0'
               AND   PD.LOC = @cLOC
               AND   PD.SKU = @cSKU
               AND   PD.OrderKey = @cOrderKey
               AND   WD.WaveKey = @cWaveKey
               AND   PD.ID > @cID
               AND   EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK) 
                              WHERE RPL.WaveKey = WD.WaveKey
                              AND   RPL.SKU = PD.SKU
                              AND   RPL.LOC = PD.LOC
                              AND   RPL.LOT = PD.LOT
                              AND   Status = '1'
                              AND   Dropid = @cDropID)
               ORDER BY 1
         END
         ELSE
         BEGIN
            SELECT @cID = ID, @nRPLIDQty = SUM( PICKQTY)
            FROM RDT.RDTPICKLOCK WITH (NOLOCK)
            WHERE STORERKEY = @cStorerKey 
            AND LOC = @cLOC 
            AND SKU = @cSKU 
            AND WAVEKEY = @cWaveKey 
            AND ADDWHO = @cUserName 
            AND STATUS = '1'
            GROUP BY ID

            IF ISNULL( @cID, '') <> ''
            BEGIN
               SELECT @nIDQty = SUM( QTY)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   OrderKey = @cOrderKey
               AND   Loc = @cLOC
               AND   SKU = @cSKU
               AND   ID = @cID
               AND   STATUS = '0'

               IF @nIDQty>@nRPLIDQty
                  SELECT TOP 1 @cID = PD.ID
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
                  WHERE PD.StorerKey = @cStorerKey
                  AND   PD.Status = '0'
                  AND   PD.LOC = @cLOC
                  AND   PD.SKU = @cSKU
                  AND   PD.OrderKey = @cOrderKey
                  AND   WD.WaveKey = @cWaveKey
                  AND   PD.ID = @cID
                  AND   EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK) 
                                 WHERE RPL.WaveKey = WD.WaveKey
                                 AND   RPL.SKU = PD.SKU
                                 AND   RPL.LOC = PD.LOC
                                 AND   RPL.LOT = PD.LOT
                                 AND   Status = '1')
                  ORDER BY 1
               ELSE
                  SELECT TOP 1 @cID = PD.ID
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
                  WHERE PD.StorerKey = @cStorerKey
                  AND   PD.Status = '0'
                  AND   PD.LOC = @cLOC
                  AND   PD.SKU = @cSKU
                  AND   PD.OrderKey = @cOrderKey
                  AND   WD.WaveKey = @cWaveKey
                  AND   PD.ID > @cID
                  AND   EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK) 
                                 WHERE RPL.WaveKey = WD.WaveKey
                                 AND   RPL.SKU = PD.SKU
                                 AND   RPL.LOC = PD.LOC
                                 AND   RPL.LOT = PD.LOT
                                 AND   Status = '1')
                  ORDER BY 1
            END
            ELSE
            BEGIN
                  SELECT TOP 1 @cID = PD.ID
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
                  WHERE PD.StorerKey = @cStorerKey
                  AND   PD.Status = '0'
                  AND   PD.LOC = @cLOC
                  AND   PD.SKU = @cSKU
                  AND   PD.OrderKey = @cOrderKey
                  AND   WD.WaveKey = @cWaveKey
                  AND   EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK) 
                                 WHERE RPL.WaveKey = WD.WaveKey
                                 AND   RPL.SKU = PD.SKU
                                 AND   RPL.LOC = PD.LOC
                                 AND   RPL.LOT = PD.LOT
                                 AND   Status = '1')
                  ORDER BY 1
            END
         END

         SELECT @nTTL_Qty2Pick = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.Status <> '4'
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cSKU
         AND   PD.ID = @cID
         --AND   PD.OrderKey = @cOrderKey
         AND   WD.WaveKey = @cWaveKey
            /*
         -- Change id only need recalculate id qty to pick
         IF @cRPL_ID <> @cID
            SELECT @nTTL_Qty2Pick = ISNULL( SUM( Qty), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.Status = '0'
            AND   PD.LOC = @cLOC
            AND   PD.SKU = @cSKU
            AND   PD.ID = @cID
            --AND   PD.OrderKey = @cOrderKey
            AND   WD.WaveKey = @cWaveKey

         IF ISNULL( @nTTL_Qty2Pick, 0) = 0
         BEGIN
            SELECT @nLOCIDSKUQty = ISNULL( SUM( Qty), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.LOC = @cLOC
            AND   PD.SKU = @cSKU
            and   PD.ID = @cID
            AND   PD.Status = '3'
            AND   WD.WaveKey = @cWaveKey

            IF @nLOCIDSKUQty = 0
               SELECT @nTTL_Qty2Pick = ISNULL( SUM( Qty), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
               WHERE PD.StorerKey = @cStorerKey
               --AND   PD.Status = '0'
               AND   PD.LOC = @cLOC
               AND   PD.SKU = @cSKU
               AND   PD.ID = @cID
               --AND   PD.OrderKey = @cOrderKey
               AND   WD.WaveKey = @cWaveKey
         END
         */
         SELECT @nPD_QtyPicked = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.Status = '3'
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cSKU
         AND   PD.ID = @cID
         AND   WD.WaveKey = @cWaveKey
         --AND   PD.OrderKey = @cOrderKey

         SELECT @nPL_QtyPicked = ISNULL( SUM( PickQty), 0)
         FROM RDT.RDTPICKLOCK WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   Status = '1'
         AND   LOC = @cLOC
         AND   SKU = @cSKU
         AND   WaveKey = @cWaveKey
         AND   AddWho = @cUserName
         --AND   OrderKey = @cOrderKey
         AND   ID = @cID


         UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK) SET 
            ID = @cID
         WHERE StorerKey = @cStorerKey
         AND   Status = '1'
         AND   LOC = @cLOC
         AND   SKU = @cSKU
         AND   WaveKey = @cWaveKey
         AND   AddWho = @cUserName
         AND   (( ISNULL( DropID, '') = '') OR ( DropID = @cDropID))
         AND   OrderKey = @cOrderKey

         INSERT INTO TRACEINFO ( TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5) VALUES
         ('123', GETDATE(), @cStorerKey, @cLOC, @cSKU, @cWaveKey, @cUserName)
         SET @cExtendedInfo = CAST( ( @nPD_QtyPicked + @nPL_QtyPicked) AS NVARCHAR( 3)) + '/' + CAST( @nTTL_Qty2Pick AS NVARCHAR( 3)) + ' ' + RIGHT( @cID,12)
      END
   END

   IF @nStep = 8
   BEGIN
      IF @nInputKey = 0
      BEGIN
         SET @cExtendedInfo = @cO_Field08
      END
   END
   
   IF @nStep = 9
   BEGIN
      IF @nInputKey = 0
      BEGIN
         SET @cExtendedInfo = @cO_Field12
      END
   END
   
QUIT:    
END -- End Procedure  

GO