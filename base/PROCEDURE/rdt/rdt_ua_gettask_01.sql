SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_UA_GETTASK_01                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Get next SKU to Pick, ORDER seq as below                    */  
/*          If there is pack requirement on the order header level      */
/*          (Orders.Userdefine10<>ÆÆ), sort the pick detail by          */
/*          COO(Lotattribute.Lottable08), sku                           */
/*          Else sort the pick detail by COO, logicalloc,loc            */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 12-Jun-2012 1.0  James       SOS247205 - Created                     */  
/* 24-06-2015  1.1  James       Update sorting seq                      */
/************************************************************************/  

CREATE PROC [RDT].[rdt_UA_GETTASK_01] (  
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

   DECLARE @cSize_Seq         NVARCHAR( 30), 
           @n_MultiStorer     INT 

   SELECT @n_MultiStorer = V_String37 
   FROM rdt.rdtMOBREC WITH (NOLOCK) 
   WHERE Mobile = @n_Mobile

   IF EXISTS ( SELECT 1 
               FROM RDT.RDTPickLock RPL WITH (NOLOCK) 
               JOIN dbo.Orders O WITH (NOLOCK, INDEX(PKOrders) ) ON RPL.OrderKey = O.OrderKey
               WHERE RPL.Status < '9'
               AND   RPL.AddWho = @c_UserName
               AND   RPL.StorerKey = CASE WHEN @n_MultiStorer = 1 THEN RPL.StorerKey ELSE @c_StorerKey END
               AND   RPL.PutAwayZone = CASE WHEN @c_PutAwayZone = 'ALL' THEN RPL.PutAwayZone ELSE @c_PutAwayZone END
               AND   RPL.PickZone = CASE WHEN ISNULL(@c_PickZone, '') = '' THEN RPL.PickZone ELSE @c_PickZone END
               AND   ISNULL( O.Userdefine10, '') <> '')
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE ListName = 'CLPLOCTYPE' AND ISNULL( CODE, '') <> '' AND StorerKey = @c_StorerKey)
         SELECT TOP 1   
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = SKU.SKU,  
            @c_oFieled04   = SKU.DESCR,
            @c_oFieled05   = SKU.Style,
            @c_oFieled06   = SKU.Color,
            @c_oFieled07   = SKU.Size,
            @c_oFieled08   = SKU.BUSR7,
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)  
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( L.LocationType = CLK.Code AND PD.StorerKey = CLK.Storerkey AND ListName = 'CLPLOCTYPE')
         WHERE RPL.StorerKey = @c_StorerKey  
            AND RPL.Status < '9'  
            AND RPL.AddWho = @c_UserName  
            AND PD.Status = '0'  
            AND L.PutAwayZone = CASE WHEN @c_PutAwayZone = 'ALL' THEN L.PutAwayZone ELSE @c_PutAwayZone END  
            AND L.PickZone = CASE WHEN ISNULL(@c_PickZone, '') = '' THEN L.PickZone ELSE @c_PickZone END  
            AND L.Facility = @c_Facility  
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK) 
                            WHERE SKIP_RPL.OrderKey = PD.OrderKey
                            AND SKIP_RPL.SKU = PD.SKU
                            AND SKIP_RPL.AddWho = @c_UserName
                            AND SKIP_RPL.Status = 'X')
         ORDER BY LA.Lottable08, SKU.SKU, L.LogicalLocation, L.LOC
      ELSE
         SELECT TOP 1   
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = SKU.SKU,  
            @c_oFieled04   = SKU.DESCR,
            @c_oFieled05   = SKU.Style,
            @c_oFieled06   = SKU.Color,
            @c_oFieled07   = SKU.Size,
            @c_oFieled08   = SKU.BUSR7,
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)  
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE RPL.StorerKey = @c_StorerKey  
            AND RPL.Status < '9'  
            AND RPL.AddWho = @c_UserName  
            AND PD.Status = '0'  
            AND L.PutAwayZone = CASE WHEN @c_PutAwayZone = 'ALL' THEN L.PutAwayZone ELSE @c_PutAwayZone END  
            AND L.PickZone = CASE WHEN ISNULL(@c_PickZone, '') = '' THEN L.PickZone ELSE @c_PickZone END  
            AND L.Facility = @c_Facility  
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK) 
                            WHERE SKIP_RPL.OrderKey = PD.OrderKey
                            AND SKIP_RPL.SKU = PD.SKU
                            AND SKIP_RPL.AddWho = @c_UserName
                            AND SKIP_RPL.Status = 'X')
         ORDER BY LA.Lottable08, SKU.SKU, L.LogicalLocation, L.LOC
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE ListName = 'CLPLOCTYPE' AND ISNULL( CODE, '') <> '' AND StorerKey = @c_StorerKey)
         SELECT TOP 1   
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = SKU.SKU,  
            @c_oFieled04   = SKU.DESCR,
            @c_oFieled05   = SKU.Style,
            @c_oFieled06   = SKU.Color,
            @c_oFieled07   = SKU.Size,
            @c_oFieled08   = SKU.BUSR7,
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)  
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( L.LocationType = CLK.Code AND PD.StorerKey = CLK.Storerkey AND ListName = 'CLPLOCTYPE')
         WHERE RPL.StorerKey = @c_StorerKey  
            AND RPL.Status < '9'  
            AND RPL.AddWho = @c_UserName  
            AND PD.Status = '0'  
            AND L.PutAwayZone = CASE WHEN @c_PutAwayZone = 'ALL' THEN L.PutAwayZone ELSE @c_PutAwayZone END  
            AND L.PickZone = CASE WHEN ISNULL(@c_PickZone, '') = '' THEN L.PickZone ELSE @c_PickZone END  
            AND L.Facility = @c_Facility  
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK) 
                            WHERE SKIP_RPL.OrderKey = PD.OrderKey
                            AND SKIP_RPL.SKU = PD.SKU
                            AND SKIP_RPL.AddWho = @c_UserName
                            AND SKIP_RPL.Status = 'X')
         ORDER BY LA.Lottable08, L.LogicalLocation, PD.LOC
      ELSE
         SELECT TOP 1   
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = SKU.SKU,  
            @c_oFieled04   = SKU.DESCR,
            @c_oFieled05   = SKU.Style,
            @c_oFieled06   = SKU.Color,
            @c_oFieled07   = SKU.Size,
            @c_oFieled08   = SKU.BUSR7,
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)  
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE RPL.StorerKey = @c_StorerKey  
            AND RPL.Status < '9'  
            AND RPL.AddWho = @c_UserName  
            AND PD.Status = '0'  
            AND L.PutAwayZone = CASE WHEN @c_PutAwayZone = 'ALL' THEN L.PutAwayZone ELSE @c_PutAwayZone END  
            AND L.PickZone = CASE WHEN ISNULL(@c_PickZone, '') = '' THEN L.PickZone ELSE @c_PickZone END  
            AND L.Facility = @c_Facility  
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK) 
                            WHERE SKIP_RPL.OrderKey = PD.OrderKey
                            AND SKIP_RPL.SKU = PD.SKU
                            AND SKIP_RPL.AddWho = @c_UserName
                            AND SKIP_RPL.Status = 'X')
         ORDER BY LA.Lottable08, L.LogicalLocation, PD.LOC
   END

   SELECT 
      @c_oFieled11   = ExternOrderKey,  
      @c_oFieled12   = ConsigneeKey  
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey  
      AND OrderKey = @c_oFieled02
END 

GO