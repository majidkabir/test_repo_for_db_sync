SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_GetNextTask                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next SKU to Pick                                        */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-Sep-2008 1.0  James       Created                                 */
/* 12-Dec-2008 1.1  Vicky       Add TraceInfo (Vicky02)                 */
/* 03-Feb-2009 1.2  James       SOS127539 - Merged with Pharma          */
/*                              Cluster Pick                            */
/* 20-Dec-2010 1.3  TLTING      Performance Tune                        */
/* 27-Dec-2011 1.4  TLTING      Performance Tune (TLTING01)             */  
/* 26-Jul-2011 1.5  James       SOS221854 Bug fix (james01)             */  
/* 06-Mar-2012 1.6  James       SOS#238001 - Fix get loc error (james02)*/
/* 05-Jun-2012 1.7  TLTING      Performance Tune (TLTING02)             */  
/* 30-Apr-2013 1.8  James       SOS276235 - Allow multi storer (james03)*/  
/* 24-Feb-2017 1.9  James       Perfomance tuning (james04)             */
/* 27-Nov-2017 2.0  James       Add new parms (james05)                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_Cluster_Pick_GetNextTask] (
   @cStorerKey                NVARCHAR( 15),
   @cUserName                 NVARCHAR( 15),
   @cFacility                 NVARCHAR( 5),
   @cPutAwayZone              NVARCHAR( 10),
   @cPickZone                 NVARCHAR( 10),
   @cLangCode                 NVARCHAR( 3),
   @nErrNo                    INT              OUTPUT,
   @cErrMsg                   NVARCHAR( 20)    OUTPUT,  -- screen limitation, 20 NVARCHAR max
   @cLOC                      NVARCHAR( 10)    OUTPUT,
   @cOrderKey                 NVARCHAR( 10)    OUTPUT,
   @cExternOrderKey           NVARCHAR( 20)    OUTPUT,
   @cConsigneeKey             NVARCHAR( 15)    OUTPUT,
   @cSKU                      NVARCHAR( 20)    OUTPUT,
   @cSKU_Descr                NVARCHAR( 60)    OUTPUT,
   @cStyle                    NVARCHAR( 20)    OUTPUT,
   @cColor                    NVARCHAR( 10)    OUTPUT,
   @cSize                     NVARCHAR( 5)     OUTPUT,
   @cColor_Descr              NVARCHAR( 20)    OUTPUT,
   @cLot                      NVARCHAR( 10)    OUTPUT,
   @cPickSlipNo               NVARCHAR( 10)    OUTPUT,
   @nMobile                   INT,
   @nFunc                     INT,
   @cWaveKey                  NVARCHAR( 10) = '',
   @cLoadKey                  NVARCHAR( 10) = '',
   @cLottable02               NVARCHAR( 18)  = '',
   @dLottable04               DATETIME       = NULL
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success         INT
   DECLARE @n_err             INT
   DECLARE @c_errmsg          NVARCHAR( 250),
           @cORD_StorerKey    NVARCHAR( 15),    -- (james03)
           @nMultiStorer      INT               -- (james03)

   -- TraceInfo (Vicky02) - Start
   DECLARE    @d_starttime    datetime,
              @d_endtime      datetime,
              @d_step1        datetime,
              @d_step2        datetime,
              @d_step3        datetime,
              @d_step4        datetime,
              @d_step5        datetime,
              @c_col1         NVARCHAR(20),
              @c_col2         NVARCHAR(20),
              @c_col3         NVARCHAR(20),
              @c_col4         NVARCHAR(20),
              @c_col5         NVARCHAR(20),
              @c_TraceName    NVARCHAR(80)



   IF @nFunc = 1628
   BEGIN
      SELECT TOP 1
         @cLOC = PD.Loc,
         @cSKU = PD.SKU,
         @cLot = LA.LOT
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE RPL.StorerKey = @cStorerKey
         AND RPL.Status = '1'
         AND RPL.AddWho = @cUserName
         AND (( ISNULL( @cWaveKey, '') = '') OR ( RPL.WaveKey = @cWaveKey))
         AND (( ISNULL(@cLoadKey, '') = '') OR ( RPL.LoadKey = @cLoadKey))
         AND PD.Status = '0'
         AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
         AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
         AND LOC.Facility = @cFacility
      GROUP BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lot
      ORDER BY LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lot

      SELECT
         @cSKU_Descr   = SKU.DESCR,
         @cStyle       = SKU.Style,
         @cColor       = SKU.Color,
         @cSize        = SKU.Size,
         @cColor_Descr = SKU.BUSR7
      FROM dbo.SKU SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU
   END
   ELSE
   BEGIN
      SET @d_starttime = getdate()

      SET @c_col1 = @cPutAwayZone
      SET @c_col2 = @cPickZone
      SET @c_col3 = @cUserName
      SET @c_col4 = ''
      SET @c_col5 = ''

      SET @c_TraceName = 'rdt_Cluster_Pick_GetNextTask'
      -- TraceInfo (Vicky02) - End

      SET @d_step1 = GETDATE() -- (Vicky02)

      -- (james03)
      SET @nMultiStorer = 0
      IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
         SET @nMultiStorer = 1

      SELECT TOP 1
         @cLOC = PD.Loc,
         @cOrderKey = PD.OrderKey,
         @cSKU = PD.SKU,
         @cLot = PD.LOT,
         @cPickSlipNo = PD.PickSlipNo
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE (( @nMultiStorer = 1) OR ( RPL.StorerKey = @cStorerKey))
         AND RPL.Status < '9'
         AND RPL.AddWho = @cUserName
         AND PD.Status = '0'
         AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
         AND (( ISNULL(@cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
         AND L.Facility = @cFacility
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                         WHERE SKIP_RPL.OrderKey = PD.OrderKey
                         AND SKIP_RPL.StorerKey = RPL.StorerKey  
                         AND SKIP_RPL.SKU = PD.SKU
                         AND SKIP_RPL.AddWho = @cUserName
                         AND SKIP_RPL.Status = 'X')
         -- Not to get the same loc within the same orders
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                         WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                         AND SKIP_RPL2.StorerKey = RPL.StorerKey  -- TLTING02
                         AND SKIP_RPL2.AddWho <> @cUserName
                         AND SKIP_RPL2.Status = '1'
                         AND SKIP_RPL2.LOC = pd.LOC )  -- james02
      ORDER BY L.LogicalLocation, PD.LOC, PD.SKU, RPL.OrderKey    

      SET @d_step1 = GETDATE() - @d_step1 -- (Vicky02)

      -- (james01)  
      IF @@ROWCOUNT = 0  
      BEGIN  
         -- Look for task for another storer within defined storergroup (james03)
         IF @nMultiStorer = 1
         BEGIN
            SELECT TOP 1
               @cLOC = PD.Loc,
               @cOrderKey = PD.OrderKey,
               @cSKU = PD.SKU,
               @cLot = PD.LOT,
               @cPickSlipNo = PD.PickSlipNo
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (PD.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
            WHERE PD.Status = '0'
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @cPutAwayZone))
               AND (( ISNULL(@cPickZone, '') = '') OR ( L.PickZone = @cPickZone))
               AND L.Facility = @cFacility
               AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                               WHERE SKIP_RPL.OrderKey = PD.OrderKey
                               AND SKIP_RPL.StorerKey = PD.StorerKey  
                               AND SKIP_RPL.SKU = PD.SKU
                               AND SKIP_RPL.AddWho = @cUserName
                               AND SKIP_RPL.Status = 'X')
               -- Not to get the same loc within the same orders
               AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                               WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                               AND SKIP_RPL2.StorerKey = PD.StorerKey  -- TLTING02
                               AND SKIP_RPL2.AddWho <> @cUserName
                               AND SKIP_RPL2.Status = '1'
                               AND SKIP_RPL2.LOC = PD.LOC )  -- james02
            ORDER BY L.LogicalLocation, PD.LOC, PD.SKU, PD.OrderKey    
         END
      
         IF @@ROWCOUNT = 0
         BEGIN
            SET @cOrderKey = ''  
            GOTO Quit  
         END
      END  

      SET @d_step2 = GETDATE() -- (Vicky02)   

      IF @nMultiStorer = 1
      BEGIN
         SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         SELECT @cSKU_Descr = SKU.DESCR,
            @cStyle = SKU.Style,
            @cColor = SKU.Color,
            @cSize = SKU.Size,
            @cColor_Descr = SKU.BUSR7
         FROM dbo.SKU SKU WITH (NOLOCK)
         WHERE SKU.Storerkey = @cORD_StorerKey
         AND   SKU.SKU = @cSKU

         SET @d_step2 = GETDATE() - @d_step2 -- (Vicky02)

         SET @d_step3 = GETDATE() -- (Vicky02)
         SELECT
            @cExternOrderKey = ExternOrderKey,
            @cConsigneeKey = ConsigneeKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cORD_StorerKey
         AND   OrderKey = @cOrderKey
      END
      ELSE
      BEGIN
         SELECT @cSKU_Descr = SKU.DESCR,
            @cStyle = SKU.Style,
            @cColor = SKU.Color,
            @cSize = SKU.Size,
            @cColor_Descr = SKU.BUSR7
         FROM dbo.SKU SKU WITH (NOLOCK)
         WHERE SKU.Storerkey = @cStorerKey
         AND   SKU.SKU = @cSKU

         SET @d_step2 = GETDATE() - @d_step2 -- (Vicky02)

         SET @d_step3 = GETDATE() -- (Vicky02)
         SELECT
            @cExternOrderKey = ExternOrderKey,
            @cConsigneeKey = ConsigneeKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey
      END

      SET @d_step3 = GETDATE() - @d_step3 -- (Vicky02)

      -- Trace Info (Vicky02) - Start
      SET @d_endtime = GETDATE()
   --   INSERT INTO TraceInfo VALUES
   --               (RTRIM(@c_TraceName), @d_starttime, @d_endtime
   --               ,CONVERT(NVARCHAR(12),@d_endtime - @d_starttime ,114)
   --               ,CONVERT(NVARCHAR(12),@d_step1,114)
   --               ,CONVERT(NVARCHAR(12),@d_step2,114)
   --               ,CONVERT(NVARCHAR(12),@d_step3,114)
   --               ,CONVERT(NVARCHAR(12),@d_step4,114)
   --               ,CONVERT(NVARCHAR(12),@d_step5,114)
   --               ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

         SET @d_step1 = NULL
         SET @d_step2 = NULL
         SET @d_step3 = NULL
         SET @d_step4 = NULL
         SET @d_step5 = NULL
      -- Trace Info (Vicky02) - End
   END
Quit:
END

GO