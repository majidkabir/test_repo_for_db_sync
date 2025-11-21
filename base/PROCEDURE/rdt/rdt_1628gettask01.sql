SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1628GETTASK01                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Get next SKU to Pick                                        */  
/*          ORDER seq as below                                          */  
/*          PickDetail.Loc, SKU, ORDERKEY                               */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 08-Apr-2016 1.0  James       Created                                 */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_1628GETTASK01] (  
   @n_Mobile                  INT, 
   @n_Func                    INT, 
   @c_StorerKey               NVARCHAR( 15),  
   @c_UserName                NVARCHAR( 15),  
   @c_Facility                NVARCHAR( 5),  
   @c_PutAwayZone             NVARCHAR( 10),  
   @c_PickZone                NVARCHAR( 10),  
   @c_LangCode                NVARCHAR( 3),  
	@c_oFieled01               NVARCHAR( 20)      OUTPUT,
	@c_oFieled02               NVARCHAR( 20)      OUTPUT,
   @c_oFieled03               NVARCHAR( 20)      OUTPUT,
   @c_oFieled04               NVARCHAR( 20)      OUTPUT,
   @c_oFieled05               NVARCHAR( 20)      OUTPUT,
   @c_oFieled06               NVARCHAR( 20)      OUTPUT,
   @c_oFieled07               NVARCHAR( 20)      OUTPUT,
   @c_oFieled08               NVARCHAR( 20)      OUTPUT,
   @c_oFieled09               NVARCHAR( 20)      OUTPUT,
   @c_oFieled10               NVARCHAR( 20)      OUTPUT,
	@c_oFieled11               NVARCHAR( 20)      OUTPUT,
	@c_oFieled12               NVARCHAR( 20)      OUTPUT,
   @c_oFieled13               NVARCHAR( 20)      OUTPUT,
   @c_oFieled14               NVARCHAR( 20)      OUTPUT,
   @c_oFieled15               NVARCHAR( 20)      OUTPUT, 
   @b_Success                 INT            OUTPUT, 
   @nErrNo                    INT            OUTPUT,   
   @cErrMsg                   NVARCHAR( 20)   OUTPUT 
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_WaveKey   NVARCHAR( 10),
           @c_LoadKey   NVARCHAR( 10),
           @c_Lottable02   NVARCHAR( 18),
           @c_LogicalLoc   NVARCHAR( 10),
           @c_LOC          NVARCHAR( 10),
           @d_Lottable04   DATETIME

   SELECT @c_WaveKey    = V_String1, 
          @c_LoadKey    = V_LoadKey,
          @c_Lottable02 = V_Lottable02,
          @d_Lottable04 = V_Lottable04
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @n_Mobile

   IF ISNULL( @c_oFieled03, '') <> ''
   BEGIN
      SET @c_LogicalLoc = ''
      SELECT @c_LogicalLoc = LogicalLocation
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @c_LOC
         AND Facility = @c_Facility

      SELECT TOP 1
         @c_oFieled01 = PD.Loc,
         @c_oFieled03 = PD.SKU,
         @c_oFieled13 = LA.Lottable02,
         @c_oFieled14 = LA.Lottable04
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK)
         ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE O.StorerKey = @c_StorerKey
         AND PD.Status = '0'
         AND O.LoadKey = @c_LoadKey
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL( @c_PickZone, '') = '') OR ( LOC.PickZone = @c_PickZone))
         AND LOC.Facility = @c_Facility
         AND RTRIM(LOC.LogicalLocation) + RTRIM(PD.SKU) + ISNULL(RTRIM(LA.Lottable02), '') + ISNULL(CONVERT( NVARCHAR( 10), LA.Lottable04, 120), 0) >
               RTRIM(@c_LogicalLoc) + RTRIM(@c_oFieled03) + RTRIM(@c_Lottable02) + ISNULL(CONVERT( NVARCHAR( 10), @d_Lottable04, 120), 0)--@dLottable04
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            WHERE PD.StorerKey = RPL.StorerKey AND PD.OrderKey = RPL.OrderKey AND PD.SKU = RPL.SKU AND RPL.Status = '1')
      GROUP BY SKU.Style, SKU.Color, LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
      ORDER BY RTRIM( SKU.Style) + RTRIM( SKU.Color), LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04

      IF @@ROWCOUNT = 0
      BEGIN
         SELECT TOP 1
            @c_oFieled01 = PD.Loc,
            @c_oFieled03 = PD.SKU,
            @c_oFieled13 = LA.Lottable02,
            @c_oFieled14 = LA.Lottable04
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE O.StorerKey = @c_StorerKey
            AND (( ISNULL( @c_WaveKey, '') = '') OR ( O.UserDefine09 = @c_WaveKey))
            AND (( ISNULL(@c_LoadKey, '') = '') OR ( O.LoadKey = @c_LoadKey))
            AND PD.Status = '0'
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL( @c_PickZone, '') = '') OR ( LOC.PickZone = @c_PickZone))
            AND LOC.Facility = @c_Facility
         GROUP BY SKU.Style, SKU.Color, LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
         ORDER BY RTRIM( SKU.Style) + RTRIM( SKU.Color), LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
      END

      GOTO Quit
   END
   ELSE
   BEGIN
      SELECT TOP 1
         @c_oFieled01 = PD.Loc,
         @c_oFieled03 = PD.SKU,
         @c_oFieled13 = LA.Lottable02,
         @c_oFieled14 = LA.Lottable04
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE RPL.StorerKey = @c_StorerKey
         AND RPL.Status = '1'
         AND RPL.AddWho = @c_UserName
         AND (( ISNULL( @c_WaveKey, '') = '') OR ( RPL.WaveKey = @c_WaveKey))
         AND (( ISNULL(@c_LoadKey, '') = '') OR ( RPL.LoadKey = @c_LoadKey))
         AND PD.Status = '0'
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL( @c_PickZone, '') = '') OR ( LOC.PickZone = @c_PickZone))
         AND LOC.Facility = @c_Facility
      GROUP BY SKU.Style, SKU.Color, LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
      ORDER BY RTRIM( SKU.Style) + RTRIM( SKU.Color), LOC.LogicalLocation, PD.Loc, PD.SKU, LA.Lottable02, LA.Lottable04
   END

   Quit:
END 

GO